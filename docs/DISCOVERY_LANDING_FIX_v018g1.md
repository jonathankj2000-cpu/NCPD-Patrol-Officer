# v0.18g1: nearby staging for terminal scene discovery

The supplied v0.18g run contains 35 arrivals, 34 completed terminal/layout pairs,
six verified variants and three verified source locations. Of 28 unverified
pairs, 26 failed `Landing navmesh not ready/too far from recorded center` at the
terminal itself. Those 13 terminal areas never reached offset/layout search.
The remaining two unverified pairs exhausted the geometric search around Grand
Imperial Mall. These are separate failure classes; there is no evidence that the
complete scene fits every terminal area.

The ledger and exported report both end at event 1083 during functional settling
at Chapel, pair 35, without a stop/error/completion event. The user's observed
return message confirms a return was displayed, but the files do not establish
its trigger. No 35-pair cap exists. This release fixes the proven staging defect
and retains stop evidence; it does not claim to have proven the original stop.

## Procedure change

Only explicit off-duty discovery changes. After the existing protected transfer
and five-second collision streaming hold, probe the terminal and its 24 existing
offsets for a supported staging point. Up to three bounded staging passes use the
unchanged `officer_down_layout.landing` checks: ground/slope, small navigation
snap, local Static/Vehicle clearance and same-level elevation. A broad snap to a
different floor is still rejected.

Move V to the supported staging point and confirm a stable landing before
searching full scene poses around the original terminal anchor. V may stand at
a nearby point rather than on an exact terminal coordinate with no navmesh.
A functional actor trial still moves to the fully checked scene center; a failed
trial must clean up every owned actor before returning to the supported staging
point. If no safe staging point exists, that pair remains unverified. It never
grants approval from navmesh alone or changes the full scene's dimensions.

The full geometry, ten-actor spawner, native protection/ownership, injured aid
access, original survey profiles and production dispatch remain unchanged.
All 44 REDscript files and eight archives are byte-identical to v0.18g. No new
framework, native API or dependency is added.

## Stop evidence and counting

Discovery logs `stop_requested` before cleanup and `return_started` at return.
The return message retains the reason rather than replacing it with generic
movement status. Native duty/combat/wanted/mount stops add read-only observations
of those states; unavailable optional observations are explicitly marked.
Physical cleanup remains mandatory before return or another scene.

`scene_discovery_report.json` now includes:

- `verified_count`: layout variants with full placement proof.
- `verified_anchor_count`: distinct source terminals with a verified variant.
- `last_run`: queued/completed pairs, latest event/anchor/time, status and reason.
  A partial export without a final event is `incomplete`, not a claimed success
  or a guessed stop cause.

The CET counter explicitly names terminal/layout pairs: 60 terminals times two
layouts means up to 120 pairs. It does not mean 120 physical locations.

Keep the previous discovery JSONL and JSON. Catalog/layout proof revisions have
not changed, so compatible successful variants are preserved and skipped. The
six supplied successful variants need no retest. Previously unverified pairs
remain eligible for the corrected search. The original survey and 16 approved
production sites remain separate; there is no automatic dispatch import.

## Testing

Install the complete ZIP and fully restart. On a manual test save, go off duty,
exit the vehicle and use CET > Testing > Scene discovery: terminal offsets.
Use the existing nearest-three button for a short test or the all-60 button to
retry unverified pairs while preserving earlier compatible successes.

Thirty portable suites retain legacy dispatch/UI/VIP and original survey
comparisons. The added regression executes the old v0.18g controller against
exact-terminal navmesh denial: all 120 pairs are rejected before offset search.
The corrected controller finds supported offsets and completes 120 full scenes
against the same engine boundary fixture, with unchanged geometry validation.
Other controls cover Static clearance at the anchor, genuine wrong-position
actors and cleanup/retry, all 120 pairs beyond index 35, a simulated combat stop
at pair 35 with retained reason, partial exports and prior-ledger compatibility.
The simulated stop tests logging, not the cause of the user's observed stop.

No test here proves actual Night City ground/navmesh, rendering or a real new
site's combat/revive behavior. Another in-game run is required to measure how
many of the previously unsearched areas fit the complete scene.
