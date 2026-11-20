R4e: runtime relocation of the in-game-confirmed r4d quest marker

User evidence: assets/quest_marker_probe/r4d-game-evidence.json. The supplied
r4d log proves one native QuestMappin, correct fixed Coyote position, objective
link and unchanged manual waypoint. It does not establish relocation or GPS.
The archived resources/.xl, original phase and private fact namespace remain
byte-identical to r4d. Native interface advances to 6; graph ready stays 5.

The new opt-in control relocates the existing confirmed native marker 150 m
east of V's position at the button press. The point is not ground/navmesh
validated: no actor or mission is spawned. Existing dispatch is not converted.

Before writing, the controller rediscovers the current private pin and validates
its unique hash/type, active phase, position and objective link. It checks the
live ID again and issues one SetMappinPosition call. There is no forcing loop,
fallback renderer, replacement marker or manual-waypoint write. Move requests
are rejected for an idle/visual test, incomplete proof, combat/duty/wanted,
menus, wrong identity or a target within 25 m of the current target.

Readback compares:
- IMappin.GetWorldPosition(), for the actual live marker;
- GetQuestMappinPosition(privateHash, out Vector3), also used by the game's
  questLogDetailsPanel.swift Show on Map action;
- objective link and the same original native pin ID;
- manual tracked ID sampled immediately before/after the single write.

SetMappinPosition is declared in game orphans.swift:17804.
GetQuestMappinPosition is declared at :17846 and called by
cyberpunk/UI/fullscreen/quest_log/questLogDetailsPanel.swift:263.
Offline contracts declare the latter but are never installed.

Basic native confirmed retains its pin/hash/current-target/link meaning.
relocation confirmed requires all of the above readbacks within two meters,
plus three observed active seconds of stability and unchanged manual ID across
the move. Menus pause observation. Any failed sample resets stability; a
snap-back revokes confirmation without reapplying the position. Stop clears confirmation; load forgets move requests/IDs. A new start resets
the move state and restores the static control target.
A newer user-selected story or manual waypoint between operations is respected.

Test: OFF DUTY, set a manual waypoint, Start static quest marker, wait for
confirmation, then TEST: Relocate native marker near V. Wait five UNPAUSED
gameplay seconds before checking the world map and quest-log Show on Map.
Log diagnostics, including runtime/quest coordinates, quest position OK,
relocation confirmed, stable seconds, moved pin ID and manual before/after move.
Remove afterward. Repeat elsewhere only after a stable result or after
remove/start. Native confirmation without relocation confirmation is partial.

Portable tests default to IGNORING native position writes; a void return must
not imply success. Explicit positive fixtures separately enable runtime and
quest-registry updates. Cases cover renderer-only movement, delayed/unknown
quest positions, snap-back, stability windows, menus, missing/type/duplicate/
reused pins, stale cached IDs, changed manual ID, user selections, save/stop/
rearm and the real Lua/CET route. Actual native relocation, map rendering and
GPS still need in-game testing. No further gameplay integration is assumed.

R4d reference control and attribution details follow.

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
