NCPD PATROL v0.5c - LOCAL DISPATCH / DUTY RULES / VEHICLE RADIO
============================================================
Built on the user's confirmed scanner bonus, receipt and dispatch setup.
New GPS refresh and vehicle audio still need in-game verification.

INSTALL
Exit the game completely. Extract the complete ZIP into the game directory
containing bin and r6 and replace all NCPDPatrol files. Include the new
vehicle_radio.lua and updated redscript files. Restart and load a save.
Requirements match v0.5b: Cyberpunk 2077 2.5, matching CET, Codeware 1.21.4,
RED4ext 1.31.0+, TweakXL and compatible redscript. No new dependency.

DISPATCH RANGE
 - Search within 1000 m first, then 1500 m, then 2000 m.
 - Select randomly from the first non-empty tier. Distant markers outside 2 km
   never bypass the limit, even if monitoring knows about them.
 - An empty search waits 30 seconds before retrying. Request dispatch now in
   CET still bypasses the wait. Distance is straight-line distance, not road length.
 - CET assignment logs include distance and the selected search radius.

GPS REFRESH
 - The owned dispatch waypoint is reactivated and its position updated.
 - The UI tracked-mappin value and current menu-state signals are refreshed,
   without opening a menu or changing menu/time-dilation state.
 - Automatic refresh attempts are bounded to three, including initial placement.
 - CET offers Refresh dispatch GPS plus the native tracking-flag diagnostic.
 - These changes try to address GPS appearing only after opening/closing the map.
   Offline tests verify the update calls and bounds, not actual GPS rendering.
   Test the line before opening the map. If it still waits for the map, report
   Navigation from CET before and after Refresh dispatch GPS and map open/close.

DISPATCH VOICE
The existing nc_heat_1_start line, confirmed suitable by the user, accompanies
new dispatch notices. Mute dispatch voice and the voice preview remain in CET.
On-scene voice remains unset pending the user's own briefing audio files.
The short alert and longer 8-second dispatch/resolved notices are retained.

VEHICLE CHATTER
 - Uses the existing radio_car_police_npc sound event with the vehicle entity ID
   as its audio object. It does not play ambient chatter on the player emitter.
 - Requires ON DUTY, an owned police vehicle, and the player mounted in that car.
 - Eligibility uses IsPlayerVehicle and either the known patrol Hella record or
   a player audio-resource name containing police. Custom vehicles with different
   audio metadata may need explicit support.
 - The controller polls every 0.25 seconds. Exiting, switching cars, muting,
   ending a shift or criminal termination stops the event on that same vehicle.
 - A given occupied car starts one event; it is not restarted every frame.
 - CET has Mute/Enable vehicle chatter and a source/entity diagnostic.
 - Native dispatch-call voice is separate from this ambient vehicle event.
 - Actual audibility and spatial playback of the native NPC event need an
   in-game check. The event name comes from the game's sound-event catalog.

CRIMINAL ACTIVITY
 - Wanted heat is read from PreventionSystem.GetHeatStage().
 - Becoming wanted during a shift immediately disables native duty/bonus
   eligibility when detected and shows an eight-second priority notification:
   NCPD: Shift terminated due to criminal activity.
 - CET checks every 0.25 seconds; the reward tick checks again before paying.
 - Dispatch waypoints and vehicle chatter are cleared. CET dismisses the live
   spawned partner. Loading a save still forgets old IDs instead of deleting them.
 - Start Shift is rejected while wanted, including requests from terminals.
 - Money already paid is retained. Pending earned receipts survive the priority
   termination message. Stale assignment/arrival messages are discarded.
 - Police wanted/chase state is not cleared by the mod.

IN-GAME CHECK
1. Start a shift and Request dispatch now. Check distance/radius in CET.
2. Check for a GPS route before opening the map. Try Refresh dispatch GPS if
   absent, then report the native tracking diagnostic and visible result.
3. Confirm the approved radio voice accompanies a new dispatch notice.
4. Enter your summoned police Hella. Listen for chatter; leave the vehicle and
   confirm it stops. Test a second owned police car, a civilian and an unowned car.
5. While on duty, gain a wanted star. Confirm the termination notification,
   partner dismissal, cleared dispatch, stopped chatter and OFF DUTY status.
6. Try starting a shift while wanted, then again after losing the wanted level.

VALIDATION
All six Lua modules pass LuaJIT loading. Redscript 1.0.1 syntax/type checks pass
against source-derived game/Codeware contracts, not the actual 2.5 script cache.
The authored native class is executed through a syntax adapter with mocked game
calls; actual Lua modules run against that class with a CET conversion bridge.
Scenarios cover radius tiers/cap, bounded GPS update signals, dispatch voice,
owned/mounted car eligibility, car-entity audio start/stop/switch/mute, wanted
reward cutoff, priority termination, saved receipt preservation, partner dismissal,
wanted start rejection and safe load reset, plus previous patrol regressions.
Live sound banks, 3D rendering and GPS output cannot be verified by these checks.

ROLLBACK
Exit the game, remove vehicle_radio.lua and reinstall the complete v0.5b ZIP.
The previous installation ZIPs remain available on GitHub.
