NCPD PATROL v0.5e - RADIO STATE / DEFERRED REPLAY TEST
==================================================
The second dispatch remained silent in v0.5d despite two native requests and one
replay reset. That log established sent calls, not audible playback or the cause.

CHANGES
 - Before requesting nc_heat_1_start, reset isHeat1LineRequestOngoing, matching
   the game's PoliceRadioScriptSystem.PlayRadio handling for that entry.
   This is a radio scheduling flag; the mod does not change wanted heat.
 - For a repeat request owned by the current shift, abort the previous radio line,
   then wait 0.5 seconds before sending. This separates abort and request; it is
   a test mitigation, not a claim about a proven engine cooldown.
 - Check duty/wanted state again before the deferred send. Ending duty, loading
   a save or superseding the request invalidates its pending callbacks.
 - Sample native recent-request history one second after the actual send.
   Voice log lines now update at preparation, sending and later observation.
 - The existing 12-second chatter pause now starts its release timer at the actual
   send. Only the currently occupied eligible owned police car can resume.

DIAGNOSTICS
requests counts actual native sends; attempts counts prepared requests.
pending native send distinguishes a deferred call from a sent one.
heat1 flag before/after records the scheduling flag around the native call.
recent before/after shows native history observed before and after sending.
The native API returns no acknowledgement of audible playback. History is not a
playback receipt; unchanged or repeated history alone does not prove rejection.
Voice still follows the dispatch notification queue. Requesting another dispatch
while one is active creates no new assignment or voice request.

INSTALL / TEST
1. Exit the game completely. Extract this entire ZIP into the game folder
   containing bin and r6, replacing all NCPDPatrol files. Include the new file
   r6/scripts/NCPDPatrol/NCPDPatrolRadioStep.reds, plus NCPDPatrolVoiceWindow.reds.
2. Load a save and start a shift. In a vehicle, test two accepted dispatches with
   visible notices. Complete or cancel the first assignment before requesting
   the next. Preview police radio in CET also tests calls during duty.
3. If a later call is silent, wait at least two seconds after its notice, then
   capture the Voice log line containing "Native history sampled after 1 s".
   Include the first and second calls if possible. It should show requests=2
   after two actual sends, plus the flag and recent-before/after fields.
4. In an owned police car, confirm chatter pauses for the call window and can
   resume after 12 seconds. Getting out or ending duty should keep it stopped.

Requirements: Cyberpunk 2077 2.5, matching CET, Codeware 1.21.4, RED4ext 1.31.0+,
TweakXL and compatible redscript. No additional dependency.

RETAINED / AUDIO COUNTS
Dispatch search tiers 1/1.5/2 km, marker and HUD, bonus ledger/receipts, notification
queue, vehicle-bound chatter, wanted termination/start rejection, terminal duty,
partner and boarding remain. Open/close the world map when needed for the GPS
line. On-scene voice awaits the user's briefing files.
The ZIP bundles zero audio files. There is one dispatch entry (nc_heat_1_start)
and one chatter event (radio_car_police_npc); the number of internal recordings
is unknown. None in recent history is an empty slot, not a silent sound file.
Chatter volume is unchanged; an event-specific gain control is not verified.

VALIDATION / LIMITS
All six Lua modules load in LuaJIT. Redscript syntax/type checks pass against
source-derived contracts, not the actual game script cache. Authored native logic
is exercised via a syntax adapter with mocked game APIs; actual CET modules run
against that logic in the scenarios. Checks cover flag reset, deferred sending,
history observation/logging, stale callbacks, duty/wanted/load cancellation and
previous reward, notice, vehicle, partner, boarding and navigation behaviour.
Real native scene playback still needs an in-game test.

ROLLBACK
Exit the game, remove r6/scripts/NCPDPatrol/NCPDPatrolRadioStep.reds and reinstall
the complete v0.5d ZIP from GitHub. Keep its NCPDPatrolVoiceWindow.reds.
