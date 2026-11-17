# Arrest workspot anchor

This is an authored, invisible `gameObject`, cooked with `PLATFORM_PC`, with one `workWorkspotResourceComponent` named `NCPDPatrolArrestPC`. It references the vanilla resource:

`base\workspots\common\ground\generic__lie_ground_lean_front_handcuffs_a__aggressive__01.workspot`

The template is spawned privately at the suspect's position through Codeware, with state/spawn persistence disabled. No NPC, mesh or animation bank is bundled. There is no AMM entity, script or dependency.

The path is listed in [the game resource catalogue](https://github.com/DoctorPresto/Cyberpunk-File-Types/blob/d0ed69d6f33b31a76dbbf1fd853d13e93c085282/workspot.txt). The expected `lie_ground_0__2h_back_handcuffs_a__01` clip and its shuffle variants are listed for average male/female rigs in [AMM's reference catalogue](https://github.com/MaximiliumM/appearancemenumod/blob/main/Release/bin/x64/plugins/cyber_engine_tweaks/mods/AppearanceMenuMod/db.sqlite3); that catalogue is research evidence and is not shipped.

`arrest.lua` checks template/resource existence, the new component name, asynchronous reference readiness and a readable workspot tree before transferring the actor. It selects a lying handcuff clip from the loaded tree, calls `PlayInDeviceSimple`, then explicitly sends `SendJumpToAnimEnt` and `SendPlaySignal`. Clip/play is retried at most once; unconfirmed playback is released after three seconds.

Payment still requires a stable matching non-transition clip, active workspot playback and the private helper's actor association. Codeware 1.21.4 exposes the current clip through [GetWorkspotInstance](https://github.com/psiberx/cp2077-codeware/blob/v1.21.4/src/App/World/WorkspotSystemEx.hpp). A void playback call alone never registers an arrest. These startup changes address concrete omissions in v0.7a; an in-game test must establish whether they resolve its reported T-pose.

Build with WolvenKit Console 9.1.1 and its .NET runtime:

```sh
python tools/build_arrest_assets.py --wk-cli /path/to/WolvenKit.CLI
```

The tool compiles the JSON, checks the component/reference after round-tripping and unpacks the archive to compare entity bytes. Runtime entry into this workspot from an incapacitated NPC still requires in-game validation. Average human rigs on flat ground are the first test target. No particular visible handcuff prop is guaranteed by the template.
