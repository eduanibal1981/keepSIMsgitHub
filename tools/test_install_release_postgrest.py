import hashlib
import io
import json
from pathlib import Path
import tarfile
import tempfile
import unittest
from unittest.mock import patch
import install_release_postgrest as installer


def archive(name='postgrest',kind=tarfile.REGTYPE):
    data=io.BytesIO()
    with tarfile.open(fileobj=data,mode='w:xz') as tar:
        item=tarfile.TarInfo(name);item.type=kind
        content=b'isolated-executable';item.size=len(content)
        tar.addfile(item,io.BytesIO(content))
    return data.getvalue()

class PostgrestInstallerTest(unittest.TestCase):
    def run_install(self,temp,data,expected=None):
        temp=Path(temp)
        (temp/'deployment').mkdir(exist_ok=True)
        (temp/'deployment/postgrest-artifacts.json').write_text(json.dumps({
            'version':'16.4','archives':{'darwin-arm64':['postgrest.tar.xz', expected or hashlib.sha256(data).hexdigest()]}}))
        with patch.object(installer,'ROOT',temp),patch.object(installer.platform,'system',return_value='Darwin'),patch.object(installer.platform,'machine',return_value='arm64'),patch.object(installer.urllib.request,'urlopen',return_value=io.BytesIO(data)):
            installer.install(temp/'binary')
        return temp/'binary'

    def test_checksum_mismatch_never_writes_an_executable(self):
        with tempfile.TemporaryDirectory() as temp:
            with self.assertRaisesRegex(ValueError,'digest mismatch'):
                self.run_install(temp,archive(),expected='0'*64)
            self.assertFalse((Path(temp)/'binary').exists())

    def test_exact_regular_binary_is_installed(self):
        with tempfile.TemporaryDirectory() as temp:
            output=self.run_install(temp,archive())
            self.assertEqual(output.read_bytes(),b'isolated-executable')
            self.assertTrue(output.stat().st_mode & 0o111)

    def test_archive_cannot_write_outside_the_selected_file(self):
        with tempfile.TemporaryDirectory() as temp:
            with self.assertRaisesRegex(ValueError,'one regular'):
                self.run_install(temp,archive('../outside'))
            self.assertFalse((Path(temp)/'binary').exists())

    def test_existing_binary_is_never_overwritten(self):
        with tempfile.TemporaryDirectory() as temp:
            output=Path(temp)/'binary';output.write_bytes(b'existing')
            with self.assertRaisesRegex(ValueError,'overwrite'):
                installer.install(output)
            self.assertEqual(output.read_bytes(),b'existing')

if __name__=='__main__': unittest.main()
