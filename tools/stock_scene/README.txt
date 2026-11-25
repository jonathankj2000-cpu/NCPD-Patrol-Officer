NCPD PATROL - ORIGINAL GAME VOICES IN THE VOSS SCENE
=================================================
Separate developer control over the complete v0.20f1 private quest package.
This is not the public Nexus 0.8.7 release and is not an audio-cut fix.

The direct-event A/B control was silent in game, so its results cannot compare
the voices. This package disables that helper and uses the existing Voss
conversation, which the author has already heard working in game.

INSTALL
1. Fully exit the game. Disable the earlier VO Lengths, WEM Header and direct
   Audio Control test packages in Vortex. Install this complete package after
   the main mod and let it win conflicts, then deploy and restart the game.
2. This package overwrites the old length service with its inert recovery
   stub and the old NCPDPatrolVoiceAB helper with a disabled notice. It never
   registers custom duration metadata or sends direct native voice events.
3. The main CET banner still says v0.20f1. A full restart is required; loading
   a save alone does not reset cached resources from previous experiments.

RUN THE EXISTING SCENE
1. Use a test save before the Voss briefing, go off duty, then use the existing
   CET Testing > Quest giver prototype > Activate quest giver test. If an old
   test is still active, use its existing clear action before reactivating.
2. Follow the meeting marker and approach Voss normally with CET closed.
   There is no new playback button. The regular quest scene plays all lines.
3. Expected fingerprint: Voss speaks V's short original lines, starting with
   "How should I know? I'm not a criminal." Her own recorded briefing should
   not be heard. She may use V's voice and her long facial clips will not
   match the words. Subtitles may retain the briefing text. These are expected
   test artifacts, not a playable story version.
4. All ten original speech slots and their exact timings are retained, about
   144 seconds total. Voss's substituted lines are short, so leave the long
   pauses running until the scene ends. V's four existing replies are kept.
5. Report whether Voss's replacement lines and V's replies are audible, and
   whether background cuts remain at their starts, ends or scene transitions.
   If Voss still speaks the recorded briefing, a different archive won the
   conflict or the game was not fully restarted. If a replacement is silent,
   report that; silence is not a successful cut-free comparison.

OPTIONAL OUTPUT CHECK
Play a quiet continuous sound in another Windows program during the scene.
If recording, capture the complete shared output mix, not just game audio.
Note whether only Cyberpunk cuts out or the external sound also disappears.

WHAT CHANGES / WHAT THIS PROVES
Only six locstringId.ruid references in conversation.scene are replaced with
the four original V IDs already used by the working scene. Every speech
event, actor, voice flag, section length, pause, edge, workspot, lipsync bank,
quest graph, script and other archive resource stays byte-identical.
No game audio is copied or redistributed. The game's localization resolves
its own installed voice files. All six original Voss WEMs remain unchanged
in the archive but are not referenced by the scene's ten dialogue lines.

This bypasses both the custom voiceover-map lookup and the custom WEMs. It
does not isolate the encoder alone, test an official Wwise re-encode, or prove
that the native line-length metadata and the custom metadata are equivalent.
Cuts with stock voices would argue against custom encoding being necessary
for the failure. No cuts would point toward the custom VO path, not identify
one specific cause. Actual audible playback still needs an in-game test.

ROLLBACK
Disable this test package and the older audio experiments, reinstall the
original v0.20f1 Dialogue Handoff package and fully restart the game. Remove
the separate NCPDPatrolVoiceAB folder if manually installed. The inert length
service can remain disabled. The public 0.8.7 package is unchanged.

CREDIT
The scene and native voice-reference schemas retain the existing Andrea
Olivato MIT attribution in THIRD_PARTY_NOTICES.txt. No external audio or new
framework is included. The native V IDs come from this mod's existing scene.
