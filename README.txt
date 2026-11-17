NCPD PATROL v0.7a - ARRESTS / SEPARATE PAYMENT TEST
=================================================
On duty, arrest living, downed human enemies through the game's primary body
interaction (normally F). Each registered arrest pays EUR$250 exactly once for
that actor identity in the save. This payment is separate from scanner bonuses.

USE
1. Exit the game completely. Extract this ENTIRE ZIP into the game directory
   containing bin, r6 and archive, replacing NCPD Patrol files. Include the new
   archive/pc/mod/NCPDPatrol_Arrest.archive, arrest.lua, both Arrest redscripts
   and NCPDPatrol_Arrest.yaml. Restart; CET announces v0.7a. Main/support native
   interfaces use version 16; the independent arrest interface uses version 1.
2. Start a shift through the existing terminal interaction or CET.
3. Incapacitate an ordinary human enemy without killing them. Approach/look at
   the body and use Arrest suspect (primary interaction, normally F). Stay on
   foot within 2.5 m for two seconds. There is no new required hotkey or CET step.
4. The mod requests a lying handcuff workspot. It must observe the expected
   non-transition clip, an active workspot and ownership by its private helper
   for at least 0.5 seconds before registering and paying the arrest.
5. Look for NCPD ARREST REGISTERED | +EUR$250. Ordinary body/loot choices return
   after registration. The same body cannot be paid again by pressing F,
   changing shift or loading a save that already contains that payment.

ELIGIBILITY / INTERRUPTIONS
Dead bodies, active enemies, civilians, police, companions, bosses, robots,
mounted actors and quest-marked bodies are excluded. Quest items also mark a
body as quest-related; collect story/evidence items normally before expecting
an arrest choice. A ragdoll or writhing animation alone does not establish life:
both native death checks and defeated/unconscious state are used.
The body interaction is enabled for eligible empty-inventory targets too.
Menus pause treatment/confirmation. Range, death, mounting, wanted/off-duty or
world changes cancel an unfinished arrest. Repeated events share one reservation.
A missing/wrong/foreign animation or failed payment does not register an arrest.
An unconfirmed pose times out rather than granting money for the request alone.

PAYMENT IS INDEPENDENT
NCPDPatrolArrestSystem owns its saved paid-suspect ledger, fixed EUR$250 reward,
transaction, count and receipt queue. It only reads common duty/wanted state.
It does not call scanner monitoring/payment, alter paid activity IDs, increment
activities or scanner bonus totals, or add money to the scanner receipt queue.
Scanner payouts remain as before. The balance in the game's wallet naturally
contains both kinds of money, but each arrest gets its own payment/receipt.
The arrest count shown in CET/logs is paid actor identities in this save, not
scanner activities or a combined shift bonus. Identity is by EntityID, not model.
A newly spawned actor with a different ID is a different suspect.

ANIMATION AND CLEANUP
The small included archive contains an authored invisible gameObject anchor
with a workWorkspotResourceComponent. It references the existing vanilla
base/workspots/common/ground/
generic__lie_ground_lean_front_handcuffs_a__aggressive__01.workspot.
No AMM entity, animation bank, script or dependency is bundled. No paired V
animation or guaranteed visible handcuff prop is added.
The suspect is not respawned, deleted, healed, resurrected or made a follower.
Its defeated/unconscious state remains; the workspot controls the arrest pose.
The mod stops only playback still bound to its own helper. It removes only its
own non-persistent helpers when the player leaves 60 m, the body disappears/dies,
or the shift ends. Failed helper deletions retain their IDs for retries.
A world load forgets old handles without sending deletion into the new world.
The paid identity survives even if the pose ends, the body is carried or ordinary
engine population cleanup removes it. Prisoner transport is outside this build.

TEST AND DIAGNOSTICS
First test an average male/female human enemy on flat ground. The native resource
path and clip candidates are verified in reference catalogues; actual game entry
into this workspot from a defeated body has not been tested here. Animation and
F/input/loot UI compatibility need an in-game test. This is a first test build.
If no pose starts or no payment occurs, send CET lines beginning with Arrest |
and Arrest pose |. They show progression, the observed clip or the failure.
The NCPD ARRESTS CET section shows the current status; CET is not needed to arrest.

VALIDATION
10 Lua modules parse in LuaJIT. All 13 redscripts compile against source-derived
API contracts with zero warnings/errors, not against an actual game cache.
Authored arrest logic and actual CET controller/wrappers execute with native
boundaries mocked. Tests cover eligibility, menu/time/range guards, one payment
per identity across shifts/loads, duplicate/stale callbacks, correct/incorrect/
transition/foreign clip evidence, no payout from a void request, body interactions,
failed cleanup, death and loaded-away references. The actual scanner and arrest
classes are exercised together: one scanner completion pays/counts EUR$1000,
one arrest separately pays EUR$250, without mixing their ledgers or receipts.
Earlier partner/boarding/backup/dispatch/radio/reward regressions also pass.
The archive is compiled with WolvenKit 9.1.1, round-tripped to verify its component
and native dependency, then extracted to verify exact entity bytes.
These checks do not emulate real animations, AI, physics or native save loading.

RETAINED REQUIREMENTS
Cyberpunk 2077 2.5, matching CET, Codeware 1.21.4, RED4ext 1.31.1, TweakXL and
compatible redscript. No extra runtime dependency or new required binding.
v0.6e partner health/voice observations remain; this is not an injury-voice fix.
Scanner/support behaviour and prior receipts are preserved; only their interface
version guards advance. Backup, boarding and follower helper are unchanged.

ROLLBACK TO v0.6e
Exit the game. Remove these five additions, then reinstall the complete v0.6e ZIP:
- archive/pc/mod/NCPDPatrol_Arrest.archive
- bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrol/arrest.lua
- r6/scripts/NCPDPatrol/NCPDPatrolArrestSystem.reds
- r6/scripts/NCPDPatrol/NCPDPatrolArrestInteractions.reds
- r6/tweaks/NCPDPatrol_Arrest.yaml
Keep the v0.6e partner-down YAML and partner-voice script. Prior archives remain
on GitHub. Development asset source/build tool and portable tests are available
in the repository and are not needed in the game-install ZIP.
