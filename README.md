# NCPD Patrol

## v0.5c: local dispatch, duty rules and vehicle chatter

**[Download v0.5c](https://github.com/jonathankj2000-cpu/NCPD-Patrol-Officer/raw/refs/heads/main/releases/NCPD_Patrol_v0.5c_Local_Dispatch_Duty_Radio_TEST.zip)**

Based on the user's confirmed scanner bonus, receipt and dispatch setup. GPS refresh and vehicle chatter remain changes requiring an in-game test.

### Dispatch distance

Assignments search within **1 km**, then **1.5 km**, then **2 km**, selecting from the first non-empty tier. The previous fallback to all known scanners is removed. If every tier is empty, automatic mode retries after 30 seconds. **Request dispatch now** still bypasses the wait. Distances are straight-line distances; the road route can be longer.

CET logs the selected radius and target distance. Eligibility still requires an active, unfinished Assault in Progress or Suspected Organized Crime POI, excluding paid/duplicate IDs and calls cancelled during the current shift.

### GPS update attempt

The tagged dispatch marker is reactivated and repositioned, and the UI tracked-mappin value and current menu-state signals are refreshed. No menu is opened and menu/time-dilation state is not changed. Refresh attempts are bounded to three, including initial placement. CET adds **Refresh dispatch GPS** and a native tracking-flag diagnostic.

This addresses the reported behaviour where the route appeared only after opening/closing the map. **Actual GPS-line rendering is not verified here.** Test the route before opening the map; if it still needs that workaround, report the navigation diagnostic before/after the refresh button and map open/close. A native tracking flag is diagnostic information, not proof that the line was rendered.

### Dispatch voice and ambient vehicle radio

The user-confirmed **`nc_heat_1_start`** police-radio line now accompanies a **new dispatch notification**. CET includes **Mute / Enable dispatch voice** and the existing preview. The short alert and eight-second dispatch/resolved notices remain. Custom on-scene voice waits for the user's briefing audio files.

Ambient chatter uses the existing **`radio_car_police_npc`** event, with the **car's entity ID** passed to the native audio system. It starts while on duty and mounted in an owned police car, and stops on that same car when exiting, switching vehicles, muting, ending duty or being terminated for crime. The controller checks every 0.25 seconds and starts one event per occupied vehicle rather than restarting it every frame.

Eligibility requires **IsPlayerVehicle** and either the known patrol Hella record or a player audio-resource name containing `police`. This supports the patrol Hella and vehicles using police audio metadata; custom vehicles with other metadata can need explicit support. Civilian and unowned vehicles are excluded. CET includes **Mute / Enable vehicle chatter** and an entity/source diagnostic.

The event name is present in the game's sound catalog. **Audibility and spatial playback need an in-game check.** Dispatch-call voice and the ambient car event have separate controls.

### Criminal activity ends the shift

Wanted heat is read from **PreventionSystem.GetHeatStage()**. A non-zero level during duty disables native duty and bonus eligibility, clears dispatch markers, stops vehicle chatter and displays this eight-second priority notification:

> NCPD: Shift terminated due to criminal activity.

CET then dismisses the live partner and switches to OFF DUTY. Monitoring checks every 0.25 seconds, and the native reward tick checks again before processing a payment. **Start Shift is rejected while wanted**, including terminal requests.

Already-paid money is retained and pending earned receipts can display after the termination notice. Pending assignment/arrival notices are discarded; notice tokens prevent an interrupted callback from cutting the new priority notice short. Loading a save follows the separate reset path, forgetting old partner/vehicle IDs instead of acting on them in the new world. The mod does not clear the game's wanted/chase state.

### Install and test

Requirements match v0.5b: Cyberpunk 2077 **2.5**, matching **CET**, **Codeware 1.21.4**, **RED4ext 1.31.0+**, **TweakXL** and compatible **redscript**. No new dependency.

1. Exit the game completely. Extract the ZIP into the game folder containing `bin` and `r6`, replacing all NCPDPatrol files, including the updated redscript and new **vehicle_radio.lua**.
2. Start a shift and **Request dispatch now**. Check the distance/radius and whether GPS appears without opening the map. Try **Refresh dispatch GPS** if necessary.
3. Confirm the approved voice accompanies the new dispatch notice.
4. Enter your summoned police Hella. Check chatter starts, then stops when you get out. Test another owned police car and excluded civilian/unowned vehicles.
5. Gain a wanted star during a shift. Check the termination notification, OFF DUTY state, partner dismissal, cleared dispatch and stopped car chatter.
6. Check that duty cannot restart while wanted, and can restart after the wanted level ends.

### Validation

- All six Lua modules pass LuaJIT loading.
- The authored native class is exercised through a test-only syntax adapter with mocked game calls. Actual CET Lua modules run against it through a native-array conversion bridge.
- Checks cover radius boundaries/tier expansion/2 km cap; bounded GPS updates and UI signals without opening a map; dispatch voice; owned/mounted police-car eligibility; vehicle-entity playback/stop/switch/mute; wanted reward cutoff; priority notification tokens; preservation of already-earned receipts; actual partner dismissal on crime; wanted start rejection; and save-load cleanup without reusing old IDs.
- Prior scanner/payment/receipt, terminal, partner and vehicle boarding regressions pass.
- redscript 1.0.1 reports no syntax/type errors or warnings against source-derived game/Codeware API contracts. This is not compilation against the actual Cyberpunk 2.5 script cache and cannot verify live audio banks, spatial playback or GPS rendering.

### Previous versions

- [v0.5b: longer notices and audio preview](https://github.com/jonathankj2000-cpu/NCPD-Patrol-Officer/raw/refs/heads/main/releases/NCPD_Patrol_v0.5b_Dispatch_Audio_Notices_TEST.zip)
- [v0.5a: dispatch prototype](https://github.com/jonathankj2000-cpu/NCPD-Patrol-Officer/raw/refs/heads/main/releases/NCPD_Patrol_v0.5a_Scanner_Dispatch_TEST.zip)
- [v0.4c: scanner bonus/receipt](https://github.com/jonathankj2000-cpu/NCPD-Patrol-Officer/raw/refs/heads/main/releases/NCPD_Patrol_v0.4c_Scanner_Monitor_Fix_TEST.zip)

To return to v0.5b, exit the game, remove `vehicle_radio.lua` and reinstall the complete v0.5b ZIP.

### API references

- [Existing game sound-event catalog, including radio_car_police_npc](https://github.com/justarandomguyintheinternet/CP77_entSpawner/blob/93254747ba1156b26eb43fecef8e6b5336ce596a/resources/bin/x64/plugins/cyber_engine_tweaks/mods/entSpawner/data/spawnables/audio/sounds/sounds.txt)
- [Native AudioSystem entity playback/stop API](https://github.com/In-Question/MOD_Development_Reference/blob/main/DecompiledGameScripts/core/systems/audioSystem.swift)
- [PreventionSystem heat-stage getter](https://github.com/In-Question/MOD_Development_Reference/blob/main/DecompiledGameScripts/core/systems/preventionSystem.swift)
- [Native quest tracker and tracked-mappin/menu signals](https://github.com/In-Question/MOD_Development_Reference/blob/main/DecompiledGameScripts/cyberpunk/UI/quests/quest_tracker.swift)
- [Existing police-radio entry](https://github.com/In-Question/MOD_Development_Reference/blob/main/DecompiledGameScripts/core/systems/policeRadioSystem.swift)

Installation ZIP SHA-256: `ab3d8889223f2b0fff64db1828fef6fcf5da2a5afbec650fcf7ad77656d8292f`
