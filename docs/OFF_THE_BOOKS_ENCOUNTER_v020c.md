# Off the Books restaurant encounter — v0.20c

The existing Voss conversation, its continuation receipt, actor records, readable
shard, ten archives, dispatch and duty implementations are unchanged. This patch
adds three narrow PSM decision wrappers, native corpse-loot refresh, and fields
in the existing **Log Off the Books diagnostics**. No additional dependency.

## What the sources establish

Game sources: [MOD_Development_Reference, 81d996b5](https://github.com/In-Question/MOD_Development_Reference/tree/81d996b584a693e8b0f0b20526a9fa38b5c83fe7/DecompiledGameScripts).
Existing Codeware fields were checked against 1.21.4, commit
`6dfdbceff7882d8ad8632ab1ff8d42bcef20a8ad`. Tweak record definitions were checked
against Cyberpunk-Tweaks `0f39f780c92ca389f97fc19cb5ba3c10ba32dd7d`.

### Weapon restriction

1. `DefaultTransition.GetCurrentSceneTierData` reads the permanent **SceneTier
   stimulus object** in `StateContext`; this is distinct from writing a player
   blackboard integer.
2. `SceneTierInitialDecisions.EnterCondition` enters the scene state machinery
   when its requested tier exceeds 1. `SceneTierIIDecisions.EnterCondition`
   accepts a requested `Tier2_StagedGameplay`.
3. `SceneTierAbstractEvents.OnEnter/OnUpdate` applies the request's `emptyHands`
   flag and maintains its HighLevel state. Tier2 also has native locomotion and
   speed setup/teardown. `ForceEmptyHandsDecisions` consumes the force flag;
   `ForceEmptyHandsEvents` unequips weapons and reports UpperBody 5.
4. Removing that one flag would be insufficient: the separate
   `WeaponReadyListenerTransition.OnHighLevelChanged` considers HighLevel 2–5
   safe scene tiers. Its ready predicate rejects firing in those tiers unless
   a scene explicitly forces aim. Draw/switch logic also has its own guards.
5. `PlayerPuppet.OnEnterSafeZone` uses `ForceEmptyHandsByZone` and Zones 2.
   The reported Zones 1 and negative safe-area/effect tests do not identify that
   branch as the blocker.

No Off the Books encounter code or its journal requests SceneTier 2. The
inside/outside change is consistent with a native area request. **The exact
restaurant volume/quest node sending it is not proven**: these REDscript sources
expose the stimulus and its consumers, not that native sender. The new diagnostic
records the existing Codeware `SceneTierData.userDebugInfo` when available;
an empty/debug-only value is not proof of a particular world trigger.

### Corpse looting

| Question | Source finding and limitation |
|---|---|
| NPC base | `Character.CorpoManArasaka` derives from `Crowd_NPC_Base`. Setting the private record's `isCrowd: false` does not prove which components/descriptor the spawned template exposes. No live component result has yet been supplied. |
| `items: []` | The base list contains crowd accessories such as phones, cigarettes, bags and an umbrella. Emptying that list does not itself create/remove an Inventory or Loot interaction descriptor. It is retained. |
| Inventory quantity | `GiveItem` plus quantity readback establishes that seeding worked, not that a loot input is available. Before/after-death quantities now have separate saved observations, plus a live quantity. An unloaded/legacy observation is reported as unknown rather than fabricated. |
| Accessibility | `ScriptedPuppet.UpdateLootInteraction` enables native `Loot` only for an inactive puppet whose Inventory component reports `IsAccessible()`. |
| Container/highlight | `ScriptedPuppet.IsContainer` also depends on cached loot quality. `OnItemAddedEvent` only evaluates quality if it is already valid: adding a shard need not initialise an invalid cache. The previous seeder did not explicitly refresh it. |
| Shard tags | `HideInBackpackUI`, `HideAtVendor` and the readable tags are vanilla `BaseShard` behavior. `Quest` promotes quest-loot quality range/highlighting in `EvaluateLootQuality`; it is not evidence of a hidden corpse item. Existing tags/read action/journal entry remain unchanged. |
| Lifetime | Existing `persistSpawn`/`persistState`, unique role tags and created-role facts remain. The mod does not delete the corpse on death, stage change, leaving the area, or taking the shard. Explicit test cancellation still cleans owned actors. Actual engine corpse serialization needs an in-game test. |
| Acquisition | The original player item handler runs first. The exact positive-quantity item event records the receipt, even when the native readable immediately consumes its inventory instance into Shards. Death never grants evidence. |

The sources establish separate loot prerequisites and a refresh gap. They do
**not** yet prove that the affected contractor has missing components, an
inaccessible inventory, an invalid quality cache, or an absent native Loot
descriptor. Diagnostics distinguish those outcomes; this patch does not claim
that inventory quantity alone verifies the reported UI failure.

## Implementation

The combat exception applies only while Eliminate or Retrieve is actually active
in the journal, off duty, with the first briefing receipt and the owned target
bound. V must be within 20 m of `(-649.795, 929.771, 9.400)` and within 3 m of
that floor. It only handles a real Tier2 request with `emptyHands=true` and
HighLevel 1/2. Native dialogue, scene animation, Voss's active briefing,
workspots, vehicles, takedowns, swimming transition, cinematic tiers, safe-zone
force flags, the independent ForceEmptyHands quest fact and the four tested
restriction effects all retain their native decisions.

Inside that scope, the three wrappers allow native `ToExploration` and prevent
immediate Tier2 re-entry. **Native ExplorationEvents**, not mod blackboard writes,
resets force flags, scene overrides and HighLevel. Its normal listener updates
WeaponReady. The raw SceneTier request is never changed. Leaving scope, looting,
cancelling, interruption, or unready/restoring sessions removes the decision
exception; the still-present native request regains control. No permission or
restoration state is saved. Wanted, civilian reactions and enemy hit/AI handlers
are not wrapped or disabled by this fix.

For the owned dead contractor while the shard is still present, the owner asks
for native `SetLootInteractionAccessibilityEvent(accessible=true)` if necessary,
requests `EvaluateLootQualityEvent`, and refreshes ordinary Loot/interaction
state. Queue acceptance is not success: subsequent component/container readback
controls retries. At most eight attempts, one second apart, run for an attached
actor; restore/rebinding resets this transient budget. The item is neither
removed from the corpse nor given to V by this repair.

Missing/disabled components or rejected native accessibility delivery remain
visible in diagnostics, with Retrieve still active. No actor replacement,
component fabrication, separate physical pickup or simulated dialogue pickup
is silently used. If prerequisites become ready but no native Loot input appears
while looking at the body, inspect the live template/interaction descriptor
before choosing that alternative.

## Diagnostics and in-game test

Install the **complete 131-file package**, overwrite and restart the game. Do
not clear a working v0.20b quest just to update. Existing stage, cycle, created,
seeded, killed and acquired facts are retained. New quantity/event observations
use additional facts; historical quantities cannot be reconstructed from a save
made after death.

1. Finish the existing Voss briefing, or resume a saved active encounter.
2. Enter the restaurant and draw, equip and fire. The requested tier may remain
   **2** by design; HighLevel should be native Exploration **1**, and UpperBody
   should leave ForceEmptyHands **5**. Confirm restrictions return outside the
   exception and during unrelated dialogue. Do not remove status effects in CET.
3. Before the kill, log Off the Books diagnostics. Expect the actual private
   contractor record, valid shard, `seeded=1`, live quantity 1 and a live target.
4. Kill him and wait 2–3 seconds. Expect `killed=1`, `acquired=0`, stage 2 and
   after-death/live quantity 1. Killing alone must not advance to Return.
5. Approach/look at the corpse. Check ordinary loot UI, the named readable
   shard and actual pickup. Diagnostics distinguish **unavailable** native
   prerequisites, **not observed** input despite readiness, and **available**
   native Loot input for V. An active input still needs visual UI confirmation.
6. Taking the shard must set `acquisition event=true`, `acquired=1` and activate
   Escape if wanted, otherwise Return. Read it in Shards. Escape wanted and
   return to retained Voss. The final debrief/reward remains future work.
7. Repeat from saves before death and after death/before pickup. Leave and return
   before taking the shard. Check the same saved contractor, one shard and the
   correct objective. Also reload after pickup: no shard or target replacement.
8. Cancel the test while inside the restaurant and confirm normal weapon
   restrictions return. A cancelled, returned or completed encounter cannot
   keep the exception active.

## Verification boundary

42 portable suites include the existing full Voss/continuation/dispatch checks.
The added test executes all three actual wrappers, native PSM reset/decision
and weapon-ready methods, native loot cache/interaction methods, real exact-item
observer, wanted-stage progression, rejected native deliveries and transient
reload recovery. It reproduces the two logical gaps independently of the patch.
The pinned game method excerpts and hashes are in
`tests/off_the_books/game_reference.json`; they are test data, not installed
replacement game scripts. All ten archives and first-scene inputs are frozen.

The offline source/API compile runs with Browser Extension present and absent;
legacy Bool/String/operator guards and the known invalid Dispose negative
control are retained. This is **not** compilation against the user's actual
game cache. Native PSM scheduling, exact area sender, native accessibility event
delivery, rendered loot UI, gunfire and real save serialization still require
the above in-game test. No live game success is claimed by the offline results.
