# Officer Down cleanup and repeat requests

Historical v0.18e design notes. Its direct REDscript Dispose call failed in the
reported game cache; [v0.18e1](STARTUP_FIX_v018e1.md) removes that call and the
incorrect offline import. Disposal is now only a capability-checked CET attempt.

The report from v0.18d shows `phase=aftermath`, `stage=3`, aid completed, zero
remaining enemies, zero active quest pins, three pending actor rows and ten
retained handles. The player had exceeded both 90 seconds and 150 m. This proves
the quest reached its success state and actor cleanup still holds the next call.
The count matches the three scene vehicles, but that older diagnostic cannot
identify the remaining actor types or prove the engine-side cause.

## Source evidence and intervention

Codeware 1.21.4 `DynamicEntitySystem.cpp:172` accepts `DeleteEntity` once, marks
its state deleted and requests population/stub removal. Later calls return false
when the state is already marked deleted. Its ID registry is removed after a
despawn callback; repeatedly calling DeleteEntity is not another removal request.
The original shared remover retained every still-managed ID indefinitely.
Officer Down additionally waited for cached physical handles before clearing
its native created-ID registry, so a pending vehicle could lock this type forever
while the other dispatch types remained available.

The default actor remover is unchanged when its new optional acknowledgement
callback is absent. Catalogue Officer Down supplies that callback to record only
successful Codeware delete requests in its native same-world ownership registry.
After five active cleanup seconds, a still-attached private scene vehicle may
receive one native `Entity.Dispose` request. That engine entrypoint is exposed in
the game definitions and used by Codeware's static-entity teardown. Calling it
is a request, not a success test. Both physical detachment and manager cleanup
remain observed before normal ownership is cleared.

The native helper requires a completed/closed assignment, current generation,
an exact ID created by this scene, the cached object reference, a recorded
Codeware acceptance and one of the two private vehicle records. It never
disposes NPCs, partners, backup, ambient/owned-player vehicles or arbitrary IDs.
It rejects active-scene, unready/stale-world and duplicate requests. A refused
Codeware deletion without an acceptance receipt keeps ownership and cannot use
this fallback. Partial setup and CET reload retain the same deletion receipts.

If a vehicle is already physically gone but Codeware still keeps its deleted ID,
the ID is transferred to a separate native receipt list. This requires the exact
owned vehicle classification, prior accepted deletion, no attached cached object
and no attached Codeware object at that ID. Only then can the scene release its
foreground created-ID registry. The ID is not forgotten: the receipt list is
polled once per active second, pruned after manager removal and cleared on world
change. It holds IDs, not actor handles, and is bounded at 256. If the bound is
reached, additional rows remain pending rather than being silently discarded.
These receipts survive CET reload and never delete reused IDs after save/load.
Native cleanup bookkeeping ticks during aftermath/cleanup as well as active/idle.

## Requests, reporting and existing behavior

The old direct catalogue request returned false silently during aftermath. A
valid manual request now checks eligibility and a suitable next location, then
ends the completed scene's retention early and requests cleanup. It starts the
next token/marker only after cleanup succeeds. Asynchronous cleanup reports its
state; the user can retry after the scene-cleared message. Automatic requests
retain 90 seconds / 150 m and can select another type during aftermath.

Cleanup API errors are retried without changing an already successful quest into
a failed/foreground-blocking assignment. Pending cleanup reports once after
15 seconds. Diagnostics include pending vehicle/NPC/unknown counts, actual attached
handles, accepted deletions, one-shot native disposals and retained detached IDs.
Gameplay JSONL adds cleanup-error, disposal and ID-retirement events and the exact
pending row kinds/records/IDs. Existing raw logs and summary export are preserved.

No engine pin is unregistered, no manual waypoint is replaced and no reward is
reset. Dual completion still pays EUR$2000 and one career incident exactly once.
The 45/27/18/10 mix, site catalogue, other incident owners, survey behavior,
Career Start/End Shift and partner police-hit guard remain intact. The fallback
uses the catalogue's created-ID registry; the separate original fixed-point
legacy prototype does not gain an untracked disposal path.

## Validation and limits

The new portable suite executes the actual facade, scene controller, native
owner and marker/reward ledgers. It reproduces the reported stage/three-row/
ten-handle shape with accepted car deletion that stops acknowledging removal.
The old v0.18d module fails both the repeat-request and stalled-car controls.
The new controller completes three sequential incidents, reuses the original
authored pin and pays EUR$6000 once across those three incidents.

Cases cover normal automatic retention, other-type fallback, pending physical
detach after Dispose, outright deletion refusal, late Codeware ID acknowledgement,
retained receipt pruning, private-object/type/world guards, CET reload, partial
cleanup, unavailable contexts, API errors and world-ID reuse. Existing survey,
layout and gameplay suites still run. All 44 native scripts are separately
source/API compiled with Browser Extension both present and absent.

Engine teardown and Codeware callbacks are mocked boundaries. The old in-game
line does not prove which three actors or which engine condition caused the
stall. Actual vehicle Dispose/manager acknowledgement and repeated gameplay
remain in-game checks. Install the complete package and fully restart the game
so the new native cleanup methods match the Lua controller.
