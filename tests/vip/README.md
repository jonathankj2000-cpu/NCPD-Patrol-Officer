# VIP transport and tyre regression checks

Run `python tests/vip/check_vip.py` with Python 3 and lupa. The release builder
runs this and all six existing arrest/trunk/scanner/career/cyberpsycho suites.

The authored redscript quest runs through the existing syntax adapter, with
only game APIs mocked. The actual VIP, ambush, shared officer AI and dispatcher
Lua modules also execute. Coverage includes distinct pickup/delivery activation,
no early destination reveal or near-player spawn, exact private NPC identity,
actual boarding in the same owned police car as the player DRIVER, occupied
partner/driver seats, missing/free seats, live actual exit at destination,
death/non-lethal failure, abandonment, missing actors, lost car, timers/menus,
tracking restoration, stale tokens, save reconciliation, no duplicate requests,
rejected/deferred deletes, partial creation, shift end, shutdown and scanner/
cyberpsycho exclusion. No money or career total is written by these incidents.

Ambush cases exercise queued manual testing with no road history, actual driven
position history behind the car, seating proof before chase, the native chase
command/event/init sequence, three stopped seconds, braking and stationary proof
before animated exit, actual exit before combat, escape, one encounter per trip,
completion without killing attackers and cleanup of only owned entities.

`tests/trunk_menu/check_trunk.py` executes the authored repair wrapper and new
callbacks: body/health routines, wheel reset order, bounded delayed work,
mount/unmount physics reset, fresh puncture invalidating queued repairs, and a
second service for new damage. Native wheel physics itself is a boundary.

`check_native.py` optionally uses the established local `ncpd-check` tool and
source-derived game/BEF contracts in sibling work directories. Its additional
declarations are in `tests/career/contracts/vip-vehicle.reds`; they are merged
into offline native stubs. It checks all 24 scripts with and without BEF. This
is not compilation against the actual Cyberpunk 2.5 cache. CI instead runs the
portable authored-code tests and parses all 15 Lua modules.

`tools/build_vip_assets.py` compiles both journal/localization resources with
WolvenKit 9.1.1, round-trips them, packs and extracts the archive, then verifies
exact extracted bytes. Resource SHA256 values are recorded separately from the
archive container, whose timestamps vary between builds. The full 56-file ZIP
includes all existing archives, Lua and redscript; the builder checks unchanged
production files against v0.13b before packaging.

## Primary references

Record definitions were checked at Cyberpunk-Tweaks commit
[`0f39f780c92ca389f97fc19cb5ba3c10ba32dd7d`](https://github.com/CDPR-Modding-Documentation/Cyberpunk-Tweaks/tree/0f39f780c92ca389f97fc19cb5ba3c10ba32dd7d):

- `characters/npcs/records/quest/minor_activities/ma_wat_lch.tweak`:
  `ma_wat_lch_03_garbage_man` uses a municipal full-NPC service template and civilian affiliation.
- `characters/npcs/records/gameplay/factions/maelstrom.tweak`:
  `maelstrom_grunt1_ranged1_lexington_ma` is a full armed ganger. Its name does
  not guarantee a Lexington; its own equipment pool is inherited unchanged.
- `vehicles/cars/v_standard2_archer_hella.tweak`:
  `v_standard2_archer_hella` uses the basic Hella template. The private clone
  clears `randomPassengers`; this module creates its own two crew members.

Game script/API evidence is in [MOD_Development_Reference](https://github.com/In-Question/MOD_Development_Reference):
`core/gameplay/vehicles.swift` supplies global `GetMountedVehicle`, speed and
braking APIs; `core/components/scriptComponents/vehicleComponent.swift` supplies
seat occupancy, mounting callbacks, `GetPS`, repair and the flat-tyre check;
`core/systems/dynamicSpawnSystem.swift` supplies chase command/event/SetInitCmd
and hostile attitude setup. `orphans.swift` and mounting definitions supply
`MountingInfo.slotId.id`, native `ToggleBrokenTire`/`GetFlatTireIndex`, tyre events
and delayed entity events. Existing working partner/backup code supplies the
animated mount/unmount pattern. No API name was inferred from the UI wording.

Live car access at anchors, traffic collisions, vehicle chase/pathfinding,
body/wheel visual persistence, animations and journal rendering require an
in-game test. The offline checks do not simulate these engine systems.
