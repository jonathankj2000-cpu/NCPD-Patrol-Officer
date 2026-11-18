# Bean Bagger prototype checks

`python tests/beanbagger/check_beanbagger.py` executes the authored native policy
and DamageManager wrapper with game event/flag/slot boundaries mocked. It checks
native-first ordering; exact item, V, ranged and human scope; removal of explicit
lethal overrides; native Nonlethal and no-finisher flags; zero damage on living
downed/pending-defeat targets; unrelated attacks, NPC firing, dead/mechanical
targets and missing data; and transient diagnostics/load reset.

The TweakXL check verifies the stable handoff ID, fixed Tier 2, inherited Tactician,
0.90 DamagePerHit multiplier, and Codeware-registered item name/description. The
standalone YAML path is reused so the experimental Pax definition is replaced.
No vanilla record, visual asset, shared Pax package or global stat is rewritten.

Career tests execute the actual appended reward part, delivery failure/retry,
pre-update save receipts, separate session-only test copies, fixed tier and real
CET button. Existing 20-incident claims reopen only for the new missing weapon.
The original partner assignments, scanner/arrest receipts and incident counts
are preserved. All existing shift-entry tests still execute.

API evidence: `damageManager.swift` / `damageSystem.swift` run ModifyHitData
before ProcessInstantKill; `attackData.swift` defines AddFlag/RemoveFlag and
IsRangedOnly; `hitReactionComponent.swift::CanDieCondition` uses Nonlethal when
the NPC's native defeat mechanic is active; NPCPuppet exposes pending defeat.
The policy does not enable defeat on story actors or resurrect/heal any target.

These checks do not execute native health pools, hit reactions, localization
loading or game rendering. In-game non-lethal outcomes, multi-pellet timing,
headshots/perks, real damage scaling and compatibility still need validation.

## v0.16b blue grip resources

The user supplied the original game resources in `Beanbagger (2).zip`. Authored
private resources are in `assets/beanbagger/visuals`; the archive is rebuilt with
`tools/build_beanbagger_assets.py --wk-cli <WolvenKit.CLI>` (9.1.1/.NET 10).
`compiled.json` records the exact packed bytes and round-trip checks.

The fore-end mask selects the moving foreend bone and its original polymer mask,
excluding the magazine cap and metal pump fittings. The rear mask selects only
the lower pistol grip; the stock panel and butt pad remain original. Separate
first/third-person masks follow each LOD's UVs. Previously empty layers 9 (pump)
and 8 (grip) are reused within the engine's 20-layer limit. All other layers decode
identically to the originals, retaining their wear/dirt. The private plastic
template defines sRGB #28567D in linear color and matte roughness .68-.82.

The entire appearance uses a new factory name and private depot paths; vanilla
weapon resources and item records are not replaced. Mesh render buffers, bones,
rig matrices and component animation/binding data are retained. The portable
visual check validates registration, references, masks/geometry manifests and
source/archive integrity. Rendering and pumping under actual game lighting are
manual checks; do not treat resource round-trips as game validation.
