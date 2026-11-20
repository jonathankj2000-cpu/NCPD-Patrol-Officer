NCPD PATROL v0.18a OFFICER DOWN - COMPLETE BRANCH TEST

Manual-only rescue prototype at TEST_KRYSS_01:
X=-490.911377, Y=-173.816315, Z=7.887070.
One police car, one injured officer, one defending officer, two gang cars and
five gang members. BOTH the revive and suspect neutralization are required.
Completion pays EUR$2000 and records one generated career incident.

Install all 99 files and fully restart the game. Go on duty, travel 100-5000 m
from the intersection, then use CET -> Testing -> Officer Down prototype ->
TEST: Request Officer Down. The quest has a fixed native marker and keeps your
manual waypoint. This prototype is not part of the automatic 50/30/20 mix.

The scene prepares within 180 m. All ten entities are protected and held until
arrival within 55 m. Staging protection/position locks are then released;
the injured officer stays protected until revival. Approach on foot and use F
or the nearby CET revive fallback. Remain within 2.5 m for 3 seconds. Recovery
must actually finish with full health before rescue counts.

The supplied coordinate does not specify street direction. Use Clear Officer
Down scene, then TEST: Rotate Officer Down scene 90 degrees and request again
if placement is unsuitable. Ground, clearance and navmesh checks can refuse a
layout. Physical road alignment, combat and animations still need game testing.

Cancel active dispatch and end shift clean up the scene. Successful scenes may
remain for 90 seconds or until you leave 150 m; this does not reserve the next
dispatch. Clear Officer Down scene permits a quick repeat at this one test site.
Log Officer Down diagnostics includes native quest/aid/marker state and rotation.

All existing VIP routes, native marker-bank assets, arrest/partner code and
automatic dispatch weights are retained. Browser Extension remains optional.
See docs/OFFICER_DOWN_v018a.md in the repository.

PREVIOUS BUILD NOTES

NCPD PATROL v0.17f VIP ROUTE CATALOGUE - COMPLETE BRANCH TEST

VIP transport now selects from 360 pre-generated endpoint pairs at 60 fixed
catalogue locations. Pickup, witness arrival and delivery use the exact XYZ
associated with their existing native quest-marker sites. Live fast travel or
drop-point markers no longer supply VIP endpoints; unlocked terminal counts
do not limit the route pool. Indoor H10 Atrium remains excluded.

Routes are still selected randomly near V. Active scanner incidents exclude
both endpoints within 100 m. Existing local/expanded distance bounds remain;
the last 12 selections are avoided when the local eligible pool permits it.
Diagnostics include the route ID and both native marker site IDs.

The VIP coordinator, boarding, ambush, EUR$2000 reward, career record, cleanup,
native scripts, archives, arrest and manual waypoint handling are unchanged.
No new dependency. Browser Extension remains optional.

Install all 89 files and FULLY EXIT AND RESTART THE GAME. Use CET -> Dispatch
to request a VIP transport. Check pickup visibility, drive to the witness,
confirm the marker changes only after boarding, deliver, then request another
dispatch. Repeat at different locations and with an existing manual waypoint.
If a marker fails, Log active dispatch marker diagnostics plus Log VIP diagnostics
identify the selected route/site. Test physical pickup/parking in game: data
validation cannot establish road access or actual rendering at every endpoint.
See docs/VIP_ROUTE_CATALOGUE_v017f.md in the repository.

PREVIOUS BUILD NOTES

NCPD PATROL v0.17e2 ARREST INITIALIZATION - COMPLETE BRANCH TEST

Private animation bindings are loaded, configured and read back BEFORE the
arrest helper can attach. Later resource instances/empty caches are rechecked;
pending assets create no helper. The prior code created the helper before these
bindings were copied, which may explain an active workspot with a T-pose.

The actual v0.17e code fails the new attachment-order invariant. Rendering is
still unverified: native playback acceptance does not prove the visible clip.
Native scripts, arrest archive, loop topology, health/physics and payment rules
are unchanged. Includes the H10 exclusion and all v0.17e improvements.

Install all 88 files. FULLY EXIT AND RESTART THE GAME to discard old resource
instances, then try a new living downed enemy not already credited as arrested.
The log should show private binding readback before the helper-attached line.
See docs/ARREST_BINDING_INITIALIZATION_v017e2.md in the repository.

PREVIOUS BUILD NOTES

NCPD PATROL v0.17e1 H10 LOCATION FIX - COMPLETE BRANCH TEST

Megabuilding H10: Atrium is excluded from generated dispatch locations:
VIP pickup, VIP delivery and cyberpsycho destination. The exact fast-travel ID
is blocked, with a 2 m XYZ fallback for marker wrappers lacking point data.
Street-level points beneath the building remain eligible. The world terminal,
scanner incidents, marker-bank indices, native scripts and archives are unchanged.

Includes all v0.17e improvements. Install all 88 files and fully restart.

PREVIOUS BUILD NOTES

NCPD PATROL v0.17e PATROL IMPROVEMENTS - COMPLETE BRANCH TEST

Install the entire bin/r6/archive package and fully restart the game.
87 install files; 28 Lua modules; 36 REDscript files. Existing dependencies and
keys remain. Browser Extension is optional for the mod; the career page needs it.

CHANGES
- Marker catalogue and diagnostic formatting are separate helpers. The existing
  marker controller still owns timing, native proof, fallback and cleanup.
  3161 observation rows, including diagnostic strings, match the actual r5c code.
- NCPD Career: Start Shift in the sidebar of every section. Uses the same shift
  controller as CET/fast travel. SHIFT REQUESTED gives feedback until the normal
  controller consumes the request; refresh permits retry, SHIFT ACTIVE is shown
  on duty. No direct rewards or partner spawning from the browser handler.
- Backup prefers your recent driven route and retains it while you walk to the
  trunk. It checks road support, static clearance and the active camera. With no
  route history it checks a straight approach behind your stationary position.
- The backup car must attach at the requested road level and settle before the
  two officers are created. Misplaced cars are removed before retrying elsewhere;
  three attempts maximum. Requests search for up to 20 active seconds per try.
- One-patrol reservation, fixed request destination, braking/exit, following,
  boarding, 10-4 and distance cleanup remain. World reset forgets old IDs.
- Bean Bagger review: no clear source regression found. Its archive and private
  pump/grip resources are identical to the original blue-grip release. No asset
  edits or new runtime diagnostics. Possible causes and comparisons are recorded
  in docs/BEAN_BAGGER_BLUE_PUMP_REVIEW.md in the repository.

TEST
Repeat marker completion/new dispatch and loading. Start a shift from Career.
For backup, drive to a roadside stop and request it after exiting, then try a
stationary request without recent driving. Test camera angles and bridges.
Unsafe approaches can refuse instead of spawning on uncertain ground.
The existing CET Bean Bagger test-copy control can compare a fresh gun after
restart with your existing gun; no new diagnostic control is required.

All six archives and the VIP/ambush code are unchanged. Money/progression and
scanner/VIP/cyberpsycho quest outcomes are unchanged. Portable tests and offline
source/API checks are separate from actual game rendering/driving. Long-term
marker stability and earlier reload-crash attribution remain open.
See docs/PATROL_IMPROVEMENTS_v017e.md in the repository for implementation scope.

PREVIOUS BUILD NOTES

NCPD PATROL v0.17d FIXED QUEST MARKERS r5c - COMPLETE BRANCH TEST

Fixes the r5b rejection where an active native pin had the correct hash,
objective link and positions, but the ownership census said zero. The private
catalogue is now independent of journal availability during restoration, and
selected private-entry identity participates in the census directly.

CET updates and both marker controllers wait for Codeware Session/Ready.
BeforeEnd blocks work while the old player can still exist. Session callbacks
change flags only; restored journal work is deferred and capped at 48 objectives
per update. Duplicate Ready events do not invalidate an assignment.

INSTALL AND TEST
Install the entire bin/r6/archive package and fully restart. Bank interface 4
and the new NCPDPatrolMarkerSession.reds file are required. 84 install files,
27 Lua modules and 34 native scripts. All six archives are unchanged from r5b.
Browser Extension remains optional; no additional dependency or hotkey.

Test loading, repeated scanner/VIP/cyberpsycho requests, cancel/complete and
reload. A normal native marker should persist beyond five seconds and show:
ownership entries=3112, selected in catalog=true, active bank pins=1,
native confirmed=true, fallback=false.

CET > Diagnostics > Fixed quest markers > Log active dispatch marker diagnostics
The button prints current state and a retained pre-cleanup snapshot. It now
also shows catalogue membership, expected hash, session readiness and restore
cursor. Fallback's status follows its latest registration/active observations.

18 portable suites include the directly observed r5b failure and a negative
control against the actual r5b code. Offline source/API compilation is separate
from an installed game-cache build. Actual rendering/reload stability remains
unverified. The repeated crash is NOT attributed or claimed fixed: the earlier
raw dump showed an abnormal animation allocation; a later access violation is
reported in the supplied analysis without its raw archive here.
See docs/FIXED_QUEST_MARKERS.md for evidence and scope.

PREVIOUS BUILD NOTES

NCPD PATROL v0.17d FIXED QUEST MARKERS r5b - COMPLETE BRANCH TEST

This build changes marker lifetime and recovery after r5a's disappearing pins.
Native quest instances are DEACTIVATED and retained for engine reuse. Only
our script-created fallback is unregistered. Inactive cached native pins no
longer fail the one-active-marker check. A correctly positioned active native
pin remains visible even if journal proof is missing; it is reported as
retained=true, native confirmed=false. Full native proof stays separate.

The marker bank and legacy Coyote test wait for an ATTACHED player before
mutating native state. This addresses a loading guard defect. The reported
PoolAnimBuffers/513-GiB assertion is NOT attributed or confirmed fixed by this
build; the crash report does not identify its responsible mod.

INSTALL AND TEST
Install the entire bin/r6/archive package and fully restart the game.
Native bank interface 3 is required. All six archives are identical to r5a.
First check loading, then request/cancel several scanner/VIP/cyberpsycho calls,
and reload after playing. Check the marker beyond five seconds and on stage
changes/completion. Your manual waypoint remains independent.

CET > Diagnostics > Fixed quest markers > Log active dispatch marker diagnostics

The button now prints current state AND "Fixed markers before cleanup".
The retained snapshot survives fallback; no quick five-second capture is needed.
Fallback diagnostics show its actual ID, registration, active/visible engine
flags, position and attempt count. A request is not reported as confirmed
registration. A valid native marker can remain while journal link=false.

18 portable suites, including 1556 cached native instances, same-ID reuse,
partial-proof retention, detached-player guards and two negative controls
against r5a; 27 Lua modules, 33 native scripts, 83 installed files. Offline API
compilation runs with Browser Extension present and absent. Actual marker/GPS
rendering and the reported crash still require game validation.
See docs/FIXED_QUEST_MARKERS.md for evidence, ownership and test scope.

PREVIOUS BUILD NOTES

NCPD PATROL v0.17d FIXED QUEST MARKERS r5a - COMPLETE BRANCH TEST

Fixes the r5 journal layout that exposed all terminal locations. Every selected
site now has its own objective with one map pin; all pin definitions start
inactive. Only the selected pin receives MappinManager Active. Scanner sites
use authored relative offsets from the game-confirmed Coyote world anchor.

The existing scanner/VIP/cyberpsycho owners select the site objective and retain
their attendance, deadlines, actors, results, rewards and career logic. Unknown
locations or unconfirmed native pins recover the common objective and use an
independent quest-style fallback. Your manual waypoint remains yours.

INSTALL AND TEST
Install the COMPLETE bin/r6/archive ZIP in the game root and fully restart.
All three dispatch/VIP/cyberpsycho archives and updated native scripts are
required. No CET hot reload. This version requires bank interface 2.

Start a shift, set a manual waypoint and request a scanner, VIP or cyberpsycho
using the existing controls. After five unpaused gameplay seconds use:
CET > Diagnostics > Fixed quest markers > Log active dispatch marker diagnostics

Expected native result: native confirmed=true, native pins=1,
active bank pins=1, other bank pins=0, target active=true, objective link=true,
both position checks=true, fallback=false. Confirm only the selected location
is shown and the manual waypoint is still available. If fallback=true, the
independent marker is present but native journal binding was not confirmed.

Check VIP pickup -> delivery, cyberpsycho response -> neutralize -> completion,
scanner completion and next dispatch, cancellation/replacement, end shift and
save/load. Old or unexpected PRIVATE bank pins are pruned; story/manual and
other mods' markers are outside this cleanup. Stale runtime-position evidence
is reset. Refused cleanup must finish before a replacement/fallback is created.

Testing > Legacy Coyote marker experiment is a separate older experiment.
Its static r4d marker passed in game; r4e relocation failed. R5 also failed in
game (terminal pool visible; no scanner native pin). R5a's rendering and GPS
still require an IN-GAME TEST. Automated API checks do not prove that result.

323 catalog sites; 1556 single-pin site objectives. 18 portable suites,
27 Lua modules, 33 native scripts, 83 installed files. Original actor/reward/
result methods are source-guarded; native owners gain only navigation paths
and transient site selection. Browser Extension remains optional.
See docs/FIXED_QUEST_MARKERS.md for ownership, evidence and building.

PREVIOUS BUILD NOTES

NCPD PATROL v0.17d NATIVE MARKER RELOCATION PROBE r4e - COMPLETE BRANCH TEST

R4d's fixed Coyote marker is CONFIRMED IN GAME by the user's log: one native
QuestMappin, objective link, correct position, unchanged manual waypoint ID.
This does not establish runtime relocation or GPS. The exact archived resources
and phase/fact namespace from that successful control are retained unchanged.

New CET control: TEST: Relocate native marker near V.
1. OFF DUTY, outside combat/wanted status. Set a normal manual waypoint.
2. Start static quest marker and wait for native confirmed=true at Coyote.
3. Press Relocate native marker near V. The target is 150 m east of V's position
   at the button press, with the same elevation. This is a marker test only.
4. Wait five UNPAUSED gameplay seconds before opening the world map.
5. Inspect the new location on the map and the quest-log Show on Map location.
   Log diagnostics, then Remove and wait for cleanup.

The controller discovers the live private QuestMappin again, checks its hash
and objective link, and issues SetMappinPosition ONCE. It does not spawn a new
marker, force its position every frame, or write the manual waypoint.
relocation confirmed=true additionally requires the same native pin ID,
runtime position AND GetQuestMappinPosition readback within 2 m of the target,
and 3 observed active seconds of stability. Manual before/after move must match.
The quest-position API is also used by the game's quest-log location control.

Runtime position OK with quest position OK=false exposes a partial result;
an ignored call, snap-back, missing pin or changed identity cannot pass.
Position reads are listed in diagnostics even when confirmation fails.
Basic native confirmed refers to current pin/link/target; relocation confirmed
is the stricter result. This build's relocation remains UNTESTED IN GAME.

Install the COMPLETE bin/r6/archive ZIP and fully restart; no CET hot reload.
Probe interface=6; archived graph ready=5 remains correct. Browser Extension
is optional. Five Testing controls, including the prior independent visual
control. Normal dispatch, rewards and progression retain existing behavior.
17 portable suites; 25 Lua modules, 31 native files, 79 installed files.
Offline source/API compile and tests mock engine boundaries. Use a test save.
See docs/QUEST_MARKER_PROBE.md and the verification report for scope/evidence.

PREVIOUS BUILD NOTES

NCPD PATROL v0.17d MIT REFERENCE MARKER PROBE r4d - COMPLETE BRANCH TEST

The r4c game log showed an active quest/objective and graph stage=1, but ZERO
native quest pins. This build compares the concrete Negative Balance setup by
Andrea Olivato, used under MIT. See THIRD_PARTY_NOTICES.txt for full attribution.

Reference test: a private journal quest uses the same fixed world NodeRef as
Negative Balance's El Coyote Cojo pin, QuestGiverVariant, an initially active
pin definition and questJournalNodeDefinition activation. Its private root
phase starts passive. The original quest/story is not included or required.
Expected point: X -1259.598, Y -989.166, Z 12.037. This does not follow V.

Install the COMPLETE bin/r6/archive package into the game root and restart.
Include NCPDPatrol_QuestMarkerProbe.archive AND .archive.xl and both new
NCPDPatrolReferenceMappins/NCPDPatrolReferenceMappinData.reds files.
Existing dependencies remain; Browser Extension is optional. Probe interface=5.
The old r4c phase/journal remain available to close a test saved while active.

OFF DUTY > CET > Testing > Quest marker experiment:
1. Set an ordinary manual waypoint. Start static quest marker.
2. Wait five seconds; inspect the WORLD MAP near El Coyote Cojo, Heywood.
3. Log quest marker test diagnostics, then Remove and wait for cleanup.
4. TEST: Andrea visual marker is a SEPARATE renderer control at the same point.
   Inspect/log/remove it too. It uses Andrea's small Show/Move/Hide helper,
   adapted with private ownership checks. It does not establish journal or GPS.

Reference graph ready=5, stage=1 means activation completed. confirmed=true
still requires one actual QuestMappin matching our private journal hash,
position and objective link. A yellow icon or active journal alone is not proof.
The visual control reports visual confirmed separately; native confirmed stays
false. Manual waypoint IDs are sampled before/after; neither test tracks them.

Normal dispatch, currency and progression retain their behavior. Real game
marker creation, presentation, GPS and saved-phase execution need testing.
17 portable suites; 25 Lua modules, 31 native files, 79 installed files.
See docs/QUEST_MARKER_PROBE.md for sources, diagnostics and rollback.

PREVIOUS BUILD NOTES

NCPD PATROL v0.17d VIP REFACTOR r3 - COMPLETE BRANCH TEST

VIP location selection and waypoint ownership have their own modules.
The existing transport still owns its quest/token, witness, actual boarding,
delivery, completion/failure and actor/scene cleanup. Ranges, random selection,
marker inspection/recovery, rewards and ambush behavior retain the r2 contracts.
The six-tab CET interface is included.

Install this COMPLETE package into the game root (bin/r6/archive) and restart.
CET announces "v0.17d VIP refactor r3". Include the new vip_locations.lua and
vip_waypoint.lua files. No dependency, native interface or save-format change.
Browser Extension remains optional. Reapply an optional Chinese preview overlay
after this full installation.

16 suites pass: 29,208 matching VIP trace rows against r2, the unchanged
17,374-row dispatch comparison and 156 CET action routes. 24 Lua modules,
28 unchanged native scripts, 72 install files. Source guards preserve the moved
policies and remaining transport/cleanup flow. Real engine boundaries are mocked.
Check pickup/delivery markers, boarding, payment, cancellation/load and the next
automatic dispatch in game. Ambush placement/chase tuning is a later round.

See docs/VIP_REFACTOR.md in the repository for ownership and in-game checks.

PREVIOUS BUILD NOTES

NCPD PATROL v0.17d CET REFACTOR r2 - COMPLETE BRANCH TEST

Six CET tabs: Patrol, Dispatch, Career, Settings, Diagnostics, Testing.
Duty/availability stay at the top; last status stays in a separate footer.
Each tab scrolls independently. Technical logs and test grants have their own
sections. Career shows rank/progress/next reward. Active test unlocks show a
warning on every tab. All 52 previous controls remain available.

Install this COMPLETE package in the game root (bin/r6/archive) and restart.
CET announces "v0.17d CET refactor r2". Include the new cet_ui.lua module.
No new dependency, native API or save-format change. Browser Extension remains
optional. Reapply an optional Chinese preview overlay after this full install.

The menu is separate from the live session. Existing shift/update/cleanup,
dispatch, partner, backup, arrests, repair, rewards and progression retain their
owners. Main and previous test packages remain available separately.

15 suites pass: 156 old/new action routes, all existing gameplay checks and
17,374 matching dispatch trace rows. 22 Lua modules, 28 unchanged native scripts,
70 install files. CET 1.37.1 APIs were checked; game rendering/input are mocked.
Please check all tabs, resizing/scrolling/status footer, normal patrol controls
and a completed VIP followed by the next automatic dispatch in game.

See docs/CET_UI_REFACTOR.md in the repository for code ownership and checks.

PREVIOUS BUILD NOTES

NCPD PATROL v0.17d DISPATCH REFACTOR r1 - BRANCH TEST

Dispatch now separates scanner assignments, scheduling and result tracking.
CET/trunk integration, 50/30/20 selection, timers, native journals, rewards,
career records, marker recovery and actor cleanup keep their existing contracts.
Read-only diagnostics distinguish assignment reservations and scene cleanup.
No new dependencies, native API changes or save migration.

Install this COMPLETE package in the game root (bin/r6/archive) and restart.
CET announces "v0.17d dispatch refactor r1". This is a test build for the
refactor branch; main and the previous v0.17d release remain available.
Reapply the optional Chinese preview overlay after installing this full ZIP.

All 13 existing test suites plus the v0.17d behavioral comparison are run.
21 Lua modules, 28 unchanged native scripts, 69 install files. Engine APIs are
mocked; actual game validation is still required. Check scanner/VIP/cyberpsycho
completion, next automatic call within 120 gameplay seconds when Available,
Busy/cancel/replacement at the trunk, saved career credits and partner/backup.
Foreground actor cleanup can still explicitly hold the next assignment.

See docs/DISPATCH_REFACTOR.md in the repository for ownership and test details.

PREVIOUS GAMEPLAY BUILD NOTES

NCPD PATROL v0.17d - VIP PARTIAL AMBUSH CLEANUP

V0.17D FIX
Completed VIP dispatch no longer waits for known ambush NPC/car IDs to despawn.
They stay owned/retried in the bounded background queue. Earlier retirement only
recognized combat-resolved crews; never-attached cars and normal partial cleanup
could hold dispatch forever despite a completed journal and removed witness.
Vehicle-only cleanup also releases cancelled/failed assignments once NPC IDs are
gone. Recheck eligibility after deletion and during updates; late units join the
same convoy scene. Keep three scenes maximum, no re-spawning from retired units,
and ordinary combat/menu/Busy pauses. A full queue permits other dispatch types.

Diagnostics now show pending vehicle/NPC/unknown counts, whether the car ever
attached, crew IDs requested and last status. A registered controller/ID does
not prove its car appeared. This fixes cleanup blocking, not unseen-car spawning.

Install the COMPLETE package and restart; CET announces v0.17d. Marker recovery,
native scripts, archives and rewards are unchanged. Thirteen suites include three
never-attached cars, partial crew deletion, pending NPC despawn, later cleanup,
automatic next dispatch and preservation of the next marker/journal. Engine
boundaries are mocked; in-game verification is still required.

V0.17C FIX
VIP checks its current waypoint ID against the game marker registry every
gameplay second. Missing pins are re-registered after a two-second grace;
inactive/displaced pins are activated/repositioned. Failed recovery retries
at most every five seconds. Healthy markers stay in place. Journal/token,
witness and rewards are not restarted. Delivery stays hidden until boarding.

VIP changes/cancellation/completion remove only its own current marker ID.
Load/reset forgets old-world IDs. Log VIP diagnostics includes marker status,
ID, coordinates and repair count. Rebuild VIP waypoint replaces the current
pickup/delivery marker explicitly if it is registered but visually missing.

Install the COMPLETE package and restart; CET announces v0.17c. Native scripts,
assets and v0.17b ambush cleanup are unchanged. Thirteen portable suites cover
marker disappearance, delayed registration, inactive/wrong-position pins, API
failure and bounded retries, stage transitions, foreign markers and load reset.
Registry tests do not emulate game rendering. The known GPS-line limit remains.

V0.17B FIX
Completed VIP missions release dispatch while neutralized ambush bodies clean
in a separate queue. Delayed/refused despawn no longer blocks every new call.
All IDs remain owned and retried, with at most three retained convoy scenes.
A full queue skips new VIPs while allowing scanner/cyberpsycho fallback. A new
VIP preserves older scenes. Existing body retention stays 90 seconds/150 m.
Still-active attackers and undelivered VIP cleanup retain their reservation.

The 60-120 second standby starts when the generated assignment closes and runs
during cleanup. Previously retention delayed that timer, and failed ambush
despawn could leave the entire dispatcher stuck. Busy/menu/combat pauses stay.

CET shows Automatic dispatch with the timer or blocking reason. Log automatic
dispatch diagnostics includes VIP/cyberpsycho state. Ambush status now shows
remaining retention seconds or the number of actors awaiting deletion.

Install the COMPLETE package and restart; CET announces v0.17b. Native scripts,
archives, the 50/30/20 mix and saved rewards remain unchanged. Thirteen portable
suites cover VIP-to-next-call continuity, bodies refusing deletion for over five
simulated minutes, Codeware-style deferred despawn, three-scene capacity and
fallback, pause gates and live attacker cleanup. In-game validation is needed.

V0.17A TEST
Automatic calls, Request dispatch now and the trunk's Request new dispatch
now draw 50% scanner / 30% VIP / 20% cyberpsycho. Unavailable types are removed
from that draw and another type is tried, once each at most. Pending actor
cleanup blocks a new call. All-unavailable searches retry after 30 seconds.
Busy, combat and menu pauses remain. Individual CET test buttons are retained.
Actual proportions depend on which types have suitable locations/resources.

VIP delivery pays a flat EUR$2000. Cyberpsycho completion pays EUR$3000,
plus EUR$500 for a confirmed non-lethal neutralization. Both contribute one
NCPD Career incident. Existing scanner EUR$1000 / active-dispatch EUR$500
supplements and independent EUR$250 arrest payouts are retained. A scanner
dispatch still counts only once toward promotions.

Generated completions and payments are saved separately from scanners/arrests.
Unique persistent IDs and paid records prevent duplicate rewards. Failed
transactions retry earned money across loading/shift changes. Payment receipts
follow the completion notice. Existing scanner progress and milestone claim
records survive. Old prototype generated wins cannot be credited retroactively.
Active generated missions still close on reload; earned records remain saved.

Install the COMPLETE package and restart, including NCPDPatrolIncidentSystem.reds.
VIP/cyberpsycho native interfaces: 4. Incident interface: 1. No new dependency.
Thirteen portable suites and offline API checks cover 18 Lua modules, 28 native
scripts and 66 install files. Actual game/cache compilation, traffic and
rendered behavior still require an in-game test. See CHANGELOG_NEXUS.md in the
GitHub repository for changes since the published Nexus 0.8.1 version.

V0.16E TEST
VIP searches retain preferred 500-2000 m pickups and 800-2500 m trips. If no
pair exists, try 250-2000 m pickups/500-3500 m trips, then pickup radii of
3.5 km and 5 km with trips up to 5 km. Nearby mixed/drop-point routes precede
remote fast-travel-only routes. Scanner clearance stays 100 m. Location
diagnostics show total/clear/blocked counts, distance buckets and nearest point.
Responses beyond 2 km gain time: five minutes normally, up to ten minutes at
5 km. The packed journal briefing refers to the assigned deadline. Delivery
still has fifteen minutes and requires actual boarding and a living exit.

An ambush can now have 1-3 cars, each with two attackers and separate mounting,
chase, combat and cleanup. Default: random 1-3. CET > DISPATCH CONTROLS >
Ambush cars ... (change) cycles Random/1/2/3. TEST: Trigger VIP ambush uses
that choice. Changes made after a car starts apply to the next transport.
Each car needs its own checked off-camera road position and 12 m separation.
One warning follows actual mounting. Extra cars with no safe start within
20 gameplay seconds are skipped. One convoy per trip; no late second wave.

An unsuitable arrest area now shows a short instruction to move the suspect
to flat, clear ground. Technical errors and rejection counters stay in CET.
Fresh placement queries retry briefly for up to about two seconds, with a
0.9 m navigation probe. Actual displacement remains capped at 2 m/0.75 m and
existing surface, native activation and payment checks remain. There is no
20-second cooldown. Apparently flat ground that still fails needs a live test;
the new log counters distinguish navigation, collision, slope and height.

Install the ENTIRE package and restart: includes vip_ambush_unit.lua and the
updated VIP archive. VIP native API is 3. No new dependency. Twelve portable
suites and offline API compilation pass; native traffic, collision, animation
and installed-game compilation still need in-game confirmation.

V0.16D TEST
Arrest placement now scores nearby ground using navigation and real collision
across the lying footprint, preferring a flatter patch within the existing 2 m
and 0.75 m height limits. Native workspot sliding does the final alignment;
the actor's root height no longer blocks the animation before it can start.
Actual local alignment plus the existing native activation proof is required
before payment. Unsafe/no nearby ground still rejects without payment.

R pickup is preserved before arrest and after a failed attempt. Only primary
Loot/F is replaced; pickup is blocked during the short active securing request.
Use native pickup to move a suspect when no safe nearby patch exists.

VIP selection ignores fast-travel interaction availability and falls back to
native drop-point terminal markers when the discovered fast-travel network
does not provide a valid pair. It does not unlock any travel point. Existing
500-2000 m pickup, 800-2500 m delivery, scanner clearance and arrival navigation
checks remain. Log VIP diagnostics shows location counts and selected sources.
Regions without suitable world markers can still be unavailable.

Ambushes check recent driven route distance, static road support, the car
footprint and a corridor clear of barriers. Spawned car position/height must
match the checked lane before crew creation and chase. Crew now spawn within
the car footprint instead of 3-6 m to its side. Wrong-level/lane cars are
deleted before retry, with three attempts maximum per trip. No hostile warning
until verified placement and actual boarding. Unsafe points defer spawning.

Install the entire ZIP and restart. Test R pickup and ragdoll arrest near curbs,
VIP dispatch in a sparsely discovered district while driving, and manual VIP
ambushes on bridges/divided roads. Road placement rejection logs actual and
requested coordinates. Twelve portable suites plus offline API compilation
pass; actual game traffic/physics and installed-cache compilation need testing.
No partner weapon-state changes. Existing payments and archives are retained.

V0.16C FIXES
Living physical ragdolls can be prepared for the same lying arrest loop. The
selected eligible suspect gets a checked nearby ground position, at most 2 m
away and 0.75 m vertically. No health, death or defeat state is changed. Payment
still needs stable native workspot activation. Failed recovery/unsafe ground
pays nothing; cleanup releases only this mod's physics ownership. Native body
pickup/mounting keeps control if it takes over after payment.

Cyberpsycho scene selection ignores fast-travel interaction availability, which
can change while mounted. Completed incidents free the dispatch immediately;
retained actors are cleaned after 120 seconds or leaving 150 m without touching
later markers/journals. A maximum of three retained scenes bounds resources.
The Bean Bagger uses the verified vanilla Tactician inventory icon.
Weapon readiness keeps its existing rules and native combat priority. Partner
follow refresh now replaces its previous owned indefinite follow request.

Install all files and restart. Arrest module interface: 6. Test physical and
animated living downed suspects, a cyberpsycho request while driving, another
request after completion, and the Bean Bagger inventory icon. All checks are
offline; actual game animation/physics and installed-cache compilation need
confirmation.

========================================================
Full installation package. Fixes active backup holding at the request location,
adds verified-equipment fallback for partner/backup readiness, and replaces the
horizontal trunk choices with a two-row numeric game popup. Includes all 17
cyberpsycho variants, existing VIP ambush/aftermath, tyre repair, career, partner
revive, backup and arrests. Generated payouts and career credit are included.

V0.15D HOTFIX
Fixes the two compilation errors reported in the v0.15c game log:
- Bool comparisons in officer equipment use Equals/NotEquals intrinsics.
- The trunk popup caller imports the complete Codeware.UI namespace, including
  the CustomPopup type required by CustomPopupManager.ShowPopup.
No gameplay or reward changes. Includes the complete v0.15c installation.
The offline source checker had accepted constructs rejected by the game compiler.
CI now also checks those observed incompatibilities. This is not a game-cache
compilation guarantee; confirm that the updated scripts compile in your game.

V0.15E SHIFT START FIX
The v0.15d scripts compile in the user's game, but shift entry still expected
trunk API 3 while the new popup exposes API 4. Shift entry now uses the same
canonical compatibility check as the trunk bridge. No native scripts changed.
Tests execute the shipped init.lua and trunk.lua through CET Start/End Shift,
fast-travel requests and the optional hotkey. Current interfaces start normally;
missing/old interfaces refuse before beginning a shift or spawning a partner.
Install this complete package and restart. All v0.15d fixes are included.

V0.16A BEAN BAGGER FOR V
M2038 NCPD Bean Bagger is an extra fixed Tier 2 reward at 20 completed incidents.
Its stable item ID is Items.NCPDBeanBagger_M2038. Existing receipts stay intact:
if you already collected the old 20-incident bundle, Claim next milestone reward
issues just this missing part. Partner equipment and assignments are unchanged.
The separate CET > NCPD CAREER > TEST: Give Bean Bagger (Tier 2) button needs no
unlock override. It gives one test copy per session without consuming a career
receipt. The normal tiered test button includes it too and shares test receipts.

Weapon name/description use the existing Codeware localization provider. The
weapon keeps the normal Tactician geometry, pump animation, sound and muzzle VFX.
A private ArchiveXL appearance adds matte blue to the pistol grip and pump only.
The stock panel, butt pad, receiver, barrel and other parts keep original materials.
Its own
0.90 DamagePerHit multiplier remains; perks/mods/normal game scaling still apply.
The handoff's full Pax hook is replaced: that package also adds a damage bonus.
A native hit wrapper applies Nonlethal only to V's ranged hits using this exact
weapon on human NPCs, and removes explicit kill/dismember overrides on that hit.
Living downed/unconscious/pending-defeat targets take zero further Bean Bagger
hit damage, including follow-up pellets. Other guns, NPC firing, bashes,
explosions, quickhacks and mechanical targets retain their normal behavior.
This follows the game's defeat mechanism. Scripted/boss defeat restrictions and
other damage sources are not overridden. No automatic arrest, payment or revive.

BEAN BAGGER GAME TEST
1. Restart after installing all files. Use TEST: Give Bean Bagger (Tier 2), then
   confirm its inventory name and Tier 2 quality and equip it on V. Check the blue
   pistol grip and pump, aim, fire/reload, and compare a normal Tactician.
   Include NCPDPatrol_BeanBagger.archive and .archive.xl from the ZIP.
2. While on duty, shoot an ordinary human enemy. Test torso/headshot, close range
   and a follow-up shot on a downed target. Look for living defeat, not death.
3. CET > Log Bean Bagger diagnostics reports actual last-target dead/defeated/
   unconscious state, native defeat availability and matched pellet hit counts.
4. Approach an eligible living downed enemy and use the existing Arrest suspect
   interaction. It should pay the existing EUR$250 once after securing.
5. Switch to a normal gun; its damage/lethality must remain normal. If comparing
   damage, match Tier 2, attachments and perks; native damage has random variation.
6. Check the career claim, save/load and duplicate claim/test-button behavior.
All logic/source/API checks are offline. Actual game outcomes must be tested.

The integrated YAML deliberately uses the handoff's original file path,
r6/tweaks/NCPDBeanBagger/NCPDBeanBagger.yaml, replacing its old experimental
record on a normal full-package install. The standalone CET utility is not
needed or bundled. No extra framework dependency is added.

INSTALL
Exit the game. Extract the ENTIRE ZIP into the Cyberpunk 2077 directory that
contains bin, r6 and archive. Replace files and restart; CET announces v0.17a.
Include NCPDPatrol_VIP.yaml and BOTH VIP archive/.archive.xl files.
Keep the Cyberpsycho archive/.xl and all other bundled files.
Include r6/tweaks/NCPDPatrol_CareerWeapons.yaml. It defines reward-only
Military variants with fixed game qualities. It does not edit the vanilla guns.
r6/tweaks/NCPDPatrol_CareerVehicles.yaml registers the four reward cars
for the garage. Registration alone does not unlock a car; claim its reward.

Keep the existing compatible Cyberpunk 2077 2.5 dependencies: CET, RED4ext,
Codeware, redscript, TweakXL and ArchiveXL. Frameworks are not bundled.
For the computer page, the main Browser Extension Framework 0.9.7 is optional:
https://www.nexusmods.com/cyberpunk2077/mods/10038
Without BEF, use CET's career/reward/partner controls. The rest of the mod works.

PATROL MENU: HOLD R, THEN USE NUMBERS
At your owned police car's trunk, tap R for backup as before. HOLD R opens the
blocking game popup, with FOUR options on each of TWO rows. No CET overlay or
additional hotkeys are needed. Normal weapon quickslots are blocked by the popup.
  1: Available / Busy       2: Vehicle repair (10 s)
  3: New partner            4: Cancel dispatch
  5: New dispatch           6: Cop Stats
  7: 10-4 - Release backup  9: Close menu
8 is spare. Top-row and numpad digits work; mouse selection is also supported.
Esc/C closes through the game's popup cancel action. Hold R remains the native
hold interaction. Busy retains the current assignment but pauses automatic calls.
7 is disabled without a patrol; selecting other options never queues 10-4.
Walking away, losing duty eligibility, loading or opening a full-screen menu
invalidates the trunk session. Closing restores vanilla stash/tap/hold choices.
A blocked popup queue times out and restores the trunk instead of trapping it.

ACTIVE BACKUP AND EQUIPMENT TEST
1. Request backup; let the car stop and officers get out. Walk 15-30 m away.
   Both officers should follow V rather than hold at the original request point.
   Native boarding gets priority while V is mounted or a mount/exit runs.
2. Draw/holster on foot with the partner and backup present. An accepted AI
   equipment request is NOT proof of a drawn gun. If no held-slot change occurs
   within one second, the new native helper uses that officer's existing primary
   inventory and the game's equip/unequip routines, then verifies the held slot.
   It does not give, delete or drop guns or change combat/high-level states.
3. Holstering waits for calm. Alerted officers may mirror V drawing, but are never
   forced to holster. Combat, downing/revive and vehicle/boarding take priority.
4. If it still fails, CET > NCPD PARTNER > Log officer readiness (partner + backup)
   reports actual V/officer weapons, ownership, native state and fallback results.
5. Hold R > 7 to release backup, wait for any actual vehicle exits, then drive away.
   The primary partner remains assigned. Check normal revive and VIP transport.

10-4 BACKUP STAND-DOWN
At an owned police car's trunk, HOLD R to open Patrol Menu. While a patrol is
assigned, press 7 for 10-4 - Release backup.
This ends BACKUP follower duty. Officers stop following V and trying to join
V's vehicle. They remain at the scene; there is NO immediate despawn.
If already seated, they request an animated exit from their ACTUAL vehicle/seat
when it is stationary. Wait for them to exit before you drive away. A blocked
exit gets bounded retries; no teleport or braking of V's vehicle is forced.
The primary partner remains your partner and keeps existing boarding behavior.
Without 10-4, backup follow/boarding behavior stays available.

Existing distance cleanup removes the patrol after you are 150 m from the
release point, car AND officers for three seconds. Another patrol remains
blocked until its entities are actually removed, including deferred deletion.
A pending request with no deployed entities is cancelled without creating one.
CET > NCPD BACKUP > 10-4: Release backup provides a fallback test button.
End Shift still performs the normal cleanup. Save/load forgets old-world IDs.
Install all updated Lua, redscript, interaction tweaks and localization together;
the native trunk API is now 4; officer equipment API is 1. New behavior needs a game test.

OFFICER READINESS TEST
1. Start a shift with your partner on foot. Draw your weapon: the partner should
   draw their own primary weapon. Holster it: in a calm state, the partner should
   holster after a short delay. Fists/empty hands do not count as a drawn weapon.
2. Approach a scanner with V's gun drawn. The partner should have their own gun
   ready before combat starts. Native combat takes over; alerted officers never
   holster just because V does. Holstering V must not holster a fighting officer.
3. Call backup, let them park and get out, then repeat. Each officer has separate
   readiness state. No synchronization is forced while either V or that officer
   is mounted. Existing vehicle combat remains native.
4. Check boarding and partner down/revive: readiness yields to those actions and
   resumes after follower recovery. Movement/follow/hold orders are preserved.
   Unsupported gear API calls disable readiness for that actor and log once;
   following/boarding/combat remain available. A replacement gets fresh state.

CYBERPSYCHO VARIANT TEST
Random mode uses 17 verified original Sighting records, as PRIVATE clones.
It avoids the previous variant where multiple records are available. The pool
includes two armored exos, netrunners, snipers, melee/mantis and ranged fighters.
In CET > DISPATCH CONTROLS, TEST: Next cyberpsycho variant cycles the next choice.
Then use TEST: Request cyberpsycho dispatch. Use random cyberpsycho variants
restores random mode. Changing the next preference never swaps an active target.
Travel and completion are unchanged: actual death, defeat or unconsciousness of
the exact spawned/selected actor resolves the assignment. Original quest NPCs,
ambient deaths and other variants cannot complete it. The Bloody Ritual copy
uses aggressive reactions without requiring its original intro. Private clones
use unaffiliated hostile reactions; inherited equipment/stats/abilities remain.
Large exo placement/pathfinding and all appearances/abilities need in-game tests.
Use open locations for exos. Story bosses such as Smasher are not in this pool.
Update ALL Lua, native scripts AND NCPDPatrol_Cyberpsycho.yaml; native CP API is 3.
No new archive/dependency is needed beyond the files already bundled in the ZIP.

VIP TRANSPORT TEST (MANUAL FIRST VERSION)
1. Start a shift, clear any active dispatch, and use CET > DISPATCH CONTROLS >
   TEST: Request VIP transport. Outside combat; a car request is supported.
2. Objective 1: collect the witness, preferably 500-2000 m away. Sparse areas
   may use a 250 m pickup or expand out to 5 km. Response time is five minutes
   normally, rising up to ten minutes with distant pickups. The VIP spawns when
   you approach within 140 m; nothing is spawned beside you on request.
3. Stop near the witness, as DRIVER of an OWNED POLICE CAR. Leave a passenger
   seat free. The VIP tries rear-right, rear-left, then front-right. Your partner
   keeps their occupied seat. VIP boarding is animated, with no teleport fallback.
4. Objective 2 appears only when the witness is actually seated in your car.
   A delivery marker normally 800-2500 m from pickup (500-5000 m fallback) is
   then revealed. Deliver within
   15 gameplay minutes. Menus pause the mission timer.
5. A convoy of 1-3 hostile cars, two gang members each, may pursue you after
   driving 250-400 m. Use Ambush cars ... (change) to set Random/1/2/3.
   TEST: Trigger VIP ambush arms it sooner; it still waits for a road position
   your car actually drove through, 35-65 m behind you and outside the active
   camera view. Looking backwards delays the spawn until the scene bounds are
   off camera. Keep driving on a clear
   road until a suitable trail exists. It will not spawn during the last 180 m
   to delivery. No new hotkey is required. The car starts at a recorded position;
   traffic/lane clearance and native chase AI still require live testing.
6. If you stop for three seconds while the pursuers are within 45 m, they brake,
   wait until their car is stationary, get out and attack. You can escape instead:
   staying over 350 m away for ten gameplay seconds closes the ambush. One ambush
   per trip. Active pursuit has a 150-second test limit. Native combat behavior
   is retained; user tests observed shooting from vehicles. The warning now
   appears after the actual car and crew attach and the chase is requested.
   Defeated/dead attackers and their car remain for 90 gameplay seconds, or until
   you stay more than 150 m from BOTH the car and all bodies for three seconds.
   This also applies when both attackers go down while seated. Delivering the
   VIP does not immediately remove a retained scene. Explicit cancel/shift end
   still closes the encounter. Another assignment waits for scene cleanup.
7. Stop within 30 m of delivery. The witness must ACTUALLY EXIT alive near the
   destination before the journal succeeds. You need not kill the pursuers.
   The delivered witness stays briefly, then is removed after 20 gameplay seconds
   or once you leave 80 m. Cancel active dispatch works from CET or the trunk.
8. Log VIP diagnostics shows current phase, seat, native quest state and ambush.
   Pickup uses fast-travel location anchors, without performing fast travel.
   NCART and anchors near unfinished scanners are excluded. Some anchors may be
   unsuitable for car access; test in a clear roadside area. GPS has the same
   known map-open/close limitation as other dispatch markers.

Only the mod-created witness, car and crew are managed. Death/incapacitation of
this witness, a lost transport vehicle, abandonment, timeout or journal rejection
cannot succeed. End shift cancels; wanted termination fails. Load closes a saved
active VIP journal without deleting actors using old-world entity IDs. New calls
stay blocked until owned-entity cleanup is confirmed. The first prototype uses a
municipal worker as the protected witness; no story NPC is recruited or edited.

VEHICLE REPAIR / TYRES
The existing ten-second trunk service now resets tyres AFTER body repair and
retries after wheel-physics activation on entering/exiting. The repair receipt
is invalidated by a fresh puncture event, so newly shot tyres remain damaged.
Test: shoot front and rear tyres, request repair, wait ten seconds, enter and
leave the car, and drive. Then shoot a tyre again: it should stay flat until
another repair. Engine/native visual persistence must be confirmed in game.

CYBERPSYCHO DISPATCH TEST
1. Start a shift and cancel any existing dispatch. Outside combat, use CET >
   DISPATCH CONTROLS > TEST: Request cyberpsycho dispatch. You may be in a car.
2. The assignment selects a world location 500-1000 m away, expanding to
   1.5 km and 2 km if needed. Marker, notice and response objective appear
   immediately. No enemy or distant navmesh query is created on request.
3. Drive to the scene within three gameplay minutes. Menus pause the timer.
   When you approach within 140 m, the deadline clears and scene preparation
   starts. Navigation is checked around the assigned location, not around V.
4. One cyberpsycho is created near that scene. Once its exact identity and
   attachment are confirmed, the journal completes the response objective and
   activates Neutralize the cyberpsycho. Death, defeat or unconsciousness
   must remain observed for 0.75 gameplay seconds. Backup remains available.
5. Test lethal and non-lethal completion in separate runs. Cancel active
   dispatch (CET or trunk) also cancels a journey before an enemy exists.
6. After success, the target remains until you leave 150 m from the scene or
   120 gameplay seconds pass. Target cleanup must finish before another call.
   Log cyberpsycho diagnostics includes initial distance and search radius.

Location anchors come from native fast-travel world markers. NCART markers
and anchors within 100 m of unfinished scanners are excluded. This does not
perform fast travel. Local spawn projection searches within 50 m of the anchor
and checks reachability after arrival. Failure to find a distant site or local
spawn point never changes the incident into a nearby spawn. This is a prototype
location pool; real site coverage and placement need game testing.

The private Character.NCPDPatrol_Cyberpsycho clone and its HMG/strong-arms combat
configuration are retained. Original quest records/facts and ambient actors are
not edited. Crowd-directed rampage behavior remains a later extension.

The scene marker stays at the destination; HUD distance follows the registered
target. GPS can still require opening/closing the map. Abandonment, missing
actors, refused journal changes and bounded scene-setup failure do not count
as completion. Shift end cancels, wanted termination fails, and loading closes
old active journal entries without deleting previous-world entity IDs.

The first test still does not award generated-incident payment or career credit.
The full updated Cyberpsycho archive is required; native interface is now 2.

COMPUTER
At a browser-capable computer, open Net and select NCPD Career. Its address is
NETdir://ncpd.career. A permanent sidebar provides three pages:

SERVICE RECORD: rank, service grade and promotion progress, next milestone,
incident/dispatch/arrest totals, issued rewards, a seven-step milestone track,
selected partner and quick claim/assignment controls.
REWARDS & EQUIPMENT: seven reward cards with LOCKED, AVAILABLE,
PARTIAL - RETRY or CLAIMED states, weapon tiers, partner access and collection.
PARTNER ASSIGNMENT: four profiles with role, equipment, access requirements,
progress and assignment controls. Locked and selected profiles are explicit.

Navy/cyan/gold panels, button hover feedback and a latest-service-update strip
provide a consistent layout. Width and height adapt to the browser content
viewport rather than using the old fixed-width body. Wider screens expand the
layout; smaller viewports scale the same design. No new asset dependency.

The page is a snapshot. Refresh record after using a CET test control or when
your incident total has changed. Claims, selections and tab clicks refresh it.
If the entry is absent, keep that Net browser open and use CET's Log career
browser diagnostics or Open NCPD Career (computer browser). These do not alter
BEF settings or bypass its restrictions. Diagnostics now include viewport
dimensions, UI scale and fallback=true/false. If the native viewport is not yet
measured, the page uses a 1920x1080 fallback; Refresh record measures it again.

MILESTONES
    5  NCPD anti-shrapnel helmet
   10  Villefort Cortes NCPD Overlord
   20  NCPD reinforced ballistic vest + Lexington Military (T2) + Merrimac Police
   35  Full NCPD Badge Set: coat, pants, boots and goggles
   50  Masamune Military (T3) + Chevillon Emperor NCPD Ironclad
   75  Militech Hellhound Man o' War
  100  MaxTac helmet, jacket and pants + Defender Military (T5)

Claim reward issues the oldest available bundle, one per click. Items go into
inventory; vehicles are enabled in the game's garage. A distinct REWARD ISSUED
notice identifies the milestone. Opening/refreshing does not issue anything.
Each successful item/vehicle has its own receipt saved with the character.
If a bundle partly fails, PARTIAL - RETRY collects its remaining parts only.
Repeated clicks or loading the updated save must not duplicate its rewards.
Already-owned reward vehicles count as collected without another enable call.

Existing v0.10 cash receipts are retained separately. They do not block the
new equipment rewards. New career claims do not grant the old test cash bonus.
Scanner EUR$1000, dispatch EUR$500 and arrest EUR$250 payments are unchanged
and maintain separate records.

Career uses on-duty scanner activity records already maintained by NCPD Patrol,
across shifts and saves. Earlier activities the mod never recorded cannot be
reconstructed. Dispatch and arrest totals do not add extra career credits.
Rank: Probationary Officer (0), Police Officer (5), Patrol Officer (10), Senior
Officer (20), Corporal (35), Sergeant (50), Lieutenant (75), Captain (100).

PARTNERS
    0  Standard NCPD Patrol Officer - Copperhead
   20  NCPD Shotgun Enforcer - Zhuo shotgun
   50  NCPD Tactical Officer - M2067 Defender
  100  MaxTac Netrunner - Omaha / Kappa, netrunner archetype

Access unlocks from the same real incident count, independently of claiming
equipment. Select a profile at the computer. The choice is saved; it takes
effect at shift start or Request new partner from the owned car's trunk menu.
CET also has Partner assignment (CET fallback) and Request new partner buttons.
Changing selection does not remove an officer who is currently on assignment.
Only the actor created by this mod can be replaced. A missing next model or
rejected deletion leaves the existing actor registered and creates no extra.

The Shotgun Enforcer record contains 'tactician' but its vanilla equipment is
a Zhuo. The Tactical Officer supplies Defender. MaxTac uses a generic record,
not a story quest actor. Following, combat, boarding and revive use the existing
controller; their behavior on the three new records needs an in-game test.
Friendly MaxTac quickhacks against NPC enemies are not yet verified.

TEST BUTTON
CET > NCPD CAREER > TEST: Unlock all milestones (session)
This immediately makes all seven reward bundles and all four partner profiles
available. It grants nothing automatically and does not fabricate incident
records or raise your actual rank. The computer displays TEST UNLOCK ACTIVE.

Use Claim reward on the page, or Claim next milestone reward in CET. Inspect
the items and summon each unlocked vehicle. Claims are stored normally, even
when made with test access: clearing the override does not remove those items
or cars. Use a test save if you do not want these claims on your normal save.

Clear test unlocks, or load a save, to restore normal requirements. The override
is transient. A naturally unlocked partner selection survives loading. If a
selected profile was accessible only through test mode and is still locked,
future spawns use Standard until it becomes available again or you select one.
No extra reward is issued by clearing or re-enabling the override.

WEAPON TIER RETEST
Already claimed weapons remain claimed; existing inventory items are not
modified or removed. To get fresh examples after updating, enable TEST unlocks,
then use CET > NCPD CAREER > TEST: Give tiered reward weapons.
This gives one new Lexington T2, Masamune T3 and Defender T5 per session.
No incident counts, normal claim receipts, money or vehicles are changed.
Repeated clicks do not repeat successful test deliveries. If a delivery fails,
retry to get the remaining guns. Loading a save resets the test-delivery list.
Test copies remain in inventory if you save. Inspect tier, appearance, damage
and mod slots in game; the fixed-tier records use native quality generation.

SUGGESTED IN-GAME CHECK
1. Confirm v0.15b. Open all three career pages. Check that the content fills
   the browser, text stays readable and the sidebar/hover/click targets work.
2. Note your actual incident count and rank. Enable test unlocks and refresh;
   access changes while those real values remain unchanged. Check the seven
   reward cards and four partner cards. Claim available bundles if desired.
3. Retain your v0.11b weapon test: Lexington T2, Masamune T3, Defender T5.
   Check all 12 equipment pieces/weapons and all four garage vehicles. Try
   repeat claims, save/load, and verify the receipts remain collected.
4. Enable test unlocks again if needed. Select each new partner and request a
   replacement while on duty. Check follow, combat, car boarding and revive.
5. Check backup/repair/menu at the new cars' trunks and on-duty vehicle chatter.
6. Clear test unlocks. Actual progression and normal eligibility must return.

VALIDATION
Automated tests execute production reward/progression code, actual CET partner
spawning/replacement and actual init.lua test-button handlers. Native APIs and
widgets are mocked. Tests cover legacy cash migration, all 16 reward records,
partial failure/retry across simulated load, garage acceptance/confirmation,
already-owned vehicles, safe context guards, partner gates/selection, test-mode
expiry and no synthetic scanner records. Computer tests use pinned BEF base
Init/Uninit and registry methods with per-device matching and callback cleanup.
All three authored pages fit native-widget fixtures at 1920x1080, 3840x2160,
3440x1440, 1280x720 and 3840x1800. Tests exercise the actual viewport helpers,
hover and all callback cleanup, including stale pages and detached devices.
Offline font/layout previews are not in-game screenshots or hit-testing.

All 24 redscript files pass source-derived API checks with BEF installed and
absent; 17 Lua modules parse. The full 58-file ZIP is checked byte-for-byte.
This is not validation against the real game script cache or actual gameplay.
Camera/retention tests cover FOV/aspect, looking back, scene-volume edges,
missing camera data, delayed notification, last seated kill/down, timer pauses,
all-body distance checks, post-delivery retention and explicit-cancel retries.
Existing arrest/trunk/dispatch tests pass. Archives and payment code remain
unchanged from v0.11b. Core recognizes the four additional owned police cars; support
registration accepts the four partner records. Down/revive recovery is retained.

Weapon tests cover the fixed quality definitions, delivery records, unchanged
legacy receipt identities, missing definitions, partial test-delivery retries,
and the actual CET button. Real weapon tooltips still need an in-game test.

Cyberpsycho tests execute the actual native controller and CET spawn/AI/cleanup,
dispatcher exclusion/cancellation and shipped request/cancel button handlers.
The new journal/localization resources compile, round-trip and extract exactly
with WolvenKit 9.1.1. These are native-boundary tests, not a game simulation.

Interfaces: main/support 17, arrest 5, trunk 2, scanner journal 2, career 3,
browser 1, cyberpsycho 2.

ROLLBACK TO v0.13a
Exit the game and reinstall the entire v0.13a ZIP, including its Cyberpsycho
archive. This restores the nearby manual spawn test.

ROLLBACK TO v0.12a
Exit the game. Remove cyberpsycho.lua, NCPDPatrolCyberpsychoSystem.reds,
NCPDPatrol_Cyberpsycho.yaml and NCPDPatrol_Cyberpsycho.archive/.archive.xl,
then reinstall the full v0.12a ZIP. The encounter adds no persistent reward or
career fields. Earlier packages remain available on GitHub.

ROLLBACK TO v0.11b
Exit the game and reinstall the entire v0.11b ZIP. This update only changes the
career page and its transient layout diagnostics; saved career data is retained.

ROLLBACK TO v0.11a
Exit the game, remove r6/tweaks/NCPDPatrol_CareerWeapons.yaml and reinstall the
entire v0.11a ZIP. Use a pre-test save to remove already issued test copies.

ROLLBACK TO v0.10b
Exit the game. Remove r6/tweaks/NCPDPatrol_CareerVehicles.yaml and reinstall the
entire v0.10b ZIP. Use a save from before this test to undo already issued gear,
vehicles or choices. Earlier packages remain available on GitHub.
