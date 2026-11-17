# Arrest checks

Install Python 3 and `lupa`, then run from a repository checkout:

```sh
python tests/arrests/check_arrest.py
python tests/arrests/check_arrest_interactions.py
```

The authored redscript classes execute through a test-only syntax adapter; native APIs are mocked. The actual CET arrest module runs in LuaJIT. This includes the actual `NCPDPatrolArrestPlayback` callback class, rather than a mock claiming that a native request succeeded.

The workspot boundary deliberately returns nil from both GetWorkspotInstance and GetDeviceUser, matching the reported v0.7c case. Native setup/animation callbacks must supply the matching path and lying clip to permit one payment. Wrong/missing/transition/foreign/superseded/stale callbacks cannot pay. Active playback with no callbacks cannot pay. A paid standing transition returns to lying without another payment; an ignored hold stops within three seconds with at most three corrections, even under repeated transition callbacks.

Other checks retain eligibility, interruptions, one payment per saved identity, independent scanner/arrest accounting and receipts, duplicate/stale events, body interactions, resource/component/tree readiness, asynchronous token failures, menus, scene departure, cleanup failures and loaded-away references.

The fixture now follows Codeware 1.21.4's type restriction: ResourceHelper rejects the component's asynchronous workspotResource property. That corrected boundary reproduces the v0.7b abort. v0.7c uses ResourceDepot.LoadResource and waits without restarting the request; only a loaded token can supply a resource. Failed/refused/finished-but-unloaded tokens cannot start playback or pay an arrest. These mocked checks do not establish that native playback renders the intended pose.

These are logic/contract checks, not an emulator of native callback dispatch, game AI, serialization, animations, targeting or physics. The user confirmed visible workspot playback in v0.7c; v0.7d callback dispatch and interruption of standing transitions still need an in-game test. Separate local checks compile all 14 redscripts against source-derived API contracts, not the actual Cyberpunk script cache.
