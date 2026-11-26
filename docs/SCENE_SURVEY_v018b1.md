# Injured transition measurement pilot

The uploaded v0.18b evidence supports investigating early injured-actor rejection.
This patch adds an opt-in three-site protocol while retaining the full 17-site
procedure, live Officer Down geometry/behavior, native scripts and archives.

## What the supplied files establish

The JSON export and JSONL contain the same **223 events** from one run:

- 85 scene creation trials and 82 post-spawn trial failures.
- **76 failures** say `Actor displaced: injured`; four name gang cars, one the
  police car and one an enemy. Preflight rejection is a separate category.
- The 76 injured failures have whole-second timestamp differences of **one
  second in 45 cases and two seconds in 31 cases** from the matching creation
  event. These timestamps do not establish precise subsecond animation timing.
- Kryss_04 has seven injured failures and one gang-car failure; Kryss_11 has
  eight injured failures. Kryss_15 has an injured failure followed by validation.
- Kryss_15's final injured displacement is about **1.286 m**, with a maximum
  observation displacement about **1.291 m**. Both are below the existing
  **1.5 m** limit, so its old acceptance is consistent with the validator.
- Only **15 site outcomes** were completed: two validated and 13 unverified.
  The run stopped at Kryss_16 because V was observed outside the allowed scene
  center range. The log does not establish whether this was input or a physical
  push. Kryss_17 was not reached.

The previous observer ran just after attachment/protection applied the private
down status, without a settling phase. It returned on the first displacement
failure before saving that actor's failed XYZ. Thus the logs establish which
actor/phase failed, but cannot prove an animation-induced trajectory, a final
offset, its direction, or whether waiting would rescue the location. The source
JSONL SHA256 was `cc8ca116d7a56723d2d32fd93f687d705596c47646780b6dbe7e5091a00bfc3f`.

## Run the narrow test

Install the full **105-file v0.18b1 package** and fully restart. Preserve the
existing `scene_survey_results.jsonl`; no test results ship in the ZIP.
Load a manual test save, go **OFF DUTY**, exit the vehicle and clear earlier
dispatch/backup actors. In **CET → Testing → Scene survey**, use
**TEST: Injured settling pilot (3 sites)**. Close CET and leave V still.

The queue is **Kryss_04, Kryss_11 and Kryss_15**, including the previously
validated control. Current and saved successful headings remain available as
starting choices. Export afterwards and share **both** JSON/JSONL files from the
NCPDPatrol CET folder. The ordinary all-17-site buttons retain their old immediate
observer; choosing the pilot does not roll its policy into those buttons.

## Pilot procedure and limits

All ten actors still have to pass the original preflight, actual creation,
record/ID/attachment and protection checks. After the injured actor is bound,
the pilot records its position during remaining spawning and the transition.
Once the complete scene is attached, wait **four active seconds**.

During this window, only the injured actor's original 1.5 m distance rejection
is deferred. Its identity, attachment, finite position and life remain checked.
A hard temporary envelope of **3 m horizontally / 1.5 m vertically** still
rejects catastrophic movement, and a confirmed root more than 0.2 m below
supported ground rejects a through-floor condition. This envelope never grants
a validated result. The other nine actors retain the original **1.5 m** rule
after attachment and throughout the settling/observation phases.

After the window:

1. Require **all actors within 1.5 m of their original requested positions**.
   No expected position is reset to wherever the actor happened to settle.
2. For the injured actor, require a finite Static support hit, normal Z at least
   0.85, and root height from -0.2 to 0.75 m over that surface.
3. Check local body-height Static rays and a small Vehicle overlap proxy at the
   final position. These are conservative local clearance tests, not full
   skeleton/animation collision proof.
4. Observe **three active seconds** with every actor remaining within **0.15 m
   of its observation-start position**, in addition to the unchanged original
   1.5 m bound. Continued drifting/wriggling of the entity root is rejected.
5. Confirm physical cleanup before writing a validated site result or moving V.

Menus and unready worlds pause active sampling. Cancellation, physical deletion
gates, source-specific protection, CET recovery, world-generation invalidation,
original-position return and disk-error cleanup retain the established behavior.
The survey starts no quest and awards no credits or career progress.

## Measurements and isolation

`injured_motion_sample` events are emitted at the existing roughly 0.25-active-
second polling cadence, including the rejection frame. They contain:

- spawning/settling/observing phase and active time since the down request;
- original expected XYZ, actual XYZ, 3D displacement and per-sample movement;
- world delta and delta projected onto the requested heading's forward/right
  axes, making a repeatable directional offset distinguishable across headings;
- transition peak, life/high-level state when available, support observations,
  local clearance flags, final anchor drift and the actual rejection reason.

There is no animation-completion callback in this measurement. A high-level
state or elapsed timer does not prove which animation clip is playing. There
is **no actor teleport, expected-position rebase or spawn compensation**. A stable
final 1.8 m offset still fails; its measured vector can inform a later decision
about configuration compensation rather than silently accepting bad placement.

Pilot events use `validation_profile = injured-settling-pilot-v1`. Exported site
rows carry separate pilot latest/proven fields. Older rows without a profile
remain legacy evidence. Pilot successes do not overwrite legacy results or alter
the ordinary retry filter. The unchanged catalog/layout revisions preserve the
user's original evidence and headings.

## Verification

The portable tests compare the current default full tour against the exact
v0.18b Lua implementation at `6b8db2612cb2504270a6fad779ee436c34bbfb1f`.
Normalized events, virtual timing, movement, CreateEntity specs and deletions
match. Tests additionally cover a transient 1.8 m shift returning to 0.8 m,
persistent 1.8 m rejection, strict police-car movement, catastrophic/below-ground
motion, missing ground, local Static/Vehicle obstruction, final drift below the
old distance bound, menu/world pauses, cancellation, file failure and profile
isolation. These tests mock engine motion; they do not prove the actual down
animation caused the uploaded failures or that the real three-site pilot passes.

All **41 REDscript files**, seven archives, live Officer Down controller/layout
and the 17-location input catalogue are byte-identical to v0.18b. Only the explicit
survey pilot/measurement path, additive UI and validation-profile storage change.
