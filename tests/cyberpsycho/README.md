# Cyberpsycho encounter checks

Run with Python 3 and lupa:

    python tests/cyberpsycho/check_cyberpsycho.py

The actual authored native controller executes through the shared syntax
adapter. Tests cover exact private-record/target admission, death and both
non-lethal states, stable confirmation, unrelated deaths, target disappearance,
menus/time deltas, distance abandonment, duty/wanted/death, journal write failures,
tracking preservation, stale tokens and simulated save/load reconciliation.

The real CET encounter module and dispatcher execute with native creation,
navigation, actor, AI, journal and widget boundaries mocked. Scenarios cover
spawn/AI delay, invalid points/paths, refused requests, pre-spawn resource checks,
identity verification before hostility, setup rollback, one entity reservation,
rejected/deferred deletion, world reset without stale deletes, ordinary dispatch
mutual exclusion and cancel/replace/shift-end routing. Existing payments must
remain untouched. The source asset topology and TweakXL clone are also checked.

The generated archive receives separate WolvenKit compilation, round-trip and
exact extracted-resource checks in the release builder. All 23 production
redscript files pass source-derived API checks with and without optional BEF.
Neither these checks nor native mocks validate live combat, navmesh placement,
the final rendered journal or true game serialization. Those need a game test.
