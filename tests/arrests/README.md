# Arrest checks

Install Python 3 and `lupa`, then run from a repository checkout:

```sh
python tests/arrests/check_arrest.py
python tests/arrests/check_arrest_interactions.py
```

The authored redscript classes execute through a test-only syntax adapter; native APIs are mocked. The actual CET arrest module runs in LuaJIT. The harness executes the actual activation-proof class, native registration/payment system, production-result receiver and body-interaction wrappers.

The workspot boundary deliberately supplies no debug callbacks and makes legacy instance/device lookups unavailable. It independently models IsActorInWorkspot and the active/entering/exiting flags reported by the user. Continuous clean activation without a play-result event must register exactly once after 1.5 seconds. A successful event for the exact helper still requires 0.75 seconds settled activation. Negative pending results veto the attempt; wrong/duplicate/stale recipients cannot alter another request. A positive result without settled entry cannot pay. The test does not claim to know which clip renders: v0.7e intentionally credits activation rather than clip observation.

Other cases cover two-second securing, paused/hitch time, range/death/wanted, a competing workspot during resource loading, pending/failed/refused loads, missing components/tree, one-second pose-command limits after registration, life/exit cancellation, cleanup retries, world loads, saved identity history and independent scanner/arrest 1000/250 payments and receipts. ResourceHelper rejects the asynchronous component field; ResourceDepot tokens supply readiness.

These are logic/contract checks. Native event dispatch, real activation timing, rendered animation, AI, physics and native save loading are not emulated. The user confirmed visible workspot animation in v0.7c, but v0.7e registration and timed pose holding need an in-game test. Separate local checks compile all 15 redscripts against source-derived API contracts, not the actual game cache.
