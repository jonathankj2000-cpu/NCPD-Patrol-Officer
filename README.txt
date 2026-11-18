NCPD PATROL v0.13b - DISTANT CYBERPSYCHO DISPATCH PROTOTYPE
=================================================
Full installation package. Adds a distant cyberpsycho response assignment
with travel and neutralization objectives. Lethal and non-lethal takedowns resolve it.
The 0.12a career portal, rewards, weapon tiers, partner, backup and arrests are
included. This first encounter prototype tests spawning, combat and quest state;
it does not issue generated-incident payment or career credit yet.

INSTALL
Exit the game. Extract the ENTIRE ZIP into the Cyberpunk 2077 directory that
contains bin, r6 and archive. Replace files and restart; CET announces v0.13b.
Include NCPDPatrol_Cyberpsycho.yaml and the new Cyberpsycho archive/.archive.xl.
Include r6/tweaks/NCPDPatrol_CareerWeapons.yaml. It defines reward-only
Military variants with fixed game qualities. It does not edit the vanilla guns.
r6/tweaks/NCPDPatrol_CareerVehicles.yaml registers the four reward cars
for the garage. Registration alone does not unlock a car; claim its reward.

Keep the existing compatible Cyberpunk 2077 2.5 dependencies: CET, RED4ext,
Codeware, redscript, TweakXL and ArchiveXL. Frameworks are not bundled.
For the computer page, the main Browser Extension Framework 0.9.7 is optional:
https://www.nexusmods.com/cyberpunk2077/mods/10038
Without BEF, use CET's career/reward/partner controls. The rest of the mod works.

CYBERPSYCHO DISPATCH TEST
1. Start a shift and cancel any existing dispatch. Outside combat, use CET >
   DISPATCH CONTROLS > TEST: Request cyberpsycho dispatch. You may be in a car.
2. The assignment selects a world location 500-1000 m away, expanding to
   1.5 km and 2 km if needed. Marker, notice and response objective appear
   immediately. No enemy or distant navmesh query is created on request.
3. Drive to the scene within three gameplay minutes. Menus pause the timer.
   When you approach within 140 m, the deadline clears and scene preparation
   starts. Navigation is checked around the assigned location, not around V.
4. One cyberpsycho is created near that scene. Once its exact identity and
   attachment are confirmed, the journal completes the response objective and
   activates Neutralize the cyberpsycho. Death, defeat or unconsciousness
   must remain observed for 0.75 gameplay seconds. Backup remains available.
5. Test lethal and non-lethal completion in separate runs. Cancel active
   dispatch (CET or trunk) also cancels a journey before an enemy exists.
6. After success, the target remains until you leave 150 m from the scene or
   120 gameplay seconds pass. Target cleanup must finish before another call.
   Log cyberpsycho diagnostics includes initial distance and search radius.

Location anchors come from native fast-travel world markers. NCART markers
and anchors within 100 m of unfinished scanners are excluded. This does not
perform fast travel. Local spawn projection searches within 50 m of the anchor
and checks reachability after arrival. Failure to find a distant site or local
spawn point never changes the incident into a nearby spawn. This is a prototype
location pool; real site coverage and placement need game testing.

The private Character.NCPDPatrol_Cyberpsycho clone and its HMG/strong-arms combat
configuration are retained. Original quest records/facts and ambient actors are
not edited. Crowd-directed rampage behavior remains a later extension.

The scene marker stays at the destination; HUD distance follows the registered
target. GPS can still require opening/closing the map. Abandonment, missing
actors, refused journal changes and bounded scene-setup failure do not count
as completion. Shift end cancels, wanted termination fails, and loading closes
old active journal entries without deleting previous-world entity IDs.

The first test still does not award generated-incident payment or career credit.
The full updated Cyberpsycho archive is required; native interface is now 2.

COMPUTER
At a browser-capable computer, open Net and select NCPD Career. Its address is
NETdir://ncpd.career. A permanent sidebar provides three pages:

SERVICE RECORD: rank, service grade and promotion progress, next milestone,
incident/dispatch/arrest totals, issued rewards, a seven-step milestone track,
selected partner and quick claim/assignment controls.
REWARDS & EQUIPMENT: seven reward cards with LOCKED, AVAILABLE,
PARTIAL - RETRY or CLAIMED states, weapon tiers, partner access and collection.
PARTNER ASSIGNMENT: four profiles with role, equipment, access requirements,
progress and assignment controls. Locked and selected profiles are explicit.

Navy/cyan/gold panels, button hover feedback and a latest-service-update strip
provide a consistent layout. Width and height adapt to the browser content
viewport rather than using the old fixed-width body. Wider screens expand the
layout; smaller viewports scale the same design. No new asset dependency.

The page is a snapshot. Refresh record after using a CET test control or when
your incident total has changed. Claims, selections and tab clicks refresh it.
If the entry is absent, keep that Net browser open and use CET's Log career
browser diagnostics or Open NCPD Career (computer browser). These do not alter
BEF settings or bypass its restrictions. Diagnostics now include viewport
dimensions, UI scale and fallback=true/false. If the native viewport is not yet
measured, the page uses a 1920x1080 fallback; Refresh record measures it again.

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
1. Confirm v0.13b. Open all three career pages. Check that the content fills
   the browser, text stays readable and the sidebar/hover/click targets work.
2. Note your actual incident count and rank. Enable test unlocks and refresh;
   access changes while those real values remain unchanged. Check the seven
   reward cards and four partner cards. Claim available bundles if desired.
3. Retain your v0.11b weapon test: Lexington T2, Masamune T3, Defender T5.
   Check all 12 equipment pieces/weapons and all four garage vehicles. Try
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
All three authored pages fit native-widget fixtures at 1920x1080, 3840x2160,
3440x1440, 1280x720 and 3840x1800. Tests exercise the actual viewport helpers,
hover and all callback cleanup, including stale pages and detached devices.
Offline font/layout previews are not in-game screenshots or hit-testing.

All 23 redscript files pass source-derived API checks with BEF installed and
absent; 13 Lua modules parse. The full 50-file ZIP is checked byte-for-byte.
This is not validation against the real game script cache or actual gameplay.
Existing arrest/trunk/dispatch tests pass. Archives and payment code remain
unchanged from v0.11b. Core recognizes the four additional owned police cars; support
registration accepts the four partner records. Down/revive recovery is retained.

Weapon tests cover the fixed quality definitions, delivery records, unchanged
legacy receipt identities, missing definitions, partial test-delivery retries,
and the actual CET button. Real weapon tooltips still need an in-game test.

Cyberpsycho tests execute the actual native controller and CET spawn/AI/cleanup,
dispatcher exclusion/cancellation and shipped request/cancel button handlers.
The new journal/localization resources compile, round-trip and extract exactly
with WolvenKit 9.1.1. These are native-boundary tests, not a game simulation.

Interfaces: main/support 17, arrest 5, trunk 2, scanner journal 2, career 3,
browser 1, cyberpsycho 2.

ROLLBACK TO v0.13a
Exit the game and reinstall the entire v0.13a ZIP, including its Cyberpsycho
archive. This restores the nearby manual spawn test.

ROLLBACK TO v0.12a
Exit the game. Remove cyberpsycho.lua, NCPDPatrolCyberpsychoSystem.reds,
NCPDPatrol_Cyberpsycho.yaml and NCPDPatrol_Cyberpsycho.archive/.archive.xl,
then reinstall the full v0.12a ZIP. The encounter adds no persistent reward or
career fields. Earlier packages remain available on GitHub.

ROLLBACK TO v0.11b
Exit the game and reinstall the entire v0.11b ZIP. This update only changes the
career page and its transient layout diagnostics; saved career data is retained.

ROLLBACK TO v0.11a
Exit the game, remove r6/tweaks/NCPDPatrol_CareerWeapons.yaml and reinstall the
entire v0.11a ZIP. Use a pre-test save to remove already issued test copies.

ROLLBACK TO v0.10b
Exit the game. Remove r6/tweaks/NCPDPatrol_CareerVehicles.yaml and reinstall the
entire v0.10b ZIP. Use a save from before this test to undo already issued gear,
vehicles or choices. Earlier packages remain available on GitHub.
