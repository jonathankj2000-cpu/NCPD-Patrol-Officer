# v0.18i — CET menu cleanup

Both current Officer Down request buttons already used the nearby catalogue.
The old prototype request was a separate route that always selected Kryss 1.
The user's exact button was uncertain; an always-Kryss-1 bug was not reproduced
in the normal dispatcher. This update removes those ambiguous prototype
launchers without changing production selection.

## Menu changes

- Testing starts with Dispatch scenarios: scanner, VIP, cyberpsycho and the
  normal Officer Down dispatch. Nearby scene-officer revive remains available.
- Milestone test unlocks are grouped with Reward equipment.
- Scene survey and discovery remain below SCENE DEVELOPMENT - OFF DUTY.
- Diagnostics has one Officer Down group with state, catalogue count/coverage,
  log, gameplay export and guarded scene cleanup.
- Removed ten old buttons: fixed-intersection request/rotation/locator, two
  injured-placement pilot launchers, and five legacy Coyote marker controls.
- Added one safe cleanup control under Older marker test recovery. Legacy
  backend ownership, cleanup APIs, assets and native classes remain installed.

## Verification

The catalogue retains all 54 enabled entries, including the original 16 and
38 approved compact discovery placements. No coordinates, headings, quest
roots, indices, archives or native scripts changed. All 54 remain eligible
when the entire catalogue is enabled together; controlled eligible random
outcomes exercise the actual dispatcher and native marker owner for every
site. Separate ordinary random requests from five distant origins select
nearby catalogue sites within the first available search band.

The existing lifecycle fixture still checks all 54 complete scenes, rescue,
neutralization, payment and cleanup. The UI oracle retains 52 earlier controls
and compares 156 action routes. Retired launchers are absent on every tab;
current requests, logging, export and recovery still route once. Passive
menu drawing produces no gameplay actions. The established release builder
runs 32 portable suites and verifies all 117 packaged files. These checks mock
the engine boundary and do not establish real-game spawn/render reliability.

The only dispatcher addition is a read-only count and coverage getter; the
release builder checks that removing that bounded addition restores the
v0.18h facade byte-for-byte. Every other install payload except build labels,
CET layout and README remains byte-identical to v0.18h. Runtime evidence files
are excluded from the ZIP.

## In-game checks

1. Install the full ZIP and restart. Dispatch should show 54 enabled locations
   and City Center, Heywood, Pacifica, Santo Domingo and Watson coverage.
2. On duty and available, request Officer Down from Dispatch, then test from
   another covered area after completion/cleanup. Inspect the selected site
   through Diagnostics → Officer Down: current dispatch.
3. Testing → Dispatch scenarios → TEST: Request Officer Down dispatch uses
   the same selection route. It keeps normal shift/assignment/cleanup guards.
4. Confirm logging and gameplay export, current marker lifecycle and rewards.
5. Off duty on a test save, confirm the recorded survey and terminal-discovery
   controls remain available. Keep existing result files when updating.
