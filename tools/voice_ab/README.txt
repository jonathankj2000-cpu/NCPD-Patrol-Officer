NCPD PATROL - VOSS AUDIO RECOVERY AND DIRECT VOICE CONTROL
========================================================
This complete package restores the original v0.20f1 media/scene/scripts and
disables the rejected VO Lengths service. It also adds an OPTIONAL standalone
CET audio comparison. It does not claim to fix the original background cuts.

RECOVERY FIRST
1. Fully exit the game. Disable the previous VO Lengths and WEM Header test
   packages. Install this package after the main NCPD Patrol package and let
   it win file conflicts. Its original 131 files are byte-identical to v0.20f1.
2. The old r6/scripts/NCPDPatrolVossLengthTest/NCPDPatrolVossLengthTest.reds is
   overwritten with an inert recovery stub. It does not register or modify
   durations. This also handles a manual install without deleting files.
3. Restart the whole game: loading a save alone cannot reset cached global
   voice metadata. CET's main NCPD version banner remains v0.20f1.
4. The original non-overlap guards are restored. The original audio cuts may
   remain. No quest facts, progression or save data are rewritten.

SEPARATE A/B CONTROL - NO VOSS QUEST REQUIRED
1. Stand still off duty, without a wanted level, outside combat/conversations.
   Choose a place where the normal background sounds are easy to recognize.
2. Open CET. In "NCPD Voice A/B (temporary)", click "Run voice A/B comparison".
3. Close CET. After three seconds the helper sends four individual native
   audio events: original V line 1, original V line 2, Voss 01, then Voss 03.
   All four play on V through the same native event type/flags. There are
   deliberately long gaps. The entire control takes about 59 seconds.
4. Listen for cuts before/after the original V lines and before/after Voss.
   Say which group cuts, and whether all four lines were audible. A short
   recording is useful but is not required to report the comparison.
5. The result is exported automatically to:
   bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrolVoiceAB/voss_voice_ab_result.json
   Include it if the comparison fails to start or a line is missing.

Opening CET after the first event cancels the remaining events. Cancel only
prevents future sends: a current line may finish naturally. The helper does
not issue global Stop/mute commands or interrupt any unrelated voice.
It refuses to start if the active VO Lengths service still wins load order.
The queued-event log is not proof a sound was played; report what you hear.

WHY THIS CONTROL
The native duration experiment DID load successfully (one resource callback,
six added entries, verified=6/6). The author reports unchanged cuts and newly
overlapping V/Voss voices. That experiment is rejected; its metadata changes
are not part of production. The control bypasses quest/section scheduling and
lipsync, using the existing native gameaudioeventsDialogLine event directly.
This can distinguish stock/custom playback on the PLAYER emitter. It does not
test the NPC emitter path, measure mixer buses, or establish a root cause.

No new DLL or framework is required. Existing CET and Codeware are used.
No actors are moved/spawned, no scene is started, and no production dialogue,
duty, dispatch, wanted, rewards, weapons or career code is modified.

SOURCE / CREDIT
Event/data API: Codeware 1.21.4's DialogLineEvent and audioDialogLineEventData
imports; game's Entity.QueueEvent and SceneSystemInterface declarations.
Native event name corroborated by cyb3rpsych0s1s/audioware at
e71fcc1c87fb8d9c2885b452272e0c883f6831e0, types/vanilla/events/dialog_line.rs.
NewObject, CRUID and Enum construction checked against CET Scripting.cpp at
20b42c69040b11eb8c676a4fc86dc4b6d1c55781. No external implementation or audio
is copied. Audioware is not required. Existing author/Andrea Olivato credits
are retained in THIRD_PARTY_NOTICES.txt.

LOCAL VERIFICATION / LIMITS
Tests execute the helper against recording API boundaries, check exact uint64
IDs, event fields, guards, timing gaps, cancellation, export and the recovery
stub. The stub passes an offline API compile. Actual native event delivery,
audible results and actual game-cache compilation require testing in game.

REMOVE THE OPTIONAL HELPER
Remove/disable NCPDPatrolVoiceAB's folder after testing. The recovery stub can
remain inert. To return to only original v0.20f1, disable this test package and
the earlier length test, or manually remove their two separate added folders.
