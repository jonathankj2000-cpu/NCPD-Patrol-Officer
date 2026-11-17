NCPD PATROL v0.10a - CAREER COMPUTER PAGE TEST
==========================================
NCPD Career appears in the in-game computer browser through Browser Extension
Framework. It shows rank, promotion progress, next reward, milestones and
recorded scanner/dispatch/arrest totals. No CET menu is needed for normal use.

INSTALL
Exit the game. Extract the ENTIRE ZIP into the game directory containing bin,
r6 and archive, replacing files. Restart; CET announces v0.10a.
For the computer page install the main Browser Extension 0.9.7 framework:
https://www.nexusmods.com/cyberpunk2077/mods/10038
Do not install its CustomSiteExample in place of the main framework.
The page hooks are optional; the rest of NCPD Patrol still works without BEF.
Existing v0.9b dependencies remain: Cyberpunk 2077 2.5 and compatible CET,
RED4ext, Codeware, redscript, TweakXL and ArchiveXL (1.28.8 recommended).
Dependencies are not bundled.

OPEN THE PAGE
Use a browser-capable computer, such as V's apartment computer. Open the Net
browser homepage NETdir://ncity.pub and click NCPD Career. It is a text link;
this prototype does not need a custom website icon archive.
Site address: NETdir://ncpd.career
The page shows a snapshot. Refresh record reloads it; claiming also refreshes.
Cop Stats at the vehicle trunk now shows the actual career summary and points
to the computer page.

PROGRESSION
Recorded on-duty scanner activities determine rank. These are the same saved
activity records NCPD Patrol has already maintained, so existing recorded
progress is included. Activities completed before the mod recorded them are
unknown and are not reconstructed. Dispatches and arrests are separate totals,
not additional career activity credits for the same scanner.

    0   Probationary Officer
   10   Patrol Officer
   20   Senior Officer
   40   Corporal
   60   Sergeant
   80   Lieutenant
  100   Captain

The progress bar is relative to the current rank. At 15 recorded activities:
Patrol Officer, 5/10 in rank, 15/20 total, 50 percent toward the next promotion.
At 100 or more, the bar is full and all current milestones are reached.

REWARDS
Each milestone currently offers a prototype EUR$1000 service bonus. These cash
rewards test the claim flow before vehicle/equipment rewards are selected.
They are defined centrally in the career controller. This version does not
unlock a vehicle, outfit or stronger partner.

Claim reward pays the oldest available milestone, one per click. A successful
native transaction saves that milestone as claimed and queues a distinct
NCPD CAREER REWARD money receipt. Claims do not spend progress or reduce rank.
Failed transactions leave the milestone available. Repeated clicks and loading
the updated save cannot pay the same milestone again. All six test rewards
sum to EUR$6000. Claims are allowed off duty, but not during combat, wanted
status, death or a detached/unloaded game context.

The page distinguishes LOCKED, AVAILABLE and CLAIMED milestones. Promotions
are based on activity progress, whether or not you have collected the reward.
The next reward line describes the next upcoming promotion; unlocked unclaimed
rewards are listed as AVAILABLE and can still be collected.

Service rewards, scanner bonuses, dispatch supplements and arrests maintain
separate records/receipts. No money is granted by opening or refreshing a page.
Previously earned eligible milestones are available for manual claiming.

TEST
1. Open NCPD Career and check its rank, totals, progress and next reward.
2. Refresh/reopen several times; progress and money must stay unchanged.
3. If a milestone is available, claim it. Check the service receipt and CLAIMED
   state. Reopen and save/load to confirm that the claim remains recorded.
4. Confirm Cop Stats now agrees with the page's scanner count and rank.
5. If the entry is absent, check that Browser Extension is installed/enabled.
   Compilation errors need the redscript log; visual/input issues need the
   observed behavior and a screenshot of the page.

VALIDATION
All 21 authored redscript files pass offline source-derived API/BEF shape
contract checks with and without BEF, with zero warnings/errors. Portable tests
execute the career controller, page rendering choices, click handlers and
browser registration/cleanup hooks with native widget and BEF calls mocked.
Arrest/trunk/dispatch regressions also run; all 12 Lua modules parse. The full
42-file ZIP is validated byte-for-byte. This does not establish actual game
cache compatibility, BEF runtime behavior, screen layout or physical input.
Those are the purpose of the in-game test of this version.

Confirmed arrest/dispatch archives and payment logic are preserved. The core
receives only a new queued career receipt method. Trunk changes are limited
to Cop Stats. Main/support 17, arrest 5, trunk 2, journal 2; new career 1.

ROLLBACK
To return to v0.9b, exit the game and remove these two new files:
 r6/scripts/NCPDPatrol/NCPDPatrolCareerSystem.reds
 r6/scripts/NCPDPatrol/NCPDPatrolCareerBrowser.reds
Then reinstall the entire v0.9b ZIP. Earlier packages remain on GitHub.
