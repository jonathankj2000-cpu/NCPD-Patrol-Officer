"""Reproduce the reported v0.20a1 deletion and execute receipt/async recovery."""
from pathlib import Path
import argparse,copy,json,subprocess,sys
HERE=Path(__file__).resolve().parent;sys.path.insert(0,str(HERE))
from check_off_books import runtime,ROOT,PREFIX,ROOTPATH,first_assets,fact,position,restore
BASE='bc60498ee9bcd62b649f51d4cb09eded79ecee1c'

def main():
    # Exact published controller + a delayed/rejected final journal update:
    # final speech ends, IsSucceeded is false, auto-clear deletes all actors.
    old=runtime();old.lua.globals().QNative.Version=lambda _self:4
    source=subprocess.check_output(['git','show',BASE+':'+PREFIX+'quest_giver_test.lua'],cwd=ROOT,text=True)
    old.f.qmod=old.lua.execute(source);old.f.obConfigureRetention();old.f.qDelayCompletion=True
    old.start();old.arrive();old.talk();old.step(180)
    assert old.f.qfacts['ncpd_patrol_qgiver_test_stage']==0 and not old.f.qmod.active()
    assert len(old.f.deletes)==3 and fact(old,'stage')==0 and fact(old,'cycle')==0
    assert 'Scene ended without a proven journal completion' in old.f.qmod.diagnostics()
    # The real old authored Default RET port also leads straight to cleanup
    # even after the final scene receipt. The new graph must evaluate it.
    documents=copy.deepcopy(first_assets.outputs()[0])
    documents['quest_giver.questphase.json']=json.loads(subprocess.check_output(['git','show',BASE+':assets/quest_giver_test/quest_giver.questphase.json'],cwd=ROOT))
    bad=runtime(documents=documents);bad.f.qEndPort='Default RET'
    bad.start();bad.arrive();bad.talk();bad.step(180)
    assert fact(bad,'stage')==0 and bad.f.qfacts['ncpd_patrol_qgiver_test_briefed']==0 and len(bad.f.deletes)==3
    # New native graph on both real output ports. Completion proof comes from
    # the final scene fact, not an assumed immediate journal readback.
    for port in ['conversation_out','Default RET']:
        m=runtime();m.f.qEndPort=port;m.f.qDelayCompletion=True
        m.f.obRequireDescriptions=True;m.f.obJournalDelay=.75
        m.start();m.arrive();m.talk();m.finish_conversation();m.step(2)
        assert m.f.qfacts['ncpd_patrol_qgiver_test_briefed']==1 and m.f.qmod.briefingComplete()
        assert not m.lua.eval('QNative:IsSucceeded()') and fact(m,'stage')==1 and fact(m,'cycle')==1
        assert not m.books.ObjectiveVisible(m.books) and not m.f.deletes[1] and len(m.f.creates)==3
        m.step(15)
        assert m.books.ObjectiveVisible(m.books) and m.f.tracked.path==ROOTPATH+'/main/eliminate'
        assert m.f.entries[ROOTPATH+'/main/eliminate/briefing'].state==2
        assert fact(m,'activation_complete')==1 and fact(m,'cycle')==1 and not m.f.deletes[1]
        assert len(m.lines)==10 and len(m.sms_notifications)==1 and m.f.qPoseActive()
        m.f.qDelayCompletion=False;m.step(3);assert m.lua.eval('QNative:IsSucceeded()')
        position(m);m.step(2);assert len(m.f.creates)==6 and fact(m,'seeded')==1
        m.step(10);assert len(m.f.creates)==6 and fact(m,'cycle')==1
    # Missing dependency after a genuine briefing is explicit, recoverable,
    # and never a reason to delete Voss or discard the completion receipt.
    m=runtime();missing=m.f.entries[ROOTPATH];m.f.entries[ROOTPATH]=None
    m.start();m.arrive();m.talk();m.finish_conversation();m.step(4)
    assert fact(m,'stage')==fact(m,'cycle')==0 and m.f.qmod.briefingComplete()
    assert not m.f.deletes[1] and 'Missing journal quest' in m.f.books.diagnostics()
    m.f.entries[ROOTPATH]=missing;m.step(4)
    assert fact(m,'stage')==1 and fact(m,'cycle')==1 and m.books.ObjectiveVisible(m.books)
    # Native rejection keeps the same request pending. A manual Continue or a
    # world reload does not start another cycle or pretend the objective exists.
    m=runtime();m.f.obRejectedPath=ROOTPATH+'/main/eliminate'
    m.start();m.arrive();m.talk();m.finish_conversation();m.step(12)
    assert fact(m,'stage')==1 and fact(m,'cycle')==1 and not m.books.ObjectiveVisible(m.books)
    assert 'Journal state request rejected' in m.f.books.diagnostics() and not m.f.deletes[1]
    assert m.f.books.begin(m.f.obStatus);restore(m);m.step(3)
    assert fact(m,'stage')==1 and fact(m,'cycle')==1 and len(m.f.creates)==3
    m.f.obRejectedPath=None;m.step(4)
    assert m.books.ObjectiveVisible(m.books) and fact(m,'cycle')==1 and not m.f.deletes[1]
    assert m.f.tracked.path==ROOTPATH+'/main/eliminate'
    # Explicit encounter cancellation must remain cancelled after recovery;
    # explicit Continue or a genuinely new briefing can re-arm it.
    assert m.f.books.clear(m.f.obStatus);m.step(3);restore(m);m.step(4)
    assert fact(m,'stage')==0 and m.f.qmod.briefingComplete() and m.f.qmod.actor() is not None
    assert m.f.books.begin(m.f.obStatus);m.step(2);assert fact(m,'cycle')==2
    m.f.qmod.clear(m.f.qstatus);m.step(3)
    assert not m.f.qmod.briefingComplete() and fact(m,'stage')==0
    m.start();position(m,1424.737,-2750.759,204.665);m.step(2)
    position(m,1424.737,-2752.759,204.665);m.step(1);m.finish_conversation();m.step(3)
    assert fact(m,'stage')==1 and fact(m,'cycle')==3
    # Native Tick may run before graph cancellation processes request=0.
    # It must not re-latch a legacy final stage after an explicit Clear.
    m.lua.execute("QNative:RequestClear();QNative:Tick(.25)")
    assert not m.f.qmod.briefingComplete()
    m.f.qfacts['ncpd_patrol_qgiver_test_briefed']=1
    assert not m.f.qmod.briefingComplete() # late graph completion stays cancelled
    # An early native return has no final scene receipt and must never award
    # completion or begin the target encounter.
    m=runtime();m.start();m.arrive();m.talk();m.emit(12,'Default RET');m.run();m.step(4)
    assert not m.f.qmod.briefingComplete() and fact(m,'stage')==0 and fact(m,'cycle')==0
    assert m.f.manual==654 and m.f.wallet==0
    report={'reported_v020a1_journal_validation_deletion_reproduced':True,
        'old_native_default_return_cancellation_reproduced':True,
        'both_native_return_ports_use_actual_final_receipt':True,
        'voss_retained_during_pending_or_rejected_journal':True,
        'parent_and_description_activation_before_objective':True,
        'missing_dependency_retries_with_specific_reason':True,
        'same_pending_cycle_recovers_without_duplicates':True,
        'explicit_cancel_survives_reload_and_new_briefing_rearms':True,
        'first_quest_completion_retried_without_replaying_speech':True,
        'early_return_cannot_fabricate_briefing':True,'actual_game_validation':False}
    p=argparse.ArgumentParser();p.add_argument('--report',type=Path);a=p.parse_args()
    if a.report:a.report.write_text(json.dumps(report,indent=2)+'\n')
    print('PASS: exact v0.20a1 completion-check deletion and Default RET cancellation reproduced; durable receipt, retained Voss, async/rejected journal activation, retry/cancel/load and both return paths')
if __name__=='__main__':main()
