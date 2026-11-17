# Arrest checks

Install Python 3 and `lupa`, then run from a repository checkout:

```sh
python tests/arrests/check_arrest.py
python tests/arrests/check_arrest_interactions.py
```

The authored redscript classes execute through a test-only syntax adapter; native APIs are mocked. The actual CET arrest module runs in LuaJIT. Checks cover eligibility, interruption, one payment per saved actor identity, independent scanner/arrest accounting, receipts, duplicate/stale events, body interactions, resource/component/tree readiness, asynchronous token waiting/failure, explicit clip/play, one retry, three-second release, observed clip/ownership guards, menus, scene departure, failed cleanup and loaded-away references.

The fixture now follows Codeware 1.21.4's type restriction: ResourceHelper rejects the component's asynchronous workspotResource property. That corrected boundary reproduces the v0.7b abort. v0.7c uses ResourceDepot.LoadResource and waits without restarting the request; only a loaded token can supply a resource. Failed/refused/finished-but-unloaded tokens cannot start playback or pay an arrest. These mocked checks do not establish that native playback renders the intended pose.

These are logic/contract checks, not an emulator of game AI, native serialization, animations, targeting or physics. In-game F interaction and workspot playback still need a manual game test. Separate local checks compile all redscripts against source-derived API contracts; those contracts are not the actual Cyberpunk script cache.
