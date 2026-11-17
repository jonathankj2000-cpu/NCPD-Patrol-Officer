# Arrest checks

Install Python 3 and `lupa`, then run from a repository checkout:

```sh
python tests/arrests/check_arrest.py
python tests/arrests/check_arrest_interactions.py
```

The authored redscript classes execute through a test-only syntax adapter; native APIs are mocked. The actual CET module runs in LuaJIT. The harness consumes **assets/arrest/arrest_lying_loop.workspot.json**, resolves handles and represents native CBool fields as booleans. Node handles and entry IDs deliberately differ. The controller must make one jump to entry ID 2, issue no play signal and send no periodic jumps over a simulated paid interval.

Source and private resource tokens are independent. Tests cover pending/missing private assets, malformed exit-capable topology and unreadable source bindings before playback. Animation/rig/prop data is copied only to the private resource; source transitions/status stay untouched, while the authored loop/root/status/tags stay private. Both native rig setups and their setup hashes are preserved. Archive topology/serialization is independently checked by the WolvenKit build tool.

Existing cases execute the actual activation proof, result receiver, interaction and payment code: missing debug/clip data with stable native fallback, exact-helper positive/negative/stale results, no-entry/transition states, timers/menus, eligibility/range/death/wanted, asynchronous failures, cleanup retries, world loads, saved paid identities and independent scanner/arrest 1000/250 payments and receipts. Unverified StopInDevice or ambient deletion calls fail the fixture.

These are logic/contract checks. They do not emulate native metadata initialization, animation rendering, AI, physics, event dispatch or native save loading. The user confirmed registration/payment in v0.7e and the physical private lying loop in v0.7f. v0.8a retains the arrest source and archive unchanged. Separate local checks compile all 15 redscripts against source-derived API contracts, not the actual game cache.
