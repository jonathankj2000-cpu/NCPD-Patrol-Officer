"""Execute the scoped idle-mode request without emulating game animation.

The optional moving-workspot model shows the old controller never requests
idle-only mode. Native selection/rendering still requires a game test.
"""
from pathlib import Path
import argparse,json,subprocess
from check_quest_giver import ROOT,PREFIX,assets,runtime
from pose_source import without_idle_only_lua,without_idle_only_pose

BASE='e554a51015ba8fbd302e4c581ec839c522e68704'

def main():
    docs,_=assets.outputs()
    for path,strip in [(PREFIX+'quest_giver_test.lua',without_idle_only_lua),
        ('r6/scripts/NCPDPatrol/NCPDPatrolQuestGiverTest.reds',without_idle_only_pose)]:
        assert strip((ROOT/path).read_text())==subprocess.check_output(['git','show',BASE+':'+path],cwd=ROOT,text=True),path
    for path in ['assets/quest_giver_test/contract.json','assets/quest_giver_test/conversation.scene.json',
        'assets/quest_giver_test/onscreens.json.json','r6/scripts/NCPDPatrol/NCPDPatrolVossSubtitles.reds']:
        if path.endswith('conversation.scene.json'):
            from audio_source import without_ambient_mix
            assert without_ambient_mix(json.loads((ROOT/path).read_text()))==json.loads(subprocess.check_output(['git','show',BASE+':'+path],cwd=ROOT)),path
        else:assert (ROOT/path).read_bytes()==subprocess.check_output(['git','show',BASE+':'+path],cwd=ROOT),path
    old=runtime(docs,legacy_walk=True);old.f.qposeModelWalkAfter=5
    old.start();old.arrive();old.step(15)
    assert old.f.qposeWalks==1 and len(old.f.qposeIdleCalls)==0 and len(old.f.qposeCalls)==1
    for no_user_map in [False,True]:
        m=runtime(docs);m.f.qposeModelWalkAfter=5;m.f.qposeNoDeviceUser=no_user_map
        m.start();m.arrive();m.step(90)
        assert len(m.f.qposeIdleCalls)==1 and len(m.f.qposeCalls)==1 and m.f.qposeWalks==0
        actor=m.f.qposeIdleCalls[1].actor;anchor=m.f.qposeCalls[1].position
        assert actor.GetWorldPosition(actor).x==anchor.x and actor.GetWorldPosition(actor).y==anchor.y
        m.talk();m.finish_conversation();m.step(60)
        assert m.lines==[r['text'] for r in assets.read('contract.json')['conversation']]
        assert len(m.f.qposeIdleCalls)==1 and len(m.f.qposeCalls)==1 and m.f.qposeWalks==0
        assert m.f.qPoseActive() and not m.f.deletes[1]
        m.clear();assert not m.f.qPoseActive()
    # Actual native guard code rejects unrelated actors/state before issuing
    # any quest node. A valid pose is acquired before all tests below.
    m=runtime(docs);m.start();m.arrive()
    m.lua.execute('''
        local f=F;local npc=f.qposeCalls[1].actor;local qs=GameInstance:GetQuestsSystem({})
        local stage='ncpd_patrol_qgiver_test_stage';local before=#f.qposeIdleCalls
        assert(not QNative:RequestPoseIdle(nil))
        for _,flag in ipairs({'dead','detached','foreign-record'}) do
            local fake={}
            function fake:IsAttached() return flag~='detached' end
            function fake:IsDead() return flag=='dead' end
            function fake:GetRecordID() return 'Character.Other' end
            assert(not QNative:RequestPoseIdle(fake),flag)
        end
        for _,value in ipairs({0,2}) do
            qs:SetFactStr(stage,value);assert(not QNative:RequestPoseIdle(npc))
        end
        qs:SetFactStr(stage,1)
        f.ready=false;assert(not QNative:RequestPoseIdle(npc));f.ready=true
        f.menu=true;assert(not QNative:RequestPoseIdle(npc));f.menu=false
        f.qposeNoNativeSystem=true;assert(not QNative:RequestPoseIdle(npc));f.qposeNoNativeSystem=false
        local links=f.qposeLinks;f.qposeLinks={}
        assert(not QNative:RequestPoseIdle(npc));f.qposeLinks=links
        assert(#f.qposeIdleCalls==before)
    ''');m.clear()
    # Missing/older installed bridges cannot partially activate the quest.
    m=runtime(docs);m.lua.execute('QNative.Version=function() return 2 end')
    assert not m.f.qmod.start(m.f.qstatus) and len(m.f.creates)==0
    assert 'complete v0.20b' in m.f.qlog[len(m.f.qlog)]
    # This remains cosmetic: refusal does not remove a visible Voss, stop her
    # existing spot, alter the voice timeline or cancel the SMS/meeting quest.
    for flag in ['qposeNoNativeSystem','qposeIdleExecuteThrows']:
        m=runtime(docs);setattr(m.f,flag,True);m.start();m.arrive()
        assert m.f.qmod.active() and m.f.qPoseActive() and len(m.f.deletes)==0
        assert 'pose=unconfirmed' in m.f.qmod.diagnostics() and len(m.f.qposeIdleCalls)==0
        m.talk();m.finish_conversation();m.clear()
    result={'baseline':BASE,'old_controller_lacks_idle_request_in_moving_workspot_model':True,
        'one_idle_only_request_after_private_pose_active':True,'request_function':'IdleOnlyMode','native_enum_value':3,
        'exact_private_npc_tag_record_and_stage_scope':True,'waiting_dialogue_and_post_dialogue_model_held':True,
        'no_workspot_restart_jump_teleport_or_repeated_repair':True,'no_device_user_mapping_required':True,
        'cosmetic_failure_retains_quest_actors_and_voice_flow':True,'existing_cleanup_and_replay_retained':True,
        'v019h_scene_media_caption_script_and_timing_byte_identical':True,
        'actual_native_idle_mode_rendering_confirmed':False,'actual_game_validation':False}
    parser=argparse.ArgumentParser();parser.add_argument('--report',type=Path);args=parser.parse_args()
    if args.report:args.report.write_text(json.dumps(result,indent=2)+'\n')
    print('PASS: exact private Voss idle-only node after active pose, once before dialogue; old controller lacks hold in optional moving-branch model; native actor/stage/menu/world guards, old-bridge refusal, missing user map and cosmetic fallback; no restart/jump/teleport, unchanged v0.19h scene/media/caption timing (native animation boundary mocked)')

if __name__=='__main__':main()
