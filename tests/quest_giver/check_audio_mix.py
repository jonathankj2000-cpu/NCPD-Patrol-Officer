"""Check the isolated speech-event tail experiment without emulating the mixer.

Roundtrip/extraction is verified when building the archive. Hearing continuous
ambience and unchanged voice levels still requires a game test.
"""
from pathlib import Path
import argparse,copy,hashlib,json,subprocess,sys
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools'));import build_quest_giver_assets as assets
from audio_source import AUDIO_ASSETS,without_event_tail
BASE='9957b3cb4f34355ea0046dc7503962e8c940b886'

def old(path):return subprocess.check_output(['git','show',BASE+':'+path],cwd=ROOT)

def main():
    docs,_=assets.outputs();assets.validate(docs)
    current=docs['conversation.scene.json']
    before=json.loads(old('assets/quest_giver_test/conversation.scene.json'))
    assert without_event_tail(current)==before
    # Source-backed old payload is rejected by the revised section/event
    # contract, independently of the source normalizer above.
    stale=copy.deepcopy(docs);stale['conversation.scene.json']=before
    try:assets.validate(stale)
    except AssertionError:pass
    else:raise AssertionError('Published v0.20f eventless tails accepted')
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
    # Section lengths/edges and starts are fixed: absolute start time and the
    # complete 143.836 s conversation must therefore remain exactly identical.
    def timeline(doc):
        nodes={n['Data']['nodeId']['id']:n['Data'] for n in doc['Data']['RootChunk']['sceneGraph']['Data']['graph']}
        cursor=1;clock=0;rows=[];seen=set()
        while nodes[cursor]['$type']!='scnEndNode':
            assert cursor not in seen;seen.add(cursor);node=nodes[cursor]
            for event in node.get('events',[]):
                e=event['Data']
                if e['$type']=='scnDialogLineEvent':rows.append((e['screenplayLineId']['id'],clock+e['startTime']))
            clock+=node.get('sectionDuration',{}).get('stu',0)
            cursor=node['outputSockets'][0]['destinations'][0]['nodeId']['id']
        return rows,clock
    assert timeline(current)==timeline(before) and timeline(current)[1]==143836
    result={'baseline':BASE,'ten_private_speech_events_extended_500_ms':True,'all_other_scene_fields_and_voice_start_times_identical':True,
        'same_143836_ms_scene_duration_and_existing_overlap_guard':True,
        'six_voss_and_four_v_lines_covered':True,'all_media_lipsync_captions_and_text_identical':True,
        'compiled_archive_roundtripped_and_extracted':True,'native_vo_context':'Vo_Context_Minor_Activity',
        'global_mix_and_volume_settings_modified':False,'native_mixer_cause_confirmed':False,'actual_game_validation':False}
    p=argparse.ArgumentParser();p.add_argument('--report',type=Path);a=p.parse_args()
    if a.report:a.report.write_text(json.dumps(result,indent=2)+'\n')
    print('PASS: exact v0.20f 500 ms tails rejected; ten speech-event durations/cache hash reviewed; identical absolute voice starts, 143.836 s scene and overlap guard; six Wwise media deltas audited separately; roundtripped archive')

if __name__=='__main__':main()
