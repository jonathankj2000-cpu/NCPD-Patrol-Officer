# Evidence death loot — v0.20d

The affected v0.20c save showed `stage=2`, `seeded=1`, `acquired=0`, live shard
quantity 1, first dead quantity 0, current quantity 0 and refresh attempts 0.
Inventory/Interaction components were present, accessible and enabled, while
the actor was not a container and had no native Loot input. This identifies a
missing corpse item, rather than a missing component. Inventory quantity alone
still does not prove rendered loot availability.

The weapon fix is confirmed in game. The reported request source was
`InteriorAreaNotifier 5084`; HighLevel became 1 and ForceEmptyHands was false.
The PSM wrappers and all of their scope/guard methods are unchanged in this fix.

## Source findings

- Cyberpunk-Tweaks commit `0f39f780c92ca389f97fc19cb5ba3c10ba32dd7d`:
  `characters/bases/base_records.tweak:42` defines `Crowd_NPC_Base` with
  `lootDrop = LootTables.Empty`. `CorpoManArasaka` inherits that base and does
  not override the drop. Our previous private contractor also did not override it.
- Game reference `81d996b584a693e8b0f0b20526a9fa38b5c83fe7`:
  `cyberpunk/NPC/NPCPuppet.swift:3270` calls native `ProcessLoot()` during
  `OnIncapacitated`, after the inherited handler. The disposal-device path
  explicitly checks `WasLootGenerated()` before calling `ProcessLoot()`.
  The NPC attach path also invokes loot generation for restored incapacitated
  actors. These native operations own the final corpse inventory.
- `orphans.swift` exposes `WasLootGenerated`, `ProcessLoot`, query ItemIDs,
  per-record inventory removal and the exact LootTable/LootItem accessors used
  here. LootTable/LootItem schema is demonstrated by vanilla quest loot records.
  TweakXL's documented `$type` syntax accepts the short record type names.

The record inheritance and scripted native-call boundary are established.
**Native ProcessLoot internals are not open REDscript code**. The log proves
the before/after quantity loss, not which internal instruction removed the item
or whether a particular game/mod combination used a different inventory bucket.
The repair addresses the confirmed empty final inventory without disabling the
native death handler or replacing the character template.

## Change

Only `Character.NCPDPatrol_VossContractor01` gains a `lootDrop` override, pointing
to a new private table with one guaranteed, count-one entry for the existing
`Items.NCPDPatrol_VossEvidence01`. Corporate appearance, NPC behavior, shard
tags, native Read action and journal identity are unchanged. Vanilla records,
other encounter loot tables and the global loot generator are untouched.
Runtime readiness verifies the actual table binding, item identity, chance and
counts; a mixed package cannot silently use the inherited empty table.

The owner uses a query ItemID to count all matching instances. It waits for
native generation before refreshing corpse loot. If generation is absent,
it makes one guarded ProcessLoot request, then waits for readback within the
existing eight-attempt budget. It does not repeatedly regenerate the actor.

Native generation may replace the pre-death inventory or preserve its item.
The controller therefore checks the final count and removes only excess
copies of this exact private item in this owned corpse. It never trims player
or unrelated inventory. The existing accessibility/quality/normal-Loot refresh
then operates on one confirmed corpse item.

For an existing v0.20c corpse whose item already vanished, a previous real seed
receipt permits **one saved recovery attempt** after native generation. The
replacement goes to the same corpse, not V. Accepted-but-unobserved inventory
writes cannot trigger repeated grants. A rejected write can retry within the
bounded budget. After the corpse item has been confirmed, later removal is
not repaired; this protects native pickup/disposal or external inventory edits.
The one-use recovery flag also survives reload. All new facts use the existing
`ncpd_patrol_otb_` namespace and reset only on explicit new test-cycle Begin.

The acquired fact stops replenishment, and an unexpected restored extra corpse
copy is removed only after that real receipt exists. Killing still leaves the
Retrieve objective active. The original player handler and exact acquisition
observer remain unchanged; the readable can be consumed into Shards normally,
then the quest selects Escape when wanted or Return otherwise.

## Test the existing affected save

1. Install the complete 131-file v0.20d package and restart. Load the affected
   save; do not clear/restart the quest just to repair the corpse.
2. Approach the same body and allow 2–3 seconds. Log Off the Books diagnostics.
   Expect `death loot configured=true`, `native loot generated=true`, current
   shard count 1 and `acquired=0`. An old corpse may show `corpse repair used=1`.
   Its historical `shard after death=0` observation is deliberately preserved.
3. Look at the body and verify ordinary loot UI and the named evidence shard.
   Native prerequisites and an active Loot input are separate diagnostic fields;
   they do not by themselves certify the rendered interface.
4. Take the shard. Check acquisition event/acquired=1, its Shards journal entry,
   conditional NCPD escape and the Return objective. No auto-pickup on kill.
5. Save/reload before taking evidence, leave and return, and reload after pickup.
   The same body/item should persist before pickup and no new supply afterward.
6. For a fresh encounter test, confirm native generation leaves exactly one
   shard without using the old-save recovery. Existing test cleanup remains
   explicit; the working weapon exception and first Voss dialogue are retained.

## Verification

The regression executes the **published v0.20c native controller and Lua** with
the reported inventory replacement boundary. It reproduces live=1/dead=0,
zero refresh attempts and a stalled Retrieve objective. The current controller
is tested against the actual private table declarations, a surviving live seed,
an old saved empty corpse, pending/rejected generation, refused/deferred grants,
query-vs-instance lookup, duplicate trimming, pending pickup, later removal,
exact item receipt and transient save/load resets. Weapon override source and
scope methods are compared byte-for-byte with the confirmed v0.20c version.

43 portable suites and source/API compile checks with Browser Extension present
and absent pass. All ten archives, Voss voice/lipsync/scene inputs and existing
dispatch/duty/reward code are frozen. The compile check uses source-derived API
contracts, not the user's real game cache. Native generation internals, actual
loot rendering and real save serialization still need the in-game checks above.
