# NCPD Patrol

## v0.8c: native trunk tap and hold

**[Download the complete v0.8c test ZIP](https://github.com/jonathankj2000-cpu/NCPD-Patrol-Officer/raw/refs/heads/main/releases/NCPD_Patrol_v0.8c_Native_Trunk_Hold_TEST.zip)**

Fixes v0.8b's **"Trunk input not received"** failure. The native `InteractionActions` context sends only `BUTTON_RELEASED` for `Choice2`; the old custom listener required a press that this action never delivers. The interaction record's `action` is also a String, not CName. v0.8c removes that listener and its custom half-second timer, using two separate native choices:

- **Request NCPD Backup**: short **R**, via `Choice2`.
- **Patrol Menu**: **hold R**, via `Choice2_Hold`, with the game's hold icon and timing (vanilla about **0.3 s**).

Both follow the player's secondary-interaction binding. No new key, input XML or Input Loader dependency is required. The v0.8b countdown compiler fix is retained.

### Install and test

1. Exit the game completely. Extract the **entire ZIP** into the directory containing **bin, r6 and archive**, replacing files, and restart. CET announces **v0.8c**. Main/support interfaces stay **17**, arrests **5**; the trunk bridge is now **2**.
2. Start a shift and approach your owned police car's trunk on foot. Expect the vanilla stash plus **two separate backup/menu prompts**, including the hold icon. Tap R for one backup; hold R until the indicator completes for Patrol Menu. The hold must not also request backup.
3. Check that releasing the opening hold leaves the menu open. Scroll and select with **F**; a fresh **R** closes it. Stash and entry choices return on closing/selecting. Moving away, mounting, game menus, wanted status or shift end also close it.

The release/hold entry callbacks and both actual PS trunk wrappers pass local tests. **The native input manager's physical hold/release arbitration, icons and menu rendering still need an in-game test.** See [installation and behavior details](README.txt).

### Menu


| Choice | Behavior |
| --- | --- |
| Set BUSY / Set AVAILABLE | Pause/resume new automatic dispatch assignments. Busy retains the active assignment, objective and completion/bonus monitoring; manual requests remain available. |
| Request vehicle repair | One free repair after **10 seconds of gameplay**, with request/completion notices. Game menus pause the timer. It repairs the exact requested car; entering or changing cars does not transfer it. Duplicate requests do not stack or reset the timer. Health, tires, deformation, glass and damage effects use native routines. |
| Request new partner | Replace only the mod-created partner. Rejected deletion blocks a new spawn and retains the old ID. |
| Cancel dispatch | Remove the current mod marker/objective without completing or changing the vanilla scanner activity. |
| Request new dispatch | Cancel the assignment, then search for another eligible scanner using the existing 1/1.5/2 km radius tiers. Cleanup failure blocks replacement. Works while Busy. No available alternative means no new assignment. |
| Cop Stats | Show recorded on-duty scanner completions and next milestone: **10, 20, 40, 60, 80, 100, 120...**. Progression rewards are **planned**, not awarded yet. |

Cop Stats reads the existing persistent scanner-payment ledger in the current save. It counts scanner completions whose bonus was registered; activities completed before monitoring was installed are unknown. Arrest payments/counts remain separate. The existing CET automatic-dispatch setting remains a separate preference. New shifts start Available. Pending repairs cancel on shift end, wanted status, loading or loss/destruction of the requested vehicle; destroyed cars are not resurrected.

### Retained behavior

The user reported the remaining controls working through CET. Dispatch/partner/backup controllers, main/support systems, revive interaction wrappers, repair wrapper/timer, Cop Stats/payment logic and all arrest source/YAML/archive are verified unchanged from v0.8b. The confirmed v0.7f lying handcuff resource remains identical. Existing Fast Travel duty, scanner bonus/receipts, dispatch HUD/radio, vehicle chatter and wanted termination remain. GPS can still require opening/closing the map.

### Validation and references

All **11 Lua modules** parse. All **18 redscripts** compile with zero warnings/errors against source-derived API contracts, **not an actual game cache**. [Portable trunk checks](tests/trunk_menu/README.md) execute the authored backup/hold/menu action classes and entry callbacks, both PS trunk wrappers/action-list helpers, stash/menu restoration and existing repair/stats/dispatch/partner logic. The input fixture uses the actual release-only and hold-complete accepted event contract; requiring a raw listener or CName action lookup fails fixtures. Existing scanner, radio, revive, boarding, backup and arrest regressions pass. The original invalid CeilF cast remains rejected by a type regression.

The native hold/release definitions are in [InteractionActions](https://github.com/jackhumbert/cyberpunk2077-input-loader/blob/2758cd8ab54e340f4531a1e0adb13d8b0231d998/fallback/inputContexts.xml). The minimal test excerpt is not installed. Native input arbitration/delivery, UI rendering, real AI/vehicle graphics and native save loading are not emulated. [Arrest tests](tests/arrests/README.md) and [asset sources](assets/arrest/README.md) remain available. Requirements stay game 2.5, matching CET, Codeware 1.21.4, RED4ext 1.31.1, TweakXL and compatible redscript.

### Rollback

The full [v0.8b ZIP](https://github.com/jonathankj2000-cpu/NCPD-Patrol-Officer/raw/refs/heads/main/releases/NCPD_Patrol_v0.8b_Trunk_Compile_Fix_TEST.zip) restores the preceding trunk build. To return to the confirmed [v0.7f ZIP](https://github.com/jonathankj2000-cpu/NCPD-Patrol-Officer/raw/refs/heads/main/releases/NCPD_Patrol_v0.7f_Private_Lying_Loop_TEST.zip), remove `trunk.lua` plus `NCPDPatrolTrunkSystem.reds`, `NCPDPatrolTrunkInteractions.reds` and `NCPDPatrolTrunkVehicle.reds`, then reinstall its complete ZIP. Earlier packages remain in [releases](releases). The arrest archive is identical.

ZIP SHA-256: `ed971e58926822a7df77de74c3f1967717654efc430b2f2aa1d112a84d74662f`
