"""Build an isolated WEM channel-configuration experiment over exact v0.20f1.

The production source tree stays unchanged. The output is a complete package
with one replaced archive and one added test note. Only the six Voss WEMs in
that archive change: their legacy mono mask becomes modern packed mono config.
This is a format compatibility test, not a confirmed fix for the audio cuts.
"""
from pathlib import Path
import argparse
import hashlib
import json
import struct
import subprocess
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]
BASE_ZIP = 'NCPD_Patrol_v0.20f1_Dialogue_Handoff_TEST.zip'
BASE_SHA256 = 'd6493b500015e0877d28b4d85570ad9ec165a07c877c7ceb75643b1b61cc9bb4'
NAME = 'NCPD_Patrol_WEM_Channel_Header_TEST.zip'
ARCHIVE = 'archive/pc/mod/NCPDPatrol_QuestGiverTest.archive'
DEPOT = 'base/ncpd_patrol/quest_giver_test/'
VOICES = tuple(f'vossbriefing{i:02}.wem' for i in range(1, 7))
LEGACY_MONO = 0x00000004
PACKED_MONO = 0x00004101  # 1 channel | standard type (1 << 8) | FC (4 << 12)
NOTE_NAME = 'NCPDPatrol_WEM_Channel_Header_TEST.txt'
NOTE = '''NCPD PATROL - ISOLATED WEM CHANNEL HEADER TEST
=================================================
Complete test package based on v0.20f1. The CET version banner remains v0.20f1:
no Lua or REDscript was changed for this audio-format experiment.

Six Voss WEM files now use packed mono channel configuration 0x00004101 instead
of the legacy speaker mask 0x00000004. The compressed audio, sample rate/count,
seek tables, decoder allocation fields, lipsync, scene, captions, event lengths,
voice context, quests, wanted policy and all other gameplay files are unchanged.
This is NOT a complete official Wwise re-encode or a proven audio-cut fix.

INSTALL / TEST
1. Exit the game completely. Install this complete package over v0.20f1. If a
   mod manager asks, let this test's NCPDPatrol_QuestGiverTest.archive win.
2. Restart the game and load a save before Voss's briefing, or repeat the
   existing quest-giver test. A full restart is required for cached audio.
3. Listen for cuts at the first Voss line and at Voss -> V -> Voss transitions.
   Note whether the cuts disappear, change, or stay the same. Listen with the
   live game muted/closed if comparing a separate recording afterwards.
4. Confirm Voss audio, V's original lines, lipsync, subtitles and the following
   quest still work. No new diagnostic addon or dependency is required.

ROLLBACK
Reinstall NCPD_Patrol_v0.20f1_Dialogue_Handoff_TEST.zip (the original package)
and fully restart the game. No save or quest facts are changed by this test.

RESEARCH / CREDIT
Andrea Olivato's cyberpunk-codes, MIT, reference commit
f50e2d05e2ff868a1a15dbe40fd2cd9c77ff91be: the inspected fixer01_face__a01.wem and
gig01_nix_brief__n01.wem use packed mono configuration 0x4101. No reference
audio is included. Existing attribution remains in THIRD_PARTY_NOTICES.txt.
Independent format reference: vgmstream/vgmstream, src/meta/wwise.c,
commit 5d5574405d61876cb995c17d86ccb8fd0be3565e, lines 864-873.
The existing kamus1/wem-encoder authoring provenance is preserved.
'''


def digest(body):
    return hashlib.sha256(body).hexdigest()


def chunks(body):
    """Read this experiment's exact RIFF layout; never guess a byte offset."""
    if len(body) < 12 or body[:4] != b'RIFF' or body[8:12] != b'WAVE':
        raise ValueError('Not a RIFF/WAVE resource')
    if struct.unpack_from('<I', body, 4)[0] + 8 != len(body):
        raise ValueError('RIFF size mismatch')
    result = {}
    cursor = 12
    while cursor < len(body):
        if cursor + 8 > len(body):
            raise ValueError('Truncated RIFF chunk header')
        tag, size = struct.unpack_from('<4sI', body, cursor)
        start = cursor + 8
        if tag in result or start + size > len(body):
            raise ValueError('Duplicate or truncated RIFF chunk')
        result[tag] = (start, size)
        # These pinned WEMs contain only fmt and a final data chunk, without
        # an odd-length data pad. Other layouts are rejected below.
        cursor = start + size
    if tuple(result) != (b'fmt ', b'data') or result[b'fmt '][1] != 0x42:
        raise ValueError('Not the pinned Wwise Vorbis chunk layout')
    return result


def patch_header(body):
    entries = chunks(body)
    fmt, _ = entries[b'fmt ']
    codec, channels, rate = struct.unpack_from('<HHI', body, fmt)
    if (codec, channels, rate) != (0xFFFF, 1, 44100):
        raise ValueError('Expected the original mono 44.1 kHz Wwise Vorbis')
    config_offset = fmt + 0x14
    config = struct.unpack_from('<I', body, config_offset)[0]
    if config not in (LEGACY_MONO, PACKED_MONO):
        raise ValueError('Unexpected channel configuration; refusing to guess')
    if config == PACKED_MONO:
        return body
    output = bytearray(body)
    struct.pack_into('<I', output, config_offset, PACKED_MONO)
    return bytes(output)


def inspect_delta(before, after):
    old_chunks = chunks(before)
    assert old_chunks == chunks(after)
    fmt, _ = old_chunks[b'fmt ']
    offset = fmt + 0x14
    assert struct.unpack_from('<I', before, offset)[0] == LEGACY_MONO
    config = struct.unpack_from('<I', after, offset)[0]
    assert config == PACKED_MONO
    assert config & 0xFF == struct.unpack_from('<H', after, fmt + 2)[0] == 1
    assert (config >> 8) & 0xF == 1 and config >> 12 == 4
    assert len(before) == len(after)
    assert before[:offset] == after[:offset] and before[offset+4:] == after[offset+4:]
    differences = [i for i, (a, b) in enumerate(zip(before, after)) if a != b]
    assert differences == [offset, offset + 1]
    start, size = old_chunks[b'data']
    assert before[start:start+size] == after[start:start+size]
    return {'bytes': len(after), 'before_sha256': digest(before), 'after_sha256': digest(after),
            'config_offset': offset, 'old_config': hex(LEGACY_MONO), 'new_config': hex(config),
            'changed_byte_offsets': differences, 'compressed_data_identical': True,
            'every_other_header_field_identical': True}


def files_under(folder):
    return {p.relative_to(folder).as_posix(): p.read_bytes()
            for p in folder.rglob('*') if p.is_file()}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--wk-cli', type=Path, required=True)
    parser.add_argument('--output-dir', type=Path, default=ROOT/'releases')
    args = parser.parse_args()
    base = ROOT/'releases'/BASE_ZIP
    assert digest(base.read_bytes()) == BASE_SHA256
    with zipfile.ZipFile(base) as source:
        assert source.testzip() is None and len(source.namelist()) == 131
        payload = {name: source.read(name) for name in source.namelist()}
    # Every production file remains at the already game-tested source version.
    for name, body in payload.items():
        assert (ROOT/name).read_bytes() == body, 'Production source changed: '+name
    source_hashes = {name: digest(body) for name, body in payload.items()}
    wk = args.wk_cli.resolve()
    def run(*argv):
        subprocess.run([str(wk), *map(str, argv)], check=True)
    with tempfile.TemporaryDirectory(prefix='ncpd-wem-header-') as temp:
        temp = Path(temp)
        original = temp/'original.archive'
        original.write_bytes(payload[ARCHIVE])
        staging = temp/'NCPDPatrol_QuestGiverTest'
        staging.mkdir()
        run('extract', original, '--outpath', staging)
        original_files = files_under(staging)
        assert len(original_files) == 16
        expected = set(json.loads((ROOT/'assets/quest_giver_test/compiled.json').read_text())['resources'])
        assert set(original_files) == {DEPOT+name for name in expected}
        deltas = {}
        for name in VOICES:
            path = DEPOT+name
            before = original_files[path]
            after = patch_header(before)
            deltas[path] = inspect_delta(before, after)
            (staging/path).write_bytes(after)
        packed = temp/'packed'
        packed.mkdir()
        run('pack', staging, '--outpath', packed)
        archive = packed/'NCPDPatrol_QuestGiverTest.archive'
        extracted = temp/'extracted'
        extracted.mkdir()
        run('extract', archive, '--outpath', extracted)
        actual = files_under(extracted)
        assert set(actual) == set(original_files)
        for name, before in original_files.items():
            assert actual[name] == (patch_header(before) if name in deltas else before), name
        payload[ARCHIVE] = archive.read_bytes()
    payload[NOTE_NAME] = NOTE.encode('utf-8')
    assert {name for name in source_hashes if source_hashes[name] != digest(payload[name])} == {ARCHIVE}
    for name, body in payload.items():
        if name not in (ARCHIVE, NOTE_NAME):
            assert digest(body) == source_hashes[name]
    output_dir = args.output_dir.resolve()
    output_dir.mkdir(parents=True, exist_ok=True)
    target = output_dir/NAME
    with zipfile.ZipFile(target, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=9) as output:
        for name, body in sorted(payload.items()):
            info = zipfile.ZipInfo(name, (2026, 11, 24, 0, 0, 0))
            info.create_system = 3
            info.external_attr = 0o100644 << 16
            info.compress_type = zipfile.ZIP_DEFLATED
            output.writestr(info, body, compresslevel=9)
    with zipfile.ZipFile(target) as output:
        assert output.testzip() is None
        assert len(output.namelist()) == len(set(output.namelist())) == 132
        assert {name: output.read(name) for name in output.namelist()} == payload
    for name, before in source_hashes.items():
        assert digest((ROOT/name).read_bytes()) == before, 'Production source modified: '+name
    report = {'experiment': 'modern packed mono WEM channel configuration only',
              'baseline_zip': BASE_ZIP, 'baseline_sha256': BASE_SHA256,
              'source_commit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
              'install_files': 132, 'existing_install_files': 131,
              'production_source_files_unchanged': 131,
              'changed_existing_install_files': [ARCHIVE], 'added_test_note': NOTE_NAME,
              'archive_resources': 16, 'changed_archive_resources': deltas,
              'other_archive_resources_identical': 10, 'all_50_redscripts_identical': True,
              'all_47_lua_modules_identical': True, 'scene_and_lipsync_identical': True,
              'sample_rates_and_counts_identical': True, 'compressed_voice_audio_identical': True,
              'decoder_allocation_fields_unchanged': True,
              'not_an_official_wwise_reencode': True, 'no_global_audio_override': True,
              'actual_game_validation': False, 'root_cause_confirmed': False,
              'file': target.name, 'bytes': target.stat().st_size, 'sha256': digest(target.read_bytes()),
              'files': {name: digest(body) for name, body in payload.items()}}
    (output_dir/'NCPD_Patrol_WEM_Channel_Header_verification.json').write_text(json.dumps(report, indent=2)+'\n')
    print(json.dumps({k: report[k] for k in ('experiment', 'install_files', 'production_source_files_unchanged', 'file', 'bytes', 'sha256', 'root_cause_confirmed')}, indent=2))


if __name__ == '__main__':
    main()
