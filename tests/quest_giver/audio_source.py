"""Normalize only the reviewed per-line Voss mix change for older oracles."""
import copy
from build_quest_giver_assets import fnv

AUDIO_ASSETS={
    'assets/quest_giver_test/conversation.scene.json',
    'assets/quest_giver_test/compiled.json',
    'archive/pc/mod/NCPDPatrol_QuestGiverTest.archive',
}

def without_ambient_mix(doc):
    doc=copy.deepcopy(doc);root=doc['Data']['RootChunk']
    value=root['sceneSolutionHash']['sceneSolutionHash']
    assert value['sceneSolutionHashDate']==fnv('ncpd_patrol_voss_automatic_conversation_v7_ambient_mix_v1')
    value['sceneSolutionHashDate']=fnv('ncpd_patrol_voss_automatic_conversation_v7_timing_v1')
    count=0
    for node in root['sceneGraph']['Data']['graph']:
        for event in node['Data'].get('events',[]):
            data=event['Data']
            if data['$type']=='scnDialogLineEvent':
                assert data['voParams']['voContext']=='Vo_Context_Minor_Activity'
                data['voParams']['voContext']='Vo_Context_Quest';count+=1
    assert count==10
    return doc
