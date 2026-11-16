NCPD PATROL v0.5a - SCANNER DISPATCH TEST
======================================
Built on v0.4c, whose scanner bonus and receipt the user confirmed in game.
The new dispatch, waypoint and HUD display still require in-game verification.

INSTALL / UPDATE
1. Exit Cyberpunk 2077 completely.
2. Extract the complete ZIP into the game folder containing bin and r6.
3. Replace the NCPDPatrol files. Include both new Lua files and the new
   NCPDPatrolDispatchMappinData.reds script; do not update only init.lua.
4. Start the game, load a save and start a shift.

REQUIREMENTS
Cyberpunk 2077 2.5, a matching CET version (1.38.0+), Codeware 1.21.4,
RED4ext 1.31.0+, TweakXL and a matching redscript (Codeware specifies 0.5.32+).
No additional dependency is introduced by this dispatch prototype.

DISPATCH
 - One active assignment at a time, selected from existing active, unfinished
   Assault in Progress / Suspected Organized Crime Activity POI markers.
 - Incidents within 2.5 km are preferred; otherwise the available wider pool is
   used. Duplicate journal IDs and assignments cancelled this shift are excluded.
 - Selection creates an NCPD dispatch notification and a Custom Position waypoint
   at the target. An in-game text display shows the assignment and distance.
 - Within 60 m, the objective becomes Resolve the incident and collect evidence.
 - Arrival and kills do not complete the assignment. Completion uses the same
   saved/live POI phase as the working v0.4c bonus monitor.
 - Streaming out alone does not complete a dispatch. Completion can still be
   detected from the saved phase after the original scanner marker disappears.
 - The existing EUR$1000 bonus/receipt handles payment. Dispatch adds no second
   reward. Other eligible scanners still receive their normal patrol bonus.
 - First automatic call: 30-60 seconds. After completion/cancellation: 60-120
   seconds. Automatic countdowns pause in menus and combat. Only one call is active.
 - If no eligible marker is available, automatic mode retries after 30 seconds.
 - End Shift cancels the assignment and removes tagged dispatch waypoints.
 - Loading a save resets duty and dispatch. Tagged markers are cleaned using
   current native IDs; IDs from the previous loaded world are not reused.

CET TEST CONTROLS
Open the NCPD Patrol window and find DISPATCH.
 - Request dispatch now: bypasses the automatic wait. Requires an active shift.
 - Cancel active dispatch: clears the assignment and its waypoint. It does not
   complete, fail or reset the original scanner activity. That ID will not be
   selected again during the same shift.
 - Pause / Resume automatic dispatch: manual requests remain available.
 - State, completed count, automatic countdown and HUD attachment state are shown.
 - CET logs dispatch assignment (including POI hash), arrival, completion and errors.

QUICK TEST
1. Start a shift. Click Request dispatch now in CET; close the overlay.
2. Check the dispatch notification, waypoint on the map/world, and HUD objective.
3. Travel to the marker. Within 60 m the objective should change to resolving it.
4. Finish the scanner, including evidence collection. Confirm the dispatch clears,
   its waypoint disappears, and the existing NCPD BONUS PAID receipt appears.
5. Request another assignment. Test cancellation, End Shift and loading a save.
6. To test automatic mode, leave it enabled while outside menus and combat.

NAVIGATION / HUD LIMITS
The prototype registers a visible Custom Position waypoint automatically. The
normal road GPS line is not claimed as verified: direct manual-map tracking is
not exposed by the API used here. Check actual navigation behaviour in game.
The new text display attaches to the quest tracker's HUD parent and is placed at
the top right. It is separate from journal quests. Its position/readability with
your HUD settings needs verification. Any HUD setup error appears in CET, while
the dispatch notification and waypoint can continue to work.
This version chooses existing scanner encounters; it does not reset completed
encounters or generate new enemies/evidence. Reported Crime follow-ups are excluded.

VALIDATION
All Lua modules pass LuaJIT loading. The redscript files pass syntax/type checks
with redscript 1.0.1 against source-derived game/Codeware API contracts, not the
actual Cyberpunk 2.5 script cache. The authored reward/helper class is exercised
through a test-only syntax adapter with mocked native calls. Actual Lua modules
are tested against that class with a CET array-conversion bridge and native mocks.
Scenarios cover scanner filtering, nearby preference, duplicate/cancelled IDs,
manual and automatic requests, menus/combat, arrival, stream-out, correct target
completion, payment retries/no duplicate payment, HUD lifecycle, failed waypoint
registration, End Shift and tagged cleanup after a load. The previous partner,
vehicle boarding, terminal requests, bonus and receipt regression checks pass.
These checks cannot verify real HUD placement, waypoint rendering or GPS routes.

ROLLBACK TO v0.4c
Exit the game, remove dispatch.lua, dispatch_hud.lua and
r6/scripts/NCPDPatrol/NCPDPatrolDispatchMappinData.reds, then reinstall the complete
v0.4c ZIP. Ending the shift before rollback removes an active dispatch waypoint.
