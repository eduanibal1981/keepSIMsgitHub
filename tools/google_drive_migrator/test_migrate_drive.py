import unittest
import zipfile
from contextlib import nullcontext
from pathlib import Path
from unittest.mock import patch

from migrate_drive import (
    DriveItem,
    JsonlState,
    MigrationError,
    bind_state_directory,
    load_inventory,
    migration_order,
    office_content_fingerprint,
    remove_local_staging,
    run_staged,
    sanitize_filename,
    verify_staged_copy,
    write_inventory,
)


FOLDER = "application/vnd.google-apps.folder"


class MigrationHelpersTest(unittest.TestCase):
    def test_ownership_orders_files_before_deepest_folders(self):
        items = [
            DriveItem("root-folder", "Root", FOLDER, ("drive-root",)),
            DriveItem("child-folder", "Child", FOLDER, ("root-folder",)),
            DriveItem("file", "data.bin", "application/octet-stream", ("child-folder",)),
        ]
        ordered = migration_order(items, "ownership")
        self.assertEqual([item.id for item in ordered], ["file", "child-folder", "root-folder"])

    def test_staged_orders_parent_folders_first(self):
        items = [
            DriveItem("child", "Child", FOLDER, ("parent",)),
            DriveItem("parent", "Parent", FOLDER, ("drive-root",)),
            DriveItem("file", "data.bin", "application/octet-stream", ("child",)),
        ]
        ordered = migration_order(items, "staged")
        self.assertEqual([item.id for item in ordered], ["parent", "child", "file"])

    @patch("migrate_drive.clean_source_item")
    @patch("migrate_drive.folder_is_empty", return_value=False)
    @patch("migrate_drive.verify_staged_copy", return_value=(True, "SHA-256 ok"))
    @patch("migrate_drive.upload_file", return_value={"id": "destination-file"})
    @patch("migrate_drive.download_binary")
    @patch("migrate_drive.create_folder")
    def test_flat_staged_skips_folders_and_uses_one_parent(
        self, create_folder, _download, upload, _verify, _empty, cleanup
    ):
        path = Path(__file__).with_name(".test-flat-state.jsonl")
        temp_path = Path(__file__).with_name(".test-flat-temp")
        path.unlink(missing_ok=True)
        temp_path.mkdir(exist_ok=True)
        try:
            items = [
                DriveItem("folder", "Folder", FOLDER, ("drive-root",)),
                DriveItem("file", "data.bin", "application/octet-stream", ("folder",)),
            ]
            with patch(
                "migrate_drive.tempfile.TemporaryDirectory",
                return_value=nullcontext(str(temp_path)),
            ):
                completed, failures = run_staged(
                    None,
                    None,
                    items,
                    "one-destination-folder",
                    JsonlState(path),
                    "trash",
                    True,
                )
            create_folder.assert_not_called()
            self.assertEqual(upload.call_args.args[3], "one-destination-folder")
            cleanup.assert_any_call(None, "file", "trash")
            self.assertEqual((completed, failures), (1, 0))
        finally:
            path.unlink(missing_ok=True)
            temp_path.rmdir()

    def test_state_resumes_from_last_record(self):
        path = Path(__file__).with_name(".test-state.jsonl")
        path.unlink(missing_ok=True)
        try:
            state = JsonlState(path)
            state.record("one", "uploaded", destination_id="dest")
            state.record("one", "source_cleaned", destination_id="dest")
            loaded = JsonlState(path)
            self.assertEqual(loaded.latest["one"]["status"], "source_cleaned")
        finally:
            path.unlink(missing_ok=True)

    def test_office_fingerprint_ignores_package_metadata(self):
        first = Path(__file__).with_name(".test-first.docx")
        second = Path(__file__).with_name(".test-second.docx")
        first.unlink(missing_ok=True)
        second.unlink(missing_ok=True)
        try:
            for path, timestamp in ((first, "old"), (second, "new")):
                with zipfile.ZipFile(path, "w") as archive:
                    archive.writestr(
                        "word/document.xml",
                        '<w:doc xmlns:w="urn:w"><w:t>Hello world</w:t></w:doc>',
                    )
                    archive.writestr("docProps/core.xml", f"<created>{timestamp}</created>")
            self.assertEqual(
                office_content_fingerprint(first), office_content_fingerprint(second)
            )
        finally:
            first.unlink(missing_ok=True)
            second.unlink(missing_ok=True)

    def test_filename_is_safe_for_windows(self):
        self.assertEqual(sanitize_filename('report: Q1/2026?.pdf'), "report_ Q1_2026_.pdf")

    @patch("migrate_drive.download_destination_for_verification")
    def test_binary_verification_rejects_different_destination(self, download):
        source = Path(__file__).with_name(".test-source.bin")
        verify = Path(__file__).with_name(".test-verify.bin")
        source.write_bytes(b"source bytes")

        def write_destination(_service, _file_id, _export_mime, path):
            path.write_bytes(b"different bytes")

        download.side_effect = write_destination
        try:
            verified, evidence = verify_staged_copy(
                None, source, "destination", None, False, verify
            )
            self.assertFalse(verified)
            self.assertIn("SHA-256", evidence)
        finally:
            remove_local_staging(source, verify)

    def test_inventory_round_trip_keeps_tuple_parents(self):
        path = Path(__file__).with_name(".test-inventory.json")
        path.unlink(missing_ok=True)
        try:
            expected = [DriveItem("id", "Name", "text/plain", ("parent",), 4, "hash")]
            write_inventory(path, expected)
            self.assertEqual(load_inventory(path), expected)
        finally:
            path.unlink(missing_ok=True)

    def test_state_directory_is_bound_to_account_pair(self):
        directory = Path(__file__).parent
        manifest = directory / "migration.json"
        manifest.unlink(missing_ok=True)
        try:
            bind_state_directory(directory, "old@gmail.com", "new@gmail.com", "ownership")
            bind_state_directory(directory, "OLD@gmail.com", "NEW@gmail.com", "ownership")
            with self.assertRaises(MigrationError):
                bind_state_directory(
                    directory, "other@gmail.com", "new@gmail.com", "ownership"
                )
            with self.assertRaises(MigrationError):
                bind_state_directory(directory, "old@gmail.com", "new@gmail.com", "staged")
        finally:
            manifest.unlink(missing_ok=True)


if __name__ == "__main__":
    unittest.main()
