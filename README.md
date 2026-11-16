# NCPD Patrol

## v0.4b test build

**[Download v0.4b: corrected shift labels and visible bonus receipt](https://github.com/jonathankj2000-cpu/NCPD-Patrol-Officer/raw/refs/heads/main/releases/NCPD_Patrol_v0.4b_Captions_Bonus_Receipt_TEST.zip)**

This version needs an in-game test on Cyberpunk 2077 2.5. Offline checks passed; live terminal interactions, native pathfinding and animations have not been verified here.

### New in v0.4b

- Terminal choices have native caption keys registered through Codeware: **Start NCPD Shift / End NCPD Shift**, replacing the inherited Select Destination label. The native input key is retained.
- After a successful bonus transfer, a separate **NCPD BONUS PAID: +EUR$1000** money-style receipt is displayed after 2 seconds, for 8 seconds. This message reports the patrol bonus alone.
- Receipts never grant money, and a receipt from a previous loaded session is discarded.
- **Last bonus paid** is included in the CET scanner diagnostics.
- The EUR$1000 reward, saved paid-activity IDs, eligibility checks and vehicle boarding implementation are retained.

### Patrol features

- Ordinary available Fast Travel terminals offer **Fast Travel** plus **Start Shift / End Shift** using the game's interaction list.
- Start Shift automatically calls the tested NCPD officer model.
- Entering a stopped vehicle sends an explicit, animated passenger boarding command. On-foot follow commands pause while the officer approaches the door and while seated.
- The officer uses a free passenger seat, waits for a moving car to stop, and receives an exit command when you get out. Pending boarding is cancelled when you get out or switch cars. Retries are bounded; instant mounting and failsafe teleport are disabled.
- Eligible NCPD combat activities completed on duty pay **EUR$1000 extra**. Paid activity IDs are stored with the save, preventing repeat payments for the same activity.
- End Shift dismisses the partner and shows the number of paid activities and total patrol bonus.

### Requirements

Cyberpunk 2077 **2.5**, matching **CET 1.38.0+**, **Codeware 1.21.4**, **RED4ext 1.31.0+**, **TweakXL**, and **redscript compatible with patch 2.5** (Codeware specifies 0.5.32+).

### Installation

1. Exit the game completely.
2. Download the installation ZIP above.
3. Extract it into the game folder containing `bin` and `r6`, replacing the old NCPDPatrol Lua files and adding the new scripts and interaction tweak.
4. Load a save and approach an ordinary Fast Travel terminal. Use the regular interaction selector to choose **Start NCPD Shift**.

The CET panel and existing duty hotkey remain available for troubleshooting. The car and outfit controls are retained.

### First in-game checks

1. Confirm both Fast Travel and Start Shift are shown, start a shift, and confirm the partner appears.
2. With the officer 5-10 metres away, get into a parked Hella and wait for him to approach and enter. Test getting out, changing vehicles and occupied passenger seats.
3. Complete an eligible scanner activity; wait for the separate NCPD BONUS PAID receipt. It shows only the patrol bonus, not the combined vanilla reward.
4. End the shift at a terminal and check the summary and partner cleanup.

### Bonus coverage and save behaviour

The first build uses Codeware's NCPD combat registry: **Assault in Progress** and **Suspected Organized Crime Activity**. **Reported Crime** follow-ups are not included. Completion comes from the game's activity state, including any evidence collection needed to finish it.

Already completed activities do not receive retrospective bonuses. Each activity ID pays once in a save timeline, including if another mod restarts it. Duty resets to OFF on loading a save; the paid activity ledger is retained. Monitoring waits for the activity registry to be ready and checks once per second during a shift.

### Validation

The v0.4b checks also cover receipt delay, money style, duration, failed-transfer suppression, no second money transfer from a receipt, session reset, and the caption-key/provider mapping. The new native captions and live HUD appearance still need an in-game check.


- LuaJIT syntax and mocked lifecycle tests: UI/hotkey/terminal duty requests, duplicate protection, dismissal, cleanup and save reset.
- Mocked vehicle tests: free-seat selection, approach without repeated follow commands, seated state, exit, vehicle switching, moving/full cars, bounded retries and native-call error handling.
- The authored reward class was exercised through a test-only syntax adapter with mocked game calls: old/off-duty/duplicate completions, late registry readiness, failed payment retry and restored-session behaviour.
- redscript 1.0.1 syntax/type checks passed against API contracts derived from the game definitions and Codeware source. This is **not** compilation against the actual Cyberpunk 2.5 script cache or an in-game test.

### Previous versions / rollback

**[Download v0.4a](https://github.com/jonathankj2000-cpu/NCPD-Patrol-Officer/raw/refs/heads/main/releases/NCPD_Patrol_v0.4a_Terminal_Bonus_Boarding_TEST.zip)**

To return to v0.4a, remove `NCPDPatrolLocalization.reds` and `NCPDPatrolBonusReceipt.reds` from `r6/scripts/NCPDPatrol`, then reinstall the complete v0.4a ZIP.


**[Download v0.3b](https://github.com/jonathankj2000-cpu/NCPD-Patrol-Officer/raw/refs/heads/main/releases/NCPD_Patrol_v0.3b_Auto_Shift_Partner.zip)**

To return from v0.4b to v0.3b, exit the game, remove `r6/scripts/NCPDPatrol` and `r6/tweaks/NCPDPatrol_Interactions.yaml`, then reinstall v0.3b. The extra `boarding.lua` may also be removed; v0.3b does not load it.

### API references

- [Codeware native localization providers](https://github.com/psiberx/cp2077-codeware/blob/v1.21.4/wiki/Home.md#localization)


- [Terminal actions](https://github.com/In-Question/MOD_Development_Reference/blob/main/DecompiledGameScripts/cyberpunk/devices/fastTravel/dataTermController.swift)
- [Terminal entity refresh](https://github.com/In-Question/MOD_Development_Reference/blob/main/DecompiledGameScripts/cyberpunk/devices/fastTravel/dataTermDevice.swift)
- [Codeware activity API](https://github.com/psiberx/cp2077-codeware/blob/v1.21.4/scripts/World/OpenWorldSystem.reds)
- [Codeware activity completion and filtering](https://github.com/psiberx/cp2077-codeware/blob/v1.21.4/src/App/World/OpenWorldSystem.cpp)

Installation ZIP SHA-256: `feebbc2f2ac251c5e1c3a2e473f9e3e16b6cf31f821851ab2546bf103b6ba6ec`
