NCPD PATROL v0.5b - LONGER NOTICES / ALERT SOUND / RADIO PREVIEW
============================================================
Based on v0.5a dispatch and v0.4c bonus/receipt, confirmed in game by the user.
The new notice timing, sound and native radio preview need an in-game check.

NEW IN v0.5b
 - New dispatch and Incident resolved notifications last 8 seconds each.
 - On scene and cancellation stay at 4 seconds.
 - Patrol notifications share a session-bound queue. A bonus receipt no longer
   interrupts Resolved after two seconds. Each queued notice gets its duration.
 - Money still transfers immediately. Its receipt becomes eligible after two
   seconds and waits for earlier patrol notices to finish before displaying.
 - A short existing ui_phone_sms alert sounds when an assignment notice actually
   appears. It is a notification signal, not a looping vehicle siren.
 - CET includes Mute/Enable dispatch alert and Test dispatch alert.
 - CET includes Preview police radio (in vehicle), requesting the game's existing
   nc_heat_1_start line through PoliceRadioSystem. Its documented use is a pursuit
   call. Previewing requests audio without changing heat, district or police AI.
 - A suitable spoken on-scene briefing has not been selected. This build does
   not automatically play pursuit dialogue on arrival. Use the preview to judge
   the wording and audibility before choosing an appropriate briefing.

INSTALL / UPDATE
1. Exit Cyberpunk 2077 completely.
2. Extract the complete ZIP into the game folder containing bin and r6.
3. Replace the NCPDPatrol files, including the new NCPDPatrolNotice.reds file.
4. Restart the game, load a save and start a shift.
Requirements are the same as v0.5a: Cyberpunk 2077 2.5, matching CET, Codeware
1.21.4, RED4ext 1.31.0+, TweakXL and compatible redscript. No new dependency.

QUICK TEST
1. Open CET > NCPD Patrol > DISPATCH and click Test dispatch alert.
2. Start a shift and click Request dispatch now. Confirm the eight-second call
   notification and a single alert when it appears. Earlier notices can delay it.
3. On arrival, check the same four-second On scene message and HUD objective.
4. Complete the scanner and collect evidence. Confirm Resolved lasts eight
   seconds, followed by the patrol bonus receipt, with only one money transfer.
5. Test Mute dispatch alert; the explicit Test button still auditions the sound.
6. In a parked vehicle, try Preview police radio (in vehicle). Report whether it
   is audible and what the dispatcher says, so a fitting on-scene line can be chosen.

RETAINED DISPATCH
One existing active, unfinished Assault in Progress / Suspected Organized Crime
activity is assigned at a time. Incidents within 2.5 km are preferred. The first
automatic call waits 30-60 seconds, then 60-120 seconds after resolution/cancel.
Automatic countdowns pause in menus/combat. Request dispatch now skips the wait;
Cancel active dispatch clears the assignment without changing the vanilla scanner.
End Shift/load reset cleans tagged dispatch markers. The Custom Position waypoint
and in-game objective display from v0.5a remain. The normal road GPS line has not
been independently verified. The existing scanner ledger handles the EUR$1000
bonus and prevents duplicate payments; dispatch/audio/notifications add no money.
Terminal duty, partner AI, boarding, Hella and uniform controls are retained.

VALIDATION / LIMITS
The redscript files pass syntax/type checking against source-derived API
contracts with redscript 1.0.1, not the actual Cyberpunk 2.5 script cache. Lua
modules pass LuaJIT loading. Authored native reward/notice logic is exercised
through a syntax adapter with chronological native delay mocks. Checks cover
8/4/8-second notice order, delayed receipt isolation, no extra transfers, alert
timing/duplicates/mute, audio preview controls, stale-session callbacks and missing
delay fallback, plus previous dispatch/reward/partner/boarding regressions.
Actual sound audibility, the spoken line's wording and live HUD timing need an
in-game check. No new sound assets or custom spoken lines are supplied.

ROLLBACK
Exit the game, remove r6/scripts/NCPDPatrol/NCPDPatrolNotice.reds, and reinstall
the complete v0.5a ZIP. The previous v0.5a and v0.4c ZIPs remain on GitHub.
