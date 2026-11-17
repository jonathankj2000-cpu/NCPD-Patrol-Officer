# NCPD Patrol

## v0.7e: register arrests through native activation

**[Download the complete v0.7e test ZIP](https://github.com/jonathankj2000-cpu/NCPD-Patrol-Officer/raw/refs/heads/main/releases/NCPD_Patrol_v0.7e_Arrest_Native_Activation_TEST.zip)**

The v0.7d test showed active playback but no debug callback path or clip data. Registration now credits **completed securing plus stable native activation**. It no longer requires a readable animation name. **This changes the confirmation policy: activation does not prove which clip is rendered.** The requested vanilla handcuff animation was visibly confirmed in the earlier game test.

### Install and test

1. Exit the game completely. Extract the **entire ZIP** into the game directory containing **bin, r6 and archive**, replacing the mod files. Include the new **NCPDPatrolArrestEvents.reds** and updated **NCPDPatrolArrestPlayback.reds**. Restart; CET announces **v0.7e**. Main/support interfaces remain **17**, arrests use **4**. The archive is unchanged.
2. While **ON DUTY**, incapacitate an ordinary human enemy without killing them. Approach/look at the body and use **Arrest suspect**, normally **F**. Remain on foot within **2.5 m until the receipt**. Securing takes two seconds, followed by activation confirmation. No extra binding or CET action.
3. Expect **NCPD ARREST REGISTERED | +EUR$250** and one increase in the arrest count. Repeating input, changing shift or loading a save containing that payment cannot pay the same saved identity again.
4. Stay nearby for **15–20 seconds** to test the pose keeper. After registration, it re-selects the lying handcuff clip **at most once per second**, without additional play signals. Native forced exits can end the pose. Physical holding still needs an in-game test.
5. If it fails, send **Arrest activation**, **Arrest request**, **Arrest hold** and **Arrest |** lines. Activation reports the source, result status, native flags and stable/required seconds. **observed clip=unavailable** is intentional: metadata names describe requested clips.

### Native confirmation

The resource must load and contain a lying handcuff candidate. A native proof is armed for the exact actor, helper and request token immediately before playback. It refuses a pre-existing workspot, then requires a transition into **IsActorInWorkspot + active playback**, outside entry/exit.

The normal **PlayInDeviceCallbackEvent** is addressed to the private helper. A positive result from that exact recipient requires **0.75 s** of continuous native activation. If no result arrives, **1.5 s** continuous activation supplies the fallback. A negative result while pending cancels the arrest. Other helper IDs, duplicate results and stale requests are ignored. A positive result without settled activation cannot pay.

Both routes recheck duty/wanted state, life/eligibility, range, token and duplicate identity before the transaction. A void request alone cannot pay. Menus and oversized frame deltas cannot fast-forward registration. Functional-test callbacks and instance/device-user lookups are no longer required. There is no per-clip rendering verification in this version.

### Pose keeper and cleanup

The initial working workspot request is retained. Re-selection starts only after registration, with at least one second between jumps. No shared workspot resource/tree, NPC health, defeated state or AI role is changed. Commands stop on lost/ending native activation, death, mounting, removed downed state, helper loss, duty end or scene departure over 60 m. Only private managed helpers are deleted; declined deletions are retried. No unverified StopInDevice is sent to ambient actors. Loading forgets stale handles. No AMM dependency, paired V animation or prisoner transport is added.

### Separate payments

Arrests retain their own persistent paid-identity ledger, **EUR$250** transaction, count and receipt queue. Scanner activity IDs, **EUR$1000** payouts, scanner bonus totals and scanner receipts are unchanged. Receipts never award money. Failed transactions do not mark a suspect paid; earned payment remains if the pose ends or normal engine cleanup removes the body.

Dead/active/civilian/police/companion/boss/robot/mounted/quest-marked targets are excluded. Quest/evidence items can mark a body as quest-related; loot those normally first. Eligible empty-inventory bodies expose the arrest interaction. Normal body/loot choices return after registration or off duty. Moving away, death, mounting, wanted, duty end or loading cancels unfinished registration.

### Validation and limits

All **10 Lua modules** parse in LuaJIT. All **15 redscripts** compile with zero warnings/errors against source-derived API contracts, **not an actual game cache**. Tests run the actual native proof, controller, result receiver, interactions and payment code against mocked native boundaries. They cover absent debug data, stable native fallback, positive/negative/foreign/stale helper results, no-entry/transition states, timers/menus, eligibility/range/death/wanted, asynchronous resources, one-second command limits, cleanup/world loads and independent **1000/250** scanner/arrest payments.

These checks do not emulate native event dispatch, rendered animation, AI, physics or native save loading. The receipt and physical hold still need an in-game test. [Asset/API research](assets/arrest/README.md) and [portable checks](tests/arrests/README.md) are available. The archive, partner revival/boarding/backup, scanner monitoring, dispatch, radio and main/support scripts are unchanged. Requirements remain game 2.5, matching CET, Codeware 1.21.4, RED4ext 1.31.1, TweakXL and compatible redscript.

### Rollback

Earlier full ZIPs remain in [releases](releases). To return to **v0.7d**, exit the game, remove **r6/scripts/NCPDPatrol/NCPDPatrolArrestEvents.reds**, then reinstall its complete ZIP. Returning to **v0.7c** also requires removing **NCPDPatrolArrestPlayback.reds**. See the included README for removing arrests entirely when returning to v0.6e.

Archive SHA-256: `5ecca81515cc13b9bab30a94c329919f848bc1b055668ce3eb7112d52e0a1868`
