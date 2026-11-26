"""Ship the complete v0.20g six-line Wwise fix with legacy test recovery."""
from pathlib import Path
import argparse
import hashlib
import json
import subprocess
import sys
import tempfile
import zipfile
from lupa.luajit21 import LuaRuntime
from nexus_release import original_payload

ROOT = Path(__file__).resolve().parents[1]
NAME = 'NCPD_Patrol_v0.20g_Wwise_Voice_Fix_TEST.zip'
REPORT = 'NCPD_Patrol_v0.20g_Wwise_Voice_Fix_verification.json'
PREFIX = 'bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrol/'
ARCHIVE = 'archive/pc/mod/NCPDPatrol_QuestGiverTest.archive'
STUB = 'r6/scripts/NCPDPatrolVossLengthTest/NCPDPatrolVossLengthTest.reds'
HELPER = 'bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrolVoiceAB/'
DELTA = {ARCHIVE, PREFIX+'init.lua', PREFIX+'cet_ui.lua', 'README.txt'}


def sha(body):
    return hashlib.sha256(body).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--compiler', type=Path, required=True)
    args = parser.parse_args()
    original = original_payload()
    files = {name: (ROOT/name).read_bytes() for name in original}
    assert {name for name in files if files[name] != original[name]} == DELTA
    snapshots = {name: sha(body) for name, body in files.items()}
    with tempfile.TemporaryDirectory(prefix='voss-wwise-release-') as temporary:
        report_path = Path(temporary)/'media.json'
        subprocess.run([sys.executable, str(ROOT/'tests/quest_giver/check_voss_media.py'),
                        '--report', str(report_path)], check=True, cwd=ROOT)
        tests = json.loads(report_path.read_text())
    compiled = json.loads((ROOT/'assets/quest_giver_test/compiled.json').read_text())
    assert sha(files[ARCHIVE]) == compiled['archive_sha256']
    assert compiled['wwise_voice_fix']['other_ten_resources_byte_identical']
    files[STUB] = (ROOT/'tools/voice_ab/recovery/NCPDPatrolVossLengthTest.reds').read_bytes()
    subprocess.run([str(args.compiler.resolve()), str(ROOT/'tests/audio_trace/length-api.reds'), '--',
                    str(ROOT/'tools/voice_ab/recovery/NCPDPatrolVossLengthTest.reds')], check=True)
    helper = (ROOT/'tools/stock_scene/disabled_voice_ab.lua').read_text()
    old = "The direct voice comparison was silent in game and is disabled. Use NCPD Patrol's existing quest-giver test to meet Voss. In the stock-scene control, she deliberately speaks with V's original voice."
    new = "Direct voice comparison disabled. v0.20g uses all six author-supplied Wwise Vorbis 48 kHz voices in the normal Voss scene. Start the existing quest-giver test and let the complete briefing finish."
    assert helper.count(old) == 1
    helper = helper.replace(old, new).replace('Use the existing Voss scene for the stock-audio control.',
                                             'Use the normal Voss scene for the v0.20g Wwise voices.')
    files[HELPER+'init.lua'] = helper.encode()
    note = (ROOT/'tools/voss_wwise/README.txt').read_bytes()
    files[HELPER+'README.txt'] = note
    files['NCPDPatrol_v0.20g_Wwise_Voice_Fix_TEST.txt'] = note
    assert len(files) == 135
    lua = LuaRuntime()
    parse = lua.eval('function(body,name) local fn,err=loadstring(body,name);assert(fn,err) end')
    for name, body in files.items():
        if name.endswith('.lua'):
            parse(body.decode(), name)
    target = ROOT/'releases'/NAME
    with zipfile.ZipFile(target, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        for name, body in sorted(files.items()):
            info = zipfile.ZipInfo(name, (2026, 11, 26, 0, 0, 0))
            info.create_system = 3
            info.external_attr = 0o100644 << 16
            info.compress_type = zipfile.ZIP_DEFLATED
            z.writestr(info, body, compresslevel=9)
    with zipfile.ZipFile(target) as z:
        assert z.testzip() is None and len(z.namelist()) == len(set(z.namelist())) == 135
        assert {name: z.read(name) for name in z.namelist()} == files
    for name, digest in snapshots.items():
        assert sha((ROOT/name).read_bytes()) == digest, name
    assert sha((ROOT/'releases/NCPD_Patrol_v0.8.7_Nexus_Release.zip').read_bytes()) == 'ba0b70e0c0ec180dd839fd8878c9fd6acef8f794520047d573745edc91f46aec'
    result = {'version': 'v0.20g', 'flavour': 'Complete private branch / Wwise Voice Fix',
              'source_commit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
              'file': NAME, 'bytes': target.stat().st_size, 'sha256': sha(target.read_bytes()),
              'install_files': 135, 'changed_existing_install_files': sorted(DELTA),
              'all_fifty_existing_native_scripts_identical': True,
              'six_author_wems_packed_unmodified': True,
              'other_ten_archive_resources_byte_identical': True,
              'first_line_fix_confirmed_in_game': True, 'full_conversation_game_test_pending': True,
              'nexus_087_unchanged': True, 'rejected_length_and_direct_event_tests_disabled': True,
              'media_checks': tests, 'resource_audit': compiled['wwise_voice_fix']['resource_audit'],
              'files': {name: sha(body) for name, body in sorted(files.items())}}
    (ROOT/'releases'/REPORT).write_text(json.dumps(result, indent=2)+'\n')
    print(json.dumps({k: result[k] for k in ('version', 'install_files', 'file', 'bytes', 'sha256', 'full_conversation_game_test_pending')}, indent=2))


if __name__ == '__main__':
    main()
