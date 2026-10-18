"""Regression tests use synthetic credentials assembled without tracked literals."""

from contextlib import redirect_stdout, redirect_stderr
import importlib.util
import io
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


MODULE_PATH = Path(__file__).with_name("scan_embedded_secrets.py")
SPEC = importlib.util.spec_from_file_location("scan_embedded_secrets", MODULE_PATH)
scanner = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = scanner
SPEC.loader.exec_module(scanner)


class SecretScanTests(unittest.TestCase):
    def rules(self, source):
        return {f.rule for f in scanner.scan_text(source, "file.ts")}

    def test_provider_shapes_are_detected_without_assignments(self):
        for credential, rule in (
            ("sbp_" + "a1" * 20, "supabase-management-pat"),
            ("KEY" + "b2" * 20, "telnyx-api-key"),
            ("csk_" + "c3" * 20, "firsty-client-secret"),
            ("keepsims_turn_" + "secret_" + "sample", "predictable-turn-secret"),
        ):
            with self.subTest(rule=rule):
                self.assertIn(rule, self.rules(credential))

    def test_environment_and_config_fallbacks_are_detected(self):
        value = "opaque" + "0a" * 20
        for source in (
            f'const token = Deno.env.get("ZENDIT_API_SECRET") || "{value}";',
            f'const token = Deno.env.get("TURN_SHARED_SECRET") || Deno.env.get("COTURN_SHARED_SECRET") || "{value}";',
            f'const token = await fetchConfig(supabase, "TWILIO_AUTH_TOKEN", "{value}");',
            f'const token = Deno.env.get("FIRSTY_CLIENT_SECRET") ?? "{value}";',
        ):
            with self.subTest(source=source[:35]):
                self.assertIn("embedded-secret-fallback", self.rules(source))

    def test_dart_token_and_paypal_json_are_detected(self):
        value = "a1" * 16
        for source in (
            f"static const String _authToken = '{value}';",
            f'"PAYPAL_ACCESS_TOKEN": "{value}",',
            f'"PAYPAL_CLIENT_SECRET": "{value}",',
            f'const DEFAULT_CLIENT_SECRET = "{value}";',
            'credential: "password",',
        ):
            with self.subTest(source=source[:30]):
                self.assertIn("embedded-secret-assignment", self.rules(source))

    def test_placeholders_public_keys_and_secret_reads_are_allowed(self):
        source = '''
"PAYPAL_ACCESS_TOKEN": "${PAYPAL_ACCESS_TOKEN}",
"PAYPAL_CLIENT_SECRET": "YOUR_PAYPAL_CLIENT_SECRET",
"API_KEY": "<insert key in user storage>",
"TWILIO_AUTH_TOKEN": "fake-token",
const anonKey = "public-client-key";
const TELNYX_PUBLIC_KEY = "public-verification-key";
const secret = Deno.env.get("FIRSTY_CLIENT_SECRET");
const emptySecret = "";
'''
        self.assertEqual(scanner.scan_text(source, "example.json"), [])

    def test_catalog_hash_metadata_is_structural_and_credentials_still_fail(self):
        import json
        path = 'supabase/tests/fixtures/admin_maintenance_baseline.json'
        digest = 'a1' * 32
        self.assertEqual(scanner.scan_text(json.dumps({'functions': {'get_internal_secret': digest}}), path), [])
        self.assertTrue(scanner.scan_text(json.dumps({'PAYPAL_CLIENT_SECRET': digest}), path))
        provider = 'KEY' + 'a' * 30
        self.assertTrue(scanner.scan_text(json.dumps({'functions': {'get_internal_secret': provider}}), path))

    def test_real_private_key_material_required(self):
        begin = "-----BEGIN " + "PRIVATE KEY-----"
        end = "-----END " + "PRIVATE KEY-----"
        self.assertIn("private-key-material", self.rules(begin + "\n" + "QWJj" * 15 + "\n" + end))
        self.assertEqual(self.rules('text.replace("' + begin + '", "")'), set())

    def test_synthetic_fixtures_do_not_hide_provider_tokens_or_metadata(self):
        value = "sbp_" + "a7" * 20
        findings = scanner.scan_text(value, "test/fixture_test.dart")
        self.assertTrue(any(f.rule == "supabase-management-pat" for f in findings))
        source = '''
credential_key: 'FIRSTY_CLIENT_SECRET',
credential_status: 'configured',
app_secret_vault_id: 'metadata-identifier',
forgotPassword: '/forgot-password',
'''
        self.assertEqual(scanner.scan_text(source, "model.dart"), [])

    def test_output_contains_locations_never_secret_values(self):
        value = "sbp_" + "d4" * 20
        with tempfile.TemporaryDirectory() as directory:
            repo = Path(directory)
            subprocess.run(["git", "init", "-q", str(repo)], check=True)
            (repo / "active.json").write_text('{"token": "' + value + '"}')
            output = io.StringIO()
            with redirect_stdout(output):
                status = scanner.main(["--repo", str(repo)])
            self.assertEqual(status, 1)
            self.assertIn("active.json:1:supabase-management-pat", output.getvalue())
            self.assertNotIn(value, output.getvalue())

    def test_archive_and_generated_inventory_is_separate(self):
        value = "sbp_" + "e5" * 20
        with tempfile.TemporaryDirectory() as directory:
            repo = Path(directory)
            subprocess.run(["git", "init", "-q", str(repo)], check=True)
            archive = repo / "supabase/migration_archive/old.sql"
            archive.parent.mkdir(parents=True)
            archive.write_text(value)
            build = repo / "build/app.bin"
            build.parent.mkdir()
            build.write_bytes(b"\x00" + value.encode())
            (repo / ".gitignore").write_text("build/\n.env\n")
            (repo / ".env").write_text(value)
            output = io.StringIO()
            with redirect_stdout(output):
                status = scanner.main(["--repo", str(repo), "--include-generated"])
            self.assertEqual(status, 0)
            self.assertIn("ARCHIVE", output.getvalue())
            self.assertIn("GENERATED", output.getvalue())
            self.assertNotIn("/.env:", output.getvalue())
            self.assertNotIn(value, output.getvalue())
            with redirect_stdout(io.StringIO()):
                self.assertEqual(scanner.main(["--repo", str(repo), "--fail-on-inventory"]), 1)

    def test_history_detects_removed_secret_without_printing_blob(self):
        value = "sbp_" + "f6" * 20
        with tempfile.TemporaryDirectory() as directory:
            repo = Path(directory)
            subprocess.run(["git", "init", "-q", str(repo)], check=True)
            file = repo / "old.txt"
            file.write_text(value)
            subprocess.run(["git", "-C", str(repo), "add", "old.txt"], check=True)
            subprocess.run(["git", "-C", str(repo), "-c", "user.name=Secret Scan Test", "-c", "user.email=test@example.invalid", "commit", "-qm", "Synthetic fixture"], check=True)
            file.write_text("removed")
            findings = scanner.scan_history(repo)
            self.assertTrue(any(f.category == "history" and f.rule == "supabase-management-pat" for f in findings))
            self.assertNotIn(value, repr(findings))

    def test_errors_are_fixed_and_redacted(self):
        output = io.StringIO()
        with tempfile.TemporaryDirectory() as directory, redirect_stderr(output):
            self.assertEqual(scanner.main(["--repo", directory]), 2)
        self.assertEqual(output.getvalue(), "ERROR repository scan could not complete\n")


if __name__ == "__main__":
    unittest.main()
