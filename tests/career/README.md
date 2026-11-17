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
adapter. Native widget constructors, game calls and framework configuration
are mocked; the base listener and registry logic use pinned BEF sources. Tests inspect actual page strings and registration/callback cleanup,
including stale pages and a detached player. Other sites remain registered.

The runtime adapter preserves URL literals while stripping source comments.
Existing arrest/trunk/dispatch regressions run in the full package builder.

`contracts/natives.reds` contains UI signatures read from
In-Question/MOD_Development_Reference (core/ui/baseWidgets and orphans.swift).
The browser contracts now use the actual CustomInternetSite type and the
actual listener/controller API ownership in the pinned BEF source snapshot.
The v0.10a inferred navigation API was incorrect and is not retained.

All 22 production redscript files were checked locally against source-derived
API declarations, with and without the optional browser module. These checks
and widget mocks do not establish compatibility with the real script cache,
BEF routing, rendered monitor layout, hit testing or actual save serialization.
The in-game test must cover opening the homepage entry, navigating and closing
the site, reward receipts, a second claim attempt and save/load.


## v0.10b registration regression

The original navigation shape was wrong: BEF adds LoadPageByAddress to the
browser controller, not the listener. The corrected controller contract and
actual pinned base class reject that original call. The listener data is the
actual CustomInternetSite value type, with the real device/controller fields.

bef_reference.py fetches three pinned public source files from
GreenManNK/Cyberpunk-2077-mod at e2012d2d7778e5101526f9e7115708d2159e6c35 and
verifies each Git blob hash. Set NCPD_BEF_SOURCE to a local reference directory
for offline tests. These reference sources are not bundled with the install.

Tests execute the actual framework base Init/Uninit and the actual registry
methods Register, Unregister, GetSitesData, GetWebPage and IsAddressBlocked.
The source adapter lowers only the registry's array iteration; its predicates
and routing execute unchanged. Native widgets/context/config are boundaries.

The production controller initialization and pre-SetWebsiteData registration
hooks are idempotent. Diagnostics read the actual per-computer registry and
framework flags. Correct-device routing, wrong-device rejection, blocked or
disabled navigation, detached-world guards and callback cleanup are checked.
The new browser state is transient; no career/payment ledgers are modified.
