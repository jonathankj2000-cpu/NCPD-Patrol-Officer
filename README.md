# NCPD Patrol

## v0.7b: arrest workspot startup test

**[Download the complete v0.7b test ZIP](https://github.com/jonathankj2000-cpu/NCPD-Patrol-Officer/raw/refs/heads/main/releases/NCPD_Patrol_v0.7b_Arrest_Workspot_Startup_TEST.zip)**

The v0.7a in-game test reached a T-pose, returned no Codeware workspot instance, then restored the original writhing animation when the arrest failed. No payment was made. This build corrects two concrete startup omissions: the private anchor now uses **PLATFORM_PC**, and playback explicitly selects a lying handcuff clip and sends the play signal. These changes still need an in-game test to establish whether they resolve the T-pose.

Before transferring the suspect, the controller checks that the template and vanilla resource exist, validates the new **NCPDPatrolArrestPC** component, and waits for its resource and workspot tree to be readable. Clip selection uses the loaded tree. Clip/play can be retried once after entry; unconfirmed playback is released after **three seconds**, with an eight-second overall setup limit. It does not change the suspect's defeated/unconscious state.

### Install and test

1. Exit the game completely. Extract the **entire ZIP** into the game directory containing **bin, r6 and archive**, replacing the existing mod files. **Replace NCPDPatrol_Arrest.archive too**; it changed. Restart. CET announces **v0.7b**; main/support interface version is **17**, arrest version **2**.
2. While **ON DUTY**, incapacitate an ordinary human enemy without killing them. Approach/look at the body and use **Arrest suspect**, normally **F**. Stay on foot within **2.5 m for two seconds**. No extra binding or CET action is required.
3. If the lying handcuff pose is confirmed, expect **NCPD ARREST REGISTERED | +EUR$250**. The same paid actor cannot yield another payment through repeated input, changing shift or loading a save containing that payment. Start with average male/female human enemies on flat ground.
4. If it fails, send CET lines starting **Arrest setup |**, **Arrest bank |**, **Arrest bank names |**, **Arrest pose |**, **Arrest native |** and **Arrest |**. They show resource readiness, selected clips, native playback and helper ownership. **clip=none with instance=false means no Codeware instance was returned**, rather than a native clip named None.

### Arrests and separate payment

Each arrest has its own **EUR$250** payment and receipt. `NCPDPatrolArrestSystem` owns its saved paid-suspect ledger, transaction, count and receipt queue; it only reads common duty/wanted state. Arrests do not contribute to scanner activities or scanner bonus totals. Scanner paid activity IDs and receipts are unchanged. Both kinds of money enter the normal wallet.

Registration still requires an observed, matching non-transition lying handcuff clip, active workspot playback and the private helper's actor association for at least **0.5 seconds**. A void playback call, wrong/transition clip, foreign device or timeout never qualifies for payment. Native registration rechecks the target, range and pending token and rejects duplicate/stale callbacks.

Dead bodies, active enemies, civilians, police, companions, bosses, robots, mounted actors and quest-marked bodies are excluded. Carried quest/evidence items also mark a body as quest-related; loot those normally first. Eligible empty-inventory bodies can expose the arrest action. Ordinary body/loot choices return after arrest or off duty. Menus pause treatment and confirmation; death, mounting, moving away, wanted/off-duty or loading cancels an unfinished arrest.

### Animation and cleanup

The included 8 KiB archive contains an authored invisible `gameObject` referencing the vanilla `generic__lie_ground_lean_front_handcuffs_a__aggressive__01.workspot`. No AMM files or animation banks are bundled, and no AMM dependency is added. No paired V animation is required; a visible handcuff prop is not guaranteed.

The mod never respawns, deletes, heals or resurrects an ambient suspect, and never gives it a follower role. It removes only its own non-persistent helpers after scene departure over 60 m, shift end or body loss/death, and retries declined deletions. It stops only playback still associated with that helper. Loading forgets stale handles. The saved paid identity remains if the pose ends, the body is carried or normal engine cleanup removes it. A different EntityID is a different suspect. Prisoner transport is outside this build.

### Validation and limits

All 10 Lua modules parse in LuaJIT. All 13 redscripts compile with zero warnings/errors against source-derived API contracts, **not an actual game cache**. Authored native logic, actual CET control and interaction wrappers execute against mocked native boundaries. Checks cover eligibility, timing/range/menu guards, duplicate/stale events, shifts/loads, payment failure, resource readiness, explicit clip/play, one retry, three-second release, clip/ownership evidence, body choices and cleanup failures. The actual scanner/arrest classes pay **1000 for a scanner completion and 250 for an arrest independently**, with separate counts, histories and receipts. Previous partner/boarding/backup/dispatch/radio/reward checks pass.

The archive is built with WolvenKit Console 9.1.1. Round-tripping verifies **PLATFORM_PC**, the new component name and native dependency; packing/extraction preserves exact entity bytes. [Asset source and rebuild instructions](assets/arrest/README.md) and [portable logic checks](tests/arrests/README.md) are included in this repository. Local checks cannot establish rendered animation, AI, physics or native save-loading behavior.

Requirements remain Cyberpunk 2077 2.5, matching CET, Codeware 1.21.4, RED4ext 1.31.1, TweakXL and compatible redscript. No extra runtime dependency. Partner revival, boarding, backup, scanner rewards and dispatch behavior are preserved apart from compatibility version guards. The reported post-revive injury dialogue has not been declared fixed.

### Rollback

Earlier full ZIPs remain in [releases](releases), including v0.7a and v0.6e. To remove arrests and return to v0.6e, exit the game, remove these five additions, then reinstall the entire [v0.6e ZIP](https://github.com/jonathankj2000-cpu/NCPD-Patrol-Officer/raw/refs/heads/main/releases/NCPD_Patrol_v0.6e_Revive_Health_Voice_TEST.zip):

- `archive/pc/mod/NCPDPatrol_Arrest.archive`
- `bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrol/arrest.lua`
- `r6/scripts/NCPDPatrol/NCPDPatrolArrestSystem.reds`
- `r6/scripts/NCPDPatrol/NCPDPatrolArrestInteractions.reds`
- `r6/tweaks/NCPDPatrol_Arrest.yaml`

Keep its partner-down YAML and partner-voice script.

Archive SHA-256: `ed66423534d2e821ad7e015c6b2b8647c16018142bc8f1f61e41ef13aa9f99c5`
