"""Materialize checksummed build inputs transferred in bounded text chunks.

The CI commit removes the transport chunks after restoring the reviewed files.
An already materialized checkout needs no transfer directory.
"""
from pathlib import Path
import base64, hashlib, io, json, shutil, zipfile

ROOT = Path(__file__).resolve().parents[1]


def materialize(root):
    root = Path(root)
    transport = root / 'assets/beanbagger/upload'
    manifest = transport / 'manifest.json'
    if not manifest.exists():
        return
    expected = json.loads(manifest.read_text())
    encoded = ''.join((transport / name).read_text().strip() for name in expected['chunks'])
    payload = base64.b64decode(encoded, validate=True)
    assert hashlib.sha256(payload).hexdigest() == expected['zip_sha256']
    with zipfile.ZipFile(io.BytesIO(payload)) as archive:
        assert set(archive.namelist()) == set(expected['files'])
        assert archive.testzip() is None
        for name, digest in expected['files'].items():
            relative = Path(name)
            assert not relative.is_absolute() and '..' not in relative.parts
            assert name == 'archive/pc/mod/NCPDPatrol_BeanBagger.archive' or name.startswith('assets/beanbagger/visuals/')
            data = archive.read(name)
            assert hashlib.sha256(data).hexdigest() == digest, name
            output = root / relative
            output.parent.mkdir(parents=True, exist_ok=True)
            output.write_bytes(data)
    shutil.rmtree(transport)
    print('Restored and verified', len(expected['files']), 'reviewed binary/large source files')


if __name__ == '__main__':
    materialize(ROOT)
