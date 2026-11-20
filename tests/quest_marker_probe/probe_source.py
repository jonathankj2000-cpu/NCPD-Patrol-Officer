"""Remove only the explicitly reviewed r4 opt-in hooks for earlier oracles."""
import re

def without_probe(source):
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
