# v0.19f — three Voss subtitle blocks

The voiced briefing now displays three successive text blocks in the game's
existing subtitle field. The first is shown at line start, the second at 15.0 s
(“Unfortunately…”), and the third at 28.5 s (“I need you…”). These timings were
checked against the supplied recording using local word alignment. All supplied
words are retained, in order. The alignment tool is an authoring aid and is not
included or required by the mod.

`SubtitleLineLogicController.SetLineData` is wrapped only for the exact private
Voss record, full briefing text, and active conversation stage. Other dialogue
passes through unchanged. The native method runs once, preserves the original
line ID, speaker, duration, settings and visibility lifecycle, and renders the
first short block immediately. Two native delayed callbacks update only the
same text widget. Weak controller ownership, per-line generations, current
quest stage and speaker attachment guard against late/stale writes.

The scene still contains one uninterrupted dialogue event. Its WEM, animation
bank, voice/lipsync mapping, scene graph, SMS introduction, body pose helper and
quest phase are byte-identical to v0.19e. No sound or animation is restarted by
the subtitle callbacks. The text and timing live in `contract.json`; the native
controller and localized on-screen strings are generated from that data.

The wrapper uses the existing game subtitle API documented in
MOD_Development_Reference at `81d996b584a693e8b0f0b20526a9fa38b5c83fe7`:
`cyberpunk/UI/subtitles/subtitlesControllers.swift`,
`core/ui/widgetReference.swift`, and `orphans.swift`. No new Andrea Olivato
code/assets are adapted for this update; all earlier MIT credits remain.

Validation executes the actual authored wrapper and callback methods with
recording native UI/delay boundaries. It checks all three blocks, exact timing,
unchanged metadata, unrelated dialogue fallthrough, widget reuse, cancellation,
completion, speaker detach and released controllers. All 45 pre-existing native
scripts, eight other archives, production dispatch systems, approved locations
and recorded evidence are preserved.

This is an offline check, not game validation. In the game, verify the two text
changes against the recording, pause/resume behavior, both replies and clear /
replay. Actual HUD layout, timing and footwear/ground alignment still require
testing. Clear the old quest-giver test before updating, install the complete
123-file package, and fully restart. Activate the same OFF DUTY CET test to
receive the SMS and visit Voss.
