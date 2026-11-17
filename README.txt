NCPD PATROL v0.6b - REVIVE AI / BACKUP ARRIVAL TEST
===============================================
Addresses two v0.6a reports: the revived partner stands still despite the success
notice, and backup cars drive past the player rather than stop and disembark.

PARTNER RECOVERY
The old success check only observed life/status activity. Native AI can still
have a downed signal, an unconscious high-level state or a separate companion
FollowerDefeated effect. v0.6b removes those companion effects, clears only downed
gate signals on our registered partner, restores senses/bump and requests the
same relaxed-state transition used by the game's recoverable defeat path.
The readiness check now includes those AI states. Follower restoration uses the
canonical AIHumanComponent.SetCurrentRole path, including follower sense type,
companion cache and role-change event. It no longer manually clears/re-attaches
the existing role during recovery. Follow and boarding wait for its player target.
Repairs/rebinds are bounded. The return-to-duty notice waits for target readiness;
a binding failure is reported rather than claimed as following.
The same partner is retained, with the existing 3-second / 2.5-m revive interaction
and death protection. No new treatment animation or automatic NPC replacement.
If still stuck: CET > Log partner AI diagnostics. Send the Partner AI line, which
includes aid state, high-level state, activity, downed signal, companion defeat
and follower target readiness.

BACKUP ARRIVAL
Backup is independent of scanner dispatch locations. It now receives a fixed
world-position drive command at the request location, not a follow command aimed
at a moving player/vehicle. The destination stays fixed if you move afterward.
Within 28 m, the drive command is stopped and only our backup car receives native
braking. The crew stay seated during braking. After the speed is below 0.7 and the
stop phase has lasted 0.5 seconds, animated exit is requested. A stop over 45 m
away or a failure to stop within 10 seconds aborts/cleans up the response.
One car/two officers, trunk action, optional unbound CET key, unit reservation,
150-m/3-second departure rearm and duty/load cleanup remain.

INSTALL / TEST
1. Exit the game completely. Extract the whole ZIP into the game folder containing
   bin and r6, overwriting all files. Restart; both native systems report version12.
2. Start a shift. Test revive, walk away and then enter a stopped car. Confirm
   the same partner follows and boards. CET Test: down partner remains available.
3. At a clear roadside location, request backup through the owned police Hella's
   trunk action. Stay near the request point. Check the car brakes, stops and the
   officers get out, including when no scanner dispatch is active.
4. Repeated requests must stay blocked. Travel over 150 m from the request scene,
   car and officers for three seconds to release the unit, then request again.
5. If a problem remains, send Partner AI diagnostics or the Backup status/log
   showing approach, braking, exit or failure. The arrival test is still in-game.

REQUIREMENTS / RETAINED
Cyberpunk 2077 2.5, matching CET, Codeware 1.21.4, RED4ext 1.31.0+, TweakXL and
compatible redscript. No new dependency or input binding is required. Stash keeps
its normal action; backup uses the secondary trunk choice (normally R here).
Terminal duty, scanner bonuses/receipts, dispatch, marker/HUD, vehicle chatter and
wanted termination remain. GPS still uses the map open/close workaround when
needed. Dispatch voice and chatter volume are unchanged.

VALIDATION / LIMITS
All eight Lua modules parse in LuaJIT. Redscript checks have zero warnings/errors
against source-derived contracts, not the actual game script cache. Authored
support and recovery helpers plus actual CET modules execute in scenarios for
active-but-downed AI, companion-effect cleanup, canonical role/target recovery,
resumed boarding, bounded failure handling, fixed backup destination, braking a
moving arrival, no moving-car exit, stopping timeout and prior regressions.
Native AI, physics, mounting, audio and rendered UI are mocked. This validates
control flow and API use; it cannot prove real movement, braking or animations.
Clear roadside locations are still needed: spawn positions use character navmesh,
not a verified traffic-lane placement API.

ROLLBACK
Exit the game and reinstall the complete v0.6a ZIP. No added files to remove.
