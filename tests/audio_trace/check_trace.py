"""Execute the standalone CET observer over recording, read-only game services.

This checks trace ownership/bounds/export and pass-through observer use, not
native hook delivery, audio rendering or the cause of the user's cuts.
"""
from pathlib import Path
import argparse,json
from lupa.luajit21 import LuaRuntime
ROOT=Path(__file__).resolve().parents[2]
SOURCE=ROOT/'tools/audio_trace/init.lua'
FIXTURE=r'''
F={stage=1,SceneTier=1,HighLevel=1,UpperBody=0,Zones=1,events={},observers={},writes=0,samples=0}
local f=F
function registerForEvent(name,callback) assert(not f.events[name]);f.events[name]=callback end
function Observe(class,method,callback)
 if f.badHook==method then error('registration rejected') end
 local key=class..'.'..method;assert(not f.observers[key]);f.observers[key]=callback
end
function f.emit(key,...) assert(f.observers[key],key);f.observers[key](nil,...) end
local p={}
function p:IsAttached() return not f.detached end
function p:IsDead() return f.dead==true end
function p:GetEntityID() return {hash=123} end
function p:GetRecordID() return 'Character.Player_Puppet_Base' end
f.player=p
local q={}
function q:GetFactStr(name) assert(name=='ncpd_patrol_qgiver_test_stage');return f.stage end
local patrol={}
function patrol:IsOnDuty() return f.duty==true end
local systems={}
function systems:Get(name) assert(name=='NCPDPatrolSystem');return not f.noPatrol and patrol or nil end
local definitions={PlayerStateMachine={SceneTier='SceneTier',HighLevel='HighLevel',UpperBody='UpperBody',Zones='Zones'},UI_System={IsInMenu='menu'}}
function GetAllBlackboardDefs() return definitions end
local psm={}
function psm:GetInt(key) f.samples=f.samples+1;return f[key] end
local ui={}
function ui:GetBool(key) assert(key=='menu');return f.menu==true end
local boards={}
function boards:GetLocalInstanced(id,definition)
 assert(id.hash==123 and definition==definitions.PlayerStateMachine)
 return not f.noPSM and psm or nil
end
function boards:Get(definition) assert(definition==definitions.UI_System);return ui end
local scene={}
function scene:IsEntityInScene(id) assert(id.hash==123);return f.stage==2 end
function scene:IsEntityInDialogue(id) assert(id.hash==123);return f.stage==2 end
Game={GetPlayer=function() return f.noPlayer and nil or p end,
 GetQuestsSystem=function() if f.worldLost then error('world unavailable') end;return q end,
 GetScriptableSystemsContainer=function() return systems end,
 GetBlackboardSystem=function() return boards end,
 GetSceneSystem=function() return {GetScriptInterface=function() return scene end} end}
json={encode=function(report) if f.badJSON then error('JSON unavailable') end;f.report=report;return 'ENCODED' end}
io={open=function(name,mode)
 assert(name=='voss_audio_capture.json' and mode=='w')
 if f.badOpen then error('open denied') end
 return {write=function(_,body) assert(body=='ENCODED');if f.badWrite then return nil,'disk full' end;f.writes=f.writes+1;return true end,
  close=function() return true end}
end}
'''

def runtime(init=True):
    lua=LuaRuntime(unpack_returned_tuples=True);lua.execute(FIXTURE)
    module=lua.execute(SOURCE.read_text());g=lua.globals();g.Probe=module
    if init:g.F.events['onInit']()
    return lua,module,g.F

def begin():
    lua,m,f=runtime();assert m.arm()[0];f.stage=2;m.update(.05);return lua,m,f

def main():
    source=SOURCE.read_text()
    for forbidden in ['Override(', 'registerHotkey(', 'SetFact', 'GiveItem', 'SetInt(', 'SetBool(', 'ExecuteNode(', 'Game.GetAudioSystem(']:
        assert forbidden not in source,forbidden
    lua,m,f=runtime(False);assert not m.arm()[0];f.events['onInit']();f.events['onInit']()
    assert len(list(f.observers))==12
    f.emit('AudioSystem.Play','idle');m.update(2)
    assert f.samples==0 and f.writes==0 and not m.export()[0]
    for flag in ['dead','detached','noPatrol','duty']:
        lua,m,f=runtime();f[flag]=True;assert not m.arm()[0] and f.writes==0,flag
    lua,m,f=runtime();f.stage=2;assert not m.arm()[0]
    lua,m,f=begin();assert not m.arm()[0]
    f.emit('AudioSystem.State','mix','dialogue');f.emit('AudioSystem.State','mix','dialogue')
    f.emit('AudioSystem.Switch','switch','on',lua.table_from({'hash':456}),'emitter')
    f.emit('AudioSystem.Play','event',lua.table_from({'hash':456}),'emitter')
    f.emit('AudioSystem.Stop','event',lua.table_from({'hash':456}),'emitter')
    f.emit('AudioSystem.PlayOnEmitter','another',lua.table_from({'hash':456}),'emitter')
    for method in ['Parameter','GlobalParameter','NotifyGameTone']:
        f.emit('AudioSystem.'+method,'parameter',.5)
    f.emit('SubtitleLineLogicController.SetLineData',lua.table_from({'id':98765,'text':'Original line','speaker':f.player,'duration':7.5}))
    f.emit('BaseSubtitlesGameController.HideDialogLinesByData',lua.table_from([{'id':98765}],recursive=True))
    f.emit('BaseSubtitlesGameController.HideDialogLine',lua.table_from([98765]))
    f.HighLevel=2;f.SceneTier=2;f.UpperBody=5;m.update(.6)
    assert f.writes==0 and not m.export()[0],'No disk I/O during dialogue'
    f.stage=3;m.update(.05);m.update(2.01)
    assert f.writes==1 and f.report.end_reason=='conversation_ended'
    r=f.report;assert len(r.audio)==8 and r.observed_calls.State==2 and r.subtitle_callbacks==1
    assert r.audio[3].entity_id=='456' and r.audio[3].emitter=='emitter'
    assert r.subtitles[1].text_preview=='Original line' and r.subtitles[1].speaker_id=='123'
    assert r.subtitles[1].line_id==r.subtitles[2].line_id==r.subtitles[3].line_id=='98765'
    assert r.subtitle_hide_callbacks==2
    assert any(row.HighLevel==2 and row.UpperBody==5 for _,row in r.states.items()) and len(r.frame_gaps)==2
    assert not r.coverage.native_wwise_internals_observed and not r.coverage.mixer_levels_measured
    assert r.coverage.subtitle_markers_are_not_audible_voice_onsets
    assert r.previous_audio is None and r.previous_state is None
    writes=f.writes;f.emit('AudioSystem.Play','after');m.update(4);assert f.writes==writes
    # Callback inputs are copied, bounded and do not retain live game objects.
    lua,m,f=begin();line=lua.table_from({'text':'Copied','speaker':f.player,'duration':2})
    f.emit('SubtitleLineLogicController.SetLineData',line);line.text='Mutated';line.speaker=None
    f.emit('SubtitleLineLogicController.SetLineData',None)
    for i in range(1100):f.emit('AudioSystem.Play','event-'+str(i))
    for i in range(1300):f.emit('AudioSystem.Parameter','parameter-'+str(i),i)
    assert m.finish('bounds')[0]
    assert len(f.report.audio)==768 and f.report.dropped.audio>0 and f.report.previous_audio_size==1024
    assert f.report.subtitles[1].text_preview=='Copied' and f.report.error_counts.subtitle_decode==1
    # Preroll/timeouts, world replacement and protected export retries.
    lua,m,f=runtime();assert m.arm()[0]
    for i in range(80):f.emit('AudioSystem.Play','pre-'+str(i))
    m.update(181);assert f.report.end_reason=='no_conversation_before_timeout' and len(f.report.audio)==0
    lua,m,f=begin()
    f.observers['PlayerPuppet.OnGameAttached']();assert f.report.end_reason=='world_replaced' and f.report.loaded_scene.skipped=='world_replaced'
    lua,m,f=begin();f.worldLost=True;m.update(.1);assert f.report.end_reason=='world_unavailable' and f.report.loaded_scene.skipped=='world_unavailable'
    lua,m,f=begin();f.events['onShutdown']();assert f.report.loaded_scene.skipped=='shutdown'
    lua,m,f=begin();m.update(float('inf'));m.update(float('nan'));m.update(-1)
    assert f.writes==0;m.update(181);assert f.report.end_reason=='conversation_timeout'
    for flag in ['badJSON','badOpen','badWrite']:
        lua,m,f=begin();f[flag]=True;assert not m.finish('export_retry')[0],flag
        f[flag]=False;assert m.export()[0] and f.report.end_reason=='export_retry',flag
    # Loaded resource fingerprinting is deferred until capture has stopped.
    scene=json.loads((ROOT/'assets/quest_giver_test/conversation.scene.json').read_text())['Data']['RootChunk']
    graph={}
    for row in scene['sceneGraph']['Data']['graph']:
        node=row['Data'];speech=[e['Data'] for e in node.get('events',[]) if e['Data']['$type']=='scnDialogLineEvent']
        if speech:graph[node['nodeId']['id']]={'nodeId':node['nodeId'],'events':speech,'sectionDuration':node['sectionDuration']}
    lua,m,f=begin();g=lua.globals()
    g.ExpectedScene=lua.table_from({'sceneGraph':{'graph':graph},'sceneSolutionHash':scene['sceneSolutionHash']},recursive=True)
    lua.execute('''
        F.resourceReads=0
        Game.GetResourceDepot=function() return {LoadResource=function(_,path)
          assert(path=='base\\\\ncpd_patrol\\\\quest_giver_test\\\\conversation.scene')
          F.resourceReads=F.resourceReads+1
          return {IsLoaded=function() return not F.resourcePending end,IsFinished=function() return not F.resourcePending end,
            IsFailed=function() return false end,GetResource=function() return ExpectedScene end}
        end} end
    ''')
    m.update(.5);assert f.resourceReads==0 and f.writes==0
    assert m.finish('fingerprint')[0] and f.resourceReads==1
    assert f.report.loaded_scene.timing_fields_match_v020f1 and len(f.report.loaded_scene.speech_sections)==10
    assert f.report.loaded_scene.solution_hash=='7566336010319024185'
    g.ExpectedScene.sceneGraph.graph[2].events[1].duration=16150
    m.export();assert not f.report.loaded_scene.timing_fields_match_v020f1
    f.resourcePending=True;m.export();assert not f.report.loaded_scene.loaded
    lua,m,f=runtime(False);f.badHook='Play';f.events['onInit']();assert m.arm()[0]
    m.finish('partial_registration');assert 'rejected' in f.report.registration_attempts['AudioSystem.Play']
    result={'read_only_observer_and_state_capture_executed':True,'inactive_and_off_duty_guards':True,
        'no_disk_io_during_dialogue':True,'automatic_two_second_postroll_export':True,
        'frame_gaps_psm_changes_audio_requests_and_ui_markers_recorded':True,
        'bounded_plain_data_and_export_retry':True,'preroll_timeouts_world_reset_and_callback_errors':True,
        'loaded_scene_fields_checked_after_capture_only':True,'old_timing_and_pending_resource_distinguished':True,
        'native_audio_hook_delivery_verified':False,'audible_mixer_cause_verified':False,'actual_game_validation':False}
    p=argparse.ArgumentParser();p.add_argument('--report',type=Path);a=p.parse_args()
    if a.report:a.report.write_text(json.dumps(result,indent=2)+'\n')
    print('PASS: standalone read-only CET capture, request/UI/state/frame timeline, guards, bounded buffers, no recording I/O, auto export, timeout/reset/error recovery; native delivery and mixer cause unverified')

if __name__=='__main__':main()
