"""Execute assassination reporting through the pinned native quest request.

The engine request queue and police response are recording boundaries. These
tests do not claim real police spawning, live cooldown or game serialization.
"""
from pathlib import Path
import argparse,json,subprocess
from check_off_books import runtime,encounter,killed,restore,fact,state,PREFIX,ROOT

def main():
    m=runtime();encounter(m)
    assert not m.f.wanted and len(m.f.obWantedRequests)==0
    target=m.f.obRole('target');target.down=True;target.unconscious=True;m.step(2)
    assert fact(m,'killed')==0 and len(m.f.obWantedRequests)==0
    killed(m)
    assert fact(m,'stage')==2 and fact(m,'acquired')==0 and m.f.obHeat==3 and m.f.wanted
    assert len(m.f.obWantedRequests)==m.f.obNativeWantedCalls==1
    request=m.f.obWantedRequests[1]
    assert request.m_wantedLevel==3 and request.m_forcePlayerPositionAsLastCrimePoint
    assert not request.m_forceGreyStars and not request.m_resetGreyStars and not request.m_forceIgnoreSecurityAreas
    assert m.f.obHeatReason=='QuestEvent'
    assert all(m.f.obPrevention.lastKnown[key]==m.f.playerPoint[key] for key in ['x','y','z'])
    assert not m.f.obPrevention.m_forceEternalGreyStars
    m.step(30);assert len(m.f.obWantedRequests)==1
    m.f.obLoot();m.step(1)
    assert fact(m,'stage')==3 and state(m,'escape')==2 and state(m,'return')==1
    restore(m);assert fact(m,'stage')==3 and len(m.f.obWantedRequests)==1
    m.f.wanted=False;m.step(2)
    assert fact(m,'stage')==4 and state(m,'escape')==3 and state(m,'return')==2
    restore(m);m.step(60)
    assert not m.f.wanted and len(m.f.obWantedRequests)==1 and fact(m,'stage')==4
    assert len(m.f.creates)==6 and m.f.obseedCount==1 and m.f.wallet==0
    # An existing higher chase is never downgraded or reset by our report.
    for heat in [3,4,5]:
        m=runtime();encounter(m);m.f.wanted=True;m.f.obHeat=heat;killed(m)
        assert m.f.obHeat==heat and len(m.f.obWantedRequests)==0 and fact(m,'death_wanted_reported')==1
        m.f.wanted=False;m.f.obLoot();m.step(1)
        assert fact(m,'stage')==4 and len(m.f.obWantedRequests)==0
    # Pre-looted evidence cannot take Return in the same tick as a queued
    # native wanted request; the ordinary next-frame delivery selects Escape.
    m=runtime();encounter(m);m.f.obLoot();m.step(.25)
    m.f.obRole('target').dead=True;m.step(.25)
    assert fact(m,'stage')==2 and len(m.f.obWantedQueue)==1 and m.f.obNativeWantedCalls==0
    m.step(.25);assert fact(m,'stage')==3 and m.f.obHeat==3 and m.f.obNativeWantedCalls==1
    # Missing service defers rather than duplicating sends or skipping Escape.
    m=runtime();encounter(m);m.f.obMissingPrevention=True;killed(m);m.f.obLoot();m.step(2)
    assert fact(m,'stage')==2 and fact(m,'death_wanted_reported')==0 and len(m.f.obWantedRequests)==0
    m.f.obMissingPrevention=False;m.step(1)
    assert fact(m,'stage')==3 and m.f.obHeat==3 and len(m.f.obWantedRequests)==1
    for flag in ['menu','ready','duty','obPlayerDead']:
        m=runtime();encounter(m);m.f.obRole('target').dead=True
        setattr(m.f,flag,False if flag=='ready' else True);m.step(2)
        assert len(m.f.obWantedRequests)==0,flag
        setattr(m.f,flag,True if flag=='ready' else False);m.step(1)
        assert len(m.f.obWantedRequests)==1,flag
    # Update migration: dead legacy encounters and completed saves must not be
    # attacked again. An alive legacy target arms for its subsequent death.
    for stage in [2,3,4]:
        m=runtime();encounter(m);m.f.obRole('target').dead=True
        m.f.qfacts.ncpd_patrol_otb_death_wanted_policy=0
        m.f.qfacts.ncpd_patrol_otb_killed=1;m.f.qfacts.ncpd_patrol_otb_stage=stage
        restore(m);m.step(3)
        assert not m.f.wanted and len(m.f.obWantedRequests)==0 and fact(m,'death_wanted_policy')==2,stage
    m=runtime();encounter(m);m.f.qfacts.ncpd_patrol_otb_death_wanted_policy=0;restore(m)
    assert fact(m,'death_wanted_policy')==1
    killed(m);assert len(m.f.obWantedRequests)==1 and m.f.obHeat==3
    # Cancellation does not erase a crime, and it cannot report another one.
    m.books.Cancel(m.books);m.step(3)
    assert m.f.wanted and len(m.f.obWantedRequests)==1
    m=runtime();encounter(m);m.books.Cancel(m.books);m.f.obRole('target').dead=True;m.step(2)
    assert len(m.f.obWantedRequests)==0
    # Strictly retain the confirmed weapon/loot/event implementation.
    base='a70f6c697ec39ef502b8e3bec5f610a33b96b4a3'
    for path in ['r6/scripts/NCPDPatrol/NCPDPatrolOffBooksCombat.reds','r6/scripts/NCPDPatrol/NCPDPatrolOffBooksLoot.reds','r6/scripts/NCPDPatrol/NCPDPatrolOffBooksEvents.reds','r6/tweaks/NCPDPatrol_OffTheBooks.yaml']:
        assert (ROOT/path).read_bytes()==subprocess.check_output(['git','show',base+':'+path],cwd=ROOT),path
    result={'one_native_heat3_quest_request_per_death_cycle':True,'native_queue_and_handler_sources_executed':True,
        'higher_wanted_levels_not_lowered':True,'no_forced_grey_stars_or_cooldown_override':True,
        'evidence_still_required_then_escape_and_return':True,'no_reapplication_after_escape_or_transient_reload':True,
        'existing_dead_legacy_saves_not_retroactively_pursued':True,'alive_legacy_encounters_arm_for_future_death':True,
        'pause_world_duty_cancel_and_missing_service_guards':True,'confirmed_loot_combat_and_events_unchanged':True,
        'actual_police_response_and_cooldown_verified':False,'actual_game_validation':False}
    p=argparse.ArgumentParser();p.add_argument('--report',type=Path);a=p.parse_args()
    if a.report:a.report.write_text(json.dumps(result,indent=2)+'\n')
    print('PASS: one native three-star quest request, exact pinned handler, Retrieve/Escape/Return, higher heat, pause/cancel/missing service, legacy migration and no renewed pursuit after load/escape (engine response unverified)')

if __name__=='__main__':main()
