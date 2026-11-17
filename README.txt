NCPD PATROL v0.7f - PRIVATE LYING LOOP TEST
=========================================
The user confirmed arrests/payments work in v0.7e, but the vanilla workspot
continued through standing/idle and then returned to the defeated animation.
This build uses a private workspot containing only an infinite lying idle.

INSTALL AND TEST
1. Exit the game completely. Extract the ENTIRE ZIP into the game directory
   containing bin, r6 and archive, replacing existing mod files. Replace
   archive/pc/mod/NCPDPatrol_Arrest.archive: it now contains two resources and
   the helper component name has changed to NCPDPatrolArrestLoop. Restart;
   CET announces v0.7f. Main/support interfaces remain 17; arrests now use 5.
2. Start a shift, incapacitate an ordinary human enemy without killing them,
   approach/look at the body and use Arrest suspect (normally F). Stay on foot
   within 2.5 m until the separate NCPD ARREST REGISTERED | +EUR$250 receipt.
3. Remain nearby for at least 30-60 seconds. Check whether the suspect stays
   lying with hands behind the back. The resource loops itself; the controller
   no longer restarts the animation every second or sends play/advance signals.
4. Try another eligible body, including an average female human if available.
   The same paid identity must not pay again. No new hotkey or CET action.

WHAT CHANGED
The archive contains the private helper and an authored arrest_lying_loop.workspot.
Its Root -> Output -> WorkspotHub graph feeds a root sequence and one inner
sequence whose idle is lie_ground_0__2h_back_handcuffs_a__01. Both sequences loop
infinitely. A 30-second pause holds the idle before repeating. There are no
standing clips, exit nodes or custom transitions. Natural exits and sequence
time limits are disabled in this private tree. No last-frame freeze is used.
The helper references this private file. Before playback, CET loads the original
vanilla handcuff resource and the private resource. It copies animation/rig and
item/prop bindings into the mod-owned tree once per world, retaining native setup
hashes because the animation sets are unchanged. The native source tree is not
modified. Private loop flags, nodes, tags and status effect remain authored.
All original rig setups are copied, rather than selecting only a male rig.
Playback jumps once to sequence ENTRY ID 2. This is not handle ID 6, nor a jump
to an idle name assumed to be an animation leaf. No SendPlaySignal is sent.
This is a test of a real resource loop. The compiled topology cannot establish
whether a rig's idle itself contains unexpected movement or AI forces an exit.
No suspect despawn is added in this preferred-loop trial.

REGISTRATION AND PAYMENTS RETAINED
Registration, eligibility, persistent paid identities, EUR$250 transactions,
receipts, native activation proof and production-result receiver match the
user-confirmed v0.7e behavior. The native system only adds the loop path and
advances its interface version. Two-second securing remains, followed by
0.75 seconds settled activation with a positive result from the exact private
helper, or 1.5 seconds when no result arrives. A pending negative result vetoes
registration. Wrong/duplicate/stale results and unsettled activation cannot pay.
The system still verifies activation, not the rendered clip. Menus and oversized
frame deltas cannot advance the timers. Duty, wanted state, life, range and
saved identity are checked again before the transaction.
Scanner activity IDs, EUR$1000 scanner payouts, bonus totals and scanner receipts
are unchanged. Arrests retain their own reward, ledger, count and receipt queue.
A failed transaction does not mark a body paid; receipts never award money.

ELIGIBILITY AND CLEANUP
Dead/active/civilian/police/companion/boss/robot/mounted/quest-marked bodies are
excluded. Quest/evidence items can mark a body as quest-related; loot them first.
Eligible empty-inventory bodies expose the action. Normal body/loot choices
return after registration or off duty. Range, death, mounting, wanted/duty end
or loading cancels unfinished registration. No NPC is healed, resurrected,
respawned, deleted or assigned an AI role by this build.
The helper is released on native playback/actor-state loss, shift end or leaving
60 m. Only private managed helper IDs are deleted, with retries. No unverified
StopInDevice command is sent to ambient actors. Loading forgets old handles and
clears the private binding cache. Saved payments remain if the pose ends.
No AMM dependency, paired V animation or prisoner transport is added.

DIAGNOSTICS AND VALIDATION
Send Arrest loop, Arrest request, Arrest activation and Arrest | lines if the
pose still ends or payment fails. Loop setup should report private bindings
configured, entry=2, infinite=true and natural exits=false. Requested clips and
compiled topology are distinct from unavailable runtime clip telemetry.
The archive is built with WolvenKit 9.1.1. Both resources round-trip; validation
checks the PC graph, entry IDs, infinite flags, no natural exits/transitions,
and packing/extraction preserves exact bytes. No native animation bank is bundled.
All 10 Lua modules parse. All 15 redscripts compile against source-derived API
contracts with zero warnings/errors, not against an actual game cache. Tests
consume the actual authored loop JSON, verify one entry-ID jump without replay
signals, separate resource readiness, copied rig/setup bindings, unchanged native
source data and unchanged payment/interaction/cleanup guards. Missing or invalid
private loops do not silently fall back to the vanilla standing sequence.
Native metadata initialization, rendered animation, AI, physics and native save
loading are not emulated; the physical loop requires an in-game test.
Partner revive/boarding/backup, scanner monitoring, dispatch, radio, main/support
scripts and the activation-proof/result/interaction scripts are unchanged.
Requirements remain game 2.5, matching CET, Codeware 1.21.4, RED4ext 1.31.1,
TweakXL and compatible redscript. No new runtime dependency.

ROLLBACK
Exit the game and reinstall the complete v0.7e ZIP, including its original
NCPDPatrol_Arrest.archive. No new install-file paths were added by v0.7f.
Earlier full ZIPs remain on GitHub. For v0.7d also remove NCPDPatrolArrestEvents.reds;
for v0.7c also remove NCPDPatrolArrestPlayback.reds. See earlier READMEs for fully
removing arrests when returning to v0.6e.
