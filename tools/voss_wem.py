"""Validate the author's modern mono 48-kHz Wwise Vorbis exports."""
import struct


def inspect(body):
    assert body[:4] == b'RIFF' and body[8:12] == b'WAVE'
    assert struct.unpack_from('<I', body, 4)[0] + 8 == len(body), 'Truncated WEM'
    chunks, pos = {}, 12
    while pos < len(body):
        assert pos + 8 <= len(body)
        tag, size = struct.unpack_from('<4sI', body, pos)
        pos += 8
        assert tag not in chunks and pos + size <= len(body)
        chunks[tag] = body[pos:pos+size]
        pos += size
        if pos < len(body):
            pos += size & 1  # Native Wwise omits a final odd data pad.
    assert pos == len(body) and set(chunks) == {b'fmt ', b'hash', b'data'}
    assert len(chunks[b'hash']) == 16
    fmt = chunks[b'fmt ']
    assert len(fmt) == 0x42
    codec, channels, rate = struct.unpack_from('<HHI', fmt)
    assert (codec, channels, rate) == (0xFFFF, 1, 48000), 'Expected mono 48-kHz Wwise Vorbis'
    assert struct.unpack_from('<H', fmt, 16)[0] == 0x30
    assert struct.unpack_from('<I', fmt, 20)[0] == 0x4101
    samples = struct.unpack_from('<I', fmt, 24)[0]
    assert samples > 0
    seek, offset = struct.unpack_from('<II', fmt, 40)
    data = chunks[b'data']
    assert seek % 4 == 0 and 0 < seek < offset < len(data)
    setup_size = struct.unpack_from('<H', data, seek)[0]
    assert seek + 2 + setup_size == offset
    setup_hash = 0x811C9DC5
    for byte in data[seek+2:offset]:
        setup_hash = ((setup_hash * 0x01000193) & 0xFFFFFFFF) ^ byte
    assert setup_hash == struct.unpack_from('<I', fmt, 60)[0]
    packets, pos = 0, offset
    while pos < len(data):
        assert pos + 2 <= len(data)
        size = struct.unpack_from('<H', data, pos)[0]
        pos += 2
        assert size > 0 and pos + size <= len(data), 'Truncated audio packet'
        pos += size
        packets += 1
    assert packets > 1
    return {'codec': 'Wwise Vorbis 0xFFFF', 'channels': channels, 'sample_rate': rate,
            'sample_frames': samples, 'duration_seconds': samples/rate,
            'audio_packets': packets}
