Fixed quest markers r5b

R5a failed in game: the scanner marker briefly appeared in world and map, then
vanished from both. VIP/cyberpsycho reportedly behaved similarly; later calls
produced no initial marker. The post-fallback diagnostics had already cleared
the native evidence. The user also reported an assertion during save loading.
Sanitized observations are in assets/fixed_markers/r5a-game-evidence.json.
R5b's game rendering, repeated-load stability and crash resolution are unverified.

Native lifetime and proof

R5b preserves r5a's six archives byte-for-byte: each site objective contains
one map pin and the definitions start inactive. There are 132 scanner sites,
191 terminals and 1556 site objectives/pins. The original location policy,
RNG, dispatch mix, journal text, timers, actors, results, payments and career
owners remain in place. Existing native quest owners still select the site path.

The earlier implementation treated registered inactive native instances as
unwanted markers, unregistered them and required their absence for success.
That incorrectly conflated registration with visibility and could interfere
with native caching/reuse. R5b separates registered and ACTIVE counts. Cleanup
requests MappinManager Inactive and SetMappinActive(false) for private native
pins. It never unregisters an engine-owned quest pin. UnregisterMappin is
reserved for our own tagged, script-created fallback instances.

Unexpected ACTIVE private pins are deactivated, including legacy r5 hashes.
Inactive native instances are preserved. On activation, one exact inactive
cached instance with the expected hash and position may be re-enabled once.
An ambiguous hash, wrong position or inactive objective does not qualify.
Cleanup verifies deactivation before replacement; refused deactivation retries.
Foreign, story and manual pins remain outside this private namespace.

Full native confirmation still requires one active selected QuestMappin, exactly
one active private bank pin overall, the correct objective hash/ID association,
correct runtime AND quest-log positions, an active site objective and unchanged
manual waypoint ID across activation. Inactive cached bank entries do not fail
this check. The marker manager uses typed Uint16 IDs and path index 1;
disablePreviousMappins=false. No runtime position writes or manual tracking
writes are added. Terminal references and scanner Coyote-relative offsets stay
as authored in r5a. The user's r4d static marker is the proven anchor reference;
it does not prove that the r5b bank activation works in game.

A physically valid selected native marker may have incomplete journal proof.
R5b retains that one active correctly positioned pin and explicitly reports
"Native marker retained; journal link unconfirmed", with native confirmed=false.
A journal-readback failure alone no longer deletes an otherwise usable pin.
Five active seconds WITHOUT a usable native pin trigger deactivation and common-
objective recovery before fallback. Menus pause the sampling timer.

Evidence and fallback

Before native-to-fallback handover, the controller retains a snapshot containing
scope/site/path, hash/ID, registered/active counts, target/runtime/journal
positions and link results. Clearing current proof does not erase that snapshot.
A new assignment resets it. This eliminates the need to capture a transient
five-second log line while testing.

The existing Diagnostics > Fixed quest markers > Log active dispatch marker
diagnostics button prints TWO lines: "Fixed markers" for current state and
"Fixed markers before cleanup" for the retained native snapshot. Both are also
shown in the panel. The separate legacy Coyote experiment remains under Testing.

Fallback is an independent script-created QuestStatic/QuestGiver renderer,
not a claim of native journal association or GPS. Diagnostics expose its ID,
registration, active/visible engine flags, position match and attempt count.
A requested but unobserved fallback is reported as pending. The visible flag
is an engine observation, not proof of rendered pixels. Failed/missing
registration retries at most once per five active seconds. A known inactive
fallback at the target is re-enabled rather than duplicated.

Save loading and reported crash

Both the dispatch bank and legacy experiment now require a defined AND ATTACHED
player before their Tick can reconcile journals, execute nodes or change
markers. A non-null GetPlayer result during old-world detachment is insufficient.
The normal world-attachment callback still forgets old Lua handles and the
native restored callbacks forget previous-world IDs/tokens.

The supplied crash report says PoolAnimBuffers requested 550622650736 bytes
(about 513 GiB) with alignment 322565760, during "Loading world" after 647
seconds in the process. The allocation/alignment are abnormal. The short stack
report does not identify a mod. This evidence neither proves nor excludes NCPD
Patrol causality. The lifecycle fixes address source defects; they are NOT a
verified fix for that animation allocation assertion. No crash dump, screenshot,
save or system-info attachment is committed or bundled.

Verification and installation

18 portable suites and offline API compilation cover the complete package.
The bank suite executes production native/Lua code with mocked engine
boundaries, including a 1556-instance inactive cache, repeated same-ID reuse,
active-only proof/pruning, partial-proof retention, snapshot survival, fallback
liveness/retries, and a non-null detached player during restore. Both cache
unregistration and detached-player regressions are independently rejected
when the suite runs the actual earlier r5a implementation as negative controls.

The original scanner/VIP/cyberpsycho attendance, stage transitions, completion,
reward and tracking methods are still source-guarded. All six scanner briefings,
VIP pickup/delivery, cyberpsycho response/neutralize, reuse, timeout, stale tokens
and separate payment ledgers remain covered. Old dispatch/VIP/CET comparison
suites retain their unavailable-bank compatibility scope. Offline compilation
runs with Browser Extension present and absent; it is not a game-cache compile.

Install the entire r5b package and fully exit/restart the game. Bank interface 3
is required; CET hot reload is insufficient. First verify save loading, then
request/cancel several scanner, VIP and cyberpsycho assignments and reload.
Check that markers persist past five seconds, change with the stage, disappear
on cancellation/completion, and leave the manual waypoint available.

native confirmed=true is the preferred full proof. retained=true with
native confirmed=false means the native marker is kept but journal binding is
unconfirmed. If no marker is visible, use the same diagnostics button and keep
both lines; the retained snapshot and fallback ID/state avoid the earlier race.
GPS and crash resolution still require actual game tests.

Resource building remains:
DOTNET_ROOT=<runtime> python tools/build_fixed_marker_assets.py --wk-cli <WolvenKit.CLI>

R5b needs no resource rebuild. The builder still verifies one-pin site layout,
inactive definitions, original objective/text preservation, roundtrip and
extracted compiled bytes. Rebuild through that tool after future journal edits.
Rollback uses the entire previous package including its three journal archives;
reward and progression receipts are not migrated by this feature.
