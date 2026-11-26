"""Package the isolated native voice-length metadata test over pinned v0.20f1."""
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
NAME = 'NCPD_Patrol_VO_Lengths_TEST.zip'
NATIVE = 'r6/scripts/NCPDPatrolVossLengthTest/NCPDPatrolVossLengthTest.reds'
NOTE = 'NCPDPatrol_VO_Lengths_TEST.txt'


def sha(data):
    return hashlib.sha256(data).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--compiler', type=Path, required=True)
    parser.add_argument('--allow-rejected-experiment', action='store_true',
                        help='Historical reproduction only: this test caused overlapping voices in game')
    args = parser.parse_args()
    if not args.allow_rejected_experiment:
        parser.error('Rejected in-game experiment: cuts unchanged and V/Voss overlap introduced. Use the recovery/control package.')
    original = ROOT/'releases'/BASE
    assert sha(original.read_bytes()) == BASE_HASH
    with zipfile.ZipFile(original) as z:
        assert z.testzip() is None and len(z.namelist()) == 131
        files = {name: z.read(name) for name in z.namelist()}
    # No production payload/source edits are needed for this experiment.
    baseline = {name: sha(data) for name, data in files.items()}
    for name, data in files.items():
        assert (ROOT/name).read_bytes() == data, name
    with tempfile.TemporaryDirectory(prefix='ncpd-vo-length-test-') as temp:
        report_path = Path(temp)/'tests.json'
        subprocess.run([sys.executable, str(ROOT/'tests/audio_trace/check_length_metadata.py'),
                        '--compiler', str(args.compiler.resolve()), '--report', str(report_path)], check=True, cwd=ROOT)
        tests = json.loads(report_path.read_text())
    files[NATIVE] = (ROOT/'tools/voss_length_test/NCPDPatrolVossLengthTest.reds').read_bytes()
    files[NOTE] = (ROOT/'tools/voss_length_test/README.txt').read_bytes()
    target = ROOT/'releases'/NAME
    with zipfile.ZipFile(target, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        for name, data in sorted(files.items()):
            info = zipfile.ZipInfo(name, (2026, 11, 24, 0, 0, 0))
            info.create_system = 3
            info.external_attr = 0o100644 << 16
            info.compress_type = zipfile.ZIP_DEFLATED
            z.writestr(info, data, compresslevel=9)
    with zipfile.ZipFile(target) as z:
        assert z.testzip() is None and len(z.namelist()) == len(set(z.namelist())) == 133
        assert {name: z.read(name) for name in z.namelist()} == files
    for name, digest in baseline.items():
        assert sha(files[name]) == digest and sha((ROOT/name).read_bytes()) == digest, name
    result = {'experiment': 'register six private native English Voss VO lengths',
              'source_commit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
              'baseline': BASE, 'baseline_sha256': BASE_HASH, 'tests': tests,
              'install_files': 133, 'existing_131_install_files_identical': True,
              'existing_50_redscripts_and_47_lua_modules_identical': True,
              'all_10_archives_and_original_wems_identical': True,
              'only_added_install_files': [NATIVE, NOTE], 'new_native_services': 1,
              'global_playback_or_gameplay_overrides': False,
              'header_experiment_stacked': False, 'actual_game_validation': False,
              'native_callback_delivery_confirmed': False, 'audible_fix_confirmed': False,
              'file': NAME, 'bytes': target.stat().st_size, 'sha256': sha(target.read_bytes()),
              'files': {name: sha(data) for name, data in files.items()}}
    (ROOT/'releases/NCPD_Patrol_VO_Lengths_verification.json').write_text(json.dumps(result, indent=2)+'\n')
    print(json.dumps({k: result[k] for k in ('experiment', 'install_files', 'existing_131_install_files_identical', 'file', 'bytes', 'sha256', 'audible_fix_confirmed')}, indent=2))


if __name__ == '__main__':
    main()
