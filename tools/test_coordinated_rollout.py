import copy
import hashlib
from pathlib import Path
import tempfile
import unittest

from check_coordinated_rollout import check_pins


class RolloutPinSafetyTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.parent = Path(self.temporary.name)
        self.source = self.parent / 'keep_sims' / 'supabase' / 'example.sql'
        self.source.parent.mkdir(parents=True)
        self.source.write_text('SELECT 1;\n')
        self.manifest = {
            'project_id': 'zwxswagokhgbuzrrbnhr',
            'status': 'BLOCKED_PREPARATION_ONLY',
            'pins': [{'component': 'customer', 'path': 'supabase/example.sql',
                      'sha256': hashlib.sha256(self.source.read_bytes()).hexdigest()}],
        }

    def test_changed_or_deleted_source_cannot_keep_its_previous_pin(self):
        self.assertEqual(check_pins(self.manifest, self.parent), [])
        self.source.write_text('SELECT 2;\n')
        self.assertTrue(check_pins(self.manifest, self.parent))
        self.source.unlink()
        self.assertTrue(check_pins(self.manifest, self.parent))

    def test_symlink_cannot_redirect_a_valid_pin_outside_its_repository(self):
        external = self.parent / 'external.sql'
        external.write_bytes(self.source.read_bytes())
        self.source.unlink()
        self.source.symlink_to(external)
        self.assertTrue(check_pins(self.manifest, self.parent))

    def test_parent_symlink_cannot_redirect_a_valid_pin(self):
        external = self.parent / 'external'
        external.mkdir()
        (external / 'example.sql').write_bytes(self.source.read_bytes())
        self.source.unlink()
        self.source.parent.rmdir()
        self.source.parent.symlink_to(external)
        self.assertTrue(check_pins(self.manifest, self.parent))

    def test_path_traversal_absolute_path_and_unknown_component_are_rejected(self):
        for path in ('../external.sql', '/private/tmp/example.sql', r'..\external.sql'):
            with self.subTest(path=path):
                manifest = copy.deepcopy(self.manifest)
                manifest['pins'][0]['path'] = path
                self.assertIn('Unsafe pin path', check_pins(manifest, self.parent))
        self.manifest['pins'][0]['component'] = 'vm'
        self.assertIn('Unsafe pin path', check_pins(self.manifest, self.parent))

    def test_wrong_target_duplicate_and_empty_artifacts_are_rejected(self):
        manifest = copy.deepcopy(self.manifest)
        manifest['project_id'] = 'another-project'
        self.assertTrue(check_pins(manifest, self.parent))
        manifest = copy.deepcopy(self.manifest)
        manifest['pins'].append(manifest['pins'][0])
        self.assertTrue(check_pins(manifest, self.parent))
        self.manifest['pins'] = []
        self.assertIn('Missing pinned inputs', check_pins(self.manifest, self.parent))

    def test_editing_status_cannot_turn_preparation_into_approval(self):
        self.manifest['status'] = 'AUTHORIZED'
        self.assertTrue(check_pins(self.manifest, self.parent))


if __name__ == '__main__':
    unittest.main()
