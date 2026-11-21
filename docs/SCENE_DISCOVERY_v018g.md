# v0.18g: Officer Down Scene Discovery

This is an explicit off-duty developer tool. It uses the existing 60 VIP terminal
coordinates as anchors to search nearby open ground. It does not change live
dispatch, the 16 approved City Center/Watson sites, the original 17-site survey,
quest markers, rewards, actors or progression.

## Start with the short test

1. Install the complete ZIP and fully restart Cyberpunk 2077; the matching native
   scene discovery API is required.
2. Load a manual test save, end your shift, exit your vehicle and leave combat.
   Finish/clear existing patrol actors and retained dispatch scenes first.
3. Open CET > Testing > **Scene discovery: terminal offsets**.
4. Select **TEST: Discover scenes near 3 closest terminals**, then close CET.
   This tests up to six terminal/layout pairs and returns V to the start.
5. Inspect/export **scene_discovery_report.json** in the NCPDPatrol CET folder.
   Keep **scene_discovery_results.jsonl** alongside it.
6. If the short test behaves correctly, use **TEST: Discover scenes near all 60
   terminals**. It skips terminal/layout pairs with compatible saved successes.
   The complete search can take substantially longer than the original survey.

The nearest-three choice is relative to V when starting. Repeating it somewhere
else selects another local group. Compact and standard are tested independently.
An anchor that already has both verified variants needs no additional trial.

## Search procedure

The baked anchors are a selected subset of the existing fixed-marker catalogue,
not a newly scraped street network. Coverage is City Center (6), Heywood (10),
Pacifica (3), Santo Domingo (15), Watson (16) and Westbrook (10). Indoor H10 Atrium
remains excluded. No Street Location System or TroubleSpots dependency is added.
Existing factual coordinate attribution remains in THIRD_PARTY_NOTICES.txt.
`tools/build_scene_discovery_catalog.py --check` verifies the generated module.

At each anchor, after the existing protected transfer and streamed landing:

- Search at 10, 20 and 30 metres in eight 45-degree bearings.
- Try headings 0/90/180/270 first, then 45/135/225/315, for each offset.
- Use at most two passes: 384 geometric poses per terminal/layout.
- Process one geometric pose per active update, no more often than 0.1 seconds.
  Menus/world streaming and long frames pause the test.
- Check local Static ground and slope, small navmesh/grounding offsets, elevation,
  standing clearance, all three vehicle footprints and all seven NPC positions
  with the unchanged `officer_down_layout.lua` validation.
- Reject broad grounding snaps, other floors and nearby duplicate sites. Existing
  compact sites use a 5 m same-level dedup radius; discoveries from another anchor
  use 10 m for the same layout. Different levels are not deduplicated together.
- Only after complete geometric fit, move to the supported shifted center, confirm
  landing and recheck the full layout before spawning any actor.
- Run the existing ten-actor functional survey. The injured officer may move within
  the incident area; actual support/clearance/down-state and a reachable aid spot
  must remain usable for three seconds. Other actors retain survey validation.
- Physically clean the scene before accepting success or trying another pose.

Geometry-only failures create no actors. A valid navmesh center is not proof of a
complete scene. The first fully successful pose is retained for each anchor/layout;
the tool does not attempt to catalogue every open patch around a terminal.
A failed functional trial returns to the protected anchor before continuing the
bounded offset search. An API error remains an error, not a geometric rejection.

## Evidence and continuity

New files are isolated from `scene_survey_results.jsonl` and
`scene_survey_report.json`:

- `scene_discovery_results.jsonl`: append-only events, rejected geometry,
  per-heading failures, functional samples and cleanup-confirmed successes.
- `scene_discovery_report.json`: exported at the end or through **Export discovery
  report**. `verified_candidates` contains actual grounded XYZ, heading, layout,
  nominal offset, source terminal coordinates/ID/district, all ten samples and
  the functional proof. The header counts verified candidates, not dispatches.

Failed or interrupted trials never grant verification. Matching catalog/layout
revisions and complete functional proof are required when loading old evidence.
Truncated/stale lines are ignored without discarding earlier compatible results.
Previously successful candidates are retained; temporary later blockage does not
erase them. A compatible success allows that terminal/layout pair to be skipped.
The report is derived from the ledger; keep the JSONL for continuation and analysis.
No discovered location is imported automatically into production dispatch. A later
review can select usable candidates and bake their actual positions/rotations into
the established catalogue, with the same marker and gameplay integration process.

## Cancellation, reload and physical cleanup

**Stop discovery and return** uses the existing ownership/drain process. The
native owner also queries each exact current-run ID in the actual world before
releasing discovery actors. A manager-free but still attached actor continues to
block teleportation, including after Lua drain handles were lost during CET reload.
It never looks up ambient actors by proximity or reuses saved IDs across worlds.

After CET reload, **Recover discovery cleanup and return** selects the separate
discovery ledger using a transient native mode tag. It cleans only current-session
native-recorded IDs, then returns V. If physical cleanup or the return landing is
blocked, the reservation remains instead of silently authorizing a new tour.
A save/game reload drops transient ownership and does not automatically resume.
Use a manual test save and avoid saving in the middle of a developer tour.

Transfers reuse the existing protected teleport and landing checks. This build
does not claim to add a loading screen, purge memory or discover unloaded terrain
without moving V. It never starts a quest, pays money or adds career credit.

## Validation limits

The release runs 29 portable suites, including the actual discovery iterator,
unchanged layout, shared actor lifecycle and translated native survey owner against
mocked engine boundaries. Tests cover both layouts across all 60 source anchors
(120 complete scenes), zero-spawn geometric rejection, diagonal headings, grounded
Z export, wrong-level rejection, aid-route failures, namespace preservation,
truncated/stale ledgers, all six new CET routes, cancellation/CET recovery, disk/API
failures and menu/session guards. Existing survey trace/profile checks remain.

All 44 REDscript files pass offline source/API checks with Browser Extension both
present and absent. The previously observed unavailable `VehicleObject.Dispose`
compile failure remains a negative control. This is not an actual game-cache
compile or evidence that a physical Night City location is approved.

Real terrain streaming, collision queries, traffic and root motion still need the
short in-game pilot. A geometry/functional pass does not test actual combat, enemy
behavior or pressing F to revive the officer. Those need gameplay checks before a
new site is added to production dispatch.
