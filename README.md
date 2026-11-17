# NCPD Patrol

## v0.8b: trunk menu compiler fix

**[Download the complete v0.8b test ZIP](https://github.com/jonathankj2000-cpu/NCPD-Patrol-Officer/raw/refs/heads/main/releases/NCPD_Patrol_v0.8b_Trunk_Compile_Fix_TEST.zip)**

v0.8b fixes the exact `NO_MATCHING_OVERLOAD` error reported in both game-2.50 compiler logs at `NCPDPatrolTrunkSystem.reds:87`. `CeilF(Float)` already returns `Int32`; the repair countdown now returns it directly, removing the invalid `Cast<Int32>`. The previous local contract mistakenly declared a Float return. A new type regression compiles the actual corrected getter and requires the original expression to fail with the same verified signature. The remaining gameplay code is unchanged from v0.8a.

At your owned police car's trunk while **ON DUTY**, **tap and release R for backup** or **hold about 0.5 seconds for Patrol Menu**. The native secondary interaction binding is used, so remapping applies. Scroll the choice list and select with **F**; a fresh **R** closes it. The vanilla stash returns when the menu closes. If the game delivers the interaction event on release, the held menu opens then.

The user confirmed v0.7f arrests pay and suspects remain lying in handcuffs. **Arrest source and the compiled archive are unchanged in v0.8b.**

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

### Install and test

1. Exit the game. Extract the **entire ZIP** into the game directory containing **bin, r6 and archive**, replacing files. Restart; CET announces **v0.8b**. Main/support interfaces remain **17**, arrest interface **5**, and the independent trunk bridge is **1**.
2. Start a shift, approach your owned police car's trunk, then test a short R tap versus a hold. A hold must not also request backup. Releasing the opening hold must leave the menu open. Stash F must return on closing.
3. Test Busy with an active assignment, manually request another call while Busy, and switch Available again. Try repair on a damaged vehicle, enter it while waiting, and check the ten-second completion and visible damage reset. Try partner replacement and Cop Stats.
4. Menu layout, native input/event delivery and visible repair effects still need an in-game test. Report the displayed notice and **Patrol menu** CET lines if tap/hold fails. Existing GPS behavior still may require opening/closing the map.

No new hotkey or runtime dependency is required. Existing Fast Travel duty controls, scanner bonuses, dispatch/radio/HUD, vehicle-local chatter, wanted termination, partner follow/combat/boarding/revive, one backup patrol and separate EUR$250 lying arrests are retained. See [installation and behavior details](README.txt).

### Validation

All **11 Lua modules** parse in LuaJIT. The repaired getter passes the real-return-type contract and the original cast is rejected. All **18 redscripts** compile with **zero warnings/errors** against source-derived API contracts, **not the actual game cache**. [Portable trunk checks](tests/trunk_menu/README.md) execute authored native input/menu/repair/stats logic and actual CET dispatch/partner/bridge modules with native boundaries mocked. They cover event orders and duplicate suppression, no backup without a trunk action, missing input failing closed, scope/closing, Busy versus active/manual calls, waypoint cleanup failure, exact-vehicle repair timing/pause/repeat/cancellation, partner replacement failure, read-only milestones, and duty/world cleanup. Existing reward, dispatch/radio, partner/revive/boarding, backup and arrest checks pass.

[Arrest checks](tests/arrests/README.md) and [asset build sources](assets/arrest/README.md) remain available. Arrest source/YAML/archive and revive interaction wrappers are verified byte-for-byte unchanged from the confirmed v0.7f base. Native input delivery, choice-list rendering, vehicle graphics/physics, real AI and native save loading are not emulated. Requirements remain game 2.5, matching CET, Codeware 1.21.4, RED4ext 1.31.1, TweakXL and compatible redscript.

### Rollback

Exit the game, remove the four new files below, and reinstall the complete [v0.7f ZIP](https://github.com/jonathankj2000-cpu/NCPD-Patrol-Officer/raw/refs/heads/main/releases/NCPD_Patrol_v0.7f_Private_Lying_Loop_TEST.zip):

- `bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrol/trunk.lua`
- `r6/scripts/NCPDPatrol/NCPDPatrolTrunkSystem.reds`
- `r6/scripts/NCPDPatrol/NCPDPatrolTrunkInteractions.reds`
- `r6/scripts/NCPDPatrol/NCPDPatrolTrunkVehicle.reds`

Older complete ZIPs remain in [releases](releases). The v0.7f arrest archive is identical.

ZIP SHA-256: `16499f4ca45a3ee1faacc51271667c473d282f48d7314e04b03c19ea524e1571`
