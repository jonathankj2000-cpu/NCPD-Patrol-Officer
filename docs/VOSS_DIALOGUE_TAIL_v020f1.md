# Voss dialogue event tails — v0.20f1

The author heard no clear improvement from v0.20f's VO-context change. A source
comparison against Andrea Olivato's MIT project found another concrete
difference: our ten speech events ended 500 ms before their section boundaries.
His `fixer01_face.scene.json` has 23 direct speech-to-speech transitions with no
such tail. Both projects use one native scene for the conversation; there is no
evidence that our scene was restarting between lines, nor a special ambience
fix in the inspected reference scenes.

Reference: `andreaolivato/cyberpunk-codes`, commit
`f50e2d05e2ff868a1a15dbe40fd2cd9c77ff91be`,
`fixer01/source/raw/mod/fixer01/scenes/fixer01_face.scene.json`,
blob `82f4a677128dff4765fe66276c7eefa8b8b2ce2d`.
Existing Andrea Olivato MIT attribution is retained.

## Isolated change

Relative to the published v0.20f package
`9957b3cb4f34355ea0046dc7503962e8c940b886`, each of the ten speech events has its
duration increased by exactly 500 ms, ending at the existing section boundary.
The scene cache hash is updated. No section is shortened, and no new event or
actor is added. The native VO context remains `Vo_Context_Minor_Activity` so
this test changes only event-tail coverage.

Every absolute voice start, section boundary, pause and the 143.836-second
conversation duration is identical. The established startup guard against
overlapping Voss/V speech remains. Source WEMs, lipsync, four native V IDs,
text, caption switch schedule, LookAt and idle pose are unchanged. Extending a
speech event may keep its final caption visible for another half second.
The 300 ms Voss lead-ins remain; this test does not fill those separate gaps.

Only `conversation.scene` differs among the sixteen resources extracted from
the private archive. All other assets and nine other archives remain exact.
All 50 REDscript files, the encounter Lua, facts, death/wanted handling,
evidence, dispatch, duty, rewards and native API versions remain exact. The
complete package still has 131 install files and no new dependencies.

## Test and evidence limits

Fully restart after installation. Use a save before Voss's briefing or the
existing explicit quest-giver test replay. Compare the same location, audio
settings and conversation against v0.20f. Listen immediately before/after both
speakers, including first and final lines. Confirm voices, lipsync, caption
changes, normal pauses, no overlap, completion and continued quest progression.

The automated source comparison permits only the ten exact duration changes
and cache hash. It checks identical absolute starts, complete scene time and
original overlap envelope; the published v0.20f tails are rejected by the new
asset validation. WolvenKit roundtrip/extraction checks compiled resources and
all original media. The complete 46-suite regression set is retained.

These checks cannot establish native mixer behavior or audible continuity.
An eventless tail is not itself proof of an ambience mute. The native reason
for the reported cuts remains unconfirmed until this controlled game test.
