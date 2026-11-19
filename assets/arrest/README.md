# Private arrest workspot

The archive now contains **two authored metadata resources**:

- [arrest_workspot.ent.json](arrest_workspot.ent.json) builds `base\ncpd_patrol\arrest_workspot.ent`, an invisible PC `gameObject` with one `workWorkspotResourceComponent` named **NCPDPatrolArrestLoop**. Its `workspotResource` points to the private file below.
- [arrest_lying_loop.workspot.json](arrest_lying_loop.workspot.json) builds `base\ncpd_patrol\arrest_lying_loop.workspot`. It has a native Root → Output → WorkspotHub graph and an infinite root sequence containing one infinite lying-idle sequence and a 30-second pause. Sequence **entry ID 2** is distinct from serialized **handle ID 6**. There are no standing/exit nodes, custom transitions or sequence time limits; natural exits are disabled. Last-frame freezing is not used.

The idle is `lie_ground_0__2h_back_handcuffs_a__01`. Animation binaries are not bundled. Before first use in a world, the controller loads the original vanilla `base\workspots\common\ground\generic__lie_ground_lean_front_handcuffs_a__aggressive__01.workspot` and copies only its `finalAnimsets`, rig and item/prop-related fields into the mod-owned tree. All original rig setups and animation-setup hashes are retained because those sets are unchanged. Source root/nodes, transitions, tags and status are not copied or modified. The private resource keeps its authored loop and zero status effect. Strong metadata handles are retained until world reset.

The controller requests the loop and jumps **once by entry ID**, without SendPlaySignal or periodic replay. This uses the actual sequence rather than assuming an idle name identifies a workAnimClip leaf. Registration/proof/result/receipt behavior is retained from the user-confirmed v0.7e version; only the native interface version and private path getter advance.

The user observed standing/idle and return to writhing with the old native bank, whose metadata includes a distinct `__to__stand__` transition. The new topology removes that route. It does not establish that every rig's idle motion is purely lying or that game AI cannot force an exit. Actual private-resource initialization and rendering need an in-game test. No suspect despawn is added to this loop trial.

## API and format references

- Native fields for [workSequence](https://github.com/WolvenKit/WolvenKit/blob/c6065b22f70cb0a53913f5440d112ab1b7dd00a4/WolvenKit.RED4/Types/Classes/workSequence.cs), [workPauseClip](https://github.com/WolvenKit/WolvenKit/blob/main/WolvenKit.RED4/Types/Classes/workPauseClip.cs), [workWorkspotTree](https://github.com/WolvenKit/WolvenKit/blob/main/WolvenKit.RED4/Types/Classes/workWorkspotTree.cs) and [WorkspotHub](https://github.com/WolvenKit/WolvenKit/blob/main/WolvenKit.RED4/Types/Classes/animAnimNode_WorkspotHub.cs).
- [An independent workspot generator](https://github.com/Edgemodders/REDnode/blob/4b25d953b47640abc93be4721637996945d445bd/packages/rednode/src/workspot.ts) documents looping idle sequences and instant entry-ID jumps. Its reported game observations are reference evidence, not validation of this mod.
- [ResourceDepot](https://github.com/psiberx/cp2077-codeware/blob/v1.21.4/src/App/Depot/ResourceDepot.hpp) and [ResourceToken](https://github.com/psiberx/cp2077-codeware/blob/v1.21.4/src/App/Depot/ResourceToken.hpp) provide asynchronous loading. ResourceHelper is not used on the component's async reference.
- The normal [PlayInDeviceCallbackEvent](https://github.com/In-Question/MOD_Development_Reference/blob/81d996b584a693e8b0f0b20526a9fa38b5c83fe7/Definitions/Game_Definitions/classes/gamePlayInDeviceCallbackEvent.lua) is addressed to the exact private helper. Existing settled-native activation fallback remains when no result arrives.

## Rebuild

Players install the compiled archive from the complete ZIP. Developers use WolvenKit Console 9.1.1 and its .NET runtime:

```sh
python tools/build_arrest_assets.py --wk-cli /path/to/WolvenKit.CLI
```

WolvenKit JSON uses numeric `0`/`1` for CBool and requires handle definitions before references. The builder compiles both files, round-trips the PC graph and loop topology, validates the helper reference/name and entry IDs, then packs/unpacks to compare exact bytes. No native `.anims` data or third-party playback entity is shipped. There is no AMM runtime dependency.


## v0.16c physical-ragdoll recovery

The loop/archive itself is unchanged. Arrest interface 6 adds a scoped native
physics lease for the selected eligible living suspect. `IsRagdollEnabled()`
covers both full ragdoll and animated-ragdoll flags. `CreateDisableRagdollEvent`
and `NPCPuppet.SetDisableRagdoll(true)` release physics; the controller waits for
both native flags to clear before placing/starting the workspot. These are the
same reset primitives used by the game's body-carrying code. NPCPuppet's disable
notification updates collision/animgraph state without changing health or defeat.

CET checks nearby navigation support, a short footprint and player reachability.
The native relocation gate independently limits displacement to 2 m, vertical
change to 0.75 m and player distance to 2.5 m, with NaN/infinite/stale-token guards.
After placement is observed, the existing activation proof and payment flow run.
No placement/reset operation can award money. Ineligible/dead/story/civilian/
police/companion actors and temporary knockdowns remain excluded by the existing
eligibility rules.

Cleanup confirms deletion of the private helper before releasing its physics
lease. `CanEnableRagdollComponent` is gated only for leased actors. Native pickup
or mounting after payment keeps its own disabled-physics ownership; no forced
ragdoll/drop is requested for a mounted body. World restore forgets old handles.

The expanded arrest scenarios cover ordinary animated-down arrests, full and
animated ragdoll recovery, nearby relocation, unsupported/unreachable/other-floor
points, stale/NaN/distant requests, stuck physics, death during recovery, body
pickup handoff and existing exactly-once payments. Native API signatures are
recorded in `tests/arrests/recovery-api.reds`. Local source/API compilation with
and without optional BEF passes. Actual game physics/poses remain manual tests.
