# NCPD Patrol

## v0.6c: controlled revive gate test with automatic observation

**[Download v0.6c](https://github.com/jonathankj2000-cpu/NCPD-Patrol-Officer/raw/refs/heads/main/releases/NCPD_Patrol_v0.6c_Revive_Gate_Probe_TEST.zip)**

The partner getting up and remaining still was already confirmed. This build changes the blocking condition before collecting new evidence.

### Controlled change

The v0.6b diagnostic showed **aid state=2, active=true, high level=Relaxed, follower defeated=false, follower target ready=true, downed signal=true**. The mod rejected recovery solely on the remaining downed tag and therefore disabled follow/boarding.

That tag alone no longer fails readiness. Life/status, conscious high-level state, companion-defeat and follower-target checks remain. Immortal protection, the same actor, existing signal cleanup and role binding remain. This does not establish that the signal is harmless to the engine; it removes the mod veto so its effect can be observed.

### Automatic evidence

After revive and target readiness, **Revive probe** lines are armed. When both actors are on foot, outside combat/menus and at least 5 m apart, the observer records the existing follow command's ID/state and maximum horizontal displacement for three seconds. Periodic follow refresh is held for that one window to keep the sampled command stable.

The observer sends no commands, moves/heals nobody and changes no native flags. Menus/combat/vehicles restart observation, close-range standing is not called a failure, and optional field errors cannot stop partner control. It finishes once with **Horizontal displacement observed** or **No horizontal displacement observed** and the native flags.

Command state is not proof of motion. Displacement is not proof that follow caused it. The new evidence will distinguish the mod's veto from a continuing engine/control problem.

### Install and report

1. Exit the game completely and extract the entire ZIP into the game folder containing bin and r6, replacing all mod files. Include the new **revive_probe.lua**. Restart; CET announces v0.6c and both native interfaces use version 13.
2. Revive once in this new version. Observation arms/samples automatically during normal play. No manual active-state setting or new hotkey is required.
3. Send the **Revive probe** result line from CET. It includes the command state, elapsed time, displacement and native AI flags. **Log partner AI diagnostics** also shows whether the observer is waiting, sampling or finished.

A waiting observer explains whether menus, combat, vehicles or a follow gap under 5 m prevented a useful sample.

### Retained scope

**Backup code is byte-for-byte v0.6b.** Duty, scanner bonuses/receipts, dispatch, boarding, wanted termination, chatter and radio behaviour are retained. Requirements remain Cyberpunk 2077 2.5, matching CET, Codeware 1.21.4, RED4ext 1.31.0+, TweakXL and compatible redscript. No added dependency or required key binding.

### Validation and limits

Nine Lua modules parse in LuaJIT. Redscript checks pass with zero warnings/errors against source-derived contracts, not the actual game script cache. Authored support logic and actual CET modules execute against simulated native boundaries. Scenarios cover the reported residual-tag combination, same-actor recovery, stable command sampling, observed/no displacement, near-target demand, menu/combat/vehicle pauses, hitches, optional native field failures, reset and prior regressions.

These checks cannot verify real Cyberpunk movement or the original engine-side cause. This is a diagnostic test build.

### Rollback

[Download v0.6b](https://github.com/jonathankj2000-cpu/NCPD-Patrol-Officer/raw/refs/heads/main/releases/NCPD_Patrol_v0.6b_Revive_AI_Backup_Arrival_TEST.zip). Exit the game, remove revive_probe.lua from the CET mod folder and reinstall the complete v0.6b ZIP.

### API references

- [AI command ID and state fields](https://github.com/In-Question/MOD_Development_Reference/blob/main/Definitions/Game_Definitions/classes/AICommand.lua)
- [Puppet activity checks](https://github.com/In-Question/MOD_Development_Reference/blob/main/DecompiledGameScripts/cyberpunk/puppet/scriptedPuppet.swift)
- [Canonical follower role and target](https://github.com/In-Question/MOD_Development_Reference/blob/main/DecompiledGameScripts/core/components/aiComponent.swift)

Archive SHA-256: `e8701e7a8b9ddf796794138018dfacf6260b7825c94063e0742be0c225412047`
