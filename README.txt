NCPD PATROL v0.7d - ARREST CALLBACK / LYING HOLD TEST
==================================================
The v0.7c in-game test confirmed visible handcuff animation. It did not reach
payment: GetWorkspotInstance and GetDeviceUser were empty despite native active
playback. The three-second confirmation timeout then deleted the helper.
This build replaces that confirmation route with scoped native callbacks and
attempts to redirect a standing transition back to the lying handcuff clip.

INSTALL AND TEST
1. Exit the game completely. Extract this ENTIRE ZIP into the game directory
   containing bin, r6 and archive, replacing the existing mod files. Include the
   new r6/scripts/NCPDPatrol/NCPDPatrolArrestPlayback.reds. Restart; CET announces
   v0.7d. Main/support interfaces remain 17; the arrest interface is now 3.
   The included NCPDPatrol_Arrest.archive is unchanged from v0.7b/v0.7c.
2. Start a shift. Incapacitate an ordinary human enemy without killing them.
   Approach/look at the body, use Arrest suspect (normally F), and remain on
   foot within 2.5 m for two seconds. No additional binding or CET action.
3. Expect a lying handcuff pose and NCPD ARREST REGISTERED | +EUR$250 after the
   native callback proof has remained valid for half a second. The CET arrest
   count should increase once. Repeating input or changing shift cannot pay
   that saved actor identity again.
4. Stay nearby for 15-20 seconds to check the hold. On an observed transition
   after a lying clip, the controller re-selects the lying clip. This mechanism
   still needs in-game validation: native forced exits may end the pose.

CONFIRMATION AND HOLD
A fresh NCPDPatrolArrestPlayback listener is registered for the suspect using
SendDebugCommandFunctionalTests / FunctionalTests. It records OnWorkspotSetup,
OnAnimationChanged, missing/skipped clips, finish and instance removal.
Payment requires the expected native resource path and an allowed lying clip,
the correct actor/request token, active playback outside entry/exit, and a
stable half-second observation. A second setup, missing clip or ended context
invalidates the proof. Active=true by itself and a void play request cannot pay.
The old instance lookup is diagnostic only; instance=false can accompany a valid
native callback. context=true means the fresh callback matches the expected
resource and is not superseded/finished, not a GetDeviceUser result.
The native payment entry point also checks the callback proof before the usual
eligibility, range, token, duplicate identity and transaction checks.
After payment the helper is retained. A standing/other transition after a real
lying clip gets at most one jump per callback revision, with a half-second
cooldown and at most three unacknowledged corrections. If it does not return
within three seconds, playback is released. A finished/superseded context is
released without controlling the replacement. Saved payment remains paid.
No shared game resource, bank tree, animation or NPC life/AI state is rewritten.

PAYMENT IS STILL INDEPENDENT
NCPDPatrolArrestSystem retains its own saved paid-suspect ledger, fixed EUR$250
reward, transaction, count and receipt queue. Scanner activity IDs, EUR$1000
scanner payouts, scanner bonus counters and scanner receipts are unchanged.
A failed transaction does not add the suspect to the paid ledger. Receipts never
award money. Identity is by saved EntityID, not model or a combined shift total.

ELIGIBILITY AND CLEANUP
Dead bodies, active enemies, civilians, police, companions, bosses, robots,
mounted actors and quest-marked bodies are excluded. Quest/evidence items can
mark a body as quest-related; loot them normally first. Eligible bodies with
empty inventories can expose Arrest suspect. Normal body/loot choices return
after registration or off duty. Menus pause treatment/confirmation. Death,
mounting, moving away, wanted/off-duty or loading cancels unfinished arrests.
The suspect is never respawned, deleted, healed, resurrected or made a follower.
Only private nonpersistent helpers are deleted after leaving 60 m, shift end,
body loss/death or lost playback. Failed deletions retain IDs for retry. A world
load forgets old handles. Callback listeners are disarmed on cleanup; they keep
bounded state and only a weak actor reference. Prisoner transport is not added.
The existing vanilla ground/handcuff resource supplies animation and props.
No AMM asset or dependency and no paired V animation is added.

DIAGNOSTICS AND VALIDATION
If it fails, send lines starting Arrest setup, Arrest resource token, Arrest
bank, Arrest pose, Arrest native, Arrest hold and Arrest |. In the new pose line,
source=native callback, clip, context and path show the actual confirmation.
The native callback bridge and transition interruption still need an in-game
test. The prior build's visible animation does not prove this new bridge works.
10 Lua modules parse. All 14 redscripts compile against source-derived API
contracts with zero warnings/errors, not an actual game cache. Actual authored
callback/controller/payment code runs against mocked native boundaries. Tests
cover empty old lookups with valid callbacks, missing/wrong/transition/foreign/
superseded/stale proof, one separate payment, hold correction and bounded failed
holds, asynchronous loading, menus/range, body choices and cleanup/world loads.
These checks do not emulate rendered animation, native callback dispatch,
physics, AI or native save loading. The archive is byte-identical to v0.7c.
Partner revival/boarding/backup, scanner rewards, dispatch, radio and native
main/support scripts are unchanged. Requirements remain game 2.5, matching CET,
Codeware 1.21.4, RED4ext 1.31.1, TweakXL and compatible redscript.

ROLLBACK
To return to v0.7c, exit the game, remove the new
r6/scripts/NCPDPatrol/NCPDPatrolArrestPlayback.reds, then reinstall its full ZIP.
Earlier complete ZIPs remain on GitHub. To return to v0.6e also remove arrest.lua,
NCPDPatrolArrestSystem.reds, NCPDPatrolArrestInteractions.reds,
r6/tweaks/NCPDPatrol_Arrest.yaml and archive/pc/mod/NCPDPatrol_Arrest.archive.
Keep v0.6e's partner-down YAML and partner-voice script.
