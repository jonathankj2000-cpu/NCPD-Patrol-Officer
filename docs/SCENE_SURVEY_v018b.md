# Compact Officer Down and a sequential scene survey

The concrete change is a smaller Officer Down encounter plus an explicit CET
tool for testing the user's recorded places. The tool visits candidates,
uses the same placement and actor code as the encounter, records physical
spawn evidence and clears each scene before the next transfer.

## Layout and supplied locations

The confirmed geometry keeps gang cars at **-5.5/+5.5 m laterally**, hence
**11 m between their centers**. Police and gang car lines move to **-6/+6 m**,
giving **12 m between lines** (about 13.2 m diagonally from the police car
center to either gang car center). The injured/defending officers move to
-9.5 m, while the gunmen stand at 9.5/10 m with lateral offsets -7, -3.5, 0,
3.5 and 7 m. The NPC forward span drops from 24.5 to 19.5 m. Vehicle length
still contributes to the complete footprint. Height, slope, footprint, static
clearance, vehicle overlap and navmesh limits are retained.

The live Officer Down prototype uses this compact variant at its original
fixed quest-marker position. Standard geometry remains a survey comparison.
`officer_down_layout` takes an explicit site and variant, while the shared
`officer_down_actors` owns the common CreateEntity specification, record checks,
attachment, protection/hold commands and deletion behavior. The survey observes
positions without invoking the production corrective position lock.

The DOCX contains **16 entries, Kryss_02–Kryss_17**. Together with the original
TEST_KRYSS_01, the input has **17 candidates**. `assets/scene_survey/sites.json`
retains their exact XYZ and captured heading/provenance. Generated Lua normalizes
headings to 0–360 degrees. Coverage is **City Center (Central) and Watson only**;
individual districts are not guessed from coordinates. These places are not
automatically added to the dispatch pool or given fabricated success results.

## Running the tool

1. Install the full **104-file package** and fully restart Cyberpunk.
2. Load a **manual test save**, go **OFF DUTY**, exit the vehicle, leave game
   menus/combat/wanted status, and clear any retained dispatch/backup scene.
3. In **CET → Testing → Scene survey: 17 recorded sites**, choose
   **TEST: Survey all 17 sites (compact)**. Standard is available for comparison.
4. Close CET and let the game run. Avoid movement input during sampling. The
   tour moves V automatically and eventually restores the original XYZ/yaw.
5. Use **Export scene survey report** and share `scene_survey_report.json` from
   `bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrol/`.

Other controls load saved evidence, retry compact sites whose latest result is
unverified/missing, stop and return, recover a CET-interrupted test, or log the
current phase. Survey/native reservations block normal duty startup until
cleanup/return has finished. Drawing the panel performs no movement or spawning.

## Transfer and physical proof

- Before testing, a private native owner reserves the run, captures V's original
  position/yaw and adds only the `NCPDPatrolSurveyPlayer` invulnerability source.
  It is removed at completion; other god-mode sources remain intact.
- Each transfer requires no owned Codeware IDs and no retained attached handles.
  V is moved to the recorded center. The authored layout leaves the center empty,
  but ambient vehicles/static geometry are checked separately there.
- Arrival waits at least five active seconds, then requires two seconds of
  supported central landing/navmesh. While collision streams, V can be held at
  the recorded point. Unsupported, obstructed or occupied centers are unverified
  after 30 active seconds. Menus and unready worlds pause the process.
- Try the captured heading plus 90/180/270-degree alternatives, or a matching
  previously proven heading first. Preflight rejection is retried across two
  passes at one-second intervals. It never permanently blacklists a place.
- All ten positions must pass production ground/clearance/navigation/Vehicle
  overlap checks before the first entity exists. Private records, nonpersistent
  specs and the same actual spawn/attachment checks are used in both systems.
- After attachment/protection/hold, observe **at least three active seconds**.
  Every actor must retain the expected record/ID and remain within 1.5 m of its
  requested position. Cars brake; NPCs hold. No corrective actor teleport runs
  during sampling. A physical displacement rejects that trial.
- A successful sample becomes a validated site result only after deletion and
  physical detachment are confirmed. Pending/refused cleanup remains reserved;
  no new area can load on top of it. Protection is removed by private source,
  followed by a short interval before another trial/site.
- Unexpected native/API errors and failed creation abort the tour rather than
  labeling every location unsuitable. Disk failures do not bypass cleanup or
  retain V's temporary protection after a confirmed return.

No quest or journal state is activated, no rewards/career incidents are awarded,
and no manual waypoint is touched by this tool. The protected injured officer
uses the same private down status, but the survey tests placement, not the revive
interaction or firefight. Returning does not undo world triggers encountered by
visiting an area; reload the manual test save before returning to ordinary play.

## Persistent evidence and consistent rotation

`scene_survey_results.jsonl` is an append-only event log. It includes each
site/heading rejection, errors, completed site outcomes, original-position return
and interruption events. Each append starts on a fresh line, so a truncated tail
from an interrupted write does not swallow the next event. Invalid lines and
incompatible catalog/layout revisions are ignored when loading.

A validated record contains the candidate's XYZ, variant, exact successful yaw,
actual/expected coordinates for all ten actors, observed duration, maximum drift
and confirmed-cleanup flag. Proven headings are retained separately from latest
results: a later traffic blockage does not erase an earlier success. The latest
failure remains eligible for retry. Proven headings influence the next test's
first choice, while current terrain/navmesh/occupancy is always revalidated.

`scene_survey_report.json` is a derived export containing latest/proven outcomes
for each candidate/variant and the event history. A failed export can be retried
from the JSONL evidence. Reports describe **placement/spawn/stability** and do not
claim completed combat/revive tests or approved baked dispatch markers. They can
later inform a reviewed location/marker catalogue.

## Cancellation, reload and native ownership

Cancellation clears only this run's Codeware IDs and returns V once the physical
scene is gone. A dead player is never teleported; vehicle entry pauses return
until V exits. If return landing cannot be confirmed, protection/reservation is
retained and reported instead of claiming success.

The native helper records every created ID immediately, including partial
creation, and retains the original player position. After **CET reload in the
same running game**, **Recover survey cleanup and return** uses only that native
ID list. It never discovers or deletes ambient actors. A true save/session change
forgets old IDs without deletion/teleport, preventing reuse in a different world.
The tour never automatically resumes after a saved-game reload.

Existing 40 REDscript files, seven archives and the original native marker
controllers/banks remain byte-identical to v0.18a3. The new native survey system
has no journal, payment or career dependencies. Existing dispatch weights and
scanner/VIP/cyberpsycho/arrest rewards are unchanged. Browser Extension is optional.

## Loading and limits of verification

The source-derived TeleportationFacility interface provides coordinate
`Teleport(object, Vector4, EulerAngles)` and `TeleportToNode(object, NodeRef)`.
The inspected fast-travel path uses registered node references; no verified
arbitrary-coordinate, memory-purging loading-screen call was found. This version
uses controlled coordinate transfer, ground/navmesh readiness and hard cleanup
gates. A loading-screen graphic would not prove resources were purged. Memory
and streaming behavior must be checked during the actual game tour.

Portable tests execute the actual Lua tour/store/shared actor code and translated
native owner. They cover all 17 coordinates, both geometries, preferred-yaw reload,
retry filters, delayed loading/menus, physical detach after IsManaged=false,
partial/refused cleanup, displacement without correction, cancellation, API/disk
errors, source-specific god mode, CET recovery, session generation, death/mount
guards, evidence parsing/export and the eight CET actions. The offline native
source/API compiler checks 41 scripts with Browser Extension present/absent.
Engine queries are mocked in portable tests; source/API compilation is not the
actual Cyberpunk game cache, and neither establishes in-game site validity.
