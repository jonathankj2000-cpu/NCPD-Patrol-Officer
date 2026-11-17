NCPD PATROL v0.8c - NATIVE TRUNK TAP / HOLD TEST
==============================================
Fix for v0.8b's "Trunk input not received" message. The vanilla input context
only sends BUTTON_RELEASED for Choice2; the old listener waited for a press
that this action never supplies. InteractionBase.action is also String, not
CName. This build removes the raw listener and custom half-second timer.
Two native choices now use Choice2 (backup) and Choice2_Hold (Patrol Menu).
The game supplies the separate hold icon, timing and input arbitration.
The v0.8b repair-countdown compiler fix remains in place.

INSTALL AND FIRST TEST
1. Exit the game completely. Extract the ENTIRE ZIP into the game directory
   containing bin, r6 and archive, replacing all existing mod files. Restart;
   CET announces v0.8c. Main/support interfaces remain 17, arrests 5; the trunk
   bridge is now 2. No manual file removal or new runtime dependency is needed.
2. Start a shift. Approach your owned police car's trunk while on foot. Expect
   the vanilla stash plus TWO separate native actions: Request NCPD Backup
   on a short R press, and Patrol Menu with the hold-R icon. Remapping follows
   the game's secondary-interaction binding; no custom hotkey is required.
3. Tap and release R: request one backup patrol. Hold R until the native hold
   indicator completes: open the patrol choice list without requesting backup.
   Vanilla Choice2_Hold uses about 0.3 seconds; the mod does not edit this timeout.
4. Scroll the list and use F to select. A fresh R closes the menu. The opening
   hold's release is arbitrated by the native interaction system. Check that
   the menu stays open on release and that no backup is sent by that hold.
   Closing/selecting restores stash and both trunk entry choices. Walking away,
   mounting, game menus, wanted status or shift end close it too.
5. Test the physical hold/release and icons in game. Local tests execute native
   entry callbacks and PS wrappers but do not emulate the actual input manager
   or rendered UI. The removed "Trunk input not received" path no longer exists.

PATROL MENU (GAMEPLAY LOGIC RETAINED)
- Available / Busy: Busy pauses new automatic dispatch assignments. The active
  assignment, its marker, objective, completion monitoring and bonus continue.
  Manual requests remain available. The CET automatic-calls preference remains
  separate; a new shift starts Available.
- Request vehicle repair (10 s): one free repair after ten gameplay seconds.
  Menus pause the timer. It repairs the exact requested car, including if you
  enter or move away. Duplicate requests neither stack nor reset the timer.
  Vehicle loss/destruction, wanted status, shift end or loading cancel it.
  The native health, tire, body/glass and damage-effect wrapper is unchanged.
- Request new partner: replace only the recorded mod-created partner. Failed
  deletion retains the old ID and prevents an extra spawn.
- Cancel dispatch: clear the mod marker/objective without completing/changing
  the vanilla activity.
- Request new dispatch: cancel the assignment, then try another eligible
  scanner within the existing 1/1.5/2 km search tiers. Cleanup failure blocks
  replacement; no alternative means no new assignment. Works while Busy.
- Cop Stats: recorded on-duty paid-scanner completions and the next milestone:
  10, 20, 40, 60, 80, 100, 120, etc. Historical completions before monitoring
  are unknown. Progression rewards remain planned, not awarded. Arrests are
  counted/paid separately.

RETAINED FEATURES
Fast Travel duty controls; partner following/combat/boarding/revive; one capped
backup car/two officers; scanner bonuses/receipts; dispatch HUD, marker/radio;
vehicle-local chatter; wanted termination; independent EUR$250 lying arrests.
Arrest code/YAML/archive, aid wrappers, dispatch/partner/backup controllers,
main/support systems, repair wrapper/timer and stats/payment logic are verified
unchanged from v0.8b. GPS may still require opening/closing the map.

VALIDATION
All 11 Lua modules parse. All 18 redscripts compile with zero warnings/errors
against source-derived API contracts, not the actual game cache. Tests execute
both real trunk PS wrappers, native backup/hold/menu entry callbacks, caption
records, stash/menu restoration, native release-only event contract, range/
ownership/pause/duty/life guards and existing repair/stats/dispatch/partner logic.
The original invalid CeilF cast remains rejected by a separate type regression.
Existing scanner, radio, revive, boarding, backup and arrest regressions pass.
Native input arbitration, rendered icons/choice list, AI, vehicle graphics and
native save loading still require in-game validation. No new input XML is
installed. No Input Loader dependency is introduced.
Requirements remain game 2.5, matching CET, Codeware 1.21.4, RED4ext 1.31.1,
TweakXL and compatible redscript.

ROLLBACK
Reinstall the full v0.8b ZIP to return to the previous trunk test. For the
confirmed v0.7f arrest build: remove trunk.lua plus NCPDPatrolTrunkSystem.reds,
NCPDPatrolTrunkInteractions.reds and NCPDPatrolTrunkVehicle.reds, then reinstall
its entire ZIP. The arrest archive is identical. Older ZIPs remain on GitHub.
