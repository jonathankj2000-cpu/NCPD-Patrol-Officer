NCPD PATROL v0.7e - NATIVE ARREST ACTIVATION TEST
==============================================
The v0.7d test showed active playback but no debug callbacks or clip data.
This build registers completed securing plus stable native activation. It no
longer requires readable animation names. This is a change in confirmation
policy: activation does not prove which clip is rendered.

INSTALL AND TEST
1. Exit the game completely. Extract the ENTIRE ZIP into the game directory
   containing bin, r6 and archive, replacing NCPD Patrol files. Include the new
   NCPDPatrolArrestEvents.reds and updated NCPDPatrolArrestPlayback.reds.
   Restart; CET announces v0.7e. Main/support interfaces remain 17, arrests use 4.
   The archive is unchanged from v0.7b/v0.7c/v0.7d. No new runtime dependency.
2. While ON DUTY, incapacitate an ordinary human enemy without killing them.
   Approach/look at the body, use Arrest suspect (normally F), and remain on
   foot within 2.5 m until the receipt. Securing takes two seconds, followed by
   the activation confirmation described below. No extra binding or CET action.
3. Expect NCPD ARREST REGISTERED | +EUR$250 and one increase in the arrest count.
   That saved actor identity cannot pay again through repeated input, changing
   shift or loading a save containing its payment.
4. Remain nearby for 15-20 seconds to test the lying pose keeper. It re-selects
   the requested lying handcuff clip at most once per second after registration.
   Actual holding still needs an in-game test; forced native exits release it.

CONFIRMATION POLICY
The vanilla resource must exist, load and contain a lying handcuff candidate.
The native proof is armed for the exact actor, helper and request token before
PlayInDeviceSimple, and refuses actors already using a workspot. The engine must
then report IsActorInWorkspot and active playback outside entering/exiting.
A normal PlayInDeviceCallbackEvent is requested on our private helper. A positive
result from that helper requires 0.75 s continuous activation. If no result
arrives, 1.5 s continuous activation supplies the fallback. A negative result
received while pending cancels registration. Other helper IDs, stale requests
and duplicate results are ignored. A success event alone cannot grant money.
Both routes still check duty, wanted state, life/eligibility, range, request token
and duplicate identity before the transaction. A void request without settled
native activation never pays. Menus/hitches cannot fast-forward either timer.
This confirms playback activation, not a rendered lying clip. No animation name
or callback path is invented; logs explicitly say observed clip=unavailable.
The functional-test listener, raw instance and device-user gates are removed.

POSE KEEPER AND CLEANUP
The initial working workspot/clip request is retained. Once registered, the
controller re-selects the same lying clip no more than once per second, without
additional play signals. It does not poll animation names or inspect transitions.
No repeated selection is sent during the initial confirmation window.
Pose commands stop on lost/ending activation, death, mounting, removed downed
state, duty end, helper loss or scene departure over 60 m. Only private managed
helpers are deleted, with retries for refused deletion. No unverified
StopInDevice is sent to ambient actors. Loading forgets old handles.
No shared game resource, bank tree, health, defeated status or AI role is edited.
The existing vanilla bank supplies animations/props; no AMM dependency or paired
V animation is added. Prisoner transport is not included.

PAYMENT AND ELIGIBILITY
Arrests still own a saved paid-identity ledger, fixed EUR$250 reward, transaction,
count and receipt queue. Scanner activity IDs, EUR$1000 scanner payouts, bonus
counters and scanner receipts are unchanged. A failed transaction does not mark
the suspect paid; receipt callbacks never award money. Payment survives a pose
ending, ordinary engine cleanup and shift changes.
Dead/active/civilian/police/companion/boss/robot/mounted/quest-marked actors are
excluded. Quest/evidence items can mark a body as quest-related; loot them first.
Eligible empty-inventory bodies expose Arrest suspect. Normal body/loot choices
return after registration or off duty. Moving away, death, mounting, wanted,
duty end or loading cancels unfinished registration.

DIAGNOSTICS AND VALIDATION
If it fails, send Arrest activation, Arrest request, Arrest hold and Arrest |
lines. Activation reports source=native play result or native activation fallback,
result status, native flags and stable/required seconds. Observed clip remains
unavailable. Metadata clip names are requests, not runtime animation evidence.
All 10 Lua modules parse. All 15 redscripts compile against source-derived API
contracts with zero warnings/errors, not against an actual game cache. Tests run
the actual proof/controller/result receiver and payment code with native APIs
mocked. They cover the reported no-debug-data state, stable activation fallback,
positive/negative/foreign/stale helper results, no-entry/transition states,
timers/menus, death/range/wanted, loading failures, one-second request limits,
cleanup/world loads and independent 1000/250 scanner/arrest payments.
These checks do not emulate native event dispatch, rendered animations, AI,
physics or native save loading. The receipt and physical pose need a game test.
Partner revival/boarding/backup, scanner monitoring, dispatch, radio, main/support
scripts and archive bytes are unchanged. Requirements remain game 2.5, matching
CET, Codeware 1.21.4, RED4ext 1.31.1, TweakXL and compatible redscript.

ROLLBACK
To return to v0.7d, exit the game, remove the new
r6/scripts/NCPDPatrol/NCPDPatrolArrestEvents.reds, then reinstall its entire ZIP.
Returning to v0.7c also requires removing NCPDPatrolArrestPlayback.reds.
To return to v0.6e, remove both scripts above, arrest.lua,
NCPDPatrolArrestSystem.reds, NCPDPatrolArrestInteractions.reds,
r6/tweaks/NCPDPatrol_Arrest.yaml and archive/pc/mod/NCPDPatrol_Arrest.archive,
then reinstall the full v0.6e ZIP. Keep its partner-down YAML and voice script.
Earlier complete ZIPs remain available on GitHub.
