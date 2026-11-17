# NCPD Patrol

## v0.7d: arrest callback and lying hold test

**[Download the complete v0.7d test ZIP](https://github.com/jonathankj2000-cpu/NCPD-Patrol-Officer/raw/refs/heads/main/releases/NCPD_Patrol_v0.7d_Arrest_Callback_Hold_TEST.zip)**

The v0.7c in-game test confirmed the visible handcuff animation. Registration did not reach the transaction: the Codeware instance and device-user lookups were empty despite native active playback. The three-second confirmation timeout removed the helper. The observed vanilla sequence also included a transition to standing.

v0.7d uses a fresh **native callback listener** to observe the resource path and animation on the arrest target. It attempts to redirect a standing transition back to the lying clip and retains the helper after payment. **Native callback dispatch and interruption of the standing transition still need an in-game test.**

### Install and test

1. Exit the game completely. Extract the **entire ZIP** into the game directory containing **bin, r6 and archive**, replacing existing mod files. Include the new **NCPDPatrolArrestPlayback.reds**. Restart; CET announces **v0.7d**. Main/support interfaces remain **17**; the arrest interface is **3**. The archive is unchanged from v0.7b/v0.7c.
2. While **ON DUTY**, incapacitate an ordinary human enemy without killing them. Approach/look at the body and use **Arrest suspect**, normally **F**. Stay on foot within **2.5 m for two seconds**. No extra binding or CET action.
3. Expect a lying handcuff pose, then **NCPD ARREST REGISTERED | +EUR$250** after half a second of valid proof. The arrest count should increase once. Repeating input, changing shift or loading a save containing that payment cannot pay the same actor identity again.
4. Stay nearby for **15–20 seconds** to check whether standing transitions return to the lying clip. Native forced exits can still end playback; payment remains recorded if the pose ends.
5. If it fails, send lines starting **Arrest setup**, **Arrest resource token**, **Arrest bank**, **Arrest pose**, **Arrest native**, **Arrest hold** and **Arrest |**. The pose line now says **source=native callback**. **context=true** means the fresh callback matches the expected resource and has not been superseded or finished. The old **instance** field is diagnostic only.

### Confirmation and pose control

`NCPDPatrolArrestPlayback` receives native workspot setup, animation-change, missing/skipped-clip, finish and instance-removal callbacks. It is armed for one actor and request token. Registration requires the expected resource path and an allowed lying handcuff clip, active playback outside entry/exit, and a stable half-second observation. A second setup or missing/finished context invalidates the proof. The native payment entry point checks that proof before the existing target, range, eligibility, token and duplicate checks. A void request or active playback alone cannot pay.

After a real lying clip has been observed, a standing/other transition can trigger a jump back to the lying clip. Corrections are limited to one per callback revision, a half-second cooldown, at most three unacknowledged jumps and a three-second response deadline. Superseded playback is not controlled. The existing working vanilla resource is retained; no shared bank or animation tree is rewritten.

### Separate arrest payments

Each arrest pays **EUR$250** with its own receipt. `NCPDPatrolArrestSystem` owns its persistent paid-suspect ledger, transaction, count and receipt queue. It only reads common duty/wanted state. Scanner activity IDs, **EUR$1000** payouts, scanner bonus totals and scanner receipts are unchanged. Both sources enter the normal wallet. A failed transaction does not register the actor; receipt callbacks never award money.

Dead/active/civilian/police/companion/boss/robot/mounted/quest-marked actors are excluded. Quest/evidence items can mark a body as quest-related; loot those normally first. Eligible empty-inventory bodies expose the interaction. Normal body/loot choices return after registration or off duty. Menus pause treatment/confirmation; moving away, death, mounting, wanted/off-duty or loading cancels unfinished arrests.

Only private nonpersistent helpers are deleted after scene departure over 60 m, shift end, body loss/death or ended playback. Failed deletions are retried; loading forgets stale handles. Callback listeners are disarmed on cleanup and hold bounded state with a weak actor reference. Ambient suspects are never respawned, deleted, healed, resurrected or made followers. Prisoner transport is not included. No AMM dependency or paired V animation is added.

### Validation and limits

All **10 Lua modules** parse in LuaJIT. All **14 redscripts** compile with zero warnings/errors against source-derived contracts, **not an actual game cache**. The actual authored callback, controller, interaction and payment code runs with native boundaries mocked. Checks cover empty instance/device lookups with valid callbacks, wrong/missing/transition/foreign/superseded/stale proof, one separate payment, transition correction, bounded failed holds, asynchronous loading, menus/range, body choices, cleanup and world loads. Scanner/arrest classes still pay/count **1000 and 250 independently**. Native callback dispatch, rendered animation, AI, physics and native save loading are not emulated.

The included 8 KiB archive is byte-identical to v0.7c and contains only the authored PC workspot anchor. [Asset/API research](assets/arrest/README.md) and [portable logic checks](tests/arrests/README.md) are in the repository. Partner revival/boarding/backup, scanner monitoring, dispatch, radio and main/support native scripts are unchanged. Requirements remain game 2.5, matching CET, Codeware 1.21.4, RED4ext 1.31.1, TweakXL and compatible redscript.

### Rollback

Earlier complete ZIPs remain in [releases](releases). To return to **v0.7c**, exit the game, remove **r6/scripts/NCPDPatrol/NCPDPatrolArrestPlayback.reds**, then reinstall the entire [v0.7c ZIP](https://github.com/jonathankj2000-cpu/NCPD-Patrol-Officer/raw/refs/heads/main/releases/NCPD_Patrol_v0.7c_Arrest_Async_Load_TEST.zip). See the included README for removing arrests entirely when returning to v0.6e.

Archive SHA-256: `42d3f8f23e0f6c0267536a00f0df6f33e0014592c0196926584286847a5d34ee`
