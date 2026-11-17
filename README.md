# NCPD Patrol

## v0.6e: post-revive health and voice test

**[Download v0.6e](https://github.com/jonathankj2000-cpu/NCPD-Patrol-Officer/raw/refs/heads/main/releases/NCPD_Patrol_v0.6e_Revive_Health_Voice_TEST.zip)**

The user confirmed that v0.6d's down/revive, following, combat and vehicle boarding work in-game. The remaining report is repeated injury dialogue **only after revive**. Actual health during the complaint has not yet been measured.

### Healing and observation

The existing request for **100% health** now follows removal of the recoverable down effect. During protected recovery, the mod reads the native health pool back after at least one second. Below 99%, it requests full health **once more** and reads back on the next eligible tick. There is no repeated healing during normal following/combat. A rejected heal retains its actual low readback in diagnostics.

After follower restoration, **Partner health after revive** prints current health, Wounded/combat flags, revive count, before/after healing measurements and whether a retry occurred. Current health can differ from the earlier recovery measurement through later combat. Before a completed revive, `heal measured=false` marks the before/after fields as unmeasured.

The new **NCPDPatrolPartnerVoice.reds** observes script voice requests for this mod's registered partner on duty. **Partner VO request** prints the requested context, script source and health/Wounded/combat snapshot at request time. It always preserves the original call, arguments, delay and return value. It never mutes or replays speech.

Logging is automatic, at most once per two seconds and 30 lines per partner/revive; each sample contains the latest request. It is not an exhaustive recording list, cannot capture every native audio route, and does not prove audible playback. A 100% snapshot rules out low health at that request. A Wounded flag alone does not identify the cause of a spoken line. No speculative status cleanup is applied.

### Install and report

1. Exit the game completely. Extract the **entire ZIP** into the game directory containing bin and r6, overwriting NCPD Patrol files. Include the new **NCPDPatrolPartnerVoice.reds** and the existing **NCPDPatrol_PartnerDown.yaml**. Restart; CET announces **v0.6e**, native interfaces **15**.
2. Start a fresh shift/partner and down/revive normally. The existing **Test: down partner** button also works. No new binding or log arming is required.
3. If the complaint continues, send **Partner health after revive** and **Partner VO request** lines. If no VO request is captured, send the health line. The existing **Log partner AI diagnostics** button also prints current health while he complains.

### Preserved behaviour and validation

The private infinite **DefeatedWithRecover** record, revive interaction, follower helper, boarding, backup and movement/controller probe are unchanged from v0.6d. Scanner rewards, dispatch, radio and chatter logic remain; compatibility guards advance to interface 15. Requirements remain Cyberpunk 2077 2.5, matching CET, Codeware 1.21.4, RED4ext 1.31.0+, TweakXL and compatible redscript.

Nine Lua modules parse in LuaJIT. Eleven redscripts pass the local compiler with zero warnings/errors against source-derived API contracts, **not the actual game cache**. Authored support logic, the actual voice wrapper and CET modules execute against mocked native boundaries. Checks cover rejected healing, single retry, truthful low readback, no ongoing healing loop, repeated same-actor revive, voice scoping and argument/call/return preservation, logging bounds/rearming, lifecycle guards and prior regressions. In-game healing/audio still need confirmation.

### Rollback

**[Download confirmed v0.6d](https://github.com/jonathankj2000-cpu/NCPD-Patrol-Officer/raw/refs/heads/main/releases/NCPD_Patrol_v0.6d_Recoverable_Partner_TEST.zip)**. Exit the game, remove **r6/scripts/NCPDPatrol/NCPDPatrolPartnerVoice.reds**, then reinstall the complete v0.6d ZIP. Keep its PartnerDown YAML.

### API references

- [Health pool percentage and setting APIs](https://github.com/In-Question/MOD_Development_Reference/blob/main/Definitions/Game_Definitions/classes/gameStatPoolsSystem.lua)
- [Script voice request entry point](https://github.com/In-Question/MOD_Development_Reference/blob/main/DecompiledGameScripts/core/entity/gameObject.swift)
- [Hit-reaction voice contexts](https://github.com/In-Question/MOD_Development_Reference/blob/main/DecompiledGameScripts/cyberpunk/ai/Tasks/ReactionTasks/aiHitReactionTasks.swift)
- [Wounded status type](https://github.com/In-Question/MOD_Development_Reference/blob/main/DecompiledGameScripts/cyberpunk/ai/Conditions/aiStatusEffectCondition.swift)

Archive SHA-256: `1efe824bda7a9488eb306a275dd89bd0fbfcca39445f074167285d1af6c9d291`
