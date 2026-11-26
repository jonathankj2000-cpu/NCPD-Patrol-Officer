"""Execute the direct-event test at recording API boundaries, never a mixer."""
from pathlib import Path
import argparse
import json
import subprocess
import sys
import tempfile
from lupa.luajit21 import LuaRuntime

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT/'tools/voice_ab/init.lua'
FIXTURE = r'''
F={events={},observers={},sent={},writes=0,psm={SceneTier=1,HighLevel=1,UpperBody=0,Zones=1},stage=0}
function registerForEvent(name,cb) assert(not F.events[name]);F.events[name]=cb end
function Observe(class,method,cb) assert(class=='PlayerPuppet' and method=='OnGameAttached');F.observers.world=cb end
function print(_) end
CName={new=function(x) return x end}
CRUID={new=function(x) return {hash=F.badId and 0ULL or x} end}
Enum={new=function(name,value) return {name=name,value=value} end}
function NewObject(name)
 assert(name=='gameaudioeventsDialogLine' or name=='audioDialogLineEventData')
 if F.badType then return nil end
 return {}
end
local player={}
function player:IsAttached() return not F.detached end
function player:IsDead() return F.dead==true end
function player:IsInCombat() return F.combat==true end
function player:GetEntityID() return {hash=F.playerHash or 123} end
function player:QueueEvent(event)
 if F.badQueue then error('queue rejected') end
 local d=event.data
 assert(d.context.name=='locVoiceoverContext' and d.context.value=='Vo_Context_Minor_Activity')
 assert(d.expression.name=='locVoiceoverExpression' and d.expression.value=='Vo_Expression_Spoken')
 assert(d.isPlayer and not d.isRewind and not d.isHolocall and d.customVoEvent=='None')
 assert(d.seekTime==0 and d.playbackSpeedParameter==1)
 F.sent[#F.sent+1]={id=tostring(d.stringId.hash),target=self}
end
F.player=player
local patrol={IsOnDuty=function() return F.duty==true end,HasWantedLevel=function() return F.wanted==true end}
local systems={Get=function(_,name) assert(name=='NCPDPatrolSystem');return not F.noPatrol and patrol or nil end}
local defs={PlayerStateMachine={SceneTier='SceneTier',HighLevel='HighLevel',UpperBody='UpperBody',Zones='Zones'},UI_System={IsInMenu='menu'}}
function GetAllBlackboardDefs() return defs end
local psm={GetInt=function(_,key) return F.psm[key] end}
local ui={GetBool=function(_,key) assert(key=='menu');return F.menu==true end}
local boards={GetLocalInstanced=function() return not F.noPSM and psm or nil end,Get=function() return ui end}
local scene={IsEntityInScene=function() return F.scene==true end,IsEntityInDialogue=function() return F.dialogue==true end,
 IsFastForwardingActive=function(_,mode) if F.badFF then error('not exposed') end;return (mode.value=='Default' and F.ffdefault==true) or (mode.value=='GameplayReview' and F.ffreview==true) end}
local q={GetFactStr=function(_,name) assert(name=='ncpd_patrol_qgiver_test_stage');return F.stage end}
local services={GetService=function(_,name)
 assert(name=='NCPDPatrolVossLengthTest')
 if F.lengthDiag then return {GetDiagnostics=function() return F.lengthDiag end} end
end}
Game={GetPlayer=function() return not F.noPlayer and player or nil end,
 GetScriptableSystemsContainer=function() return systems end,GetScriptableServiceContainer=function() return services end,
 GetBlackboardSystem=function() return boards end,GetQuestsSystem=function() return q end,
 GetSceneSystem=function() return {GetScriptInterface=function() return scene end} end}
json={encode=function(value) if F.badJSON then error('encode failed') end;F.report=value;return 'JSON' end}
io={open=function(path,mode)
 assert(path=='voss_voice_ab_result.json' and mode=='w')
 if F.badOpen then return nil,'open failed' end
 return {write=function(_,body) assert(body=='JSON');if F.badWrite then return nil,'write failed' end;F.writes=F.writes+1;return true end,
 close=function() return true end}
end}
'''


def runtime():
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute(FIXTURE)
    module = lua.execute(SOURCE.read_text())
    lua.globals().Probe = module
    fixture = lua.globals().F
    fixture.events['onInit']()
    return lua, module, fixture


def advance(module, seconds):
    for _ in range(round(seconds/.05)):
        module.update(.05)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--compiler', type=Path)
    parser.add_argument('--report', type=Path)
    args = parser.parse_args()
    source = SOURCE.read_text()
    for forbidden in ['Override(', 'SetFact', 'ExecuteNode', 'SetTimeDilation', 'GiveItem', 'GetAudioSystem', 'CreateEntity', 'DeleteEntity']:
        assert forbidden not in source, forbidden
    lua, module, fixture = runtime()
    fixture.events['onInit']()
    assert module.arm()[0]
    advance(module, 2.9)
    assert len(fixture.sent) == 0 and fixture.writes == 0
    advance(module, .2)
    assert len(fixture.sent) == 1 and fixture.sent[1].id == '1938843197804515328ULL'
    assert not module.export()[0] and fixture.writes == 0
    advance(module, 56.5)
    assert len(fixture.sent) == 4 and fixture.writes == 1
    assert [fixture.sent[i].id for i in range(1, 5)] == [
        '1938843197804515328ULL', '1895381798296993792ULL', '7936178618028821476ULL', '7936180817052077898ULL']
    assert fixture.report.end_reason == 'four_events_sent'
    assert fixture.report.coverage.queued_is_not_proof_of_audible_playback
    assert not fixture.report.coverage.quest_scene_started and not fixture.report.coverage.actual_audio_measured
    assert not fixture.report.coverage.npc_emitter_tested
    assert fixture.report.queued[2].t - fixture.report.queued[1].t >= 10-1e-9
    assert fixture.report.queued[3].t - fixture.report.queued[2].t >= 10-1e-9
    assert fixture.report.queued[4].t - fixture.report.queued[3].t >= 20-1e-9
    for flag in ['duty','wanted','combat','dead','detached','noPlayer','noPatrol','noPSM','menu','dialogue']:
        _, module, fixture = runtime();fixture[flag]=True
        assert not module.arm()[0] and len(fixture.sent)==0, flag
    for state in ['SceneTier','HighLevel']:
        _, module, fixture = runtime();fixture.psm[state]=2
        assert not module.arm()[0], state
    _, module, fixture = runtime();fixture.stage=2
    assert not module.arm()[0]
    _, module, fixture = runtime();fixture.lengthDiag='callback registered=true | verified=6/6'
    assert not module.arm()[0] and 'still active' in module.status()
    _, module, fixture = runtime();fixture.lengthDiag='Voss VO lengths | disabled=true'
    assert module.arm()[0]
    # Overlay waiting is a bounded grace period; no event is sent until closed.
    _, module, fixture = runtime();fixture.events['onOverlayOpen']();assert module.arm()[0]
    advance(module, 10);assert len(fixture.sent)==0
    fixture.events['onOverlayClose']();advance(module, 3.1);assert len(fixture.sent)==1
    fixture.events['onOverlayOpen']();module.update(.05)
    assert fixture.report.end_reason.startswith('overlay_reopened') and len(fixture.sent)==1
    _, module, fixture = runtime();fixture.events['onOverlayOpen']();assert module.arm()[0]
    advance(module, 45.1);assert fixture.report.end_reason=='overlay_not_closed' and len(fixture.sent)==0
    # Native construction/readback/dispatch failures cannot be labelled success.
    for flag in ['badType','badId','badQueue']:
        _, module, fixture = runtime();fixture[flag]=True;assert module.arm()[0]
        advance(module, 3.1)
        assert fixture.report.end_reason=='native_event_failed' and len(fixture.sent)==0, flag
    for flag in ['badJSON','badOpen','badWrite']:
        _, module, fixture = runtime();assert module.arm()[0];fixture[flag]=True
        assert not module.finish('manual_cancel')[0]
        fixture[flag]=False;assert module.export()[0]
    for event in ['world','onShutdown']:
        _, module, fixture = runtime();assert module.arm()[0];advance(module, 3.1)
        (fixture.observers.world if event=='world' else fixture.events[event])()
        count=len(fixture.sent);advance(module, 90)
        assert count==len(fixture.sent)==1
    _, module, fixture = runtime();assert module.arm()[0];fixture.playerHash=999;module.update(.05)
    assert fixture.report.end_reason=='player_replaced'
    _, module, fixture = runtime();fixture.badFF=True;assert module.arm()[0];advance(module, .1)
    module.finish('optional_getter');assert fixture.report.states[1].fast_forward_error
    _, module, fixture = runtime();assert module.arm()[0]
    for value in [float('nan'),float('inf'),0,-1]:module.update(value)
    assert len(fixture.sent)==0
    module.finish('invalid_delta')
    stub = ROOT/'tools/voice_ab/recovery/NCPDPatrolVossLengthTest.reds'
    text = stub.read_text()
    assert 'RegisterCallback(' not in text and 'ArrayPush(' not in text and 'ApplyLengths' not in text
    assert 'disabled=true' in text and 'UnregisterCallback' in text
    sys.path.insert(0, str(ROOT/'tests/arrests'))
    from translate import translate
    recovery_lua = LuaRuntime(unpack_returned_tuples=True)
    recovery_lua.execute('''Removed=0
      function IsDefined(x) return x~=nil end
      GameInstance={GetCallbackSystem=function() return {UnregisterCallback=function(_,name,owner,method)
        assert(name=='Resource/PostLoad' and method=='OnLengthsLoaded');Removed=Removed+1 end} end}''')
    recovery = recovery_lua.execute(translate(stub))
    recovery.OnLoad(recovery); recovery.OnLoad(recovery)
    assert recovery_lua.globals().Removed == 2 and 'disabled=true' in recovery.GetDiagnostics(recovery)
    rejected = subprocess.run([sys.executable,str(ROOT/'tools/build_voss_length_test_release.py'),
                               '--compiler','/not-a-compiler'],capture_output=True,text=True)
    assert rejected.returncode != 0 and 'Rejected in-game experiment' in rejected.stderr
    compiled = False
    if args.compiler:
        subprocess.run([str(args.compiler.resolve()), str(ROOT/'tests/audio_trace/length-api.reds'), '--', str(stub)], check=True)
        compiled = True
    result = {'direct_queue_uses_two_exact_stock_and_two_exact_private_uint64_ids': True,
              'same_player_emitter_and_native_flags_for_both_groups': True,
              'no_quest_scene_or_global_audio_state_override': True,
              'active_length_experiment_blocks_test': True, 'three_second_overlay_closed_preroll': True,
              'spaced_slots_do_not_emit_overlapping_requests': True,
              'native_failure_and_readback_failures_not_reported_as_playback': True,
              'state_frame_gap_and_optional_fast_forward_evidence': True,
              'guard_cancel_world_shutdown_and_export_retries': True,
              'recovery_stub_never_registers_or_modifies_lengths': True,
              'recovery_onload_executed_and_rejected_builder_blocked': True,
              'recovery_stub_offline_api_compile': compiled,
              'actual_native_event_delivery_and_audio_result_verified': False}
    if args.report:args.report.write_text(json.dumps(result,indent=2)+'\n')
    print('PASS: direct native-event control exact uint64 IDs/flags, separated slots, off-duty/menu/scene/experiment guards, '
          'native failure/readback and export retry handling, lifecycle/cancellation, disabled recovery service. '
          'Actual game event delivery and audible result unverified.')
    return result


if __name__=='__main__':main()
