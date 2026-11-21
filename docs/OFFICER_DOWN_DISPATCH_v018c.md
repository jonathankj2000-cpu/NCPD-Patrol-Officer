# Officer Down dispatch and expandable surveyed sites

The uploaded functional report contains 1,732 events from five runs. Its newest
functional run validated **16 compact sites**. Kryss_13 was unverified because
the central landing lacked a Static ground hit; it is excluded from the initial
dispatch catalogue, not permanently blacklisted. Source report SHA256:
`a8a1ed0fa76dbf3d2309f25145913f51863f420273bd1563c859986398571b3b`.

## Gameplay

The user's selected mix is **45% scanner, 27% VIP, 18% cyberpsycho, 10% Officer
Down**. Selection is weighted without replacement when a type is unavailable.
If the catalogue module/resources are unavailable, the three older types retain
their original relative 50/30/20 availability behavior. All four types share
the existing single-assignment and foreground-cleanup reservation.

For a direct test, start a shift and use **CET → Dispatch → Request Officer Down
dispatch**. Ordinary automatic dispatch and the trunk's existing Request new
dispatch also include the new type. There are no added trunk keys/hotkeys.

Sites are selected 500-1000 m away first, then within 2 km and 5 km if necessary.
Recent sites are avoided when alternatives exist in that band. A failed site
cools down for 120 active on-duty seconds, then becomes eligible again. Outside
City Center/Watson coverage, another incident type can be chosen.

The compact layout is unchanged: one police car, two gang cars, two officers and
five gang members; police/gang lines are 12 m apart and gang cars retain ±5.5 m
offsets. Runtime preparation begins within 250 m. The saved successful heading
is tried first, followed by quarter turns; all ten current spawn positions are
rechecked against actual support, navmesh, geometry and traffic before creation.
Near 180 m, rejected preflight may retry for eight active seconds. No rotation
is attempted after actor creation has begun.

All actors are privately owned/protected while staged. The injured officer is
not teleported back to a prescribed landing point. The other nine actors retain
the pre-arrival position lock. After four active seconds, the same functional
observer as the survey requires ground/clearance, the expected injured state and
a complete walking route to a usable aid position for three active seconds.
Mounted V uses a nearby nav source within 1.5 m of the seat position, avoiding an
unbounded snap to another road level. On arrival within 55 m, ready actors are
released into combat. Failed access is bounded by the observer's 12-second
window and closes the assignment instead of leaving frozen actors indefinitely.

Both the officer's revive and all five suspects being killed/downed/unconscious
or arrested are required. The existing ledger awards **EUR$2000 once and one
generated career incident**. Scanner supplements and arrest payouts stay separate.
Response deadline is five minutes; the active scene allows ten minutes and is
abandoned beyond 300 m. Menus pause active progression as in the prototype.

## Quest markers and lifetime

Each catalogue site owns a distinct quest/objective path and one authored fixed
pin. The original point reuses the original proven journal. The additional
archive contains 15 independent, initially inactive quests/pins; only the chosen
quest is activated. Positions use the established Coyote anchor plus fixed
authored offsets. The existing SceneMarker controller and bank are unchanged;
there is no runtime marker relocation, engine-pin unregister or manual-waypoint
replacement. New marker resources were compiled, round-tripped and extracted
byte-identically; actual game rendering remains a gameplay check.

The selected catalogue index persists only so the correct journal marker can be
closed after loading. The shift/scene does not resume from old actor IDs. Native
created-ID ownership is session scoped. Cancellation/failed setup retain their
foreground reservation until manager entries and captured attached handles have
gone. Native weak handle caching covers a partial spawn followed by an
asynchronous delete and CET reload. Successful aftermath remains for 90 seconds
or until you leave 150 m and does not reserve other assignment types. Another
Officer Down waits for its own previous scene to clear; weighted fallback can
select a different type meanwhile.

## Reliability evidence

`officer_down_dispatch.jsonl` is append-only, separate from the survey log and
all payment/career ledgers. It records catalogue revision, site/run, source,
position/distance, preflight rotations, actual created/bound actor positions,
marker diagnostics, aid access, arrival/revive, terminal outcome and cleanup.
Runtime failures include player position to help distinguish mounted/road-level
issues. A logging error is reported once per distinct error and never cancels
the incident or changes payments.

Use **CET → Diagnostics → Export Officer Down gameplay report** to write
`officer_down_dispatch_report.json`. The summary streams existing raw history
into per-site counters; it does not hold the whole historical event list in
memory. Send both gameplay files after a longer playtest. Counters report
observed events; a hard process crash cannot emit a terminal event retrospectively.
The original fixed-intersection prototype remains a separate legacy test; use
the Dispatch-tab action for normal catalogue gameplay/logging.

## Add locations

1. Append captured candidate positions/headings and coverage to
   `assets/scene_survey/sites.json`. Run `python tools/build_scene_survey_catalog.py`.
2. Build/install a survey test package and use the off-duty **all recorded
   sites** functional survey. Keep/export both survey evidence files.
3. Import a report with currently validated compact functional results:
   `python tools/build_officer_down_sites.py --import-report /path/to/scene_survey_report.json`.
4. Compile/round-trip/extract the updated independent journal archive:
   `python tools/build_officer_down_sites.py --wk-cli /path/to/WolvenKit.CLI`.
5. Run the release checks and ship the complete package; new journal resources
   require a full game restart. A report alone cannot create a new native quest
   marker in a running game.

The checked-in catalogue is the reviewable source of stable indices, quest paths,
approved centers and preferred headings. Import preserves existing indices and
appends new ones. Disable a persistently problematic site with `enabled=false`;
retain its index/path/resource for save cleanup. Re-surveying a location updates
its proven heading without inventing an offset from its observed injured landing.
Raw gameplay logs never automatically add/disable sites or alter baked assets.

## Checks and limits

Portable tests execute the actual generated catalogue, native quest owner,
scene controller, shared aid access and dispatcher. They cover all 16 sites,
all 100 weighted first draws, fallback, automatic resume, dual completion and
one payout, natural shifted landings, mounted access, blocked-ground cooldown,
partial/unmanaged-but-attached cleanup, CET recovery and world-ID invalidation.
Append/export/reload and disk failures are exercised independently of rewards.
The old manual scene and unavailable-catalogue dispatch regressions remain.

Native scripts are source/API compiled with Browser Extension present and absent.
Engine boundaries are mocked in portable tests; combat AI, rendering of the new
pins, long-running spawning and real F/revive behavior need gameplay validation.
All seven earlier archives, marker bank/controller, VIP/ambush, cyberpsycho,
arrest, partner, backup and incident payment/career ledgers remain unchanged.
