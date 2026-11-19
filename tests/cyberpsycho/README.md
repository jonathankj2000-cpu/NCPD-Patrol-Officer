# Cyberpsycho encounter checks

Run with Python 3 and lupa:

    python tests/cyberpsycho/check_cyberpsycho.py

The actual authored native controller executes through the shared syntax
adapter. Tests cover response-before-spawn, the 500-2000 m native range gate,
180-second deadline/pause/arrival boundary, bounded preparation, response-to-
neutralize objective transition, tracking preservation at arrival, and exact
private-record/target admission, death and both
non-lethal states, stable confirmation, unrelated deaths, target disappearance,
menus/time deltas, distance abandonment, duty/wanted/death, journal write failures,
tracking preservation, stale tokens and simulated save/load reconciliation.

The real CET encounter module and dispatcher execute with native creation,
navigation, actor, AI, journal and widget boundaries mocked. Scenarios cover
500-1000/1500/2000 m destination tiers, fast-travel/NCART/inactive/invalid marker
filtering, unfinished-scanner exclusion, requests from a vehicle and zero entity/
navigation calls before arrival. Arrival alone triggers scene-local navigation
and deferred creation; failed placement never falls back near V. Further cases:
spawn/AI delay, invalid points/paths, refused requests, pre-spawn resource checks,
identity verification before hostility, setup rollback, one entity reservation,
rejected/deferred deletion, world reset without stale deletes, ordinary dispatch
mutual exclusion and cancel/replace/shift-end routing. Existing payments must
remain untouched. The source asset topology and TweakXL clone are also checked.

The generated archive receives separate WolvenKit compilation, round-trip and
exact extracted-resource checks in the release builder. All 23 production
redscript files pass source-derived API checks with and without optional BEF.
Neither these checks nor native mocks validate live combat, navmesh placement,
the final rendered journal or true game serialization. Those need a game test.

## v0.15a variant coverage

`assets/cyberpsycho/variants.json` contains the 17 distinct base-game Sighting
source IDs, parent records, source paths/blob SHAs and pinned reference commit.
The two additional Bloody Ritual phase/elite records are not counted as unique
targets. Adam Smasher is a separate story boss and is not included. These IDs
were read from the CDPR-Modding-Documentation/Cyberpunk-Tweaks character records;
Coastview's netrunner is in `quest/combat_events/coastview.tweak`, while the other
16 are in the district `quest/minor_activities` records.

`tools/build_cyberpsycho_catalog.py` generates the private TweakXL clones, CET
catalog and exact native admission gate from that manifest. The test checks all
outputs against the manifest, both exo records and provenance fields. Every clone
is tested with death, defeat and unconsciousness; wrong variant/original records
and identity changes during a running assignment are refused. Actual CET deferred
spawning is exercised for every forced choice. Random/no-adjacent-repeat,
missing original/private records, a singleton pool and an empty pool are covered,
as are the shipped cycle/random buttons. Native CP API is 3; legacy BeginDispatch
continues to use the original private HMG clone, while BeginVariant fixes the
selected private record when the journey begins.

Private clones override quest affiliation/priority, savability, hostile attitude,
unaffiliated faction, aggressive reaction, generic name and loot. They retain
inherited entity/equipment/stats/abilities; no original records or facts change.
This removes the Bloody Ritual no-reaction intro and avoids treating a hostile
private copy as a police ally by its original affiliation. Engine-only exo/boss
initialization, navigation clearance, appearance and combat skills still need a
live test. All existing journal/target ownership/cleanup checks remain in place.
# v0.17a generated dispatch rewards

This suite now loads the authored generated incident ledger and verifies a
confirmed non-lethal target earns EUR$3500 and one cyberpsycho completion.
Existing variant, arrival, cleanup and failure cases still execute the real
controller. Dedicated `tests/incidents/check_incidents.py` cases cover lethal
EUR$3000 outcomes, non-lethal classification timing, stale/cancel/load guards,
failed payments, delayed receipts and 50/30/20 dispatch fallback.
