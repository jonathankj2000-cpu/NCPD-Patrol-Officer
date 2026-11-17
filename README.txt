NCPD PATROL v0.6e - REVIVE HEALTH / VOICE TEST
============================================
v0.6d is confirmed in-game by the user: downing, revive, following, combat and
boarding work. The remaining report is repeated 'shot/injured' dialogue that
starts after revive. Low health has not yet been measured in that game session.

CHANGES
Revive still uses the same private, infinite DefeatedWithRecover status and the
same actor, interaction and canonical follower-role restoration as v0.6d.

The 100-percent healing request now follows removal of the private down effect
and FollowerDefeated effects. During the existing protected recovery interval,
health is read from the native pool after at least one second. If below 99%,
full health is requested once more and read back on the next eligible tick.
There is at most one extra request per revive. Normal following/combat never
repeatedly heals the partner. The existing recovery/follower gates remain;
a failed heal is reported as the actual lower value, not a fabricated 100%.

New automatic line after follower restoration:
Partner health after revive | health=...% | wounded=... | combat=... |
aid state=... | revives=... | heal before=...% | heal after=...% |
heal measured=... | heal retried=...
health is the current native percentage. heal after is the recovery readback;
a value may change later through combat. Before any completed revive,
heal measured=false means those before/after fields are not a completed test.

The new NCPDPatrolPartnerVoice.reds observes GameObject.PlayVoiceOver script
requests for this mod's registered partner while on duty. It stores the voice
context, script source and a health/Wounded/combat snapshot at request time.
The original call, arguments, delay and return value are always preserved.
No audio is muted, replayed or cancelled. This cannot observe every possible
native audio route and a request is not proof of audible playback.

CET prints Partner VO request lines automatically, at most once per two seconds
and 30 lines per partner/revive. Each line reports the most recent request;
several requests between samples are combined, not an exhaustive voice history.
The existing Log partner AI diagnostics button also prints current health.
A 100% health snapshot during a complaint rules out low health at that request;
Wounded=true alone does not prove which effect caused that spoken line.
The observer does not remove wounds/statuses or alter AI to guess the cause.

INSTALL AND TEST
1. Exit the game completely and extract the ENTIRE ZIP into the game directory
   containing bin and r6, replacing all NCPD Patrol files. Include the NEW
   r6/scripts/NCPDPatrol/NCPDPatrolPartnerVoice.reds and the existing
   r6/tweaks/NCPDPatrol_PartnerDown.yaml. Restart; CET announces v0.6e and both
   native interfaces use version 15.
2. Start a fresh shift/partner, then down/revive normally. The existing Test:
   down partner button is also available. No new hotkey or log arming is needed.
3. If he keeps complaining, send Partner health after revive and Partner VO
   request lines. If no VO request is captured, send the health line anyway.
   The existing Log partner AI diagnostics button can read current health while
   the complaint is happening. No manual active-state setting is required.

VALIDATION / LIMITS
Nine Lua modules parse in LuaJIT. Eleven redscripts pass the local compiler with
zero warnings/errors against source-derived contracts, not an actual game cache.
Authored support logic, the actual VO wrapper and CET modules execute with native
boundaries mocked. Checks cover a rejected first heal, bounded retry, a rejected
retry with truthful low readback, no healing loop after recovery, repeated same-
actor down/revive, scoped voice snapshots, argument/call/return preservation,
logging bounds, rearming, world/duty/wanted guards and prior regressions.
Actual healing, audio and post-revive dialogue still need an in-game test.

Backup, boarding, follower helper, revive interaction, private down record and
movement/controller probe are unchanged from v0.6d. Scanner rewards, dispatch,
radio and chatter logic are retained; interface guards advance to version 15.
Requirements remain Cyberpunk 2077 2.5, matching CET, Codeware 1.21.4,
RED4ext 1.31.0+, TweakXL and compatible redscript. No new dependency or binding.

ROLLBACK
Exit the game, remove r6/scripts/NCPDPatrol/NCPDPatrolPartnerVoice.reds and
reinstall the complete v0.6d ZIP. Keep its PartnerDown YAML. The known-working
v0.6d archive remains on GitHub.
