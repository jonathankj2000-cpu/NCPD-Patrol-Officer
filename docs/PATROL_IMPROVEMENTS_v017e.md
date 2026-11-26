NCPD Patrol v0.17e — branch test

Scope and order

The r5c user test reports a visible marker, removal on completion and a correct
marker on the next dispatch. Long-term reliability and crash resolution remain
unproven. This package preserves r5c's marker controller and first extracts its
pure catalogue and diagnostic formatting, then adds a career duty entry and
checked backup approaches. The Bean Bagger review makes no asset changes.

Catalogue and diagnostics

NCPDPatrolFixedMarkerCatalog owns canonical paths, seeded hashes, catalogue
construction and binary lookup. Arrays remain owned by the existing controller;
out parameters pass them by reference, including the read-only Index method.
No journal, session, map or actor APIs occur in the catalogue.

NCPDPatrolFixedMarkerDiagnostics is a value-only snapshot and text formatter.
It has no world references or engine access. Snapshot capture reads fields and
pure catalogue values. The controller still performs its existing guarded manual
waypoint observation; formatting never changes state or refreshes native proof.
Current and preserved pre-cleanup lines retain their full r5c wording.

The executable comparison loads the actual r5c controller from commit
a51dabfe91c9c90856b29ecd10e086c3977d8224 and compares all ten scopes, late journal
availability, native retention, fallback, cancellation and unavailable sessions.
All 3161 observation rows match, including complete diagnostic strings, engine
mutation counters and marker IDs/active states. Repeated reads are asserted to
leave state untouched. Existing marker lifetime, five-second fallback, 48-entry
restore slices, token ownership and Session/Ready gating are unchanged.

Career Start Shift

The optional NCPD Career browser page has a Start Shift button in its sidebar,
available from all three sections. It queues RequestDuty(false), the existing
desired-state request consumed by CET's shift controller. The browser does not
directly award items, start dispatch, spawn a partner or create another shift.

After a request it shows SHIFT REQUESTED; normal refresh permits retry if the
request failed, and an on-duty page shows SHIFT ACTIVE. Repeated/stale clicks,
load transitions, missing/dead players and wanted status are guarded. The
five-viewport layout, page callback teardown and the existing shift-entry tests
cover this route. Browser Extension remains optional for the mod; it is required
to display the career website. Existing CET, hotkey and fast-travel entries stay.

Backup approaches

backup_approach.lua adapts the existing ambush's road-history, supported-floor,
static-corridor, padded-camera and actual-placement checks. The working VIP and
ambush implementations are unchanged. The native backup camera formula is
identical to the ambush formula, with duty/session/player guards instead of a
VIP quest-stage dependency. No dispatch location or VIP token is consulted.

- While on duty and unpaused, keep at most 120 samples from V's current vehicle.
  Samples include actual position, orientation, forward direction and time.
  Walking to the trunk preserves that vehicle's history; another vehicle,
  teleport or world reset cannot inherit it. History older than 60 active
  seconds is not reused.
- Prefer a connected recent route 35–90 m back along the driven path, within
  30–85 m spatial distance and four metres of height difference. Follow the
  recorded segments and reject intervening static barriers.
- With no usable history, test a continuous straight approach 40/55/70 m behind
  the request vehicle (or V for the existing on-foot CET/hotkey request). This
  checks ground and corridor clearance; it does not infer an actual traffic lane.
- Require a supported, approximately planar vehicle footprint, body clearance
  and a fully off-camera padded scene. A missing camera/query result is refusal.
  Search waits up to 20 active seconds while retaining the one-patrol reservation.
- Create the car first with spawnInView=false. Confirm attachment, horizontal
  error <=1.5 m, acceptable road height and 0.75 seconds of settling before
  creating either officer. Recheck the camera before crew deployment.
  Temporary crew positions are checked for ground and headroom behind the
  bumper, instead of four metres out to each side where railings/bridge edges
  can leave the officers off the roadway.
- A misplaced car is removed before a replacement. Async/refused deletion keeps
  its reservation. At most three car placements are tried; rejected locations
  exclude another attempt within 12 m. Partial crew creation retains every known
  actor ID until confirmed deletion. End Shift cancels pending replacements.

Arrival still uses the fixed request location, braking and animated exit.
Follower/readiness behavior, native boarding, 10-4 stand-down and the 150 m /
three-second release rule are retained. A load reset forgets stale IDs without
deleting them. Ambush pursuit AI and rewards are untouched.

Static floor/corridor checks do not prove traffic-lane identity, empty dynamic
traffic or successful driving AI. This should reduce wrong-level and visible
spawns; actual road arrival reliability still needs game testing.

Bean Bagger

No clear source regression was found. All six archives, including the blue-grip
Bean Bagger archive, are byte-identical to r5c. See
docs/BEAN_BAGGER_BLUE_PUMP_REVIEW.md for verified bindings and possible causes.
No new runtime diagnostic or speculative material/texture change is included.

Install and test

Install the complete v0.17e ZIP and fully restart. There are 87 install files,
28 Lua modules and 36 REDscript files. Existing shared interfaces stay at 17,
the marker bank stays at 4, and the additive backup spawn-safety capability is 1.
No new dependency or key binding is introduced.

1. Repeat scanner, VIP and cyberpsycho marker completion/cancellation and load.
2. Start a shift from Career without visiting a fast-travel terminal. Check the
   partner, on-duty status and normal dispatch scheduling.
3. Drive to a roadside stop, exit and request backup at the trunk. Test a fresh
   stationary request too. Turn the camera towards/away from the approach.
4. Check bridges/medians and crew arrival; verify 10-4 and distance cleanup, then
   request another patrol. Unsafe terrain can refuse the request after 20 s.
5. For the pump colour, compare an existing gun with a fresh CET test copy after
   restart and the same first-/third-person views. No special logging is needed.

Portable tests mock engine hardware. Offline source/API compilation with and
without Browser Extension does not replace the installed game-cache build.
