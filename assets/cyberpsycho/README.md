# Cyberpsycho encounter prototype assets

The archive contains a private MinorQuest with response and neutralization
objectives, each with a briefing, plus title and NPC name (six strings).
ArchiveXL merges the
quest under `quests/minor_quest`; the existing scanner archive is retained.

Build with WolvenKit Console 9.1.1 / .NET 10:

    python tools/build_cyberpsycho_assets.py --wk-cli /path/to/WolvenKit.CLI

The builder compiles both CR2W resources, serializes them again, validates the
two-objective topology and keys, then packs/extracts the archive and compares exact
resource bytes. No whole vanilla journal or map-pin asset is bundled.
The release report records the two extracted resource hashes. WolvenKit 9.1.1
uses `DateTime.Now` for archive entry timestamps (ArchiveWriter.cs), so archive
container hashes can differ between builds even when both resources are exact.

NPC source: `Character.ma_wat_lch_06_cyberpsycho` in
[ma_wat_lch.tweak](https://github.com/CDPR-Modding-Documentation/Cyberpunk-Tweaks/blob/0f39f780c92ca389f97fc19cb5ba3c10ba32dd7d/tweaks/base/gameplay/static_data/database/characters/npcs/records/quest/minor_activities/ma_wat_lch.tweak).
It supplies the HMG/strong-arms HybridHMG action map and cyberpsycho modifiers.
The runtime spawns only the new `Character.NCPDPatrol_Cyberpsycho` clone, with
General quest affiliation, regular spawn priority, hostile attitude, its own
display name and an empty loot table. Original records and quest facts are not
edited. Record presence is checked before creation; the rendered model,
equipment, difficulty and AI still require a game test.

Hostility and threat setup follow the game's
`core/systems/dynamicSpawnSystem.swift`: owned actor attitude group `hostile`,
hostile relation toward the player, then AIInjectCombatThreatCommand targeting
`#player`. Its negative duration/persistence follow the command task's native
branch. This prototype does not add crowd-directed rampage logic.
