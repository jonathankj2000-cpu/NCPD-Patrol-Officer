# One managed row and zero attached cached actors

The reported status from v0.18e1 is `Previous Officer Down scene cleanup
requested: 1 managed rows, 0 attached actors`, after both 90 seconds and 150 m.
That count describes the cached references, not a fresh lookup or pending spawn.
The previous retirement method admitted only private vehicle IDs with a positive
accepted-deletion receipt. It could never release a detached NPC's bookkeeping,
or a completed scene ID whose deletion was already marked pending before the
mod recorded an acceptance. Both cases reproduce the same permanent lock.

The new path applies to the exact private NPC and vehicle IDs created by this
catalogue scene. IDs are classified while binding, not only during late cleanup,
so detaching/losing record data does not erase an earlier ownership proof.
After the quest has closed, a detached ID may transfer to the bounded native
receipt list only in the current world, with no attached cached object, no
attached object from a fresh Codeware lookup, and no pending IsSpawning result.
Normal accepted-deletion receipts still work. Only a fully completed scene may
instead use a recorded explicit refusal after Codeware still reports IsManaged.
An API exception is not converted into an explicit refusal. Failed/partial
scenes retain their accepted-receipt requirement.

This changes bookkeeping, not NPC life/defeat/animation or physical destruction.
NPCs never enter the optional CET Dispose path. A live or pending-spawn actor
continues to hold the scene. Detached IDs remain owned in a 256-entry native
receipt list, are pruned after manager removal and forgotten on world change.
The active created-ID registry clears only after those ownership transfers and
the physical-reference checks succeed. No arbitrary timeout clears actor IDs.

Status/diagnostics now distinguish cached attached actors and fresh lookup
attached/spawning/errors. Each pending log row includes kind, record, ID,
accepted/refused deletion and lookup observations. The message therefore no
longer implies that zero cached handles proves the whole world is clear.
Existing raw logs remain readable; `detached_actor_id_retired` records the new
generic handoff. It does not affect career/incident counters or payment ledgers.

The regression suite loads the actual v0.18e1 Lua/native owner as a negative
control. A private NPC with accepted or refused deletion, and a vehicle with
refused deletion, each remain at one pending row and zero attached handles in
that version. The current owner clears the scene, retains the stale ID, starts
another incident and pays once. Fresh-live and pending-spawn cases remain
blocked until the new lookup becomes clear. Existing multi-call, marker reuse,
optional CET absence, partial/refused cleanup, world/CET recovery and reward
checks still run. The new IsSpawning contract comes from Codeware 1.21.4's
`scripts/World/DynamicEntitySystem.reds`, not an invented engine import.

The actual single row in the user's game was not identified by the old status
message. These tests cover concrete source gaps that can produce that symptom;
real game cleanup still requires playtesting. All 44 scripts are source/API
compiled with and without Browser Extension, including the earlier Dispose
compile-failure negative control. No unsupported REDscript Dispose import or
direct call is reintroduced. Cleanup API is now version 3: install the complete
package and fully restart the game.
