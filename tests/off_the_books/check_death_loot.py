"""Regression for the observed live=1/dead=0 corpse, native loot and migration.

ProcessLoot's internals are native/opaque. Their reported inventory replacement
is an explicit engine boundary here, with independent rejection/pending cases.
"""
from pathlib import Path
import argparse,hashlib,json,subprocess,sys
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
sys.path.insert(0,str(HERE))
from check_off_books import runtime,encounter,killed,restore,fact,position,PREFIX
from death_loot_fixture import records
BASE='9e41604a4935f55e081eab035bf122f986c8ba2e'

def old(path):return subprocess.check_output(['git','show',BASE+':'+path],cwd=ROOT,text=True)
def quantity(m):return m.books.EvidenceQuantity(m.books)
def current():
    m=runtime();m.f.obModelDeathLoot=True;return m
def empty_saved_corpse(m):
    target=m.f.obRole('target');target.dead=True;target.obIncapacitationSeen=True;target.obNativeLootGenerated=True
    m.f.obInventory[target.GetEntityID(target).hash][m.f.obitem]=0
    return target

def main():
    data=records();actor=data['Character.NCPDPatrol_VossContractor01'];table=data[actor['lootDrop']];item=data[table['lootItems'][0]]
    assert table=={'$type':'LootTable','minItemsToLoot':1,'maxItemsToLoot':1,'lootItems':['LootItems.NCPDPatrol_VossEvidence01']}
    assert item=={'$type':'LootItem','itemID':'Items.NCPDPatrol_VossEvidence01','dropChance':1.0,'dropCountMin':1,'dropCountMax':1}
    previous=records(old('r6/tweaks/NCPDPatrol_OffTheBooks.yaml'))
    assert set(data)-set(previous)=={'LootTables.NCPDPatrol_VossEvidence01','LootItems.NCPDPatrol_VossEvidence01'}
    for name,row in previous.items():
        actual=dict(data[name])
        if name=='Character.NCPDPatrol_VossContractor01':actual.pop('lootDrop')
        assert actual==row,name
    # Exact published v0.20c controller + Lua: native death processing removes
    # the alive seed, the inherited empty drop produces nothing, and the
    # quantity guard prevents even trying the native loot refresh.
    m=runtime(native_source=old('r6/scripts/NCPDPatrol/NCPDPatrolOffBooksSystem.reds'))
    m.f.books=m.lua.execute(old(PREFIX+'off_the_books.lua'))
    m.lua.execute("F.books.configure({status=F.obStatus,worldReady=function() return F.ready end,onDuty=function() return F.duty end,voss=function() return F.qmod.actor() end});F.obConfigureRetention()")
    m.f.obModelDeathLoot=True;m.f.obNativeEmptyRoll=True;encounter(m);assert quantity(m)==1
    killed(m);m.step(15)
    assert fact(m,'qty_before')==1 and fact(m,'qty_after')==0 and quantity(m)==0
    assert fact(m,'stage')==2 and fact(m,'seeded')==1 and fact(m,'acquired')==0
    assert m.books.m_lootAttempts==0 and m.f.obQualityRequests==0
    target=m.f.obRole('target');assert target.m_inventoryComponent.accessible and target.m_interactionComponent.isEnabled
    assert not target.IsContainer(target)
    # New native table supplies one physical corpse item after the alive seed
    # is removed. No repair, no automatic player item/receipt, normal Loot.
    m=current();encounter(m);assert quantity(m)==1
    killed(m);m.step(2);target=m.f.obRole('target')
    assert m.f.obNativeGeneratedItems==1 and quantity(m)==1 and m.f.obseedCount==1
    assert fact(m,'corpse_confirmed')==1 and fact(m,'corpse_repair_used')==0
    assert fact(m,'stage')==2 and fact(m,'acquired')==0 and target.obLootLayer
    m.f.obLookingAtBody=True
    assert 'available (native Loot input layer active' in target.NCPDPatrolOffBooksLootDiagnostics(target)
    m.f.wanted=True;m.f.obLoot();m.step(1)
    assert fact(m,'acquired')==fact(m,'acquisition_event')==1 and fact(m,'stage')==3
    assert m.f.obPlayerItems[m.f.obitem]==0 and m.f.entries[m.f.obpath].state==2
    m.f.wanted=False;m.step(1);assert fact(m,'stage')==4
    restore(m);assert quantity(m)==0 and m.f.obseedCount==1 and len(m.f.creates)==6
    # Existing v0.20c save: same owned corpse, already generated but empty.
    # Preserve the original after-death=0 observation; only live quantity changes.
    m=current();encounter(m);target=empty_saved_corpse(m);m.step(3)
    assert fact(m,'qty_after')==0 and quantity(m)==1 and m.f.obseedCount==2
    assert fact(m,'corpse_repair_used')==fact(m,'corpse_confirmed')==1
    assert fact(m,'acquired')==0 and fact(m,'stage')==2 and target.obLootLayer
    created=len(m.f.creates);restore(m);m.step(10)
    assert quantity(m)==1 and m.f.obseedCount==2 and len(m.f.creates)==created
    m.f.obLoot();m.step(2);restore(m);m.step(10)
    assert fact(m,'acquired')==1 and quantity(m)==0 and m.f.obseedCount==2
    # If native generation preserves the live seed, collapse only this exact
    # item in the owned corpse to one before the default delayed Loot window.
    m=current();m.f.obNativePreserveLiveItem=True;encounter(m);killed(m);m.step(2)
    assert quantity(m)==1 and m.f.obRemovedEvidence==1 and m.f.obseedCount==1
    assert fact(m,'corpse_repair_used')==0
    # Do not race a still-pending native inventory rebuild. Use the vanilla
    # WasLootGenerated/ProcessLoot guard once, then read back rather than loop it.
    m=current();m.f.obNativeLootPending=True;encounter(m);killed(m);m.step(3)
    assert fact(m,'stage')==2 and fact(m,'corpse_confirmed')==0 and m.f.obseedCount==1
    assert m.f.obNativeProcessCalls==2 and not m.f.obRole('target').WasLootGenerated(m.f.obRole('target'))
    m.f.obNativeLootPending=False;m.f.obRole('target').ProcessLoot(m.f.obRole('target'));m.step(2)
    assert fact(m,'corpse_confirmed')==1 and quantity(m)==1 and m.f.obseedCount==1
    # Permanent pending/rejected operations are bounded and cannot advance.
    m=current();m.f.obNativeLootPending=True;encounter(m);killed(m);m.step(20)
    assert m.books.m_lootAttempts==8 and m.f.obNativeProcessCalls==2 and fact(m,'acquired')==0
    m=current();encounter(m);target=empty_saved_corpse(m);m.f.obGiveFailed=True;m.step(20)
    assert m.books.m_lootAttempts==8 and quantity(m)==0 and fact(m,'corpse_repair_used')==0
    m.f.obGiveFailed=False;restore(m);m.step(2)
    assert quantity(m)==1 and fact(m,'corpse_repair_used')==1 and m.f.obseedCount==2
    # Accepted grant without immediate readback cannot cause repeated grants.
    # The one-use migration receipt survives another restore.
    m=current();encounter(m);target=empty_saved_corpse(m)
    m.lua.execute("local tx=GameInstance:GetTransactionSystem({});local give=tx.GiveItem;function tx:GiveItem(actor,item,n) if item==F.obitem then F.obAcceptedDeferred=(F.obAcceptedDeferred or 0)+1;return true end;return give(self,actor,item,n) end")
    m.step(15);restore(m);m.step(10)
    assert m.f.obAcceptedDeferred==1 and fact(m,'corpse_repair_used')==1 and quantity(m)==0 and fact(m,'acquired')==0
    # Confirmed evidence that subsequently leaves the body is not replenished:
    # e.g. body disposal, a pending native pickup, or an external inventory edit.
    m=current();encounter(m);killed(m);m.step(2);target=m.f.obRole('target')
    m.f.obInventory[target.GetEntityID(target).hash][m.f.obitem]=0;restore(m);m.step(10)
    assert quantity(m)==0 and m.f.obseedCount==1 and fact(m,'corpse_repair_used')==0
    m=current();encounter(m);target=empty_saved_corpse(m);m.f.obPlayerItems[m.f.obitem]=1;m.step(4)
    # Actual player possession now provides a durable receipt even if its item
    # event is delayed; the corpse must still never receive another copy.
    assert quantity(m)==0 and m.f.obseedCount==1 and fact(m,'acquired')==1
    assert m.books.EvidenceReceiptSource(m.books)=='player inventory readback'
    # Query IDs find the evidence even when a specific instance lookup misses.
    m=current();m.f.obExactInstanceMiss=True;encounter(m);assert quantity(m)==1 and m.f.obseedCount==1
    killed(m);m.step(2);assert quantity(m)==1 and fact(m,'corpse_repair_used')==0
    # Acquired fact prevents new supplies and removes only an unexpected owned
    # corpse copy after restore. It never removes unrelated/player inventory.
    m.f.obLoot();m.step(1);target=m.f.obRole('target')
    m.f.obInventory[target.GetEntityID(target).hash][m.f.obitem]=1;restore(m);m.step(2)
    assert quantity(m)==0 and fact(m,'acquired')==1 and m.f.obseedCount==1
    # Mixed/incomplete TweakXL packages fail precise readiness checks.
    for flag in ['obMissingDeathLoot','obWrongDeathLoot','obWrongDeathCount']:
        m=runtime();setattr(m.f,flag,True);assert not m.books.RecordsReady(m.books)
    # Preserve the in-game-confirmed combat override and all first-scene media.
    for path in ['r6/scripts/NCPDPatrol/NCPDPatrolOffBooksCombat.reds','r6/scripts/NCPDPatrol/NCPDPatrolOffBooksLoot.reds']:
        assert (ROOT/path).read_text()==old(path),path
    events='r6/scripts/NCPDPatrol/NCPDPatrolOffBooksEvents.reds'
    assert (ROOT/events).read_text().split('@wrapMethod(PlayerPuppet)')[0]==old(events).split('@wrapMethod(PlayerPuppet)')[0]
    system=(ROOT/'r6/scripts/NCPDPatrol/NCPDPatrolOffBooksSystem.reds').read_text()
    previous=old('r6/scripts/NCPDPatrol/NCPDPatrolOffBooksSystem.reds')
    def combat_slice(s):return s[s.index('    // A decision exception'):s.index('    public func Version()')]
    assert combat_slice(system)==combat_slice(previous)
    report={'exact_v020c_live_one_dead_zero_refresh_zero_reproduced':True,
        'inherited_empty_loot_table_identified':True,'private_native_loot_table_exactly_one_evidence':True,
        'normal_native_loot_predicates_and_real_item_receipt_executed':True,'existing_empty_saved_corpse_migration_executed':True,
        'migration_one_use_and_grant_readback_separate':True,'native_generation_wait_and_rejection_bounded':True,
        'duplicate_corpse_copy_trimmed_without_player_grant':True,'pending_pickup_confirmed_removal_and_acquired_guards':True,
        'same_saved_actor_before_after_pickup_no_duplicate':True,'all_weapon_override_code_byte_identical':True,
        'actual_native_generation_internals_emulated':False,'actual_game_validation':False}
    p=argparse.ArgumentParser();p.add_argument('--report',type=Path);args=p.parse_args()
    if args.report:args.report.write_text(json.dumps(report,indent=2)+'\n')
    print('PASS: exact v0.20c empty-corpse regression, native shard loot table, one-use saved-corpse repair, generation/readback guards, duplicate trimming, real pickup and unchanged combat')
if __name__=='__main__':main()
