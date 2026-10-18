#!/usr/bin/env python3
"""Find embedded credentials without writing credential values to output.

The default gate checks tracked and nonignored files in the customer, admin and
authoritative worker repositories. Historical/archive/generated findings are
reported separately: they still need revocation and a scoped cleanup, but are
not executable source repaired by this gate. This is a focused regression scan,
not a credential-validity test or a replacement for an established secret scanner.
"""

from __future__ import annotations

import argparse
from dataclasses import dataclass
import os
from pathlib import Path
import re
import subprocess
import sys
from collections.abc import Iterable


@dataclass(frozen=True, order=True)
class Finding:
    category: str
    path: str
    line: int
    rule: str


SECRET_NAME = re.compile(
    r"(?:^|_)(?:secret|password|auth_?token|access_?token|api_?key|credential)(?:$|_)"
    r"|^_*(?:(?:api|client|auth|access|refresh|turn|shared)(?:key|secret|token|credential)|loginPassword)$", re.I
)
PUBLIC_NAME = re.compile(
    r"(?:anon_?key|publishable|public_?key|key_?id|credential_?(?:key|id|status)|vault_?id)", re.I
)
QUOTED = r'''["'](?P<value>[^"'\r\n]*)["']'''
ASSIGNMENT = re.compile(
    r'''(?<![A-Za-z_0-9])(?P<key>[A-Za-z_][A-Za-z_0-9]*)["']?\s*(?::\s*(?:string|String)\s*)?(?:=|:)\s*'''
    + QUOTED,
    re.I,
)
ENV_FALLBACK = re.compile(
    r'''Deno\.env\.get\(\s*["'](?P<key>[A-Z_0-9]+)["']\s*\)'''
    r'''(?:\s*(?:\|\||\?\?)\s*Deno\.env\.get\(\s*["'][A-Z_0-9]+["']\s*\))*'''
    r'''\s*(?:\|\||\?\?)\s*'''
    + QUOTED,
)
CONFIG_FALLBACK = re.compile(
    r'''(?:fetchConfig|getConfig)\([^,\n]+,\s*["'](?P<key>[A-Z_0-9]+)["']\s*,\s*'''
    + QUOTED,
)
FIXED_RULES = (
    ("supabase-management-pat", re.compile(r"\bsbp_[A-Za-z0-9_-]{24,}\b")),
    ("telnyx-api-key", re.compile(r"\bKEY[A-Za-z0-9_-]{25,}\b")),
    ("firsty-client-secret", re.compile(r"\bcsk_[A-Za-z0-9_-]{24,}\b")),
    (
        "predictable-turn-secret",
        re.compile(r"\bkeepsims[_-]turn[_-]secret[_-][A-Za-z0-9_-]+\b", re.I),
    ),
    (
        "private-key-material",
        re.compile(
            r"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----"
            r"(?:\r?\n|\\n)[A-Za-z0-9+/=\r\n\\]+"
            r"-----END (?:RSA |EC |OPENSSH )?PRIVATE KEY-----"
        ),
    ),
)
SKIP_DIRS = {
    ".git", "node_modules", "Pods", ".pub-cache", ".gradle", ".wwebjs_auth",
    ".wwebjs_cache", "__pycache__", "ephemeral", ".symlinks",
}
GENERATED_DIRS = {"build", ".dart_tool", ".build", "coverage"}
GENERATED_SUFFIXES = {".dill", ".bin", ".apk", ".aab", ".ipa", ".exe", ".dll"}
MAX_FILE_BYTES = 150_000_000


def is_placeholder(value: str) -> bool:
    """Allow explicit documentation/example placeholders, not weak defaults."""
    value = value.strip()
    if not value:
        return True
    if any(marker in value for marker in ("${", "{{", "$env:", "process.env")):
        return True
    if re.fullmatch(r"<[^<>]+>", value):
        return True
    if re.fullmatch(r"(?:YOUR|REPLACE_WITH|INSERT|SET)_[A-Z0-9_]+", value):
        return True
    if re.match(r"(?:your|insert|replace)[-_ ]", value, re.I):
        return True
    if re.fullmatch(r"\{[A-Za-z_][A-Za-z0-9_]*\}", value):
        return True
    if re.fullmatch(r"(?:placeholder|example|dummy|fake|test)(?:[-_ ][a-z0-9_-]+)?", value, re.I):
        return True
    return False


def scan_text(content: str, path: str, category: str = "active", *, check_assignments: bool = True) -> list[Finding]:
    """Return locations and rule names only; no match objects or secret text."""
    findings: set[Finding] = set()

    def add(offset: int, rule: str) -> None:
        findings.add(Finding(category, path, content.count("\n", 0, offset) + 1, rule))

    for rule, pattern in FIXED_RULES:
        for match in pattern.finditer(content):
            add(match.start(), rule)

    if not check_assignments:
        return sorted(findings)

    for pattern, rule in (
        (ASSIGNMENT, "embedded-secret-assignment"),
        (ENV_FALLBACK, "embedded-secret-fallback"),
        (CONFIG_FALLBACK, "embedded-secret-fallback"),
    ):
        for match in pattern.finditer(content):
            key, value = match.group("key"), match.group("value")
            if PUBLIC_NAME.search(key) or not SECRET_NAME.search(key):
                continue
            if is_placeholder(value):
                continue
            # Explicit synthetic test data is allowed, while provider-shaped
            # literals above and real-looking account tokens still fail there.
            fixture = bool(re.search(r"(?:^|/)(?:test|tests)/|(?:\.test\.[a-z]+|_test\.dart|/test_[^/]+\.py)$", path))
            if fixture and len(value) < 48 and not re.fullmatch(r"[a-fA-F0-9]{32}", value):
                continue
            # Metadata, HTML autocomplete hints and parameter labels are not
            # credential values. These are exact labels, not substring ignores.
            if value in {"true", "false", "new-password", "current-password", "access_token", "api_key"}:
                continue
            if value.startswith("/") or re.fullmatch(r"[A-Z][A-Z_0-9]+", value):
                continue
            if rule == "embedded-secret-assignment" and len(value) < 16:
                json_password = path.endswith(".json") and "password" in key.lower()
                weak_default = value.lower() in {"password", "secret", "changeme", "openrelayproject"}
                if not json_password and not weak_default:
                    continue
            add(match.start(), rule)
    return sorted(findings)


def category_for(path: Path) -> str:
    if "migration_archive" in path.parts or ".history" in path.parts:
        return "archive"
    if any(part in GENERATED_DIRS for part in path.parts) or path.suffix in GENERATED_SUFFIXES:
        return "generated"
    return "active"


def git_files(repo: Path) -> list[Path]:
    result = subprocess.run(
        ["git", "-C", str(repo), "ls-files", "-z", "--cached", "--others", "--exclude-standard"],
        check=True, capture_output=True,
    )
    return sorted({Path(p.decode("utf-8", errors="replace")) for p in result.stdout.split(b"\0") if p})


def generated_files(repo: Path) -> Iterable[Path]:
    # Only explicit generated roots are visited; ignored .env/user secrets and
    # dependency directories are not part of an embedded-source regression gate.
    for name in sorted(GENERATED_DIRS):
        root = repo / name
        if not root.is_dir():
            continue
        for directory, dirs, files in os.walk(root, followlinks=False):
            dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
            for filename in files:
                yield (Path(directory) / filename).relative_to(repo)


def scan_repository(repo: Path, include_generated: bool = False) -> tuple[list[Finding], int, int]:
    findings: set[Finding] = set()
    skipped_large = 0
    skipped_binary = 0
    files = set(git_files(repo))
    if include_generated:
        files.update(generated_files(repo))
    for relative in sorted(files):
        if any(part in SKIP_DIRS for part in relative.parts):
            continue
        category = category_for(relative)
        if category == "generated" and not include_generated:
            continue
        path = repo / relative
        if path.is_symlink() or not path.is_file():
            continue
        if path.stat().st_size > MAX_FILE_BYTES:
            skipped_large += 1
            continue
        raw = path.read_bytes()
        binary = b"\0" in raw[:8192]
        if category == "active" and binary:
            skipped_binary += 1
            continue
        content = raw.decode("utf-8", errors="replace")
        findings.update(scan_text(content, f"{repo.name}/{relative.as_posix()}", category, check_assignments=not binary))
    return sorted(findings), skipped_large, skipped_binary


def scan_history(repo: Path) -> list[Finding]:
    """Explicit opt-in inventory of reachable Git blobs; never emit their text."""
    objects = subprocess.run(
        ["git", "-C", str(repo), "rev-list", "--objects", "--all"],
        check=True, capture_output=True,
    ).stdout.decode("utf-8", errors="replace").splitlines()
    paths: dict[str, str] = {}
    for entry in objects:
        parts = entry.split(" ", 1)
        if len(parts) == 2:
            paths[parts[0]] = parts[1]
    if not paths:
        return []
    # Batch metadata has no credential contents. Read blob contents one at a
    # time through a private pipe, bounding memory and avoiding per-object spawns.
    metadata = subprocess.run(
        ["git", "-C", str(repo), "cat-file", "--batch-check"],
        input="".join(f"{oid}\n" for oid in paths).encode(),
        check=True, capture_output=True,
    ).stdout.decode().splitlines()
    blobs = [
        fields[0]
        for entry in metadata
        if len(fields := entry.split()) == 3
        and fields[1] == "blob" and int(fields[2]) <= MAX_FILE_BYTES
    ]
    findings: set[Finding] = set()
    with subprocess.Popen(
        ["git", "-C", str(repo), "cat-file", "--batch"],
        stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
    ) as reader:
        assert reader.stdin is not None and reader.stdout is not None
        for oid in blobs:
            reader.stdin.write(f"{oid}\n".encode())
            reader.stdin.flush()
            header = reader.stdout.readline().split()
            if len(header) != 3 or header[1] != b"blob":
                raise ValueError("invalid Git object header")
            content = reader.stdout.read(int(header[2])).decode("utf-8", errors="replace")
            if reader.stdout.read(1) != b"\n":
                raise ValueError("invalid Git object delimiter")
            findings.update(scan_text(content, f"{repo.name}/{paths[oid]}", "history"))
        reader.stdin.close()
        if reader.wait() != 0:
            raise ValueError("Git object scan failed")
    return sorted(findings)


def default_repositories() -> list[Path]:
    customer = Path(__file__).resolve().parents[1]
    return [
        path for path in (customer, customer.parent / "keep_sims_admin", customer.parent / "backend-sync-wt")
        if (path / ".git").exists()
    ]


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", type=Path, action="append", help="Scan this Git repository; repeat for more.")
    parser.add_argument("--include-generated", action="store_true", help="Inventory ignored build/cache roots too.")
    parser.add_argument("--include-history", action="store_true", help="Inventory all reachable Git blobs; can be slow.")
    parser.add_argument("--fail-on-inventory", action="store_true", help="Also fail on archive/history/generated findings.")
    args = parser.parse_args(argv)
    findings: set[Finding] = set()
    skipped_large = 0
    skipped_binary = 0
    repositories = args.repo or default_repositories()
    if not repositories:
        print("ERROR no Git repositories selected", file=sys.stderr)
        return 2
    for repo in repositories:
        try:
            current, skipped, binary = scan_repository(repo.resolve(), args.include_generated)
            findings.update(current)
            skipped_large += skipped
            skipped_binary += binary
            if args.include_history:
                findings.update(scan_history(repo.resolve()))
        except (OSError, subprocess.CalledProcessError, ValueError):
            # Exceptions may include captured tool content; print a fixed message.
            print("ERROR repository scan could not complete", file=sys.stderr)
            return 2
    for finding in sorted(findings):
        print(f"{finding.category.upper()} {finding.path}:{finding.line}:{finding.rule}")
    active = sum(f.category == "active" for f in findings)
    inventory = len(findings) - active
    print(f"Scanned {len(repositories)} repositories; active findings={active}; inventory findings={inventory}; working-tree oversized files skipped={skipped_large}; active binary files skipped={skipped_binary}")
    return 1 if active or (args.fail_on_inventory and inventory) else 0


if __name__ == "__main__":
    raise SystemExit(main())
