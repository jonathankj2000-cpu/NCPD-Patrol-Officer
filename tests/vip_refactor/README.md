# VIP extraction contracts

`python tests/vip_refactor/check_vip_refactor.py` requires `lupa==2.6` and Git
history containing r2 `a9b654fed01145dd908ffe82de6e097bf2917c56`.
`--report <path>` writes JSON comparison metadata.

The pinned old and current actual VIP modules run the same three VIP and four
generated/mixed-dispatch scenario files. Existing translated native quest/reward
code runs; engine/physics/animation boundaries are mocked. An observer records
RNG, registry API calls, facade results/diagnostics, native tokens/stages, actor
ownership, notices, payments and cleanup. Lua source filenames/line numbers in
thrown errors are normalized because extraction necessarily changes them.

`source_guard.py` verifies unchanged moved policy bodies, reconstructs the old
coordinator by undoing delegation, rejects actor/journal APIs in helpers and
permits only the three build-label edits in the entrypoint/UI. Helper contracts
exercise independent marker/location instances, failed deletion/placement,
repair counters, read/reset side effects and numeric marker ID reuse after load.

The recovery mutant changes the cooldown from five to six seconds. Actual
VIP request/update probes must detect it; production source is never modified.

Since v0.17f intentionally replaces geographic selection, historical synthetic
actor/dispatch scenarios inject the actual v0.17e2 location provider from Git
at that helper boundary. The old coordinator remains unchanged and the current
coordinator is still reconstructed byte for byte. Thus identical historical
traces describe actor/scheduler behavior with legacy geography, not unchanged
new route selection. `tests/vip_routes/check_routes.py` exercises the real
baked selector, an empty live-terminal pool, history, canonical positions and a
100-to-120 m scanner-clearance mutant. The native marker suite executes all
360 pairs through both actual native stages. No legacy selector ships in the mod.

This is a contract/regression suite, not a game emulator or a traffic/GPS fix.
