# Dispatch refactor r1

This branch starts from v0.17d (`ff0d0024d85d31df783e5f989a1d2cb3d9cefbc1`).
It extracts responsibilities while preserving the existing gameplay contracts.
It is a branch test build, not a new Nexus release or a save migration.

## Ownership

| Module | Responsibility |
| --- | --- |
| `dispatch.lua` | Existing public facade, cross-type reservation guards, native-version/resource preflight, update order and coordination. |
| `dispatch_scanner.lua` | Scanner candidates and used-history, assignment/token, marker/HUD, attendance, cancellation, timeout and scanner error handling. |
| `dispatch_scheduler.lua` | Shift standby, automatic/Busy preference, countdown, 50/30/20 draws and fallback without replacement. No game or actor API calls. |
| `dispatch_results.lua` | Shift statistics, once-per-native-token result observation, baseline restoration, native incident reward ticking and diagnostics. It never grants currency. |
| Existing journal, VIP, cyberpsycho and ambush modules | Native quest bridge and their own actors, tokens, marker recovery, scene queues and cleanup. |
| Existing native redscript systems | Persistent scanner/generated/arrest ledgers, payment retries and career/milestone records. No fields or interfaces change. |

The module dependencies run toward scanner/scheduler/results and the existing
gameplay modules. They never require the `dispatch` facade back. CET and the
trunk still call the same `Dispatch.*` functions. Only the CET build label changes.
Browser Extension remains optional. The localization provider stays unchanged;
an installed Chinese preview overlay should be reapplied after this full ZIP,
as with other full mod updates.

## Assignment versus cleanup

`Dispatch.isActive()` retains its historical meaning: **the global dispatch slot
is reserved**, including foreground actor cleanup. It must not be simplified to
"native journal stage is active". A closed journal alone cannot prove the old
actors have been safely released.

`Dispatch.lifecycle()` adds fresh read-only snapshots. VIP and cyberpsycho expose
their phase, active assignment, reservation, foreground cleanup and background
cleanup separately. A live assignment can coexist with an older background scene.
`schedulerDiagnostics()` now prints the three cleanup/reservation flags.
These reads consume no random draws and never create/delete actors, move markers,
advance timers or write native quest state.

Native terminal results start standby once per system/token. The existing
60–120-second wait continues during foreground scene retention/cleanup. The slot
is still held until its owner releases it. Completed/retired ambush scenes clean
in their bounded background queue without reserving every other dispatch type.
Cancelled/failed live-NPC cleanup retains its guard. Reset forgets old-world IDs.
The v0.17c marker recovery and v0.17d partial-cleanup decisions remain intact.

## Preserved behavior

- Initial standby 30–60 seconds; later standby 60–120; no suitable call retries
  after 30 seconds. Busy, menu, combat and automatic-pause behavior are retained.
- Selection stays 50% scanner / 30% VIP / 20% cyberpsycho with at most three
  attempts, reweighting available alternatives without replacing attempted types.
- Manual typed CET tests and normal mixed calls keep their existing distinct
  guards. Busy does not prevent a deliberate manual request.
- Scanner EUR$1000 and attended-dispatch EUR$500, VIP EUR$2000, cyberpsycho
  EUR$3000 (+500 nonlethal), and independent arrest EUR$250 remain unchanged.
- No partner, backup, readiness, arrest, vehicle repair, ambush placement,
  progression, persistent field, native interface, archive or dependency changes.

## Verification

Run `python tools/build_dispatch_refactor_release.py` with `lupa==2.6` installed.
It runs all 13 existing suites and the new v0.17d differential comparison,
parses 21 Lua modules and verifies the complete 69-file install ZIP.

The comparison loads all pre-refactor Lua files from the pinned Git commit and
runs both runtimes through the same actual native/dispatch/VIP/cyberpsycho
scenarios. It compares facade results, random draws, timers, quest tokens,
payments, notices, marker registry and actor ownership after commands/updates.
Scanner contracts include successful/deferred payment, pre-arrival closure,
timeout, native journal failure, marker API failure, shift restart, range tiers,
deduplication, Busy/manual behavior and world reset. A deliberate one-second
timer mutation must fail the comparison. Lifecycle invariants run throughout.

The builder also rejects unrelated payload changes. VIP/cyberpsycho actor code
must match v0.17d after removing their read-only view; `init.lua` may differ only
in three build labels. All native scripts and binary assets must match v0.17d.
The report records every packaged file hash. CI runs on this branch and commits
the verified ZIP/report back to it. It never updates `main`.

The engine boundaries are mocked. This does not validate actual game rendering,
traffic, audio, Codeware streaming or the game's redscript cache. Native scripts
are unchanged, so no new native API compatibility claim is made.

## In-game acceptance

Install the complete ZIP in the game root and restart. CET should announce
`v0.17d dispatch refactor r1`. Use a test save for paid completion checks.

1. Start duty at fast travel; check partner arrival and normal trunk controls.
2. Use each typed CET dispatch test: scanner, VIP and cyberpsycho. Verify journal,
   marker, completion, receipt and one career credit. Finish a VIP with ambush,
   then stay Available/out of combat for up to 120 gameplay seconds and check the
   next automatic call. Foreground cleanup can still hold that slot explicitly.
3. Toggle Busy, reopen menus, cancel and request a replacement at the trunk.
4. End a shift and load a save. Saved credits/claims remain; active assignments
   still reset on load. Check that old scene cleanup cannot remove the next pin.
5. Confirm partner/backup combat, revive, boarding, 10-4, arrests and tyre repair
   still behave normally. These systems are unchanged but share the session.

If anything differs, use **Log automatic dispatch diagnostics**, plus the
relevant VIP/cyberpsycho diagnostics. The branch keeps v0.17d separately available
for a direct comparison.
