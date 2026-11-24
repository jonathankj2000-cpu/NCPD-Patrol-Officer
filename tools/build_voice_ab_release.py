"""Recover v0.20f1 timing and add a separate direct native voice comparison."""
from pathlib import Path
import argparse
import hashlib
import json
import subprocess
import sys
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]
BASE = 'NCPD_Patrol_v0.20f1_Dialogue_Handoff_TEST.zip'
BASE_HASH = 'd6493b500015e0877d28b4d85570ad9ec165a07c877c7ceb75643b1b61cc9bb4'
NAME = 'NCPD_Patrol_Voss_Audio_Control_TEST.zip'
SERVICE = 'r6/scripts/NCPDPatrolVossLengthTest/NCPDPatrolVossLengthTest.reds'
PREFIX = 'bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrolVoiceAB/'


def sha(data):
    return hashlib.sha256(data).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--compiler', type=Path, required=True)
    args = parser.parse_args()
    original = ROOT/'releases'/BASE
    assert sha(original.read_bytes()) == BASE_HASH
    with zipfile.ZipFile(original) as z:
        assert z.testzip() is None and len(z.namelist()) == 131
        files = {name: z.read(name) for name in z.namelist()}
    hashes = {name: sha(data) for name, data in files.items()}
    for name, data in files.items():
        assert (ROOT/name).read_bytes() == data, name
    with tempfile.TemporaryDirectory(prefix='voss-control-tests-') as temp:
        report_path = Path(temp)/'tests.json'
        subprocess.run([sys.executable, str(ROOT/'tests/audio_trace/check_voice_ab.py'),
                        '--compiler', str(args.compiler.resolve()), '--report', str(report_path)], check=True, cwd=ROOT)
        tests = json.loads(report_path.read_text())
    files[SERVICE] = (ROOT/'tools/voice_ab/recovery/NCPDPatrolVossLengthTest.reds').read_bytes()
    files[PREFIX+'init.lua'] = (ROOT/'tools/voice_ab/init.lua').read_bytes()
    files[PREFIX+'README.txt'] = (ROOT/'tools/voice_ab/README.txt').read_bytes()
    files['NCPDPatrol_Voss_Audio_Control_TEST.txt'] = files[PREFIX+'README.txt']
    assert len(files) == 135
    target = ROOT/'releases'/NAME
    with zipfile.ZipFile(target, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        for name, data in sorted(files.items()):
            info = zipfile.ZipInfo(name, (2026, 11, 24, 0, 0, 0))
            info.create_system = 3
            info.external_attr = 0o100644 << 16
            info.compress_type = zipfile.ZIP_DEFLATED
            z.writestr(info, data, compresslevel=9)
    with zipfile.ZipFile(target) as z:
        assert z.testzip() is None and len(z.namelist()) == len(set(z.namelist())) == 135
        assert {name: z.read(name) for name in z.namelist()} == files
    for name, digest in hashes.items():
        assert sha(files[name]) == digest and sha((ROOT/name).read_bytes()) == digest, name
    report = {'experiment': 'recovery and direct native stock/custom voice control',
              'source_commit': subprocess.check_output(['git','rev-parse','HEAD'], cwd=ROOT, text=True).strip(),
              'baseline': BASE, 'baseline_sha256': BASE_HASH, 'install_files': 135,
              'original_131_production_files_identical': True,
              'original_scene_timing_overlap_guards_and_media_restored': True,
              'failed_length_service_overwritten_with_inert_stub': True,
              'previous_successful_length_readback_did_not_fix_cuts_and_caused_overlap': True,
              'standalone_cet_test_only_after_explicit_button': True,
              'no_quest_scene_or_global_mixer_override': True,
              'tests': tests, 'added_or_replaced_test_files': [p for p in files if p not in hashes],
              'actual_game_validation': False, 'root_cause_confirmed': False,
              'file': NAME, 'bytes': target.stat().st_size, 'sha256': sha(target.read_bytes()),
              'files': {name: sha(data) for name, data in files.items()}}
    (ROOT/'releases/NCPD_Patrol_Voss_Audio_Control_verification.json').write_text(json.dumps(report, indent=2)+'\n')
    print(json.dumps({k:report[k] for k in ('experiment','install_files','original_131_production_files_identical','file','bytes','sha256','root_cause_confirmed')}, indent=2))


if __name__ == '__main__':main()
