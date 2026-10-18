#!/usr/bin/env python3
"""Run bounded release checks; no remote DB, providers, deployment or history writes.

Every command has its own log and result. Missing prerequisites and timeouts fail;
all other selected checks still run. A profile pass is never a full release pass.
"""
import argparse
from contextlib import contextmanager, nullcontext
import datetime
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import shutil
import subprocess
import sys
import time
import tempfile

ROOT = Path(__file__).resolve().parents[1]
PROFILES = ('source', 'unit', 'database', 'apps', 'builds', 'edge-runtime', 'development', 'release')
DB_SUITES = ('fixture', 'run', 'credentials', 'privileges', 'paypal',
             'webhook-auth', 'concurrency', 'paypal-concurrency',
             'webhook-auth-concurrency', 'notifications', 'forecasts',
             'maintenance', 'second-number', 'pricing', 'retail', 'schedules',
             'vouchers', 'fleet', 'source-recovery', 'scheduled-http')


def checks(profile, root=ROOT):
    admin = root.parent / 'keep_sims_admin'
    backend = root.parent / 'backend-sync-wt'
    rows = []
    def add(name, directory, command, env=None):
        rows.append((name, directory, command, env or {}))
    if profile in ('source', 'development', 'release'):
        add('archive', root, ['python3','tools/migration_archive.py','verify'])
        add('source-tool-tests', root, ['python3','-m','unittest','discover','-s','tools','-p','test_*.py'])
        add('migration-edge-manifest', root, ['python3','tools/build_deployment_manifest.py','--check'])
        add('source-bytes', root, source_command(root))
        # All three repositories are explicit. A missing sibling cannot shrink
        # the scanner scope into a misleading clean result.
        add('secrets', root, ['python3','tools/scan_embedded_secrets.py',
            '--repo',str(root),'--repo',str(admin),'--repo',str(backend)])
    if profile in ('unit', 'development', 'release'):
        add('edge-contracts', root, ['node','--test', *sorted(str(p.relative_to(root)) for p in (root/'test').glob('*.test.cjs'))])
        files = sorted(set((backend/'test').glob('*test.js')) | set(backend.glob('*test.js')))
        add('worker-contracts', backend, ['node','--test', *[str(p.relative_to(backend)) for p in files]])
        for p in sorted(backend.glob('*.js')) + sorted((backend/'providers').glob('*.js')):
            add('syntax-'+p.relative_to(backend).as_posix().replace('/','-'),backend,['node','--check',str(p.relative_to(backend))])
    if profile in ('database', 'development', 'release'):
        for name in DB_SUITES:
            env = {'SECOND_NUMBER_NATIVE':'1','PRICING_NATIVE':'1','FLEET_NATIVE':'1'}
            add('sql-'+name,root,['node','tools/financial-tests/'+name+'.mjs'],env)
    if profile in ('apps', 'development', 'release'):
        for name, directory in [('customer',root),('admin',admin)]:
            add(name+'-dependencies',directory,['flutter','pub','get','--enforce-lockfile'])
            add(name+'-analysis',directory,['flutter','analyze','--no-pub'])
            add(name+'-tests',directory,['flutter','test','--no-pub','--reporter','expanded'])
    if profile in ('builds', 'release'):
        add('customer-android',root,['flutter','build','appbundle','--release','--no-pub'])
        add('customer-ios-compile',root,['flutter','build','ios','--release','--no-codesign','--no-pub'])
        add('admin-macos',admin,['flutter','build','macos','--release','--no-pub'])
        add('admin-web',admin,['flutter','build','web','--release','--no-pub'])
    if profile in ('edge-runtime', 'development', 'release'):
        # This requires per-function dependency locks. It deliberately does not
        # manufacture a new dependency graph during release verification.
        for p in sorted((root/'supabase/functions').glob('*/index.ts')):
            add('deno-'+p.parent.name,p.parent,['deno','check','--frozen','--lock=deno.lock','index.ts'])
    if profile == 'release':
        add('deployment-evidence',root,['python3','tools/build_deployment_manifest.py','--gate'])
    # This runs even when an earlier command failed. Verification must never
    # accept a source snapshot that a test/dependency/build command rewrote.
    add('source-bytes-after', root, source_command(root))
    return rows


def source_command(root):
    command = ['python3', 'tools/reproducible_sources.py']
    if not (root/'.git').exists():
        command += ['--lock', str(root.parent/'source-lock.json')]
    command += ['verify']
    if not (root/'.git').exists():
        command += ['--checkout']
    return command


@contextmanager
def preserve_visual_artifacts(root):
    """Tests may render new previews, but cannot replace existing review bytes."""
    output = root/'output'
    with tempfile.TemporaryDirectory(prefix='keepsims-visuals-') as temp:
        backup = Path(temp)/'output'
        if output.exists():
            shutil.copytree(output, backup)
        try:
            yield
        finally:
            if backup.exists():
                shutil.copytree(backup, output, dirs_exist_ok=True)


def validate_inventory(profile, root):
    required = [root/'test',root.parent/'keep_sims_admin/pubspec.lock',root.parent/'backend-sync-wt/test']
    missing = [str(p) for p in required if not p.exists()]
    if missing: raise ValueError('Missing required source: '+', '.join(missing))
    if profile in ('unit','development','release'):
        if not list((root/'test').glob('*.test.cjs')): raise ValueError('No Edge contract tests discovered')
        if not list((root.parent/'backend-sync-wt/test').glob('*test.js')): raise ValueError('No worker tests discovered')


def toolchain_errors(profile, pins):
    errors = []
    if sys.version_info < tuple(map(int, pins.get('minimum_python', '3.9').split('.'))):
        errors.append('Python is below the supported minimum')
    probes = []
    if profile in ('unit','database','development','release'): probes.append(('node',['node','--version'],pins['node']))
    if profile in ('apps','builds','development','release'):
        try:
            result = json.loads(subprocess.check_output(['flutter','--version','--machine'],text=True))
            for name, actual in [('flutter',result['frameworkVersion']),('dart',result['dartSdkVersion']),('flutter_revision',result['frameworkRevision'])]:
                if actual != pins[name]: errors.append(f'{name}: expected {pins[name]}, observed {actual}')
        except (OSError,subprocess.CalledProcessError,ValueError,KeyError) as e: errors.append('Flutter toolchain unavailable: '+type(e).__name__)
    if profile in ('edge-runtime','development','release'): probes.append(('deno',['deno','--version'],pins['deno']))
    if profile in ('database','development','release'):
        binary = os.environ.get('POSTGREST_BINARY')
        if not binary: errors.append('POSTGREST_BINARY is required; HTTP checks must not be skipped')
        else: probes.append(('postgrest',[binary,'--version'],pins['postgrest']))
    for name, command, expected in probes:
        try:
            env = dict(os.environ)
            if name == 'postgrest' and env.get('POSTGREST_LIBRARY_PATH'):
                env['DYLD_LIBRARY_PATH'] = env['POSTGREST_LIBRARY_PATH']
            value = subprocess.check_output(command,text=True,stderr=subprocess.STDOUT,env=env).splitlines()[0]
            if not re.search(r'(?<![0-9.])'+re.escape(expected)+r'(?![0-9.])',value): errors.append(name+': unexpected version '+value)
        except (OSError,subprocess.CalledProcessError) as e: errors.append(name+' unavailable: '+type(e).__name__)
    return errors


def main(argv=None):
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('profile',choices=PROFILES)
    parser.add_argument('--output',type=Path,required=True,help='New directory outside selected release sources')
    parser.add_argument('--timeout',type=int,default=1200,help='Per-check timeout in seconds')
    args=parser.parse_args(argv)
    pins=json.loads((ROOT/'deployment/release-toolchains.json').read_text())
    args.output.mkdir(parents=True,exist_ok=False)
    report={'format':1,'profile':args.profile,'started_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),
            'host':platform.platform(),'python':platform.python_version(),'toolchains':pins,'checks':[],
            'evidence':'local checks only; no provider sandbox or live smoke certification'}
    lock_path = ROOT/'deployment/source-lock.json'
    if not lock_path.is_file(): lock_path = ROOT.parent/'source-lock.json'
    report['source_lock_sha256'] = hashlib.sha256(lock_path.read_bytes()).hexdigest() if lock_path.is_file() else None
    report['repository_heads'] = {}
    for name, directory in [('customer', ROOT), ('admin', ROOT.parent/'keep_sims_admin'), ('backend', ROOT.parent/'backend-sync-wt')]:
        try:
            report['repository_heads'][name] = subprocess.check_output(['git','-C',str(directory),'rev-parse','HEAD'],text=True,stderr=subprocess.DEVNULL,timeout=15).strip()
        except (OSError, subprocess.CalledProcessError, subprocess.TimeoutExpired):
            report['repository_heads'][name] = None
    try:
        validate_inventory(args.profile,ROOT)
        errors=toolchain_errors(args.profile,pins)
    except ValueError as e: errors=[str(e)]
    for error in errors:
        report['checks'].append({'name':'prerequisite','status':'failed','message':error})
        print('FAIL '+error,flush=True)
    # Toolchain mismatch prevents commands from being presented as pinned evidence.
    rows=[] if errors else checks(args.profile)
    for name,directory,command,env in rows:
        log=args.output/(name+'.log')
        start=time.monotonic()
        print('CHECK '+name,flush=True)
        try:
            if command[0]=='deno' and not (directory/'deno.lock').is_file():
                raise ValueError('Missing reviewed per-function deno.lock')
            if name=='sql-schedules' and not os.environ.get('POSTGREST_BINARY'):
                raise ValueError('Real schedule HTTP checks require POSTGREST_BINARY')
            with (preserve_visual_artifacts(directory) if name in ('customer-tests','admin-tests') else nullcontext()), log.open('w') as stream:
                result=subprocess.run(command,cwd=directory,env={**os.environ,**env},stdout=stream,stderr=subprocess.STDOUT,timeout=args.timeout)
            code=result.returncode
            item={'name':name,'status':'passed' if code==0 else 'failed','exit_code':code,'log':log.name}
        except (OSError,ValueError,subprocess.TimeoutExpired) as e:
            log.write_text(type(e).__name__+': '+str(e)+'\n')
            item={'name':name,'status':'failed','message':str(e),'log':log.name}
        item['seconds']=round(time.monotonic()-start,3)
        item['log_sha256']=hashlib.sha256(log.read_bytes()).hexdigest()
        report['checks'].append(item)
        print(item['status'].upper()+' '+name,flush=True)
    report['status']='passed' if report['checks'] and all(x['status']=='passed' for x in report['checks']) else 'failed'
    report['release_approved']=False # Passing automated checks never authorizes rollout.
    (args.output/'results.json').write_text(json.dumps(report,indent=2)+'\n')
    print(report['status'].upper()+': '+str(args.output/'results.json'),flush=True)
    return 0 if report['status']=='passed' else 1

if __name__=='__main__': sys.exit(main())
