# NCPD Patrol

## v0.10b: career browser registration and navigation fix

[Download the complete v0.10b test ZIP](https://github.com/jonathankj2000-cpu/NCPD-Patrol-Officer/raw/refs/heads/main/releases/NCPD_Patrol_v0.10b_Career_Browser_Registration_FIX.zip)

Corrects a real v0.10a API error: `LoadPageByAddress` belongs to `BrowserGameController`, not `BrowserEventsListener`. Refresh/claim now navigate through the controller. Registration is idempotent and is also ensured before the native browser loads website data. The listener uses BEF's actual computer device context.

If the homepage entry is missing, keep that computer's Net browser open, open CET and use **Log career browser diagnostics**. The output reports the compiled BEF module, runtime enabled/bypass/blocked state, browser hooks, per-device registration and page requests. **Open NCPD Career (computer browser)** tests direct navigation on that same computer without changing BEF settings.

Adds an **NCPD Career** page to the in-game computer browser through [Browser Extension Framework](https://www.nexusmods.com/cyberpunk2077/mods/10038). The page shows your rank, progress toward the next promotion, the next milestone reward, and recorded scanner, dispatch and arrest totals.

The career uses scanner activities already recorded by NCPD Patrol while on duty. Existing recorded progress carries over across shifts and saves. Opening or refreshing the page never adds progress or grants money.

| Recorded activities | Rank | Prototype milestone reward |
| --- | --- | --- |
| 0 | Probationary Officer | — |
| 10 | Patrol Officer | €$1000 |
| 20 | Senior Officer | €$1000 |
| 40 | Corporal | €$1000 |
| 60 | Sergeant | €$1000 |
| 80 | Lieutenant | €$1000 |
| 100 | Captain | €$1000 |

The progress bar measures the current promotion interval. For example, at 15 activities the page shows **5/10 in rank**, **15/20 total** and a half-filled bar. Milestones show **LOCKED**, **AVAILABLE** or **CLAIMED**.

**Claim reward** collects the oldest available milestone, one per click. Claims work off duty at a computer. Each successful transfer produces its own **NCPD CAREER REWARD** receipt and is saved once per milestone. Failed transactions leave the reward available for another attempt. These are prototype cash rewards; the reward catalog can later be replaced with confirmed vehicle or equipment rewards. No vehicle, outfit or partner upgrade is granted in this version.

Dispatch and arrest totals are shown separately. They do not grant additional career activity credits. Service rewards, scanner bonuses, €$500 dispatch supplements and arrest payments use separate records.

### Install and test

1. Exit the game, extract the **entire ZIP** into the game directory and replace files. Restart; CET announces **v0.10b**.
2. Install **Browser Extension 0.9.7**, its main framework package, to enable the page. Open a browser-capable computer, such as the one in V's apartment, go to **NETdir://ncity.pub** and select **NCPD Career**. The site address is **NETdir://ncpd.career**.
3. Check your rank, progress and next reward. Use **Refresh record** to reload the snapshot. If you already have recorded milestones, claim one and check the separate receipt. Reopening the site or loading the same updated save must keep that reward claimed.
4. **Cop Stats** at the vehicle trunk also shows the real career summary and points to the computer page.

Browser Extension is optional for the rest of NCPD Patrol. Conditional imports/hooks keep the core mod usable without it. Dependencies otherwise remain those of v0.9b: Cyberpunk 2077 2.5 and compatible CET, RED4ext, Codeware, redscript, TweakXL and ArchiveXL (1.28.8 recommended). Frameworks are not bundled.

### Validation and limits

[Career checks](tests/career/README.md) execute authored rank/reward logic, actual page rendering decisions, real click handlers and browser lifecycle hooks through the shared syntax adapter. Native game/widget calls are mocked. Tests execute the pinned BEF base Init/Uninit and actual Register/Unregister/GetSitesData/GetWebPage methods, including their per-device filtering. Tests cover progression boundaries, existing save records, claim failure/retry, six once-only rewards, save restore, stale contexts, refreshing and callback/registration cleanup without removing other sites. Existing arrest/trunk/dispatch regressions also pass.

All **22 redscript files** pass source-derived API checks with and without BEF, including the actual pinned BEF base class, with zero warnings/errors. The old v0.10a listener navigation call is rejected by the corrected check. This is not compilation against an actual game cache or the user's installed BEF runtime. The career page's physical layout, framework registration and input, and real in-game money/receipt display still need a game test.

The full **43-file ZIP** is checked byte-for-byte. Existing arrest/dispatch archives and scanner/dispatch payment logic are preserved. Only a career-receipt entry point is added to the core, and trunk changes are limited to Cop Stats. Main/support interface **17**, arrest **5**, trunk **2**, journal **2**; career is **1**.

[Full instructions](README.txt) · [Previous v0.9b ZIP](https://github.com/jonathankj2000-cpu/NCPD-Patrol-Officer/raw/refs/heads/main/releases/NCPD_Patrol_v0.9b_Dispatch_Briefings_Rewards_TEST.zip) · [Earlier packages](releases)
