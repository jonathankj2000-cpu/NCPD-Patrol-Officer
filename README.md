# NCPD Patrol

## v0.12a: NCPD personnel portal

[Download the complete v0.12a test ZIP](https://github.com/jonathankj2000-cpu/NCPD-Patrol-Officer/raw/refs/heads/main/releases/NCPD_Patrol_v0.12a_Career_Portal_UI_TEST.zip)

The career computer page is now a departmental personnel portal. It reads the computer browser's content viewport and scales its layout to fill the available area, including wider displays. A permanent sidebar provides three sections:

- **Service Record:** current rank and service grade, promotion progress, the next reward, incident/dispatch/arrest totals, issued rewards, a seven-step milestone track and your selected partner.
- **Rewards & Equipment:** all seven reward allocations as cards, with **LOCKED**, **AVAILABLE**, **PARTIAL - RETRY** or **CLAIMED** status, weapon tiers, partner access and a collection desk.
- **Partner Assignment:** four profile cards with role, equipment, service requirement, access progress and assignment controls.

The portal uses navy panels, cyan accents, gold action buttons, hover feedback and a persistent latest-update panel. **Refresh record** updates the snapshot after progress or CET test settings change. Rendering a page never issues rewards. The career model, saved receipts, partner behavior and fixed weapon tiers are unchanged from v0.11b.

### Rewards and partners

Weapon rewards now have a fixed tier based on their milestone: **Tier 2 through 20 incidents, Tier 3 through 50, Tier 4 through 75, Tier 5 above 75**. The current catalog therefore gives Lexington Military **Tier 2**, Masamune Military **Tier 3** and Defender Military **Tier 5**. The 75-incident milestone still awards the Hellhound; it has no weapon reward. Reward-only records inherit the Military presets and use the game's fixed Uncommon/Rare/Legendary qualities, including their disabled random +/- tier rolls. Normal world/vendor weapons and already-owned items are not changed.

Already claimed v0.11a rewards stay claimed. To retest tiers, enable **TEST: Unlock all milestones (session)**, then press **TEST: Give tiered reward weapons**. This delivers one new copy of each reward gun per session, without changing incident totals, rewards already claimed, money or vehicles. Test copies remain in inventory if you save. A partial delivery can be retried without repeating the successful test copies.

Choose an unlocked partner for your next shift or **Request new partner** from your owned police car's trunk menu. Selection does not immediately replace a partner who is already on duty.

| Incidents resolved | Equipment / vehicle reward | Partner access |
| --- | --- | --- |
| 0 | Existing starting Hella and police uniform remain available | Standard NCPD Patrol Officer |
| 5 | NCPD anti-shrapnel helmet | — |
| 10 | Villefort Cortes NCPD Overlord | — |
| 20 | NCPD reinforced ballistic vest, Lexington Military (Tier 2), Thorton Merrimac Police | NCPD Shotgun Enforcer |
| 35 | Full NCPD Badge Set: coat, pants, boots and goggles | — |
| 50 | Masamune Military (Tier 3), Chevillon Emperor NCPD Ironclad | NCPD Tactical Officer with Defender |
| 75 | Militech Hellhound Man o' War | — |
| 100 | MaxTac helmet, jacket and pants; Defender Military (Tier 5) | MaxTac Netrunner |

Career uses **on-duty scanner incidents already recorded by NCPD Patrol**, across shifts and saves. Dispatches and arrests retain their separate totals and payments. Opening a page or unlocking a partner does not add incident credits. At 5 incidents the new rank is Police Officer; the later ranks are Patrol Officer (10), Senior Officer (20), Corporal (35), Sergeant (50), Lieutenant (75) and Captain (100).

**Claim reward** collects the oldest available equipment milestone, one per click. Each successful item or vehicle unlock receives a saved receipt. If a bundle partly fails, **PARTIAL - RETRY** collects the remaining parts without duplicating the parts already issued. Previously claimed prototype cash bonuses remain in the save and do not block the new rewards. The former EUR$1000 career test bonuses are replaced by this catalog; scanner/dispatch/arrest payments are unchanged.

Partner access unlocks automatically at 0/20/50/100 incidents. The selected profile is saved. It uses the existing follower, combat, boarding and revive controller. The Shotgun Enforcer's vanilla record supplies a **Zhuo** despite containing `tactician` in its ID. The Tactical Officer's record supplies an M2067 Defender. MaxTac uses the generic netrunner record, not a named story character. Friendly netrunner quickhacks are **not yet verified in game**.

### Install and test

1. Exit the game. Extract the **entire ZIP** into the game directory containing `bin`, `r6` and `archive`, replacing files. Restart; CET announces **v0.12a**. Include both bundled career tweak files.
2. For the computer page, use the main [Browser Extension Framework 0.9.7](https://www.nexusmods.com/cyberpunk2077/mods/10038) package. At V's apartment computer, open **Net > NCPD Career**. Check all three sidebar sections, text readability, hover feedback and clicks on your screen. Use **Refresh record** after changing progress/test settings. The address remains `NETdir://ncpd.career`.
3. In CET, under **NCPD CAREER**, press **TEST: Unlock all milestones (session)**. This makes all seven reward bundles and all four partners available. It leaves your real incident count and rank unchanged and grants nothing automatically. Use a test save when collecting rewards: issued equipment/vehicles are saved normally.
4. Claim rewards on the computer or with **Claim next milestone reward** in CET. Check inventory and the vehicle summon menu. Repeated claims and save/load should retain receipts without issuing duplicates.
5. Open **Partner Assignment**, select a profile, then start a shift or use **Request new partner** at the trunk. A CET replacement button and a **Partner assignment (CET fallback)** section are also available. Test follow, combat, passenger boarding, downing and revive for each new profile.
6. **Clear test unlocks**, or load a save, to restore normal requirements. Naturally unlocked partner choices persist across loads. A profile chosen only through the temporary test override falls back to Standard if it is still locked after loading. Clearing test unlocks does not remove rewards already collected.

Browser Extension remains **optional**. Without it, progression, rewards and partner choices work through the CET fallback; the computer page is absent. Other requirements remain the established Cyberpunk 2077 2.5 setup: compatible CET, RED4ext, Codeware, redscript, TweakXL and ArchiveXL. Dependencies are not bundled.

### Validation and limits

[Automated checks](tests/career/README.md) execute authored reward/progression code, partner spawning/replacement, the real CET test-button handlers and all three computer pages. Portal checks exercise the native viewport lookup helpers, layout bounds at five viewport sizes, routes, hover feedback, callback cleanup, stale pages, missing viewports and detached devices. They use the actual pinned BEF base/registry with native game/widget boundaries mocked. Existing reward/save/partner/arrest/trunk/dispatch regressions also pass.

All 22 production redscript files pass source-derived API checks with and without BEF. All 12 Lua modules parse. The complete 45-file install ZIP is verified byte-for-byte. Offline layout previews use the authored widget tree; they do not reproduce the game's renderer. Real computer scaling, text rendering and pointer hit testing still need a game test, as do the item tiers/appearance/tooltips under testing in v0.11b.

Arrest/dispatch archives, core/support logic, career progression/reward logic, vehicle and weapon tweaks, and partner behavior are byte-for-byte unchanged from v0.11b. Browser diagnostics now include viewport dimensions, UI scale and whether fallback dimensions were used. Career interface is **3**; main/support **17**, arrest **5**, trunk **2**, journal **2** and browser diagnostics **1** remain unchanged.

[Full instructions](README.txt) · [Previous v0.11b ZIP](https://github.com/jonathankj2000-cpu/NCPD-Patrol-Officer/raw/refs/heads/main/releases/NCPD_Patrol_v0.11b_Milestone_Weapon_Tiers_TEST.zip) · [Earlier packages](releases)
