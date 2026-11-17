NCPD PATROL v0.10b - CAREER BROWSER REGISTRATION FIX
==========================================
NCPD Career appears in the in-game computer browser through Browser Extension
Framework. It shows rank, promotion progress, next reward, milestones and
recorded scanner/dispatch/arrest totals. No CET menu is needed for normal use.

INSTALL
Exit the game. Extract the ENTIRE ZIP into the game directory containing bin,
r6 and archive, replacing files. Restart; CET announces v0.10b.
For the computer page install the main Browser Extension 0.9.7 framework:
https://www.nexusmods.com/cyberpunk2077/mods/10038
Do not install its CustomSiteExample in place of the main framework.
The page hooks are optional; the rest of NCPD Patrol still works without BEF.
Existing v0.9b dependencies remain: Cyberpunk 2077 2.5 and compatible CET,
RED4ext, Codeware, redscript, TweakXL and ArchiveXL (1.28.8 recommended).
Dependencies are not bundled.

OPEN THE PAGE
Use a browser-capable computer, such as V's apartment computer. Open the Net
browser homepage NETdir://ncity.pub and click NCPD Career. The site uses BEF's valid default placeholder icon; click the NCPD Career name.
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

BROWSER FIX / DIAGNOSTICS
v0.10a used LoadPageByAddress on the wrong object. BEF defines it on
BrowserGameController; refresh and claim now use that controller. Initialization
is idempotent, and registration is ensured before SetWebsiteData loads the
homepage. The listener uses BEF's actual computer device, not a guessed owner.

If the entry is still absent, keep the computer's Net browser open and use CET:
 Log career browser diagnostics
This reports BEF module presence, runtime enabled/bypass state, address blocking,
init hooks, actual per-device registry matching and page requests.
 Open NCPD Career (computer browser)
This tests direct navigation on the current computer. It does not enable BEF,
remove address blocks or bypass framework restrictions. Send the diagnostic
line if normal homepage access still fails. For compilation failures send the
current redscript log instead.

VALIDATION
All 22 production redscript files pass source-derived API checks with BEF's
actual pinned base class and with BEF absent. The old listener navigation call
is rejected by the corrected API check. Tests execute BEF's actual Init/Uninit,
Register/Unregister and per-device GetSitesData/GetWebPage methods. Native game
calls, rendering/input and framework configuration are mocked. Pinned reference
sources are downloaded only by developer tests and are not installed in game.
Career/payment, callback cleanup, delayed initialization and diagnostics checks
pass, along with prior arrest/trunk/dispatch regressions. All 12 Lua modules
parse. The 43-file ZIP is validated byte-for-byte. Actual screen visibility,
input and the user's installed runtime still need an in-game test.

Confirmed arrest/dispatch archives and payment logic are preserved. The core
receives only a new queued career receipt method. Trunk changes are limited
to Cop Stats. Main/support 17, arrest 5, trunk 2, journal 2; new career 1.

ROLLBACK
To return to v0.9b, exit the game and remove these three career files:
 r6/scripts/NCPDPatrol/NCPDPatrolCareerSystem.reds
 r6/scripts/NCPDPatrol/NCPDPatrolCareerBrowser.reds
 r6/scripts/NCPDPatrol/NCPDPatrolCareerBrowserState.reds
Then reinstall the entire v0.9b ZIP. Earlier packages remain on GitHub.
