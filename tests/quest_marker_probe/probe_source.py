"""Remove only the explicitly reviewed r4 opt-in hooks for earlier oracles."""
import re

def without_location_exclusion(source):
    # Exact reviewed H10 eligibility addition only; historical traces retain
    # all other geography/RNG/actor policy. New target cases test the exclusion.
    source=source.replace('local LocationPolicy = require("dispatch_location_policy")\n','')
    source=source.replace('if metres>=500 and metres<=2000 and LocationPolicy.allowed(pin,point,true) then',
                          'if metres>=500 and metres<=2000 then')
    source=source.replace('if (variant==gamedataMappinVariant.FastTravelVariant\n                    or variant==gamedataMappinVariant.ServicePointDropPointVariant)\n                    and LocationPolicy.allowed(pin,point,variant==gamedataMappinVariant.FastTravelVariant) then',
                          'if variant==gamedataMappinVariant.FastTravelVariant\n                    or variant==gamedataMappinVariant.ServicePointDropPointVariant then')
    return source

def without_probe(source):
    source=source.replace('-- NCPD Patrol v0.18b1 Injured Settling Pilot | opt-in three-site transition measurements','-- NCPD Patrol v0.18b Scene Survey | compact layout and 17-site off-duty tour')
    source=source.replace('v0.18b1 Injured Settling Pilot loaded. Testing has an opt-in three-site injured transition probe. Full 17-site surveys retain their original procedure. Existing results are preserved; pilot results use a separate validation profile. Install the complete package and fully restart the game.','v0.18b Scene Survey loaded. Compact Officer Down layout and an explicit off-duty 17-site test tour. City Center and Watson only. Use a manual test save; survey evidence is stored in the CET mod folder. Install the complete package and fully restart the game.')
    source=source.replace('NCPD Patrol - v0.18b1 Injured Settling Pilot###','NCPD Patrol - v0.18b Scene Survey###')
    source=source.replace('-- NCPD Patrol v0.18b Scene Survey | compact layout and 17-site off-duty tour','-- NCPD Patrol v0.18a3 Officer Down placement | automatic rotations and vehicle clearance')
    source=source.replace('v0.18b Scene Survey loaded. Compact Officer Down layout and an explicit off-duty 17-site test tour. City Center and Watson only. Use a manual test save; survey evidence is stored in the CET mod folder. Install the complete package and fully restart the game.','v0.18a3 Officer Down placement loaded. Automatic rotations, vehicle clearance and early preparation with bounded retry. Combat, revive, rewards and dispatch markers are unchanged. Install the complete package and fully restart the game.')
    source=source.replace('NCPD Patrol - v0.18b Scene Survey###','NCPD Patrol - v0.18a3 Officer Down placement###')
    source=re.sub(r'^.* -- scene survey hook[^\n]*\n','',source,flags=re.M)
    source=re.sub(r'^    -- scene survey guard begin\n.*?^    -- scene survey guard end\n','',source,flags=re.M|re.S)
    source=re.sub(r'^-- scene survey setup begin\n.*?^-- scene survey setup end\n\n','',source,flags=re.M|re.S)
    source=source.replace('-- NCPD Patrol v0.18a3 Officer Down placement | automatic rotations and vehicle clearance','-- NCPD Patrol v0.18a2 Officer Down ground fix | typed navigation and full probe height')
    source=source.replace('v0.18a3 Officer Down placement loaded. Automatic rotations, vehicle clearance and early preparation with bounded retry. Combat, revive, rewards and dispatch markers are unchanged. Install the complete package and fully restart the game.','v0.18a2 Officer Down ground fix loaded. Character navigation receives Vector4 ground; probes cover the accepted height range. Other scene behavior and dispatch markers are unchanged. Install the complete package and fully restart the game.')
    source=source.replace('NCPD Patrol - v0.18a3 Officer Down placement###','NCPD Patrol - v0.18a2 Officer Down ground fix###')
    source=source.replace('-- NCPD Patrol v0.18a2 Officer Down ground fix | typed navigation and full probe height','-- NCPD Patrol v0.18a1 Officer Down locator | manual test waypoint button')
    source=source.replace('v0.18a2 Officer Down ground fix loaded. Character navigation receives Vector4 ground; probes cover the accepted height range. Other scene behavior and dispatch markers are unchanged. Install the complete package and fully restart the game.','v0.18a1 Officer Down locator loaded. CET Testing includes a manual waypoint to the test intersection. Existing dispatch markers and scene behavior are unchanged. Install the complete package and fully restart the game.')
    source=source.replace('NCPD Patrol - v0.18a2 Officer Down ground fix###','NCPD Patrol - v0.18a1 Officer Down locator###')
    source=source.replace('-- NCPD Patrol v0.18a1 Officer Down locator | manual test waypoint button','-- NCPD Patrol v0.18a Officer Down | fixed intersection rescue scene')
    source=source.replace('v0.18a1 Officer Down locator loaded. CET Testing includes a manual waypoint to the test intersection. Existing dispatch markers and scene behavior are unchanged. Install the complete package and fully restart the game.','v0.18a Officer Down loaded. Manual fixed-intersection rescue under CET Testing; staged protection, combat and officer revive. VIP routes and arrest fix retained. Install the complete package and fully restart the game.')
    source=source.replace('NCPD Patrol - v0.18a1 Officer Down locator###','NCPD Patrol - v0.18a Officer Down###')
    source=source.replace('-- NCPD Patrol v0.18a Officer Down | fixed intersection rescue scene','-- NCPD Patrol v0.17f VIP route catalogue | fixed endpoint pairs from the native marker bank')
    source=source.replace('v0.18a Officer Down loaded. Manual fixed-intersection rescue under CET Testing; staged protection, combat and officer revive. VIP routes and arrest fix retained. Install the complete package and fully restart the game.','v0.17f VIP route catalogue loaded. 360 baked routes use 60 canonical native-marker endpoints. Includes the arrest initialization fix. Install the complete package and fully restart the game.')
    source=source.replace('NCPD Patrol - v0.18a Officer Down###','NCPD Patrol - v0.17f VIP route catalogue###')
    # Reviewed additive manual Officer Down controls; old menu routes remain.
    source=re.sub(r'^        -- Officer Down UI begin\n.*?^        -- Officer Down UI end\n','',source,flags=re.M|re.S)
    # Reviewed VIP route release labels; coordinator/session code is unchanged.
    source=source.replace('-- NCPD Patrol v0.17f VIP route catalogue | fixed endpoint pairs from the native marker bank','-- NCPD Patrol v0.17e2 arrest initialization | prepare private bindings before helper attachment')
    source=source.replace('v0.17f VIP route catalogue loaded. 360 baked routes use 60 canonical native-marker endpoints. Includes the arrest initialization fix. Install the complete package and fully restart the game.','v0.17e2 arrest initialization loaded. Private animation bindings are prepared before helper attachment. Includes the H10 dispatch exclusion. Install the complete package and fully restart the game.')
    source=source.replace('NCPD Patrol - v0.17f VIP route catalogue###','NCPD Patrol - v0.17e2 arrest initialization###')
    # Reviewed arrest-initialization build labels only.
    source=source.replace('-- NCPD Patrol v0.17e2 arrest initialization | prepare private bindings before helper attachment','-- NCPD Patrol v0.17e1 H10 location fix | excludes indoor H10 Atrium from generated dispatch')
    source=source.replace('v0.17e2 arrest initialization loaded. Private animation bindings are prepared before helper attachment. Includes the H10 dispatch exclusion. Install the complete package and fully restart the game.','v0.17e1 H10 location fix loaded. Indoor H10 Atrium excluded from VIP pickup/delivery and cyberpsycho dispatch. Install the complete package and restart.')
    source=source.replace('NCPD Patrol - v0.17e2 arrest initialization###','NCPD Patrol - v0.17e1 H10 location fix###')
    # Reviewed H10 hotfix build labels.
    source=source.replace('-- NCPD Patrol v0.17e1 H10 location fix | excludes indoor H10 Atrium from generated dispatch','-- NCPD Patrol v0.17e patrol improvements | catalogue/diagnostics, career duty entry and road-checked backup')
    source=source.replace('v0.17e1 H10 location fix loaded. Indoor H10 Atrium excluded from VIP pickup/delivery and cyberpsycho dispatch. Install the complete package and restart.','v0.17e patrol improvements loaded. Marker catalogue/diagnostics refactored; Start Shift in NCPD Career; backup uses checked off-camera road approaches. Install the complete package and restart.')
    source=source.replace('NCPD Patrol - v0.17e1 H10 location fix###','NCPD Patrol - v0.17e patrol improvements###')
    source=without_location_exclusion(source)
    # Reviewed v0.17e build labels only; session behavior is still compared.
    source=source.replace('-- NCPD Patrol v0.17e patrol improvements | catalogue/diagnostics, career duty entry and road-checked backup','-- NCPD Patrol v0.17d fixed quest markers r5c | finite journal marker bank')
    source=source.replace('v0.17e patrol improvements loaded. Marker catalogue/diagnostics refactored; Start Shift in NCPD Career; backup uses checked off-camera road approaches. Install the complete package and restart.','v0.17d fixed quest markers r5c loaded. Scanner, VIP and cyberpsycho activate fixed journal pins. Unmapped sites use independent quest-style markers. Install the complete package and restart.')
    source=source.replace('NCPD Patrol - v0.17e patrol improvements###','NCPD Patrol - v0.17d fixed quest markers r5c###')
    source=re.sub(r"fixed quest markers r5[abc]", "fixed quest markers r5", source)
    # Exact navigation adapters only. Bank-present behavior has its own suite;
    # historical oracles exercise the unavailable-bank compatibility boundary.
    source=re.sub(r'^.* -- r5 marker hook[^\n]*\n','',source,flags=re.M)
    source=re.sub(r'^        -- r5 marker UI begin\n.*?^        -- r5 marker UI end\n','',source,flags=re.M|re.S)
    source=source.replace('Navigation.place(patrol, chosen.position, "scanner")','patrol:PlaceDispatchWaypoint(chosen.position)')
    source=source.replace('Navigation.place(patrol,origin,"cyberpsycho")','patrol:PlaceDispatchWaypoint(origin)')
    source=source.replace('Navigation.place(patrol,point,"vip")','patrol:PlaceDispatchWaypoint(point)')
    source=source.replace('Navigation.place(patrol,waypointPoint,"vip")','patrol:PlaceDispatchWaypoint(waypointPoint)')
    source=source.replace('function M.navigationState() return Navigation.describe(active and active.waypoint, navigation) end','function M.navigationState() return navigation end')
    source=source.replace('-- NCPD Patrol v0.17d fixed quest markers r5 | finite journal marker bank','-- NCPD Patrol v0.17d quest marker test r4e | isolated opt-in experiment')
    source=source.replace('v0.17d fixed quest markers r5 loaded. Scanner, VIP and cyberpsycho activate fixed journal pins. Unmapped sites use independent quest-style markers. Install the complete package and restart.','v0.17d quest marker test r4e loaded. Opt-in fixed-position quest marker under CET Testing. Normal dispatch retains its existing waypoint. Install the complete package and restart.')
    source=source.replace('NCPD Patrol - v0.17d fixed quest markers r5###','NCPD Patrol - v0.17d quest marker test r4e###')
    source=re.sub(r'quest marker test r4[abcde]', 'quest marker test r4', source)
    source=re.sub(r'^.* -- r4 probe hook[^\n]*\n','',source,flags=re.M)
    source=re.sub(r'^        -- r4 probe UI begin\n.*?^        -- r4 probe UI end\n','',source,flags=re.M|re.S)
    return source.replace('-- NCPD Patrol v0.17d quest marker test r4 | isolated opt-in experiment',
                          '-- NCPD Patrol v0.17d VIP refactor r3 | extracted locations and waypoint ownership').replace(
        'v0.17d quest marker test r4 loaded. Opt-in fixed-position quest marker under CET Testing. Normal dispatch retains its existing waypoint. Install the complete package and restart.',
        'v0.17d VIP refactor r3 loaded. VIP locations and waypoint ownership are separate modules. Transport, ambush, rewards and the CET menu retain their existing behavior. Install the complete package and restart.').replace(
        'NCPD Patrol - v0.17d quest marker test r4###','NCPD Patrol - v0.17d VIP refactor r3###')

PROBE_BUTTONS={'Log active dispatch marker diagnostics','Log legacy Coyote test diagnostics','TEST: Start static quest marker','TEST: Relocate native marker near V','TEST: Andrea visual marker','Remove quest marker test'}
PROBE_BUTTONS.update({'TEST: Survey all 17 sites (compact)','TEST: Survey all 17 sites (standard)','TEST: Retry unverified survey sites','Stop survey and return','Recover survey cleanup and return','Load saved survey results','Export scene survey report','Log scene survey diagnostics'})
PROBE_BUTTONS.add('TEST: Injured settling pilot (3 sites)')
PROBE_BUTTONS.update({'TEST: Request Officer Down','TEST: Rotate Officer Down scene 90 degrees','Revive scene officer (nearby)','Clear Officer Down scene','Log Officer Down diagnostics','TEST: Waypoint to Officer Down intersection'})
