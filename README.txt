NCPD PATROL v0.5d - DISPATCH VOICE REPLAY / DIAGNOSTICS
====================================================
The user confirmed vehicle chatter is audible, termination works, and the marker
works while the GPS line still needs a map open/close. This update targets missing
repeat dispatch voice and retains marker-only navigation.

AUDIO COUNTS / VOLUME
 - The mod bundles zero audio files.
 - Dispatch requests one native scene entry: nc_heat_1_start.
 - Vehicle chatter uses one native sound event: radio_car_police_npc.
 - Those identifiers are not a count of internal recordings. The number of raw
   voice files behind the scene/event is not known from these script/API sources.
 - Chatter volume is unchanged. A verified event-specific gain control has not
   been found for this native event. This build does not claim a 20-30% boost or
   change global game/car volume settings. A precise boost needs verified resource
   or playback gain control.

VOICE REPLAY CHANGES
 - Before another radio request owned by the current shift, with zero wanted
   heat, the native radio line is reset with AbortCurrentRadioLine.
 - The first request of a shift does not reset an unknown previous radio line.
 - No police-radio reset/request is made while wanted. Termination remains active.
 - Our car chatter pauses for a 12-second window when an on-duty voice request is
   issued. The occupied eligible car can resume through the normal controller
   after that window. Leaving the car or ending duty prevents resume.
 - Window tokens prevent an old timer from releasing a newer pause. Loading a
   save invalidates old callbacks and never reuses vehicle entity IDs.
 - The game radio API returns no audible-playback acknowledgement. These changes
   are a mitigation to test, not proof of why the second call was silent.

VOICE DIAGNOSTICS
CET displays native request count, replay-reset count, last source (dispatch/test),
entry name, pending notification count, status and the recent request history read
before sending the next request. A Voice | ... line is logged when the native
request count changes. A successful request is not reported as confirmed playback.
Speech is requested when its dispatch notice is shown, so earlier queued notices
can delay it. A repeated click on an already assigned dispatch creates no new call.

NAVIGATION
The dispatch marker and HUD objective remain. Automatic/manual GPS refresh calls
and tracked-mappin/UI-state writes from v0.5c are removed. Open and close the world
map when the game needs it to initialize the GPS line. No further GPS fix is claimed.

INSTALL / TEST
1. Exit the game completely. Extract the entire ZIP into the game folder containing
   bin and r6 and replace all NCPDPatrol files. Include NCPDPatrolVoiceWindow.reds.
2. Load a save, start a shift and test two accepted dispatches with visible notices.
   Cancellation/completion is needed before requesting another assignment.
3. In an owned police car, check chatter pauses during the call window and resumes
   after 12 seconds. Get out during the window and confirm it stays stopped.
4. If a later call is silent, send the [NCPD Patrol] Voice | ... lines from the first
   and second calls. The counts distinguish sent requests from notices still queued.
5. Preview police radio in CET can test voice requests without needing a free scanner.
Requirements match v0.5c: Cyberpunk 2077 2.5, matching CET, Codeware 1.21.4,
RED4ext 1.31.0+, TweakXL and compatible redscript. No additional dependency.

RETAINED
Dispatch radius tiers 1/1.5/2 km, manual controls, notifications/receipt queue,
save-bound bonus ledger, vehicle-bound chatter, wanted termination/start rejection,
terminal duty, partner and boarding remain. On-scene voice awaits the user's files.

VALIDATION
All six Lua modules load in LuaJIT. Redscript syntax/type checks pass against
source-derived contracts, not the actual game script cache. Authored native logic
and actual Lua scenarios verify repeat requests, ownership/reset guards, chatter
pause/resume, stale tokens, voice logs, marker-only behaviour and existing duty,
bonus, notification, partner and boarding regressions. They cannot verify real
sound output or prove the cause of a silent native scene request.

ROLLBACK
Exit the game, remove r6/scripts/NCPDPatrol/NCPDPatrolVoiceWindow.reds and reinstall
the complete v0.5c ZIP. Earlier ZIPs remain on GitHub.
