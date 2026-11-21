# Injured usability replaces spawn precision

The user reported `Injured placement did not hold after staging` at Kryss_04,
heading 270.643, and clarified the acceptance criterion: an officer landing a
little to either side is fine; ground clipping, inaccessible geometry or a
nonfunctional injured officer matters. Accordingly this changes the **normal
17-site UI actions**, not another opt-in three-site precision pilot.

## Run

Install all **107 files**, fully restart, keep the existing evidence and use a
manual test save, OFF DUTY and on foot. In **CET → Testing → Scene survey**, use
**TEST: Survey all 17 sites (compact)**. Close CET and leave V still. Standard
and retry actions also use functional validation. Export the same JSON/JSONL
afterward. Only City Center (Central) and Watson are covered by these sites.

## Acceptance

Original layout preflight, actual ten-actor creation, record/ID/attachment,
source-specific protection and cleanup remain. Initial attachment still verifies
the entity was actually created at the requested road level, before applying
the private down effect. The injured officer may then land naturally anywhere
inside the broad **25 m incident area**, measured from the recorded scene center.
Displacement from its intended spawn is evidence, not a rejection condition.
There are no injured corrective teleports, spawn-offset compensation, expected-
position rebasing or fixed 0.15 m root-stability anchor in this profile.

After four active seconds for the initial transition, require:

- finite supported ground beneath the **actual** injured position, a usable
  ground normal, no clearly below-floor root and no unsupported/floating root;
- local Static/Vehicle body-clearance proxies;
- an alive, attached, owned/protected private injured officer with its expected
  down status and AI component;
- a standing position within the actual mission's **2.5 m aid range**, with
  local supported ground and standing clearance;
- a clear line from that aid position to the officer, with no intervening wall
  or Vehicle corridor blockage;
- a **complete navigation path for V**, from the current scene center to the
  aid position. Nearby but disconnected navmesh is insufficient. Both path
  endpoints and all path coordinates are checked.

Probe up to eight nearby aid positions. Once one is usable, it must remain in
range, clear, connected and backed by the correct injured state for **three
active seconds**. Small root motion is allowed while those conditions hold.
Losing the aid position resets the window; a replacement must establish a fresh
window. Functional observation is bounded to 12 active seconds before retrying
another orientation. Menus/unready worlds pause the active clock and queries.
The other nine actors retain the original 1.5 m placement checks.

The native aid check mirrors necessary actor/state/range prerequisites; it does
not register a live quest, run a revive, award money or claim that F interaction
rendering/recovery was tested. Static rays, overlaps and navigation are local
proxies, not a proof that every animated limb is free of rendered geometry.

## Evidence and compatibility

New events use **`injured-functional-v1`**. Motion records retain intended/actual
XYZ and displacement, adding actual support, usable aid position, scene distance,
readiness and any real functional failure. A validated result saves the observed
injured position and confirmed aid position, with `revive_executed=false`.
The observed landing is not used as a compensating spawn offset on future runs.

Primary `latest`/`proven` exported rows select functional results after a normal
tour (and on fresh-session export). `primary_validation_profile` identifies
that selection. `legacy_latest`/`legacy_proven`, earlier pilot fields and
`injured_functional_latest`/`injured_functional_proven` retain separate evidence.
Original JSONL is append-only; older results remain heading hints and cannot
skip a new functional test. The explicit legacy internal `start` entry and both
historical pilot controls remain for regression/comparison; the three normal
full-tour/retry UI actions call `startFunctional`.

## Implementation and validation

The new observer is `scene_survey_functional.lua`. The native survey owner adds
read-only readiness/path checks; live Officer Down and its aid/rewards are not
changed. Navigation API signatures come from the pinned game reference's
`cyberpunk/ai/aiNavigationSystem.swift`, including `CalculatePathForCharacter`
and `NavigationPath.path`. Source/API contracts are developer test files only.

Portable engine mocks exercise all 17 real scene entries with safe 4 m landing
offsets in varying directions, plus 0.7 m motion while an aid position remains
usable. They reject ground/Static/Vehicle obstruction, walls, blocked standing
positions, disconnected navmesh, partial paths, missing down-state, death,
detachment and escaped actors. Timer reset, strict non-injured movement,
menu/world pause, API/disk errors, cancellation, CET recovery, old-native refusal,
profile isolation and normal UI routing are checked. Earlier explicit legacy
tour/precision-pilot regressions remain.

All seven archives, other 40 native scripts, geometry/catalogue, live missions,
arrest, partner, backup and marker code are byte-identical to v0.18b2. An actual
game run must still confirm animation rendering, engine navigation access and
in-game revive behavior; portable tests do not establish those outcomes.
