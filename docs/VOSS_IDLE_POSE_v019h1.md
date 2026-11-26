# v0.19h1 — hold Voss's existing idle pose

The user confirms that v0.19h's conversation flows without overlap. The
remaining report is a body transition from crossed arms into sideways walking.

The current helper starts the complete vanilla arms-crossed `stand_around__02`
workspot with `PlayInDeviceSimple`. Successful native workspot activity does not
mean that the resource stays on its first idle animation: normal gestures and
branches may still progress. Inspection of the six supplied lipsync clips shows
an additive head rig and null motion-extraction handles, so an ordinary body
workspot branch is the first candidate to isolate. This is not a verified
native rendering diagnosis; no game recording or vanilla workspot tree dump
was supplied for the sideways movement.

After the exact private Voss actor reaches an active, non-entering/non-exiting
pose, the controller makes one `RequestPoseIdle` call. The bridge executes a
`questUseWorkspotNodeDefinition` with `questUseWorkspotParamsV1.function` set to
`questUseWorkspotNodeFunctions.IdleOnlyMode` (3), `enableIdleMode = true`, and the
private `ncpd_patrol_qgiver_test_npc` tag. Changing/restarting a workspot,
teleporting, jumping to an entry and player mode are explicitly disabled.

These are existing native quest types exposed by Codeware, not new native
imports bundled with this mod. Reference declarations are in Codeware 1.21.4:

- `scripts/Base/Imports/questUseWorkspotNodeFunctions.reds`
- `scripts/Base/Imports/questUseWorkspotParamsV1.reds`
- `scripts/Base/Imports/questUseWorkspotNodeDefinition.reds`
- `scripts/Base/Addons/EntityReference.reds`
- `scripts/Quest/QuestsSystem.reds`

The bridge checks world readiness, menu state, meeting stage, attached/living
private record and actual current workspot membership before requesting the
node. The Lua side also retains its existing helper/device-user scope checks;
an absent device-user mapping is still allowed by the previously confirmed
v0.19f1 fix. A different helper user cannot trigger the new request.

`ExecuteNode` has no success receipt for rendered body animation. The returned
boolean only means that the request was issued. A refused/thrown cosmetic
request follows the existing fallback: retain Voss, her car, the SMS and the
quest, and allow the normal conversation. No retry loop, periodic animation
restart, snapback or generic `StopInDevice` is added. The existing helper-first
cleanup and scene-release gate remain responsible for clearing the actors.

API version 3 prevents an updated CET module from using an older bridge that
lacks the request. No archive is rebuilt: all nine archives, the complete scene,
six voices, lipsync, captions, timings, LookAt and SMS data are byte-identical
to v0.19h. Production dispatch, rewards, sites and evidence are untouched.
Existing Andrea Olivato MIT presentation credit remains in the package.

The added portable test executes the actual Lua and translated bridge against
recording native boundaries. An optional moving-branch model distinguishes
the previous controller (no idle-only request) from the new one, across waiting,
all ten dialogue turns and post-conversation retention. It checks single-call
scope, invalid actor/stage/world/menu cases, old bridge refusal, cosmetic
fallback and unchanged v0.19h payload. This model does not emulate native
animation rendering; the source/API compiler also runs with Browser Extension
both present and absent.

Clear the previous quest-giver test, install the complete 123-file package and
fully restart. Wait near Voss outside her 3 m dialogue radius, then approach
and allow the whole conversation to finish without skipping. She should keep
the crossed-arms idle while waiting and speaking. Check her feet stay planted,
eye contact and dialogue timing still work, and Clear/replay remains usable.
If she still walks, the next step is to inspect the actual workspot tree/clip
selection and author a dedicated stationary loop; do not edit the working VO
timings or remove the native pose guards to hide the problem.
