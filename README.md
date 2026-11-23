# NCPD Patrol

## v0.20b — Voss continuation

Fixes the reported `Scene ended without a proven journal completion` auto-clear.
The final scene receipt is stored separately from journal acknowledgement.
Normal native return checks that receipt, Voss/Hella remain, and the continuation
retries until its own journal entries become active. Rejected or missing entries
now identify the exact blocker. The working speech, lipsync and timing are retained.

[Download the complete v0.20b test ZIP](https://github.com/jonathankj2000-cpu/NCPD-Patrol-Officer/raw/refs/heads/git-checkout--b-refactor/cleanup/releases/NCPD_Patrol_v0.20b_Voss_Continuation_TEST.zip)

Install the complete 129-file package and restart. If the previous version already
cleared the failed conversation, activate the Voss test and finish it once again.
The target objective should start automatically; there is no need to race the
Continue button. [Details](docs/VOSS_CONTINUATION_v020b.md).

## v0.20a1 — Startup compilation fix

Fixes the supplied REDscript `NO_MATCHING_OVERLOAD` error in
`NCPDPatrolOffBooksSystem.reds:68`: the readable journal path now uses
`Equals()` for its String comparison. The newer offline checker had accepted
the previous `==`; the compatibility guard now rejects that exact shipped
v0.20a source before packaging. Quest logic and all ten archives are retained.

[Download the complete v0.20a1 test ZIP](https://github.com/jonathankj2000-cpu/NCPD-Patrol-Officer/raw/refs/heads/git-checkout--b-refactor/cleanup/releases/NCPD_Patrol_v0.20a1_Startup_Fix_TEST.zip)

Overwrite with the complete 129-file package and restart. There is no quest or
save reset required. Then continue the existing off-duty test as described below.

## v0.20a — Off the Books encounter

After the existing Voss briefing, a separate **off-duty** quest sends V to an
Arasaka contractor and two elite guards in Cherry Blossom Market. Kill the
contractor, loot his real readable evidence shard, lose any pursuing NCPD and
return to Voss. Voss and her Hella remain available at the original meeting.
The return conversation and final quest reward are future work.

[Download the complete v0.20a test ZIP](https://github.com/jonathankj2000-cpu/NCPD-Patrol-Officer/raw/refs/heads/git-checkout--b-refactor/cleanup/releases/NCPD_Patrol_v0.20a_Off_the_Books_TEST.zip)

Install all 129 files and fully restart. OFF DUTY > CET > Testing > Quest giver
prototype > activate. If the briefing is already completed in the save, use
**TEST: Continue Off the Books after briefing** instead. Normal patrol dispatch,
rewards and the working first conversation are retained.
[Implementation, test steps and limits](docs/OFF_THE_BOOKS_v020a.md).

## v0.19h1 — Voss idle pose

Requests native idle-only mode for Voss's existing arms-crossed workspot once
it is active, before dialogue. The working v0.19h voice and caption timing,
lipsync, SMS and all nine archives are retained.

[Download the complete v0.19h1 test ZIP](https://github.com/jonathankj2000-cpu/NCPD-Patrol-Officer/raw/refs/heads/git-checkout--b-refactor/cleanup/releases/NCPD_Patrol_v0.19h1_Voss_Idle_Pose_TEST.zip)

Clear the old test, install all 123 files and fully restart. Wait near Voss,
then approach and let the conversation finish; check the body stays in its
idle rather than transitioning to walking. [Details](docs/VOSS_IDLE_POSE_v019h1.md).

## v0.19h — Voss timing

Adds playback headroom before V replies and longer turn-taking pauses. Caption
changes occur later; short adjoining phrases are grouped into 19 blocks.
Original media, dialogue and the working scene identifiers are preserved.

[Download the complete v0.19h test ZIP](https://github.com/jonathankj2000-cpu/NCPD-Patrol-Officer/raw/refs/heads/git-checkout--b-refactor/cleanup/releases/NCPD_Patrol_v0.19h_Voss_Timing_TEST.zip)

Clear the old test, install all 123 files and fully restart. Let the ten-turn
conversation finish without skipping, checking overlap and caption timing.
[Timing policy and validation limits](docs/VOSS_TIMING_v019h.md).

## v0.19g1 — Voss scene ID fix

Corrects malformed local dialogue type/index IDs in v0.19g and restores a dense
ordered scene graph. All speech, original V string IDs, media and native scripts
are preserved. The bad v0.19g identifiers are now rejected before packaging.

[Download the complete v0.19g1 test ZIP](https://github.com/jonathankj2000-cpu/NCPD-Patrol-Officer/raw/refs/heads/git-checkout--b-refactor/cleanup/releases/NCPD_Patrol_v0.19g1_Voss_Scene_ID_Fix_TEST.zip)

Install all 123 files, fully restart and test from a save made before the old
Voss test was activated. This fixes an identified data error; the reported
native crash still needs game confirmation. [Details](docs/VOSS_SCENE_ID_FIX_v019g1.md).

## v0.19g — Voss conversation

The meeting uses the supplied six-part Voss briefing with matching lipsync and
four automatic original V replies. There is no choice menu. SMS, the grounded
waiting pose and the v0.19f1 pose-confirmation fix remain included.

[Download the complete v0.19g test ZIP](https://github.com/jonathankj2000-cpu/NCPD-Patrol-Officer/raw/refs/heads/git-checkout--b-refactor/cleanup/releases/NCPD_Patrol_v0.19g_Voss_Conversation_TEST.zip)

Clear the old test, install all 123 files and fully restart. Activate the same
quest-giver test and approach Voss. Verify V's original voices and timing in
the game. [Details](docs/VOSS_CONVERSATION_v019g.md).

## v0.19f1 — Voss pose confirmation fix

Fixes the eight-second cancellation that could delete Voss and the Hella even
while her waiting animation was playing. Native actor activity can confirm the
pose without a device-user mapping. Cosmetic pose failures now retain the
actors and meeting quest. SMS, three captions, voice and lipsync are preserved.

[Download the complete v0.19f1 test ZIP](https://github.com/jonathankj2000-cpu/NCPD-Patrol-Officer/raw/refs/heads/git-checkout--b-refactor/cleanup/releases/NCPD_Patrol_v0.19f1_Voss_Pose_Check_Fix_TEST.zip)

Clear the old test, install all 123 files and fully restart. Wait at least
15 seconds near Voss before approaching to talk, then test either reply.
[Cause, regression and game checks](docs/VOSS_POSE_CHECK_FIX_v019f1.md).

## v0.19f — Voss subtitles

The briefing displays three timed subtitle blocks while voice and lipsync play
continuously. Includes the native SMS invitation and grounded arms-crossed
waiting pose from v0.19d/e.

[Download the complete v0.19f test ZIP](https://github.com/jonathankj2000-cpu/NCPD-Patrol-Officer/raw/refs/heads/git-checkout--b-refactor/cleanup/releases/NCPD_Patrol_v0.19f_Voss_Subtitles_TEST.zip)

Clear the old quest-giver test, install all 123 files and fully restart. Use
OFF DUTY → CET → Testing → Quest giver prototype → Activate. Text changes at
approximately 15 and 28.5 seconds into the voiced briefing. Actual in-game
timing and ground alignment need testing. [Details](docs/VOSS_SUBTITLES_v019f.md).

## v0.19a1 — quest giver scene-guard fix

Corrects the early “Finish the current game scene” rejection. Player scene
membership alone no longer blocks activation or the investigator greeting.
Both gates use actual dialogue state and restricted scene tiers. The broader
ownership check still protects the private actors during cleanup.

[Download the complete v0.19a1 test ZIP](https://github.com/jonathankj2000-cpu/NCPD-Patrol-Officer/raw/refs/heads/git-checkout--b-refactor/cleanup/releases/NCPD_Patrol_v0.19a1_Scene_Guard_Fix_TEST.zip)

Install all 122 files and fully restart. Then use the same OFF DUTY quest-giver
test button. All nine archives and 45 native scripts are unchanged.
[Fix evidence and checks](docs/QUEST_GIVER_SCENE_GUARD_v019a1.md).


## v0.19a — quest giver prototype

Adds an **explicit OFF DUTY test** under **Testing → Quest giver prototype**.
Activating it starts a separate journal quest and a fixed native marker at
`1424.737, -2754.759, 204.665`. An NCPD investigator uses the supplied appearance
and yaw `-143.376`; a private police Hella is parked sideways 4 m behind her.
The two actors are staged when V comes within 120 m.

Approach within 3 m **on foot** with game subtitles enabled. A native, silent
scene shows **quest giver hello → option 1 / option 2 → V's reply → quest giver
goodbye**, then marks the journal quest complete. Both choices share the ending.
Use **Clear quest giver test** before replaying the other path.

[Download the complete v0.19a test ZIP](https://github.com/jonathankj2000-cpu/NCPD-Patrol-Officer/raw/refs/heads/git-checkout--b-refactor/cleanup/releases/NCPD_Patrol_v0.19a_Quest_Giver_Prototype_TEST.zip)

Install all 122 files and fully restart. This does not activate automatically
at milestones, pay rewards or contribute career incidents. Existing dispatch,
54 Officer Down sites, progression and the optional browser retain their
behavior. [Scope, implementation and game checks](docs/QUEST_GIVER_PROTOTYPE_v019a.md).


## v0.18i — CET menu cleanup

Officer Down requests on **Dispatch** and **Testing → Dispatch scenarios** use
all **54 enabled catalogue locations**. The menu now displays the count and
coverage. Current Officer Down state, logging, export and cleanup are grouped
under **Diagnostics → Officer Down: current dispatch**.

Removed the fixed Kryss 1 launcher/rotation/locator, obsolete injured-placement
pilot controls and old marker experiment launchers. Existing recorded-site
survey and terminal discovery tools remain; milestone test unlocks are grouped
with Reward equipment. One guarded cleanup button remains for old marker tests.

[Download the complete v0.18i test ZIP](https://github.com/jonathankj2000-cpu/NCPD-Patrol-Officer/raw/refs/heads/git-checkout--b-refactor/cleanup/releases/NCPD_Patrol_v0.18i_CET_Menu_Cleanup_TEST.zip)

Install all 117 files and fully restart. All 54 locations, native scripts,
archives, dispatch behavior, rewards and saved results are unchanged.
[Scope, catalogue audit and game checks](docs/CET_MENU_CLEANUP_v018i.md).


## v0.17e2 — arrest initialization test

Prepares and reads back the private arrest animation bindings **before helper
attachment**, checks later resource instances/caches, and waits for pending
assets without creating an unbound helper. Native scripts, the infinite lying
loop/archive, physics and payment are unchanged. Includes the H10 exclusion.

[Download the complete v0.17e2 test ZIP](https://github.com/jonathankj2000-cpu/NCPD-Patrol-Officer/raw/refs/heads/git-checkout--b-refactor/cleanup/releases/NCPD_Patrol_v0.17e2_Arrest_Initialization_TEST.zip)

Install all 88 files and fully restart. Test a newly downed, uncredited suspect.
The old code fails the new attachment-order test; whether this resolves the
reported T-pose still needs game confirmation. [Evidence and test](docs/ARREST_BINDING_INITIALIZATION_v017e2.md).

## v0.17e1 — H10 location fix

Excludes **Megabuilding H10: Atrium** from VIP pickup/delivery and cyberpsycho
dispatch destinations. Uses its exact fast-travel record plus a 2 m XYZ fallback;
street-level locations below it remain eligible. World fast travel and fixed
marker-bank indices are preserved. Includes the complete v0.17e improvements.

[Download the complete v0.17e1 test ZIP](https://github.com/jonathankj2000-cpu/NCPD-Patrol-Officer/raw/refs/heads/git-checkout--b-refactor/cleanup/releases/NCPD_Patrol_v0.17e1_H10_Location_Fix_TEST.zip)

Install all 88 files and restart the game.

## v0.17e — patrol improvements branch test

Extracts the working r5c marker catalogue and diagnostic formatting with **3161
identical observation rows** against the actual r5c controller. Marker activation,
confirmation, fallback timing, cleanup and session gating keep their behavior.

NCPD Career now has **Start Shift** in its sidebar, using the existing shift
controller. Backup prefers V's recently driven route, checks ground, corridor
and camera visibility, and confirms the car's actual placement before deploying
its two officers. Placement retries are bounded and retain the one-unit limit.

[Download the complete v0.17e test ZIP](https://github.com/jonathankj2000-cpu/NCPD-Patrol-Officer/raw/refs/heads/git-checkout--b-refactor/cleanup/releases/NCPD_Patrol_v0.17e_Patrol_Improvements_TEST.zip)

Install all 87 files and fully restart. Browser Extension is optional; the
career website needs it. VIP/ambush and all six archives are unchanged. No clear
Bean Bagger pump-colour regression was found; materials and runtime diagnostics
are unchanged. [Findings](docs/BEAN_BAGGER_BLUE_PUMP_REVIEW.md).

[Scope, checks and game-test steps](docs/PATROL_IMPROVEMENTS_v017e.md).
Backup driving and long-term marker/load reliability still need game testing.


## Fixed quest markers r5c — branch test

Corrects r5b's false rejection of a valid native marker: deterministic private
ownership is independent of journal availability during restore, and the
selected private entry identifies its own pin. Codeware Session/Ready gates
CET/native work; restore processes at most 48 objectives per update. Fallback
status follows live registration rather than keeping its initial pending label.

[Download the complete r5c test ZIP](https://github.com/jonathankj2000-cpu/NCPD-Patrol-Officer/raw/refs/heads/git-checkout--b-refactor/cleanup/releases/NCPD_Patrol_v0.17d_Fixed_Quest_Markers_r5c_TEST.zip)

Install all 84 files and fully restart; the new session service and bank
interface 4 are required. All six archives stay byte-identical to r5b. Expected
normal state: 3112 ownership identities, selected membership true, one active
bank pin and native confirmed=true. The existing diagnostics button prints
both current and pre-cleanup evidence. Game stability and crash attribution
remain unverified. [Implementation and evidence](docs/FIXED_QUEST_MARKERS.md).

## Fixed quest markers r5b — branch test

Native quest pins now survive deactivation for engine reuse. The check counts
active pins separately from cached instances; a correctly positioned active pin
is retained when journal proof is incomplete. Both marker controllers wait for
an attached player before native cleanup. Pre-cleanup diagnostics survive fallback,
and fallback registration/activation is measured explicitly.

[Download the complete r5b test ZIP](https://github.com/jonathankj2000-cpu/NCPD-Patrol-Officer/raw/refs/heads/git-checkout--b-refactor/cleanup/releases/NCPD_Patrol_v0.17d_Fixed_Quest_Markers_r5b_TEST.zip)

Install the complete package and fully restart. Check save loading first, then
repeat dispatch/cancel/completion and reload. The existing **Log active dispatch
marker diagnostics** button prints current state and a retained pre-cleanup
snapshot. The reported animation-buffer crash is **not attributed or confirmed
fixed**; these changes address verified source defects. All six archives stay
byte-identical to r5a. [Evidence, checks and limits](docs/FIXED_QUEST_MARKERS.md).

## Fixed quest markers r5a — branch test

Corrects r5's all-location marker pool with **one site objective and one pin**,
inactive definitions and explicit selected-pin activation. Scanner sites now
use fixed offsets from the game-confirmed Coyote anchor. Native confirmation
requires exactly one active bank pin, correct objective link and both positions.
Old/private pool markers and stale diagnostic positions are cleaned up.

[Download the complete r5a test ZIP](https://github.com/jonathankj2000-cpu/NCPD-Patrol-Officer/raw/refs/heads/git-checkout--b-refactor/cleanup/releases/NCPD_Patrol_v0.17d_Fixed_Quest_Markers_r5a_TEST.zip)

Install the entire package and restart. Use **Diagnostics → Fixed quest markers
→ Log active dispatch marker diagnostics** while the assignment is active.
The separate legacy Coyote experiment does not diagnose active dispatches.
Original attendance, actors, results, payments and progression remain with
their existing owners; they select the matching site objective. Manual
waypoints stay independent. Browser Extension remains optional.

18 portable suites, source guards and offline API compilation pass; **r5a still
needs in-game validation**. R5's observed failure is recorded with the fix.
[Implementation, evidence and test steps](docs/FIXED_QUEST_MARKERS.md).

## VIP refactor r3 — branch test

VIP location selection and waypoint ownership now live in separate modules.
`vip.lua` keeps the native quest/token, witness, boarding, delivery and actor
cleanup flow. Selection order/ranges, marker recovery, rewards and both ambush
modules retain the r2 behavior. The six-tab CET menu is included.

[Download the complete VIP refactor r3 ZIP](https://github.com/jonathankj2000-cpu/NCPD-Patrol-Officer/raw/refs/heads/git-checkout--b-refactor/cleanup/releases/NCPD_Patrol_v0.17d_VIP_Refactor_r3_TEST.zip)

Install the **entire package** and restart; CET announces **v0.17d VIP refactor r3**.
Include both `vip_locations.lua` and `vip_waypoint.lua`. No new dependency,
native interface or save migration. Main remains separate from this branch.

Verification: **16 suites**, **29,208 matching VIP trace rows against r2**, the
unchanged **17,374-row dispatch comparison** and **156 CET action comparisons**;
24 Lua modules, 28 unchanged native scripts and a complete 72-file ZIP. Actual
game validation remains necessary. [Ownership and checks](docs/VIP_REFACTOR.md).

## CET interface refactor r2 — branch test

The CET menu now has **Patrol, Dispatch, Career, Settings, Diagnostics and Testing**
tabs. Duty/availability controls stay at the top, each tab scrolls independently,
and the last action's status stays in a separate footer. Logs and test grants
are grouped away from normal patrol actions. Career shows rank, progress and
next reward; active test unlocks display a persistent warning.

[Download the complete CET refactor r2 ZIP](https://github.com/jonathankj2000-cpu/NCPD-Patrol-Officer/raw/refs/heads/git-checkout--b-refactor/cleanup/releases/NCPD_Patrol_v0.17d_CET_Interface_Refactor_r2_TEST.zip)

Install the **entire package** and restart; CET announces **v0.17d CET refactor r2**.
`cet_ui.lua` owns presentation; `init.lua` retains session/shift ownership and
update order. All 52 previous controls and their gameplay owners remain.
Native scripts, rewards, progression, dispatch timing and actor cleanup are
unchanged. Main stays separate from this refactor branch.

Verification: **15 suites**, **156 old/new button-action comparisons**, the
unchanged **17,374-row dispatch comparison**, 22 Lua modules, 28 unchanged native
scripts and a complete 70-file ZIP. CET 1.37.1 bindings were checked; actual
rendering/input still need an in-game test. [Details and checks](docs/CET_UI_REFACTOR.md).

## Dispatch refactor r1 — branch test

The dispatch coordinator now delegates scanner assignments, scheduling and result
tracking to separate modules. Existing CET/trunk calls, the 50/30/20 mix,
standby, native journals, payments, career progress and actor cleanup contracts
are preserved. Read-only lifecycle diagnostics distinguish assignments,
foreground cleanup and background scenes.

[Download the complete refactor r1 test ZIP](https://github.com/jonathankj2000-cpu/NCPD-Patrol-Officer/raw/refs/heads/git-checkout--b-refactor/cleanup/releases/NCPD_Patrol_v0.17d_Dispatch_Refactor_r1_TEST.zip)

Install the complete package and restart; CET announces **v0.17d dispatch
refactor r1**. No new dependency or save migration. This branch contains the
refactor; `main` remains unchanged. See [ownership, contracts and game checks](docs/DISPATCH_REFACTOR.md).

Verification: all 13 existing suites plus a differential comparison against
pinned v0.17d; 21 Lua modules, 28 unchanged redscript files and a complete
69-file ZIP. Actual game validation is still required.

## v0.17d: partial ambush cleanup after VIP delivery

[Download the complete v0.17d ZIP](https://github.com/jonathankj2000-cpu/NCPD-Patrol-Officer/raw/refs/heads/main/releases/NCPD_Patrol_v0.17d_VIP_Partial_Cleanup_FIX.zip)

Fixes the remaining dispatch lock with `stage=3`, `entity=none`, three current
ambush controllers and one pending ID per controller. Earlier retirement required
a confirmed combat-resolution flag. Cars that never attached, or cars left after
normal crew deletion, never met that condition and stayed in foreground cleanup.

After confirmed VIP delivery, known pending ambush IDs now move to the bounded
background queue even when despawn is incomplete. Vehicle-only cleanup can also
retire after cancellation/failure once every owned NPC ID is confirmed gone.
Eligibility is checked before and after deletion and during later updates. Late
units join the same convoy scene, preserving the three-scene limit. Retired units
cannot retry spawning or issue new ambush commands; their IDs remain owned until
deletion is confirmed. A full queue skips VIP while permitting scanner/cyberpsycho
fallback. Ordinary combat/menu/Busy pauses still apply.

Diagnostics separate pending vehicle/NPC/unknown IDs, whether the car ever attached,
crew IDs requested and the last unit status. Three controllers do not prove three
cars appeared in game. The new checks prevent their pending cleanup from reserving
a completed assignment; they do not guarantee that a previously unseen car spawns.

Install the **complete package** and restart; CET announces **v0.17d**. The v0.17c
VIP marker recovery, native scripts, archives and saved rewards are unchanged.
Thirteen regression suites include three never-attached cars, attached cars with
deleted crew, pending NPC despawn, later partial cleanup, automatic next calls and
old cleanup preserving the next journal/marker. Engine attachment/physics/rendering
are mocked and still need game validation.

## v0.17c: VIP waypoint recovery

[Download the complete v0.17c ZIP](https://github.com/jonathankj2000-cpu/NCPD-Patrol-Officer/raw/refs/heads/main/releases/NCPD_Patrol_v0.17c_VIP_Waypoint_Recovery_FIX.zip)

VIP retains its current waypoint ID and checks the game's marker registry once
per gameplay second. Missing pickup/delivery markers are re-registered after a
two-second grace period; inactive or displaced markers receive activation or
position updates. Failed recovery retries at most once every five seconds
without restarting the journal or spawning another witness. Healthy markers
stay in place. Delivery stays hidden until actual boarding.

VIP stage changes, cancellation and completion remove only its current cached
marker ID. Load/reset forgets old-world IDs without unregistering them.
**Log VIP diagnostics** includes marker status, ID, position and recovery count.
**Rebuild VIP waypoint** explicitly replaces the active pickup/delivery marker
without restarting the assignment, including when registry inspection reports
a valid pin but the renderer does not show it.

Install the **complete package** and restart; CET announces **v0.17c**. Native
scripts, assets, payouts and v0.17b independent ambush cleanup remain the same.
Thirteen regression suites cover removed, delayed, inactive and displaced pins,
temporary API failure/retry limits, both stages, scoped cancellation and world
reset. Registry tests do not emulate rendering; a game test is still required.
The known GPS-line limit remains. The earlier diagnostic confirmed a live
stage-1 VIP, but did not establish what originally removed or hid its marker.

## v0.17b: automatic dispatch after VIP delivery

[Download the complete v0.17b ZIP](https://github.com/jonathankj2000-cpu/NCPD-Patrol-Officer/raw/refs/heads/main/releases/NCPD_Patrol_v0.17b_VIP_Dispatch_Standby_FIX.zip)

Completed VIP missions no longer reserve dispatch for neutralized ambush bodies.
Those scenes move into a separate cleanup queue; even refused or delayed despawn
cannot lock scanner/cyberpsycho calls. Their IDs remain owned and retried, with a
maximum of **three convoy scenes**. A full queue temporarily skips new VIP calls
and allows the normal fallback. Starting a new VIP preserves older scenes.
Bodies retain their existing 90-second/150-m cleanup rules. Live attackers and
an undelivered VIP still reserve their assignment until cleanup is confirmed.

The **60–120 second** standby starts when a generated assignment closes and runs
during scene cleanup. Previously retention delayed that wait, and a failed
ambush despawn could leave the entire dispatch stuck in `phase=cleanup`.
Busy, game menus, combat and the automatic-dispatch toggle retain their pauses.

CET now shows **Automatic dispatch** with the current timer or blocking reason.
**Log automatic dispatch diagnostics** includes VIP/cyberpsycho state in one
entry. Retained ambush scenes show their remaining gameplay seconds; pending
deletion shows the remaining actor count. A scanner journal at stage zero is
not a diagnosis of a VIP's cleanup state.

Install the **complete package** and restart. This is a Lua scheduling/status
fix; native scripts, archives, the 50/30/20 mix and saved rewards are unchanged.
Thirteen regression suites include VIP delivery through the next automatic call,
neutralized scenes refusing deletion for over five simulated minutes, Codeware's
accepted-then-pending despawn contract, three-scene capacity/fallback, all pause
gates and still-active attacker cleanup. Engine boundaries are mocked; in-game
validation remains necessary.

## v0.17a: mixed dispatch, rewards and career incidents

[Download the complete v0.17a test ZIP](https://github.com/jonathankj2000-cpu/NCPD-Patrol-Officer/raw/refs/heads/main/releases/NCPD_Patrol_v0.17a_Mixed_Dispatch_Rewards_TEST.zip)

Automatic calls, **Request dispatch now** and the trunk's **Request new dispatch**
draw **50% scanner / 30% VIP / 20% cyberpsycho**. If a type is unavailable, its
weight is removed and another type is tried, at most once each. A pending actor
cleanup keeps the assignment slot. When nothing is available, retry after 30
seconds. Existing Busy/menu/combat pauses and individual CET test requests remain.
These are nominal weights; availability changes observed proportions.

Successful VIP delivery pays a flat **€$2,000**. Cyberpsycho completion pays
**€$3,000**, plus **€$500** for a confirmed non-lethal outcome. Each records **one
NCPD Career incident**. Scanner bonuses remain €$1,000 plus the separate €$500
attended-dispatch supplement; arrests remain an independent €$250. A scanner
dispatch contributes one career incident, not two.

Generated outcomes use their own saved completion/payment records and persistent
unique IDs. Failed transactions retry earned payments across loads and shift
changes; paid receipts appear after the completion notice. Existing scanner
history and milestone item/vehicle claim IDs are retained. Prototype generated
wins before this version cannot be backfilled because they stored no history.
In-flight generated missions still close on loading a save.

Install the **entire ZIP** and restart, including
`r6/scripts/NCPDPatrol/NCPDPatrolIncidentSystem.reds`. Cyberpsycho/VIP native
interfaces are now **4**, incident rewards **1**. No new external dependency.
Thirteen portable suites cover the full mix, fallback, outcomes, payment/receipt
retries and existing gameplay; local source/API compilation covers all 28
scripts with and without optional BEF. Actual game/cache validation is still
required. The [Nexus-ready changelog since 0.8.1](CHANGELOG_NEXUS.md) includes
the intervening features as well as this update.

## v0.16e: broader VIP routes, 1–3-car ambushes and arrest notices

[Download the complete v0.16e test ZIP](https://github.com/jonathankj2000-cpu/NCPD-Patrol-Officer/raw/refs/heads/main/releases/NCPD_Patrol_v0.16e_VIP_Convoy_Arrest_Notices_TEST.zip)

- **VIP selection:** prefer existing 500–2000 m pickups and 800–2500 m trips. If no pair exists, allow a closer 250 m pickup/500 m trip, then expand pickup radius through 3.5 km to 5 km and trip distance to 5 km. Local mixed/drop-point routes are considered before remote fast-travel-only routes. The 100 m clearance from unfinished scanners remains. Diagnostics show the nearest clear point and distance buckets, so total marker counts are no longer the only clue.
- **VIP deadlines:** ordinary responses retain five minutes; pickups beyond 2 km gain time with distance, up to ten minutes at 5 km. The journal briefing now refers to the assigned deadline; its rebuilt archive is included. Delivery retains fifteen minutes and actual living drop-off checks.
- **Ambush convoy:** random **1–3 cars**, two attackers per car, once per transport. **CET > DISPATCH CONTROLS > Ambush cars … (change)** cycles Random/1/2/3; **TEST: Trigger VIP ambush** uses that choice. Change it before the ambush starts; live-convoy changes apply to the next transport. Each car has its own placement, crew, actual mounting, chase, combat and cleanup. Reservations keep at least 12 m between cars and there is one hostile warning. The existing road/deck/barrier/camera checks remain. Cars without a safe start within the 20-second convoy window are skipped, so fixed 3 is a request subject to available space.
- **Arrest feedback:** unsuitable placement produces “Move the suspect to flat, clear ground and try again.” Technical paths and rejection counts stay in CET. Fresh placement checks retry briefly for up to about two seconds, allowing transient navigation after a carry/drop to settle. The navigation probe reaches 0.9 m; actual relocation remains within 2 m/0.75 m, with the same surface, activation and payment checks. No twenty-second cooldown was added. Persistent engine rejection on apparently flat ground still needs an in-game check; the new counters identify the failing check.

Install the **entire ZIP** and restart; CET announces **v0.16e** and VIP native interface is **3**. Includes the new `vip_ambush_unit.lua` and updated VIP archive. No new dependency. Twelve portable suites cover expanded selection/deadlines, fixed/random convoy sizes, crew ownership, deferred cleanup, partial failure and clean arrest notices; offline source/API compilation passes with and without optional BEF. Actual traffic, collision and animation still require game testing.

## v0.16d: terrain, VIP locations and ambush placement

[Download the complete v0.16d test ZIP](https://github.com/jonathankj2000-cpu/NCPD-Patrol-Officer/raw/refs/heads/main/releases/NCPD_Patrol_v0.16d_Terrain_VIP_Ambush_Fixes_TEST.zip)

- **Ragdoll arrests on uneven ground:** compare nearby candidates using navigation, real static floor normals and a complete lying footprint. Prefer a flatter patch within the existing 2 m/0.75 m limits. Native workspot sliding performs final placement; root height is checked after activation rather than blocking animation before entry. Failed placement still pays nothing.
- **Native R body pickup before arrest:** only Loot/F is replaced, preserving the game's pickup and other secondary choices. Pickup is guarded during the active securing request and returns after failure. This allows manual repositioning when there is no safe nearby patch.
- **VIP location fallback:** retain fast-travel routes, ignore their current interaction availability, and include native drop-point terminal markers if no fast-travel-only pair exists. Pickup remains 500–2000 m away; delivery is 800–2500 m from pickup. Active scanner clearance and arrival navigation checks remain. No fast-travel point is unlocked or registered. **Log VIP diagnostics** shows candidate counts and the selected source; regions without suitable world markers can still be unavailable.
- **Bridge/guardrail ambush checks:** use 35–65 m of recent driven route, denser samples, real surface/footprint checks and barrier checks along the car corridor. Verify the spawned car's actual lane position and height before creating crew. Crew spawn within the checked car footprint and board as each attaches. Misplaced cars are cleaned before another attempt, with a maximum of three attempts per trip. The hostile warning follows verified placement and actual boarding. Unsafe roads/camera views can defer an ambush.

Install the **entire ZIP** over the previous version and restart; CET announces **v0.16d**. Test arrest and R pickup near a curb, VIP assignment while driving in a district with few discovered terminals, then a manual VIP ambush on a bridge/divided road. If placement is rejected, the CET log reports requested/actual coordinates. Twelve portable suites and offline source/API compilation with and without optional BEF pass; live physics, traffic and the installed game cache require an in-game test. Partner weapon-state logic and existing reward ledgers are retained.


## v0.16c: patrol fixes

[Download the complete v0.16c test ZIP](https://github.com/jonathankj2000-cpu/NCPD-Patrol-Officer/raw/refs/heads/main/releases/NCPD_Patrol_v0.16c_Patrol_Fixes_TEST.zip)

- **Arrest living ragdolls:** before requesting the existing lying handcuff loop, the selected eligible suspect's ragdoll physics are released and a nearby navigation-supported position is checked. Displacement is limited to 2 m and 0.75 m vertically; path/support checks reject unsuitable ground. Death, life state, HP and defeat effects are not changed. EUR$250 still requires the existing acknowledged/stable workspot activation. Physics ownership is released on failure/cleanup, and a native body pickup retains its own physics ownership. Animated downed suspects keep their existing path.
- **Cyberpsycho dispatch from vehicles:** fast-travel interaction availability no longer filters out scene locations. Existing 500-2000 m distance tiers, NCART exclusion and occupied-scanner checks remain.
- **Repeat cyberpsycho incidents:** completion frees the dispatch immediately. Neutralized actors are retained for the existing 120-second/150-m aftermath and cleaned independently; their cleanup cannot clear a subsequent assignment's waypoint or journal. Three retained scenes is the resource bound. Failed/asynchronous deletion retains its owned ID for retry.
- **Bean Bagger inventory icon:** explicitly uses the verified vanilla Tactician icon. The blue-grip 3D appearance, Tier 2 reward and scoped non-lethal policy remain the same.
- **Partner:** weapon drawing/holstering retains its existing rules and native combat priority. The small follow refresh change cancels the previous owned indefinite follow command, matching backup, instead of accumulating requests.

Install the **entire ZIP** and restart; arrest interface is now **6**. Test a living physical ragdoll and an animated downed enemy, request a cyberpsycho while driving, complete it and request another, and check the inventory icon. Twelve portable suites and local source/API checks with/without optional BEF pass; actual game physics/rendering and compilation against the installed game cache still require confirmation.

## v0.16b: Bean Bagger blue grips

[Download the complete v0.16b test ZIP](https://github.com/jonathankj2000-cpu/NCPD-Patrol-Officer/raw/refs/heads/main/releases/NCPD_Patrol_v0.16b_Bean_Bagger_Blue_Grips_TEST.zip)

The Bean Bagger now has a muted matte blue pistol grip and pump fore-end, in a private ArchiveXL factory/appearance. Four authored masks cover first-person and third-person geometry. The stock panel, butt pad, receiver, barrel, sights and magazine cap retain their original materials. Vanilla Tactician files are not overridden. Original skinned geometry, rig, component bindings, pump animation, sounds and muzzle effects are retained.

Install the **entire ZIP** and restart, including `NCPDPatrol_BeanBagger.archive` and its `.archive.xl`. Test with **CET > NCPD CAREER > TEST: Give Bean Bagger (Tier 2)**, then equip it, aim, fire/reload and inspect it in inventory/photo mode. Compare against a vanilla Tactician. Appearance/tone and animation need an actual game test; local checks compile and round-trip all eleven resources, verify private paths and unchanged geometry/animations, and extract the packed archive to compare resource bytes.

Tier 2, the 20-incident reward, existing item/reward IDs, receipts, scoped non-lethal policy and all native gameplay scripts remain unchanged from v0.16a. ArchiveXL is already required by NCPD Patrol. The previous stock-appearance package remains linked below.

## v0.16a: M2038 NCPD Bean Bagger

[Download the complete v0.16a test ZIP](https://github.com/jonathankj2000-cpu/NCPD-Patrol-Officer/raw/refs/heads/main/releases/NCPD_Patrol_v0.16a_Bean_Bagger_TEST.zip)

Adds **M2038 NCPD Bean Bagger**, a fixed **Tier 2** Tactician variant for V, as an extra **20-incident reward**. Existing reward receipts are preserved: previous claims reopen only for the missing new weapon. **CET > NCPD CAREER > TEST: Give Bean Bagger (Tier 2)** grants one separate test copy per session without a milestone override or career receipt. The tiered test button also includes it. Partner equipment is unchanged.

Uses the handoff's stable `Items.NCPDBeanBagger_M2038` ID and **0.90 DamagePerHit multiplier**, with a registered custom name/description through the existing required Codeware provider. The original Pax package also contains a damage bonus, so it is replaced by an exact-weapon native hit policy. V's ranged Bean Bagger hits on human NPCs receive the game's **Nonlethal** flag; explicit kill/dismember overrides are removed from that hit. Further Bean Bagger pellets/hits on living downed, unconscious or pending-defeat targets receive zero damage. Native defeat restrictions remain in effect. The existing arrest interaction and EUR$250 payment need no special weapon hook.

**Stock Tactician appearance, audio, pump action and muzzle effects** are retained. Blue grips and altered flash/smoke were only specifications in the handoff; they are not claimed as built. Other guns, NPC firing, mechanical targets, quickhacks and explosions keep normal behavior. No global Pax record, vanilla weapon, NPC life state or partner assignment is modified.

Install the **entire ZIP** and restart. Includes the v0.15d compilation and v0.15e shift-entry fixes. The YAML deliberately replaces the handoff's original path so a normal install does not load a second definition. No new dependency or archive is needed. [Checks and native API evidence](tests/beanbagger/README.md) cover scoped hit handling, migration, reward/test receipts and actual CET handlers; native non-lethal outcomes, timing and rendered localization still require in-game validation. Use **Log Bean Bagger diagnostics** after firing to inspect the actual last target's death/defeat state.


## v0.15e: shift start compatibility fix

[Download the complete v0.15e test ZIP](https://github.com/jonathankj2000-cpu/NCPD-Patrol-Officer/raw/refs/heads/main/releases/NCPD_Patrol_v0.15e_Shift_Start_Fix_TEST.zip)

Fixes `Cannot start shift: Install the v0.15b trunk module`: shift entry still expected trunk interface 3 although the popup uses interface 4. It now delegates to the trunk bridge's single compatibility check. **Install the whole package and restart.** The v0.15d redscript files, which now compile in the user's game, are unchanged.

The new regression executes the actual `init.lua` and `trunk.lua` through CET Start/End Shift, native fast-travel requests and the optional hotkey. It verifies current interfaces start once, old/missing modules fail before duty/partner creation, and a failed check does not block a later successful start. Ten portable checks pass. All native scripts, tweaks, assets, existing gameplay and progression are preserved; in-game shift start still needs confirmation.


## v0.15d: redscript compilation hotfix

[Download the complete v0.15d test ZIP](https://github.com/jonathankj2000-cpu/NCPD-Patrol-Officer/raw/refs/heads/main/releases/NCPD_Patrol_v0.15d_Redscript_Compile_Fix_TEST.zip)

Fixes the two errors observed in the v0.15c game log: officer equipment now uses `Equals`/`NotEquals` for Bool values, and the trunk caller imports `Codeware.UI.*` so `ShowPopup` can resolve its `CustomPopup` parameter type. **Install the whole package and restart the game.** No dependency changes are required for these code fixes.

The existing two-row numeric menu, backup follow changes, officer readiness, 17 cyberpsycho variants and all other v0.15c gameplay are included. All other production scripts, tweak records and binary assets are preserved. Nine portable checks, including new compatibility guards for the observed errors, pass. The separate newer offline API checker also passes with/without optional BEF; it is not a compile against the installed game cache. Actual game compilation still needs confirmation.


## v0.15c: numeric trunk menu and officer AI fixes

Superseded by v0.15d above: v0.15c contains compilation errors.

[Download the complete v0.15c test ZIP](https://github.com/jonathankj2000-cpu/NCPD-Patrol-Officer/raw/refs/heads/main/releases/NCPD_Patrol_v0.15c_Numeric_Trunk_Officer_AI_TEST.zip)

At your police car's trunk, **hold R** for a native game popup with **four options per row, two rows**. Use **1** Available/Busy, **2** Repair, **3** New partner, **4** Cancel dispatch, **5** New dispatch, **6** Cop Stats, **7** 10-4 release backup, and **9** Close. Numpad digits and mouse selection also work. The native popup blocks gameplay quickslots. The original tap R backup and stash interactions return when it closes. Each choice routes to exactly one action; 10-4 is disabled without an assigned patrol. The existing required Codeware supplies this popup; no new dependency is added.

Active backup now receives follow commands toward V. The old on-scene code assigned a follower role but then permanently held both officers at the request location. Hold-position is now reserved for released backup. Vehicle use and native boarding receive priority; 10-4 still clears follower roles, requests actual stationary-vehicle exits, and retains the patrol until existing distance cleanup.

Officer readiness now checks actual held weapons. If a native primary-weapon command remains queued without equipping after one second, a native helper uses that officer's **existing inventory** through the game's equip/unequip routines and verifies the hand slots. Only this mod's tagged dynamic officers qualify. Alerted officers can draw with V but cannot be forced to holster; native combat, boarding and revive retain priority. **Log officer readiness (partner + backup)** in CET reports actual weapon state, command state and fallback outcomes.

Install the **entire ZIP** and restart. Trunk interface **4**, officer equipment interface **1**; 17 Lua modules and 26 redscript files are included. The 17 cyberpsycho variants, VIP ambush/aftermath, tyre repair, progression, payments and all binary assets are retained. Portable regression suites and offline source/API checks verify authored logic with engine boundaries mocked. Actual popup input, weapon poses and backup following require an in-game test.

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

1. Exit the game. Extract the **entire ZIP** into the game directory containing `bin`, `r6` and `archive`, replacing files. Restart; CET announces **v0.17a**. Include the incident reward script and bundled career, Cyberpsycho and VIP tweak/archive files.
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
