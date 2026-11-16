# NCPD Patrol

## v0.4a test build

**[Download v0.4a: terminals, scanner bonus and vehicle boarding](https://github.com/jonathankj2000-cpu/NCPD-Patrol-Officer/raw/refs/heads/main/releases/NCPD_Patrol_v0.4a_Terminal_Bonus_Boarding_TEST.zip)**

This version needs an in-game test on Cyberpunk 2077 2.5. Offline checks passed; live terminal interactions, native pathfinding and animations have not been verified here.

### Changes

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
4. Load a save and approach an ordinary Fast Travel terminal. Use the regular interaction selector to choose **Start Shift**.

The CET panel and existing duty hotkey remain available for troubleshooting. The car and outfit controls are retained.

### First in-game checks

1. Confirm both Fast Travel and Start Shift are shown, start a shift, and confirm the partner appears.
2. With the officer 5-10 metres away, get into a parked Hella and wait for him to approach and enter. Test getting out, changing vehicles and occupied passenger seats.
3. Complete an eligible scanner activity; check the extra EUR$1000 notification.
4. End the shift at a terminal and check the summary and partner cleanup.

### Bonus coverage and save behaviour

The first build uses Codeware's NCPD combat registry: **Assault in Progress** and **Suspected Organized Crime Activity**. **Reported Crime** follow-ups are not included. Completion comes from the game's activity state, including any evidence collection needed to finish it.

Already completed activities do not receive retrospective bonuses. Each activity ID pays once in a save timeline, including if another mod restarts it. Duty resets to OFF on loading a save; the paid activity ledger is retained. Monitoring waits for the activity registry to be ready and checks once per second during a shift.

### Validation

- LuaJIT syntax and mocked lifecycle tests: UI/hotkey/terminal duty requests, duplicate protection, dismissal, cleanup and save reset.
- Mocked vehicle tests: free-seat selection, approach without repeated follow commands, seated state, exit, vehicle switching, moving/full cars, bounded retries and native-call error handling.
- The authored reward class was exercised through a test-only syntax adapter with mocked game calls: old/off-duty/duplicate completions, late registry readiness, failed payment retry and restored-session behaviour.
- redscript 1.0.1 syntax/type checks passed against API contracts derived from the game definitions and Codeware source. This is **not** compilation against the actual Cyberpunk 2.5 script cache or an in-game test.

### Previous version / rollback

**[Download v0.3b](https://github.com/jonathankj2000-cpu/NCPD-Patrol-Officer/raw/refs/heads/main/releases/NCPD_Patrol_v0.3b_Auto_Shift_Partner.zip)**

To return from v0.4a to v0.3b, exit the game, remove `r6/scripts/NCPDPatrol` and `r6/tweaks/NCPDPatrol_Interactions.yaml`, then reinstall v0.3b. The extra `boarding.lua` may also be removed; v0.3b does not load it.

### API references

- [Terminal actions](https://github.com/In-Question/MOD_Development_Reference/blob/main/DecompiledGameScripts/cyberpunk/devices/fastTravel/dataTermController.swift)
- [Terminal entity refresh](https://github.com/In-Question/MOD_Development_Reference/blob/main/DecompiledGameScripts/cyberpunk/devices/fastTravel/dataTermDevice.swift)
- [Codeware activity API](https://github.com/psiberx/cp2077-codeware/blob/v1.21.4/scripts/World/OpenWorldSystem.reds)
- [Codeware activity completion and filtering](https://github.com/psiberx/cp2077-codeware/blob/v1.21.4/src/App/World/OpenWorldSystem.cpp)

Installation ZIP SHA-256: `eeb50a41dfc3e1295c423ae6770283f026fb3aa09a537f5af46c93a642e2a906`
