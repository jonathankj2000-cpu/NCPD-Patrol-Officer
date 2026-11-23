"""Check a private native VO-context experiment, without emulating the mixer.

Roundtrip/extraction is verified when building the archive. Hearing continuous
ambience and unchanged voice levels still requires a game test.
"""
from pathlib import Path
import argparse,copy,hashlib,json,subprocess,sys
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools'));import build_quest_giver_assets as assets
from audio_source import AUDIO_ASSETS,without_ambient_mix
BASE='a70f6c697ec39ef502b8e3bec5f610a33b96b4a3'

def old(path):return subprocess.check_output(['git','show',BASE+':'+path],cwd=ROOT)

def main():
    docs,_=assets.outputs();assets.validate(docs)
    current=docs['conversation.scene.json']
    assert without_ambient_mix(current)==json.loads(old('assets/quest_giver_test/conversation.scene.json'))
    root=current['Data']['RootChunk'];speakers=[]
    for row in root['sceneGraph']['Data']['graph']:
        for event in row['Data'].get('events',[]):
            event=event['Data']
            if event['$type']=='scnDialogLineEvent':
                speakers.append(root['screenplayStore']['lines'][event['screenplayLineId']['id']>>8]['speaker']['id'])
                assert event['voParams']['customVoEvent']==assets.cn('None')
    assert speakers.count(0)==6 and speakers.count(1)==4
    bad=copy.deepcopy(docs)
    first=next(e['Data'] for n in bad['conversation.scene.json']['Data']['RootChunk']['sceneGraph']['Data']['graph'] for e in n['Data'].get('events',[]) if e['Data']['$type']=='scnDialogLineEvent')
    first['voParams']['voContext']='Vo_Context_Quest'
    try:assets.validate(bad)
    except AssertionError:pass
    else:raise AssertionError('A remaining quest-priority line was accepted')
    paths=subprocess.check_output(['git','ls-tree','-r','--name-only',BASE,'--','assets/quest_giver_test'],cwd=ROOT,text=True).splitlines()
    for path in paths:
        if path not in AUDIO_ASSETS:assert (ROOT/path).read_bytes()==old(path),path
    compiled=assets.read('compiled.json')
    assert compiled['roundtrip_validated'] and compiled['extracted_resource_bytes_compared']
    assert hashlib.sha256((ROOT/compiled['archive_path']).read_bytes()).hexdigest()==compiled['archive_sha256']
    for path,digest in compiled['authored_inputs'].items():assert hashlib.sha256((ROOT/path).read_bytes()).hexdigest()==digest,path
    for path in ['r6/scripts/NCPDPatrol/NCPDPatrolQuestGiverTest.reds','r6/scripts/NCPDPatrol/NCPDPatrolVossSubtitles.reds','bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrol/quest_giver_test.lua']:
        assert (ROOT/path).read_bytes()==old(path),path
    result={'baseline':BASE,'ten_private_line_contexts_changed':True,'all_other_scene_fields_and_timing_identical':True,
        'six_voss_and_four_v_lines_covered':True,'all_media_lipsync_captions_and_text_identical':True,
        'compiled_archive_roundtripped_and_extracted':True,'native_vo_context':'Vo_Context_Minor_Activity',
        'global_mix_and_volume_settings_modified':False,'native_mixer_cause_confirmed':False,'actual_game_validation':False}
    p=argparse.ArgumentParser();p.add_argument('--report',type=Path);a=p.parse_args()
    if a.report:a.report.write_text(json.dumps(result,indent=2)+'\n')
    print('PASS: only ten private dialogue mix contexts/cache hash changed; all other scene fields, audio/lipsync/captions/timing retained; roundtripped archive; audible mixer result unverified')

if __name__=='__main__':main()
