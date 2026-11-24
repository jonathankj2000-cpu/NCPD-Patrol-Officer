"""Validate the real six voice resources and reject unsafe header conversions."""
from pathlib import Path
import hashlib
import importlib.util
import json
import struct

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('wem_header', ROOT/'tools/build_voss_wem_header_test.py')
test = importlib.util.module_from_spec(spec)
spec.loader.exec_module(test)


def main():
    manifest = json.loads((ROOT/'assets/quest_giver_test/media/manifest.json').read_text())
    for name in test.VOICES:
        original = (ROOT/'assets/quest_giver_test/media'/name).read_bytes()
        assert hashlib.sha256(original).hexdigest() == manifest['packaged'][name]['sha256']
        corrected = test.patch_header(original)
        result = test.inspect_delta(original, corrected)
        assert len(result['changed_byte_offsets']) == 2
        assert test.patch_header(corrected) == corrected, 'Not idempotent'
        # A correct packed mono declaration must agree with the actual
        # channel count, without changing any compressed packet or seek data.
        fmt = test.chunks(corrected)[b'fmt '][0]
        assert struct.unpack_from('<H', corrected, fmt+2)[0] == 1
        assert struct.unpack_from('<I', corrected, fmt+0x14)[0] == 0x4101
    original = (ROOT/'assets/quest_giver_test/media'/test.VOICES[0]).read_bytes()
    fmt = test.chunks(original)[b'fmt '][0]
    malformed = [original[:-1], b'OggS'+original[4:]]
    for offset, form, value in [(fmt, '<H', 1), (fmt+2, '<H', 2),
                                (fmt+4, '<I', 48000), (fmt+0x14, '<I', 0x3102)]:
        wrong = bytearray(original)
        struct.pack_into(form, wrong, offset, value)
        malformed.append(bytes(wrong))
    for data in malformed:
        try:
            test.patch_header(data)
        except ValueError:
            continue
        raise AssertionError('Accepted a different codec/layout or a damaged WEM')
    assert test.NOTE.encode().isascii()
    print('PASS: six pinned real voices: modern packed mono config agrees with one channel; '
          'exact two-byte deltas, unchanged compressed data/all other headers, idempotence; '
          'different codecs, rates, channel layouts and truncation rejected. Game audio result unverified.')


if __name__ == '__main__':
    main()
