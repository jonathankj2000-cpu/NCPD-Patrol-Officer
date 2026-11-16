# NCPD Patrol

## v0.5a dispatch test

**[Download v0.5a: scanner dispatch with manual CET test button](https://github.com/jonathankj2000-cpu/NCPD-Patrol-Officer/raw/refs/heads/main/releases/NCPD_Patrol_v0.5a_Scanner_Dispatch_TEST.zip)**

Based on **v0.4c**, whose scanner bonus and receipt have now been confirmed in game by the user. The new dispatch, navigation marker and HUD display still require an in-game test.

### Dispatch behaviour

Start Shift, then wait for a call or press **Request dispatch now** in the CET panel. One active assignment is selected from active, unfinished Assault in Progress or Suspected Organized Crime scanner markers. Incidents within 2.5 km are preferred; the wider available pool is used if necessary. Duplicate journal IDs, completed/paid activities, inactive markers and assignments cancelled during the current shift are excluded.

The call displays a notification, places a **Custom Position waypoint** at the incident, and shows an in-game HUD objective with distance. Within 60 m, the objective changes to **Resolve the incident and collect evidence**. Completion uses the same live/saved POI phase as the working bonus monitor. Arrival, kills and streaming out do not themselves finish the dispatch.

The first automatic call waits **30–60 seconds**. After completion or cancellation, the next call waits **60–120 seconds**. Automatic countdowns pause in menus and combat. If no eligible marker is available, automatic mode retries after 30 seconds. A manual request bypasses the timer. It cannot replace an existing active assignment.

The existing **EUR$1000 patrol bonus and receipt** handle payment. Dispatch grants no second reward. Other eligible scanner activities still pay their patrol bonus while on duty. If the assigned incident completes but its payment fails, the bonus monitor can retry after the dispatch clears.

### CET controls

- **Request dispatch now** — immediate test request during an active shift.
- **Cancel active dispatch** — clears the assignment and its marker. The original scanner activity remains available; its ID is excluded from further dispatches during that shift.
- **Pause / Resume automatic dispatch** — manual requests remain available.
- Dispatch state, completed count, next-call timer and HUD attachment status are shown. Assignment logs include the target POI hash.

End Shift clears dispatch and removes its tagged markers. Loading a save resets duty and assignment state. Cleanup identifies owned markers by script-data type and uses their current IDs, avoiding a stale ID from the previous loaded world.

### Install and test

Requires Cyberpunk 2077 **2.5**, matching **CET 1.38.0+**, **Codeware 1.21.4**, **RED4ext 1.31.0+**, **TweakXL**, and compatible **redscript** (Codeware specifies 0.5.32+). This prototype adds no new dependency.

1. Exit the game completely and extract the ZIP into the game folder containing `bin` and `r6`, replacing the NCPDPatrol files. Include both new Lua files and `NCPDPatrolDispatchMappinData.reds`.
2. Start a shift at an ordinary Fast Travel terminal or in CET. Open **DISPATCH → Request dispatch now**, then close the overlay.
3. Check the notification, waypoint and HUD objective. Travel to the location and check the objective changes on arrival.
4. Complete the scanner, including evidence collection. Confirm the assignment clears, its marker disappears, and the existing **NCPD BONUS PAID** receipt appears once.
5. Test another manual request, cancellation, End Shift and save loading. Test automatic mode outside menus/combat.

### Navigation and HUD scope

The automatic waypoint is a registered Custom Position marker. **The normal road GPS line is not verified**; direct manual-map tracking is not exposed by the API used here. Actual navigation behaviour must be checked in game.

The objective is a small text display attached to the quest tracker's HUD parent, positioned at the top right. It is separate from a journal quest. Its placement and visibility with the user's HUD settings need verification. HUD setup errors appear in CET; dispatch notification and waypoint operation can continue independently.

Assignments select existing scanner encounters. They do not regenerate completed encounters or spawn new enemies/evidence. Reported Crime follow-ups are excluded. Available assignments depend on the live mappin pool and shrink as existing scanners are completed.

### Retained patrol features

Fast Travel terminal Start/End Shift, automatic partner spawn, explicit passenger boarding with bounded retries, vehicle exit and cleanup, Police Hella/uniform controls, and the v0.4c scanner bonus/receipt remain available. The planned partner revive feature is not included in this dispatch build.

### Validation

- All Lua modules load with LuaJIT. Actual module scenarios exercise manual/automatic requests, nearby selection, duplicate/cancelled IDs, HUD lifecycle, menus/combat, arrival, correct-incident completion, cancellation, failed waypoint registration and recovery, and End Shift/load cleanup.
- The authored redscript class is exercised through a test-only syntax adapter with mocked game natives and a CET array-conversion bridge. Tests verify inactive/non-NCPD/completed exclusions, saved completion after stream-out, no completion from stream-out alone, payment retry after dispatch resolution, no duplicate reward, and cleanup of tagged markers without deleting foreign markers sharing an old ID.
- Existing partner/boarding, terminal request, reward, receipt and save/session regressions pass.
- redscript 1.0.1 reports no syntax/type errors against independently declared game/Codeware contracts. This is not compilation against the actual Cyberpunk 2.5 script cache. Native HUD rendering, marker presentation, script-data restoration and GPS navigation require in-game verification.

### Previous versions

- [v0.4c: confirmed scanner bonus/receipt](https://github.com/jonathankj2000-cpu/NCPD-Patrol-Officer/raw/refs/heads/main/releases/NCPD_Patrol_v0.4c_Scanner_Monitor_Fix_TEST.zip)
- [v0.4b: captions and receipt](https://github.com/jonathankj2000-cpu/NCPD-Patrol-Officer/raw/refs/heads/main/releases/NCPD_Patrol_v0.4b_Captions_Bonus_Receipt_TEST.zip)
- [v0.3b: auto-spawn partner](https://github.com/jonathankj2000-cpu/NCPD-Patrol-Officer/raw/refs/heads/main/releases/NCPD_Patrol_v0.3b_Auto_Shift_Partner.zip)

To return to v0.4c, end the shift, exit the game, remove `dispatch.lua`, `dispatch_hud.lua` and `NCPDPatrolDispatchMappinData.reds`, then reinstall its complete ZIP.

### API references

- [Codeware mappin enumeration](https://github.com/psiberx/cp2077-codeware/blob/v1.21.4/scripts/World/MappinSystem.reds)
- [Native mappin system definitions](https://github.com/In-Question/MOD_Development_Reference/blob/main/Definitions/Game_Definitions/classes/gamemappinsMappinSystem.lua)
- [Native quest tracker lifecycle](https://github.com/In-Question/MOD_Development_Reference/blob/main/DecompiledGameScripts/cyberpunk/UI/quests/quest_tracker.swift)
- [Native ink text API](https://github.com/In-Question/MOD_Development_Reference/blob/main/DecompiledGameScripts/core/ui/baseWidgets/textWidget.swift)

Installation ZIP SHA-256: `1dfbc4b8ca5e474ffa584b7eeb6e5b20fef5c8c8e7b037d35d1e2dd4c781ddca`
