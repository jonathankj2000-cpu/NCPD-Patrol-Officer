# v0.18f — Scene arrival and stray fire

The reported Officer Down scene was prepared but later failed with `Actor
displaced: defender` while V remained in a vehicle. The previous code applied
the survey's 1.5 m placement threshold on every live staging sample, including
after approval. It also requested a teleport and immediately measured position;
an asynchronously applied teleport cannot guarantee that next measurement.
This is a source-backed failure path, not proof of the exact animation in the
reported session. The previous arrival radius was 55 m, but the 4 s settling
plus 3 s usable-access window could delay actual combat far inside that radius.

## Live Officer Down staging

- Native and Lua arrival gates use one authored 50 m radius. Being mounted does
  not prevent activation. All ten actual actors must still attach and bind.
- Cars retain protection, braking, position correction and displacement checks.
  Standing NPCs keep their hold command and protection, but no longer receive
  spawn-anchor teleports. Fresh identities/finite positions, the 25 m scene
  area, supported ground/height, Static and vehicle clearance are checked.
- Live standing-NPC movement is judged by physical safety, not spawn precision.
  The opt-in live policy does not change any off-duty survey profile or evidence.
- Approaching from a distance still permits the existing settling/access window.
  Reaching 50 m may activate as soon as a complete current body/aid-state/clearance
  and walking-path snapshot succeeds; it does not require waiting 7 extra seconds.
- Once proved, aid access survives a temporary failure to calculate a walking
  route from V's vehicle seat. Actual injured body/ground/down-state/clearance
  checks continue before release. Missing, buried, blocked or escaped actors
  remain failures. Combat then uses the existing native quest/aid/completion code.
- `ready`/`arrived` gameplay logs remain, with `arrival_check` and actual proof.
  Diagnostics now expose `scene approved` and `combat radius`. The scene is not
  advertised as ready immediately on attachment.

## Bounded accidental police-hit allowance

The old police-hit policy explicitly excluded V and covered only the exact
registered partner. The criminal-duty monitor still terminates a shift on a
wanted level. The new policy runs before the normal NPC/vehicle `OnHit` callback
that starts the damage pipeline; it does not clear wanted levels afterwards.

V's exception requires the attached living local player, active non-wanted duty,
a ready world, combat state, a ranged gun hit on a non-hostile police NPC or
police vehicle, a valid current weapon/attack/time and nearby hostile context.
Context is a living, active non-police hostile within 150 m that V is looking at
or tracking, or one that hit V with gunfire in the last six simulation seconds.
The incoming-hit observer never suppresses the original incoming hit.

Looking at or tracking any police receiver prevents the exception. The policy
allows one discharge per ten simulation seconds, shared across all police
receivers and weapons. Further callbacks for that exact attack reference,
weapon and attack timestamp are grouped for at most 0.5 s for pellets/ricochets.
Different shots do not enter a general immunity window. An allowance displays
`NCPD: Stray police hit excused. Check your fire.` once. Transient context and
allowances reset on world/shift start; no persistent career fields are changed.

Deliberate direct aim, repeated shots, civilian damage, hostile police, other
companions, off-duty events, non-ranged attacks and already-wanted states retain
the original handling. The current-partner guard is retained. `EnforceDutyRules`
is unchanged, so a legitimate wanted level still terminates duty and dispatch.

This is a conservative heuristic at hit delivery, not a perfect intent detector.
Targeting data may be stale/missing, and fast aim changes/projectile timing can
produce false negatives or positives. One-hit protection cannot establish the
cause of the user's original wanted event. Near-miss gunshot stimuli, explosions,
other crime events or third-party rewrites are outside this exception.

Source contracts are pinned to In-Question/MOD_Development_Reference
`81d996b584a693e8b0f0b20526a9fa38b5c83fe7`: `core/entity/gameObject.swift:984`,
`core/gameplay/vehicles.swift:993`, `cyberpunk/NPC/NPCPuppet.swift:2690`,
`cyberpunk/damage/attackData.swift:204/252`, `cyberpunk/damage/preAttack.swift:92`,
`cyberpunk/damage/damageSystem.swift:1339`, and `orphans.swift` GameInstance and
TargetingSystem declarations. No RTTI-only native method is imported at runtime.

## Verification and required gameplay checks

Portable tests execute the real Lua lifecycle and translated REDscript policy,
owner and wrappers. Exact previous v0.18e2 modules reproduce defender displacement,
late activation and V's unprotected police-hit path as negative controls. New
cases cover mounted 50/51 m boundaries, fast arrival, pre/post-approval movement,
seat/path failure, unsafe actors/cars, exact-shot pellet grouping, direct aim,
repeat shots, stale/dead/friendly threats, load reset and unchanged wanted
termination. Engine damage, navigation, targeting and clock remain boundaries.
All earlier package suites and the corrected offline API compile with Browser
Extension both present and absent remain required. This is not a game-cache
compile or proof of actual animation, damage/police behavior or third-party order.

Install the complete package and fully restart. In a manual test save, approach
Officer Down in a car and check combat starts near 50 m. Let a cyberpsycho engage
V, then compare a genuine off-target police hit with deliberate police aim and
repeated shots. The allowance message and CET Diagnostics > Scanner bonus and
radio > Log police fire diagnostics distinguish an excused discharge. Retest
Officer Down completion/repeat calls; its v0.18e2 cleanup rules are retained.
