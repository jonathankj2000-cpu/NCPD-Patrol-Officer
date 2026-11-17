# NCPD Patrol

## v0.7a: arrests with a separate payment

**[Download the complete v0.7a test ZIP](https://github.com/jonathankj2000-cpu/NCPD-Patrol-Officer/raw/refs/heads/main/releases/NCPD_Patrol_v0.7a_Arrests_Separate_Payment_TEST.zip)**

While ON DUTY, use **Arrest suspect** on a living, downed human enemy through the primary body interaction, normally **F**. Stay on foot within **2.5 m for two seconds**. The mod then requests a lying handcuff pose. Only a stable matching clip in an active workspot owned by the private helper permits registration and an individual **EUR$250** payment.

Each arrest has its own **NCPD ARREST REGISTERED | +EUR$250** receipt. **Arrests do not contribute to scanner activities or scanner bonus totals.** `NCPDPatrolArrestSystem` owns its own saved payment ledger, transaction, count and receipt queue; it only reads common duty/wanted state. The scanner system, paid activity IDs and scanner receipt queue are untouched. Money from either source enters the ordinary wallet.

### Install and test

1. Exit the game completely. Extract the **entire ZIP** into the game directory containing **bin, r6 and archive**, replacing the existing mod files. Include the new **NCPDPatrol_Arrest.archive**, **arrest.lua**, both **Arrest redscripts** and **NCPDPatrol_Arrest.yaml**. Restart; CET announces **v0.7a**, main/support interfaces **16**, arrest interface **1**.
2. Start a shift using the existing terminal or CET control. Incapacitate an ordinary human enemy without killing them, approach/look at the body, and press the primary interaction for **Arrest suspect**. No additional binding or CET action is required.
3. Stay close until the arrest pose is observed. Expect the separate EUR$250 receipt. The same paid actor cannot yield another arrest payment by repeating the input, changing shift or loading a save containing that payment.
4. If the pose or payment fails, send CET lines beginning **Arrest |** and **Arrest pose |**. They show the observed animation or failure. Start with average male/female human enemies on flat ground.

Dead bodies, active enemies, civilians, police, companions, bosses, robots, mounted actors and quest-marked bodies are excluded. Carried quest/evidence items also set the quest marker; loot those normally first. Eligible empty-inventory bodies can expose the arrest action. Ordinary body/loot choices return after arrest or off duty. Menus pause treatment and confirmation; death, mounting, moving away, wanted/off-duty or loading cancels an unfinished arrest.

### Lying animation and ownership

The included 8 KiB archive contains an authored invisible `gameObject` anchor referencing the vanilla `generic__lie_ground_lean_front_handcuffs_a__aggressive__01.workspot`. It bundles no animation bank or AMM files and adds no AMM dependency. No paired V animation is required. A visible handcuff prop is not guaranteed.

The CET controller checks the expected non-transition `lie_ground_0__2h_back_handcuffs_a__01` clip (including shuffle variants), active playback and the private helper's actor association for at least 0.5 seconds. A void playback request, wrong clip, another device or a timeout never qualifies for payment. Native registration also rejects duplicate/stale callbacks and rechecks the suspect and range.

The mod never respawns/deletes/heals/resurrects an ambient suspect or assigns it a follower role. It removes only its own non-persistent helpers after scene departure over 60 m, shift end or body loss/death, and retries declined deletions. It stops only playback still associated with that helper. Loading forgets stale handles. The saved paid-identity ledger remains if the pose ends, the body is carried or ordinary engine cleanup removes it. A new actor with a different EntityID is a new suspect. Prisoner transport is outside this first build.

### Validation and limits

10 Lua modules parse in LuaJIT. All 13 redscripts compile with zero warnings/errors against source-derived API contracts, **not the actual game cache**. Authored native logic, actual CET control and interaction wrappers execute against mocked native boundaries. Checks cover eligibility, timing/menus/range, duplicate/stale events, shifts/loads, payment failure, clip/ownership evidence, body choices, cleanup failures and old-world handles. The actual scanner/arrest classes pay **1000 for a scanner completion and 250 for an arrest independently**, with separate counts, histories and receipts. Previous partner/boarding/backup/dispatch/radio/reward checks pass.

The archive is built with WolvenKit Console 9.1.1. Its component/reference survives serialization and packing/extraction preserves exact entity bytes. [Asset source and rebuild instructions](assets/arrest/README.md) and [portable logic checks](tests/arrests/README.md) are included in the repository.

**The F interaction and transition from a defeated NPC into the workspot still need in-game confirmation.** Catalogue/API evidence and local checks cannot verify rendered animation, AI, physics or native save loading. This is a first test build; an unconfirmed pose is cancelled without payment.

Requirements remain Cyberpunk 2077 2.5, matching CET, Codeware 1.21.4, RED4ext 1.31.1, TweakXL and compatible redscript. No extra runtime dependency. v0.6e partner health/voice observations are retained; the reported post-revive dialogue has not been declared fixed. Scanner/support logic is preserved apart from compatibility version guards; backup/boarding/follower helpers are byte-identical to v0.6e.

### Rollback

**[Download v0.6e](https://github.com/jonathankj2000-cpu/NCPD-Patrol-Officer/raw/refs/heads/main/releases/NCPD_Patrol_v0.6e_Revive_Health_Voice_TEST.zip)**. Exit the game and remove the five additions below before reinstalling that complete ZIP:

- `archive/pc/mod/NCPDPatrol_Arrest.archive`
- `bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrol/arrest.lua`
- `r6/scripts/NCPDPatrol/NCPDPatrolArrestSystem.reds`
- `r6/scripts/NCPDPatrol/NCPDPatrolArrestInteractions.reds`
- `r6/tweaks/NCPDPatrol_Arrest.yaml`

Keep its partner-down YAML and partner-voice script. Previous archives remain available.

Archive SHA-256: `7c93d5b9d5975c52f40a5d73ad4e0a7484c5516e6c179e47095db6010d3a0dff`
