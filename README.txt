NCPD PATROL v0.4a - TERMINAL DUTY / SCANNER BONUS / VEHICLE BOARDING
=================================================================
TEST BUILD: offline checks passed; this update still needs an in-game test.

INSTALL / UPDATE FROM v0.3b
1. Exit Cyberpunk 2077 completely.
2. Extract the installation ZIP into the game directory containing bin and r6.
3. Replace the NCPDPatrol Lua files and install the new redscript and YAML files.
4. Start the game and load a save.

REQUIREMENTS FOR CYBERPUNK 2077 2.5
 - Cyber Engine Tweaks 1.38.0+ with support for game patch 2.5.
 - Codeware 1.21.4 and RED4ext 1.31.0+.
 - redscript compatible with patch 2.5 (Codeware specifies 0.5.32+).
 - TweakXL, now also used for the terminal interaction choice records.

START / END SHIFT IN THE WORLD
Look at an available, ordinary Fast Travel terminal. Its interaction choices
should include the existing Fast Travel option and Start Shift or End Shift.
Selecting Start Shift calls the same NCPD officer model as v0.3b.
Selecting End Shift dismisses the active or pending partner and shows a summary.
Metro gates and unavailable/disabled Fast Travel interactions are excluded.
The existing CET panel and duty hotkey remain available for troubleshooting.

VEHICLE BOARDING
When you get into a stopped vehicle, your partner is explicitly instructed to
walk to a free passenger seat and enter with an animation. Periodic on-foot
follow commands are suppressed during approach and while seated.
Front-right is preferred, then rear-right, then rear-left. The driver seat is
never assigned and occupied seats are skipped. A moving car must stop before
a new boarding command is issued. Vehicle entry is paused during combat.
Getting out cancels a pending approach or asks a seated partner to get out.
There is no instant mounting or failsafe teleport. A blocked door or missing
navmesh can still prevent entry. Three attempts are made, 20 seconds apart;
exit and re-enter the vehicle to start a new attempt if boarding stalls.

SCANNER BONUS
 - EUR$1000 extra for each eligible NCPD combat activity completed on duty.
 - Coverage: Codeware's NCPD combat registry (Assault in Progress and Suspected
   Organized Crime Activity). Reported Crime follow-ups are not covered.
 - A baseline is taken when the scanner system is ready. Already completed
   activities do not receive retrospective bonuses.
 - Completion uses the activity's actual completed state, including any evidence
   collection needed by the game. No enemy kill counting is used.
 - Money is added only after a successful inventory transaction. Paid activity
   IDs are saved in the same save as the money and prevent duplicate payouts.
 - Each activity ID pays once per playthrough/save timeline, even if another
   mod restarts the activity.
 - The end-of-shift message reports paid activity count and total patrol bonus.
 - Duty resets to OFF on loading a save. The paid activity ledger is retained.

QUICK IN-GAME CHECK
1. Confirm Fast Travel and Start Shift are both visible at an ordinary terminal.
2. Start Shift; allow the officer to appear and check that the choice changes.
3. With the partner 5-10 metres away, enter a parked Hella and wait for him to
   approach the passenger door. Test getting out and entering another vehicle.
4. Complete an eligible scanner activity and check for the extra EUR$1000 message.
5. End Shift at a terminal; check the summary and partner cleanup.
6. Load a save and start another shift; old completed activities must not pay again.

VALIDATION / LIMITS
Lua modules passed LuaJIT syntax and mocked lifecycle/vehicle tests. The authored
reward class passed completion, payment retry and save/session scenarios through
a test-only syntax adapter with mocked game native calls. redscript 1.0.1 passed
syntax/type checks against source-derived API contracts. These checks do not use
your actual Cyberpunk 2.5 script cache and cannot verify live interaction prompts,
pathfinding, animations or full scanner coverage. This build is not in-game
verified. The earlier v0.3b installation ZIP remains in the GitHub releases folder.

RETURN TO v0.3b
Exit the game. Remove r6/scripts/NCPDPatrol and
r6/tweaks/NCPDPatrol_Interactions.yaml, then reinstall the v0.3b ZIP.
The original Police Hella tweak remains in place.
