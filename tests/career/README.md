# Career rewards and partner checks

Run with Python 3 and lupa:

    python tests/career/check_career.py

The authored career model reads the existing scanner ledger. Tests cover the
seven rank/reward thresholds, independent dispatch/arrest totals, all 16 reward
records, legacy cash claim migration, native failure/retry, partial bundles
across simulated restore, once-only item receipts, existing vehicle ownership
and confirmation after EnablePlayerVehicle. Rewards never add activity credits.
The actual core guard recognizes all four reward cars only when player-owned.

Partner tests exercise 0/20/50/100 eligibility and saved selection, invalid or
temporarily locked choices, and the actual CET partner.lua spawn/replacement
module consuming that selection, then its real native RegisterPartner call and
follower initialization. All four models must receive the existing immortal /
manual-defeat protection; unknown models and unsafe contexts are rejected.
Missing models, unavailable career modules,
rejected deletion and load cleanup do not create duplicates or touch ambient
actors. Original follow/boarding/revive code paths are retained. Native entity
creation and character AI are boundaries; no gameplay success is inferred.

The actual init.lua onDraw handler runs against ImGui boundaries. Tests click
the shipped test-unlock, clear, claim, weapon-test and partner-assignment buttons. Test mode
changes eligibility only, expires on restore and preserves genuine receipts.

Weapon-tier tests inspect the actual TweakXL reward records and their Military
parents/fixed Uncommon, Rare and Legendary qualities. The authored career code
must deliver those records at T2/T3/T5 while retaining original preset IDs as
receipt keys. Already claimed v0.11a rewards stay consumed. Missing definitions
cannot fall back to random-tier weapons. Test copies do not change claims or
progress, retries preserve successful copies, double clicks do not duplicate,
and loading resets transient test-delivery state. Tier 4 is configured for the
75-incident rule; there is currently no weapon reward at that milestone.

The real browser listener, renderer, tab/claim/assignment release callbacks and
initialization/uninitialization hooks execute through the shared syntax adapter.
Native widgets/game/context/config are mocked. All three portal pages execute
at 1920x1080, 3840x2160, 3440x1440, 1280x720 and 3840x1800. Tests exercise both
production viewport helpers, verify exact viewport coverage and child bounds,
and check page strings, routes, hover feedback, model guards and every release/
enter/leave callback cleanup. Stale pages, detached devices, zero-sized viewport
fallback and later refresh/resize are covered. This is not a substitute for
real font layout, scaling, hit testing or rendering.

bef_reference.py fetches three pinned public BEF source files from
GreenManNK/Cyberpunk-2077-mod at e2012d2d7778e5101526f9e7115708d2159e6c35 and
verifies Git blob hashes. Set NCPD_BEF_SOURCE to their local directory for
offline tests. These references are test-only and never installed by the ZIP.
Tests execute the actual base Init/Uninit and registry Register, Unregister,
GetSitesData, GetWebPage and IsAddressBlocked. Only array iteration is lowered;
the routing predicates execute unchanged. Registration remains idempotent and
per-computer, and other sites survive closing the NCPD page.

contracts/natives.reds contains source-derived UI signatures, including native
inkWidgetRef.Get/GetController, widget size/scale/pivot/rotation, inkText wrapping,
inkEvent.GetCurrentTarget and the protected browser content/controller fields.
These match decompiled game UI/internet/browserController.swift and core ink
declarations. rewards.reds adds
TDBID.Create, StrBeginsWith and the actual VehicleSystem signatures, from
orphans.swift and core/systems/vehicleSystem.swift in MOD_Development_Reference.
The shared offline GameInstance declaration includes its native GetVehicleSystem.
All 22 production scripts pass local API checks with and without optional BEF,
including its actual pinned base class. The real game cache is not available.

tools/build_career_release.py runs this suite and the arrest, trunk and dispatch
regressions, parses all 12 CET modules, verifies protected production files
against v0.11b, including unchanged career model, core/support, partner module,
vehicle/weapon tweaks and all archives, and builds
the deterministic 45-file install ZIP with a byte/hash manifest. The four
vehicle eligibility records are checked; no bulk vehicle unlock API is used.

In-game testing still needs to cover true save serialization, item delivery,
garage/summon behavior, the three new archetypes' follow/combat/boarding/revive,
friendly netrunner quickhacks, and the actual monitor UI/input.
