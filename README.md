# NCPD Patrol

## v0.5b: longer notifications and dispatch audio

**[Download v0.5b](https://github.com/jonathankj2000-cpu/NCPD-Patrol-Officer/raw/refs/heads/main/releases/NCPD_Patrol_v0.5b_Dispatch_Audio_Notices_TEST.zip)**

Based on **v0.5a dispatch** and **v0.4c bonus/receipt**, both confirmed working in game by the user. The new notification queue, sound and native radio preview still need an in-game check.

### Notifications

- New dispatch and **Incident resolved** notices last **8 seconds** each.
- **On scene** and cancellation remain **4 seconds**.
- Patrol notices share a queue, so the delayed bonus receipt does not cut Resolved short after two seconds. Each queued notice gets its full configured duration.
- Money still transfers immediately. The receipt becomes eligible after 2 seconds, then waits for earlier patrol notices before displaying for 8 seconds. Notifications never grant money.
- Pending notices and their callbacks belong to the loaded session; old callbacks cannot release or display a notice in a restored session.

### Dispatch alert and spoken-radio preview

An accepted dispatch plays the existing short **`ui_phone_sms`** notification signal when its notice reaches the screen. This build supplies a short alert rather than a vehicle siren loop.

CET's **DISPATCH** section adds:

- **Mute / Enable dispatch alert** for automatic assignment alerts.
- **Test dispatch alert** to audition the signal directly, including while assignment alerts are muted.
- **Preview police radio (in vehicle)** to request the existing **`nc_heat_1_start`** line through the native PoliceRadioSystem. The script does not change heat, district, vehicle or police AI state to trigger it.

The documented radio entry is used for pursuit dialogue. **An appropriate spoken on-scene briefing has not yet been selected**, so it is not played automatically on arrival. The preview lets the user check audibility and wording in game before selecting a fitting briefing. No custom recorded/generated speech or additional audio dependency is included.

### Install and check

Requirements match v0.5a: Cyberpunk 2077 **2.5**, matching **CET**, **Codeware 1.21.4**, **RED4ext 1.31.0+**, **TweakXL**, and compatible **redscript**. No additional dependency.

1. Exit the game completely. Extract the ZIP into the game folder containing `bin` and `r6`, replacing the mod files and including the new **NCPDPatrolNotice.reds** file.
2. Load a save. In **CET → NCPD Patrol → DISPATCH**, try **Test dispatch alert**.
3. Start a shift and **Request dispatch now**. Confirm the eight-second notification and one short alert. Earlier queued notices can delay when it appears.
4. Travel to the incident. Check the existing four-second **On scene** message and HUD objective.
5. Finish the scanner, including evidence collection. Check the full **Resolved** notification followed by the bonus receipt, and one money transfer.
6. In a parked vehicle, try **Preview police radio (in vehicle)** and report the line's wording and whether it suits an arrival briefing.

### Retained patrol and dispatch

One active, unfinished Assault in Progress or Suspected Organized Crime activity is selected at a time, preferring incidents within 2.5 km. Automatic calls wait 30–60 seconds initially and 60–120 seconds after resolution/cancellation, pausing in menus and combat. CET retains manual request, cancellation and pause/resume controls. Cancellation does not alter the vanilla scanner, and its ID is excluded for the remainder of that shift.

The Custom Position waypoint, in-game HUD objective, shared saved/live completion state and tagged cleanup on End Shift/load remain. The normal road GPS line has not been independently verified. Dispatch continues to use the existing EUR$1000 scanner reward ledger, so it adds no duplicate bonus. Other eligible scanners still pay while on duty.

Terminal Start/End Shift, partner following/combat/boarding, Police Hella and uniform controls remain available. Revive is not included in this build. Existing encounters are selected rather than regenerated; Reported Crime follow-ups are excluded.

### Validation

- LuaJIT loading of all modules, actual CET module scenarios and the adapted authored native class: dispatch, HUD, automatic/manual controls, audio controls, duplicate suppression, mute and explicit previews.
- Native reward/notification scenarios with chronological DelaySystem mocks: full 8/4/8-second durations, receipt ordering, no second money transfer, alert timing, queued alert delivery, restored-session isolation and missing-delay fallback.
- Previous scanner completion/payment/receipt, terminal duty, partner, boarding and cleanup regressions pass.
- redscript 1.0.1 syntax/type checking against source-derived game and Codeware contracts: no warnings or errors. These checks do not use the actual Cyberpunk 2.5 script cache and cannot verify live sound banks, voice content or HUD timing.

### Previous versions

- [v0.5a: confirmed dispatch prototype](https://github.com/jonathankj2000-cpu/NCPD-Patrol-Officer/raw/refs/heads/main/releases/NCPD_Patrol_v0.5a_Scanner_Dispatch_TEST.zip)
- [v0.4c: confirmed scanner bonus/receipt](https://github.com/jonathankj2000-cpu/NCPD-Patrol-Officer/raw/refs/heads/main/releases/NCPD_Patrol_v0.4c_Scanner_Monitor_Fix_TEST.zip)

To return to v0.5a, exit the game, remove `r6/scripts/NCPDPatrol/NCPDPatrolNotice.reds` and reinstall the complete v0.5a ZIP.

### API references

- [Native police radio script and documented radio entries](https://github.com/In-Question/MOD_Development_Reference/blob/main/DecompiledGameScripts/core/systems/policeRadioSystem.swift)
- [PoliceRadioSystem audio-request API](https://github.com/In-Question/MOD_Development_Reference/blob/main/Definitions/Game_Definitions/classes/gamePoliceRadioSystem.lua)
- [Existing ui_phone_sms notification use](https://github.com/In-Question/MOD_Development_Reference/blob/main/DecompiledGameScripts/cyberpunk/UI/fullscreen/notification/journalNotification.swift)

Installation ZIP SHA-256: `827d50543b6392f22d1ad0de309ec8ca1d43d026f08287c1a649e2ab407a394f`
