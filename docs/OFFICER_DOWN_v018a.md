# Officer Down — v0.18a manual prototype

The fixed test scene uses the user's CET capture:
`TEST_KRYSS_01: (-490.911377, -173.816315, 7.887070)`.

The encounter contains one police Hella, an injured officer behind it, one
armed defending officer, two opposing Hella cars and five Maelstrom gunmen.
Relative positions rotate together around the fixed marker. The coordinate
capture contains no street orientation; heading zero is an initial authoring
choice, not a claim that this layout is road-tested. CET can rotate the next
scene by 90 degrees after the existing scene is cleared.

## Flow and boundaries

1. On duty, manually request the scene from 100–5000 m away. The automatic
   50% scanner / 30% VIP / 20% cyberpsycho mix stays unchanged.
2. A private one-objective journal quest activates one baked native marker at
   the exact fixed point. It uses the established Coyote reference plus a fixed
   authored offset. It does not register, move or track a custom waypoint.
3. Within 180 m, validate the entire layout's ground level, car footprints,
   static clearance and nearby NPC navmesh before creating any entity.
4. Create private nonpersistent actors/cars. Verify actual attachment and
   record identity. Apply staging invulnerability, hold NPC AI and correct
   positional drift until arrival. Neutral attitudes delay the firefight.
5. At 55 m, once all ten entities are ready/protected, stop hold commands,
   release staging position locks/protection and inject combat threats between
   the gunmen, defending officer and V. The injured officer remains protected.
6. Use F on the injured officer, or the nearby CET fallback. Treatment needs
   three active seconds within 2.5 m on foot. Menus pause it; leaving range
   interrupts it. A reversible private DefeatedWithRecover status is removed,
   health is restored and actual life/high-level state/health readback must
   confirm recovery. No main-partner registration or follower slot is reused.
7. Completion requires both actual recovery and all five suspects dead,
   defeated, unconscious or registered arrested, observed for one second.
   Missing/detached NPCs cannot count as neutralized.
8. The existing incident ledger awards EUR$2000 and one generated career
   incident exactly once. Its existing persistent FIFO payment retry/receipt
   mechanism handles a temporarily rejected payment. Scanner/arrest and
   earlier VIP/cyberpsycho amounts are unchanged.
9. Successful aftermath can remain for 90 seconds or until V leaves 150 m.
   It does not reserve another dispatch. Failed or cancelled partial deletion
   keeps a reservation until Codeware confirms every owned ID is unmanaged.

Response has a five-minute deadline; the active rescue has ten minutes.
Losing the injured officer, abandoning the active scene beyond 300 m, expiry,
ending duty or criminal activity closes the assignment. The uninjured officer
can be killed after staging protection is released.

## Ownership and compatibility

- Existing six archives, fixed-bank controller/catalogue/diagnostics, VIP route
  catalogue, partner, arrest and backup code stay byte-identical to v0.17f.
- The new marker helper owns one exact private journal path/hash. It observes
  native identity, objective association, runtime/journal positions and manual
  ID preservation before claiming confirmation. Activation alone is not proof.
  Engine-owned cached native pins are deactivated/reused, never unregistered.
- Session readiness gates scene and marker work. A changed session generation
  forgets old Lua handles before deletion can touch reused IDs. Native cancel
  and fail also refuse mutations while the world is unready.
- Only Codeware IDs created by this scene are deleted. The normal partner's
  registration, recovery state and god-mode sources are untouched. Protection
  removes only this scene's private god-mode source.
- The injury interaction wrappers target the exact registered injured actor;
  ordinary bodies, other cops and the player's partner use existing behavior.
- Browser Extension stays optional. No additional plugin is required.

## Validation and game test

The portable suite executes the actual Lua coordinator/layout, translated
native quest/aid/marker and incident ledger. Cases cover staging, arrival,
protection release, positional correction, dual completion in either order,
interruption/recovery/health checks, lethal/non-lethal/arrest outcomes, pending
payment and receipt, partial/failed/deferred cleanup, missing actors, session
change, native false-success rejection, dispatcher reservation/aftermath and
five routed CET controls. Scene-marker hash is checked against every existing
private-bank ownership hash. Existing historical behavior comparisons retain
all original public routes; the six reviewed additive scene API methods are
checked separately.

The private journal/localization archive is compiled with WolvenKit 9.1.1,
round-tripped, packed, extracted and compared byte for byte. The local offline
REDscript source/API compiler checks all scripts with optional Browser Extension
present and absent. These checks do not replace the game's actual script cache,
rendering, physics, animation or AI.

Install the entire 99-file package and fully restart. Use **CET → Testing →
Officer Down prototype → TEST: Request Officer Down** while 100–5000 m away.
Approach, observe the marker and firefight, use F to revive, neutralize the
suspects, then verify the receipt and next dispatch. Repeat after cancellation
and loading. Use **Clear Officer Down scene** before changing orientation or
quickly replaying this same site. If geometry checks reject the scene or the
street alignment is wrong, rotate and retry; actor positions may need actual
in-game calibration. **Log Officer Down diagnostics** records heading, owned
actor count and native quest/aid/marker state.

Physical layout, traffic collisions, AI combat/cover, F interaction, recovery
animation and actual marker rendering remain in-game validation tasks.

## v0.18a1: manual test locator

**CET → Testing → Officer Down prototype → TEST: Waypoint to Officer Down
intersection** places a normal custom waypoint at the shared scene coordinate.
It works off duty, only registers on the explicit button click, and starts no
quest or actors. The action may replace the player's current manual waypoint.
Repeated clicks detect an existing active custom marker at that location.
Change/remove it on the world map; GPS may require opening/closing the map.

This handler is local to the CET testing panel. Every native script, archive,
gameplay module, dispatcher and existing quest/waypoint controller remains
byte-identical to v0.18a. Normal dispatch preserves the manual waypoint; the
new locator is an explicit user-requested map action.

## v0.18a2: typed ground queries and probe coverage

The first live attempt exposed a native boundary mismatch: a raycast returns
`SpatialQueryResult.position` as `Vector3`, whereas
`FindPointInSphereForCharacter` requires a `Vector4` center. The layout now
constructs a `Vector4` explicitly before querying character navigation. The
original test fixture incorrectly returned a `Vector4` hit position; it now
returns `Vector3` and rejects incorrectly typed native arguments. Executing the
exact v0.18a1 layout against this fixture reproduces the reported type error.

The ground ray now spans +1.5 to -1.5 m around the authored height. The old ray
started only 0.7 m above it, leaving part of the already accepted +1.3 m uphill
range unsearchable. A separate negative control changes only the old type
conversion and confirms that it still misses valid +1.1 m ground. The current
helper accepts supported ground across all four rotations, including +/-1.1 m.

Height +/-1.3 m, minimum surface-normal Z 0.85, maximum vehicle corner delta
0.4 m, clearance and navmesh requirements are unchanged. Unsupported geometry
still refuses the whole layout before any actor creation. Errors distinguish
missed/invalid hits, slope, height and vehicle footprint failures, with the
heading and probe coordinate for support failures. The exact cause of the
original police-ground rejection remains unconfirmed: its old message combined
all those conditions. No claim is made that the physical scene is calibrated.

This patch changes only the layout helper and CET build labels in the installed
runtime. All 40 native scripts, seven archives, quest/waypoint controllers,
scene actors, combat/revive behavior and payment logic remain byte-identical to
v0.18a1. Install the complete package, fully restart, and first retry the same
90-degree rotation that previously reached character navigation. If support is
still rejected, the full new line identifies which check needs investigation.
