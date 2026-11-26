# v0.19g — automatic Voss/V conversation

Replaces the placeholder meeting dialogue and two choices with the supplied
manuscript: Voss 01 → V 1 → Voss 02 → V 2 → Voss 03 → V 3 → Voss 04 → Voss 05 →
V 4 → Voss 06. The scene runs automatically and completes the journal after
the last line. It remains a standalone meeting test; no contractor/combat
mission, payment or automatic milestone activation is added.

All six WAVs are complete Wwise Vorbis streams with their original sample
counts. Each Voss dialogue event starts voice and facial animation together
after 300 ms. The three supplied animation banks contain three, two and one
clips. A consolidated bank preserves every animation payload, rig, track/joint/
frame value and data chunk, relocating only resource-local IDs and chunk indices.
Original source banks remain byte-identical. `tools/build_voss_lipsync_bank.py`
reproduces and roundtrip-checks the merge. The archive includes seven media files.

V replies use original game string IDs `1938843197804515328`,
`1895381798296993792`, `1938900123686932480`, `1714373979483803648`, in that order.
The native player actor follows the existing MIT reference pattern. No original
V audio, global subtitle entries or voice-map overrides are packaged for these
IDs. Supplied English words are scene-local fallback text. Actual voice variants
and playback require game verification. Conservative initial V scene slots of
4.0, 5.5, 4.5 and 7.5 seconds can be tuned independently of Voss's measured files.

Voss has 23 short paragraph-sized subtitle blocks timed against the recording.
The UI-only wrapper preserves continuous audio/lipsync and native font, name,
settings and line lifetime. Generation/actor/stage guards reject stale writes
when V speaks, another Voss line starts, the widget is reused or the test ends.

SMS/history, meeting location, Hella, grounded arms-crossed waiting pose,
`pla_default_tgt` LookAt and the v0.19f1 confirmation/fallback fix are retained.
The native quest phase/bridge are unchanged. The final scene node writes the
existing private completion receipt, whose legacy fact name is `choice`, only
after all ten turns. No choice UI exists. Actors remain until explicit clear.
All eight other archives, 45 other native scripts, production dispatch systems,
rewards, career and recorded survey data are unchanged.

Checks execute the actual ten-turn graph, Lua/native bridge and subtitle
wrapper/callbacks, including final-only completion, interruption/replay and
the earlier active-pose despawn regression. All six WEM containers/sample counts,
merged payload provenance and exact native V IDs are checked. Malformed routing,
voice, speaker, helper, LookAt and SMS bindings are rejected. Source/API compile
passes with Browser Extension present/absent; this is not a game-cache compile.

Scene/player/voice schemas retain Andrea Olivato's MIT attribution at
`4aeaad5d235e3a0244c0f1857757d1b01cbcd58e`, including the original-V pattern in
`fixer01/source/raw/mod/fixer01/scenes/fixer01_face.scene.json`. Existing full
copyright/license notices apply. Story, new voice and facial banks are supplied
by the NCPD Patrol author.

Clear an old quest-giver test, install all 123 files and fully restart. OFF DUTY
→ CET → Testing → Quest giver prototype → Activate. Read the SMS, visit Voss,
close CET and approach on foot. Check all ten turns, four V voices, six facial
clips, captions and final completion; test both player voices if available.
Playback, exact V timing, rendering and pause behavior need game confirmation.
