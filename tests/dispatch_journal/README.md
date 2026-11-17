# Dispatch journal checks

Install Python 3 and lupa, then run:

    python tests/dispatch_journal/check_journal.py

An optional argument selects another install root. The authored redscript
controller runs through the shared syntax adapter; only native APIs are mocked.
The actual CET dispatcher and dispatch_journal bridge execute in LuaJIT.

Cases cover 180-second expiry, arrival at the deadline boundary, menu/lag pause,
success/failure/cancellation, repeated outcomes and stale tokens, reuse after
both success and failure, rejected reset/activation, missing/wrong journal
assets, unobserved activation, existing/player-changed story tracking, wanted/
duty/death, loaded-world cleanup and preservation of completed history. Native
writes outside the mod-owned journal path fail fixtures. Real scanner phase
changes drive CET completion. All six briefing paths are exercised, including
reuse and original-path upgrade cleanup. Native completion requires a matching
CompletedPhase scanner. The separate EUR$500 ledger is checked for duplicate
callbacks, stale tokens, failed terminal transitions, cancelled/failed calls,
save/load persistence, unavailable transactions and delayed successful retry.
Actual CET receipt consumption is checked once per successful transfer.

The asset builder checks the authored schema/localization keys, compiles both
resources, round-trips them and verifies exact archive extraction bytes.
The release builder runs these and the existing arrest/trunk checks, parses all
12 CET modules and checks preserved gameplay files against the v0.9a base.
The core scanner system is compared byte-for-byte after removing only the
added money-receipt wrapper. No scanner/arrest ledger is used for dispatch pay.

Native API signatures were checked in core/systems/journalManager.swift and
gameJournalManager.lua in MOD_Development_Reference at
81d996b584a693e8b0f0b20526a9fa38b5c83fe7.
ArchiveXL registration follows its Journal extension. The own resource hierarchy
is Quest -> Phase -> Objective -> Description. No quest mappin is authored.

These are logic/format checks, not a game emulator. Game-cache compilation,
native journal rendering, terminal-state reactivation, actual notifications,
tracking and save loading still need in-game validation. The first prototype
cancels active calls on load, matching the existing duty session policy.
