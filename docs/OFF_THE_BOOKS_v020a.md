# Off the Books — v0.20a test

The existing SMS and ten-turn Voss briefing now lead to a separate off-duty
assassination/evidence quest. This slice ends when V returns to Voss. It does
not invent the second conversation, final payment or automatic milestone gate.

## Encounter and evidence

The contractor stands at `-649.795, 929.771, 9.400`, yaw `-170.762`. Two elite
guards use the supplied positions and yaws. All three spawn within 140 m during
the eliminate/retrieve stages, after ground, slope, obstruction and nav checks.
Each role has a private record/tag and a saved creation receipt. Previously
created roles are recovered or re-enabled at the same managed ID, never
replaced simply because an entity reference is temporarily unavailable.

Verified upstream records are documented with pinned sources in
[records.json](../assets/off_the_books/records.json):

- `Character.CorpoManArasaka`, male corporate appearance
  `citizen__arasaka_corpo_ma_corporate_01_1`.
- `Character.arasaka_cyborg_franged3_shingen_ma_elite` for both elite guards.
- `Items.generic_arasaka_family_backstory_shard` and `ItemAction.Read`.

Runtime typed checks confirm those bases, all private records and the exact
private Read action/journal path before assignment. Source verification does
not establish that the installed game has those records; a missing record
rejects the test with a useful status instead of partially assigning it.

Private NPCs start neutral and receive scoped native hold-position commands.
A hit on an owned actor releases those holds and explicitly makes both guards
hostile to, and aware of, the actual aggressor. Native hit/crime handling runs
first, exactly once; no immunity or global faction relationship is installed.

The real item `Items.NCPDPatrol_VossEvidence01` is seeded once into the target's
native inventory with quantity readback. It inherits the vanilla shard assets
and uses its own localized title, contents and readable journal entry. Looting
a `Gen_Readable` normally removes its inventory instance and activates Shards.
The exact native acquisition event, after vanilla processing, records a saved
receipt. Persistent inventory quantity is therefore not the completion test.
Failure to seed the contractor never compensates by granting an item to V.

## Objectives and persistence

1. Eliminate the Arasaka contractor: actual death, not incapacitation.
2. Retrieve the encrypted data shard: death without acquisition stays here.
3. Lose the NCPD: active only while wanted after securing the evidence.
4. Return to Lieutenant Mara Voss: same original meeting and Hella.

Each spatial objective has its own fixed journal marker; escape has no spatial
pin. Only these private pins are activated/deactivated. Manual waypoints are
untouched. Native facts record stage, cycle, created roles, death, evidence and
return arrival. Persistent Codeware specs retain encounter spawn/state. Lua
world resets discard transient handles rather than cancelling the operation.
An on-duty reset/wanted termination does not own this quest. Starting a shift
is blocked through eliminate/retrieve/escape; ordinary patrol is available
again while the future Voss debrief is pending. Return arrival is off-duty.

Voss/car remain after the first briefing and recover by their current-world
tags. They are re-enabled if streamed out. Their pose helper is restored at
Voss's actual position without replaying dialogue. Cosmetic pose failure does
not cancel the story or remove the pair. Explicit full clearing still releases
the pose device before deleting the actors after native scene release.

## Game test

Use a test save; install the complete **129-file** ZIP and restart the game.
Keep the existing dependencies. Browser Extension remains optional.

1. Go **OFF DUTY**. CET → Testing → Quest giver prototype →
   **TEST: Activate quest giver quest**. Read the SMS, meet Voss, and let the
   existing conversation finish. Check Voss and her Hella remain.
2. If this save already completed that conversation, use
   **TEST: Continue Off the Books after briefing**. Repeated clicks should
   report an active operation, without duplicating actors.
3. Follow the target objective. Check a standing male contractor and two elite
   guards at the restaurant, initially neutral. Test target or guard attack:
   both guards should defend. Normal police/civilian reactions should remain.
4. Incapacitate first if desired: the eliminate objective must stay active.
   Killing must switch to retrieve; killing alone must not give the evidence.
5. Loot the target through the normal loot UI. Open Shards and read
   **ARASAKA INTERNAL — TRANSFER AUTHORIZATION**. Check its supplied text and
   that the loot cannot be repeatedly collected for progression/rewards.
6. If wanted, lose the NCPD before the return objective activates. With no
   wanted level, escape should be skipped. A later pursuit reactivates escape.
7. Return to Voss. She and her car should still be available, with no replay
   of the first conversation. The return objective remains for the next debrief
   implementation; this release does not finish/pay the whole story quest.
8. Save/load at eliminate, retrieve, escape and return. Leave/re-enter the
   restaurant. Check stages, sharded evidence and death persist, actors do not
   duplicate or resurrect, and each active pin remains at the right location.
9. To repeat without listening again, **Clear Off the Books encounter only**,
   wait for cleanup, then **Continue Off the Books after briefing**. Full
   **Clear quest giver test** cancels both slices and removes their actors.

**Log Off the Books diagnostics** reports stage, cycle, death, evidence, seed,
wanted state, marker proof, managed roles and cleanup. Clearing retains native
Shards history. No new career, scanner, dispatch or arrest rewards are issued.

## Validation limits

The separate journal/shard archive compiles and round-trips with WolvenKit;
extraction matches its authored resource bytes. All nine existing archives,
first-scene media/caption timing, 54 Officer Down sites and payment systems are
unchanged. Forty portable suites execute controllers, native observers, the
original authored conversation and marker helpers against recording engine
boundaries. REDscript source/API checks run with BEF present and absent.

These checks do not emulate real combat AI, engine save serialization, native
loot UI, root motion or marker rendering. Those require the game test above.
Andrea Olivato's MIT readable-folder adaptation is credited in
[THIRD_PARTY_NOTICES.txt](../THIRD_PARTY_NOTICES.txt).
