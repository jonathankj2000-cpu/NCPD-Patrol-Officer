# NCPD Patrol

## v0.6b: partner AI after revive and backup arrival

**[Download v0.6b](https://github.com/jonathankj2000-cpu/NCPD-Patrol-Officer/raw/refs/heads/main/releases/NCPD_Patrol_v0.6b_Revive_AI_Backup_Arrival_TEST.zip)**

This test build addresses two reports from v0.6a: the partner gets up after revive and remains idle despite the success notice, and backup drives past instead of stopping and unloading.

### Partner recovery

The previous success check observed life/status activity. That does not establish that AI has left a downed state. Recovery now removes the separate **FollowerDefeated** effects, clears only downed gate signals on the registered partner, restores senses/bump and requests the relaxed-state transition used by the game's recoverable defeat path.

Readiness also checks high-level state, companion defeat effects and downed signals. The follower role is restored through **AIHumanComponent.SetCurrentRole**, which updates follower sense type, companion cache and the role-change event. Recovery no longer manually clears the existing role and invokes its private attach hook. Follow and boarding wait for the player target to become ready. Repairs/rebinds are bounded, and the return-to-duty notice waits for target readiness.

The same actor remains, with the existing three-second revive within 2.5 m and death protection. There is no new treatment animation or automatic replacement. If the partner still stops, use **Log partner AI diagnostics** in CET and send that line.

### Backup arrival

Backup is **independent of scanner dispatch locations**. It now drives to the fixed world position where assistance was requested, using a drive-to-point command instead of following the player/vehicle. Moving afterward does not move that destination.

Within 28 m, the drive command is stopped and native braking is applied only to the owned backup car. The crew remain seated while it brakes. Exit is requested after speed falls below 0.7 and the stop phase has lasted 0.5 seconds. Stopping over 45 m away or failing to stop within 10 seconds aborts and cleans up the response.

One car/two officers, the secondary trunk action beside stash, the optional unbound CET key, one active-unit reservation, 150-m/three-second departure rearm and duty/load cleanup remain.

### Install and test

Exit the game completely and extract the entire ZIP into the game folder containing bin and r6, replacing all mod files. Restart. No new files or dependencies were added compared with v0.6a; both native systems use interface version 12.

1. Start a shift, revive the partner, walk away and enter a stopped car. Check that the same actor follows and boards. **Test: down partner** remains in CET.
2. Request backup from your owned police Hella's trunk beside a clear road. Stay at the request point and check braking, stop and crew exit. Also test with no scanner dispatch active.
3. A second request should remain blocked. Move at least 150 m from the request scene, car and officers for three seconds, then check rearm.
4. Report the **Partner AI** diagnostics or **Backup** log/status if something remains wrong.

### Requirements and retained features

Cyberpunk 2077 **2.5**, matching **CET**, **Codeware 1.21.4**, **RED4ext 1.31.0+**, **TweakXL** and compatible **redscript**. No additional dependency or required input binding.

Terminal duty, bonus receipts, scanner dispatch, marker/HUD, partner boarding, vehicle-bound chatter and wanted termination remain. The GPS line still uses the map open/close workaround when necessary. Dispatch audio and chatter volume are unchanged.

### Validation and limits

All eight Lua modules parse in LuaJIT. Redscript checks pass with zero warnings/errors against source-derived contracts, not the actual game script cache. Authored support/recovery helpers and actual CET modules execute in scenarios for active-but-downed AI, companion-effect cleanup, canonical role/target restoration, resumed boarding, bounded failures, fixed backup destination, braking on moving arrival, no moving-car exit, stopping timeout and prior duty/bonus/dispatch/cleanup regressions.

Native AI, physics, mounting, audio and rendered UI are mocked. These checks verify control flow and API use, not actual in-game movement or animations. Clear roadside tests remain necessary: spawn positions use character navmesh, not a verified traffic-lane placement API.

### Rollback

[Download v0.6a](https://github.com/jonathankj2000-cpu/NCPD-Patrol-Officer/raw/refs/heads/main/releases/NCPD_Patrol_v0.6a_Revive_Backup_Car_TEST.zip). Exit the game and reinstall that complete ZIP. No added files need removal.

### API references

- [Follower role initialization and companion-defeat cleanup](https://github.com/In-Question/MOD_Development_Reference/blob/main/DecompiledGameScripts/cyberpunk/ai/roles/aiRole.swift)
- [Canonical AI role change and companion target](https://github.com/In-Question/MOD_Development_Reference/blob/main/DecompiledGameScripts/core/components/aiComponent.swift)
- [Puppet life/activity and recovery](https://github.com/In-Question/MOD_Development_Reference/blob/main/DecompiledGameScripts/cyberpunk/puppet/scriptedPuppet.swift)
- [Native downed-signal API](https://github.com/In-Question/MOD_Development_Reference/blob/main/Definitions/Game_Definitions/classes/AISignalHandlerComponent.lua)
- [Native drive-to-point command](https://github.com/In-Question/MOD_Development_Reference/blob/main/Definitions/Game_Definitions/classes/AIVehicleDriveToPointAutonomousCommand.lua)
- [Native vehicle braking](https://github.com/In-Question/MOD_Development_Reference/blob/main/Definitions/Game_Definitions/classes/vehicleBaseObject.lua)

Archive SHA-256: `ec3491915fee818e98c51862a7811bdb1ab9221dfc70da65bb45c50caa14bece`
