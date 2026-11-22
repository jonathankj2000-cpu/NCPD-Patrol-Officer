# v0.19f1 — retain Voss and the meeting quest

The reported failure is the eight-second waiting-pose watchdog: Voss visibly
adopts the pose, but the Lua controller does not confirm it, cancels the native
quest and deletes Voss, the Hella and the helper. The SMS remains in Messages.

The previous condition required `GetDeviceUser(helperID)` to return Voss as
well as the actor's native workspot state to be active. The device lookup is
not a required playback receipt. Confirmation now accepts a continuous native
active state on the exact Voss actor started by this controller, from a clean
pre-request state. An explicitly different device user still prevents proof.
The half-second stable window and single playback request are retained.

The `ExtendedWorkspotInfo` fields are `isActive`, `entering` and `exiting`, as
documented in MOD_Development_Reference `81d996b584a693e8b0f0b20526a9fa38b5c83fe7`
(`orphans.swift`, `gameExtendedWorkspotInfo.lua`). The old Lua used nonexistent
`isEntering`/`isExiting` fields. The fixture now exposes the real native names
and rejects unknown properties instead of mirroring that error.

Cosmetic resource/load/playback failures now leave the actors and native SMS /
meeting quest intact and permit the existing proximity conversation. The
watchdog remains bounded at eight active seconds. It records an unconfirmed
pose and the observed native state, without stopping or restarting a pose that
may already be playing. The private helper remains owned until explicit clear.
Actor death/detach, invalid geometry, native quest interruption, scene ownership
and world recovery retain their existing handling. Explicit clear still releases
the helper before deleting the puppet, and cancellation blocks late creation.

The regression runs the actual v0.19f Lua with an active actor and no device-user
mapping: the old code visibly has a pose, times out, and deletes all three
entities. The new code retains the scene, completes either dialogue choice,
and clears it explicitly. Additional cases cover native entering/exiting,
missing information, mismatched helper user, missing/failed/pending resources
and rejected playback, with the meeting quest retained and both dialogue paths
still usable. Engine state and rendering remain mocked.

All nine archives and all 46 REDscript files are byte-identical to v0.19f.
SMS, voice, lipsync, the three timed captions, scene graph, assets and production
dispatch systems are unchanged. No new third-party code/assets are adapted.

Install the complete 123-file package and fully restart. Use Clear quest giver
test before replaying. Remain outside the three-metre talk radius for at least
15 seconds after Voss appears, then close CET, approach on foot, hear the
briefing and select either reply. Voss and the car should survive the previous
timeout. If a warning remains, Log quest giver diagnostics includes the native
pose fields and `last failure`. Actual game behavior still needs confirmation.
