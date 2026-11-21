# Career shift control and partner police-hit safety

The Career browser previously rendered a disabled `SHIFT ACTIVE` button while
on duty. The same sidebar location now shows an enabled `END SHIFT` on the
service, rewards and partner pages. Start and end have separate desired-state
handlers, so a stale callback never toggles duty in the other direction. Both
queue the existing native `RequestDuty` bridge; the normal CET controller owns
partner dismissal, incident cancellation, backup cleanup and final shift notices.
Repeated clicks are disabled with `SHIFT REQUESTED` / `ENDING SHIFT` feedback.
Refresh can retry the same desired state. Saving/loading retains the established
off-duty reset and persistent career/payment ledgers. Fast travel's existing
Start/End action is unchanged. Browser Extension remains optional.

`CET > Testing > Dispatch scenarios > TEST: Request Officer Down dispatch`
now calls the same surveyed-site request as the Dispatch-tab button, alongside
the scanner, VIP and cyberpsycho tests. It retains availability, single-assignment
and cleanup guards. The original fixed-intersection prototype stays separate.

## What the source establishes

Reference snapshot: `In-Question/MOD_Development_Reference` at
`81d996b584a693e8b0f0b20526a9fa38b5c83fe7` (decompiled source, not the installed
game/other-mod combination).

- `cyberpunk/damage/damageSystem.swift:1339`: normal post-processing calls
  `SendDamageRequestToPreventionSystem` only for a player instigator. That
  request contains target/time/type/damage, not the original attacker.
- `core/entity/gameObject.swift:1304`: death-related prevention reports check
  whether any credited damage dealer is the player.
- `core/gameplay/vehicles.swift:60`: a vehicle's `IsPrevention()` depends on
  prevention passengers, rather than merely having an NCPD vehicle record.
- `core/gameplay/vehicles.swift:1001`: `ReactToHitProcess` can `InjectThreat`
  when a crowd police vehicle is hit by an attacker that is not a prevention unit.
- `core/gameplay/vehicles.swift:1040`: finalization can send a `CombatHit` to
  the police driver, independently of the ordinary player-only crime gate.
- `core/components/targetTrackingComponent.swift:308`: the ordinary puppet hit
  path separately excludes companions; that does not remove the vehicle path.

These paths explain why treating all partner hits as automatically exempt is
unsafe. They do **not** prove that the reported bullet caused the observed wanted
level. A collision, another hit or another mod could also be involved. This
version does not reinterpret or clear wanted state after the fact, where the
original instigator is no longer available in a prevention request.

## Narrow intervention

`NCPDPatrolPartnerSafety` wraps the ordinary `OnHit` callbacks on `VehicleObject`
and `NPCPuppet`. The reference callbacks normally delegate to the standard damage
pipeline. A hit is ignored before that delegation only when:

1. The hit receiver matches the event target and both receiver and attacker
   remain attached to the current ready world.
2. Duty is active and the living, attached player is available.
3. The exact attacker reference is the current `SupportSystem.IsPartner` actor.
4. The attack type is ranged gunfire.
5. The receiver is a police NPC or a vehicle with prevention occupants/NCPD
   affiliation, and is hostile to neither V nor the partner.

Enemy targets and hostile police quest actors keep their ordinary hit callbacks.
V's bullets, other mods' companions, backup, unregistered former partners, melee,
explosions, collisions and off-duty events pass through with the original return
value. There is no record-wide immunity, suppression window or wanted reset.
The exact transient partner reference is cleared by existing save/load lifecycle.
No new polling, saved ledger, actor AI setting or default log spam is introduced.

## Validation and playtest

The Career fixture executes actual page rendering, callbacks and native requests
for both duty states, all three sections, stale/double clicks, wanted start/end,
missing player/device, world readiness, death and teardown. Existing shift-entry
tests execute CET's start/end lifecycle. The new safety suite executes the actual
policy, both wrappers, current native partner identity and criminal-termination
rule. Engine damage/threat calls are recording boundaries, not a police simulator.
The full package also retains all existing incident, reward, marker, survey,
arrest, vehicle and readiness checks. Offline source/API compilation runs with
Browser Extension present and absent; it is not a game-cache compile.

In game, check Career End Shift and the new Testing button first. During a
normal vehicle firefight with a partner, passing traffic police should not take
partner stray-hit damage or start the vehicle hit-reaction path. Enemy cars and
suspects should still take partner damage. On a separate manual test save, V's
own criminal hit should still produce the ordinary wanted/shift termination.
The narrow guard does not claim to suppress near-miss gunshot stimuli, indirect
explosions or other mods that rewrite the attacker before the hit callback.
