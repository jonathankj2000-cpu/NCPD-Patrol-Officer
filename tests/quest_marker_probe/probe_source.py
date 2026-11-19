"""Remove only the explicitly reviewed r4 opt-in hooks for earlier oracles."""
import re

def without_probe(source):
    source=re.sub(r'quest marker test r4[abcd]', 'quest marker test r4', source)
    source=re.sub(r'^.* -- r4 probe hook[^\n]*\n','',source,flags=re.M)
    source=re.sub(r'^        -- r4 probe UI begin\n.*?^        -- r4 probe UI end\n','',source,flags=re.M|re.S)
    return source.replace('-- NCPD Patrol v0.17d quest marker test r4 | isolated opt-in experiment',
                          '-- NCPD Patrol v0.17d VIP refactor r3 | extracted locations and waypoint ownership').replace(
        'v0.17d quest marker test r4 loaded. Opt-in fixed-position quest marker under CET Testing. Normal dispatch retains its existing waypoint. Install the complete package and restart.',
        'v0.17d VIP refactor r3 loaded. VIP locations and waypoint ownership are separate modules. Transport, ambush, rewards and the CET menu retain their existing behavior. Install the complete package and restart.').replace(
        'NCPD Patrol - v0.17d quest marker test r4###','NCPD Patrol - v0.17d VIP refactor r3###')

PROBE_BUTTONS={'TEST: Start static quest marker','TEST: Andrea visual marker','Remove quest marker test',
               'Log quest marker test diagnostics'}
