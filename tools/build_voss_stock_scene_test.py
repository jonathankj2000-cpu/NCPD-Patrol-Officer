"""Build a stock-voice control inside the existing Voss scene, not a new player."""
from pathlib import Path
import argparse
import copy
import hashlib
import json
import subprocess
import sys
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]
BASE = 'NCPD_Patrol_v0.20f1_Dialogue_Handoff_TEST.zip'
BASE_SHA = 'd6493b500015e0877d28b4d85570ad9ec165a07c877c7ceb75643b1b61cc9bb4'
NAME = 'NCPD_Patrol_Voss_STOCK_SCENE_TEST.zip'
ARCHIVE = 'archive/pc/mod/NCPDPatrol_QuestGiverTest.archive'
SCENE = 'base/ncpd_patrol/quest_giver_test/conversation.scene'
LENGTH_STUB = 'r6/scripts/NCPDPatrolVossLengthTest/NCPDPatrolVossLengthTest.reds'
HELPER = 'bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrolVoiceAB/'
# These four IDs already play as V's replies in this exact scene.
STOCK_IDS = ('1938843197804515328', '1895381798296993792',
             '1938900123686932480', '1714373979483803648')
REPLACEMENTS = dict(zip((1, 513, 1025, 1537, 1793, 2305),
                       (*STOCK_IDS, STOCK_IDS[0], STOCK_IDS[1])))


def sha(body):
    return hashlib.sha256(body).hexdigest()


def root(document):
    return document['Data']['RootChunk']


def stock_scene(before):
    after = copy.deepcopy(before)
    lines = root(after)['screenplayStore']['lines']
    original_v = [str(line['locstringId']['ruid']) for line in lines if line['speaker']['id'] == 1]
    assert tuple(original_v) == STOCK_IDS, 'The known working native replies changed'
    assert len(lines) == 10
    changed = []
    for line in lines:
        if line['speaker']['id'] != 0:
            continue
        item = line['itemId']['id']
        assert item in REPLACEMENTS
        old = str(line['locstringId']['ruid'])
        assert old not in STOCK_IDS, 'Input is already the stock control'
        line['locstringId']['ruid'] = REPLACEMENTS[item]
        changed.append({'item_id': item, 'before': old, 'after': REPLACEMENTS[item]})
    assert len(changed) == 6
    validate_delta(before, after)
    return after, changed


def validate_delta(before, after):
    """Accept exactly six reviewed ID substitutions; reject every other change."""
    restored = copy.deepcopy(root(after))
    old_lines = root(before)['screenplayStore']['lines']
    new_lines = restored['screenplayStore']['lines']
    assert len(old_lines) == len(new_lines) == 10
    count = 0
    for old, new in zip(old_lines, new_lines):
        if old['speaker']['id'] == 0:
            assert str(new['locstringId']['ruid']) == REPLACEMENTS[old['itemId']['id']]
            assert str(old['locstringId']['ruid']) != str(new['locstringId']['ruid'])
            new['locstringId']['ruid'] = old['locstringId']['ruid']
            count += 1
    assert count == 6 and restored == root(before), 'Unexpected scene mutation'
    assert all(str(line['locstringId']['ruid']) in STOCK_IDS
               for line in root(after)['screenplayStore']['lines'])


def tree(folder):
    return {p.relative_to(folder).as_posix(): p.read_bytes()
            for p in folder.rglob('*') if p.is_file()}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--wk-cli', type=Path, required=True)
    parser.add_argument('--compiler', type=Path, required=True)
    args = parser.parse_args()
    original = ROOT/'releases'/BASE
    assert sha(original.read_bytes()) == BASE_SHA
    with zipfile.ZipFile(original) as z:
        assert z.testzip() is None and len(z.namelist()) == len(set(z.namelist())) == 131
        payload = {name: z.read(name) for name in z.namelist()}
    hashes = {name: sha(body) for name, body in payload.items()}
    for name, body in payload.items():
        assert (ROOT/name).read_bytes() == body, 'Production source changed: '+name

    wk = args.wk_cli.resolve()
    def run(*argv):
        subprocess.run([str(wk), *map(str, argv)], check=True)

    with tempfile.TemporaryDirectory(prefix='voss-stock-scene-') as temp:
        temp = Path(temp)
        checks = temp/'checks.json'
        subprocess.run([sys.executable, str(ROOT/'tests/audio_trace/check_stock_scene.py'),
                        '--compiler', str(args.compiler.resolve()), '--report', str(checks)],
                       check=True, cwd=ROOT)
        tests = json.loads(checks.read_text())
        source = temp/'original.archive'
        source.write_bytes(payload[ARCHIVE])
        staging = temp/'NCPDPatrol_QuestGiverTest'
        staging.mkdir()
        run('extract', source, '--outpath', staging)
        originals = tree(staging)
        assert len(originals) == 16 and SCENE in originals
        serialized = temp/'serialized'
        serialized.mkdir()
        run('convert', 'serialize', staging/SCENE, '--outpath', serialized)
        document = serialized/'conversation.scene.json'
        before = json.loads(document.read_text(encoding='utf-8-sig'))
        after, replacements = stock_scene(before)
        document.write_text(json.dumps(after, indent=2)+'\n')
        compiled = temp/'compiled'
        compiled.mkdir()
        run('convert', 'deserialize', document, '--outpath', compiled)
        binary = (compiled/'conversation.scene').read_bytes()
        assert binary[:4] == b'CR2W' and binary != originals[SCENE]
        (staging/SCENE).write_bytes(binary)
        packed = temp/'packed'
        packed.mkdir()
        run('pack', staging, '--outpath', packed)
        archive = packed/'NCPDPatrol_QuestGiverTest.archive'
        extracted = temp/'extracted'
        extracted.mkdir()
        run('extract', archive, '--outpath', extracted)
        actual = tree(extracted)
        assert set(actual) == set(originals)
        assert {name for name in actual if actual[name] != originals[name]} == {SCENE}
        assert actual[SCENE] == binary
        roundtrip = temp/'roundtrip'
        roundtrip.mkdir()
        run('convert', 'serialize', extracted/SCENE, '--outpath', roundtrip)
        final_scene = json.loads((roundtrip/'conversation.scene.json').read_text(encoding='utf-8-sig'))
        validate_delta(before, final_scene)
        assert root(final_scene) == root(after)
        payload[ARCHIVE] = archive.read_bytes()

    payload[LENGTH_STUB] = (ROOT/'tools/voice_ab/recovery/NCPDPatrolVossLengthTest.reds').read_bytes()
    payload[HELPER+'init.lua'] = (ROOT/'tools/stock_scene/disabled_voice_ab.lua').read_bytes()
    note = (ROOT/'tools/stock_scene/README.txt').read_bytes()
    payload[HELPER+'README.txt'] = note
    payload['NCPDPatrol_Voss_STOCK_SCENE_TEST.txt'] = note
    assert len(payload) == 135
    assert {name for name in hashes if sha(payload[name]) != hashes[name]} == {ARCHIVE}
    target = ROOT/'releases'/NAME
    with zipfile.ZipFile(target, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        for name, body in sorted(payload.items()):
            info = zipfile.ZipInfo(name, (2026, 11, 26, 0, 0, 0))
            info.create_system = 3
            info.external_attr = 0o100644 << 16
            info.compress_type = zipfile.ZIP_DEFLATED
            z.writestr(info, body, compresslevel=9)
    with zipfile.ZipFile(target) as z:
        assert z.testzip() is None and len(z.namelist()) == len(set(z.namelist())) == 135
        assert {name: z.read(name) for name in z.namelist()} == payload
    for name, digest in hashes.items():
        assert sha((ROOT/name).read_bytes()) == digest, 'Production source modified: '+name
    report = {'experiment': 'Original native voice IDs inside the existing Voss quest scene',
              'source_commit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
              'baseline': BASE, 'baseline_sha256': BASE_SHA, 'install_files': 135,
              'changed_production_payload_files': [ARCHIVE], 'changed_archive_resources': [SCENE],
              'scene_delta': replacements, 'all_10_speech_slots_events_actors_edges_and_timings_identical': True,
              'all_original_wems_and_other_15_resources_identical': True,
              'all_131_production_source_files_identical': True,
              'length_experiment_disabled': True, 'silent_direct_voice_helper_disabled': True,
              'native_audio_redistributed': False, 'official_wwise_reencode': False,
              'test_changes_native_vo_ids_and_lookup_not_encoder_alone': True,
              'actual_game_validation': False, 'root_cause_confirmed': False, 'tests': tests,
              'file': NAME, 'bytes': target.stat().st_size, 'sha256': sha(target.read_bytes()),
              'files': {name: sha(body) for name, body in payload.items()}}
    (ROOT/'releases/NCPD_Patrol_Voss_STOCK_SCENE_verification.json').write_text(json.dumps(report, indent=2)+'\n')
    print(json.dumps({key: report[key] for key in ('experiment', 'install_files', 'file', 'bytes', 'sha256', 'actual_game_validation')}, indent=2))


if __name__ == '__main__':
    main()
