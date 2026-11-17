NCPD PATROL v0.6c - CONTROLLED REVIVE GATE PROBE
==============================================
The report already established that the partner gets up and stays still. This
build changes the blocking condition before asking for a new observation.

ONE CONTROLLED CHANGE
The user's v0.6b log showed aid state=2, active=true, high level=Relaxed,
follower defeated=false, follower target ready=true, downed signal=true.
The remaining downed tag alone no longer fails recovery readiness. Life/status,
conscious high-level state, companion-defeat effects and follower-target checks
remain. Immortal protection, the same actor and the revive interaction remain.
Existing signal cleanup and role binding are retained. No signal-consumption or
backup AI changes are included. This test does not establish that a residual
signal is harmless to the engine; it removes the mod's veto so that can be tested.

AUTOMATIC OBSERVATION
After revive and follower-target readiness, Revive probe log lines are armed.
When both actors are on foot, outside combat/menus, with at least 5 m separation,
the observer records the existing follow command's ID/state and the partner's
maximum horizontal displacement over a three-second window. Periodic follow
refresh is held during that one window to keep the sampled command stable.
The observer sends no commands, moves/heals nobody and changes no native flags.
Menus, combat and vehicles pause/restart observation. Standing next to the player
is not classified as a movement failure. Native field errors are reported as
unavailable and cannot stop partner control. The observer stops after its result.
The result is Horizontal displacement observed or No horizontal displacement
observed, with command state and the native AI flags on the same line.
A command state does not prove movement; position change does not prove that
follow caused it. The evidence will distinguish the mod gate from a continuing
engine/control problem. Real gameplay is needed to resolve that question.

INSTALL / GET THE NEW EVIDENCE
1. Exit the game completely. Extract this whole ZIP into the game folder
   containing bin and r6, overwriting the mod files. Include new revive_probe.lua.
   Restart. Both native systems use version13; CET announces v0.6c.
2. Use revive once in this new version. Normal play after revive arms/samples
   automatically; there is no manual active-state setting or new hotkey.
3. Send the Revive probe result line from CET. It includes aid state, residual
   downed tag, follower target, command state, elapsed time and displacement.
   The existing Log partner AI diagnostics button also includes probe status.
If the probe is waiting, its status states whether menus/combat/vehicles or a
follow distance under 5 m prevented a useful sample.

SCOPE / REQUIREMENTS
Backup code is byte-for-byte the v0.6b implementation. Duty, scanner bonuses,
dispatch, boarding, wanted termination, chatter and radio behaviour are retained.
Requirements: Cyberpunk 2077 2.5, matching CET, Codeware 1.21.4, RED4ext 1.31.0+,
TweakXL and compatible redscript. No added dependency or required key binding.

VALIDATION
Nine Lua modules parse in LuaJIT. Redscript checks pass with zero warnings/errors
against source-derived contracts, not the actual game script cache. Authored
support logic and actual CET modules run against simulated native boundaries.
Checks cover the exact residual-tag combination, same-actor revival, a stable
sampled follow command, movement/no movement, near-player demand, menu/combat/
vehicle pauses, hitches, native property errors, world reset and prior regressions.
These checks cannot verify actual Cyberpunk movement or the underlying cause.

ROLLBACK
Exit the game, remove revive_probe.lua from the CET mod folder and reinstall the
complete v0.6b ZIP. Earlier archives remain on GitHub.
