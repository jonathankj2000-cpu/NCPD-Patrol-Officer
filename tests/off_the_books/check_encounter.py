"""Execute the scoped decision hooks and native loot refresh against game code.

Source/API checks complement this test. Native zone provenance, actual component
event handling, rendered loot, real gunfire and save serialization need the game.
"""
from pathlib import Path
import argparse,hashlib,json,subprocess,sys
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
sys.path.insert(0,str(HERE))
from check_off_books import runtime,encounter,killed,restore,fact,position

def hooks(m):
    g=m.lua.globals();c=m.f.obContext;s=m.f.obSI
    return (g.ScopedSceneTierInitialDecisions.EnterCondition(g.ScopedSceneTierInitialDecisions,c,s),
            g.ScopedSceneTierIIDecisions.EnterCondition(g.ScopedSceneTierIIDecisions,c,s),
            g.ScopedSceneTierAbstractDecisions.ToExploration(g.ScopedSceneTierAbstractDecisions,c,s))

def originals(m):
    g=m.lua.globals();c=m.f.obContext;s=m.f.obSI;r=g.GameReference
    return (r.SceneTierInitialDecisions.EnterCondition(r.SceneTierInitialDecisions,c,s),
            r.SceneTierIIDecisions.EnterCondition(r.SceneTierIIDecisions,c,s),
            r.SceneTierAbstractDecisions.ToExploration(r.SceneTierAbstractDecisions,c,s))

def native_restricted(m):
    g=m.lua.globals();native=g.GameReference.SceneTierAbstractEvents
    native.OnUpdate(native,.25,m.f.obContext,m.f.obSI)

def native_exploration(m):
    g=m.lua.globals();native=g.GameReference.ExplorationEvents
    native.OnEnter(native,m.f.obContext,m.f.obSI)

def empty_hands(m):
    g=m.lua.globals();native=g.GameReference.DefaultTransition
    # The predicate calls the inherited helper supplied by the game boundary.
    native.IsNoCombatActionsForced=m.lua.eval('function() return F.obNoCombatTag==true end')
    return native.IsEmptyHandsForced(native,m.f.obContext,m.f.obSI)

def combat():
    # Baseline: real native Tier2 decisions force hands; its HighLevel listener
    # independently prevents Ready even if an empty-hands flag is removed.
    m=runtime();assert hooks(m)==(True,True,False)
    assert empty_hands(m) and not m.f.obWeaponReady.m_weaponReadyListenerReturnValue
    m.f.obContext['values'].ForceEmptyHands=False
    assert not empty_hands(m) and not m.f.obWeaponReady.m_weaponReadyListenerReturnValue
    native_restricted(m);assert empty_hands(m)
    assert m.f.obBoard['values'].high==2
    # Actual ten-turn briefing -> accepted operation -> owned target binding.
    encounter(m);before=len(m.f.obPSMWrites);assert hooks(m)==(False,False,True)
    assert len(m.f.obPSMWrites)==before,'Decision hooks must never write PSM state'
    native_exploration(m)
    assert m.f.obBoard['values'].high==1 and not empty_hands(m)
    assert m.f.obWeaponReady.m_weaponReadyListenerReturnValue
    assert m.f.obTierData.tier==2 and m.f.obTierData.emptyHands,'Native request must remain untouched'
    for _ in range(30):assert hooks(m)==(False,False,True)
    # Leaving the radius immediately delegates again; native re-entry performs
    # its own state reset. No stored permission or blanket restoration write.
    position(m,-649.795+21);assert hooks(m)==(True,True,False)
    native_restricted(m)
    assert m.f.obBoard['values'].high==2 and empty_hands(m)
    assert not m.f.obWeaponReady.m_weaponReadyListenerReturnValue
    position(m);assert hooks(m)==(False,False,True)
    assert m.f.books.clear(m.f.obStatus) and hooks(m)==(True,True,False)
    # Each excluded condition exercises all three hooks and the original game
    # decision method exactly once. Never reset unrelated dialogue/cinematics.
    cases={
        'world unavailable':"F.ready=false",
        'menu':"F.menu=true",
        'on duty':"F.duty=true",
        'escape':"F.qfacts.ncpd_patrol_otb_stage=3",
        'return':"F.qfacts.ncpd_patrol_otb_stage=4",
        'evidence already acquired':"F.qfacts.ncpd_patrol_otb_acquired=1",
        'player dead':"F.obPlayerDead=true",
        'player detached':"F.playerAttached=false",
        'another floor':"F.playerPoint=Vector4.new(-649.795,929.771,13.4,1)",
        'target detached':"F.obRole('target').attached=false",
        'target no longer owned':"F.managed[F.obRole('target'):GetEntityID().hash]=nil",
        'journal interrupted':"F.entries['quests/minor_quest/ncpd_patrol_off_the_books'].state=4",
        'first dialogue':"F.qfacts.ncpd_patrol_qgiver_test_stage=2",
        'native dialogue':"F.qforeignDialogue=true",
        'native scene animation':"F.obSceneAnimation=true",
        'workspot':"F.obPlayerWorkspot=true",
        'vehicle':"F.mounted=true",
        'takedown':"F.obTakedown=true",
        'swimming transition':"F.obContext.values.enteredWaterFromSceneTierII=true",
        'real safe zone':"F.obContext.values.ForceEmptyHandsByZone=true",
        'independent quest restriction':"F.qfacts.ForceEmptyHands=1",
        'cinematic high level':"F.obBoard.values.high=3",
        'different Tier2 data':"F.obTierData.emptyHands=false",
    }
    for effect in ['NoCombat','NoWeapons','InDaClub','NoWorldInteractions']:
        cases[effect]="F.obRestrictions={['GameplayRestriction.%s']=true}"%effect
    for label,mutation in cases.items():
        m=runtime();encounter(m);assert hooks(m)==(False,False,True),label
        calls={k:m.f.obPSMOriginalCalls[k] for k in ['initial','tier2','exploration']}
        m.lua.execute(mutation);before=len(m.f.obPSMWrites)
        assert hooks(m)==originals(m),(label,hooks(m),originals(m))
        assert len(m.f.obPSMWrites)==before,label
        assert all(m.f.obPSMOriginalCalls[k]==v+1 for k,v in calls.items()),label
    for tier in [1,3,4,5]:
        m=runtime();encounter(m);m.f.obTierData.tier=tier
        assert hooks(m)==(tier>1,False,tier==1),tier
    # Restoration has no permission receipt: detached references deny scope
    # until the same saved actor is recovered. No duplicate target or shard.
    m=runtime();encounter(m);assert hooks(m)==(False,False,True)
    m.books.OnRestored(m.books,0,0);assert hooks(m)==(True,True,False)
    m.f.books.reset();m.step(2);assert hooks(m)==(False,False,True)
    assert len(m.f.creates)==6 and m.f.obseedCount==1
    m.f.obPoliceResponse=True;m.f.obHit(m.f.obRole('target'),m.f.player)
    assert m.f.wanted and hooks(m)==(False,False,True),'Wanted response must not disable the encounter exception'
    return len(cases)

def loot():
    # Reproduce quantity != loot: initial invalid loot quality does not get
    # evaluated by the real OnItemAddedEvent, even with a shard in inventory.
    m=runtime();m.f.obInitialLootInaccessible=True;encounter(m)
    target=m.f.obRole('target');target.OnItemAddedEvent(target,m.lua.table_from({}))
    assert fact(m,'seeded')==1 and fact(m,'qty_before')==1
    assert not target.IsContainer(target) and not target.m_inventoryComponent.accessible
    target.dead=True;target.UpdateLootInteraction(target);assert not target.obLootLayer
    m.step(1)
    assert fact(m,'killed')==1 and fact(m,'stage')==2 and fact(m,'acquired')==0
    assert m.f.obAccessRequests==1 and not target.m_inventoryComponent.accessible
    assert not target.NCPDPatrolOffBooksLootReady(target),'An accepted event is not accessibility proof'
    m.step(2)
    assert target.NCPDPatrolOffBooksLootReady(target) and target.obLootLayer
    assert target.m_hasQuestItems and target.obQualityLayer=='QualityRange_Max'
    assert fact(m,'qty_after')==1 and fact(m,'qty_after_seen')==1 and m.f.obseedCount==1
    assert fact(m,'acquired')==0 and m.f.obOriginalAdded==0
    assert 'not observed' in target.NCPDPatrolOffBooksLootDiagnostics(target)
    # The read-only diagnostic only says available when the native Loot input
    # is actually active for V. Prerequisites alone do not claim visible UI.
    m.f.obLookingAtBody=True
    writes=m.f.obInteractionRequests;quality=m.f.obQualityRequests
    assert 'available (native Loot input layer active' in target.NCPDPatrolOffBooksLootDiagnostics(target)
    m.f.books.diagnostics()
    assert writes==m.f.obInteractionRequests and quality==m.f.obQualityRequests
    # Save before pickup, reload far away, then return to the same corpse.
    position(m,-1000,1000,9.4);restore(m)
    assert fact(m,'stage')==2 and m.f.obseedCount==1 and len(m.f.creates)==6
    position(m);m.step(2);assert target.dead and target.NCPDPatrolOffBooksLootReady(target)
    m.f.wanted=True;m.f.obLoot();m.step(1)
    assert fact(m,'acquisition_event')==fact(m,'acquired')==1 and fact(m,'stage')==3
    assert m.f.obPlayerItems[m.f.obitem]==0 and m.f.entries[m.f.obpath].state==2
    assert m.f.obOriginalAdded==1 and m.f.obseedCount==1
    assert hooks(m)==(True,True,False),'Loot receipt ends the weapon exception immediately'
    m.f.wanted=False;m.step(1);assert fact(m,'stage')==4
    restore(m);assert fact(m,'acquired')==1 and fact(m,'stage')==4 and m.f.obseedCount==1
    # Missing/disabled components cannot be fabricated into a success. No
    # fallback interaction, automatic transfer, or unlimited refresh loop.
    for flag in ['obMissingInventory','obMissingInteraction','obDisabledInteraction','obAccessDeliveryBlocked']:
        m=runtime();setattr(m.f,flag,True);m.f.obInitialLootInaccessible=True
        encounter(m);killed(m);m.step(15)
        assert fact(m,'stage')==2 and not fact(m,'acquired') and m.books.m_lootAttempts==8,flag
        assert 'unavailable' in m.f.obRole('target').NCPDPatrolOffBooksLootDiagnostics(m.f.obRole('target')),flag
        calls=m.f.obQualityRequests;m.step(10);assert m.f.obQualityRequests==calls,flag
        assert m.f.obseedCount==1 and m.f.obOriginalAdded==0,flag
    # A failed native event delivery can recover after a real reload/rebind;
    # the persisted shard and target are retained, not reseeded/reconstructed.
    m.f.obAccessDeliveryBlocked=False;restore(m);m.step(3)
    assert m.f.obRole('target').NCPDPatrolOffBooksLootReady(m.f.obRole('target'))
    assert m.f.obseedCount==1 and len(m.f.creates)==6
    # A lost item is diagnosed rather than being silently duplicated, and
    # death alone is never mistaken for a real player acquisition event.
    m=runtime();encounter(m);killed(m);target=m.f.obRole('target')
    key=target.GetEntityID(target).hash;m.f.obInventory[key][m.f.obitem]=0
    restore(m);m.step(3)
    assert fact(m,'stage')==2 and fact(m,'acquired')==0 and m.f.obseedCount==1

def main():
    reference=json.loads((HERE/'game_reference.json').read_text())
    assert reference['commit']=='81d996b584a693e8b0f0b20526a9fa38b5c83fe7'
    for row in reference['methods'].values():
        assert hashlib.sha256(row['source'].encode()).hexdigest()==row['source_sha256']
    # All first-dialogue assets, voice/lipsync, and existing private NPC/shard
    # definitions are frozen; there is no speculative archetype/tag replacement.
    base='a9d4e67901b75ec3c0f655098822371afd26cff6'
    frozen=subprocess.check_output(['git','ls-tree','-r','--name-only',base,'--','assets/quest_giver_test','assets/off_the_books','archive','r6/tweaks'],cwd=ROOT,text=True).splitlines()
    frozen+=['r6/scripts/NCPDPatrol/NCPDPatrolQuestGiverTest.reds','r6/scripts/NCPDPatrol/NCPDPatrolVossSubtitles.reds','bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrol/quest_giver_test.lua']
    from audio_source import AUDIO_ASSETS
    # The separate audio suite verifies only per-line mix context/cache hash
    # changes and recompilation; all other first-scene payload remains frozen.
    for path in frozen:
        if path in AUDIO_ASSETS:continue
        if path=='r6/tweaks/NCPDPatrol_OffTheBooks.yaml':
            # Only the contractor's private native death-loot table is added;
            # the new death-loot suite validates its exact schema and identity.
            from death_loot_fixture import records
            old=records(subprocess.check_output(['git','show',base+':'+path],cwd=ROOT,text=True));current=records()
            for key,row in old.items():
                actual=dict(current[key])
                if key=='Character.NCPDPatrol_VossContractor01':actual.pop('lootDrop')
                assert actual==row,key
            continue
        assert (ROOT/path).read_bytes()==subprocess.check_output(['git','show',base+':'+path],cwd=ROOT),path
    exclusions=combat();loot()
    source='\n'.join((ROOT/'r6/scripts/NCPDPatrol'/n).read_text() for n in ['NCPDPatrolOffBooksCombat.reds','NCPDPatrolOffBooksLoot.reds','NCPDPatrolOffBooksSystem.reds'])
    for forbidden in ['SetPermanentBoolParameter','SetPermanentScriptableParameter','SetTierData','RemoveStatusEffect','AddGodMode','RegisterInputListener','SetBlackboardIntVariable']:
        assert forbidden not in source,forbidden
    report={'pinned_game_methods_executed':len(reference['methods']),'native_tier2_empty_hands_and_weapon_ready_failure_reproduced':True,
        'actual_three_psm_decision_wrappers_executed':True,'scope_exclusions_executed':exclusions,
        'native_exploration_reset_and_weapon_ready_listener_executed':True,'native_restrictions_resume_outside_scope':True,
        'native_tier_request_never_modified':True,'hooks_never_write_psm_blackboards':True,
        'quantity_without_native_loot_quality_failure_reproduced':True,'actual_native_loot_refresh_executed':True,
        'event_acceptance_distinct_from_readback':True,'only_observed_native_loot_layer_reports_available':True,
        'missing_components_and_rejected_events_do_not_claim_success':True,'bounded_refresh_and_reload_rebind':True,
        'actual_item_event_required_no_kill_grant':True,'shard_and_actor_not_duplicated':True,
        'save_transient_resets_before_and_after_pickup':True,'wanted_escape_and_return_preserved':True,
        'all_first_dialogue_assets_and_existing_npc_item_fields_retained':True,
        'native_zone_sender_identified':False,'rendered_native_loot_ui_verified':False,'actual_game_validation':False}
    p=argparse.ArgumentParser();p.add_argument('--report',type=Path);args=p.parse_args()
    if args.report:args.report.write_text(json.dumps(report,indent=2)+'\n')
    print('PASS: restaurant-scoped native PSM transitions, restriction restoration, corpse loot refresh/readback, real item receipt, wanted stages and saved-actor recovery')
if __name__=='__main__':main()
