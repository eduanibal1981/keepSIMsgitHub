import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import release_checks as gate


class ReleaseChecksTest(unittest.TestCase):
    def test_missing_companion_cannot_reduce_the_gate(self):
        with tempfile.TemporaryDirectory() as temp:
            with self.assertRaisesRegex(ValueError, 'Missing required source'):
                gate.validate_inventory('unit', Path(temp)/'keep_sims')

    def test_all_native_and_real_http_acceptance_suites_are_required(self):
        rows=gate.checks('database')
        names={row[0] for row in rows}
        for name in ('concurrency','paypal-concurrency','webhook-auth-concurrency',
                     'scheduled-http','schedules','pricing','second-number','retail','fleet'):
            self.assertIn('sql-'+name,names)
        for name in ('sql-pricing','sql-second-number','sql-fleet'):
            env=next(row[3] for row in rows if row[0]==name)
            self.assertEqual(env['PRICING_NATIVE'],'1')
            self.assertEqual(env['SECOND_NUMBER_NATIVE'],'1')
            self.assertEqual(env['FLEET_NATIVE'],'1')
        release_fleet=next(row for row in gate.checks('release') if row[0]=='sql-fleet')
        self.assertEqual(release_fleet[3]['FLEET_NATIVE'],'1')

    def test_every_profile_finishes_with_source_consistency(self):
        for profile in gate.PROFILES:
            self.assertEqual(gate.checks(profile)[-1][0], 'source-bytes-after', profile)

    def test_materialized_checkout_uses_its_embedded_source_lock(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp)/'keep_sims'
            command=gate.source_command(root)
            self.assertIn(str(root.parent/'source-lock.json'),command)
            self.assertEqual(command[-2:],['verify','--checkout'])

    def test_development_checks_do_not_require_distribution_or_deployment(self):
        names={row[0] for row in gate.checks('development')}
        self.assertTrue({'customer-analysis','admin-tests','sql-fleet','source-bytes-after'} <= names)
        self.assertNotIn('deployment-evidence',names)
        self.assertNotIn('customer-android',names)

    def test_visual_review_artifacts_survive_a_failed_check(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp); file=root/'output/review.png'
            file.parent.mkdir();file.write_bytes(b'original review')
            with self.assertRaises(RuntimeError), gate.preserve_visual_artifacts(root):
                file.write_bytes(b'regenerated preview')
                raise RuntimeError('test failure')
            self.assertEqual(file.read_bytes(),b'original review')

    def test_release_requires_analysis_builds_runtime_and_deployment_evidence(self):
        names={row[0] for row in gate.checks('release')}
        for name in ('customer-analysis','admin-analysis','customer-android',
                     'customer-ios-compile','admin-macos','admin-web','source-bytes',
                     'deployment-evidence','secrets'):
            self.assertIn(name,names)
        self.assertTrue(any(name.startswith('deno-') for name in names))

    def test_command_failure_is_reported_and_later_checks_still_run(self):
        with tempfile.TemporaryDirectory() as temp:
            out=Path(temp)/'evidence'
            rows=[('failure',Path(temp),['python3','-c','raise SystemExit(9)'],{}),
                  ('later',Path(temp),['python3','-c','print("finished")'],{})]
            with patch.object(gate,'validate_inventory'),patch.object(gate,'toolchain_errors',return_value=[]),patch.object(gate,'checks',return_value=rows):
                code=gate.main(['unit','--output',str(out)])
            report=json.loads((out/'results.json').read_text())
            self.assertEqual(code,1)
            self.assertEqual([x['status'] for x in report['checks']],['failed','passed'])
            self.assertFalse(report['release_approved'])
            self.assertEqual(report['checks'][0]['exit_code'],9)
            self.assertIn('log_sha256',report['checks'][0])

    def test_toolchain_mismatch_never_produces_pinned_pass_evidence(self):
        pins={'node':'0.0.0'}
        with patch.object(gate.subprocess,'check_output',return_value='v26.11.1\n'):
            self.assertTrue(gate.toolchain_errors('unit',pins))

    def test_missing_http_binary_is_a_failure(self):
        with patch.dict(gate.os.environ,{},clear=True),patch.object(gate.subprocess,'check_output',return_value='v26.11.1\n'):
            errors=gate.toolchain_errors('database',{'node':'26.11.1'})
        self.assertTrue(any('POSTGREST_BINARY' in error for error in errors))

    def test_timeout_is_a_failed_result(self):
        import subprocess
        with tempfile.TemporaryDirectory() as temp:
            out=Path(temp)/'evidence'
            with patch.object(gate,'validate_inventory'),patch.object(gate,'toolchain_errors',return_value=[]),patch.object(gate,'checks',return_value=[('slow',Path(temp),['example'],{})]),patch.object(gate.subprocess,'run',side_effect=subprocess.TimeoutExpired('example',1)):
                self.assertEqual(gate.main(['unit','--output',str(out)]),1)
            self.assertEqual(json.loads((out/'results.json').read_text())['checks'][0]['status'],'failed')

if __name__=='__main__': unittest.main()
