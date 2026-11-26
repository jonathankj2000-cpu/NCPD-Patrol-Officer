# v0.19a1 — quest giver player scene guard

The supplied error occurs in the Lua player gate before the quest request.
The v0.19a code rejected any `IsEntityInScene(playerID)` result. That broad
membership flag is not proof of an active conversation or restricted gameplay.
The same predicate also blocked automatic greeting after reaching the NPC.

Both player gates now use `SceneSystemInterface.IsEntityInDialogue` and
`PlayerPuppet.GetSceneTier`. Default/Tier 1 gameplay is allowed; active dialogue
and tiers above 1 block entry. The actual per-entity `IsEntityInScene` check
remains in actor cleanup, where it protects scene-owned actors from deletion.
No change is made to the scene/quest assets or to the native bridge.

## Source evidence

Pinned game source/API reference: `81d996b584a693e8b0f0b20526a9fa38b5c83fe7`.

- player/player.swift: GetSceneTier reads PlayerStateMachine.HighLevel.
- player/psm/highLevelTransitions.swift: Tier1_FullGameplay returns to exploration.
- UI/fullscreen/settings/settingsMain.swift: normal gameplay checks GetSceneTier == 1.
- player/psm/scenesFastForward.swift: actual dialogue detection uses IsEntityInDialogue.
- orphans.swift: SceneSystemInterface declares IsEntityInScene and IsEntityInDialogue separately.

The reported message proves which gate rejected the request; no live scene-tier
or dialogue value was supplied, so the user's exact runtime state is not claimed.

## Verification

A negative control loads the actual v0.19a Lua module and reproduces the same
rejection with broad player membership true, dialogue false and tier 1. The
corrected module passes activation, greeting, both native choices and journal
completion under that background-membership condition. Genuine dialogue and
tiers 2–5 still block activation; dialogue/tier changes on approach delay the
greeting until gameplay is available. Existing cancellation and asynchronous
scene-release/cleanup tests remain in place. Engine boundaries are mocked.

The release verifies all 45 native scripts and nine archives unchanged and
runs all 33 portable suites. Install the full package and restart, activate
the OFF DUTY test, close CET and approach the investigator. Game confirmation
of the dialogue itself remains required.
