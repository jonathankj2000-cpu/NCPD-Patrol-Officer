r4a corrects the r4 startup compilation error: questNodeDefinition.id now
receives Cast<Uint16>(0), matching its Codeware field type. Compatibility lint
rejects the original untyped Int32 assignment. The newer offline compiler had
accepted it; the supplied game log is the evidence for this correction.

This r4 branch package is an opt-in native quest-marker experiment. It does not
replace normal scanner/VIP/cyberpsycho navigation. Those destinations are fixed
when assigned; live tracking of moving actors is outside this experiment.

Install the complete ZIP into the game root and restart the game. Keep the
existing dependencies. The native-node API was checked against Codeware 1.21.4
(6dfdbceff7882d8ad8632ab1ff8d42bcef20a8ad). Browser Extension remains optional.
Include the new quest-marker archive, its .xl, Lua module and redscript system.
No additional marker mod is required. The new test text is English.

1. Load a save, remain OFF DUTY and leave combat/wanted status/game menus.
2. Set an ordinary manual waypoint somewhere easy to recognize.
3. CET > Testing > Quest marker experiment > TEST: Start static quest marker.
   Default activation input sends exactly one Codeware ExecuteNode request.
4. Close CET. The test destination is fixed 150 m ahead of where V was facing
   at activation, at that starting elevation. The invisible target has no NPC,
   mesh, collision or interaction. It does not move with V.
5. Wait five seconds, then inspect the HUD and map. Check that your manual
   waypoint remains, that the separate test objective has its own quest marker,
   and whether selecting/tracking it produces GPS guidance. Try moving your
   ordinary waypoint while the test remains active.
6. Use Log quest marker test diagnostics and Remove quest marker test. Confirm
   the experiment disappears and the ordinary waypoint remains.

CONFIRMED requires an actual QuestMappin matching the private journal hash,
exactly one matching pin near the fixed target, and an objective-to-pin link.
ExecuteNode returning without an error is explicitly NOT success. Diagnostics
compare manual waypoint IDs before/after activation and removal without writing
to them. A native pin can be confirmed even if its UI/GPS behavior still needs
work; describe those separately in feedback.

If it says NOT CONFIRMED, log the complete line, remove the test and wait for
cleanup, then cycle Activation input to Enable and repeat; try In last. These
are controlled, empirical socket tests. The game-engine behavior of this node
when executed outside a normal quest graph is not yet confirmed. Do not run
multiple requests against a live test. A missing archive/module is an explicit
installation failure rather than a reason to retry activation inputs.

Map/game menus pause the experiment. Starting a shift, entering combat/wanted
status or ten minutes of active test time ends it. Normal removal restores the
previous active journal objective only if the experiment is still tracked.
A newer story selection takes precedence. The experiment only changes its own
journal entries and removes QuestMappins with its own journal hash.

Anchor deletion is confirmed before another test starts; deferred deletion
retains the current entity ID for retry. World loading forgets previous handles
and closes a saved active probe journal. The anchor does not persist through
saves. Install/revert with a full game restart, not CET hot reload. For a clean
rollback remove the test via its button, then install r3 and remove the four new
probe payload files listed in the verification report.

Validation: portable tests execute the authored native controller and actual
Lua coordinator against mocked engine boundaries, including no-pin responses,
wrong hashes/positions/links/types, duplicates, menu pauses, blocked retries,
foreign pins, manual waypoint changes and load/duty/cleanup cases. Existing
dispatch, VIP and CET comparison suites run with their original reference code.
The new resources are compiled, serialized back, inspected and extracted from
the packed archive with byte comparisons. Offline native compilation is run
with and without Browser Extension. Actual Cyberpunk compilation/rendering,
quest-node execution and GPS still require the above in-game test.
