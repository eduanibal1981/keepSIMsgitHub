#!/usr/bin/env python3
"""Verified Google Drive migration between two personal Gmail accounts.

The program is deliberately a dry run unless --execute is supplied.  It supports:

* staged: download each owned file to a temporary local directory, upload it as
  Account B, verify it, then trash/delete the source in Account A.
* ownership: transfer ownership in place, verify Account B is the owner, then
  revoke Account A's access only after every requested item transferred.

OAuth tokens, progress state, and reports are kept under --state-dir.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import mimetypes
import os
import re
import sys
import tempfile
import time
import zipfile
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable
from xml.etree import ElementTree


SCOPES = ["https://www.googleapis.com/auth/drive"]
FOLDER_MIME = "application/vnd.google-apps.folder"
SHORTCUT_MIME = "application/vnd.google-apps.shortcut"
GOOGLE_PREFIX = "application/vnd.google-apps."

# Google-native formats that can make a useful editable round trip.
EXPORTS: dict[str, tuple[str, str, str]] = {
    "application/vnd.google-apps.document": (
        "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
        ".docx",
        "application/vnd.google-apps.document",
    ),
    "application/vnd.google-apps.spreadsheet": (
        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        ".xlsx",
        "application/vnd.google-apps.spreadsheet",
    ),
    "application/vnd.google-apps.presentation": (
        "application/vnd.openxmlformats-officedocument.presentationml.presentation",
        ".pptx",
        "application/vnd.google-apps.presentation",
    ),
}


@dataclass(frozen=True)
class DriveItem:
    id: str
    name: str
    mime_type: str
    parents: tuple[str, ...]
    size: int | None = None
    md5: str | None = None

    @property
    def is_folder(self) -> bool:
        return self.mime_type == FOLDER_MIME

    @property
    def is_google_native(self) -> bool:
        return self.mime_type.startswith(GOOGLE_PREFIX) and not self.is_folder


class MigrationError(RuntimeError):
    pass


class JsonlState:
    """Append-only progress journal, safe to reuse after interruption."""

    def __init__(self, path: Path) -> None:
        self.path = path
        self.latest: dict[str, dict[str, Any]] = {}
        if path.exists():
            for line in path.read_text(encoding="utf-8").splitlines():
                if not line.strip():
                    continue
                record = json.loads(line)
                self.latest[record["source_id"]] = record

    def record(self, source_id: str, status: str, **details: Any) -> None:
        record = {
            "at": datetime.now(timezone.utc).isoformat(),
            "source_id": source_id,
            "status": status,
            **details,
        }
        self.path.parent.mkdir(parents=True, exist_ok=True)
        with self.path.open("a", encoding="utf-8") as handle:
            handle.write(json.dumps(record, ensure_ascii=False) + "\n")
            handle.flush()
            os.fsync(handle.fileno())
        self.latest[source_id] = record


def sanitize_filename(name: str) -> str:
    cleaned = re.sub(r'[<>:"/\\|?*\x00-\x1f]', "_", name).strip(" .")
    return cleaned or "unnamed"


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def office_content_fingerprint(path: Path) -> str:
    """Fingerprint visible OOXML text, formula/value XML, and embedded media.

    Google may rewrite package metadata during a native import/export round trip,
    so hashing the complete ZIP would produce false failures.  This intentionally
    ignores package metadata while retaining document text/data and media hashes.
    """
    digest = hashlib.sha256()
    with zipfile.ZipFile(path) as archive:
        relevant = []
        for name in archive.namelist():
            lower = name.lower()
            if lower.startswith(("word/", "xl/", "ppt/")) and (
                lower.endswith(".xml") or "/media/" in lower
            ):
                if lower.startswith(("word/theme/", "xl/theme/", "ppt/theme/")):
                    continue
                relevant.append(name)
        for name in sorted(relevant):
            data = archive.read(name)
            lower = name.lower()
            digest.update(lower.encode("utf-8"))
            if "/media/" in lower:
                digest.update(hashlib.sha256(data).digest())
                continue
            try:
                root = ElementTree.fromstring(data)
                text = " ".join(part.strip() for part in root.itertext() if part.strip())
                digest.update(text.encode("utf-8"))
            except ElementTree.ParseError:
                digest.update(data)
    return digest.hexdigest()


def item_depth(item: DriveItem, by_id: dict[str, DriveItem], cache: dict[str, int]) -> int:
    if item.id in cache:
        return cache[item.id]
    owned_parents = [by_id[parent] for parent in item.parents if parent in by_id]
    if not owned_parents:
        cache[item.id] = 0
    else:
        cache[item.id] = 1 + max(item_depth(parent, by_id, cache) for parent in owned_parents)
    return cache[item.id]


def migration_order(items: Iterable[DriveItem], mode: str) -> list[DriveItem]:
    all_items = list(items)
    by_id = {item.id: item for item in all_items}
    cache: dict[str, int] = {}
    if mode == "ownership":
        files = [item for item in all_items if not item.is_folder]
        folders = sorted(
            (item for item in all_items if item.is_folder),
            key=lambda item: item_depth(item, by_id, cache),
            reverse=True,
        )
        return files + folders
    folders = sorted(
        (item for item in all_items if item.is_folder),
        key=lambda item: item_depth(item, by_id, cache),
    )
    files = [item for item in all_items if not item.is_folder]
    return folders + files


def _google_imports() -> tuple[Any, Any, Any, Any]:
    try:
        from google.auth.transport.requests import Request
        from google.oauth2.credentials import Credentials
        from google_auth_oauthlib.flow import InstalledAppFlow
        from googleapiclient.discovery import build
        return Request, Credentials, InstalledAppFlow, build
    except ImportError as exc:
        raise MigrationError(
            "Google client libraries are missing. Run: pip install -r requirements.txt"
        ) from exc


def authenticate(credentials_path: Path, token_path: Path, expected_email: str, label: str) -> Any:
    Request, Credentials, InstalledAppFlow, build = _google_imports()
    credentials = None
    if token_path.exists():
        credentials = Credentials.from_authorized_user_file(str(token_path), SCOPES)
    if credentials and credentials.expired and credentials.refresh_token:
        credentials.refresh(Request())
    if not credentials or not credentials.valid:
        print(f"Authorize {label} ({expected_email}) using the link below.", flush=True)
        flow = InstalledAppFlow.from_client_secrets_file(str(credentials_path), SCOPES)
        credentials = flow.run_local_server(
            port=0,
            open_browser=False,
            authorization_prompt_message="AUTHORIZATION_URL: {url}",
            success_message="Authorization received. You can close this browser tab.",
        )
    token_path.parent.mkdir(parents=True, exist_ok=True)
    token_path.write_text(credentials.to_json(), encoding="utf-8")
    service = build("drive", "v3", credentials=credentials, cache_discovery=False)
    actual = service.about().get(fields="user(emailAddress,displayName),storageQuota").execute()
    actual_email = actual.get("user", {}).get("emailAddress", "").lower()
    if actual_email != expected_email.lower():
        token_path.unlink(missing_ok=True)
        raise MigrationError(
            f"Wrong account authorized for {label}: expected {expected_email}, got {actual_email}. "
            "The token was removed; run again and choose the correct account."
        )
    return service


def list_owned_items(service: Any) -> list[DriveItem]:
    items: list[DriveItem] = []
    token = None
    while True:
        response = service.files().list(
            q="'me' in owners and trashed = false",
            spaces="drive",
            corpora="user",
            pageSize=1000,
            pageToken=token,
            fields="nextPageToken,files(id,name,mimeType,parents,size,md5Checksum)",
        ).execute()
        for raw in response.get("files", []):
            items.append(
                DriveItem(
                    id=raw["id"],
                    name=raw["name"],
                    mime_type=raw["mimeType"],
                    parents=tuple(raw.get("parents", [])),
                    size=int(raw["size"]) if raw.get("size") else None,
                    md5=raw.get("md5Checksum"),
                )
            )
        token = response.get("nextPageToken")
        if not token:
            return items


def get_root_id(service: Any) -> str:
    return service.files().get(fileId="root", fields="id").execute()["id"]


def create_folder(service: Any, name: str, parent_id: str) -> str:
    return service.files().create(
        body={"name": name, "mimeType": FOLDER_MIME, "parents": [parent_id]},
        fields="id",
    ).execute()["id"]


def resolve_destination_parent(
    item: DriveItem,
    folder_map: dict[str, str],
    destination_root: str,
) -> str:
    for parent in item.parents:
        if parent in folder_map:
            return folder_map[parent]
    return destination_root


def download_binary(service: Any, file_id: str, path: Path) -> None:
    try:
        from googleapiclient.http import MediaIoBaseDownload
    except ImportError as exc:
        raise MigrationError("Google client libraries are missing") from exc
    request = service.files().get_media(fileId=file_id)
    with path.open("wb") as handle:
        downloader = MediaIoBaseDownload(handle, request, chunksize=8 * 1024 * 1024)
        done = False
        while not done:
            _, done = downloader.next_chunk()


def export_native(service: Any, file_id: str, export_mime: str, path: Path) -> None:
    data = service.files().export_media(fileId=file_id, mimeType=export_mime).execute()
    path.write_bytes(data)


def upload_file(
    service: Any,
    path: Path,
    name: str,
    parent_id: str,
    source_mime: str,
    target_mime: str | None,
) -> dict[str, Any]:
    try:
        from googleapiclient.http import MediaFileUpload
    except ImportError as exc:
        raise MigrationError("Google client libraries are missing") from exc
    body: dict[str, Any] = {"name": name, "parents": [parent_id]}
    if target_mime:
        body["mimeType"] = target_mime
    media_mime = mimetypes.guess_type(path.name)[0] or source_mime
    media = MediaFileUpload(str(path), mimetype=media_mime, resumable=True)
    return service.files().create(
        body=body,
        media_body=media,
        fields="id,name,mimeType,size,md5Checksum,parents,owners(emailAddress)",
    ).execute()


def download_destination_for_verification(
    service: Any, destination_id: str, export_mime: str | None, path: Path
) -> None:
    if export_mime:
        export_native(service, destination_id, export_mime, path)
    else:
        download_binary(service, destination_id, path)


def verify_staged_copy(
    destination_service: Any,
    source_path: Path,
    destination_id: str,
    export_mime: str | None,
    native: bool,
    verify_path: Path,
) -> tuple[bool, str]:
    download_destination_for_verification(
        destination_service, destination_id, export_mime, verify_path
    )
    if native:
        source_fingerprint = office_content_fingerprint(source_path)
        destination_fingerprint = office_content_fingerprint(verify_path)
        return (
            source_fingerprint == destination_fingerprint,
            f"OOXML content fingerprint {source_fingerprint}",
        )
    source_hash = sha256_file(source_path)
    destination_hash = sha256_file(verify_path)
    return source_hash == destination_hash, f"SHA-256 {source_hash}"


def remove_local_staging(*paths: Path) -> None:
    """Remove downloaded copies before allowing source-side cleanup."""
    for path in paths:
        for attempt in range(6):
            try:
                path.unlink(missing_ok=True)
                break
            except PermissionError:
                if attempt == 5:
                    raise
                time.sleep(1)
    leftovers = [str(path) for path in paths if path.exists()]
    if leftovers:
        raise MigrationError(f"Could not remove local staging files: {leftovers}")


def clean_source_item(service: Any, file_id: str, cleanup: str) -> None:
    if cleanup == "trash":
        service.files().update(fileId=file_id, body={"trashed": True}).execute()
    elif cleanup == "delete":
        service.files().delete(fileId=file_id).execute()


def folder_is_empty(service: Any, folder_id: str) -> bool:
    response = service.files().list(
        q=f"'{folder_id}' in parents and trashed = false",
        spaces="drive",
        pageSize=1,
        fields="files(id)",
    ).execute()
    return not response.get("files")


def run_staged(
    source: Any,
    destination: Any,
    items: list[DriveItem],
    destination_root: str,
    state: JsonlState,
    cleanup: str,
    flat: bool = False,
) -> tuple[int, int]:
    folder_map: dict[str, str] = {}
    completed = 0
    failures = 0
    ordered = (
        [item for item in items if not item.is_folder]
        if flat
        else migration_order(items, "staged")
    )

    for item in ordered:
        prior = state.latest.get(item.id, {})
        if prior.get("status") in {"source_cleaned", "folder_cleaned"}:
            if item.is_folder and prior.get("destination_id"):
                folder_map[item.id] = prior["destination_id"]
            completed += 1
            continue
        parent_id = (
            destination_root
            if flat
            else resolve_destination_parent(item, folder_map, destination_root)
        )
        destination_id = prior.get("destination_id")
        try:
            if item.is_folder:
                destination_id = destination_id or create_folder(
                    destination, item.name, parent_id
                )
                folder_map[item.id] = destination_id
                state.record(item.id, "folder_created", destination_id=destination_id)
                continue
            if item.mime_type == SHORTCUT_MIME:
                state.record(item.id, "unsupported", reason="Drive shortcut")
                failures += 1
                continue
            if item.is_google_native and item.mime_type not in EXPORTS:
                state.record(
                    item.id,
                    "unsupported",
                    reason=f"No loss-aware local round trip for {item.mime_type}",
                )
                failures += 1
                continue

            export_mime: str | None = None
            target_mime: str | None = None
            suffix = Path(item.name).suffix
            if item.mime_type in EXPORTS:
                export_mime, suffix, target_mime = EXPORTS[item.mime_type]

            with tempfile.TemporaryDirectory(prefix="drive-migrate-") as temp_name:
                temp_dir = Path(temp_name)
                source_path = temp_dir / (sanitize_filename(item.name) + suffix)
                verify_path = temp_dir / ("verify-" + sanitize_filename(item.name) + suffix)
                if export_mime:
                    export_native(source, item.id, export_mime, source_path)
                else:
                    download_binary(source, item.id, source_path)
                if not destination_id:
                    uploaded = upload_file(
                        destination,
                        source_path,
                        item.name,
                        parent_id,
                        item.mime_type,
                        target_mime,
                    )
                    destination_id = uploaded["id"]
                    state.record(item.id, "uploaded", destination_id=destination_id)
                verified, evidence = verify_staged_copy(
                    destination,
                    source_path,
                    destination_id,
                    export_mime,
                    item.mime_type in EXPORTS,
                    verify_path,
                )
                if not verified:
                    state.record(
                        item.id,
                        "verification_failed",
                        destination_id=destination_id,
                        evidence=evidence,
                    )
                    failures += 1
                    continue
                state.record(
                    item.id, "verified", destination_id=destination_id, evidence=evidence
                )
                remove_local_staging(source_path, verify_path)
                clean_source_item(source, item.id, cleanup)
                state.record(
                    item.id,
                    "source_cleaned",
                    destination_id=destination_id,
                    cleanup=cleanup,
                    evidence=evidence,
                )
                completed += 1
        except Exception as exc:  # API errors must be journaled for a resumable run.
            details = {"error": str(exc)}
            if destination_id:
                details["destination_id"] = destination_id
            state.record(item.id, "failed", **details)
            failures += 1
            print(f"FAILED: {item.name}: {exc}", file=sys.stderr)

    # Remove only source folders that are empty after all files have been handled.
    folders = [item for item in items if item.is_folder]
    by_id = {item.id: item for item in items}
    cache: dict[str, int] = {}
    for folder in sorted(folders, key=lambda x: item_depth(x, by_id, cache), reverse=True):
        record = state.latest.get(folder.id, {})
        destination_id = folder_map.get(folder.id) or record.get("destination_id")
        if record.get("status") == "folder_cleaned":
            continue
        try:
            if (destination_id or flat) and folder_is_empty(source, folder.id):
                clean_source_item(source, folder.id, cleanup)
                state.record(
                    folder.id,
                    "folder_cleaned",
                    destination_id=destination_id or destination_root,
                    cleanup=cleanup,
                )
                completed += 1
            elif destination_id:
                state.record(
                    folder.id,
                    "folder_retained",
                    destination_id=destination_id,
                    reason="Source folder still contains untransferred or externally owned items",
                )
        except Exception as exc:
            state.record(folder.id, "folder_cleanup_failed", error=str(exc))
            failures += 1
    return completed, failures


def list_permissions(service: Any, file_id: str) -> list[dict[str, Any]]:
    return service.permissions().list(
        fileId=file_id,
        fields="permissions(id,emailAddress,role,pendingOwner,permissionDetails)",
    ).execute().get("permissions", [])


def permission_is_inherited(permission: dict[str, Any]) -> bool:
    return any(
        detail.get("inherited", False)
        for detail in permission.get("permissionDetails", [])
    )


def find_permission(
    service: Any, file_id: str, email: str, direct_only: bool = False
) -> dict[str, Any] | None:
    email = email.lower()
    matches = [
        permission
        for permission in list_permissions(service, file_id)
        if permission.get("emailAddress", "").lower() == email
    ]
    direct = next(
        (permission for permission in matches if not permission_is_inherited(permission)),
        None,
    )
    return direct if direct_only else (direct or (matches[0] if matches else None))


def initiate_ownership(source: Any, file_id: str, destination_email: str) -> str:
    existing = find_permission(source, file_id, destination_email, direct_only=True)
    body = {"role": "writer", "pendingOwner": True}
    if existing:
        result = source.permissions().update(
            fileId=file_id,
            permissionId=existing["id"],
            body=body,
            fields="id,pendingOwner,role",
        ).execute()
    else:
        result = source.permissions().create(
            fileId=file_id,
            body={**body, "type": "user", "emailAddress": destination_email},
            sendNotificationEmail=True,
            fields="id,pendingOwner,role",
        ).execute()
    return result["id"]


def accept_ownership(destination: Any, file_id: str, permission_id: str) -> None:
    destination.permissions().update(
        fileId=file_id,
        permissionId=permission_id,
        body={"role": "owner"},
        transferOwnership=True,
        fields="id,role",
    ).execute()


def is_owner(service: Any, file_id: str, email: str) -> bool:
    response = service.files().get(
        fileId=file_id, fields="id,trashed,owners(emailAddress)"
    ).execute()
    return any(
        owner.get("emailAddress", "").lower() == email.lower()
        for owner in response.get("owners", [])
    )


def revoke_account_access(destination: Any, file_id: str, source_email: str) -> bool:
    direct_permissions = [
        permission
        for permission in list_permissions(destination, file_id)
        if permission.get("emailAddress", "").lower() == source_email.lower()
        and not permission_is_inherited(permission)
    ]
    for permission in direct_permissions:
        destination.permissions().delete(
            fileId=file_id, permissionId=permission["id"]
        ).execute()
    return find_permission(destination, file_id, source_email) is None


def run_ownership(
    source: Any,
    destination: Any,
    items: list[DriveItem],
    source_email: str,
    destination_email: str,
    state: JsonlState,
    keep_source_access: bool,
) -> tuple[int, int]:
    failures = 0
    blocking_failures = 0
    transferred: list[DriveItem] = []
    for item in migration_order(items, "ownership"):
        if item.mime_type in {SHORTCUT_MIME, "application/vnd.google-apps.site"}:
            state.record(item.id, "unsupported", reason=item.mime_type)
            failures += 1
            continue
        prior = state.latest.get(item.id, {})
        try:
            try:
                if is_owner(destination, item.id, destination_email):
                    state.record(item.id, "ownership_verified", destination_id=item.id)
                    transferred.append(item)
                    continue
            except Exception:
                # Account B normally cannot read an item before Account A shares it.
                pass
            permission_id = initiate_ownership(source, item.id, destination_email)
            state.record(item.id, "ownership_pending", permission_id=permission_id)
            accept_ownership(destination, item.id, permission_id)
            if not is_owner(destination, item.id, destination_email):
                raise MigrationError("Destination ownership did not verify")
            state.record(item.id, "ownership_verified", destination_id=item.id)
            transferred.append(item)
        except Exception as exc:
            state.record(item.id, "failed", error=str(exc))
            failures += 1
            blocking_failures += 1
            print(f"FAILED: {item.name}: {exc}", file=sys.stderr)

    # Avoid partially locking Account A out of a migration that needs to resume.
    if blocking_failures or keep_source_access:
        return len(transferred), failures

    revoke_failures = 0
    by_id = {item.id: item for item in items}
    depth_cache: dict[str, int] = {}
    for item in sorted(
        transferred, key=lambda value: item_depth(value, by_id, depth_cache)
    ):
        try:
            if not is_owner(destination, item.id, destination_email):
                raise MigrationError("Ownership changed before access cleanup")
            if not revoke_account_access(destination, item.id, source_email):
                raise MigrationError("Source permission still present after revoke")
            state.record(item.id, "source_access_revoked", destination_id=item.id)
        except Exception as exc:
            state.record(item.id, "access_revoke_failed", error=str(exc))
            revoke_failures += 1
    return len(transferred), failures + revoke_failures


def write_inventory(path: Path, items: list[DriveItem]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    payload = [asdict(item) for item in items]
    path.write_text(json.dumps(payload, indent=2, ensure_ascii=False), encoding="utf-8")


def load_inventory(path: Path) -> list[DriveItem]:
    if not path.exists():
        return []
    return [
        DriveItem(
            id=raw["id"],
            name=raw["name"],
            mime_type=raw["mime_type"],
            parents=tuple(raw.get("parents", [])),
            size=raw.get("size"),
            md5=raw.get("md5"),
        )
        for raw in json.loads(path.read_text(encoding="utf-8"))
    ]


def bind_state_directory(
    path: Path,
    source_email: str,
    destination_email: str,
    mode: str,
    flat: bool = False,
) -> None:
    """Prevent accidental reuse of progress data with a different account pair."""
    manifest_path = path / "migration.json"
    expected = {
        "source_email": source_email.lower(),
        "destination_email": destination_email.lower(),
        "mode": mode,
    }
    if mode == "staged":
        expected["layout"] = "flat" if flat else "tree"
    if manifest_path.exists():
        actual = json.loads(manifest_path.read_text(encoding="utf-8"))
        if actual != expected:
            raise MigrationError(
                f"State directory belongs to {actual.get('source_email')} -> "
                f"{actual.get('destination_email')}. Choose a different --state-dir."
            )
    else:
        manifest_path.write_text(json.dumps(expected, indent=2), encoding="utf-8")


def quota_summary(service: Any) -> dict[str, int | None]:
    quota = service.about().get(fields="storageQuota").execute().get("storageQuota", {})
    return {
        "limit": int(quota["limit"]) if quota.get("limit") else None,
        "usage": int(quota["usage"]) if quota.get("usage") else None,
    }


def print_plan(items: list[DriveItem], mode: str, quota: dict[str, int | None]) -> None:
    folders = sum(item.is_folder for item in items)
    native = sum(item.is_google_native and item.mime_type in EXPORTS for item in items)
    unsupported = sum(
        item.mime_type == SHORTCUT_MIME
        or (item.is_google_native and item.mime_type not in EXPORTS)
        for item in items
    )
    bytes_to_move = sum(item.size or 0 for item in items if not item.is_folder)
    print(f"Mode: {mode}")
    print(f"Owned items: {len(items)} ({folders} folders)")
    print(f"Google Docs/Sheets/Slides: {native}")
    print(f"Known unsupported special items: {unsupported}")
    print(f"Stored-file bytes reported by Drive: {bytes_to_move:,}")
    if quota["limit"] is not None and quota["usage"] is not None:
        available = quota["limit"] - quota["usage"]
        print(f"Destination bytes available: {available:,}")
        if bytes_to_move > available:
            print("WARNING: reported stored-file bytes exceed destination free space.")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-email", required=True, help="Personal Gmail Account A")
    parser.add_argument("--destination-email", required=True, help="Personal Gmail Account B")
    parser.add_argument(
        "--mode", choices=("staged", "ownership"), default="ownership",
        help="ownership preserves links/history; staged performs local download/upload",
    )
    parser.add_argument(
        "--credentials", type=Path, default=Path("credentials.json"),
        help="OAuth Desktop client JSON from Google Cloud",
    )
    parser.add_argument("--state-dir", type=Path, default=Path(".state"))
    parser.add_argument(
        "--destination-folder-id",
        help="Staged mode: existing Account B folder ID; otherwise a migration folder is created",
    )
    parser.add_argument(
        "--source-cleanup", choices=("trash", "delete"), default="trash",
        help="Staged mode cleanup after verification (default: recoverable Trash)",
    )
    parser.add_argument(
        "--flat", action="store_true",
        help="Staged mode: put all files directly in one destination folder",
    )
    parser.add_argument(
        "--confirm-permanent-delete",
        help="Required phrase DELETE-SOURCE-PERMANENTLY when cleanup=delete",
    )
    parser.add_argument(
        "--keep-source-access", action="store_true",
        help="Ownership mode: leave Account A as an editor after transfer",
    )
    parser.add_argument(
        "--execute", action="store_true",
        help="Perform the migration; omission creates inventory and prints a dry-run plan",
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    if args.source_email.lower() == args.destination_email.lower():
        raise MigrationError("Source and destination accounts must differ")
    if not args.credentials.exists():
        raise MigrationError(f"OAuth credentials file not found: {args.credentials}")
    if (
        args.mode == "staged"
        and args.source_cleanup == "delete"
        and args.confirm_permanent_delete != "DELETE-SOURCE-PERMANENTLY"
    ):
        raise MigrationError(
            "Permanent deletion requires --confirm-permanent-delete DELETE-SOURCE-PERMANENTLY"
        )

    args.state_dir.mkdir(parents=True, exist_ok=True)
    bind_state_directory(
        args.state_dir,
        args.source_email,
        args.destination_email,
        args.mode,
        args.flat,
    )
    source = authenticate(
        args.credentials,
        args.state_dir / "token_source.json",
        args.source_email,
        "Account A",
    )
    destination = authenticate(
        args.credentials,
        args.state_dir / "token_destination.json",
        args.destination_email,
        "Account B",
    )
    current_items = list_owned_items(source)
    inventory_path = args.state_dir / "inventory.json"
    # Ownership transfers remove items from Account A's listing. Preserve the
    # original entries so a resumed run can still verify and revoke access.
    if args.mode == "ownership":
        # Ownership transfers remove completed items from Account A's listing;
        # retain the prior inventory so a resumed run can still verify them.
        merged_items = {item.id: item for item in load_inventory(inventory_path)}
        merged_items.update({item.id: item for item in current_items})
        items = list(merged_items.values())
    else:
        # For staged migration, a fresh listing excludes files that were already
        # trashed and avoids retrying stale IDs that no longer exist in Drive.
        items = current_items
    write_inventory(inventory_path, items)
    print_plan(items, args.mode, quota_summary(destination))
    print(f"Inventory: {inventory_path.resolve()}")

    if not args.execute:
        print("Dry run only. Review the inventory, then add --execute when ready.")
        return 0

    state = JsonlState(args.state_dir / f"progress-{args.mode}.jsonl")
    if args.mode == "staged":
        if args.destination_folder_id:
            destination_root = args.destination_folder_id
            destination_metadata = destination.files().get(
                fileId=destination_root, fields="id,mimeType"
            ).execute()
            if destination_metadata.get("mimeType") != FOLDER_MIME:
                raise MigrationError("--destination-folder-id does not identify a folder")
        else:
            root_record = state.latest.get("__migration_root__", {})
            destination_root = root_record.get("destination_id")
            if not destination_root:
                destination_root = create_folder(
                    destination,
                    f"Drive migration from {args.source_email} {datetime.now():%Y-%m-%d}",
                    get_root_id(destination),
                )
                state.record(
                    "__migration_root__",
                    "destination_root_created",
                    destination_id=destination_root,
                )
        completed, failures = run_staged(
            source,
            destination,
            items,
            destination_root,
            state,
            args.source_cleanup,
            args.flat,
        )
    else:
        completed, failures = run_ownership(
            source,
            destination,
            items,
            args.source_email,
            args.destination_email,
            state,
            args.keep_source_access,
        )

    print(f"Completed/verified: {completed}; failures requiring review: {failures}")
    print(f"Progress journal: {state.path.resolve()}")
    return 2 if failures else 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except MigrationError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        raise SystemExit(1)
