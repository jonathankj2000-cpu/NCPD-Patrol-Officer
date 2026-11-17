# NCPD Patrol

## v0.6d: recoverable partner test

**[Download v0.6d](https://github.com/jonathankj2000-cpu/NCPD-Patrol-Officer/raw/refs/heads/main/releases/NCPD_Patrol_v0.6d_Recoverable_Partner_TEST.zip)**

The v0.6c in-game probe confirmed that the revived partner stayed still: zero horizontal displacement over three seconds. The tracked command object's state stayed **Enqueued**. That alone did not establish the controller's actual execution state.

### Different down cycle

The partner now uses a private status derived from vanilla **DefeatedWithRecover**, with infinite duration until manual revive. Revive restores health and removes that effect, letting the game's recoverable-status removal callback run. The ordinary **Defeated / ResurrectEvent** cycle and manual downed-signal, senses, bump and high-level repairs have been removed.

The same actor, scoped death protection, 3-second treatment within 2.5 m, interruptions and native Revive Partner interaction remain. Recovery waits for active/conscious state and effect removal, then uses canonical follower-role assignment and companion-target confirmation. Vanilla status records and ambient officers are unchanged. No new V treatment animation is added.

The new record is checked at registration for existence, recoverable type and infinite duration. Include the new YAML when installing.

### Automatic evidence

**Revive probe** records the tracked follow command's ID and **object state**, maximum horizontal displacement and native partner flags. A separate **Revive controller** line reads the controller's state for that command, whether a follow command executes, the selected follow command's ID and the AI update tick count.

The selected ID can differ from the tracked command. States alone do not prove motion. Each optional read fails independently as unavailable. The observer sends/cancels no commands and changes no native state.

Sampling arms automatically after revive and target confirmation, then waits for both actors on foot, outside combat/menus and at least 5 m apart. It holds periodic follow refresh during one three-second window, reports once and stops. Close-range standing is not treated as failed following.

### Install and test

1. Exit the game completely. Extract the **entire ZIP** into the game directory containing bin and r6, overwriting the mod files. Include **r6/tweaks/NCPDPatrol_PartnerDown.yaml**. Restart; CET announces **v0.6d**, native interfaces **14**.
2. **Start a new shift with a fresh partner.** An NPC already defeated by an older build cannot test the replacement down cycle.
3. Down/revive that partner. The existing **Test: down partner** button can trigger this without combat. Approach, use **Revive Partner** and stay within 2.5 m for 3 seconds.
4. Resume normal play and check following/boarding. Logging arms automatically. If still stuck, send both **Revive probe** and **Revive controller** result lines. No manual active-state setting or log arming is needed.

A waiting probe reports which distance/menu/combat/vehicle condition prevents sampling.

### Retained scope

Backup is byte-for-byte v0.6c/v0.6b. Duty, scanner bonuses/receipts, dispatch, boarding, wanted termination, chatter and radio behaviour remain. Requirements: Cyberpunk 2077 2.5, matching CET, Codeware 1.21.4, RED4ext 1.31.0+, TweakXL and compatible redscript. No added dependency or required binding.

### Validation and limits

Nine Lua modules parse in LuaJIT. Ten redscripts pass the local checker with zero warnings/errors against source-derived API contracts, **not the actual game script cache**. Authored support logic and actual CET modules execute against simulated native boundaries. Checks cover repeated same-actor revival, indefinite manual downing, missing/wrong configuration, pending effect removal, blocked recovery, canonical role binding, treatment/menu/vehicle/wanted/load guards, object/controller state disagreement, measured/no displacement, optional API failures, bounded logging and prior regressions.

This cannot verify actual AI, navigation, animations or game physics. The recoverable callback exists in the script reference; whether it avoids this partner's AI stall needs in-game confirmation. This is a test build.

### Rollback

[Download v0.6c](https://github.com/jonathankj2000-cpu/NCPD-Patrol-Officer/raw/refs/heads/main/releases/NCPD_Patrol_v0.6c_Revive_Gate_Probe_TEST.zip). Exit the game, remove **r6/tweaks/NCPDPatrol_PartnerDown.yaml** and reinstall the complete v0.6c ZIP.

### API references

- [Recoverable status apply/remove callbacks](https://github.com/In-Question/MOD_Development_Reference/blob/main/DecompiledGameScripts/cyberpunk/puppet/NPCPuppet.swift)
- [Ordinary versus recoverable defeated handling](https://github.com/In-Question/MOD_Development_Reference/blob/main/DecompiledGameScripts/cyberpunk/puppet/scriptedPuppet.swift)
- [Status records and infinite-duration base](https://github.com/CDPR-Modding-Documentation/Cyberpunk-Tweaks/blob/0f39f780c92ca389f97fc19cb5ba3c10ba32dd7d/tweaks/base/gameplay/static_data/database/status_effect/misc.tweak)
- [Controller command queries](https://github.com/In-Question/MOD_Development_Reference/blob/main/Definitions/Game_Definitions/classes/AICAgent.lua)
- [Canonical follower role and companion target](https://github.com/In-Question/MOD_Development_Reference/blob/main/DecompiledGameScripts/core/components/aiComponent.swift)

Archive SHA-256: `74719e2914681c75dde7ffbcf5d70570e484c904273e5ff6f63e93cc6f993bbd`
