# Arrest workspot anchor

This is an authored, invisible `gameObject`, cooked with `PLATFORM_PC`, with one `workWorkspotResourceComponent` named `NCPDPatrolArrestPC`. It references the vanilla resource:

`base\workspots\common\ground\generic__lie_ground_lean_front_handcuffs_a__aggressive__01.workspot`

The template is spawned privately at the suspect's position through Codeware, with state/spawn persistence disabled. No NPC, mesh or animation bank is bundled. There is no AMM entity, script or dependency.

The path is listed in [the game resource catalogue](https://github.com/DoctorPresto/Cyberpunk-File-Types/blob/d0ed69d6f33b31a76dbbf1fd853d13e93c085282/workspot.txt). The expected `lie_ground_0__2h_back_handcuffs_a__01` clip and its shuffle variants are listed for average male/female rigs in [AMM's reference catalogue](https://github.com/MaximiliumM/appearancemenumod/blob/main/Release/bin/x64/plugins/cyber_engine_tweaks/mods/AppearanceMenuMod/db.sqlite3); that catalogue is research evidence and is not shipped.

`arrest.lua` checks template/resource existence, the component name and a readable lying-clip candidate before transferring the actor. It calls `PlayInDeviceSimple`, then explicitly sends `SendJumpToAnimEnt` and one `SendPlaySignal`. There are no repeat selections during initial activation confirmation. Once registered, the lying clip is re-selected no more than once per second without another play signal. Unconfirmed setup is released after eight seconds, within the native pending timeout.

`workspotResource` is a [`CResourceAsyncReference`](https://github.com/WolvenKit/WolvenKit/blob/main/WolvenKit.RED4/Types/Classes/workWorkspotResourceComponent.cs). Codeware 1.21.4's [`ResourceHelper`](https://github.com/psiberx/cp2077-codeware/blob/v1.21.4/src/App/Depot/ResourceHelper.hpp) methods reject properties whose RTTI type is not `ResourceReference`; using them on this async property caused the v0.7b abort. v0.7c instead calls [`ResourceDepot.LoadResource`](https://github.com/psiberx/cp2077-codeware/blob/v1.21.4/src/App/Depot/ResourceDepot.hpp) with the native workspot ResRef, retains the resulting [`ResourceToken`](https://github.com/psiberx/cp2077-codeware/blob/v1.21.4/src/App/Depot/ResourceToken.hpp), polls its loaded/finished/failed state, and inspects `GetResource()` only after loading. It does not rewrite the component's reference or remove resources from the cache. The archive is unchanged from v0.7b.

The v0.7c user test confirmed visible handcuff playback, but instance/device-user lookups were empty. The v0.7d user test also returned no functional-test callback path or clip data. v0.7e removes those requirements and changes registration to completed securing plus stable native activation. It does not verify a rendered clip.

The normal `PlayInDeviceCallbackEvent` and its `wasPlayInDeviceSuccessful` field are declared in the [native event definition](https://github.com/In-Question/MOD_Development_Reference/blob/81d996b584a693e8b0f0b20526a9fa38b5c83fe7/Definitions/Game_Definitions/classes/gamePlayInDeviceCallbackEvent.lua) and used in the shipped [door](https://github.com/In-Question/MOD_Development_Reference/blob/81d996b584a693e8b0f0b20526a9fa38b5c83fe7/DecompiledGameScripts/cyberpunk/devices/door/door.swift) and [device](https://github.com/In-Question/MOD_Development_Reference/blob/81d996b584a693e8b0f0b20526a9fa38b5c83fe7/DecompiledGameScripts/cyberpunk/devices/core/deviceBase.swift) scripts. The [`PlayInDeviceSimple` signature](https://github.com/In-Question/MOD_Development_Reference/blob/81d996b584a693e8b0f0b20526a9fa38b5c83fe7/Definitions/Game_Definitions/classes/gameWorkspotGameSystem.lua) accepts a callback entity. v0.7e passes its own private helper rather than nil; an added GameObject receiver forwards only exact current-helper results to the arrest system. Existing child device handlers retain their own behavior.

A native proof is armed immediately before the request and refuses an actor already in a workspot. A positive result plus 0.75 seconds settled native activation can register; absent a result, 1.5 seconds settled activation supplies the fallback. A pending negative result vetoes the attempt. Both paths require the same registered proof, actor/token and live attached helper. Wrong/stale/duplicate results cannot change a pending request. This is activation evidence, not clip-name or helper-ownership telemetry.

After registration, the controller re-selects the metadata-selected lying clip at most once per second. It does not repeat play signals or infer actual transitions. No shared native bank/tree is edited. Native activation loss/exit, life-state changes or cleanup stop further commands. Only the private helper is deleted; the controller sends no unverified StopInDevice command to an ambient actor. The actual keeper still needs an in-game test.

Build with WolvenKit Console 9.1.1 and its .NET runtime:

```sh
python tools/build_arrest_assets.py --wk-cli /path/to/WolvenKit.CLI
```

The tool compiles the JSON, checks the PC platform, component/reference after round-tripping and unpacks the archive to compare entity bytes. The archive is unchanged from v0.7b/v0.7c; activation confirmation and timed re-selection are the new runtime work. Average human rigs on flat ground are the first test target.
