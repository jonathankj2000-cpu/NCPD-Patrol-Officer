# Mixed dispatch and generated incident rewards

Run `python tests/incidents/check_incidents.py` with Lupa 2.6. Production
redscript is executed through the existing test-only syntax adapter; the actual
dispatcher, VIP, cyberpsycho, journal and convoy Lua modules run in LuaJIT.

The suite executes all 100 possible first draws, producing 50 scanner, 30 VIP
and 20 cyberpsycho assignments through their real request/native journal paths.
It exercises unavailable locations, expanded VIP fallback, exhausted scanners,
missing generated resources, bounded all-type failure, menu/combat/Busy pauses,
normal replacement and refused actor cleanup. Fallback retains original weights
among remaining types; observed frequencies can differ when some are unavailable.

Native cases cover actual living VIP exit and stable cyberpsycho outcomes,
EUR$2000 / EUR$3000 / EUR$3500 grants, exactly one completion record, separate
scanner/arrest histories, stale/cancelled/wrong-type IDs, death before non-lethal
confirmation, rejected journal results, and serial uniqueness across restoration.
Failed/absent transactions leave a persistent earned record to retry after load
or ending duty. Receipt delay/menu pause never grants money. The live dispatch
update services payouts and reports generated completions/failures once.

Post-VIP regressions force the full 120-second standby and drive actual pickup,
boarding, delivery, retained ambush bodies and the next automatic scanner call.
Standby starts at the native terminal result and runs during scene retention.
The same cases check Busy/menu/combat pauses, visible scheduler gates, retained
scene countdowns and deferred deletion. Neutralized ambush scenes move into a
separate queue, bounded to three convoys. New VIPs retain older IDs. A full queue
allows scanner/cyberpsycho fallback. Tests keep deletion refused for more than
five simulated minutes and emulate Codeware's first-accepted/subsequent-false
contract until a despawn event. Live attacker and VIP cleanup still block a new
assignment. Later cleanup cannot remove the next marker/journal or repay the VIP.
Shift-end retries continue off duty; world resets forget only old-world IDs.

Career tests sum existing scanner history and generated completions without
counting the separate EUR$500 scanner supplement again. Existing promotion
thresholds and individual equipment claim IDs are preserved. Prototype VIP/CP
completions before this version have no stored completion history to migrate.

Native engine objects, transaction results, save serialization and notification
rendering are boundaries. This does not emulate Cyberpunk traffic/animation or
compile against the installed game cache. Optional local `tests/vip/check_native.py`
checks the complete 28-script set with and without Browser Extension Framework.
