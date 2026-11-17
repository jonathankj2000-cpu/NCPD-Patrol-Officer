# Trunk patrol menu checks

Install Python 3 and `lupa`, then run from a repository checkout:

```sh
python tests/trunk_menu/check_trunk.py
```

An optional first argument selects a separate game-install root. The harness
uses the shared syntax adapter in `tests/arrests/translate.py`, executes the
actual authored trunk system/menu action/repair wrapper and scanner-count
getter, and runs the actual CET `dispatch.lua`, `partner.lua` and `trunk.lua`
modules in LuaJIT. Native boundaries are mocked; no game process is required.

Cases cover input before/after the interaction and release, hold/tap distinction,
release suppression, duplicates, other inputs, missing input failing closed,
range/mount/pause/death/ownership guards, action record mapping, scoped menu
selection, command consumption, busy automatic versus active/manual calls,
waypoint cleanup failure, ten-second repair against the original vehicle,
menu pauses and repeated requests, lost/wrecked vehicle and duty/load cancellation,
partner deletion rejection/unready/missing actors, and read-only milestones.
The native repair wrapper is executed against health, tire and body/glass mocks.
Existing arrest and scanner payment ledgers stay independent.

Reference signatures come from the decompiled `VehicleComponent`,
`VehicleComponentPS`, `vehicleWheeledBaseObject` and listener definitions in
[MOD_Development_Reference](https://github.com/In-Question/MOD_Development_Reference/tree/81d996b584a693e8b0f0b20526a9fa38b5c83fe7),
and Codeware's [DynamicEntitySystem](https://github.com/psiberx/cp2077-codeware/blob/60c4ab59035f5eda98669464e78f8027813e1953/scripts/World/DynamicEntitySystem.reds).
The production radio control uses the same engine-time press/release pattern.

These are logic/contract checks. They do not validate native input delivery,
the rendered choice list, real repair visuals/physics, AI or save loading.
For the game test: tap at the trunk for one backup, hold for the menu without
backup, release without closing it, select with F and close with a fresh R.
Check Busy with a live assignment, manual replacement while Busy, repair after
ten gameplay seconds, partner replacement, and stats without progression payouts.
