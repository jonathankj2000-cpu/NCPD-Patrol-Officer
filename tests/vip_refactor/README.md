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

Two temporary mutants change scanner clearance from 100 to 120 m and recovery
cooldown from five to six seconds. Actual VIP request/update probes must detect
both changes. They never modify production source.

This is a contract/regression suite, not a game emulator or a traffic/GPS fix.
