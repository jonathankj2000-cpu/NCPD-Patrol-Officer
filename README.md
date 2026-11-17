# NCPD Patrol

## v0.5e: radio state and deferred replay test

**[Download v0.5e](https://github.com/jonathankj2000-cpu/NCPD-Patrol-Officer/raw/refs/heads/main/releases/NCPD_Patrol_v0.5e_Radio_State_Replay_TEST.zip)**

The second dispatch remained silent in v0.5d despite two native requests and one replay reset. Those counters establish sent calls; they do not establish audible playback or the cause of the silence.

### Changes

The game resets **`isHeat1LineRequestOngoing`** before requesting `nc_heat_1_start` through `PoliceRadioScriptSystem.PlayRadio`. This build includes that step before its direct native request. The field controls radio scheduling; wanted heat is unchanged.

For another request owned by the current shift, the mod aborts the prior radio line and waits **0.5 seconds** before sending. This separates abort and request. The delay is a test mitigation, not a proven engine cooldown. Duty and wanted eligibility are checked again before the deferred send. Ending duty, loading a save or superseding the request invalidates its pending callbacks.

The mod reads native recent-request history again **one second after sending**. CET logs change at preparation, actual sending and later observation. The existing 12-second vehicle-chatter pause starts its release timer at the actual send; the normal controller can then resume the currently occupied eligible owned police car.

### Reading the Voice diagnostics

- `requests`: actual native sends; `attempts`: prepared requests.
- `pending native send`: whether a deferred call is still waiting.
- `heat1 flag before/after`: scheduling state around the native call.
- `recent before` / `recent after`: observed native request history.

The native API returns no acknowledgement of audible playback. History is not a playback receipt, and repeated or unchanged history alone does not prove rejection. Speech is still requested when its queued dispatch notice reaches the screen. Requesting another dispatch while one is assigned creates no new assignment or voice request.

### Install and test

Requirements: Cyberpunk 2077 **2.5**, matching **CET**, **Codeware 1.21.4**, **RED4ext 1.31.0+**, **TweakXL** and compatible **redscript**. No additional dependency.

1. Exit the game completely. Extract the entire ZIP into the game folder containing `bin` and `r6`, replacing all mod files. Include the new **`NCPDPatrolRadioStep.reds`** and the existing `NCPDPatrolVoiceWindow.reds`.
2. Load a save, start a shift and test two accepted dispatches in a vehicle. Complete or cancel the first assignment before requesting the next. **Preview police radio (in vehicle)** in CET can also test requests during duty.
3. If a later call is silent, wait at least two seconds after its notice, then capture the **Voice** log line containing **`Native history sampled after 1 s`**. Include the first and second calls if possible. Two actual sends should show `requests=2`, with flag and before/after history fields.
4. In an owned police car, check that chatter pauses and can resume after the 12-second window. Getting out or ending duty should keep it stopped.

### Retained behaviour and audio limits

Dispatch search tiers of 1/1.5/2 km, marker and HUD objective, bonus ledger/receipts, notification queue, vehicle-bound chatter, wanted termination/start rejection, terminal duty, partner and boarding remain. Open and close the world map when needed for the GPS line. On-scene voice awaits the user's briefing files.

There are **zero bundled audio files**, **one dispatch scene entry** (`nc_heat_1_start`) and **one vehicle-chatter event** (`radio_car_police_npc`). The number of internal recordings behind these identifiers is unknown. `None` in recent history is an empty slot, not a silent sound file.

Chatter volume remains unchanged. An event-specific gain control has not been verified for this native playback API.

### Validation and limits

All six Lua modules load in LuaJIT. Redscript syntax/type checks pass against source-derived contracts, not the actual game script cache. Authored native logic is exercised through a syntax adapter with mocked game APIs; actual CET modules run against that logic in the scenarios. Checks cover flag reset, deferred sending, later history observation/logging, superseded callbacks, duty/wanted/load cancellation and prior reward, notice, vehicle, partner, boarding and navigation behaviour.

Real native scene playback still needs an in-game test.

### Previous versions and rollback

- [v0.5d: replay diagnostics](https://github.com/jonathankj2000-cpu/NCPD-Patrol-Officer/raw/refs/heads/main/releases/NCPD_Patrol_v0.5d_Voice_Replay_Diagnostics_TEST.zip)
- [v0.5c: local dispatch, vehicle chatter and wanted termination](https://github.com/jonathankj2000-cpu/NCPD-Patrol-Officer/raw/refs/heads/main/releases/NCPD_Patrol_v0.5c_Local_Dispatch_Duty_Radio_TEST.zip)

To return to v0.5d, exit the game, remove `r6/scripts/NCPDPatrol/NCPDPatrolRadioStep.reds` and reinstall its complete ZIP. Keep its `NCPDPatrolVoiceWindow.reds`.

### API references

- [Game police-radio script, including the scheduling-flag reset](https://github.com/In-Question/MOD_Development_Reference/blob/main/DecompiledGameScripts/core/systems/policeRadioSystem.swift)
- [Native police-radio request/history/abort API](https://github.com/In-Question/MOD_Development_Reference/blob/main/Definitions/Game_Definitions/classes/gamePoliceRadioSystem.lua)
- [Native audio-system API for vehicle playback](https://github.com/In-Question/MOD_Development_Reference/blob/main/DecompiledGameScripts/core/systems/audioSystem.swift)

Archive SHA-256: `938b78e56e0567b3e1b9f10cf21c10bc43ff66772b1ce96b5b93f6ef7551f91c`
