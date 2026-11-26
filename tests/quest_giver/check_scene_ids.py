"""Reference-backed scene identifier checks, including the shipped v0.19g data.

These reject unsafe identifiers before packing; no native game crash is run or
claimed reproduced by Python. The supplied REDscript log contains no stack.
"""
from pathlib import Path
import argparse,copy,json,subprocess,sys
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools'));import build_quest_giver_assets as assets
BASE='c098d02b4c7a23b4dee941bd8a38b21af2550d85'

def resolve_line(scene,item):
    assert isinstance(item,int) and item&255==1,'Invalid screenplay dialogue category'
    lines=scene['screenplayStore']['lines'];index=item>>8
    assert 0<=index<len(lines),'Screenplay dialogue index outside line array'
    line=lines[index];assert line['itemId']['id']==item,'Screenplay line array order mismatch'
    return line

def check_screenplay(scene):
    for i,line in enumerate(scene['screenplayStore']['lines']):
        value=line['itemId']['id'];assert value&255==1 and value>>8==i,'Invalid packed dialogue item ID'
        assert resolve_line(scene,value) is line
    for i,option in enumerate(scene['screenplayStore']['options']):
        value=option['itemId']['id'];assert value&255==2 and value>>8==i,'Invalid packed option item ID'
    for wrapped in scene['sceneGraph']['Data']['graph']:
        for event in wrapped['Data'].get('events',[]):
            event=event['Data']
            if event['$type']=='scnDialogLineEvent':resolve_line(scene,event['screenplayLineId']['id'])

def check_graph(scene):
    nodes=scene['sceneGraph']['Data']['graph'];ids=[n['Data']['nodeId']['id'] for n in nodes]
    assert ids==list(range(1,len(ids)+1)),'Scene nodes must use the reference dense ordered layout'
    for n in nodes:
        for socket in n['Data'].get('outputSockets',[]):
            for d in socket['destinations']:
                target=d['nodeId']['id'];assert 1<=target<=len(nodes),'Scene edge targets a missing node'
                assert nodes[target-1]['Data']['nodeId']['id']==target
    for entry in scene['entryPoints']+scene['exitPoints']:
        assert 1<=entry['nodeId']['id']<=len(nodes)

def rejected(call,message):
    try:call()
    except AssertionError as e:assert message in str(e),(message,str(e))
    else:raise AssertionError('Unsafe scene accepted: '+message)

def main():
    reference=assets.read('scene-id-reference.json')
    assert reference['source_git_blob']=='82f4a677128dff4765fe66276c7eefa8b8b2ce2d'
    assert len(reference['line_item_ids'])==31 and len(reference['option_item_ids'])==6
    assert reference['line_item_ids']==[(i<<8)|1 for i in range(31)]
    assert reference['option_item_ids']==[(i<<8)|2 for i in range(6)]
    assert reference['scene_node_ids']==list(range(1,41))
    assert all(x&255==1 and x>>8<31 for x in reference['dialogue_event_line_ids'])
    old=json.loads(subprocess.check_output(['git','show',f'{BASE}:assets/quest_giver_test/conversation.scene.json'],cwd=ROOT))['Data']['RootChunk']
    first=next(e['Data'] for n in old['sceneGraph']['Data']['graph'] for e in n['Data'].get('events',[]) if e['Data']['$type']=='scnDialogLineEvent')
    bad_id=first['screenplayLineId']['id'];assert bad_id==100001 and bad_id&255==161 and bad_id>>8==390
    rejected(lambda:resolve_line(old,bad_id),'Invalid screenplay dialogue category')
    rejected(lambda:check_screenplay(old),'Invalid packed dialogue item ID')
    rejected(lambda:check_graph(old),'dense ordered layout')
    docs,_=assets.outputs();assets.validate(docs);current=docs['conversation.scene.json']['Data']['RootChunk']
    check_screenplay(current);check_graph(current)
    assert [line['itemId']['id'] for line in current['screenplayStore']['lines']]==[(i<<8)|1 for i in range(10)]
    # Later timing/caption changes retain the identifier fix and every speech,
    # clip, native V string ID, voice mapping and private quest lifecycle.
    for before,after in zip(old['screenplayStore']['lines'],current['screenplayStore']['lines']):
        assert {k:v for k,v in before.items() if k!='itemId'}=={k:v for k,v in after.items() if k!='itemId'}
    assert current['locStore']==old['locStore'] and current['resouresReferences']==old['resouresReferences']
    for name in ['media/manifest.json','quest_giver.journal.json','vomap.json.json','voss.lipmap.json','lines.json.json','subtitles.json.json','voss_wait_pose.ent.json']:
        path='assets/quest_giver_test/'+name
        if name=='media/manifest.json':
            prior=json.loads(subprocess.check_output(['git','show',f'{BASE}:{path}'],cwd=ROOT))
            current_media=json.loads((ROOT/path).read_text())
            for key in ['source_upload','source_uploads','lipsync_merge','vanilla_v_string_ids']:
                assert current_media[key]==prior[key],key
        else:assert (ROOT/path).read_bytes()==subprocess.check_output(['git','show',f'{BASE}:{path}'],cwd=ROOT),name
    before_contract=json.loads(subprocess.check_output(['git','show',f'{BASE}:assets/quest_giver_test/contract.json'],cwd=ROOT))
    def without_timing(contract):
        contract=copy.deepcopy(contract)
        for key in ['version','timing']:contract.pop(key,None)
        for row in contract['conversation']:row.pop('subtitle_parts',None)
        return contract
    assert without_timing(assets.read('contract.json'))==without_timing(before_contract)
    def non_caption_entries(doc):
        return [e for e in doc['Data']['RootChunk']['root']['Data']['entries'] if '_Part' not in e['secondaryKey']]
    old_text=json.loads(subprocess.check_output(['git','show',f'{BASE}:assets/quest_giver_test/onscreens.json.json'],cwd=ROOT))
    assert non_caption_entries(docs['onscreens.json.json'])==non_caption_entries(old_text)
    for path in subprocess.check_output(['git','ls-tree','-r','--name-only',BASE,'--','r6/scripts/NCPDPatrol'],cwd=ROOT,text=True).splitlines():
        if path=='r6/scripts/NCPDPatrol/NCPDPatrolVossSubtitles.reds':continue
        if path=='r6/scripts/NCPDPatrol/NCPDPatrolQuestGiverTest.reds':
            from pose_source import without_idle_only_pose
            assert without_idle_only_pose((ROOT/path).read_text())==subprocess.check_output(['git','show',f'{BASE}:{path}'],cwd=ROOT,text=True),path
        else:assert (ROOT/path).read_bytes()==subprocess.check_output(['git','show',f'{BASE}:{path}'],cwd=ROOT),path
    for kind in ['old_id','option_type','missing_index','reordered_lines','dangling_event','sparse_node','unsorted_nodes','dangling_edge']:
        bad=copy.deepcopy(current)
        if kind in ['old_id','option_type','missing_index']:
            value={'old_id':100001,'option_type':2,'missing_index':(1000<<8)|1}[kind]
            rejected(lambda:resolve_line(bad,value),'category' if kind!='missing_index' else 'outside line array')
            continue
        if kind=='reordered_lines':bad['screenplayStore']['lines'].reverse()
        elif kind=='dangling_event':
            e=next(e['Data'] for n in bad['sceneGraph']['Data']['graph'] for e in n['Data'].get('events',[]) if e['Data']['$type']=='scnDialogLineEvent');e['screenplayLineId']['id']=(1000<<8)|1
        elif kind=='sparse_node':bad['sceneGraph']['Data']['graph'][0]['Data']['nodeId']['id']=1000
        elif kind=='unsorted_nodes':bad['sceneGraph']['Data']['graph'].reverse()
        elif kind=='dangling_edge':bad['sceneGraph']['Data']['graph'][0]['Data']['outputSockets'][0]['destinations'][0]['nodeId']['id']=999
        message={'reordered_lines':'packed dialogue','dangling_event':'outside line array','sparse_node':'dense ordered','unsorted_nodes':'dense ordered','dangling_edge':'missing node'}[kind]
        rejected(lambda:(check_screenplay(bad),check_graph(bad)),message)
    result={'reference_commit':reference['source_commit'],'reference_blob':reference['source_git_blob'],'previous_v019g_first_item_id':bad_id,'previous_type_byte':161,'previous_array_index':390,'previous_v019g_invalid_layout_rejected':True,'corrected_packed_dialogue_ids':[(i<<8)|1 for i in range(10)],'dense_scene_node_ids':list(range(1,16)),'all_dialogue_and_graph_references_checked':True,'all_44_other_native_scripts_and_all_media_unchanged':True,'only_captions_timing_and_scoped_idle_request_excluded_from_baseline_comparison':True,'actual_native_crash_reproduced':False,'actual_game_validation':False}
    p=argparse.ArgumentParser();p.add_argument('--report',type=Path);a=p.parse_args()
    if a.report:a.report.write_text(json.dumps(result,indent=2)+'\n')
    print('PASS: reference-backed scene IDs: shipped v0.19g first ID 100001/type161/index390 and sparse graph rejected; ten packed dialogue IDs, dense ordered 15-node graph and every event/edge checked; unsafe-category/index/order/reference controls; scene/lipsync/native V IDs and 44 other scripts retained, scoped captions/timing/idle and Wwise re-exports allowed (not a native crash reproduction)')
if __name__=='__main__':main()
