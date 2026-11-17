# Career and optional browser checks

Run with Python 3 and lupa:

    python tests/career/check_career.py

The actual career controller reads the actual core scanner ledger getter. Rank
boundaries, next milestones, progress, independent dispatch/arrest records,
late installation with existing progress, six once-only EUR$1000 claims,
failed transactions, restore persistence and eligibility guards are exercised.
Neither opening nor refreshing a page grants money.

The authored browser listener, page renderer, release handlers and browser
initialization/uninitialization wrappers execute through the shared syntax
adapter. Only native widget constructors, game calls and BEF entry points are
mocked. Tests inspect actual page strings and registration/callback cleanup,
including stale pages and a detached player. Other sites remain registered.

The runtime adapter preserves URL literals while stripping source comments.
Existing arrest/trunk/dispatch regressions run in the full package builder.

`contracts/natives.reds` contains UI signatures read from
In-Question/MOD_Development_Reference (core/ui/baseWidgets and orphans.swift).
The browser contracts are public API shape contracts inferred from BEF's own
documentation and the Virtual Atelier/Virtual Car Dealer SetupNewSite.reds
integration at djkovrik/CP77Mods, commit 3b8105d656325e9a061b7bff444c1688a037087e.
They deliberately do not claim to reproduce BEF's private internal data types.

All 21 production redscript files were checked locally against source-derived
API declarations, with and without the optional browser module. These checks
and widget mocks do not establish compatibility with the real script cache,
BEF routing, rendered monitor layout, hit testing or actual save serialization.
The in-game test must cover opening the homepage entry, navigating and closing
the site, reward receipts, a second claim attempt and save/load.
