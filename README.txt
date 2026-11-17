NCPD PATROL v0.9a - DISPATCH JOURNAL / RESPONSE DEADLINE TEST
==========================================================
One reusable native journal entry with one objective, driven by the existing
scanner dispatcher. The current marker is retained; native quest GPS is not
introduced. The v0.8c trunk controls and confirmed arrest system are retained.

REQUIREMENTS AND INSTALL
1. Install ArchiveXL for Cyberpunk 2077 2.5 (1.28.8 recommended):
   https://github.com/psiberx/cp2077-archive-xl/releases/tag/v1.28.8
   ArchiveXL is a NEW dependency and is not bundled. Existing CET, RED4ext,
   Codeware, redscript and TweakXL requirements remain.
2. Exit the game completely. Extract the ENTIRE ZIP into the game directory
   containing bin, r6 and archive, replacing files. Restart; CET says v0.9a.
   Install BOTH NCPDPatrol_Dispatch.archive and its .archive.xl file.
   Do not install the assets/tools/tests folders from the source repository.
3. Start a shift and request a dispatch. Look in the normal quest journal for
   NCPD Dispatch with one objective: Resolve the marked NCPD incident.
   The journal entry is reused; this is not an unlimited permanent call history.

BEHAVIOR
- A dispatch begins with a 3-minute RESPONSE deadline shown in the dispatch HUD.
  Menus pause it; invalid/oversized frame deltas do not consume it.
- Within 60 m the controller records On scene and clears the deadline. There
  is no deadline for the following fight. Arrival is checked before expiry,
  independently of slower scanner-completion polling.
- Resolving the assigned scanner after attendance sets the objective/phase/
  quest to Succeeded, and increments completed dispatches.
- Missing the response deadline sets them to Failed and clears our marker/HUD.
  The original scanner remains available. Its existing bonus rules still apply.
- An incident resolved before attendance withdraws the assignment without a
  completed-dispatch credit.
- Manual cancellation and shift end deactivate our entry. Wanted termination
  records failure. The previous tracked story objective is restored only if our
  dispatch was still tracked; a player's newer selection is respected.
- Busy pauses NEW automatic calls; an existing response deadline continues.
- Loading a save ends the current duty session as before. An old active journal
  entry is deactivated on the next loaded-world tick. Completed/failed history
  remains until the next assignment resets the single reusable entry.
- No new payment is issued by journal success/failure. Scanner and arrest money,
  ledgers and receipts are unchanged. There is no progression system in this test.
- Missing journal resources or rejected activation/reset produce diagnostics
  instead of pretending that a native journal quest was created.

MANUAL TEST
1. Request a dispatch, check its journal/objective and countdown, then arrive.
   Confirm the timer disappears. Resolve the scanner and check Completed.
2. Request another call more than 60 m away. In CET use:
   Test timeout: 15 s left (on route)
   Stay away and outside game menus for 15 gameplay seconds; check Failed,
   cleared marker, and that the vanilla scanner is still available.
3. Request another call after failure. Check reactivation and cancellation.
4. Save/load during an active call. The shift should be off and the active
   dispatch should close, while previously paid money remains unchanged.
5. If the journal is absent, refuses reuse or looks wrong, send the CET
   Log dispatch journal diagnostics output. It reports readiness, requested
   stage and actual quest/objective states.

VALIDATION AND LIMITS
The authored journal/localization compile and round-trip in WolvenKit 9.1.1.
The build checks one quest/phase/objective, its localization keys, no journal
mappin at the origin, and exact archive extraction bytes. Portable tests run the
authored native controller through a syntax adapter with native APIs mocked,
plus the actual CET dispatcher/bridge and existing arrest/trunk regressions.
A source-derived native API contract compile completed locally before the
execution environment disconnected. Hosted checks package the install ZIP.
These do not establish native cache compatibility, rendered quest UI,
reactivation behavior or native save loading; those require the game test.
The scripted-quest cloning APIs which returned false in the examined game
source are not used. Only our own journal paths are written.

PRESERVED / ROLLBACK
Partner/revive/boarding, backup, scanner payments, main/support systems, native
trunk controls and arrest code/archive are retained. GPS may still require
opening/closing the map.
To return to v0.8c, exit the game and remove these four added install files:
  bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrol/dispatch_journal.lua
  r6/scripts/NCPDPatrol/NCPDPatrolDispatchJournalSystem.reds
  archive/pc/mod/NCPDPatrol_Dispatch.archive
  archive/pc/mod/NCPDPatrol_Dispatch.archive.xl
Then reinstall the complete v0.8c ZIP. Earlier packages remain on GitHub.
