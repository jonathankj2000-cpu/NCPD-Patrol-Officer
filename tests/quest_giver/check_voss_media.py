"""Validate the authored Voss media, native bindings and uninterrupted timing.

This checks the real WEM container and user-supplied CR2W bank, not a mocked
audio player. Actual NPC head compatibility/playback still requires the game.
"""
from pathlib import Path
import argparse,copy,hashlib,json,math,struct,subprocess,sys

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
    samples=struct.unpack_from('<I',fmt,24)[0];assert samples==1850112,'Audio duration changed'
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
    assert packets==3644
    return {'codec':'Wwise Vorbis 0xFFFF','channels':channels,'sample_rate':rate,
        'sample_frames':samples,'duration_seconds':samples/rate,'audio_packets':packets}

def main():
    c=assets.read('contract.json');m=assets.read('media/manifest.json')
    for name,entry in m['packaged'].items():
        body=(assets.DIR/'media'/name).read_bytes()
        assert len(body)==entry['bytes'] and hashlib.sha256(body).hexdigest()==entry['sha256'],name
    bank=(assets.DIR/'media/voss_briefing.anims').read_bytes()
    assert bank[:4]==b'CR2W'
    assert hashlib.sha256(bank).hexdigest()=='4551f8f14adc55c52e5375bdfde81e007b1f82a3c133629a11cd0f6f2f2cd967'
    assert m['packaged']['voss_briefing.anims']==m['source_uploads']['Mara_Voss.anims']
    assert b'f_00000000CAFE0001' in bank
    body=(assets.DIR/'media/voss_briefing.wem').read_bytes();audio=wem_info(body)
    assert audio['duration_seconds']==c['briefing']['audio_seconds']
    assert abs(audio['duration_seconds']-c['briefing']['animation_seconds'])<1/30
    assert math.ceil(max(audio['duration_seconds'],m['lipsync']['duration_seconds'])*1000)==assets.briefing_ms(c)
    # Real malformed media must fail, even if its extension and mappings look OK.
    for broken in [body[:-1],b'OggS'+body[4:],body[:20]+b'\x01\x00'+body[22:],body[:44]+b'\x00'*4+body[48:]]:
        try:wem_info(broken)
        except (AssertionError,struct.error):pass
        else:raise AssertionError('Invalid or mistimed audio accepted')
    docs,_=assets.outputs();assets.validate(docs)
    for kind in ['wrong_actor','wrong_clip','early_choices','short_event','missing_lead','wrong_voice']:
        bad=copy.deepcopy(docs);s=bad['conversation.scene.json']['Data']['RootChunk']
        nodes={n['Data']['nodeId']['id']:n['Data'] for n in s['sceneGraph']['Data']['graph']}
        if kind=='wrong_actor':bad['voss.lipmap.json']['Data']['RootChunk']['sceneEntries'][0]['actorVoiceTags']=['0']
        elif kind=='wrong_clip':s['screenplayStore']['lines'][-1]['femaleLipsyncAnimationName']=assets.cn('missing_clip')
        elif kind=='early_choices':nodes[2]['outputSockets'][0]['destinations'][0]['nodeId']['id']=3
        elif kind=='short_event':nodes[10]['events'][0]['Data']['duration']=3500
        elif kind=='missing_lead':nodes[10]['events'][0]['Data']['startTime']=0
        elif kind=='wrong_voice':bad['vomap.json.json']['Data']['RootChunk']['root']['Data']['entries'][0]['stringId']='0'
        try:assets.validate(bad)
        except AssertionError:pass
        else:raise AssertionError('Broken media binding accepted: '+kind)
    xl=(ROOT/'archive/pc/mod/NCPDPatrol_QuestGiverTest.archive.xl').read_text()
    assert 'vomaps:\n    en-us: '+assets.DEPOT+'vomap.json' in xl
    assert 'lipmaps:\n    en-us: '+assets.DEPOT+'voss.lipmap' in xl
    assert len(docs['vomap.json.json']['Data']['RootChunk']['root']['Data']['entries'])==1
    # This change must not alter scene cleanup, player guards or actor staging.
    rel='bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrol/quest_giver_test.lua'
    current=(ROOT/rel).read_text().replace('hello -> Voss briefing -> two choices -> goodbye.','hello -> two choices -> goodbye.')
    assert current==subprocess.check_output(['git','show','b13576f55e8cce93e339d97fb0e691582432db8f:'+rel],cwd=ROOT,text=True)
    print('PASS: Voss media: real Wwise Vorbis stream/packet bounds, original sample count/rate, byte-identical supplied lipsync bank, matching voice/subtitle/actor/clip links, shared 300 ms lead-in, uninterrupted 42 s event before choices, malformed media/bindings rejected, V silent; actor lifecycle and player guards unchanged (in-game playback/head compatibility unverified)')
    return {'audio':audio,'supplied_animation_byte_identical':True,'voice_entries':1,
        'shared_event_lead_in_ms':300,'uninterrupted_briefing':True,'player_voice':False,
        'npc_lifecycle_and_player_guards_unchanged':True,'actual_game_validation':False}

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--report',type=Path);a=p.parse_args();report=main()
    if a.report:a.report.write_text(json.dumps(report,indent=2)+'\n')
