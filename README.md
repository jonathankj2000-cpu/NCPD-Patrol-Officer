# NCPD Patrol

## v0.7c: correct asynchronous arrest-resource loading

**[Download the complete v0.7c test ZIP](https://github.com/jonathankj2000-cpu/NCPD-Patrol-Officer/raw/refs/heads/main/releases/NCPD_Patrol_v0.7c_Arrest_Async_Load_TEST.zip)**

The v0.7b test found the archive, both resource paths and the correct attached helper, then stopped at **Arrest workspot reference could not be loaded** before attempting animation. This was an API mismatch in the mod: `workWorkspotResourceComponent.workspotResource` is a `ResourceAsyncReference`, while Codeware 1.21.4's `ResourceHelper` methods accept only synchronous `ResourceReference` properties.

v0.7c uses **ResourceDepot.LoadResource** to obtain an asynchronous token, retains it while the helper exists, polls **IsLoaded / IsFinished / IsFailed**, and calls **GetResource** after loading. Pending loads wait without starting animation or repeating the load request; refused/failed loads cancel without payment. New **Arrest resource token** lines show readiness and failure separately.

The PC anchor and tree-based lying-clip selection from v0.7b are retained, along with explicit jump/play, one retry and the three-second unconfirmed-playback release. **No native script, archive, eligibility rule or payment logic changed.** The API mismatch is corrected; actual animation still needs in-game confirmation.

### Install and test

1. Exit the game completely. Extract the **entire ZIP** into the game directory containing **bin, r6 and archive**, replacing the existing mod files. Include **NCPDPatrol_Arrest.archive**; it is unchanged from v0.7b. Restart. CET announces **v0.7c**; main/support interface version is **17**, arrest version **2**.
2. While **ON DUTY**, incapacitate an ordinary human enemy without killing them. Approach/look at the body and use **Arrest suspect**, normally **F**. Stay on foot within **2.5 m for two seconds**. No extra binding or CET action is required.
3. If the lying handcuff pose is confirmed, expect **NCPD ARREST REGISTERED | +EUR$250**. The same paid actor cannot yield another payment through repeated input, changing shift or loading a save containing that payment. Start with average male/female human enemies on flat ground.
4. If it fails, send CET lines starting **Arrest setup |**, **Arrest bank |**, **Arrest bank names |**, **Arrest resource token |**, **Arrest pose |**, **Arrest native |** and **Arrest |**. They show resource readiness, selected clips, native playback and helper ownership. **clip=none with instance=false means no Codeware instance was returned**, rather than a native clip named None.

### Arrests and separate payment

Each arrest has its own **EUR$250** payment and receipt. `NCPDPatrolArrestSystem` owns its saved paid-suspect ledger, transaction, count and receipt queue; it only reads common duty/wanted state. Arrests do not contribute to scanner activities or scanner bonus totals. Scanner paid activity IDs and receipts are unchanged. Both kinds of money enter the normal wallet.

Registration still requires an observed, matching non-transition lying handcuff clip, active workspot playback and the private helper's actor association for at least **0.5 seconds**. A void playback call, wrong/transition clip, foreign device or timeout never qualifies for payment. Native registration rechecks the target, range and pending token and rejects duplicate/stale callbacks.

Dead bodies, active enemies, civilians, police, companions, bosses, robots, mounted actors and quest-marked bodies are excluded. Carried quest/evidence items also mark a body as quest-related; loot those normally first. Eligible empty-inventory bodies can expose the arrest action. Ordinary body/loot choices return after arrest or off duty. Menus pause treatment and confirmation; death, mounting, moving away, wanted/off-duty or loading cancels an unfinished arrest.

### Animation and cleanup

The included 8 KiB archive contains an authored invisible `gameObject` referencing the vanilla `generic__lie_ground_lean_front_handcuffs_a__aggressive__01.workspot`. No AMM files or animation banks are bundled, and no AMM dependency is added. No paired V animation is required; a visible handcuff prop is not guaranteed.

The mod never respawns, deletes, heals or resurrects an ambient suspect, and never gives it a follower role. It removes only its own non-persistent helpers after scene departure over 60 m, shift end or body loss/death, and retries declined deletions. It stops only playback still associated with that helper. Loading forgets stale handles. The saved paid identity remains if the pose ends, the body is carried or normal engine cleanup removes it. A different EntityID is a different suspect. Prisoner transport is outside this build.

### Validation and limits

All 10 Lua modules parse in LuaJIT. All 13 redscripts compile with zero warnings/errors against source-derived API contracts, **not an actual game cache**. Authored native logic, actual CET control and interaction wrappers execute against mocked native boundaries. Checks cover eligibility, timing/range/menu guards, duplicate/stale events, shifts/loads, payment failure, async-token readiness/failure, explicit clip/play, one retry, three-second release, clip/ownership evidence, body choices and cleanup failures. The corrected SDK-boundary fixture rejects ResourceHelper calls on async properties, reproduces the v0.7b abort and passes with the new controller. The actual scanner/arrest classes pay **1000 for a scanner completion and 250 for an arrest independently**, with separate counts, histories and receipts. Previous partner/boarding/backup/dispatch/radio/reward checks pass.

The archive is built with WolvenKit Console 9.1.1. Round-tripping verifies **PLATFORM_PC**, the new component name and native dependency; packing/extraction preserves exact entity bytes. [Asset source and rebuild instructions](assets/arrest/README.md) and [portable logic checks](tests/arrests/README.md) are included in this repository. Local checks cannot establish rendered animation, AI, physics or native save-loading behavior.

Requirements remain Cyberpunk 2077 2.5, matching CET, Codeware 1.21.4, RED4ext 1.31.1, TweakXL and compatible redscript. No extra runtime dependency. Partner revival, boarding, backup, scanner rewards and dispatch behavior are unchanged from v0.7b. Native interface versions remain 17/2. The reported post-revive injury dialogue has not been declared fixed.

### Rollback

Earlier full ZIPs remain in [releases](releases), including v0.7b, v0.7a and v0.6e. To remove arrests and return to v0.6e, exit the game, remove these five additions, then reinstall the entire [v0.6e ZIP](https://github.com/jonathankj2000-cpu/NCPD-Patrol-Officer/raw/refs/heads/main/releases/NCPD_Patrol_v0.6e_Revive_Health_Voice_TEST.zip):

- `archive/pc/mod/NCPDPatrol_Arrest.archive`
- `bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrol/arrest.lua`
- `r6/scripts/NCPDPatrol/NCPDPatrolArrestSystem.reds`
- `r6/scripts/NCPDPatrol/NCPDPatrolArrestInteractions.reds`
- `r6/tweaks/NCPDPatrol_Arrest.yaml`

Keep its partner-down YAML and partner-voice script.

Archive SHA-256: `502c65f71e1cb8a286f8aa4f8892f187936152f0b0eff50159fc3c5a206cda63`
