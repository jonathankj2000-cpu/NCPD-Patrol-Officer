NCPD PATROL v0.6d - RECOVERABLE PARTNER TEST
==========================================
The v0.6c gameplay log confirmed zero horizontal displacement after revive.
The tracked command object's state stayed Enqueued; the native controller's
command state had not yet been queried. This build tests a different down cycle.

CHANGE
The partner now receives a private NCPDPatrolPartnerDown status derived from
vanilla DefeatedWithRecover, with BaseStats.InfiniteDuration and savable=false.
Only this mod's registered, spawned partner receives the effect. Vanilla status
records and ambient officers are not modified. The partner remains down until
manual revive; the ordinary timed follower defeat is not used as the timer.

Revive restores health and removes the private effect, allowing the game's
recoverable-status removal callback to return the actor to a conscious state.
The old ordinary Defeated / ResurrectEvent cycle and manual downed-signal,
senses, bump and high-level repairs have been removed. Canonical follower-role
rebinding and follower-target confirmation remain. The actor is not respawned.
The scoped Immortal protection, extra protection while down, 3-second treatment
within 2.5 m, interruptions and world interaction remain.

Registration checks that the new record exists, is DefeatedWithRecover and uses
InfiniteDuration. A missing/wrong record is rejected with an install error.
Native recovery readiness still requires the effect to be gone, the actor to
be active/conscious and no FollowerDefeated effect. A residual downed signal
remains diagnostic; it is not forcibly removed or a mod-only readiness veto.
No new V treatment animation is added. Down/get-up behaviour is the game's.

AUTOMATIC OBSERVATION
After revive and follower-target confirmation, the observer waits until both
actors are on foot, outside combat/menus and at least 5 m apart. For three
seconds it records the same follow command and horizontal displacement. The
periodic follow refresh is held for that window so the command remains stable.

Revive probe: command ID, OBJECT state, elapsed time, displacement and native
partner flags. Revive controller: the controller's GetCommandState result for
that command, whether a follow command executes, the selected follow command's
ID and AI update tick count. These are separate lines to fit the console better.
The selected follow ID can differ from the tracked ID; neither state alone
proves movement. Optional controller calls fail independently as unavailable.
The observer is read-only, pauses/restarts around menus/combat/vehicles and
stops after one result. It never sends/cancels commands or changes native flags.
The existing Log partner AI diagnostics button still reports probe progress.

INSTALL AND TEST
1. Exit the game completely. Extract the ENTIRE ZIP into the game directory
   containing bin and r6, overwriting the existing NCPD Patrol files. Include
   the NEW r6/tweaks/NCPDPatrol_PartnerDown.yaml. Restart; CET announces v0.6d
   and both native interfaces use version 14.
2. Start a new shift to create a fresh partner. An actor already defeated by an
   older version is not a valid test of the new down cycle.
3. Down/revive the new partner once. The existing CET Test: down partner button
   can trigger this without combat; normal low-health downing also uses it.
   Approach and use Revive Partner, staying within 2.5 m for 3 seconds.
4. Resume normal play. Check follow and boarding. Observation arms automatically;
   no manual active-state setting, log arming button or new binding is needed.
   If still stuck, send the Revive probe AND Revive controller result lines.
   If waiting, the probe explains the distance/menu/combat/vehicle condition.

SCOPE / REQUIREMENTS
Backup is byte-for-byte v0.6c/v0.6b. Duty, scanner bonuses and receipts, dispatch,
boarding, wanted termination, vehicle chatter and radio behaviour are retained.
Requirements: Cyberpunk 2077 2.5, matching CET, Codeware 1.21.4, RED4ext 1.31.0+,
TweakXL and compatible redscript. No added dependency or required key binding.

VALIDATION AND LIMITS
Nine Lua modules parse in LuaJIT. All ten redscripts pass the local checker with
zero warnings/errors against source-derived API contracts, not a game cache.
The authored support class and real CET modules execute with simulated native
boundaries. Checks cover repeated same-actor cycles, indefinite manual downing,
missing/wrong config, delayed effect removal, unsuccessful native recovery,
role-target confirmation, interruptions, menu/vehicle/wanted/load guards,
controller/object state disagreement, measured/no displacement, unavailable
native APIs, bounded logging and previous bonus/dispatch/backup regressions.
These checks do not simulate real AI, animations, navigation or game physics.
The vanilla recoverable callback is documented in the game-script reference;
whether this avoids the user's actual AI stall must be tested in the game.

ROLLBACK
Exit the game. Remove r6/tweaks/NCPDPatrol_PartnerDown.yaml and reinstall the
complete v0.6c ZIP. Earlier archives remain on GitHub.
