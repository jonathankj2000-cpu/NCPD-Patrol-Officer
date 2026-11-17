# NCPD Patrol

## v0.6a: partner revive and one backup patrol

**[Download v0.6a](https://github.com/jonathankj2000-cpu/NCPD-Patrol-Officer/raw/refs/heads/main/releases/NCPD_Patrol_v0.6a_Revive_Backup_Car_TEST.zip)**

This first implementation adds aid for your spawned partner and a backup car with two officers. Normal use stays in the game: terminals for duty, the police-car trunk for backup and a body interaction for revive.

### In-game controls

- **Duty:** start/end shift at a fast travel terminal as before.
- **Backup:** on duty, approach the trunk of your owned police Hella and choose **Request NCPD Backup**, beside stash. It inherits the terminal's secondary interaction input, normally **R** in this setup. The vanilla stash action remains.
- **Revive:** approach your downed partner and choose **Revive Partner**. Remain on foot within **2.5 m for three seconds**. The caption changes to **Reviving Partner - stay close**. Moving away or entering a vehicle interrupts treatment.
- **Optional backup key:** choose a key in **CET Bindings > NCPD Patrol - Request backup**. No default key is assigned. The trunk, CET test button and key share the same unit limit.

### Partner aid

Only the mod's registered partner receives immortal protection. When critically injured on foot (10% health or less), defeated or unconscious, that partner is downed and protected from further damage. Follow and boarding commands pause. The partner's body choices become the revive interaction; other NPC interactions retain vanilla behaviour.

Revive restores **the same actor** to full health, removes defeat/unconscious effects and requests native recovery. Following resumes once recovery is observed. Failed recovery allows another attempt. An injured passenger remains protected until exiting; the mod does not eject them from a moving vehicle.

The first version uses a timed interaction and native down/get-up behaviour, with **no V treatment animation**. CET includes **Test: down partner** for convenient testing; normal aid uses the in-world prompt.

### Backup car

One non-persistent NCPD Hella and two officers are created at a nearby approach point. The crew are initially seated there, and the car receives a native traffic-follow command. At low-speed arrival they use native unmount commands, move to the scene and support/hold there.

Only one unit may be pending or active. Repeated inputs cannot create another patrol, and duplicate feedback is limited. A wreck or dead crew still consumes the scene's unit. For normal rearm, travel at least **150 m from the request scene, car and both officers for three seconds**. Their entities are deleted before another request becomes available.

End Shift and criminal termination also clean up. Partial failures roll back accepted IDs. Failed deletions retain the reservation and retry. Loading another save forgets old-world IDs, including after off-duty cleanup failures, without deleting anything in the new world. The player's vehicle and ambient NPCs are outside this cleanup.

### First driving test

**Test beside a clear road.** The approach point is projected to character navmesh; this is not a verified traffic-lane spawn API. Tight alleys, interiors, obstacles and off-road routing may fail. Actual seating, driving, exit animations, combat and world prompts require testing in Cyberpunk 2.5.

### Installation

Requirements remain Cyberpunk 2077 **2.5**, matching **CET**, **Codeware 1.21.4**, **RED4ext 1.31.0+**, **TweakXL** and compatible **redscript**. No new dependency.

Exit the game completely and extract the entire ZIP into the game folder containing bin and r6, replacing all mod files and the interaction YAML. Include the new **backup.lua**, **officer_ai.lua**, **NCPDPatrolSupportSystem.reds** and **NCPDPatrolSupportInteractions.reds**. Keep the existing radio callback files.

Test stash/backup from the trunk, repeated-request rejection, departure/rearm, partner revive and End Shift cleanup. If something fails, report the exact **Backup** or partner status and any redscript errors.

### Retained behaviour

Existing terminal duty, bonus receipts, dispatch, marker/HUD, partner boarding and chatter remain. Open/close the world map when needed for the GPS line. Dispatch voice remains at v0.5e with its diagnostics; repeat audible playback is still unresolved. This build adds no audio files or chatter volume change.

### Validation

All eight Lua modules parse in LuaJIT. Redscript checks pass with zero warnings or errors against source-derived contracts, not the actual game script cache. Authored support/interaction logic and actual CET modules execute in scenarios for same-actor recovery, menus, duplicate input, seating, vehicle commands, exits, distance rearm, partial failures, cleanup retries and duty/load boundaries, plus prior bonus/dispatch/boarding/radio regressions.

Native game calls, driving, mounting and sound are mocked in these checks. Real game behaviour remains to be tested.

### Previous version and rollback

[v0.5e: radio state/replay test](https://github.com/jonathankj2000-cpu/NCPD-Patrol-Officer/raw/refs/heads/main/releases/NCPD_Patrol_v0.5e_Radio_State_Replay_TEST.zip)

To return to v0.5e, exit the game, remove NCPDPatrolSupportSystem.reds and NCPDPatrolSupportInteractions.reds from r6/scripts/NCPDPatrol, plus backup.lua and officer_ai.lua from the CET mod folder, then reinstall its complete ZIP.

### API references

- [Codeware 1.21.4 dynamic entity ownership and cleanup API](https://github.com/psiberx/cp2077-codeware/blob/v1.21.4/scripts/World/DynamicEntitySystem.reds)
- [Game puppet interactions and recovery](https://github.com/In-Question/MOD_Development_Reference/blob/main/DecompiledGameScripts/cyberpunk/puppet/scriptedPuppet.swift)
- [NPC defeat/recovery and ragdoll rules](https://github.com/In-Question/MOD_Development_Reference/blob/main/DecompiledGameScripts/cyberpunk/NPC/NPCPuppet.swift)
- [Vehicle trunk actions](https://github.com/In-Question/MOD_Development_Reference/blob/main/DecompiledGameScripts/core/components/scriptComponents/vehicleComponentPS.swift)
- [Native vehicle-follow command](https://github.com/In-Question/MOD_Development_Reference/blob/main/Definitions/Game_Definitions/classes/AIVehicleFollowCommand.lua)
- [Game driving handlers](https://github.com/In-Question/MOD_Development_Reference/blob/main/DecompiledGameScripts/cyberpunk/ai/commands/aiDriveCommandHandler.swift)

Archive SHA-256: `b6fd7f56a687bf3410e51314347668e819d33b24fa7acca108d1466ab9e81802`
