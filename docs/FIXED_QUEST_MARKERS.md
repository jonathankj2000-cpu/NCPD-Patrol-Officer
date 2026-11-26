Catalogue/diagnostics extraction in v0.17e

The r5c controller below remains the behavioral reference. v0.17e extracts pure
catalogue work and value-only formatting into two helpers. All 3161 comparison
rows match r5c, including diagnostics and mutation counters. The user reports
working marker creation/completion/next assignment in initial r5c game tests;
long-term/reload-crash resolution is unproven. See PATROL_IMPROVEMENTS_v017e.md.

Fixed quest markers r5c

The r5b game snapshot proves a premature rejection: one active selected native
QuestMappin has the expected hash, objective link and both positions, while the
bank census says zero. The retained/confirmed predicates therefore fail, and
five seconds later our code hides that valid native pin. The user observed two
briefly visible markers, then none on another attempt, and another reload crash.
Sanitized evidence is in assets/fixed_markers/r5b-game-evidence.json.

Ownership identity and native proof

R5b admitted current paths to m_ownHashes only if journal entries were available
inside RestoreCleanup. StartCurrent later resolved the selected entry without
repairing that catalogue. The exact live reason for the missing membership is
not captured, but the suite reproduces the rejection with temporarily absent
journal entries against the actual r5b implementation.

R5c builds a pure catalogue of 3112 private current/legacy paths using RED4ext's
Murmur3 seed 0x5EEDBA5E. It does not depend on journal availability or use world
handles. The catalogue survives world changes, with one repair if damaged.
Sorted identities use binary lookup. Recorded r5/r5b game hashes are independent
checks of the algorithm and canonical paths. Journal mutation is not required
to build identity data.

The selected pin additionally belongs to the exact private path resolved by the
current request. That direct identity participates in the SAME ownership census
as all other bank pins. An incomplete cached catalogue cannot exclude this pin.
A foreign hash or unrelated manual/story pin is not adopted. Full confirmation
requires catalogue membership and completeness; an exceptional runtime alias
can retain the selected pin without claiming full catalogue proof.

Native confirmation still requires exactly one active selected native pin,
exactly one active private bank pin, no other active private pins, the same
objective hash/ID, active objective, matching runtime AND quest-log positions,
and unchanged manual waypoint ID across activation. Inactive cached native
instances are valid. A correctly positioned selected native marker is retained
when full proof is incomplete, with native confirmed=false. A journal/census
failure alone must not delete a physically valid selected pin.

Native quest instances belong to the engine. Cleanup requests Inactive and
SetMappinActive(false), preserving reuse. UnregisterMappin is reserved for our
own tagged script-created fallback. Exact cached-target reactivation remains
bounded to one attempt; ambiguous hashes and wrong positions are not activated.
No runtime position writes, global marker disabling or manual waypoint tracking
writes are introduced.

Session lifecycle and restoration

A new Codeware ScriptableService, NCPDPatrolMarkerSession, registers sticky
Session/BeforeStart, BeforeEnd, End and Ready callbacks. These callbacks change
ONLY local readiness/generation flags. They do not access journals, actors,
map pins or quest nodes. Duplicate Ready events are idempotent. The service is
initialized before sessions and survives world transitions without old-world
references.

The native bank, legacy marker experiment and CET update entrypoint require
Session/Ready as well as normal player/world conditions. BeforeEnd suspends
CET controller updates even while GetPlayer is still non-null and attached.
A later generation forgets old logical marker state. Native work happens from
a subsequent update, outside the lifecycle callback. This is stronger than
r5b's attachment check; it is not a verified explanation of the reported crash.

The restored private-objective sweep processes at most 48 objectives per Tick,
after readiness. Its 1556 paths are fixed; no all-bank discovery happens during
restore. An incomplete/rejected sweep blocks new marker activation rather than
running an unbounded synchronous reset. Current diagnostics show readiness,
generation, restore cursor, ownership count/builds, expected hash and selected
membership. Existing quest owners retain timers, actors, results and rewards.

Fallback and diagnostics

Before a genuine native-to-fallback handover, the controller retains scope/site/
path/hash, counts, link and positions. The existing Diagnostics > Fixed quest
markers > Log active dispatch marker diagnostics control prints current state
AND Fixed markers before cleanup. No transient log capture is required.

Fallback remains an independent script-created renderer, not journal/GPS proof.
Current status now follows every observation: a delayed registration can change
from pending to active once observed. The r5b log's pending label with true
registration/active flags is reproduced as a regression, not interpreted as an
absent marker. Engine visibility flags are not proof of rendered pixels.
Retries are bounded; an inactive known fallback is re-enabled without duplicates.

Evidence and limits

The user-provided analysis is research input. Its suggested explanations are
not treated as facts or mandatory changes. The supplied earlier raw crash dump
showed an abnormal PoolAnimBuffers allocation of roughly 513 GiB. The later
analysis describes an access violation reading 0xFFFFFFFFFFFFFFFF during player
spawning; the corresponding raw archive was not attached here. Neither report
establishes NCPD Patrol causality, and r5c does not claim to resolve the crash.
No crash dump, save, screenshot, system information or full external analysis
is committed or included in the install.

All six archives remain byte-identical to r5a/r5b: 132 scanner sites and 191
terminal sites, 1556 single-pin site objectives, inactive definitions, named
terminal anchors and scanner offsets relative to the game-confirmed Coyote
anchor. Original location policy, dispatch mix, RNG, actors, journal text,
deadlines, results, money and progression remain with their existing owners.
Browser Extension remains optional. The new service uses already-required
Codeware 1.21.4 APIs.

Verification and game test

18 portable suites execute production code with engine boundaries mocked. New
coverage includes journal entries absent during restore then available at
assignment, the observed scope-3/site-40/hash-3418482757 case, direct selected
identity with a damaged catalogue, a native runtime alias without false full
proof, sticky/idempotent session callbacks, BeforeEnd with a still-attached
player, 48-objective work bounds, no world-container lookup while unavailable,
and delayed fallback registration status. Actual r5b code must fail the valid-
marker rejection control; the earlier two r5a negative controls remain.

Existing 1556-instance native cache/reuse tests, all six scanner briefings,
VIP pickup/delivery, cyberpsycho response/neutralize, cancellation, completion,
reward ledgers, manual waypoints and tracking remain covered. Original actor/
reward/result methods are source-guarded. Historical comparisons retain their
unavailable-bank scope; bank-present behavior has its own suite. Offline source/
API compilation runs with Browser Extension present and absent; it is not a
compile of the user's installed game cache.

Install the entire r5c package and fully restart. There are 84 install files,
27 Lua modules and 34 native scripts; the new MarkerSession service is required.
Bank interface 4 is required. Check loading, then repeated scanner/VIP/cyberpsycho
requests, marker persistence beyond five seconds, cancel/complete and reload.
Expected normal native state: ownership entries=3112, selected in catalog=true,
registered/active selected=1, active bank pins=1, native confirmed=true,
fallback=false. Use both diagnostic lines if behavior differs. Game rendering,
GPS and repeated-load stability still require actual game validation.
