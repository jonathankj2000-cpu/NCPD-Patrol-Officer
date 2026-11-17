# NCPD Patrol

## v0.9a: dispatch journal and response deadline prototype

[Download the full v0.9a test ZIP](https://github.com/jonathankj2000-cpu/NCPD-Patrol-Officer/raw/refs/heads/main/releases/NCPD_Patrol_v0.9a_Dispatch_Journal_Deadline_TEST.zip)

**New dependency: [ArchiveXL](https://github.com/psiberx/cp2077-archive-xl/releases/tag/v1.28.8)** for Cyberpunk 2077 2.5. Version 1.28.8 is recommended; it is not bundled. Existing CET, RED4ext, Codeware, redscript and TweakXL requirements remain.

Exit the game, extract the **whole ZIP** into the game directory and replace files. Restart; CET announces **v0.9a**. Both the new dispatch archive and its .archive.xl must be installed.

This prototype adds one reusable native journal entry, **NCPD Dispatch**, with one objective: **Resolve the marked NCPD incident**.

- Dispatch assignment starts a **3-minute arrival deadline**, displayed in the existing dispatch HUD.
- Within **60 m**, On scene stops the deadline; the following fight has no deadline.
- Resolving the assigned scanner after attendance records **Succeeded**.
- Timeout records **Failed**, closes our assignment and removes our marker. The vanilla scanner remains available.
- Cancellation/shift end deactivates our entry. Wanted termination records failure.
- Loading ends the active duty/dispatch session as before; a saved active journal entry is deactivated after load.
- The previous tracked story objective is restored only when our dispatch was still tracked.
- Busy keeps an active assignment/deadline while blocking new automatic calls.
- **Scanner/arrest payments are unchanged.** Journal completion does not award another payment.
- The existing script marker is retained. Native quest GPS and unlimited per-call journal history are separate work.

### Test

1. Request a call and check the normal journal and response countdown. Arrive, finish the scanner and check Completed.
2. Request another call over 60 m away. Use CET **Test timeout: 15 s left (on route)**, remain away outside menus and check Failed. The scanner should remain playable.
3. Request another call after success/failure to test reuse. Test cancellation and a save/load during an active assignment.
4. Use **Log dispatch journal diagnostics** if the entry is absent, refuses reset or has wrong states. Include readiness, stage, quest and objective fields.

The native entry's rendering, reuse and save behavior are the purpose of this game test. A rejected journal operation is reported rather than silently replaced by fake completion.

### Implementation and validation

The dispatcher drives the public JournalManager entry-state API on its own pre-authored paths. It does not use CreateScriptedQuestFromTemplate or the related stubbed cloning APIs. ArchiveXL merges a small journal and localization resource; no original quest or scanner state is rewritten.

The resources are compiled, round-tripped and extracted byte-for-byte by [the asset builder](tools/build_dispatch_assets.py). [Portable checks](tests/dispatch_journal/README.md) execute authored controller logic and actual CET dispatch code with native boundaries mocked. Existing arrest/trunk checks are retained. A local source-contract compile completed before the workspace executor disconnected; hosted checks finish resource building, logic checks and ZIP validation. None replaces a real game-cache/UI test.

Main/support interfaces stay **17**, arrest **5**, trunk **2**; the new journal controller is **1**. Partner/backup, scanner payouts, revive, native trunk controls and the confirmed arrest loop/archive are retained.

[Full instructions and rollback](README.txt). [Previous v0.8c ZIP](https://github.com/jonathankj2000-cpu/NCPD-Patrol-Officer/raw/refs/heads/main/releases/NCPD_Patrol_v0.8c_Native_Trunk_Hold_TEST.zip). The confirmed [v0.7f prototype](https://github.com/jonathankj2000-cpu/NCPD-Patrol-Officer/raw/refs/heads/main/releases/NCPD_Patrol_v0.7f_Private_Lying_Loop_TEST.zip) remains available.
