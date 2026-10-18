import copy
import io
import json
from pathlib import Path
import subprocess
import tarfile
import tempfile
import unittest
from unittest.mock import patch

import migration_archive
from recover_database_sources import argument_types, normalized_body, recover, OUTPUT, ROOT
from reproducible_sources import REPOS, bundle, checkout, verify, write_lock


class SQLRecoveryTests(unittest.TestCase):
    def test_normalization_preserves_literals(self):
        self.assertEqual(normalized_body('SELECT "foo" /* a /* nested */ z */ + 1;'), normalized_body('select foo+1;'))
        self.assertNotEqual(normalized_body("select 'A  B'"), normalized_body("select 'A B'"))
        self.assertNotEqual(normalized_body("select $q$A  B -- literal$q$"), normalized_body("select $q$a B -- literal$q$"))
        self.assertNotEqual(normalized_body('select "MiX"'), normalized_body('select mix'))

    def test_signature_defaults_and_types(self):
        self.assertEqual(argument_types('"p" "uuid", "x" numeric DEFAULT round(2, 1), "y" text DEFAULT \'a,b\') RETURNS void'), 'uuid, numeric, text')
        self.assertEqual(argument_types(') RETURNS trigger'), '')

    def test_recovered_signatures_and_live_hashes(self):
        import hashlib
        from recover_database_sources import dump_functions
        data = json.loads((OUTPUT/'public-routines.json').read_text())
        self.assertEqual(len(data['functions']), 17)
        self.assertTrue(all(x['exact_body_match'] for x in data['export_live_comparison']))
        for fn in data['functions']:
            parsed = dump_functions(fn['definition'])[0]
            self.assertEqual(argument_types(parsed['header']), fn['types'])
            self.assertEqual(hashlib.sha256(parsed['body'].encode()).hexdigest(), fn['source_sha256'])
            self.assertEqual(hashlib.sha256(normalized_body(parsed['body']).encode()).hexdigest(), fn['normalized_body_sha256'])

    def test_recovery_rejects_wrong_export_before_writing(self):
        with tempfile.TemporaryDirectory() as d:
            schema = Path(d)/'bad.sql'; schema.write_text('SELECT 1;')
            output = Path(d)/'output'
            with self.assertRaises(ValueError): recover(schema, output)
            self.assertFalse(output.exists())

    def test_immutable_archive_cannot_be_overridden(self):
        entry = copy.deepcopy(next(x for x in migration_archive.source_entries() if x['action']=='archived'))
        with tempfile.TemporaryDirectory() as d:
            manifest = Path(d)/'manifest.json'; revisions = Path(d)/'revisions.json'
            manifest.write_text(json.dumps({'migrations':[entry]}))
            revisions.write_text(json.dumps({'revisions':[{'file':entry['file']}]}))
            with patch.object(migration_archive,'MANIFEST',manifest), patch.object(migration_archive,'REVISIONS',revisions):
                with self.assertRaises(ValueError): migration_archive.source_entries()

    def test_required_archive_list_covers_literal_consumers(self):
        import re
        required=set(json.loads((ROOT/'deployment/required-migration-sources.json').read_text())['files'])
        archived={e['file'] for e in migration_archive.source_entries() if e['action']=='archived'}
        referenced=set()
        for directory in [ROOT/'tools',ROOT.parent/'backend-sync-wt/test']:
            for p in directory.rglob('*'):
                if not p.is_file() or p.suffix not in {'.js','.cjs','.mjs','.py'} or 'node_modules' in p.parts: continue
                referenced.update(re.findall(r'(?:migrationSource|migration_path)\([\'"]([^\'"]+\.sql)[\'"]',p.read_text()))
        self.assertFalse((referenced & archived)-required, 'Historical test dependency missing from source bundle')


class SourceSnapshotTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.parent = Path(self.temp.name)
        for component,directory in REPOS.items():
            repo = self.parent/directory; repo.mkdir()
            subprocess.run(['git','init','-q',str(repo)],check=True)
            subprocess.run(['git','-C',str(repo),'-c','user.name=Test','-c','user.email=test@example.invalid','commit','--allow-empty','-qm','fixture'],check=True)
            name = 'worker.js' if component=='backend' else 'lib/main.dart'
            file=repo/name; file.parent.mkdir(exist_ok=True); file.write_text('// isolated source\n')
            (repo/'.env').write_text('PRIVATE=never-package')
            if component=='customer':
                metadata=repo/'docs/reviews/migration-cleanup-20261016/manifest.json'
                metadata.parent.mkdir(parents=True);metadata.write_text('{"migrations":[]}')
                config=repo/'deployment/required-migration-sources.json';config.parent.mkdir()
                config.write_text('{"files":[]}')
        self.lock=write_lock(self.parent,self.parent/'lock.json')

    def test_dirty_source_round_trip_and_deterministic_bundle(self):
        a=self.parent/'a.tar'; b=self.parent/'b.tar'
        bundle(self.lock,self.parent,a); bundle(self.lock,self.parent,b)
        self.assertEqual(a.read_bytes(),b.read_bytes())
        output=self.parent/'checkout'; checkout(a,output)
        verify(self.lock,output,checkout=True)
        self.assertFalse((output/'keep_sims/.env').exists())
        self.assertTrue(self.lock['repositories']['backend']['dirty'])

    def test_modified_or_new_source_fails(self):
        (self.parent/'keep_sims/lib/main.dart').write_text('// changed')
        with self.assertRaises(ValueError): verify(self.lock,self.parent)
        (self.parent/'keep_sims/lib/main.dart').write_text('// isolated source\n')
        (self.parent/'keep_sims/lib/new.dart').write_text('// new')
        with self.assertRaises(ValueError): verify(self.lock,self.parent)

    def test_materialized_post_pipeline_allows_caches_but_rejects_source_mutation(self):
        archive=self.parent/'source.tar'; bundle(self.lock,self.parent,archive)
        output=self.parent/'checkout'; checkout(archive,output)
        for name in ('keep_sims/.dart_tool/cache.json','keep_sims/build/app.bin',
                     'keep_sims/output/review.png','keep_sims_admin/.dart_tool/cache.json',
                     'backend-sync-wt/node_modules/package/index.js'):
            file=output/name;file.parent.mkdir(parents=True,exist_ok=True);file.write_text('generated')
        verify(self.lock,output,checkout=True)
        (output/'keep_sims/lib/main.dart').write_text('// mutated by a test')
        with self.assertRaisesRegex(ValueError,'Source drift'):
            verify(self.lock,output,checkout=True)

    def test_bundle_rejects_tamper_without_partial_checkout(self):
        source=self.parent/'ok.tar'; bundle(self.lock,self.parent,source)
        bad=self.parent/'bad.tar'
        with tarfile.open(source) as old, tarfile.open(bad,'w') as new:
            for member in old.getmembers():
                data=old.extractfile(member).read()
                if member.name.endswith('main.dart'): data=b'tampered'; member.size=len(data)
                new.addfile(member,io.BytesIO(data))
        destination=self.parent/'bad-checkout'
        with self.assertRaises(ValueError): checkout(bad,destination)
        self.assertFalse(destination.exists())

    def test_bundle_rejects_traversal_and_links(self):
        for name,kind in [('../outside','file'),('link','symlink')]:
            archive=self.parent/(kind+'.tar')
            with tarfile.open(archive,'w') as f:
                member=tarfile.TarInfo(name)
                if kind=='symlink': member.type=tarfile.SYMTYPE; member.linkname='../outside'
                f.addfile(member)
            with self.assertRaises(ValueError): checkout(archive,self.parent/(kind+'-checkout'))

    def test_runtime_secret_blocks_bundle(self):
        file=self.parent/'backend-sync-wt/worker.js'
        file.write_text('const API_KEY = "'+('private-value-'*3)+'";')
        lock=write_lock(self.parent,self.parent/'lock.json')
        with self.assertRaises(ValueError): bundle(lock,self.parent,self.parent/'rejected.tar')
        self.assertFalse((self.parent/'rejected.tar').exists())

    def test_linked_source_directory_is_rejected(self):
        directory=self.parent/'keep_sims/lib'
        (directory/'main.dart').unlink();directory.rmdir()
        outside=self.parent/'outside';outside.mkdir();(outside/'main.dart').write_text('private')
        directory.symlink_to(outside,target_is_directory=True)
        # Git does not enumerate an untracked directory symlink as a file under
        # lib; a tracked path is required to exercise the ancestor check.
        subprocess.run(['git','-C',str(self.parent/'keep_sims'),'update-index','--add','--cacheinfo','100644,'+
                        subprocess.run(['git','-C',str(self.parent/'keep_sims'),'hash-object','-w',str(outside/'main.dart')],check=True,capture_output=True,text=True).stdout.strip()+',lib/main.dart'],check=True)
        with self.assertRaises(ValueError): write_lock(self.parent,self.parent/'new-lock.json')


if __name__ == '__main__': unittest.main()
