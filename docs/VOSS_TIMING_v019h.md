# v0.19h — Voss turn and caption timing

The user confirms that v0.19g1 plays the conversation successfully, but reports
that V sometimes answers one or two seconds before Voss finishes and that
captions advance early. The native crash/data correction from v0.19g1 remains.

Previously, each Voss event lasted only the larger of the measured WEM and
lipsync durations. Its section ended another 200 ms later. That schedule has
no allowance for voice startup latency. Existing caption changes anticipated
their measured phrase starts by 100 ms. These are concrete timing weaknesses;
without a game recording or supported playback-completion callback, they do
not establish the engine's exact latency or its underlying cause.

The timing policy now has three explicit values in the authored contract:

- Voss's complete dialogue event gets 2,250 ms beyond its media duration.
- Each dialogue section has a further 500 ms tail before its normal output.
- Internal caption changes occur 1,000 ms after the measured phrase starts;
  their previous 100 ms anticipation is removed. The first caption stays
  visible immediately when the native line appears.

The extra event time keeps the native line/subtitle lifetime open. It does
not re-encode, slow, trim, split or repeat the audio or lipsync files. The
shared 300 ms scene lead-in remains. Short adjoining captions are merged,
including “And V?” with the final sentence: 19 blocks instead of 23, with a
minimum authored hold of three seconds. All original words and the ten-turn
order are retained, as are all four original V IDs and their scene slots.

Andrea Olivato's pinned `fixer01_face.scene.json` uses millisecond timelines
with line padding: inspected mod-owned WEMs a01, a04 and a07 are respectively
2.26, 11.48002 and 6.6 seconds, with events 2.610, 11.830 and 6.950 seconds.
That is approximately 350 ms beyond the files. This supports keeping timing
headroom, but does not prove a fixed native startup delay. The larger allowance
here is a conservative response to the user's one-to-two-second overlap.
Reference: `andreaolivato/cyberpunk-codes`, commit
`4aeaad5d235e3a0244c0f1857757d1b01cbcd58e`, scene blob
`82f4a677128dff4765fe66276c7eefa8b8b2ce2d`; existing MIT credit is retained.

`check_timing.py` walks the authored graph, reads lengths independently from
the actual WEM containers, and checks a 0–2 second playback-start envelope.
It rejects the shipped v0.19g1 schedule and an insufficient line event even
if its section is long enough. It checks caption reading time and byte-identical
media/native V replies. The executed subtitle-wrapper tests cover the delayed
switches and stale callback guards. These are offline scheduling checks; actual
voice completion, scene clocks and UI timing require another in-game test.

Only the private scene archive, Voss subtitle controller and release labels
change in the runtime package. Production dispatch, all 54 Officer Down sites,
the other eight archives, native quest bridge, SMS, waiting pose, LookAt,
actor retention/cleanup, rewards and saved evidence are preserved.

Clear the old quest-giver test before updating, or use a save from before its
activation. Install the complete 123-file package and fully restart. Activate
the same OFF DUTY test, then let all ten turns finish without skipping. Check
that V waits through Voss's final words, that captions follow the speech, and
that the quest completes after the last line. Test both player voice variants
when possible; their original game audio lengths are still not measured here.
