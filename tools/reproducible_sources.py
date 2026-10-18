#!/usr/bin/env python3
"""Lock, package and check out the three source trees without touching Git or a server.

Dirty/untracked source is included as bytes, not misrepresented by a commit ID.
No network, database, migration-history repair or deployment commands exist here.
"""
import argparse
import hashlib
import io
import json
from pathlib import Path, PurePosixPath
import subprocess
import tarfile

ROOT = Path(__file__).resolve().parents[1]
LOCK = ROOT / 'deployment/source-lock.json'
REPOS = {'customer':'keep_sims','admin':'keep_sims_admin','backend':'backend-sync-wt'}
SCOPES = {
    'customer': ('.github/', 'lib/', 'test/', 'assets/', 'android/', 'ios/', 'macos/', 'web/',
                 'linux/', 'windows/', 'supabase/', 'tools/', 'tool/', 'deployment/',
                 'docs/reviews/migration-cleanup-20261016/',
                 'docs/reviews/source-reproducibility-20261018/',
                 'docs/reviews/source-reproducibility-20261018.md',
                 'docs/reviews/audit-baseline-20261016/live-worker-vm-inventory.json',
                 'docs/reviews/privileged-database-access-20261017/',
                 'docs/reviews/financial-production-contracts-20261017.md',
                 'pubspec.yaml', 'pubspec.lock', 'analysis_options.yaml', 'l10n.yaml',
                 'build.yaml', 'devtools_options.yaml'),
    'admin': ('lib/', 'test/', 'assets/', 'android/', 'ios/', 'macos/', 'web/',
              'linux/', 'windows/', 'tools/', 'pubspec.yaml', 'pubspec.lock',
              'analysis_options.yaml', 'l10n.yaml', 'build.yaml'),
    'backend': ('providers/', 'test/'),
}
SKIP_PARTS = {'node_modules','build','.dart_tool','.gradle','Pods','ephemeral',
              '.symlinks','__pycache__','.git','.aws','.codex','.agents'}


def digest(data):
    return hashlib.sha256(data).hexdigest()


def git(repo, *args):
    return subprocess.run(['git','-C',str(repo),*args], check=True, capture_output=True).stdout


def safe_name(value):
    p = PurePosixPath(value)
    if p.is_absolute() or not p.parts or '..' in p.parts or '\\' in value:
        raise ValueError('Unsafe source path')
    return p


def source_files(repo, component):
    paths = git(repo,'ls-files','-z','--cached','--others','--exclude-standard').split(b'\0')
    selected = []
    required_archives = set()
    if component == 'customer':
        manifest = json.loads((repo/'docs/reviews/migration-cleanup-20261016/manifest.json').read_text())
        required = json.loads((repo/'deployment/required-migration-sources.json').read_text())['files']
        required_archives = {r['current_path'] for r in manifest['migrations'] if r['file'] in required}
    for raw in sorted(set(paths)):
        if not raw: continue
        name = raw.decode('utf-8'); p = safe_name(name)
        if set(p.parts) & SKIP_PARTS or p.name.startswith('.env') or p.suffix == '.pyc': continue
        if p.name in {'local.properties','key.properties','Generated.xcconfig','flutter_export_environment.sh'}: continue
        if p.suffix in {'.jks','.keystore','.p12','.p8','.mobileprovision'}: continue
        included = any(name.startswith(scope) if scope.endswith('/') else name == scope for scope in SCOPES[component])
        if component == 'backend' and len(p.parts) == 1 and p.suffix in {'.js','.cjs','.json'}: included = True
        if component == 'customer' and name == 'deployment/source-lock.json': included = False
        if component == 'customer' and name.startswith('supabase/migration_archive/'):
            included = name in required_archives
        target = repo / name
        if included and target.exists():
            if any((repo/Path(*p.parts[:i])).is_symlink() for i in range(1,len(p.parts)+1)) or not target.is_file():
                raise ValueError('Nonregular source: '+name)
            selected.append(name)
    return selected


def inspect_sources(parent):
    repositories = {}
    for component, directory in REPOS.items():
        repo = parent / directory
        entries = []
        for name in source_files(repo, component):
            file = repo / name
            entries.append({'path':name,'sha256':digest(file.read_bytes()),
                            'executable':bool(file.stat().st_mode & 0o111)})
        repositories[component] = {'directory':directory,
            'head':git(repo,'rev-parse','HEAD').decode().strip(),
            'dirty':bool(git(repo,'status','--porcelain')),
            'files':entries}
    return repositories


def write_lock(parent, output):
    result = {'format':1,'kind':'source snapshot, not deployment approval',
              'repositories':inspect_sources(parent)}
    output.parent.mkdir(parents=True,exist_ok=True)
    output.write_text(json.dumps(result,indent=2)+'\n')
    print('Locked source bytes: '+', '.join(f"{k}={len(v['files'])}" for k,v in result['repositories'].items()))
    return result


def verify(lock, parent, checkout=False):
    errors = []
    if lock.get('format') != 1 or set(lock['repositories']) != set(REPOS): raise ValueError('Unsupported source lock')
    for component, repo in lock['repositories'].items():
        if repo['directory'] != REPOS[component]: raise ValueError('Unexpected repository directory')
        directory = parent / repo['directory']
        expected = set()
        for entry in repo['files']:
            safe_name(entry['path']); expected.add(entry['path']); file = directory / entry['path']
            if file.is_symlink() or not file.is_file() or digest(file.read_bytes()) != entry['sha256']:
                errors.append(component+':'+entry['path'])
            elif bool(file.stat().st_mode & 0o111) != entry['executable']:
                errors.append(component+':mode:'+entry['path'])
        if not checkout:
            actual = set(source_files(directory,component))
            errors.extend(component+':unlocked:'+name for name in sorted(actual-expected))
        else:
            # Materialized checkouts acquire dependency caches, compiler output
            # and visual previews during verification. Only release source is
            # inventoried, while all locked files above still require exact bytes.
            actual = set()
            for p in directory.rglob('*'):
                if not p.is_file() or set(p.relative_to(directory).parts) & SKIP_PARTS:
                    continue
                name = p.relative_to(directory).as_posix()
                if p.name.startswith('.env') or p.suffix == '.pyc': continue
                if p.name in {'local.properties','key.properties','Generated.xcconfig','flutter_export_environment.sh'}: continue
                if p.suffix in {'.jks','.keystore','.p12','.p8','.mobileprovision'}: continue
                included = any(name.startswith(scope) if scope.endswith('/') else name == scope for scope in SCOPES[component])
                if component == 'backend' and len(p.relative_to(directory).parts) == 1 and p.suffix in {'.js','.cjs','.json'}: included = True
                if component == 'customer' and name == 'deployment/source-lock.json': included = False
                if included: actual.add(name)
            errors.extend(component+':extra:'+name for name in sorted(actual-expected))
    if errors: raise ValueError('Source drift: '+', '.join(errors[:20]))


def bundle(lock, parent, output):
    from scan_embedded_secrets import scan_text
    verify(lock,parent)
    # Preflight every byte before creating an archive. Historical SQL/test fixtures
    # may contain synthetic credentials, so only fixed secret signatures are used
    # there; executable runtime code also checks secret assignments/fallbacks.
    contents = []
    for component, repo in lock['repositories'].items():
        for entry in repo['files']:
            name = entry['path']; data = (parent/repo['directory']/name).read_bytes()
            if digest(data) != entry['sha256']: raise ValueError('Source changed during packaging: '+name)
            try: text = data.decode('utf-8')
            except UnicodeDecodeError: text = ''
            runtime = (component == 'backend' and not name.startswith('test/') and name.endswith(('.js','.cjs'))) or (component == 'customer' and name.startswith('supabase/functions/') and not '/test' in name)
            findings = scan_text(text,name,check_assignments=runtime)
            if findings: raise ValueError('Secret scan rejected '+component+':'+name+' ('+','.join(sorted({f.rule for f in findings}))+')')
            contents.append((repo['directory']+'/'+name,data,entry['executable']))
    metadata = (json.dumps(lock,indent=2)+'\n').encode()
    # Deterministic uncompressed archive (stable names, modes, mtimes and owners).
    with output.open('xb') as stream, tarfile.open(fileobj=stream,mode='w') as archive:
        for name,data,executable in [('source-lock.json',metadata,False),*contents]:
            info = tarfile.TarInfo(name); info.size=len(data); info.mode=0o755 if executable else 0o644
            archive.addfile(info,io.BytesIO(data))
    print('Source bundle SHA-256: '+digest(output.read_bytes()))


def checkout(archive_path, destination):
    if destination.exists(): raise ValueError('Checkout destination must not exist')
    with tarfile.open(archive_path,'r:') as archive:
        members = archive.getmembers()
        if any(not m.isfile() for m in members): raise ValueError('Only regular source files are accepted')
        names = [m.name for m in members]
        if len(names) != len(set(names)): raise ValueError('Duplicate archive members')
        for name in names: safe_name(name)
        lock_member = archive.getmember('source-lock.json')
        if lock_member.size > 5_000_000: raise ValueError('Source lock too large')
        lock = json.loads(archive.extractfile(lock_member).read())
        if lock.get('format') != 1 or set(lock['repositories']) != set(REPOS): raise ValueError('Unsupported source lock')
        expected = {'source-lock.json'}
        for component,repo in lock['repositories'].items():
            if repo['directory'] != REPOS[component]: raise ValueError('Unexpected checkout directory')
            for entry in repo['files']:
                safe_name(entry['path']); expected.add(repo['directory']+'/'+entry['path'])
        if set(names) != expected: raise ValueError('Archive and source lock disagree')
        # Validate all hashes before creating the checkout. Never use extractall.
        for repo in lock['repositories'].values():
            for entry in repo['files']:
                member = archive.getmember(repo['directory']+'/'+entry['path'])
                if bool(member.mode & 0o111) != entry['executable']: raise ValueError('Bundle source mode mismatch')
                if digest(archive.extractfile(member).read()) != entry['sha256']: raise ValueError('Bundle source hash mismatch')
        destination.mkdir(parents=True)
        for member in members:
            file = destination/member.name; file.parent.mkdir(parents=True,exist_ok=True)
            file.write_bytes(archive.extractfile(member).read()); file.chmod(0o755 if member.mode & 0o111 else 0o644)
    verify(lock,destination,checkout=True)
    print('Verified isolated source checkout at '+str(destination))


def run_checks(parent, profile):
    customer = parent / REPOS['customer']; backend = parent / REPOS['backend']
    if profile == 'source':
        commands = [(customer,['python3','tools/migration_archive.py','verify','--required-only']),
                    (customer,['python3','-m','unittest','discover','-s','tools','-p','test_reproducibility.py']),
                    (customer,['node','--test','test/migration_source.test.cjs']),
                    (customer,['node','tools/financial-tests/source-recovery.mjs'])]
    elif profile == 'contracts':
        commands = [(customer,['node','tools/financial-tests/'+name+'.mjs']) for name in
                    ('fixture','schedules','maintenance','forecasts','vouchers')]
    elif profile == 'workers':
        commands = [(backend,['node','--test',*sorted(str(p.relative_to(backend)) for p in (backend/'test').glob('*test.js'))])]
    else:
        commands = [(parent/REPOS[c],['flutter','test']) for c in ('customer','admin')]
    for directory, command in commands:
        print('CHECK '+directory.name+': '+' '.join(command),flush=True)
        subprocess.run(command,cwd=directory,check=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--parent',type=Path,default=ROOT.parent)
    parser.add_argument('--lock',type=Path,default=LOCK)
    sub = parser.add_subparsers(dest='command',required=True)
    sub.add_parser('lock'); sub.add_parser('verify').add_argument('--checkout',action='store_true')
    sub.add_parser('bundle').add_argument('output',type=Path)
    p = sub.add_parser('checkout'); p.add_argument('archive',type=Path); p.add_argument('destination',type=Path)
    sub.add_parser('test').add_argument('profile',choices=['source','contracts','workers','apps'])
    args=parser.parse_args()
    try:
        if args.command == 'lock': write_lock(args.parent,args.lock)
        elif args.command == 'checkout': checkout(args.archive,args.destination)
        elif args.command == 'test': run_checks(args.parent,args.profile)
        else:
            lock=json.loads(args.lock.read_text())
            if args.command == 'verify': verify(lock,args.parent,args.checkout); print('Source lock verified')
            else: bundle(lock,args.parent,args.output)
    except (ValueError,subprocess.CalledProcessError) as error:
        parser.exit(1,str(error)+'\n')
