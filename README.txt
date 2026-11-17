NCPD PATROL v0.9b - DISPATCH BRIEFINGS AND COMPLETION SUPPLEMENTS
=============================================================
Six journal briefings and a separate EUR$500 reward for resolving an active,
attended dispatch. Each briefing has one objective and uses the response
deadline, attendance and completion rules introduced in v0.9a.

INSTALL
Exit the game completely. Extract the ENTIRE ZIP into the game directory
containing bin, r6 and archive, replacing files. Restart; CET announces v0.9b.
Install both NCPDPatrol_Dispatch.archive and its .archive.xl file.

Requirements remain Cyberpunk 2077 2.5 and compatible CET, RED4ext, Codeware,
redscript, TweakXL and ArchiveXL. ArchiveXL 1.28.8 is recommended:
https://github.com/psiberx/cp2077-archive-xl/releases/tag/v1.28.8
Dependencies are not bundled. This update adds no new dependency to v0.9a.

JOURNAL VARIETY
- Six authored titles, objectives and briefings are selected randomly without
  consecutive repeats: Incident Response, Unit Requested, Scene Security,
  Patrol Assignment, Incident Check and Area Response.
- Text remains general: respond, assess the scene, resolve threats and secure
  evidence. It does not invent hostages, wounded officers, gangs or NPC counts.
- Only one dispatch can be active. Each briefing is reusable; at most six
  completed/failed entries can remain as history, rather than a per-call log.
- A 3-minute response deadline pauses in menus. Within 60 m, On scene clears
  the deadline. The fight afterwards has no deadline.
- Resolving the assigned scanner after attendance records Succeeded. Timeout
  records Failed, clears the dispatch marker and leaves the scanner available.
- Cancellation/shift end deactivates the entry. Wanted termination fails it.
- Loading closes a saved active dispatch, matching the existing off-duty reset.
  Cleanup covers every briefing and the original v0.9a journal path.
- Busy prevents new automatic calls while existing response deadlines continue.
- The previous tracked story objective is restored only if our dispatch was
  still tracked. Selecting a different objective yourself is respected.
- The existing script marker is used. GPS can require opening/closing the map.

DISPATCH REWARD
- Completing the active assigned scanner after On scene earns EUR$500 EXTRA,
  independent of the scanner bonus and arrest payments. The native controller
  checks that the matching scanner has actually reached CompletedPhase.
- Successful payment queues its own eight-second money notification:
  DISPATCH BONUS PAID: +EUR$500
  The in-game message uses the game's eurodollar symbol. CET logs a matching
  receipt. Other queued notices may appear before this receipt.
- A separate persistent incident ledger prevents repeated callbacks, another
  shift or saving/loading from paying the same incident twice.
- Failed money transactions remain in a persistent earned-payment queue and
  retry in gameplay. They are not marked paid and do not show a paid receipt.
  An earned pending supplement can be delivered after the shift ends or loads.
- Failed, cancelled, replaced, expired or pre-arrival-resolved assignments earn
  no dispatch supplement. Completing an unrelated scanner earns no supplement.
- No retroactive dispatch rewards are issued for calls completed in v0.9a.

TEST
1. Start a shift and request a dispatch. Check its title, objective and briefing.
   Cancel/request a few calls; consecutive titles should differ.
2. Arrive and finish the assigned scanner. Check Completed, the separate
   EUR$500 receipt and CET payment log. The scanner bonus is its own payment.
3. Request a call over 60 m away. Use CET:
   Test timeout: 15 s left (on route)
   Stay away outside menus for 15 gameplay seconds. Check Failed and no
   dispatch supplement. The original scanner should still be playable.
4. Request a call after success/failure, and test cancellation and save/load.
5. If needed use Log dispatch journal diagnostics. Include ready, briefing,
   stage, quest/objective state, dispatch supplements paid and pending.

VALIDATION
Portable checks execute the authored native controller through a syntax
adapter, plus actual CET dispatch/bridge code with native APIs mocked. They
cover all six briefings, tracking, reuse, arrival/deadline, cancellation/load,
matching completion, once-per-incident payments, failed-payment retry across
restore and the separate payment receipt. Arrest/trunk regressions are kept.
All 19 redscript files pass source-derived API contract checks with zero
warnings/errors; this does not replace compilation against the game's cache.
WolvenKit 9.1.1 compiles and round-trips both resources. Packing/extraction and
the complete install ZIP are checked byte-for-byte. Actual journal text/UI,
money and notifications still require an in-game test of this update.

The confirmed arrest archive and partner/backup/trunk gameplay are retained.
The core scanner payment code is identical; only a queued receipt entry point
is added to the core system. The dispatch ledger never edits scanner/arrest
ledgers. Main/support interface 17, arrest 5 and trunk 2 remain; journal is 2.

Earlier full ZIPs remain in the repository releases directory. To return to
v0.9a, end the shift, exit the game and reinstall its entire ZIP.
