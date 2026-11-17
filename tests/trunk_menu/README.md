# Trunk patrol menu checks

Install Python 3 and `lupa`, then run from a repository checkout:

```sh
python tests/trunk_menu/check_trunk.py
```

An optional first argument selects a separate game-install root. The harness
uses the shared syntax adapter in `tests/arrests/translate.py`. It executes the
actual trunk system, backup/hold/menu action classes, both PS trunk wrappers,
entry callbacks and action-list helpers, repair wrapper and scanner-count getter.
Actual CET `dispatch.lua`, `partner.lua` and `trunk.lua` run in LuaJIT. Native APIs,
casts and action constructors are mocked; branch/loop/routing logic is authored.

The v0.8b failure waited for a press on `Choice2`, which accepts only
`BUTTON_RELEASED` in the native `InteractionActions` context. `Choice2_Hold`
accepts `BUTTON_HOLD_COMPLETE`, shares the same binding, has higher priority and
uses a vanilla 0.3-second hold. InteractionBase `action` is a String, not CName.
v0.8c uses two explicit native interaction records; it has no raw input listener,
press prerequisite or custom hold timer. Entry callbacks also work before the
first CET Tick. Calls to the old listener or incorrect CName lookup fail fixtures.

The minimal [native input excerpt](native-choice-context.xml) is a test reference
from [Input Loader's fallback vanilla context](https://github.com/jackhumbert/cyberpunk2077-input-loader/blob/2758cd8ab54e340f4531a1e0adb13d8b0231d998/fallback/inputContexts.xml).
It is **not installed into the game** and introduces no Input Loader dependency.
The tests check that the authored backup/hold records use these exact native
input names/events; they do not recreate the native input manager's arbitration.

Cases cover release-only backup, native hold callbacks, duplicate menu open,
old cached backup after hold, scoped commands, both actual trunk action lists,
stash/menu restoration, range/mount/pause/death/ownership/duty guards, busy versus
active/manual dispatch, cleanup failure, exact-vehicle ten-second repair,
menu pauses/repeated requests/lost vehicles, partner deletion rejection,
read-only milestones and world/duty cleanup. Native repair health, tires and
body/glass boundaries are mocked. Scanner/arrest ledgers remain separate.

Reference methods/metadata come from `VehicleComponent`, `VehicleComponentPS`,
`InteractionBase_Record`, `gameinteractionsChoiceEvent` and `vehicleWheeledBaseObject`
in [MOD_Development_Reference](https://github.com/In-Question/MOD_Development_Reference/tree/81d996b584a693e8b0f0b20526a9fa38b5c83fe7),
and Codeware's [DynamicEntitySystem](https://github.com/psiberx/cp2077-codeware/blob/60c4ab59035f5eda98669464e78f8027813e1953/scripts/World/DynamicEntitySystem.reds).

These are logic/contract checks. Native input arbitration, hold/release delivery,
rendered icons/choice list, repair visuals/physics, AI and native save loading
still need in-game testing. At the trunk expect separate tap-R backup and hold-R
Patrol Menu prompts. Hold must not request backup, and its release must leave the
menu open. Scroll/F select; a fresh R closes and restores the stash/entry choices.

## Countdown type regression

`ceilf-contract.reds` records `CeilF(Float) -> Int32` from the reference globals
and `core/math/scalar.swift`. Both supplied game-2.50 compiler logs confirmed the
v0.8a invalid identity cast at `NCPDPatrolTrunkSystem.reds:87`. The previous local
fixture incorrectly declared a Float return. v0.8b fixed the getter; v0.8c retains
it. `check_ceil_type.py` compiles the actual corrected getter, reinstates the old
cast and requires its rejection with the same contract. With the local compiler
API driver:

```sh
python tests/trunk_menu/check_ceil_type.py /path/to/ncpd-check
```

This checks that specific type error; it does not replace the actual game cache.
