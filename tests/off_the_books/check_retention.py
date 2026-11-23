"""Retained Voss and persistent-role recovery, using both real controllers."""
from pathlib import Path
import argparse,json,subprocess,sys
HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE))
from check_off_books import runtime,briefing,encounter,killed,restore,fact,position,ROOT,PREFIX

def main():
    m=runtime();briefing(m);initial=len(m.f.creates);lines=list(m.lines)
    assert initial==3 and m.f.qPoseActive() and m.f.qmod.actor() is not None
    position(m);m.step(2);assert len(m.f.creates)==6
    # Recover far away, then return to the same managed Voss/car and recreate
    # only their transient pose state. The old first scene never repeats.
    restore(m);m.step(10);assert not m.f.deletes[1] and len(m.f.creates)==6 and m.lines==lines
    position(m,1424.737,-2752.759,204.665);m.step(3)
    assert m.f.qmod.actor() is not None and m.f.qPoseActive() and len(m.f.creates)==6
    assert m.lines==lines and fact(m,'stage')==1 and m.f.manual==654
    # Unloaded saved encounter rows are re-enabled, never reconstructed at new
    # IDs. State/inventory receipt survive save and quest transient resets.
    position(m);m.step(1);m.f.obRole('target').attached=False;m.f.obKeepUnloaded=True
    restore(m);m.step(2);assert len(m.f.creates)==6 and m.f.obEnables>0
    m.f.obKeepUnloaded=False;m.step(2);assert m.f.obRole('target').attached and len(m.f.creates)==6
    killed(m);m.f.obLoot();m.step(1);assert fact(m,'stage')==3
    m.f.wanted=False;m.step(1);assert fact(m,'stage')==4
    restore(m);position(m,1424.737,-2752.759,204.665);m.step(2)
    assert fact(m,'returned')==1 and m.f.qmod.actor() is not None and len(m.f.creates)==6
    assert m.lines==lines and m.f.qfacts['ncpd_patrol_qgiver_test_stage']==3
    assert not m.f.qmod.blocksDuty() and not m.f.books.blocksDuty() and m.f.wallet==0
    m.f.qmod.shutdown();m.f.books.shutdown();m.step(2)
    assert fact(m,'stage')==4 and m.f.qfacts['ncpd_patrol_qgiver_test_stage']==3 and not m.f.deletes[1]
    # Cosmetic readiness failure after restoration retains the quest and pair.
    m.f.qposeLinks=m.lua.table_from({});m.f.qposeLoadFailed=True;restore(m);m.step(12)
    assert fact(m,'stage')==4 and m.f.qmod.actor() is not None and not m.f.deletes[1]
    # Encounter-only clear preserves the first scene receipt. Explicit full
    # clear cancels both slices and releases the pose device before the pair.
    assert m.f.books.clear(m.f.obStatus);m.step(2)
    assert fact(m,'stage')==0 and m.f.qfacts['ncpd_patrol_qgiver_test_stage']==3
    assert m.f.qmod.actor() is not None and m.f.books.begin(m.f.obStatus)
    assert fact(m,'stage')==1 and fact(m,'cycle')==2
    assert m.f.qmod.clear(m.f.qstatus);m.step(3)
    assert fact(m,'stage')==0 and m.f.qfacts['ncpd_patrol_qgiver_test_stage']==0
    assert not m.f.qmod.active() and m.f.manual==654 and m.f.wallet==0
    # A previously-created role with a missing live reference is not proof
    # that a killed/unloaded saved actor may be replaced.
    m=runtime();encounter(m);target=m.f.obRole('target');key=target.GetEntityID(target).hash
    m.f.objects[key]=None;m.f.managed[key]=None;restore(m);m.step(2)
    assert len(m.f.creates)==6 and fact(m,'stage')==1 and 'no duplicate was spawned' in m.f.books.diagnostics()
    # A partial create failure preserves already-created roles, then finishes
    # only missing roles after the boundary becomes available.
    m=runtime();briefing(m);m.f.failCreateAt=5;position(m);m.step(.25)
    assert fact(m,'created_target')==1 and fact(m,'created_guard1')==0
    m.f.failCreateAt=None;m.step(2)
    target_ids=[k for k,v in m.f.objects.items() if v.record=='Character.NCPDPatrol_VossContractor01']
    assert len(target_ids)==1 and fact(m,'created_guard1')==fact(m,'created_guard2')==1
    # Evidence failure cannot advance the quest or compensate by giving V an
    # item. Clearing/retrying remains explicit and retains native shard history.
    m=runtime();m.f.obGiveFailed=True;encounter(m);m.step(12)
    assert fact(m,'seeded')==fact(m,'acquired')==0 and m.f.obseedCount==0
    assert 'could not be placed' in m.f.books.diagnostics()
    m.f.obGiveFailed=False;m.step(1);assert fact(m,'seeded')==1 and m.f.obseedCount==1
    # If the whole saved pair really disappeared, retire its orphaned pose
    # helper before rebuilding the same meeting. Partial pairs are retained.
    m=runtime();briefing(m)
    m.lua.execute("for k,a in pairs(F.objects) do if a.record=='Character.NCPDPatrol_QG_Investigator' or a.record=='Vehicle.NCPDPatrol_QG_Hella' then a.attached=false;F.managed[k]=nil;F.objects[k]=nil end end")
    restore(m);m.step(4)
    assert len(m.f.creates)==6 and len(m.f.deletes)==1 and m.f.qmod.actor() is not None and m.f.qPoseActive()
    assert fact(m,'stage')==1
    # Previous published controller demonstrates the recovery failure: it
    # clears a completed briefing and removes Voss instead of retaining her.
    old=runtime();briefing(old)
    source=subprocess.check_output(['git','show','6197a48def37b8bdcf2dcf785a0e81e9a7d9fee4:'+PREFIX+'quest_giver_test.lua'],cwd=ROOT,text=True)
    old.lua.globals().QNative.Version=lambda _self:3
    old.f.qmod=old.lua.execute(source);old.f.obConfigureRetention();old.step(3)
    assert old.f.qfacts['ncpd_patrol_qgiver_test_stage']==0 and len(old.f.deletes)==3
    report={'voss_same_managed_pair_after_restore':True,'briefing_not_replayed':True,
        'return_arrival_fact_and_future_debrief_boundary':True,'transient_pose_failure_retains_voss':True,
        'unloaded_same_entity_enabled':True,'missing_created_role_never_duplicated':True,
        'partial_creation_recovers_without_duplicates':True,'shard_seed_failure_never_grants_player_item':True,
        'explicit_clear_and_shutdown_boundaries':True,'orphan_helper_removed_before_missing_pair_rebuild':True,
        'previous_completed_briefing_recovery_deletion_reproduced':True,'actual_game_validation':False}
    p=argparse.ArgumentParser();p.add_argument('--report',type=Path);a=p.parse_args()
    if a.report:a.report.write_text(json.dumps(report,indent=2)+'\n')
    print('PASS: retained Voss/car/pose recovery, no briefing replay, return arrival, unloaded/missing/partial encounter roles and explicit cancellation')
if __name__=='__main__':main()
