# NCPD Patrol

## v0.4c test build

**[Download v0.4c: scanner monitoring fix and payment diagnostics](https://github.com/jonathankj2000-cpu/NCPD-Patrol-Officer/raw/refs/heads/main/releases/NCPD_Patrol_v0.4c_Scanner_Monitor_Fix_TEST.zip)**

For Cyberpunk 2077 2.5. Offline checks pass. Live scanner detection and the HUD receipt still need an in-game test.

### Scanner fix

The previous bonus monitor depended on the OpenWorld activity registry. When that source was not ready or returned an empty list, the monitor returned silently and the panel stayed at “waiting”, with no payments or useful log messages.

v0.4c observes **PointOfInterest mappins** through Codeware and follows each unfinished scanner marker by its journal-path hash. It checks the game's saved POI phase as well, so completing an activity can still be detected after its marker disappears from the live list. Disappearance alone does not count as completion. A failed native saved-state lookup cannot be mistaken for Completed.

- **EUR$1000 extra** for an observed **Assault in Progress** or **Suspected Organized Crime Activity** completed while on duty. Reported Crime follow-ups are excluded.
- Already completed activities receive no backpay. An unfinished marker must first be observed during the shift.
- Money is transferred through the inventory system. Only a successful transfer marks the activity as paid. Failed transfers are retried.
- Paid IDs are saved with the money; each observed activity pays once per save timeline.
- A separate **NCPD BONUS PAID: +EUR$1000** receipt is scheduled 2 seconds after payment and lasts 8 seconds. Displaying it never grants additional money.

### Diagnostics

The CET panel shows duty state, monitor state, total live mappins, eligible NCPD markers, watched IDs, unknown phases, payment failures, paid activity count and bonus total. A watched ID is an observation, not a payment.

`[NCPD Patrol] Scanner | ...` is logged on shift start, monitor state changes, every 15 seconds during the shift, and shift end. Successful payments also log **BONUS PAID** with the amount and shift total. The panel has a **Log scanner diagnostics** button.

Explicit states distinguish an unavailable MappinSystem, no live mappins, no eligible scanner markers observed yet, active monitoring, unavailable tracked phases, and a failed payment awaiting retry. Monitoring saved POI states remains possible after live markers stream out.

### Installation and in-game check

Requires Cyberpunk 2077 **2.5**, matching **CET 1.38.0+**, **Codeware 1.21.4**, **RED4ext 1.31.0+**, **TweakXL**, and compatible **redscript** (Codeware specifies 0.5.32+).

1. Exit the game completely, then extract the ZIP into the game folder containing `bin` and `r6`. Replace all NCPDPatrol Lua and redscript files.
2. Load a save and start a shift at an ordinary available Fast Travel terminal, or through the CET panel.
3. Check **SCANNER BONUS** in the panel. Confirm **ON DUTY** and that an unfinished scanner marker is observed (`watched` greater than zero).
4. Complete a new eligible scanner activity, including any evidence collection. Check the wallet, the separate receipt, and the `paid`/`bonus` counters.
5. If it fails, report the **Scanner** log line before and after completion, together with any **Duty/bonus control failed** message. Existing completed activities are not a useful payout test.

### Retained patrol features

- Ordinary Fast Travel terminals offer **Start NCPD Shift / End NCPD Shift** alongside Fast Travel, with registered captions.
- Start Shift calls the same tested NCPD officer model. End Shift dismisses the active or pending partner.
- Explicit passenger boarding in stopped vehicles, free-seat selection, bounded retries, exit commands, and cancellation when changing vehicles. No instant mounting or failsafe teleport.
- Police Hella and uniform controls, the CET panel, and the existing duty hotkey.
- Loading a save resets duty to OFF and discards transient partner references and pending receipts. The paid ledger persists.

This update addresses bonus monitoring first. The proposed basic partner incapacitation/revive feature is not included yet.

### Validation and limits

- redscript 1.0.1 syntax/type checks against independently declared game and Codeware API contracts: no warnings or errors. This is not compilation against the actual Cyberpunk 2.5 script cache.
- The authored redscript reward class is exercised through a test-only syntax adapter with mocked game natives: live completion, completion after stream-out, failed saved-state lookups returning zero, non-NCPD exclusions, duplicate IDs, completed/off-duty exclusions, missing sources, payment retries, saved ledger, receipt delay/style/duration, no second money transfer from a receipt, and session reset.
- Actual CET Lua modules are tested with the adapted native class: UI/hotkey/terminal requests, partner cleanup, vehicle approach/seats/exit/retries, source diagnostics, periodic logging, and successful-payment logging without duplicates.

Live POI availability, phase updates and HUD delivery require in-game verification. This build does not claim full scanner coverage.

### Previous versions

- [v0.4b: captions and receipt](https://github.com/jonathankj2000-cpu/NCPD-Patrol-Officer/raw/refs/heads/main/releases/NCPD_Patrol_v0.4b_Captions_Bonus_Receipt_TEST.zip)
- [v0.4a: terminals and boarding](https://github.com/jonathankj2000-cpu/NCPD-Patrol-Officer/raw/refs/heads/main/releases/NCPD_Patrol_v0.4a_Terminal_Bonus_Boarding_TEST.zip)
- [v0.3b: auto-spawn partner](https://github.com/jonathankj2000-cpu/NCPD-Patrol-Officer/raw/refs/heads/main/releases/NCPD_Patrol_v0.3b_Auto_Shift_Partner.zip)

To return to v0.4b, reinstall its complete ZIP. To return to v0.3b, exit the game, remove `r6/scripts/NCPDPatrol` and `r6/tweaks/NCPDPatrol_Interactions.yaml`, then reinstall v0.3b. The extra `boarding.lua` may be removed; v0.3b does not load it.

### API references

- [Codeware MappinSystem extension](https://github.com/psiberx/cp2077-codeware/blob/v1.21.4/scripts/World/MappinSystem.reds)
- [Codeware native mappin enumeration](https://github.com/psiberx/cp2077-codeware/blob/v1.21.4/src/App/World/MappinSystemEx.hpp)
- [Game journal notification: saved POI phase](https://github.com/In-Question/MOD_Development_Reference/blob/main/DecompiledGameScripts/cyberpunk/UI/fullscreen/notification/journalNotification.swift)
- [PointOfInterestMappin definitions](https://github.com/In-Question/MOD_Development_Reference/blob/main/Definitions/Game_Definitions/classes/gamemappinsPointOfInterestMappin.lua)

Installation ZIP SHA-256: `813dd3cd8964ba9e4afba1a2e1ab042a4e255454003a85120ab09804b7b6bc41`
