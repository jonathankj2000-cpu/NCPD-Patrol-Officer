NCPD PATROL v0.6a - PARTNER REVIVE / BACKUP CAR TEST
================================================
First implementation of partner aid and one backup patrol, built on v0.5e.

NORMAL IN-GAME CONTROLS
 - Start/end duty at a fast travel terminal as before.
 - On duty, approach the trunk of your owned police Hella. Request NCPD Backup
   appears beside the vanilla stash action. It inherits the terminal's secondary
   interaction binding (normally R in the user's setup). Stash keeps its action.
 - Approach a downed partner and select Revive Partner. Remain on foot within
   2.5 m for three seconds. The caption changes to Reviving Partner - stay close.
   Moving away or entering a vehicle interrupts treatment.
 - Optional key: CET Bindings > NCPD Patrol - Request backup. No default binding.
   Trunk interaction, CET button and optional key share the same unit limit.

PARTNER AID
Only the mod's registered partner receives immortal protection. At low health
(10% or less), or a defeated/unconscious state, the partner is downed and protected
from further damage. Follow/boarding commands pause. The body's choices become
Revive Partner only for this registered partner; other NPCs retain vanilla logic.
Revive restores the same actor to full health, removes defeat/unconscious effects
and requests native recovery. Following resumes after recovery is observed. If
recovery fails, another attempt is allowed. No replacement NPC is spawned.
This version has no V treatment animation; it uses a timed interaction and native
down/get-up behaviour. An injured passenger remains protected until exiting;
the mod does not eject them from a moving vehicle.

BACKUP
One non-persistent NCPD Hella and two officers are created at a nearby approach
point. The crew are initially seated there, and the car receives a native traffic-
follow command. At low-speed arrival they use native unmount commands, move to
the scene and support/hold there.
Only one request/unit may be pending or active. Repeated inputs create no extra
vehicles/officers; duplicate feedback is limited. A wreck or dead crew still
consumes the scene's unit. For normal rearm, travel at least 150 m from the request
scene, backup car and both officers for three seconds. Their entities are deleted
before the reservation is released.
End Shift/criminal termination also cleans up. Partial deployment failures roll
back accepted IDs. Failed deletions retain the reservation and retry. Loading a
save forgets old-world IDs, including after off-duty cleanup failures, without
using them to delete anything in the new world. The player's car is preserved.

INSTALL / FIRST TEST
1. Exit the game completely. Extract the entire ZIP into the game folder
   containing bin and r6, replacing all mod files and the interaction YAML.
2. Include new backup.lua, officer_ai.lua, NCPDPatrolSupportSystem.reds and
   NCPDPatrolSupportInteractions.reds. Keep the existing radio callback files.
3. Start duty and use the trunk of your owned police Hella near a clear road.
   Check stash still works, request backup and observe car/crew arrival.
4. Try another request: it should be blocked. Travel over 150 m from the scene
   and unit for three seconds, then check another patrol becomes available.
5. For a quick aid test, CET has Test: down partner. Close CET, approach and use
   the world Revive Partner choice. Check interruption, recovery and following.
6. Test End Shift/wanted termination with a unit deployed. Report the exact
   Backup | or partner status and any redscript errors if something fails.

FIRST DRIVING TEST LIMIT
Use a clear roadside location. Spawn positions are projected to character navmesh;
this is not a verified traffic-lane spawn API. Tight alleys, interiors, obstacles
and off-road routing may fail. Actual driving, seating, exit animations, combat
and world prompts still need testing in Cyberpunk 2.5.

REQUIREMENTS / RETAINED
Cyberpunk 2077 2.5, matching CET, Codeware 1.21.4, RED4ext 1.31.0+, TweakXL and
compatible redscript. No additional dependency. Existing duty, bonus receipts,
dispatch, marker/HUD, boarding and chatter remain. Open/close the world map when
needed for the GPS line. Dispatch voice remains at v0.5e, including diagnostics;
repeat playback is still unresolved. No audio files or volume boost are included.

VALIDATION
All eight Lua modules parse in LuaJIT. Redscript checks pass with zero warnings
or errors against source-derived contracts, not the actual game script cache.
Authored support/interaction logic and actual CET modules run in scenarios for
same-actor recovery, menus, duplicate input, seating, vehicle commands, exits,
distance rearm, failures, cleanup retries and duty/load boundaries, plus prior
bonus/dispatch/boarding/radio regressions. Game natives, driving, mounting and
sound are mocked; these checks do not verify actual game playback or animations.

ROLLBACK
Exit the game. Remove NCPDPatrolSupportSystem.reds and
NCPDPatrolSupportInteractions.reds from r6/scripts/NCPDPatrol, plus backup.lua and
officer_ai.lua from the CET mod folder. Reinstall the complete v0.5e ZIP.
