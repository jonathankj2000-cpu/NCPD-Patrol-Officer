# VIP responsibility extraction r3

Starts from CET refactor r2 (`a9b654fed01145dd908ffe82de6e097bf2917c56`) on
`git-checkout--b-refactor/cleanup`. This round extracts VIP location selection and
waypoint ownership. It keeps the transport and ambush gameplay contracts.

## Ownership

| Module | Responsibility |
| --- | --- |
| `vip.lua` | Public facade, native journal/token guards, witness creation/identity, follow/mount/unmount commands, transport stages, completion/failure and owned actor/scene cleanup. |
| `vip_locations.lua` | A VIP-specific location policy instance: geographic marker reading, finite-coordinate checks, deduplication, unfinished-scanner clearance, ordered search tiers, random pair selection and cached diagnostics. |
| `vip_waypoint.lua` | A marker owner instance: placement, current ID/position/kind, registry inspection, activation/repositioning, bounded missing-marker recovery, manual rebuild and diagnostics. |
| Existing ambush coordinator/unit | The same convoy/road placement, crew, chase, scene retirement, bounded background queue and confirmed deletion behavior as r2. |

Each new component is created once by the existing VIP owner. Construction/reset
uses no game API or random draw. Native handles are acquired on demand. Helpers
have no journal, entity-spawn/delete, reward or global dispatch APIs. Location
diagnostics and marker state belong to their instance; they cannot overwrite a
sibling instance's state.

The complete `Dispatch.*`/`VIP.*` facade, six-tab CET menu and trunk actions stay
the same. The entrypoint/UI differ only in three build labels. Browser Extension
is still optional; no dependencies, native interfaces or persistent fields change.
Reapply an optional Chinese preview overlay after a full install, as before.

## Preserved location policy

Selection still reads geography rather than fast-travel interaction availability.
It does not unlock/register travel nodes. Completed scanners do not exclude sites;
unfinished combat scanner markers retain their 100 m clearance.

The ordered pickup/trip tiers remain exactly:

| Pickup range (m) | Trip range (m) |
| --- | --- |
| 500–1000 | 800–2500 |
| 500–1500 | 800–2500 |
| 500–2000 | 800–2500 |
| 250–2000 | 500–3500 |
| 250–3500 | 500–5000 |
| 250–5000 | 500–5000 |

Each tier tries fast-travel pairs first, then permits drop points. Deduplication,
candidate iteration, random drop draws for each pickup and the final pickup draw
retain their original order. Errors retain the location diagnostics. Spawn-point
navigation, response/delivery deadlines, witness placement, vehicle checks, seats,
animation confirmations, payments and career credit remain with their owners.

## Marker lifetime

`beginAssignment` resets the assignment's repair counter before placement.
`place` changes pickup/delivery without clearing that counter. `rebuild` adds one
repair only after successful placement. The caller retains native token/stage,
duty, wanted and menu checks before a manual rebuild.

Registry inspection stays once per gameplay second. A missing marker gets a
two-second grace; a failed recovery retries at most every five seconds. Inactive
or displaced owned pins are corrected in place. Only the cached owned ID is
unregistered. Marker diagnostics preserve the old text/IDs/positions/counters.

`clear` removes the current marker and stops restoring its target. If unregister
throws, the ID remains available to a later placement/removal attempt, as before.
`reset` only forgets handles; it must not unregister a marker from a previous
world, whose numeric ID may now belong to something else. Scene/actor cleanup
continues to be owned separately by VIP/ambush. No GPS-line fix is claimed.

## Verification

Run `python tools/build_vip_refactor_release.py` with `lupa==2.6` installed.
It parses 24 Lua modules, runs all 15 previous suites plus the VIP extraction
suite, guards every installed payload file and builds the complete 72-file ZIP.
All 28 native scripts, tweaks, assets, other gameplay modules and both ambush
modules must match r2 byte for byte.

The extraction suite materializes all r2 Lua modules from the pinned commit.
Both runtimes run the actual native quest/reward implementations against the
same engine boundaries, through three VIP scenarios and four generated/mixed
dispatch scenarios. It compares 29,208 trace rows: RNG, facade results, location
and marker diagnostics, registration/removal/repositioning, native tokens/stages,
actor ownership/commands, notices, payment and cleanup outcomes.

Source guards check that the moved policy bodies are unchanged and reconstruct
the old coordinator after reversing delegation call sites. Additional helper
contracts check isolated diagnostics/IDs, stage versus new-assignment repair
counts, failed unregister/placement, old-world ID reuse, side-effect-free reads
and resets, and the absence of actor/journal APIs. Deliberate changes to scanner
clearance and retry cooldown must be detected by the behavioral comparison.

The unchanged 17,374-row dispatch comparison and 156 CET action-route comparisons
also run. `tests/dispatch_refactor` exposes an optional trace-free bootstrap for
the new observer; its default behavior remains the existing regression path.
The CET session source check additionally recognizes the new build labels.

CI builds and commits the ZIP/report only on the refactor branch. Real engine
streaming, traffic, rendering, mounting and animations remain mocked. These
tests do not establish improved ambush reliability or actual game validation.

## In-game check

Install the **complete** ZIP and restart. CET announces `v0.17d VIP refactor r3`.
The package includes both new helper modules and the existing r2 menu.

1. Request a VIP from the Testing tab, both on foot and in an owned police car.
   Confirm the pickup marker and journal, including locations with sparse travel
   nodes. Use Log VIP diagnostics to inspect the selected route.
2. Collect the witness. Confirm actual boarding switches the objective/marker to
   delivery. Rebuild VIP waypoint remains under Diagnostics with the same guards.
3. Deliver the living witness and confirm the same EUR$2000 receipt and one career
   incident. Wait for the next automatic dispatch while Available/out of combat.
4. Test cancellation and shift end, then save/load. Old scene cleanup must not
   remove a new assignment's marker. Active calls still reset on loading.
5. If an ambush occurs, check the existing behavior and cleanup. Its spawn tuning,
   movement, crew/chase logic and retirement rules were not changed in this round.
