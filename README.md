# NCPD Patrol

## v0.15b: 10-4 backup stand-down

[Download the complete v0.15b test ZIP](https://github.com/jonathankj2000-cpu/NCPD-Patrol-Officer/raw/refs/heads/main/releases/NCPD_Patrol_v0.15b_Backup_10-4_Stand_Down_TEST.zip)

At your owned police car's trunk, **hold R > 10-4 - Release backup** while a patrol is assigned. This removes the two backup officers' follower roles and their automatic attempts to join V's car. They remain on scene. Seated officers receive an animated exit request when their actual vehicle is stationary; **wait for them to get out before driving away**. The primary partner is unaffected.

This does **not despawn** the patrol at 10-4. Existing cleanup removes it only after you leave more than 150 m from the release area, car and officers for three seconds. The reservation stays occupied until deletion is confirmed, including asynchronous/failed deletion. Pending requests with no deployed actors are simply cancelled. Normal backup still follows and can board if you do not use 10-4. A CET **10-4: Release backup** button is available for testing.

Install the **entire ZIP** and restart, including updated redscript and interaction tweaks. Trunk interface is now **3**. All v0.15a readiness, 17 cyberpsycho variants, VIP/ambush, aftermath and tyre repair are included. Eight portable suites and offline API checks pass; actual role clearing and animated exits need a game test.

## v0.15a: officer readiness and 17 cyberpsycho variants

[Download the complete v0.15a test ZIP](https://github.com/jonathankj2000-cpu/NCPD-Patrol-Officer/raw/refs/heads/main/releases/NCPD_Patrol_v0.15a_Officer_Readiness_Cyberpsycho_Variants_TEST.zip)

Your on-foot partner and on-foot backup mirror V's drawn weapon outside combat. They use native primary-weapon equip/holster commands. Holstering waits briefly for a calm state; native alerted/combat behavior takes priority when V holsters. Readiness waits during boarding, vehicle use, downing and revive recovery. It does not change follower roles, movement orders, targets or combat states. [Readiness checks and references](tests/officer_readiness/README.md).

Cyberpsycho dispatch chooses among **17 verified source records from the base game's Cyberpsycho Sightings**, including both armored exos, netrunners, snipers, melee/mantis and ranged variants. Each is a private clone; original quest actors and records are untouched. Random mode avoids adjacent repeats when more than one variant is available. In CET, use **TEST: Next cyberpsycho variant**, then **TEST: Request cyberpsycho dispatch** to force a particular test. **Use random cyberpsycho variants** restores random mode. Selection changes the next assignment only. The native journal admits only that assignment's exact private record.

[Variant IDs and source provenance](assets/cyberpsycho/variants.json) record all 17 originals and source blobs. This covers the Sighting targets, not unrelated story bosses such as Adam Smasher. The Bloody Ritual clone receives normal aggressive reactions instead of its original no-reaction intro. All clones use unaffiliated hostile reactions, retaining inherited templates, equipment, stats and abilities. Exo pathfinding, independent boss initialization, appearance and combat variety require live tests; use open areas for the large variants.

Install the **entire ZIP** and restart, including **NCPDPatrol_Cyberpsycho.yaml** and updated redscript. Cyberpsycho interface is now **3**, VIP remains **2**. The v0.14b ambush/aftermath and confirmed tyre repair are preserved byte-for-byte, as are existing progression and payments. Eight portable suites pass, all 17 Lua modules parse, and all 24 scripts pass the offline source/API checks with/without optional BEF. This is not a game-cache or gameplay validation.

## v0.14b: closer ambush and retained aftermath

[Download the complete v0.14b test ZIP](https://github.com/jonathankj2000-cpu/NCPD-Patrol-Officer/raw/refs/heads/main/releases/NCPD_Patrol_v0.14b_Close_VIP_Ambush_TEST.zip)

Attacker cars now use a recorded road point **35–65 m behind you**, with the entire car/crew spawn volume outside the active camera's padded field of view. Looking back delays the ambush. Invalid camera data also delays it. Codeware's native `spawnInView` gate is disabled for these attackers. The warning appears after actual attachment/seating and the chase request, rather than at the initial creation request.

After both attackers are killed or incapacitated, **the car and bodies remain for 90 gameplay seconds**, or until you spend three seconds more than **150 m from the car and every body**. This includes seated takedowns. Completing the delivery preserves a defeated encounter; explicit cancel/shift end still tears it down. Another assignment stays blocked through scene cleanup. Native vehicle combat remains unchanged: user testing observed shooting from vehicles. The confirmed tyre repair is byte-for-byte unchanged.

Install the **entire ZIP** and restart. Native VIP interface is now **2**, so update the redscript files together with Lua. Use the same **TEST: Request VIP transport** and **TEST: Trigger VIP ambush** controls. Test looking backwards as the ambush is armed, then look forwards, and check that defeated attackers remain. Seven portable suites and the offline source/API checks pass; live camera/traffic behavior needs a game test.

## v0.14a: VIP transport and tyre repair

[Download the complete v0.14a test ZIP](https://github.com/jonathankj2000-cpu/NCPD-Patrol-Officer/raw/refs/heads/main/releases/NCPD_Patrol_v0.14a_VIP_Transport_Tyre_Repair_TEST.zip)

Use **CET > DISPATCH CONTROLS > TEST: Request VIP transport**, on duty with any existing dispatch cleared. Objective 1 sends you to a protected witness. Stop nearby as driver of your owned police car, with a free passenger seat. The witness uses rear seats first; the partner keeps their seat. Objective 2 and its destination appear only after actual boarding. At delivery, stop and allow the living witness to exit before completion.

One hostile car and two gang members can pursue the transport. **TEST: Trigger VIP ambush** arms the encounter manually; drive until there is a recorded road position 120–220 m behind you. The automatic trigger waits for 250–400 m of driving. If you stop for three seconds with pursuers nearby, they brake, exit and attack. You can outrun them; killing the attackers is not a delivery condition. Native traffic pathfinding and animations need a game test. The existing native vehicle combat is retained; user tests observed shooting from vehicles.

The ten-second trunk repair now resets tyres after body repair and retries after entering/exiting activates wheel physics. New punctures invalidate that repair receipt, so tyres remain vulnerable. Verify front/rear tyres, entering/exiting, driving and a fresh shot after repair in game.

Pickup/delivery use native fast-travel marker locations without performing fast travel. Some anchors may have poor car access; this is a prototype location pool. Pickup has five gameplay minutes, delivery fifteen; menus pause them. End shift/cancel/load and failed entity cleanup are handled. Generated incidents still have no payment or career credit. Existing scanner, dispatch and arrest payments and saved progression remain unchanged.

Full install: extract the **entire ZIP** into the game folder and restart, including **NCPDPatrol_VIP.archive**, its **.archive.xl**, and **NCPDPatrol_VIP.yaml**. Browser Extension remains optional. [VIP test cases and source references](tests/vip/README.md) cover boarding proof, stage transitions, delivery/failures, car/crew chase/escape and cleanup with engine boundaries mocked. This is not an in-game validation.

## v0.13b: distant cyberpsycho dispatch

[Download the complete v0.13b test ZIP](https://github.com/jonathankj2000-cpu/NCPD-Patrol-Officer/raw/refs/heads/main/releases/NCPD_Patrol_v0.13b_Distant_Cyberpsycho_Dispatch_TEST.zip)

Cyberpsycho dispatch now sends you to a location **500-1000 m away**, expanding to **1.5 km and 2 km** if necessary. The scene marker, notification and journal response objective appear immediately. **No enemy is created beside the player or while travelling.** The target is created near the assigned scene only when you approach within **140 m** and its local placement is validated.

The journal has two successive objectives: **respond to the incident**, then **neutralize the cyberpsycho**. The latter activates only after the exact mod-created target is attached and registered. Both death and non-lethal defeat/unconsciousness resolve it. Existing backup remains available. The private HMG/strong-arms cyberpsycho record and combat setup are retained from v0.13a.

1. Exit the game, extract the **entire ZIP** into the game directory and restart. The updated Cyberpsycho archive is required for the response objective; its native interface is now **2**.
2. Start a shift and cancel any existing dispatch. Outside combat, press CET > **DISPATCH CONTROLS > TEST: Request cyberpsycho dispatch**. Requesting from your vehicle is supported.
3. Check that the marker and journal response objective are hundreds of metres away. Drive to the scene. The **three-minute response deadline pauses in menus** and clears on arrival.
4. On approach, the target spawns near the marked scene and the objective changes to **Neutralize the cyberpsycho**. Test lethal and non-lethal resolution in separate runs, and try your backup patrol.
5. **Cancel active dispatch** (CET or trunk) also cancels the journey. After success the target remains for inspection until you leave 150 m from the scene or 120 gameplay seconds pass. Another incident waits for target cleanup.

Destinations use existing fast-travel world-marker positions as location anchors, with NCART and anchors within 100 m of an unfinished scanner excluded. This does not initiate fast travel. The local spawn search stays within 50 m of the assigned anchor and checks navigation once the area is loaded. If no distant site or suitable local spawn point exists, the request is refused or the assignment fails; it does not fall back to spawning near V. These anchors are a prototype location pool, not a manually validated encounter catalogue.

This remains a manual encounter test. Generated-incident payment and career credit are not yet included. The scene marker stays at the destination; HUD distance follows the target once registered. GPS retains its existing map-open limitation. Leaving the scene or losing the registered target is handled as failure, never successful neutralization. Shift end cancels, wanted termination fails, and loading closes old active journal state without deleting previous-world IDs.

All 23 scripts pass source-derived API checks with and without optional BEF; 13 Lua modules parse. [Encounter checks](tests/cyberpsycho/README.md) execute the actual controller, site selection, deferred spawning, journal transitions, dispatcher and CET controls with native boundaries mocked. WolvenKit 9.1.1 compiles, round-trips and extracts both resources. Live destination coverage, local placement, journal transition and combat still need an in-game test.

### NCPD personnel portal

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

1. Exit the game. Extract the **entire ZIP** into the game directory containing `bin`, `r6` and `archive`, replacing files. Restart; CET announces **v0.15b**. Include the bundled career, Cyberpsycho and VIP tweak/archive files.
2. For the computer page, use the main [Browser Extension Framework 0.9.7](https://www.nexusmods.com/cyberpunk2077/mods/10038) package. At V's apartment computer, open **Net > NCPD Career**. Check all three sidebar sections, text readability, hover feedback and clicks on your screen. Use **Refresh record** after changing progress/test settings. The address remains `NETdir://ncpd.career`.
3. In CET, under **NCPD CAREER**, press **TEST: Unlock all milestones (session)**. This makes all seven reward bundles and all four partners available. It leaves your real incident count and rank unchanged and grants nothing automatically. Use a test save when collecting rewards: issued equipment/vehicles are saved normally.
4. Claim rewards on the computer or with **Claim next milestone reward** in CET. Check inventory and the vehicle summon menu. Repeated claims and save/load should retain receipts without issuing duplicates.
5. Open **Partner Assignment**, select a profile, then start a shift or use **Request new partner** at the trunk. A CET replacement button and a **Partner assignment (CET fallback)** section are also available. Test follow, combat, passenger boarding, downing and revive for each new profile.
6. **Clear test unlocks**, or load a save, to restore normal requirements. Naturally unlocked partner choices persist across loads. A profile chosen only through the temporary test override falls back to Standard if it is still locked after loading. Clearing test unlocks does not remove rewards already collected.

Browser Extension remains **optional**. Without it, progression, rewards and partner choices work through the CET fallback; the computer page is absent. Other requirements remain the established Cyberpunk 2077 2.5 setup: compatible CET, RED4ext, Codeware, redscript, TweakXL and ArchiveXL. Dependencies are not bundled.

### Validation and limits

[Automated checks](tests/career/README.md) execute authored reward/progression code, partner spawning/replacement, the real CET test-button handlers and all three computer pages. Portal checks exercise the native viewport lookup helpers, layout bounds at five viewport sizes, routes, hover feedback, callback cleanup, stale pages, missing viewports and detached devices. They use the actual pinned BEF base/registry with native game/widget boundaries mocked. Existing reward/save/partner/arrest/trunk/dispatch regressions also pass.

All 24 production redscript files pass source-derived API checks with and without BEF. All 17 Lua modules parse. The complete 58-file install ZIP is verified byte-for-byte. Offline layout previews use the authored widget tree; they do not reproduce the game's renderer. Real computer scaling, text rendering and pointer hit testing still need a game test, as do the item tiers/appearance/tooltips under testing in v0.11b.

Existing archives, core/support logic, career progression/reward logic and UI, vehicle and weapon tweaks, VIP/ambush and tyre repair are preserved from v0.14b. Partner/backup add readiness equipment requests; cyberpsycho dispatch adds the verified catalog and exact selected-record admission. Career interface is **3**; main/support **17**, arrest **5**, trunk **3**, scanner journal **2** and browser diagnostics **1** remain unchanged; the cyberpsycho interface is **3**; VIP is **2**.

[Full instructions](README.txt) · [Previous v0.13a ZIP](https://github.com/jonathankj2000-cpu/NCPD-Patrol-Officer/raw/refs/heads/main/releases/NCPD_Patrol_v0.13a_Cyberpsycho_Dispatch_TEST.zip) · [Earlier packages](releases)
