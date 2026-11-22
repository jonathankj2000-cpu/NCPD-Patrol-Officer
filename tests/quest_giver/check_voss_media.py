"""Validate the authored Voss media, native bindings and uninterrupted timing.

This checks the real WEM container and user-supplied CR2W bank, not a mocked
audio player. Actual NPC head compatibility/playback still requires the game.
"""
from pathlib import Path
import argparse,copy,hashlib,json,math,re,struct,subprocess,sys

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools'))
import build_quest_giver_assets as assets

def wem_info(body):
    assert body[:4]==b'RIFF' and body[8:12]==b'WAVE'
    assert struct.unpack_from('<I',body,4)[0]+8==len(body),'Truncated WEM'
    chunks={};pos=12
    while pos<len(body):
        assert pos+8<=len(body)
        tag=body[pos:pos+4];size=struct.unpack_from('<I',body,pos+4)[0];pos+=8
        assert tag not in chunks and pos+size<=len(body)
        chunks[tag]=body[pos:pos+size];pos+=size
    assert set(chunks)=={b'fmt ',b'data'}
    fmt=chunks[b'fmt '];assert len(fmt)==0x42
    codec,channels,rate=struct.unpack_from('<HHI',fmt)
    assert codec==0xffff and channels==1 and rate==44100,'Not the intended Wwise Vorbis stream'
    assert struct.unpack_from('<H',fmt,16)[0]==0x30
    assert struct.unpack_from('<I',fmt,20)[0]==4
    samples=struct.unpack_from('<I',fmt,24)[0];assert samples>0
    seek,offset=struct.unpack_from('<II',fmt,40);data=chunks[b'data']
    assert seek%4==0 and 0<seek<offset<len(data)
    setup_size=struct.unpack_from('<H',data,seek)[0]
    assert seek+2+setup_size==offset
    # Wwise stores the stripped setup and a size-prefixed packet stream.
    h=0x811c9dc5
    for byte in data[seek+2:offset]:h=((h*0x01000193)&0xffffffff)^byte
    assert h==struct.unpack_from('<I',fmt,60)[0]
    packets=0;pos=offset
    while pos<len(data):
        assert pos+2<=len(data)
        size=struct.unpack_from('<H',data,pos)[0];pos+=2
        assert size>0 and pos+size<=len(data),'Truncated audio packet'
        pos+=size;packets+=1
    assert packets>1
    return {'codec':'Wwise Vorbis 0xFFFF','channels':channels,'sample_rate':rate,
        'sample_frames':samples,'duration_seconds':samples/rate,'audio_packets':packets}

def main():
    c=assets.read('contract.json');m=assets.read('media/manifest.json');npcs=[t for t in c['conversation'] if t['speaker']=='voss']
    assert len(npcs)==6 and len(m['packaged'])==7
    for name,entry in m['packaged'].items():
        body=(assets.DIR/'media'/name).read_bytes()
        assert len(body)==entry['bytes'] and hashlib.sha256(body).hexdigest()==entry['sha256'],name
    bank=(assets.DIR/'media/voss_conversation.anims').read_bytes();assert bank[:4]==b'CR2W'
    merge=m['lipsync_merge'];assert merge['roundtrip_validated'] and merge['all_animation_payload_fields_preserved']
    assert len(merge['clips'])==6 and {x['merged_data_chunk_index'] for x in merge['clips']}==set(range(6))
    for name in merge['source_banks']:
        b=(assets.DIR/'media/source'/name).read_bytes();assert b[:4]==b'CR2W' and hashlib.sha256(b).hexdigest()==m['source_uploads'][name]['sha256']
    audios={}
    for row in npcs:
        clip=next(x for x in merge['clips'] if x['clip']==row['clip']);assert row['clip'].encode() in bank
        assert clip['all_animation_payload_fields_preserved'] and clip['num_joints']==344 and clip['num_tracks']==414
        assert clip['duration_seconds']==row['animation_seconds'] and clip['animation_type']=='AdditiveFromRefPose'
        body=(assets.DIR/'media'/row['wem']).read_bytes();audio=wem_info(body);source=m['source_uploads'][row['source_wav']]
        assert audio['sample_frames']==source['sample_frames'] and audio['sample_rate']==source['sample_rate']
        assert audio['duration_seconds']==row['audio_seconds'] and abs(audio['duration_seconds']-row['animation_seconds'])<1/30
        assert assets.media_ms(row)==math.ceil(max(row['audio_seconds'],row['animation_seconds'])*1000)
        assert assets.turn_ms(row,c['timing'])>=math.ceil(audio['duration_seconds']*1000)+2000
        audios[row['key']]=audio
    for broken in [body[:-1],b'OggS'+body[4:],body[:20]+b'\x01\x00'+body[22:],body[:44]+b'\x00'*4+body[48:]]:
        try:wem_info(broken)
        except (AssertionError,struct.error):pass
        else:raise AssertionError('Invalid audio accepted')
    assert [t['string_id'] for t in c['conversation'] if t['speaker']=='v']==['1938843197804515328','1895381798296993792','1938900123686932480','1714373979483803648']
    assert not m['vanilla_v_audio_redistributed']
    docs,_=assets.outputs();assets.validate(docs)
    for kind in ['wrong_actor','wrong_clip','early_end','short_event','missing_lead','wrong_voice','root_look_at','wrong_look_actor','wrong_workspot','player_workspot','scene_pose_restart','blocking_pose','helper_workspot','helper_lift','helper_identity','sms_sender','sms_body','sms_attachment','sms_callable','native_v_override','wrong_v_speaker']:
        bad=copy.deepcopy(docs);s=bad['conversation.scene.json']['Data']['RootChunk'];nodes={n['Data']['nodeId']['id']:n['Data'] for n in s['sceneGraph']['Data']['graph']}
        if kind=='wrong_actor':bad['voss.lipmap.json']['Data']['RootChunk']['sceneEntries'][0]['actorVoiceTags']=['0']
        elif kind=='wrong_clip':s['screenplayStore']['lines'][0]['femaleLipsyncAnimationName']=assets.cn('missing_clip')
        elif kind=='early_end':nodes[assets.SPEECH_NODES[0]]['outputSockets'][0]['destinations'][0]['nodeId']['id']=assets.RECEIPT_NODE
        elif kind=='short_event':nodes[assets.SPEECH_NODES[0]]['events'][0]['Data']['duration']=3500
        elif kind=='missing_lead':nodes[assets.SPEECH_NODES[0]]['events'][0]['Data']['startTime']=0
        elif kind=='wrong_voice':bad['vomap.json.json']['Data']['RootChunk']['root']['Data']['entries'][0]['stringId']='0'
        elif kind=='root_look_at':nodes[assets.SPEECH_NODES[0]]['events'][1]['Data']['basicData']['basic']['targetSlot']=assets.cn('None')
        elif kind=='wrong_look_actor':nodes[assets.SPEECH_NODES[0]]['events'][1]['Data']['basicData']['basic']['targetPerformerId']['id']=1
        elif kind=='wrong_workspot':s['workspots'][0]['Data']['workspotResource']['DepotPath']['$value']='missing.workspot'
        elif kind=='player_workspot':nodes[11]['questNode']['Data']['paramsV1']['Data']['isPlayer']=1
        elif kind=='scene_pose_restart':nodes[12]['outputSockets'][2]['destinations']=[{'$type':'scnInputSocketId','nodeId':assets.rid('scnNodeId',11),'isockStamp':{'$type':'scnInputSocketStamp','name':0,'ordinal':1}}]
        elif kind=='blocking_pose':nodes[11]['outputSockets'][0]['destinations']=nodes[12]['outputSockets'][0]['destinations']
        elif kind=='native_v_override':bad['vomap.json.json']['Data']['RootChunk']['root']['Data']['entries'][0]['stringId']=m['vanilla_v_string_ids'][0]
        elif kind=='wrong_v_speaker':s['screenplayStore']['lines'][1]['speaker']['id']=0
        elif kind.startswith('helper_'):
            component=next(x for x in assets.walk(bad['voss_wait_pose.ent.json']) if x.get('$type')=='workWorkspotResourceComponent')
            if kind=='helper_workspot':component['workspotResource']['DepotPath']['$value']='missing.workspot'
            elif kind=='helper_lift':component['localTransform']['Position']['z']['Bits']=256
            elif kind=='helper_identity':component['name']=assets.cn('foreign_component')
        elif kind.startswith('sms_'):
            contact=next(x for x in assets.walk(bad['quest_giver.journal.json']) if x.get('$type')=='gameJournalContact');message=contact['entries'][0]['Data']['entries'][0]['Data']
            if kind=='sms_sender':message['sender']='Player'
            elif kind=='sms_body':next(e for e in bad['onscreens.json.json']['Data']['RootChunk']['root']['Data']['entries'] if e['secondaryKey']=='NCPDPatrol_QG_Invitation')['femaleVariant']='Wrong invitation'
            elif kind=='sms_attachment':message['attachment']['Data']['realPath']='quests/story/foreign'
            elif kind=='sms_callable':contact['isCallableDefault']=1
        try:assets.validate(bad)
        except AssertionError:pass
        else:raise AssertionError('Broken media binding accepted: '+kind)
    xl=(ROOT/'archive/pc/mod/NCPDPatrol_QuestGiverTest.archive.xl').read_text()
    assert 'vomaps:\n    en-us: '+assets.DEPOT+'vomap.json' in xl and 'lipmaps:\n    en-us: '+assets.DEPOT+'voss.lipmap' in xl
    # Keep the player's established dialogue/tier guard verbatim. The pose
    # device lifecycle is intentionally changed and covered by runtime tests.
    rel='bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrol/quest_giver_test.lua'
    current=(ROOT/rel).read_text();old=subprocess.check_output(['git','show','541158bc5cd3b363806813985837da36ede3f694:'+rel],cwd=ROOT,text=True)
    guard=r'local function playerBlockReason\(player\).*?\nend'
    assert re.search(guard,current,re.S)[0]==re.search(guard,old,re.S)[0]
    native_rel='r6/scripts/NCPDPatrol/NCPDPatrolQuestGiverTest.reds';native=(ROOT/native_rel).read_text()
    prior=subprocess.check_output(['git','show','541158bc5cd3b363806813985837da36ede3f694:'+native_rel],cwd=ROOT,text=True)
    stripped=re.sub(r'^    public func GetPose(?:HelperTemplate|Resource)\(\) -> ResRef \{[^\n]+\}\n','',native,flags=re.M).replace('return 2;','return 1;')
    assert stripped==prior
    print('PASS: Voss media: six complete Wwise voices/sample counts and matching supplied lipsync clips, merged payload provenance, four exact native V IDs without global overrides, ten automatic scene turns and final receipt; malformed audio/scene/voice/LookAt/helper/SMS bindings rejected; existing player guards/native quest bridge retained (actual game playback unverified)')
    return {'audio':audios,'total_voss_audio_seconds':sum(x['duration_seconds'] for x in audios.values()),'animation_payloads_preserved':True,'voice_entries':6,'native_v_string_ids':m['vanilla_v_string_ids'],'shared_event_lead_in_ms':300,'complete_audio_per_turn':True,'player_voice':True,'player_guards_unchanged':True,'grounded_private_pose_helper':True,'no_scene_pose_restart':True,'actual_game_validation':False}

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--report',type=Path);a=p.parse_args();report=main()
    if a.report:a.report.write_text(json.dumps(report,indent=2)+'\n')
