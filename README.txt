NCPD PATROL v0.11b - FIXED MILESTONE WEAPON TIERS TEST
=================================================
Full installation package. Retains career rewards/partners and assigns fixed
weapon tiers: T2 through 20 incidents, T3 through 50, T4 through 75, T5 above 75.
Lexington Military = Tier 2; Masamune Military = Tier 3; Defender Military = T5.
The 75-incident reward remains the Hellhound; no new gun is added there.

INSTALL
Exit the game. Extract the ENTIRE ZIP into the Cyberpunk 2077 directory that
contains bin, r6 and archive. Replace files and restart; CET announces v0.11b.
Include the new r6/tweaks/NCPDPatrol_CareerWeapons.yaml. It defines reward-only
Military variants with fixed game qualities. It does not edit the vanilla guns.
The new r6/tweaks/NCPDPatrol_CareerVehicles.yaml registers the four reward cars
for the garage. Registration alone does not unlock a car; claim its reward.

Keep the existing compatible Cyberpunk 2077 2.5 dependencies: CET, RED4ext,
Codeware, redscript, TweakXL and ArchiveXL. Frameworks are not bundled.
For the computer page, the main Browser Extension Framework 0.9.7 is optional:
https://www.nexusmods.com/cyberpunk2077/mods/10038
Without BEF, use CET's career/reward/partner controls. The rest of the mod works.

COMPUTER
At a browser-capable computer, open Net and select NCPD Career. Its address is
NETdir://ncpd.career. Service Record shows rank, real incident totals, progress,
upcoming rewards and claim status. Partner Assignment shows the four profiles,
their equipment, required incident count and current selection.

The page is a snapshot. Refresh record after using a CET test control or when
your incident total has changed. Claims, selections and tab clicks refresh it.
If the entry is absent, keep that Net browser open and use CET's Log career
browser diagnostics or Open NCPD Career (computer browser). These do not alter
BEF settings or bypass its restrictions.

MILESTONES
    5  NCPD anti-shrapnel helmet
   10  Villefort Cortes NCPD Overlord
   20  NCPD reinforced ballistic vest + Lexington Military (T2) + Merrimac Police
   35  Full NCPD Badge Set: coat, pants, boots and goggles
   50  Masamune Military (T3) + Chevillon Emperor NCPD Ironclad
   75  Militech Hellhound Man o' War
  100  MaxTac helmet, jacket and pants + Defender Military (T5)

Claim reward issues the oldest available bundle, one per click. Items go into
inventory; vehicles are enabled in the game's garage. A distinct REWARD ISSUED
notice identifies the milestone. Opening/refreshing does not issue anything.
Each successful item/vehicle has its own receipt saved with the character.
If a bundle partly fails, PARTIAL - RETRY collects its remaining parts only.
Repeated clicks or loading the updated save must not duplicate its rewards.
Already-owned reward vehicles count as collected without another enable call.

Existing v0.10 cash receipts are retained separately. They do not block the
new equipment rewards. New career claims do not grant the old test cash bonus.
Scanner EUR$1000, dispatch EUR$500 and arrest EUR$250 payments are unchanged
and maintain separate records.

Career uses on-duty scanner activity records already maintained by NCPD Patrol,
across shifts and saves. Earlier activities the mod never recorded cannot be
reconstructed. Dispatch and arrest totals do not add extra career credits.
Rank: Probationary Officer (0), Police Officer (5), Patrol Officer (10), Senior
Officer (20), Corporal (35), Sergeant (50), Lieutenant (75), Captain (100).

PARTNERS
    0  Standard NCPD Patrol Officer - Copperhead
   20  NCPD Shotgun Enforcer - Zhuo shotgun
   50  NCPD Tactical Officer - M2067 Defender
  100  MaxTac Netrunner - Omaha / Kappa, netrunner archetype

Access unlocks from the same real incident count, independently of claiming
equipment. Select a profile at the computer. The choice is saved; it takes
effect at shift start or Request new partner from the owned car's trunk menu.
CET also has Partner assignment (CET fallback) and Request new partner buttons.
Changing selection does not remove an officer who is currently on assignment.
Only the actor created by this mod can be replaced. A missing next model or
rejected deletion leaves the existing actor registered and creates no extra.

The Shotgun Enforcer record contains 'tactician' but its vanilla equipment is
a Zhuo. The Tactical Officer supplies Defender. MaxTac uses a generic record,
not a story quest actor. Following, combat, boarding and revive use the existing
controller; their behavior on the three new records needs an in-game test.
Friendly MaxTac quickhacks against NPC enemies are not yet verified.

TEST BUTTON
CET > NCPD CAREER > TEST: Unlock all milestones (session)
This immediately makes all seven reward bundles and all four partner profiles
available. It grants nothing automatically and does not fabricate incident
records or raise your actual rank. The computer displays TEST UNLOCK ACTIVE.

Use Claim reward on the page, or Claim next milestone reward in CET. Inspect
the items and summon each unlocked vehicle. Claims are stored normally, even
when made with test access: clearing the override does not remove those items
or cars. Use a test save if you do not want these claims on your normal save.

Clear test unlocks, or load a save, to restore normal requirements. The override
is transient. A naturally unlocked partner selection survives loading. If a
selected profile was accessible only through test mode and is still locked,
future spawns use Standard until it becomes available again or you select one.
No extra reward is issued by clearing or re-enabling the override.

WEAPON TIER RETEST
Already claimed weapons remain claimed; existing inventory items are not
modified or removed. To get fresh examples after updating, enable TEST unlocks,
then use CET > NCPD CAREER > TEST: Give tiered reward weapons.
This gives one new Lexington T2, Masamune T3 and Defender T5 per session.
No incident counts, normal claim receipts, money or vehicles are changed.
Repeated clicks do not repeat successful test deliveries. If a delivery fails,
retry to get the remaining guns. Loading a save resets the test-delivery list.
Test copies remain in inventory if you save. Inspect tier, appearance, damage
and mod slots in game; the fixed-tier records use native quality generation.

SUGGESTED IN-GAME CHECK
1. Confirm v0.11b, open the career page and note your real incident count.
2. Enable test unlocks, refresh, and claim the seven reward bundles.
3. Check all 12 equipment pieces/weapons and all four garage vehicles. Try
   repeat claims, save/load, and verify the receipts remain collected.
4. Enable test unlocks again if needed. Select each new partner and request a
   replacement while on duty. Check follow, combat, car boarding and revive.
5. Check backup/repair/menu at the new cars' trunks and on-duty vehicle chatter.
6. Clear test unlocks. Actual progression and normal eligibility must return.

VALIDATION
Automated tests execute production reward/progression code, actual CET partner
spawning/replacement and actual init.lua test-button handlers. Native APIs and
widgets are mocked. Tests cover legacy cash migration, all 16 reward records,
partial failure/retry across simulated load, garage acceptance/confirmation,
already-owned vehicles, safe context guards, partner gates/selection, test-mode
expiry and no synthetic scanner records. Computer tests use pinned BEF base
Init/Uninit and registry methods with per-device matching and callback cleanup.
Authored page flow stays within its declared body height in widget fixtures.

All 22 redscript files pass source-derived API checks with BEF installed and
absent; 12 Lua modules parse. The full 45-file ZIP is checked byte-for-byte.
This is not validation against the real game script cache or actual gameplay.
Existing arrest/trunk/dispatch tests pass. Archives and payment code remain
unchanged. Core recognizes the four additional owned police cars; support
registration accepts the four partner records. Down/revive recovery is retained.

Weapon tests cover the fixed quality definitions, delivery records, unchanged
legacy receipt identities, missing definitions, partial test-delivery retries,
and the actual CET button. Real weapon tooltips still need an in-game test.

Interfaces: main/support 17, arrest 5, trunk 2, journal 2, career 3, browser 1.

ROLLBACK TO v0.11a
Exit the game, remove r6/tweaks/NCPDPatrol_CareerWeapons.yaml and reinstall the
entire v0.11a ZIP. Use a pre-test save to remove already issued test copies.

ROLLBACK TO v0.10b
Exit the game. Remove r6/tweaks/NCPDPatrol_CareerVehicles.yaml and reinstall the
entire v0.10b ZIP. Use a save from before this test to undo already issued gear,
vehicles or choices. Earlier packages remain available on GitHub.
