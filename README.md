# NCPD Patrol

## v0.5d: repeat dispatch voice and diagnostics

**[Download v0.5d](https://github.com/jonathankj2000-cpu/NCPD-Patrol-Officer/raw/refs/heads/main/releases/NCPD_Patrol_v0.5d_Voice_Replay_Diagnostics_TEST.zip)**

The user confirmed vehicle chatter is audible and wanted termination works. The marker remains useful; the normal GPS line still requires opening/closing the map. This build focuses on repeat dispatch voice requests and diagnostic evidence.

### Audio counts and requested volume boost

- **Zero bundled audio files.** All sounds come from the installed game.
- **One dispatch scene entry:** `nc_heat_1_start`.
- **One vehicle-chatter sound event:** `radio_car_police_npc`.

An entry/event can refer to internal scenes or multiple recordings. These identifiers do not reveal the number of raw voice files, so no count of the underlying recordings is claimed.

**Chatter volume remains unchanged.** A verified event-specific gain control for this native sound event has not been found in the exposed API used here. This update does not claim a 20–30% boost or change global game/car volume settings. A precise boost needs verified resource or playback gain control.

### Repeat-call mitigation

The first request in a shift does not reset an unknown previous police-radio line. Before a further request owned by that shift, with zero wanted heat, the mod calls **AbortCurrentRadioLine** before sending the same approved scene entry again.

The mod also pauses its vehicle-chatter event for a **12-second voice window** around an on-duty voice request. After expiry, the normal controller can resume the currently occupied eligible owned police car. Getting out, ending duty, being terminated for crime or loading a save prevents inappropriate resume. Tokens prevent an old window callback from releasing a newer pause.

The game API has no audible-playback acknowledgement. This is a mitigation to test, not a claim that a cooldown, silent file or overlap was proven to cause the missing second line.

### Voice diagnostics

CET now shows:

- Native request count and replay-reset count.
- Last source: `dispatch` or `test`.
- The scene entry, pending notification count and request status.
- Recent native radio requests read before the next request.

`[NCPD Patrol] Voice | ...` is logged when the request count changes. A request is reported as requested, not confirmed audible. Counts refer to API requests, not audio files.

Voice is requested when the queued dispatch notice reaches the screen. Earlier notices can delay it. Pressing Request dispatch now while an assignment is already active produces no additional dispatch/voice request.

### Marker navigation

The dispatch marker and in-game objective display remain. The automatic retries, manual GPS-refresh control and tracked-mappin/UI-state writes from v0.5c are removed. Open and close the world map when needed to initialize the GPS line. No further GPS fix is claimed.

### Install and test

Requirements match v0.5c: Cyberpunk 2077 **2.5**, matching **CET**, **Codeware 1.21.4**, **RED4ext 1.31.0+**, **TweakXL** and compatible **redscript**. No new dependency.

1. Exit the game completely. Extract the ZIP into the game folder containing `bin` and `r6`, replacing all mod files and including the new **NCPDPatrolVoiceWindow.reds**.
2. Load a save, start a shift and test two accepted dispatches with visible notices. Complete or cancel the first before requesting the next.
3. In an owned police car, confirm chatter pauses for the call window and can resume after 12 seconds. Get out during the pause and confirm it stays stopped.
4. If the second call is silent, report the **Voice** log lines from both calls. The counters distinguish a sent request from a notice still waiting in the queue.
5. Use **Preview police radio (in vehicle)** in CET to test requests without needing another eligible scanner.

### Retained behaviour

The 1/1.5/2 km dispatch search, notification queue, bonus ledger/receipts, vehicle-bound chatter, wanted termination/start rejection, terminal duty, partner following/combat/boarding and save cleanup remain. On-scene voice awaits the user's briefing files.

### Validation and limits

- All six Lua modules pass LuaJIT loading.
- Authored native logic is exercised through a syntax adapter with mocked game APIs. Actual CET modules run against that class with a native-array conversion bridge.
- Scenarios cover first/repeated requests, owned replay reset, zero-wanted guards, chatter stop/pause/resume, superseded pause timers, save/session invalidation, voice counters/logs and marker-only navigation, plus previous duty/bonus/receipt/partner/boarding regressions.
- Redscript 1.0.1 syntax/type checks against source-derived contracts pass. These checks do not use the actual Cyberpunk 2.5 script cache and cannot verify native audio output or establish why a scene request was silent.

### Previous versions

- [v0.5c: local dispatch, vehicle chatter and wanted termination](https://github.com/jonathankj2000-cpu/NCPD-Patrol-Officer/raw/refs/heads/main/releases/NCPD_Patrol_v0.5c_Local_Dispatch_Duty_Radio_TEST.zip)
- [v0.5b: longer notices and audio preview](https://github.com/jonathankj2000-cpu/NCPD-Patrol-Officer/raw/refs/heads/main/releases/NCPD_Patrol_v0.5b_Dispatch_Audio_Notices_TEST.zip)

To return to v0.5c, exit the game, remove `r6/scripts/NCPDPatrol/NCPDPatrolVoiceWindow.reds` and reinstall its complete ZIP.

### API references

- [Native police-radio request/history/abort API](https://github.com/In-Question/MOD_Development_Reference/blob/main/Definitions/Game_Definitions/classes/gamePoliceRadioSystem.lua)
- [Game police-radio script and its history checks](https://github.com/In-Question/MOD_Development_Reference/blob/main/DecompiledGameScripts/core/systems/policeRadioSystem.swift)
- [Native audio-system API used for vehicle playback](https://github.com/In-Question/MOD_Development_Reference/blob/main/DecompiledGameScripts/core/systems/audioSystem.swift)

Installation ZIP SHA-256: `567daa39760b9af7e08b6722f50f49f3fc5f8a6cd12ca3b126311bcf0942b4ef`
