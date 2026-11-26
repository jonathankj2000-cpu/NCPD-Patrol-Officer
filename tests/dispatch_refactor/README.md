# Dispatch refactor regression

`PYTHONPATH=<lupa install path> python tests/dispatch_refactor/check_refactor.py`

Requires LuaJIT through `lupa==2.6` and Git history containing the pinned v0.17d
commit. The test materializes that commit's 18 Lua modules in a temporary
directory, then compares them with the refactor under identical engine fixtures
and seeds. It executes authored native code using the existing translator.

The existing native/mixed/background/partial-cleanup scenarios and additional
scanner contracts run in both runtimes. After every public command/update, the
trace checks observable state, results, RNG, timers, journal tokens/stages,
money, notices, marker registry and owned actors. Source locations in thrown
Lua errors are normalized because moving code necessarily changes line numbers.
Scheduler diagnostics add flags intentionally; the existing scheduler status
text and every pre-refactor public function remain part of the comparison.

Refactored-only lifecycle assertions check that assignment, foreground cleanup
and reservation agree, that background cleanup remains separate, and that reads
have no RNG/timer/quest/actor side effects. Mutating a returned view must not
mutate module state. A temporary baseline mutation adds one second to a timer;
the comparison must detect it. Production source is never mutated by the test.

`--report <path>` writes the comparison count/digest and scenario inventory.
These are engine-mocked regressions, not an in-game validation.
