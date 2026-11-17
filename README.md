# NCPD Patrol

## v0.7f: private infinite lying workspot

**[Download the complete v0.7f test ZIP](https://github.com/jonathankj2000-cpu/NCPD-Patrol-Officer/raw/refs/heads/main/releases/NCPD_Patrol_v0.7f_Private_Lying_Loop_TEST.zip)**

The user confirmed arrest registration and payment work in v0.7e. The remaining issue is the pose: the vanilla workspot proceeds through standing/idle, then returns to the defeated animation. v0.7f uses a private resource containing only an **infinite lying idle**, with no standing/exit nodes. This tests the preferred loop approach; no suspect despawn is added.

### Install and test

1. Exit the game completely. Extract the **entire ZIP** into the game directory containing **bin, r6 and archive**, replacing existing files. **Replace NCPDPatrol_Arrest.archive too**: it now contains the helper and the new private loop. Restart; CET announces **v0.7f**. Main/support interfaces remain **17**; arrests use **5**.
2. While **ON DUTY**, incapacitate an ordinary human enemy without killing them, approach/look at the body and use **Arrest suspect**, normally **F**. Stay on foot within **2.5 m until the separate +EUR$250 receipt**. No extra binding or CET action.
3. Remain nearby for **30–60 seconds**. Check whether the suspect stays lying with hands behind the back. Try another average human rig, including female if available. The same paid identity cannot pay again.
4. If the pose ends or payment fails, send **Arrest loop**, **Arrest request**, **Arrest activation** and **Arrest |** lines. Setup should say **entry=2 | infinite=true | natural exits=false**. An outdated helper component is rejected before playback.

### Resource loop

The authored `arrest_lying_loop.workspot` has a native Root → Output → WorkspotHub graph. Its root sequence and the inner lying sequence loop infinitely. A 30-second pause holds `lie_ground_0__2h_back_handcuffs_a__01` as the idle before repeating. There are no standing clips, exit nodes or custom transitions; natural exits and sequence time limits are disabled. The controller makes **one jump to entry ID 2**, which is distinct from serialized handle ID 6. It sends no play/advance signal and performs no periodic restart.

Before use, the controller loads the functioning vanilla handcuff resource and copies its animation/rig and item/prop bindings into the **mod-owned resource only**, once per world. It retains the existing animation-setup hashes and all rig setups because those animation sets are unchanged. It does not copy the source's root, standing transitions, tags or status effect. No original game tree or cache entry is rewritten and no animation binary is bundled. See [asset source and API notes](assets/arrest/README.md).

The compiled tree proves the intended topology, not the motion rendered by a particular rig or whether game AI can force an exit. **The physical loop still needs an in-game test.**

### Confirmed arrest behavior retained

The v0.7e registration, eligibility, activation proof, production-result receiver, persistent paid identities, **EUR$250** transaction and receipts are retained. The native system only adds the private loop path and advances its interface version. Securing takes two seconds; registration then requires **0.75 s** settled activation with a positive result from the exact helper, or **1.5 s** when no result arrives. A pending negative result vetoes registration. Void requests and wrong/stale/duplicate results cannot pay. This verifies native activation, not a rendered clip. Menu/hitch, life, duty/wanted, range and duplicate-identity guards remain.

Arrests have their own ledger, count, reward and receipt queue. Scanner activity IDs, **EUR$1000** payouts, scanner bonus totals and scanner receipts are unchanged. Failed transactions do not mark the actor paid; receipts never award money. Paid identities survive a pose ending, shifts and saves containing that payment.

Dead/active/civilian/police/companion/boss/robot/mounted/quest-marked bodies are excluded. Quest/evidence items can mark a body as quest-related; loot them normally first. Empty-inventory eligible bodies expose the action. Normal body/loot choices return after registration or off duty. Actor-state/playback loss, duty end or scene departure over 60 m releases private helpers, with deletion retries. Loading forgets old handles and clears the binding cache. No ambient NPC is deleted, healed, resurrected or assigned an AI role; no unverified StopInDevice is sent to it. No AMM dependency, paired V animation or prisoner transport is added.

### Validation and limits

WolvenKit 9.1.1 compiles and round-trips both authored resources. Checks verify the PC graph, entry IDs, infinite sequences, absence of natural exits/transitions and exact packed/extracted bytes. All **10 Lua modules** parse. All **15 redscripts** compile with zero warnings/errors against source-derived API contracts, **not an actual game cache**.

The [portable checks](tests/arrests/README.md) consume the actual loop JSON and execute authored activation/controller/result/interaction/payment code with native APIs mocked. They cover one entry-ID jump without replay signals, source/private resource readiness, rig/setup copying without editing native source data, invalid/missing loop rejection, unchanged registration, independent **1000/250** scanner/arrest payments, menus/range/life/wanted and cleanup/world loads. Real metadata initialization, native event dispatch, rendering, AI, physics and native save loading are not emulated.

Partner revive/boarding/backup, scanner monitoring, dispatch, radio and main/support scripts are unchanged. Requirements remain game 2.5, matching CET, Codeware 1.21.4, RED4ext 1.31.1, TweakXL and compatible redscript.

### Rollback

Exit the game and reinstall the complete [v0.7e ZIP](https://github.com/jonathankj2000-cpu/NCPD-Patrol-Officer/raw/refs/heads/main/releases/NCPD_Patrol_v0.7e_Arrest_Native_Activation_TEST.zip), **including its original archive**. v0.7f adds no new install-file paths. Earlier complete ZIPs remain in [releases](releases).

Archive SHA-256: `5a6f34aaa942f0259824528764e0e61c102ae70e4efa1750509ba8249553de28`
