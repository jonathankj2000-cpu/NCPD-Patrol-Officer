"""Package the verified v0.20g developer sources as one complete main build."""
from pathlib import Path
import argparse
import hashlib
import json
import subprocess
import zipfile

from lupa.luajit21 import LuaRuntime
from nexus_release import original_payload

ROOT = Path(__file__).resolve().parents[1]
TESTED = 'NCPD_Patrol_v0.20g_Wwise_Voice_Fix_TEST.zip'
TESTED_SHA = '3300562f97c3039b1eb1b176d8446d0dbe253868c02a887829a46fde983fcb6a'
NAME = 'NCPD_Patrol_v0.20g_Complete.zip'
REPORT = 'NCPD_Patrol_v0.20g_Complete_verification.json'
ARCHIVE = 'archive/pc/mod/NCPDPatrol_QuestGiverTest.archive'
LENGTH_STUB = 'r6/scripts/NCPDPatrolVossLengthTest/NCPDPatrolVossLengthTest.reds'
VOICE_HELPER = 'bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrolVoiceAB/init.lua'
NEXUS = 'releases/NCPD_Patrol_v0.8.7_Nexus_Release.zip'
NEXUS_SHA = 'ba0b70e0c0ec180dd839fd8878c9fd6acef8f794520047d573745edc91f46aec'


def sha(body):
    return hashlib.sha256(body).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--compiler', type=Path, required=True)
    args = parser.parse_args()
    tested_path = ROOT/'releases'/TESTED
    assert sha(tested_path.read_bytes()) == TESTED_SHA
    with zipfile.ZipFile(tested_path) as archive:
        assert archive.testzip() is None
        tested = {name: archive.read(name) for name in archive.namelist()}
        assert len(tested) == len(archive.namelist()) == 135

    baseline = original_payload()
    files = {name: (ROOT/name).read_bytes() for name in baseline}
    # Promotion changes documentation and packaging only. Do not silently ship
    # untested runtime edits or revive any rejected audio experiment.
    assert len(files) == 131
    assert {name for name, body in files.items() if body != tested[name]} == {'README.txt'}
    native = {name for name in baseline if name.endswith('.reds')}
    assert len(native) == 50
    assert all(files[name] == baseline[name] for name in native)
    compiled = json.loads((ROOT/'assets/quest_giver_test/compiled.json').read_text())
    assert sha(files[ARCHIVE]) == compiled['archive_sha256']
    assert compiled['wwise_voice_fix']['other_ten_resources_byte_identical']
    validation = json.loads((ROOT/'assets/quest_giver_test/media/wwise_game_validation.json').read_text())
    assert validation['tested_package_sha256'] == TESTED_SHA
    assert validation['full_voss_briefing_background_audio_continuity_confirmed']
    assert len(validation['all_six_tested_wem_sha256']) == 6
    for name, digest in validation['all_six_tested_wem_sha256'].items():
        assert sha((ROOT/'assets/quest_giver_test/media'/name).read_bytes()) == digest

    files[LENGTH_STUB] = tested[LENGTH_STUB]
    recovery = ROOT/'tools/voice_ab/recovery/NCPDPatrolVossLengthTest.reds'
    assert recovery.read_bytes() == files[LENGTH_STUB]
    subprocess.run([str(args.compiler.resolve()), str(ROOT/'tests/audio_trace/length-api.reds'),
                    '--', str(recovery)], check=True)
    # Overwrite a previously installed comparison module without opening its
    # obsolete CET test window. This module has no callbacks or native calls.
    files[VOICE_HELPER] = b'-- Retired Voss voice experiment. Audio is integrated in the main quest archive.\n'
    lua = LuaRuntime()
    parse = lua.eval('function(body,name) local fn,err=loadstring(body,name);assert(fn,err) end')
    for name, body in files.items():
        if name.endswith('.lua'):
            parse(body.decode(), name)
    assert len(files) == 133 and not any(name.endswith(('.wav', '.mp3')) for name in files)
    assert sha((ROOT/NEXUS).read_bytes()) == NEXUS_SHA

    target = ROOT/'releases'/NAME
    with zipfile.ZipFile(target, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for name, body in sorted(files.items()):
            info = zipfile.ZipInfo(name, (2026, 11, 26, 0, 0, 0))
            info.create_system = 3
            info.external_attr = 0o100644 << 16
            info.compress_type = zipfile.ZIP_DEFLATED
            archive.writestr(info, body, compresslevel=9)
    with zipfile.ZipFile(target) as archive:
        assert archive.testzip() is None
        assert len(archive.namelist()) == len(set(archive.namelist())) == 133
        assert {name: archive.read(name) for name in archive.namelist()} == files
    for name in baseline:
        assert (ROOT/name).read_bytes() == files[name]
    assert sha(tested_path.read_bytes()) == TESTED_SHA
    result = {
        'version': 'v0.20g', 'flavour': 'Complete development build',
        'source_commit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
        'file': NAME, 'bytes': target.stat().st_size, 'sha256': sha(target.read_bytes()),
        'install_files': len(files), 'baseline_install_files': len(baseline),
        'game_tested_package': TESTED, 'game_tested_package_sha256': TESTED_SHA,
        'all_130_existing_runtime_and_license_files_identical_to_tested_package': True,
        'all_50_production_redscripts_identical_to_tested_package': True,
        'changed_original_install_files_since_game_test': ['README.txt'],
        'compatibility_only_files': [LENGTH_STUB, VOICE_HELPER],
        'obsolete_audio_test_window_removed': True,
        'full_voss_audio_continuity_author_confirmed': True,
        'confirmation': 'assets/quest_giver_test/media/wwise_game_validation.json',
        'repackaged_installation_independently_game_tested': False,
        'nexus_087_unchanged': True,
        'files': {name: sha(body) for name, body in sorted(files.items())},
    }
    (ROOT/'releases'/REPORT).write_text(json.dumps(result, indent=2)+'\n')
    print(json.dumps({key: result[key] for key in ('version', 'file', 'install_files', 'bytes', 'sha256')}, indent=2))


if __name__ == '__main__':
    main()
