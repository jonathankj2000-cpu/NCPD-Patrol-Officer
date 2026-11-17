NCPD PATROL v0.8b - TRUNK PATROL MENU TEST
========================================
COMPILER FIX
The timer now returns CeilF directly. CeilF returns Int32 in the game; the
extra Cast<Int32> in v0.8a is invalid. The previous local API contract had
incorrectly declared CeilF as returning Float. The corrected contract rejects
the old expression and accepts the new getter. Both supplied game-compiler logs report this exact error at TrunkSystem line 87.
No other gameplay logic changed.

Trunk features: tap the trunk's secondary interaction (normally R) for
backup, or hold it for about 0.5 seconds to open a native patrol choice list.
The user confirmed v0.7f arrest payments and the lying handcuff loop work.
The arrest code and compiled archive in this build are byte-for-byte unchanged.

INSTALL AND FIRST TEST
1. Exit the game. Extract the ENTIRE ZIP into the Cyberpunk 2077 directory
   containing bin, r6 and archive, replacing existing mod files. Restart;
   CET announces v0.8b. Main/support interfaces remain 17; arrest interface 5;
   the new independent trunk bridge is version 1. No new runtime dependency.
2. Start a shift at a Fast Travel terminal. Approach the stash interaction at
   your owned police car's trunk while on foot. The vanilla stash remains F.
3. Tap and release R: one backup request. Hold R for at least half a second:
   Patrol Menu, with no backup request from that same press. If the game's
   interaction callback arrives on release, the menu opens on release instead.
   The mod observes the native secondary action, so remapped bindings are used.
4. Scroll the native choice list and select with F (your primary interaction).
   R closes the menu. Releasing the opening hold must leave the menu open.
   Selecting a choice also closes the menu and restores the stash/backup list.
   Walking away, mounting, game menus, wanted status or shift end close it.
5. Check each option below. Menu layout, native input/event dispatch and visible
   repair effects still need an in-game test. If a short tap or hold fails,
   report the displayed notification and the CET Patrol menu lines.

PATROL MENU
- Set BUSY / Set AVAILABLE: Busy pauses NEW AUTOMATIC dispatch assignments.
  Your current assignment, its marker, objective, arrival/completion monitoring
  and scanner payout continue. Manually requesting a new call still works.
  Available resumes the timer; the existing CET automatic-dispatch preference
  remains separate. A new shift starts Available.
- Request vehicle repair (10 s): one free repair after 10 seconds of active
  gameplay, with request/completion notifications. Game menus pause the timer.
  The target is the exact car whose trunk you used; mounting or moving away
  does not transfer the repair to another car. Repeating the request neither
  stacks repairs nor restarts the timer. Health, deformation, glass, tire and
  damage-effect resets use the native vehicle APIs. It does not replace the
  vehicle or resurrect a destroyed car. Vehicle loss, shift end, wanted status
  and loading cancel the pending service. CET shows remaining seconds too.
- Request new partner: deletes only this mod's recorded partner and calls a
  fresh one. A failed/rejected deletion retains the old ID and blocks a new
  spawn. Existing following, boarding, combat and revive behavior are retained.
- Cancel dispatch: clears the current dispatch marker and HUD objective without
  altering or completing the vanilla scanner activity. Sends cancellation notice.
- Request new dispatch: cancels the current assignment, then tries another
  existing eligible scanner. The previous assignment stays excluded this shift.
  Cleanup failure prevents replacement. The existing 1/1.5/2 km search applies;
  no available alternative means no new assignment. Works while Busy.
- Cop Stats: a 10-second notice shows recorded on-duty scanner completions in
  the current save and the next planned milestone: 10, 20, 40, 60, 80, 100,
  120, etc. This reads the existing persistent paid-scanner ledger; missions
  completed before monitoring was installed are unknown. Counts therefore
  represent scanner completions whose scanner bonus has been registered.
  Arrests remain separate. Progression rewards are PLANNED, not awarded yet.

RETAINED FEATURES
Fast Travel Start/End Shift; automatic NCPD partner; native revive; one capped
backup car/two officers; on-duty scanner bonuses and receipts; dispatch HUD,
marker and radio; vehicle-local chatter; wanted-level shift termination;
separate EUR$250 arrests and the confirmed infinite lying handcuff workspot.
No new hotkey is required. The optional existing CET backup binding still works.
GPS may still need opening/closing the map. No pursuit generation is added.

VALIDATION
All 11 Lua modules parse in LuaJIT. All 18 redscripts compile with zero warnings
or errors against source-derived API contracts, not the actual game cache.
Portable tests execute the authored trunk/input/repair/stats logic and actual
CET dispatch/partner/bridge modules with game/native boundaries mocked. They
cover multiple input/event orders, duplicate suppression, missing input failing
closed, menu scope/closing, Busy versus active/manual calls, repair timing,
exact vehicle selection, pause/cancel/duplicate guards, replacement failure,
read-only milestones and world/duty cleanup. Existing scanner/dispatch/radio,
partner/revive/boarding/backup/arrest regressions also pass.
These checks do not emulate native input delivery, choice-list rendering,
vehicle graphics/physics, real AI or native save loading. Test those in game.
Requirements remain game 2.5, matching CET, Codeware 1.21.4, RED4ext 1.31.1,
TweakXL and compatible redscript. Install all mod files together.

ROLLBACK TO v0.7f
Exit the game; remove these FOUR new files, then reinstall the full v0.7f ZIP:
  bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrol/trunk.lua
  r6/scripts/NCPDPatrol/NCPDPatrolTrunkSystem.reds
  r6/scripts/NCPDPatrol/NCPDPatrolTrunkInteractions.reds
  r6/scripts/NCPDPatrol/NCPDPatrolTrunkVehicle.reds
The v0.7f archive is identical. Earlier complete ZIPs remain on GitHub.
