NCPD PATROL AUDIO TRACE v0.1 - TEMPORARY CET DIAGNOSTIC

This is a separate optional diagnostic, not another audio fix. Keep the existing
NCPD Patrol installation. It uses the existing CET and Codeware dependencies.
It never writes quest facts, changes audio settings or plays/stops sounds.

1. Extract this ZIP into the Cyberpunk 2077 game folder and restart the game.
   It adds only bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrolAudioTrace.
2. Load a save before Voss's conversation, off duty. Start the normal Voss test
   if needed, but stay far enough away that she has not begun speaking.
3. Open CET. In the temporary NCPD Audio Trace window, press
   "Arm next Voss conversation". Close CET and approach Voss within 3 minutes.
4. Let the conversation finish and wait 2 seconds. Export is automatic.
5. Send voss_audio_capture.json from:
   bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrolAudioTrace/

If interrupted, use "Stop and export capture". If export fails, the capture
remains in memory and "Export last capture again" can retry it. A new export
replaces the previous file. No hotkeys or bindings are added.

After testing, this helper folder can be removed and the game restarted. It is
not needed for ordinary gameplay. It remains unarmed unless you press Arm.

WHAT IT RECORDS

- Script-facing AudioSystem Play/Stop, switches, states and parameter requests.
- Subtitle data arrival and hide requests with line IDs. These are UI markers,
  not actual audible voice start/end times.
- Read-only SceneTier, HighLevel, UpperBody, Zones, dialogue/scene membership
  and menu/overlay state samples, with an initial snapshot and later changes.
- CET frame deltas >= 120 ms, to distinguish visible update stalls from mixing.
- Callback coverage, errors and explicit buffer truncation counts.
- After recording only: the loaded scene cache hash and ten section timings,
  compared with v0.20f1. This does not validate every archive byte.

Only a short pre-roll, one Voss conversation and 2 seconds afterwards are kept.
There is no file I/O during recording. Arrays and callback data are bounded.
Callbacks copy only plain values; game objects are never stored in the report.
Resource inspection runs only after recording, so it cannot pre-load Voss and
mask a streaming problem. If the asynchronous token is not ready, Export last
capture again can retry it; the trace remains available.

LIMITS

This does not read Wwise bus levels or hook the native audio renderer. Native
internal commands may bypass the script-facing API observers. An absence of
observed script audio calls does not establish whether the native mixer changed.
Subtitle markers can lead or lag the audible speech; times use CET update delta,
not an audio sample clock. Native callback delivery and audible symptoms need
the user's game. Observers add some overhead, so this helper is temporary.

The probe preserves original behavior using CET Observe, not Override. No
new framework, DLL, sound-bank replacement or REDscript compilation is added.

API EVIDENCE

Game source reference 81d996b584a693e8b0f0b20526a9fa38b5c83fe7:
core/systems/audioSystem.swift (public script-facing audio signatures),
core/blackboard/blackboardDefinitions.swift (PSM fields),
orphans.swift (GetLocalInstanced and scnDialogLineData), and
cyberpunk/UI/subtitles/baseSubtitlesControllers.swift (SetLineData).

CET source 20b42c69040b11eb8c676a4fc86dc4b6d1c55781:
src/scripting/FunctionOverride.cpp (Observe pass-through and registration locks)
and Scripting.cpp (script_ref conversion). Hooks register only in onInit.
