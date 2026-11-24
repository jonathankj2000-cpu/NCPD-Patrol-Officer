NCPD PATROL - ISOLATED NATIVE VO LENGTH METADATA TEST
===================================================
Full package based on v0.20f1, with ONE added REDscript service. The original
131 install files, including every archive/WEM/scene, remain byte-identical.
The CET banner still says v0.20f1. No new framework is required; this uses the
Codeware already required by NCPD Patrol.

WHAT THIS TESTS
The previous channel-header experiment produced no audible improvement in the
author's game. This test returns to the original v0.20f1 audio assets and changes
one different variable: native duration metadata for the six private Voss IDs.

The game has a separate VO length report. Stock V line lengths are known at
runtime, but the Voss IDs have never been registered there. The earlier capture
showed stock V durations replacing the authored conservative slots while Voss
durations remained at the longer authored fallback values. That is a metadata
omission; it is NOT yet proof of the cause of the ambience cuts.

The added service uses Codeware Resource/PostLoad to register the real WEM
sample durations for only the six English Voss IDs in:
base\localization\en-us\stringidvariantlengthsreport.json
It preserves stock rows and their gender-specific lengths. It does not play,
stop, mute or change mixer states. There are no scene, lipsync, WEM, caption,
quest-fact, duty, dispatch, reward or wanted-policy changes.

INSTALL / TEST
1. Fully exit the game. Disable the previous WEM Channel Header test package.
   Install this complete package over v0.20f1; let this package win conflicts.
2. Restart the game. Load before the Voss briefing and replay the conversation.
3. Listen at the first line and every Voss -> V / V -> Voss transition. Check
   that voices remain complete and do not overlap. Actual native scheduling
   may change when the engine learns the real custom voice lengths.
4. Run this single CET console command after the attempt:

local s=Game.GetScriptableServiceContainer():GetService(CName.new("NCPDPatrolVossLengthTest")); print(s and s:GetDiagnostics() or "Voss length test service missing")

Expected: resource callbacks >=1, verified=6/6. Registration alone is not proof
that the report loaded. If callbacks=0 or verified is not 6/6, include that line
when reporting the test; do not interpret unchanged audio as a valid negative.
5. If the separate Audio Trace v0.1 helper is still installed, optionally arm it
   before the conversation as before. The new JSON's declared Voss durations
   can show whether the scene consumes the native lengths rather than its
   previous fallback. This helper is not required for the metadata test.

ROLLBACK
Disable this test package and restore the original v0.20f1 package. For a manual
installation, remove only r6/scripts/NCPDPatrolVossLengthTest from this test.
Fully restart the game. No quest facts or production script files are modified.

SOURCE / CREDIT / LIMITS
Technical pointer: cyb3rpsych0s1s/audioware, documentation SCENE_DIALOG_LINES.md,
section "string id variants map", commit e71fcc1c87fb8d9c2885b452272e0c883f6831e0:
https://github.com/cyb3rpsych0s1s/audioware/blob/e71fcc1c87fb8d9c2885b452272e0c883f6831e0/book/pages/SCENE_DIALOG_LINES.md
This test does not use or require Audioware. The implementation is newly written
against Codeware 1.21.4's ResourceTarget, ResourceEvent, CallbackSystem,
ScriptableService, locVoiceoverLengthMap and locVoLengthEntry APIs. No external
audio or quest assets are included. Existing Andrea Olivato and authoring-tool
credits remain in THIRD_PARTY_NOTICES.txt.

The merge executes in local tests; its uint64 IDs and Float32 lengths match the
real private voice map and WEM sample counts. The source passes an offline API
compile. Native resource callback delivery, actual game-cache compilation,
runtime scheduling and an audible fix still require testing in Cyberpunk.
