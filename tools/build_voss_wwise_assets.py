"""Replace only the six Voss WEM resources; retain the working scene bytes."""
from pathlib import Path
import argparse
import hashlib
import json
import os
import subprocess
import tempfile
import zipfile
from voss_wem import inspect

ROOT = Path(__file__).resolve().parents[1]
MEDIA = ROOT/'assets/quest_giver_test/media'
BASE = ROOT/'releases/NCPD_Patrol_v0.20f1_Dialogue_Handoff_TEST.zip'
BASE_SHA = 'd6493b500015e0877d28b4d85570ad9ec165a07c877c7ceb75643b1b61cc9bb4'
ARCHIVE = 'archive/pc/mod/NCPDPatrol_QuestGiverTest.archive'
DEPOT = 'base/ncpd_patrol/quest_giver_test/'
VOICES = tuple('vossbriefing%02d.wem'%i for i in range(1, 7))


def sha(body):
    return hashlib.sha256(body).hexdigest()


def tree(folder):
    return {p.relative_to(folder).as_posix(): p.read_bytes()
            for p in folder.rglob('*') if p.is_file()}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--wk-cli', type=Path, required=True)
    args = parser.parse_args()
    manifest = json.loads((MEDIA/'manifest.json').read_text())
    audit = json.loads((MEDIA/'wwise_export_audit.json').read_text())
    assert set(audit['files']) == set(VOICES)
    replacements = {}
    for name in VOICES:
        body = (MEDIA/name).read_bytes()
        info = inspect(body)
        exported = audit['files'][name]
        assert sha(body) == exported['sha256'] == manifest['packaged'][name]['sha256']
        assert info['sample_frames'] == exported['sample_frames']
        assert exported['independent_decode_succeeded'] and exported['aligned_waveform_correlation'] > 0.98
        replacements[DEPOT+name] = body
    assert sha(BASE.read_bytes()) == BASE_SHA
    with zipfile.ZipFile(BASE) as z:
        original_archive = z.read(ARCHIVE)
    environment = dict(os.environ)
    def run(*argv):
        subprocess.run([str(args.wk_cli.resolve()), *map(str, argv)], env=environment, check=True)
    with tempfile.TemporaryDirectory(prefix='voss-six-wwise-') as temporary:
        temp = Path(temporary)
        original = temp/'original.archive'
        original.write_bytes(original_archive)
        stage = temp/'NCPDPatrol_QuestGiverTest'
        stage.mkdir()
        run('extract', original, '--outpath', stage)
        before = tree(stage)
        assert len(before) == 16 and replacements.keys() <= before.keys()
        for name, body in replacements.items():
            assert before[name] != body
            (stage/name).write_bytes(body)
        output = temp/'packed'
        output.mkdir()
        run('pack', stage, '--outpath', output)
        archive = output/'NCPDPatrol_QuestGiverTest.archive'
        extracted = temp/'extracted'
        extracted.mkdir()
        run('extract', archive, '--outpath', extracted)
        after = tree(extracted)
        assert set(after) == set(before)
        assert {n for n in before if before[n] != after[n]} == set(replacements)
        assert all(after[n] == body for n, body in replacements.items())
        assert sum(before[n] == after[n] for n in before) == 10
        body = archive.read_bytes()
        resource_audit = {n: {'before': sha(before[n]), 'after': sha(after[n])} for n in sorted(before)}
    compiled_path = ROOT/'assets/quest_giver_test/compiled.json'
    compiled = json.loads(compiled_path.read_text())
    allowed = {'assets/quest_giver_test/media/manifest.json',
               *('assets/quest_giver_test/media/'+name for name in VOICES)}
    for name, digest in compiled['authored_inputs'].items():
        current = sha((ROOT/name).read_bytes())
        assert current == digest or name in allowed, 'Unrelated authored input changed: '+name
        compiled['authored_inputs'][name] = current
    audit_path = 'assets/quest_giver_test/media/wwise_export_audit.json'
    compiled['authored_inputs'][audit_path] = sha((ROOT/audit_path).read_bytes())
    compiled['archive_sha256'] = sha(body)
    compiled['wwise_voice_fix'] = {'baseline_archive_sha256': sha(original_archive),
                                  'six_wems_replaced': True, 'other_ten_resources_byte_identical': True,
                                  'resource_audit': resource_audit,
                                  'whole_conversation_in_game_verified': False}
    (ROOT/ARCHIVE).write_bytes(body)
    compiled_path.write_text(json.dumps(compiled, indent=2)+'\n')
    print('PASS: six author-supplied 48-kHz Vorbis WEMs packed; other ten quest resources, including scene/map/lipsync/timing, byte-identical')


if __name__ == '__main__':
    main()
