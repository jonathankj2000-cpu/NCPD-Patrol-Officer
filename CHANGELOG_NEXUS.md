# Changes since Nexus version 0.8.1

Current development package: **0.17c**. Baseline: the published
[NCPD Patrol Officer 0.8.1 page](https://www.nexusmods.com/cyberpunk2077/mods/38800?tab=description).
The career portal, original equipment milestones and first patrol trunk menu
were already included in that release.

- **Mixed automatic dispatch:** calls now draw from 50% scanner assignments,
  30% VIP transports and 20% cyberpsycho incidents. Normal manual requests and
  the trunk's Request new dispatch action use the same mix. An unavailable type
  falls back to another, with a short retry when none can be assigned. Each type
  retains its own CET test button.
- **Post-VIP standby fix:** the next-call timer runs during completed scene
  cleanup instead of waiting for body retention first. Neutralized ambush scenes
  clean independently, so refused despawn cannot lock every new dispatch. IDs
  remain tracked in a queue bounded to three convoy scenes; a full queue skips
  new VIP calls while allowing scanner/cyberpsycho fallback. Live attackers and
  undelivered VIPs retain their cleanup reservation. CET shows the scheduler gate,
  remaining ambush retention time and pending deletion count.
- **Cyberpsycho incidents:** added dispatches to distant scenes, with arrival
  and neutralization journal objectives. The pool contains 17 private variants
  based on the game's cyberpsychos. Lethal and non-lethal outcomes complete the
  assignment. Distant spawning, vehicle requests, repeat calls and retained-scene
  cleanup have received additional checks.
- **VIP transport:** added a two-stage witness escort. Reach the pickup in an
  owned police car with a free seat; the destination appears after actual
  boarding. Complete delivery by stopping and allowing the living passenger to
  exit. Routes prefer nearby terminals, include drop-point alternatives and
  expand their search when the local pool is sparse. Distant pickups receive
  additional response time.
- **VIP waypoint recovery:** checks the registered pickup/delivery marker,
  restores missing/inactive/displaced pins and removes only its own cached ID.
  Recovery preserves the running quest. CET includes detailed marker diagnostics
  and an explicit Rebuild VIP waypoint control. Renderer/GPS limits still need
  in-game validation.
- **VIP ambushes:** transports can attract one to three attacker cars, with two
  gang members per car. Cars use recently driven road positions and checks for
  ground support, barriers, camera visibility and spacing. Each car has separate
  crew, pursuit, exit and cleanup handling. Attackers can be escaped; eliminating
  them is not required for delivery. Unsafe extra cars are skipped. CET offers
  random or fixed convoy sizes for testing.
- **Dispatch rewards and career credit:** successful VIP delivery pays a flat
  **€$2,000**. Cyberpsycho completion pays **€$3,000**, with **€$500 extra** for
  non-lethal neutralization. Both record one NCPD Career incident. Completion
  and payment history are saved separately from scanner/arrest records, with
  duplicate protection, failed-payment retries and payment notices. Existing
  career progress, equipment claims, scanner bonuses and €$250 arrest payments
  are preserved.
- **M2038 NCPD Bean Bagger:** added a Tier 2 less-lethal shotgun for V as an
  additional 20-incident reward, plus a separate CET test button. It has a custom
  name, description, inventory icon and blue pistol-grip/pump appearance. Its
  hit handling protects living downed human targets from further damage. Original
  weapon geometry, rig and animation are retained.
- **Partner and backup:** improved follow-command refresh, passenger boarding
  requests and matching V's drawn/holstered weapon state while retaining combat
  priority. Added **10-4: Release backup**, allowing the patrol to remain at the
  scene until ordinary distance cleanup instead of continuing to follow V.
- **Patrol menu and repairs:** replaced the overflowing horizontal choices with
  a two-row menu, numeric/numpad choices and mouse support. Native R tap/hold
  handling and stash restoration have been corrected. Vehicle repair now also
  restores punctured tyres.
- **Arrest improvements:** added recovery/placement handling for living ragdoll
  suspects, nearby supported-ground selection and native workspot alignment.
  Native R body pickup is preserved before arrest and after a failed attempt.
  Unsuitable placement gives a short instruction instead of a Lua error in the
  notification; detailed diagnostics remain in CET. Brief placement retries
  help with transient navigation after carrying/dropping a suspect.
- **Compatibility and validation:** corrected the reported redscript Boolean,
  popup import and trunk-interface problems. Added broader regression coverage
  for quest outcomes, saved payments, equipment handling and cleanup.

## Updating and current limits

Install the **complete package** and restart the game. Browser Extension
Framework remains optional for the computer portal; CET career controls remain
available. The new incident script is required for generated dispatch rewards.

Active generated assignments close on save reload; earned career/payment
history and pending earned payments persist. Older prototype VIP/CP wins cannot
be backfilled because they did not store completion records. Some road/scene
locations can remain unsuitable. The GPS line may still require opening and
closing the map. Live traffic, placement and animation need in-game testing.
