"""Build only the temporary CET trace, preserving the complete production mod."""
from pathlib import Path
import hashlib,json,subprocess,sys,tempfile,zipfile
ROOT=Path(__file__).resolve().parents[1]
NAME='NCPD_Patrol_Audio_Trace_v0.1_TEST.zip'
PREFIX='bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrolAudioTrace/'
BASE='2d291733dd38f04a39b3dc51e5cfce65cc42efae'

def main():
    baseline=json.loads((ROOT/'releases/NCPD_Patrol_v0.20f1_Dialogue_Handoff_verification.json').read_text())
    for path,row in baseline['files'].items():assert hashlib.sha256((ROOT/path).read_bytes()).hexdigest()==row['sha256'],path
    with tempfile.TemporaryDirectory(prefix='ncpd-audio-trace-test-') as tmp:
        path=Path(tmp)/'test.json'
        subprocess.run([sys.executable,str(ROOT/'tests/audio_trace/check_trace.py'),'--report',str(path)],cwd=ROOT,check=True)
        tests=json.loads(path.read_text())
    files={PREFIX+name:(ROOT/'tools/audio_trace'/name).read_bytes() for name in ['init.lua','README.txt']}
    archive=ROOT/'releases'/NAME
    with zipfile.ZipFile(archive,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=9) as z:
        for name,body in sorted(files.items()):
            info=zipfile.ZipInfo(name,(2026,11,24,0,0,0));info.create_system=3;info.external_attr=0o100644<<16;info.compress_type=zipfile.ZIP_DEFLATED
            z.writestr(info,body,compresslevel=9)
    with zipfile.ZipFile(archive) as z:
        assert z.testzip() is None and len(z.namelist())==2
        for name,body in files.items():assert z.read(name)==body
    body=archive.read_bytes()
    report={'version':'audio-trace-0.1','production_reference_commit':BASE,'production_install_files_unchanged':len(baseline['files']),
        'install_files':2,'only_new_separate_cet_helper_folder':True,'native_scripts_added':False,
        'audio_quest_and_playback_settings_changed':False,'tests':tests,'actual_game_validation':False,
        'native_callback_delivery_verified':False,'native_wwise_mixer_measured':False,
        'path':archive.relative_to(ROOT).as_posix(),'bytes':len(body),'sha256':hashlib.sha256(body).hexdigest(),
        'files':{name:hashlib.sha256(data).hexdigest() for name,data in files.items()}}
    (ROOT/'releases/NCPD_Patrol_Audio_Trace_v0.1_verification.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(report,indent=2))

if __name__=='__main__':main()
