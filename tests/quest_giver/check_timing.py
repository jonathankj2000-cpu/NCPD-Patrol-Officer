"""Check actual authored turn boundaries against WEM lengths and startup jitter.

Native playback/UI latency is not observable here. The 0--2 s envelope comes
from the user's overlap report; it is a bounded scheduling check, not an
audio-completion callback or a claim that a game recording was inspected.
"""
from pathlib import Path
import argparse,copy,json,subprocess,sys

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools'))
import build_quest_giver_assets as assets
from check_voss_media import wem_info

BASE='a890a40a9aafb4c6ebf37975d7465bfcf8339cec'

def audit(scene,contract):
    root=scene['Data']['RootChunk']
    nodes={n['Data']['nodeId']['id']:n['Data'] for n in root['sceneGraph']['Data']['graph']}
    cursor=1;elapsed=0;timelines=[];visited=set()
    while True:
        assert cursor not in visited,'Cycle in automatic conversation'
        visited.add(cursor);node=nodes[cursor]
        if node['$type']=='scnEndNode':break
        if node['$type']=='scnSectionNode':
            length=node['sectionDuration']['stu']/1000
            for wrapped in node['events']:
                event=wrapped['Data']
                if event['$type']!='scnDialogLineEvent':continue
                packed=event['screenplayLineId']['id'];assert packed&255==1
                index=packed>>8;line=root['screenplayStore']['lines'][index]
                assert line['itemId']['id']==packed
                row=contract['conversation'][index]
                start=event['startTime']/1000;end=start+event['duration']/1000
                assert abs(length-end)<.001,'Speech event must cover its section tail'
                if row['speaker']=='voss':
                    audio=wem_info((assets.DIR/'media'/row['wem']).read_bytes())['duration_seconds']
                    # All observed overlaps (up to two seconds) must fit
                    # within this line's active event, before its output edge.
                    for startup in [0,.5,1,1.5,2]:
                        voice_end=start+startup+audio
                        assert end>=voice_end,'Native voice could outlive its line'
                        assert length-voice_end>=.5,'Next turn could overlap Voss'
                    timelines.append({'turn':row['key'],'event_at_seconds':round(elapsed+start,3),
                        'audio_seconds':audio,'latest_modelled_voice_end':round(elapsed+start+2+audio,3),
                        'next_turn_at_seconds':round(elapsed+length,3)})
            elapsed+=length
        cursor=node['outputSockets'][0]['destinations'][0]['nodeId']['id']
    assert len(timelines)==6 and len(visited)==14
    return timelines,elapsed

def main():
    c=assets.read('contract.json');scene=assets.read('conversation.scene.json')
    timeline,total=audit(scene,c)
    def rejected(bad_scene,bad_contract):
        try:audit(bad_scene,bad_contract)
        except AssertionError:return True
        raise AssertionError('Unsafe dialogue timing accepted')
    old_scene=json.loads(subprocess.check_output(['git','show',BASE+':assets/quest_giver_test/conversation.scene.json'],cwd=ROOT))
    old_contract=json.loads(subprocess.check_output(['git','show',BASE+':assets/quest_giver_test/contract.json'],cwd=ROOT))
    assert rejected(old_scene,old_contract)
    # A long section alone cannot keep the subtitle/lipsync event alive.
    bad=copy.deepcopy(scene)
    first=next(n['Data'] for n in bad['Data']['RootChunk']['sceneGraph']['Data']['graph'] if n['Data']['nodeId']['id']==2)
    first['events'][0]['Data']['duration']=13900
    assert rejected(bad,c)
    blocks=0;shortest=1000
    for row in c['conversation']:
        if row['speaker']!='voss':continue
        parts=row['subtitle_parts'];assert ' '.join(p['text'] for p in parts)==row['text']
        # Independent readability bounds: no subsecond flash or oversized
        # return of the original whole-paragraph wall of text.
        changes=[0]+[p['start_seconds']+c['timing']['subtitle_delay_ms']/1000 for p in parts[1:]]
        changes.append((assets.turn_ms(row,c['timing'])+c['timing']['section_tail_ms'])/1000)
        for i,part in enumerate(parts):
            hold=changes[i+1]-changes[i];shortest=min(shortest,hold)
            assert hold>=3 and len(part['text'])<=160,(row['key'],part,hold)
        before=next(r for r in old_contract['conversation'] if r['key']==row['key'])
        assert row['text']==before['text'] and row['clip']==before['clip']
        blocks+=len(parts)
    assert blocks==19
    # Author-supplied Wwise re-exports preserve the original WAV content and
    # duration; the facial bank and native V replies remain byte-identical.
    media=assets.read('media/manifest.json')
    old_media=json.loads(subprocess.check_output(['git','show',BASE+':assets/quest_giver_test/media/manifest.json'],cwd=ROOT))
    assert media['source_uploads']==old_media['source_uploads']
    for name in media['packaged']:
        path='assets/quest_giver_test/media/'+name
        if name.endswith('.wem'):
            info=wem_info((ROOT/path).read_bytes());exported=media['conversion']['exports'][name]
            assert exported['independent_decode_succeeded'] and exported['aligned_waveform_correlation']>0.98
            original=media['source_uploads'][exported['source_wav']]
            assert abs(info['duration_seconds']-original['duration_seconds'])<1/48000
        else:assert (ROOT/path).read_bytes()==subprocess.check_output(['git','show',BASE+':'+path],cwd=ROOT)
    assert [r for r in c['conversation'] if r['speaker']=='v']==[r for r in old_contract['conversation'] if r['speaker']=='v']
    report={'baseline':BASE,'timeline':timeline,'scene_seconds':round(total,3),'modelled_startup_delays_seconds':[0,.5,1,1.5,2],
        'no_overlap_with_reported_two_second_startup_envelope':True,'previous_scene_rejected':True,
        'caption_blocks':blocks,'minimum_caption_hold_seconds':round(shortest,3),
        'facial_bank_and_four_native_v_lines_byte_identical':True,
        'six_wwise_exports_preserve_original_wav_content_and_duration':True,
        'actual_game_voice_completion_observed':False,'actual_game_validation':False}
    parser=argparse.ArgumentParser();parser.add_argument('--report',type=Path);args=parser.parse_args()
    if args.report:args.report.write_text(json.dumps(report,indent=2)+'\n')
    print('PASS: authored scene prevents next-turn overlap for 0--2 s modelled VO startup; old timing and short line rejected; 19 captions held >=3 s; Wwise export durations, original facial bank and V replies retained (game latency not measured)')

if __name__=='__main__':main()
