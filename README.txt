NCPD PATROL v0.3b - AUTOMATIC SHIFT PARTNER
========================================

Start Shift now automatically calls one NCPD partner. No targeting or capture
is required. The existing duty hotkey also starts a shift with a partner.

The partner uses Character.cvi_ncpd_police_ranged2_copperhead_ma, matching the
record shown in your working v0.3a test (length 47, CRC32 0x1FF388A3).
The native follower role, follow commands, and entity deletion method are
retained from that tested version.

BEHAVIOUR
 - Start Shift: request one partner, then assign the existing follower AI
   after the spawned actor becomes available.
 - Dismiss partner: remove your partner for the rest of this shift.
 - Spawn partner: manually call a replacement while on duty, if wanted.
 - End Shift: dismiss the spawned or pending partner.
 - A second spawn request is blocked while a partner is active or pending.
 - If spawning fails, diagnostics show the error. Use Spawn partner to retry.
 - Shift state resets on game reload, as before.

REQUIREMENTS FOR YOUR CYBERPUNK 2077 2.5 SETUP
 - Cyber Engine Tweaks 1.38.0 or newer with support for patch 2.5.
 - Codeware 1.21.4.
 - RED4ext 1.31.0 or newer (your reported version: 1.31.1).
 - TweakXL for the bundled police Hella tweak.

INSTALL / UPDATE FROM v0.3a
1. Exit the game.
2. Extract this ZIP into the Cyberpunk 2077 installation directory, where
   the bin and r6 folders are located. Replace both NCPDPatrol Lua files.
3. Start the game and load a save. Open CET -> NCPD Patrol - v0.3b.
4. Click Start Shift, then close CET and allow the partner to appear.
5. Check following, vehicle entry, combat, Dismiss partner and End Shift.

The police Hella YAML, car controls, outfit handling and existing hotkey ID
are preserved. This package replaces v0.3a; do not run both versions.

VALIDATION
The user confirmed v0.3a spawning, following, vehicle entry, combat assistance,
Dismiss and End Shift in game after updating CET. The v0.3b changes are checked
with a simulated CET/Codeware Lua runtime; this build has not been run in game
by the author of this update. Gameplay should be checked in your setup.

Diagnostics are shown at the bottom of the mod window and printed to CET.
