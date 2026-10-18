#!/usr/bin/env python3
"""Install only the reviewed official API test binary; verify archive before use."""
import argparse
import hashlib
import io
import json
from pathlib import Path
import platform
import tarfile
import urllib.request

ROOT=Path(__file__).resolve().parents[1]
def install(output):
    if output.exists(): raise ValueError('Refusing to overwrite existing executable')
    pins=json.loads((ROOT/'deployment/postgrest-artifacts.json').read_text())
    arch={'aarch64':'arm64','arm64':'arm64','x86_64':'x64','AMD64':'x64'}[platform.machine()]
    name,expected=pins['archives'][platform.system().lower()+'-'+arch]
    url='https://github.com/PostgREST/postgrest/releases/download/v'+pins['version']+'/'+name
    with urllib.request.urlopen(url,timeout=60) as response: data=response.read()
    if hashlib.sha256(data).hexdigest()!=expected: raise ValueError('PostgREST archive digest mismatch')
    with tarfile.open(fileobj=io.BytesIO(data),mode='r:xz') as archive:
        files=[m for m in archive.getmembers() if m.name in ('postgrest','./postgrest') and m.isfile()]
        if len(files)!=1: raise ValueError('Expected one regular postgrest executable')
        executable=archive.extractfile(files[0]).read()
    output.parent.mkdir(parents=True,exist_ok=True)
    with output.open('xb') as stream: stream.write(executable)
    output.chmod(0o755)
    print('Verified PostgREST '+pins['version'])
if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path,required=True)
    install(parser.parse_args().output)
