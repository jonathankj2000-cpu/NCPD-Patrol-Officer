# NCPD Patrol

## v0.11a: milestone equipment, police vehicles and partner assignments

[Download the complete v0.11a test ZIP](https://github.com/jonathankj2000-cpu/NCPD-Patrol-Officer/raw/refs/heads/main/releases/NCPD_Patrol_v0.11a_Career_Rewards_Partners_TEST.zip)

NCPD Career now offers equipment and police vehicle rewards. Its computer page has **Service Record** and **Partner Assignment** tabs. Choose an unlocked partner for your next shift or **Request new partner** from your owned police car's trunk menu. Selection does not immediately replace a partner who is already on duty.

| Incidents resolved | Equipment / vehicle reward | Partner access |
| --- | --- | --- |
| 0 | Existing starting Hella and police uniform remain available | Standard NCPD Patrol Officer |
| 5 | NCPD anti-shrapnel helmet | — |
| 10 | Villefort Cortes NCPD Overlord | — |
| 20 | NCPD reinforced ballistic vest, Lexington Military, Thorton Merrimac Police | NCPD Shotgun Enforcer |
| 35 | Full NCPD Badge Set: coat, pants, boots and goggles | — |
| 50 | Masamune Military, Chevillon Emperor NCPD Ironclad | NCPD Tactical Officer with Defender |
| 75 | Militech Hellhound Man o' War | — |
| 100 | MaxTac helmet, jacket and pants; Defender Military | MaxTac Netrunner |

Career uses **on-duty scanner incidents already recorded by NCPD Patrol**, across shifts and saves. Dispatches and arrests retain their separate totals and payments. Opening a page or unlocking a partner does not add incident credits. At 5 incidents the new rank is Police Officer; the later ranks are Patrol Officer (10), Senior Officer (20), Corporal (35), Sergeant (50), Lieutenant (75) and Captain (100).

**Claim reward** collects the oldest available equipment milestone, one per click. Each successful item or vehicle unlock receives a saved receipt. If a bundle partly fails, **PARTIAL - RETRY** collects the remaining parts without duplicating the parts already issued. Previously claimed prototype cash bonuses remain in the save and do not block the new rewards. The former EUR$1000 career test bonuses are replaced by this catalog; scanner/dispatch/arrest payments are unchanged.

Partner access unlocks automatically at 0/20/50/100 incidents. The selected profile is saved. It uses the existing follower, combat, boarding and revive controller. The Shotgun Enforcer's vanilla record supplies a **Zhuo** despite containing `tactician` in its ID. The Tactical Officer's record supplies an M2067 Defender. MaxTac uses the generic netrunner record, not a named story character. Friendly netrunner quickhacks are **not yet verified in game**.

### Install and test

1. Exit the game. Extract the **entire ZIP** into the game directory containing `bin`, `r6` and `archive`, replacing files. Restart; CET announces **v0.11a**. The new `r6/tweaks/NCPDPatrol_CareerVehicles.yaml` is required for the four reward cars.
2. For the computer page, use the main [Browser Extension Framework 0.9.7](https://www.nexusmods.com/cyberpunk2077/mods/10038) package. At V's apartment computer, open **Net > NCPD Career**. Use **Refresh record** after changing progress/test settings. The address remains `NETdir://ncpd.career`.
3. In CET, under **NCPD CAREER**, press **TEST: Unlock all milestones (session)**. This makes all seven reward bundles and all four partners available. It leaves your real incident count and rank unchanged and grants nothing automatically. Use a test save when collecting rewards: issued equipment/vehicles are saved normally.
4. Claim rewards on the computer or with **Claim next milestone reward** in CET. Check inventory and the vehicle summon menu. Repeated claims and save/load should retain receipts without issuing duplicates.
5. Open **Partner Assignment**, select a profile, then start a shift or use **Request new partner** at the trunk. A CET replacement button and a **Partner assignment (CET fallback)** section are also available. Test follow, combat, passenger boarding, downing and revive for each new profile.
6. **Clear test unlocks**, or load a save, to restore normal requirements. Naturally unlocked partner choices persist across loads. A profile chosen only through the temporary test override falls back to Standard if it is still locked after loading. Clearing test unlocks does not remove rewards already collected.

Browser Extension remains **optional**. Without it, progression, rewards and partner choices work through the CET fallback; the computer page is absent. Other requirements remain the established Cyberpunk 2077 2.5 setup: compatible CET, RED4ext, Codeware, redscript, TweakXL and ArchiveXL. Dependencies are not bundled.

### Validation and limits

[Automated checks](tests/career/README.md) execute authored reward/progression code, partner spawning/replacement, the real CET test-button handlers and the computer tabs/callbacks. Tests cover legacy cash receipt migration, partial native failures, garage unlock confirmation, existing vehicle ownership, saved selection and simulated restore, temporary test access, duplicate clicks and cleanup. They use the actual pinned BEF base/registry with native game/widget boundaries mocked. Existing arrest/trunk/dispatch regressions also pass.

All 22 production redscript files pass source-derived API checks with and without BEF. All 12 Lua modules parse. The complete 44-file install ZIP is verified byte-for-byte. These checks do not replace a game test: real vehicle summoning, the new NPC models/AI, actual save serialization and screen layout/input remain to be tested.

Arrest/dispatch archives and scanner/dispatch/arrest payment logic are preserved. Core changes recognize the four new reward cars after the player-ownership check. Support registration accepts the four catalog partner records; its down/revive/recovery code is unchanged. Ambient or stolen police vehicles do not gain trunk access. Career interface is **2**; main/support **17**, arrest **5**, trunk **2**, journal **2** and browser diagnostics **1** remain unchanged.

[Full instructions](README.txt) · [Previous v0.10b ZIP](https://github.com/jonathankj2000-cpu/NCPD-Patrol-Officer/raw/refs/heads/main/releases/NCPD_Patrol_v0.10b_Career_Browser_Registration_FIX.zip) · [Earlier packages](releases)
