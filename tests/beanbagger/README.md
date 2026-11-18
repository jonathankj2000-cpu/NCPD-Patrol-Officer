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

## Blue grip resource requirement

The handoff contains no original Tactician `.app`, `.ent`, `.mesh`, `.mlsetup`
or `.mlmask` files. The workspace and connected repository also contain none.
The exact grip/pump material-layer mapping therefore remains unavailable. The
current package intentionally preserves the stock appearance; no recolor archive
is advertised or fabricated. To build the requested isolated blue grips, supply
those Tactician resources with their original depot paths (for example in a ZIP).

[Official material editing guide](https://github.com/CDPR-Modding-Documentation/Cyberpunk-Modding-Docs/blob/main/modding-guides/items-equipment/editing-existing-items/changing-materials-colors-and-textures/README.md)
and [ArchiveXL appearance patching](https://github.com/CDPR-Modding-Documentation/Cyberpunk-Modding-Docs/blob/main/for-mod-creators-theory/core-mods-explained/archivexl/archivexl-resource-patching/archivexl-patching-appearances.md)
describe the source-resource/material workflow. A future patch should target
only the Bean Bagger appearance, leaving normal Tacticians intact.
