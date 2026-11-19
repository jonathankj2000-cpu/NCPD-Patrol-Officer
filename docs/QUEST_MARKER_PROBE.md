The r4b branch package corrects the quest-marker node contract. The previous
default/Enable inputs produced zero native quest pins in the supplied in-game
diagnostics. Matching journal/node hashes proved neither node activation nor
successful world-target resolution.

The node now receives Active when starting and Inactive when removing. These
are the input sockets defined by the [WolvenKit editor implementation](https://github.com/WolvenKit/WolvenKit/blob/c6065b22f70cb0a53913f5440d112ab1b7dd00a4/WolvenKit.App/ViewModels/GraphEditor/Nodes/Quest/questMappinManagerNodeDefinitionWrapper.cs).
The containing quest file entry index is now 2 for
quests/minor_quest/ncpd_patrol_marker_probe/...; the old -1 was the class's
unconfigured default. The [quest resource authoring documentation](https://hlky.github.io/cyberpunk-quest-authoring/journal/mappins.html#activating-and-hiding-a-quest-pin)
explains this index and identifies a concrete SQ021 vanilla resource for
comparison. Its examples do not prove this standalone Codeware test will run.
The r4a explicit Cast<Uint16>(0) node-ID compilation fix is retained.

This remains an opt-in native marker experiment. Normal scanner/VIP/cyberpsycho
navigation keeps its existing behavior. Destinations are fixed when assigned;
the test does not add live moving-target tracking.

Install the complete ZIP into the game root and restart. Existing dependencies
remain sufficient; the native API was checked against Codeware 1.21.4
(6dfdbceff7882d8ad8632ab1ff8d42bcef20a8ad). Browser Extension is optional.
Include the quest-marker archive/.xl, Lua module and redscript system. The probe
system is interface version 2 so mixing the older native file with new Lua is
rejected on explicit use. New test text is English.

1. Load a save, remain OFF DUTY and leave combat/wanted status/game menus.
2. Set an ordinary manual waypoint somewhere easy to recognize.
3. CET > Testing > Quest marker experiment > TEST: Start static quest marker.
4. Close CET and wait five seconds. The stationary, invisible target is 150 m
   ahead of V's starting position, at that starting elevation. It has no mesh,
   collision, NPC or interaction and does not move with V.
5. Inspect the HUD/map for an independent quest marker, with your ordinary
   waypoint still present. Check whether tracking the objective gives GPS.
6. Use Log quest marker test diagnostics, then Remove quest marker test. Confirm
   the test disappears and your ordinary waypoint remains.

There is no activation-input cycling in r4b. Each start issues exactly one
Active request. CONFIRMED requires exactly one actual QuestMappin matching the
private journal hash near the fixed target and an objective-to-pin link.
ExecuteNode returning without error is explicitly not success.

Diagnostics report the actual node file-entry index, private anchor attachment
and displacement, pin count/hash/link, and manual waypoint IDs before/after
creation/removal. If NOT CONFIRMED persists, report the full line and remove
the test. Anchor attachment proves the private object exists; it does not prove
the engine can resolve the journal's tagged target. That boundary remains for
in-game verification after the corrected activation request.

Menus pause the test. Starting a shift, entering combat/wanted status or ten
minutes of active test time ends it. Removal restores the previous active
journal objective only if the experiment is still tracked; a newer story
selection takes precedence. Writes are scoped to the private journal and
QuestMappins with its own hash. No manual waypoint write/untracking is used.

Anchor deletion is confirmed before restart; deferred deletion retains its
current ID. World loading forgets old handles and closes a saved active probe
journal. The anchor does not persist through saves. Install/revert with a full
game restart. For clean rollback remove the test, install r3, and remove the
four probe payload files listed in the verification report.

Portable tests execute the authored native controller and actual Lua coordinator
with engine boundaries mocked. The node boundary now enforces the sourced state
inputs and containing-quest index; negative controls must reject old index -1,
Enable activation and Disable cleanup. No-pin responses remain failures, and
hash/position/link/type, duplicate, menu, load, duty, manual waypoint and cleanup
cases remain covered. Existing dispatch/VIP/CET reference comparisons run too.
Resources were compiled, round-tripped, extracted and byte-compared. Offline
native compilation runs with and without Browser Extension. Actual game-cache
compilation, standalone node execution, target resolution, UI and GPS still
require the above in-game test.
