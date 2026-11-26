NCPD PATROL v0.20g - WWISE VOICE FIX
=================================
Complete private branch package. All six Voss briefing WEMs now use the
author's Wwise Vorbis exports, mono 48000 Hz. Each file independently decodes
and matches its correct original WAV. The first-line control was confirmed
in game: Voss and V's reply played without cuts, then the next old WEM cut.
The full updated conversation still needs a game test.

INSTALL
1. Completely exit Cyberpunk. Disable the earlier STOCK SCENE, FIRST LINE,
   Audio Control, VO Lengths, WEM Header and PCM test packages in Vortex.
2. Install this complete package AFTER the main mod, let it win conflicts,
   deploy and restart the whole game. Loading a save alone is not sufficient.
3. CET should now show v0.20g Wwise Voice Fix. The old direct-event comparison
   is disabled, and the rejected length service is inert.

TEST
Use a test save before the briefing or CET > Testing > Quest giver prototype >
TEST: Activate quest giver quest. Use its Clear action if a prior test remains.
Close CET, meet Voss normally and let the full conversation finish. Check all
six Voss lines, all four V replies, pauses and the final transition. Her first
words should be "V. Glad you could make it. Lieutenant Mara Voss, NCPD."
Check that lipsync, subtitles and quest continuation still work as before.

SCOPE
Only the six WEMs change inside the private quest archive. The other ten
resources, scene graph, line IDs, voice map, lipmap, facial bank, workspot,
caption timing and voice schedule match the working v0.20f1 bytes. Existing
overlap guards stay in place. Source/runtime version labels are updated.
There is no new audio API, mixer hook, duration registration or dependency.
Wwise is an authoring tool only; players do not install it.

This package retains the existing duty, dispatch, evidence, wanted, career,
partner, backup and arrest code. It introduces no save/fact migration. The
public Nexus 0.8.7 package is separate and remains unchanged. Existing MIT
and Andrea Olivato attribution remains in THIRD_PARTY_NOTICES.txt.

ROLLBACK
Disable this package and the previous audio experiments, reinstall the
v0.20f1 Dialogue Handoff package, and fully restart the game. The inert
recovery files can remain; the optional NCPDPatrolVoiceAB folder can be removed.
