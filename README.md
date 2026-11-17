# NCPD Patrol

## v0.9b: varied dispatch briefings and €$500 completion supplements

[Download the complete v0.9b test ZIP](https://github.com/jonathankj2000-cpu/NCPD-Patrol-Officer/raw/refs/heads/main/releases/NCPD_Patrol_v0.9b_Dispatch_Briefings_Rewards_TEST.zip)

Dispatches now choose from **six journal titles, objectives and briefings**, without repeating the previous choice. Text stays broad enough for existing scanner incidents: respond, assess the scene, deal with threats and secure evidence. It does not invent specific gangs, hostages, injured officers or suspect counts.

Finishing an **active assigned dispatch after On scene** earns a separate **€$500 supplement**. A successful transfer queues **DISPATCH BONUS PAID: +€$500** and prints a CET receipt. Scanner and arrest payments retain their own ledgers and receipts.

- A persistent dispatch ledger pays each incident once, including across shifts and save/load.
- Failed native transactions stay queued for retry; only successful transfers are marked paid or generate a paid receipt.
- Timeout, cancellation, replacement and an incident resolved before attendance earn no dispatch supplement.
- The native controller checks that the assigned scanner is completed before accepting success.

The v0.9a rules continue: **3-minute arrival deadline**, paused in menus; **On scene within 60 m** stops the deadline; the subsequent fight has no deadline. Failure closes the assignment while leaving the original scanner available. Only one dispatch is active. Six reusable journal entries provide limited history, rather than an unlimited per-call log. Loading closes saved active calls, including the original v0.9a path.

### Install and test

Exit the game, extract the **entire ZIP** into the game directory and replace files. Restart; CET announces **v0.9b**. Both the dispatch archive and `.archive.xl` are required.

Dependencies are unchanged from v0.9a: Cyberpunk 2077 2.5 and compatible CET, RED4ext, Codeware, redscript, TweakXL and **[ArchiveXL](https://github.com/psiberx/cp2077-archive-xl/releases/tag/v1.28.8)** (1.28.8 recommended). Dependencies are not bundled.

1. Request a few dispatches and check journal variety. Consecutive titles should differ.
2. Arrive and complete the assigned scanner. Check Completed and the **separate €$500 receipt**; other queued notices may appear first.
3. Use CET **Test timeout: 15 s left (on route)** before arrival. Check Failed and no dispatch supplement.
4. Test another call after success/failure, cancellation and a save/load during a call.
5. Use **Log dispatch journal diagnostics** if needed. It includes readiness, selected briefing, native journal states and paid/pending dispatch supplements.

No retroactive dispatch reward is paid for v0.9a completions. Existing scanner/arrest bonus rules remain independent. The existing marker/GPS behavior remains; the map may need opening and closing for a route line.

### Validation

[Portable checks](tests/dispatch_journal/README.md) run authored controller logic and actual CET dispatch/bridge code with native APIs mocked. Cases cover all six briefings, repeated outcomes, tracking/load/reuse, deadline boundaries, matching completion, exactly-once €$500 payments and persistent transaction retries. Existing arrest/trunk regressions also run. All 19 redscript files pass source-derived API contract checks; these are not the game's script cache.

The [asset builder](tools/build_dispatch_assets.py) compiles and round-trips the journal/localization with WolvenKit 9.1.1 and verifies exact archive extraction. The [release builder](tools/build_journal_release.py) checks all 12 Lua modules, preserved gameplay files and the 40-file install ZIP. Only a queued money-receipt entry point is added to the core scanner system; its existing payment code is identical. Native journal interface is now **2**; main/support **17**, arrest **5** and trunk **2** stay compatible.

The user reported v0.9a working. The new text selection, €$500 transfers and receipt display still need in-game testing of this update.

[Full instructions](README.txt) · [Previous v0.9a ZIP](https://github.com/jonathankj2000-cpu/NCPD-Patrol-Officer/raw/refs/heads/main/releases/NCPD_Patrol_v0.9a_Dispatch_Journal_Deadline_TEST.zip) · [Earlier packages](releases)
