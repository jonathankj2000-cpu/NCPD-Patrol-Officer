# Voss continuation — v0.20b

The supplied diagnostics identify the failure: the conversation reached its
final stage, but `IsSucceeded()` could not confirm the journal result. The Lua
error handler then requested Clear, resetting stage/request/choice to zero and
deleting Voss, her Hella and pose device. Off the Books subsequently rejected
the already-erased briefing state. Its old error message conflated unfinished
dialogue, missing resources, menus and rejected journal writes.

The fix stores a durable `ncpd_patrol_qgiver_test_briefed` receipt on the authored
success branch. The final scene receipt still gates success. Both the named
conversation output and normal `Default RET` evaluate it; a premature return
without the final scene fact cannot complete the briefing. Explicit Begin/Clear
resets the receipt. Proven legacy stage-3 receipts can be migrated before cleanup.

Lua keeps Voss on that receipt and retries the continuation at one-second
intervals until accepted. A pending or rejected journal state never triggers
post-briefing actor deletion. Native first-quest completion is retried separately.
Off the Books acceptance records one cycle rather than cancelling immediately
when the new objective is not visible in the same frame. Its parents and current
description activate first; actual journal state gates its marker/actor staging.
On objective transitions the new objective activates before retiring the old one.
Existing manual tracking changes are respected during a delayed activation.

Explicit cancellation suppresses automatic continuation for that briefing cycle,
including after loading. Manual Continue or a genuinely new briefing can rearm.
Missing resources and rejected journal paths remain explicit blockers; they are
not silently treated as successful activation.

Install the complete package and restart. If v0.20a1 already cleared the failed
conversation, its old completion flags were erased: start the Voss test again
and let it finish once. Voss/Hella should remain and the contractor objective
should appear automatically. Continue is available after a retained valid
briefing, with no timing race against automatic cleanup. No fresh game/save is
required. No return debrief, payment or automatic milestone activation is added.

The new test executes the actual shipped v0.20a1 controller against a withheld
journal acknowledgement and reproduces its exact failure/deletion. It also
executes the old native phase's Default RET cleanup. New tests cover both return
ports, delayed/rejected/missing journal state, description/parent requirements,
automatic retries, one-cycle recovery, explicit cancellation and early-return
rejection. These are controlled engine-boundary cases; the game must confirm
the precise runtime behavior. They do not claim to reproduce native timing.

WolvenKit compilation, roundtrip and extraction verify the rebuilt Voss archive.
Only `quest_giver.questphase` changes among its 16 binary resources. The other
15—including the exact working scene, audio, facial clips, subtitles and pose
helper—and the other nine archives remain unchanged. Evidence is recorded in
`assets/quest_giver_test/handoff-resource-audit.json`.

Native interfaces are now quest-giver 5 and Off the Books 2; mixed old scripts
are rejected. The v0.20a1 String/Equals startup fix remains included. Production
dispatch, existing rewards, career and the 54 Officer Down sites are untouched.
