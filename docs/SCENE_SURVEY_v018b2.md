# Controlled injured placement pilot

The user reports that **all three v0.18b1 passive settling sites still failed**
with injured displacement. No new trajectory files accompanied that report.
It establishes that waiting was insufficient in that test, not which collision,
animation clip, physics mode or final displacement caused it. A fixed directional
spawn compensation would not address collision-dependent landings.

The source also establishes a relevant difference: live Officer Down calls
`Actors.lock` while staged before arrival; the survey intentionally observed
actors without that correction. This build adds an explicit test of that
production-style placement, with the corrections disabled before validation.
It does not change the actual mission or claim direct lying-pose spawning.

## Run the new test

Install the **complete 106-file v0.18b2 package** and fully restart. Use a manual
test save, **OFF DUTY and on foot**, with earlier patrol/backup actors cleared.
In **CET → Testing → Scene survey**, use exactly:

**TEST: Injured placement pilot (3 sites)**

Close CET and leave V still. The queue is **Kryss_04, Kryss_11, Kryss_15**. Keep
the existing JSONL; export afterwards and share `scene_survey_report.json` and
`scene_survey_results.jsonl` from the NCPDPatrol CET folder. The passive settling
button and the legacy all-17 buttons remain available as separate protocols.

## Procedure

1. Retain the original preflight, ten-actor creation, identity, attachment and
   source-specific protection. Record injured motion through spawning.
2. After all ten actors attach, stage for **four active seconds**. Only the
   injured actor may be corrected to its original requested position, with the
   production threshold: horizontal drift over 0.5 m or vertical drift over 1 m.
   Keep the existing temporary 3 m horizontal / 1.5 m vertical safety envelope,
   life/identity checks and through-floor rejection. Other actors keep 1.5 m.
3. Before each correction, require finite supported target ground, normal Z at
   least 0.85, root-height bounds and local Static/Vehicle clearance. The same
   `TeleportationFacility.Teleport` API as live Officer Down requests placement;
   a successful request is never accepted as actual movement proof.
4. Close the native correction gate and wait **0.5 active seconds without
   corrections**. Then apply the original **1.5 m final distance limit**, the
   injured support/clearance checks and **three active seconds** of observation
   with no corrections. Every actor must stay within **0.15 m** of its fixed
   observation-start anchor as well as within the original distance bound.
5. Require confirmed physical cleanup before a validated result or next move.

The native gate requires an explicitly begun placement run, the same live
player/world, an owned/protected/tracked injured officer and a target near its
original spawn anchor. It rejects ambient actors, the other nine actors, unsafe
motion/yaw and calls after correction release. Ordinary survey runs cannot
correct actors. EndActors and reset close the gate; original cancellation,
world/menu pauses, cleanup ownership and CET-reload recovery remain in use.

## Evidence and limits

Events use `validation_profile = injured-staging-pilot-v1`. They include all
passive motion samples plus `corrections_enabled`, `correction_requested`,
`correction_target`, target support and correction count. Separate
`placement_corrections_stopped` and `placement_released` events show when
correction stops. Observed coordinates are always read from the engine; the
expected position is never reset to the landing point. Site results include
the correction count and uncorrected release duration.

Exported site rows have separate `injured_placement_pilot_latest` / `proven`
fields alongside passive-pilot and legacy results. Older evidence/headings are
preserved. Neither pilot changes the default tour retry filter or turns a failed
site into a validated dispatch location. Injured placement that does not hold
after staging reports an explicit unverified placement failure.

These checks concern entity roots and conservative local clearance proxies.
They do not prove full skeleton collision safety, animation completion or revive
behavior. If native teleport does not move the actual downed actor, or it keeps
moving after release, this test must still fail. Do not infer a guaranteed fix
from portable tests that mock engine motion.

## Verification and scope

Tests execute the actual Lua FSM and translated native owner. A 1.8 m offset in
varying directions fails passive waiting and is corrected in the new pilot.
Ignored teleports, continuous drift after release, 0.2 m final drift, unsafe
target ground/clearance and another actor moving remain rejected. Tests cover
native ownership/phase guards, old-native version refusal, menu/world pause,
cancel/disk/CET-reload cleanup and three-profile evidence isolation. The existing
default full-tour trace comparison remains identical to v0.18b.

Only `NCPDPatrolSceneSurveySystem.reds` changes among native scripts. All other
40 native scripts, seven archives, live Officer Down controller/geometry, arrest,
partner, backup, markers and the 17-site catalogue remain byte-identical to
v0.18b1. Source/API compilation is checked with Browser Extension present and
absent using source-derived contracts; this is not an actual game-cache build.
