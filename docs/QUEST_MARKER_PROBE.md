R4d: MIT reference comparison for native quest markers

The r4c game log proves graph ready=4/stage=1 and an active quest/objective,
but native pins=0, no objective link and no pin ID. Journal activation worked;
marker creation did not. The cause is not established by that log alone.
Normal dispatch navigation, currency and progression are unchanged.

Reference and attribution

[Cyberpunk.Codes](https://github.com/andreaolivato/cyberpunk-codes/tree/a256760bafb625676d13b02ccf49c52b60f41d40)
is MIT licensed, copyright (c) 2026 Andrea Olivato. THIRD_PARTY_NOTICES.txt ships
the full license, source paths and adaptation notes. reference-source.json
records provenance. No original story/quest or dependency on that mod is added.

Negative Balance's pin_epilogue supplies the concrete reference:
- EntityRef #coyote_performance_test, original relative offset and UI_Interaction slot;
- QuestStaticMappinDefinition, QuestGiverVariant, active=1 and GPS enabled;
- questJournalNodeDefinition + questJournalEntry_NodeType activate the map pin;
- fileEntryIndex=1, as in that phase, rather than the earlier generic index=2;
- questJournalQuestEntry_NodeType tracks/notifies the root on activation.
The expected world point (-1259.598, -989.166, 12.037) comes from
CCGig01Places.Coyote() in Gig01_Encounter.reds, at El Coyote Cojo, Heywood.
These changes are a reference comparison, not proven individual causes of the
r4c failure. Arbitrary runtime/procedural journal positioning remains unproven.

Implementation and proof

New root: quests/street_stories/ncpd_patrol_marker_reference.
Facts: ncpd_patrol_marker_reference_r4d_ ready/stage/request.
The 22-node/21-edge phase starts passive. request=1 activates root, phase,
objective and pin via Journal nodes; ready=5/stage=1 acknowledges the route.
request=0 deactivates them, sets stage=0 and loops back. No ExecuteNode or
dynamic entity is used. Native confirmed=true still requires one actual
QuestMappin with our hash, position within two meters, objective link and stage=1.
Color, marker definition and an active objective alone are insufficient.

The independent visual control adapts Andrea's CCSharedMappins Show/Move/Hide.
It registers a quest-style marker at the same point with private scriptData,
QuestGiverVariant and active=true. visual confirmed checks ownership, position
and variant; native confirmed remains false. It proves neither journal binding
nor GPS. NCPDPatrolReferenceMappinData differs from dispatch-owned data so normal
dispatch cleanup cannot claim it. Move/Hide check current ownership, including
a reused ID. Neither test calls TrackMappin or replaces the manual waypoint.

Cleanup and loading

Old r4c resources remain packed unchanged and its phase remains registered.
Loading sets its request to zero, waits for inactive root/stage=0, then removes
only retained old private-hash QuestMappins. Legacy cleanup blocks a new test.
New native cleanup likewise waits for phase acknowledgement before hash-scoped
fallback removal. Visual cleanup rediscovers current-world private scriptData;
saved IDs are forgotten. Failed deletion blocks restart. Newer user story
tracking is respected. Menus pause lifetime; duty/combat/wanted or ten active
minutes end the test. Reward, incident and story facts stay outside this code.

Installation and game checks

Install the complete ZIP into the game root, including archive/.xl and both
ReferenceMappins/ReferenceMappinData scripts. Fully restart; do not CET-reload.
Probe interface=5 rejects mixed files. Browser Extension remains optional.
Use a test save for these engine-owned phases/facts.

1. Stay OFF DUTY, outside combat/wanted status and game menus.
2. Set a manual waypoint. CET > Testing > Quest marker experiment.
3. Start static quest marker; wait five seconds. Inspect the WORLD MAP near
   El Coyote Cojo alongside your waypoint. Log quest marker test diagnostics.
4. Remove and wait for cleanup. Run TEST: Andrea visual marker separately;
   inspect/log/remove that control too.
5. Reference graph ready=5/stage=1 shows the route ran. Only confirmed=true
   with native pins=1, objective link=true and position OK=true proves linkage.
   ready=0 calls for ArchiveXL resource/phase logs. If stage=1 but pins=0,
   check ArchiveXL cooked-pin messages using the private journal hash.
6. visual confirmed=true is renderer evidence only; native confirmed must
   remain false. Report both tests and the manual before/after IDs.

Rollback: remove the test and wait for cleanup, then restart with the earlier
complete package. The report lists added files. Never remove another mod's
files or patch vanilla sectors. A pre-test save avoids retaining test phases.

Validation

WolvenKit 9.1.1 converts, round-trips and extracts all seven resources, retaining
the old four resource bytes. Tests execute actual authored graph data and
translated native/Lua controllers; engine boundaries are mocked. No-pin behavior
is the default. Tests cover independent native hash/type/position/link/duplicate
gates, asynchronous/failed cleanup, foreign markers, reused IDs, legacy saved
tests, renderer-only false-success rejection, menus/load/duty/timeout, rearming
and four CET routes. Existing dispatch/VIP/CET comparisons preserve gameplay.
All 31 scripts pass offline source/API compilation with BEF present and absent.
Actual game-cache compilation, ArchiveXL execution, map presentation, GPS and
save behavior still require the above in-game checks.
