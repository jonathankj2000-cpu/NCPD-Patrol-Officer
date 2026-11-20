# VIP route catalogue — v0.17f

VIP assignments could start without a pickup marker because the old selector
accepted live fast-travel **and drop-point** coordinates, while native quest
markers cover a finite catalogue. A reported pickup at
`(-976.574707, -1155.406494, 11.359848)` is **116.713 m** from the nearest
catalogue terminal (site 218, Mission Waterfront). The unchanged 2 m matcher
therefore selects `site=0`. This explains that position's off-catalog path; it
does not prove the separate cause of failed fallback registration/rendering.
The user confirms the assignment starts but the pickup marker is missing.

## Change

The mod now ships **360 pre-generated endpoint pairs across 60 authored
terminal candidates**. `assets/vip/route-sites.json` chooses the existing bank
IDs. `tools/build_vip_route_catalog.py` deterministically produces
`assets/vip/routes.json` and the small `vip_route_catalog.lua` runtime table.
The runtime table contains IDs only. The selector reads XYZ from the **same
`marker_catalog.lua`** used by navigation; it cannot independently generate a
drop-point position absent from the bank. Existing scope 8/9 objectives select
the pickup and delivery pins. No quest archive or journal rebuild is needed.

Generate with `python tools/build_vip_route_catalog.py`; verify checked-in
outputs with `--check`. Inputs/provenance hashes are included in the manifest.
Existing marker IDs, terminal node references and the 2 m tolerance stay fixed.
The script rejects unknown IDs, ambiguous matches, non-terminal sites,
H10 Atrium, apartment terminals and invalid trip lengths.

## Runtime selection

- No requirement for discovered/unlocked/live FT or drop-point markers.
- Read live scanner mappins only to exclude unfinished GangWatch/Outpost
  incidents within 100 m of **either** endpoint.
- Keep the established response tiers: prefer 500–1000 m pickup / 800–2500 m
  trip, then expand to the existing 250–5000 m pickup / 500–5000 m trip caps.
  These are straight-line measurements, not estimated driving routes.
- Randomly choose among eligible routes. Prefer routes outside the last
  12 selections; relax history when the local pool is too small. Failed setup
  attempts also enter this transient history. Nothing enters the career ledger
  until the unchanged native completion/payment checks pass.
- Diagnostics show route, pickup site, delivery site, scanner exclusions,
  nearest clear site, search radius and distances.

The route catalogue reuses one two-stage VIP quest. It does not bake a separate
quest for each pair, create road paths, relocate native markers, award advance
credits or change the 50/30/20 dispatch weights. The actor coordinator, actual
boarding/drop-off validation, ambush, EUR$2000 payout, career accounting,
cancellation, cleanup, world reset and manual waypoint handling are unchanged.
Arrest code remains byte-identical to v0.17e2, which the user reports working.

## Evidence and limits

Portable tests run the real Lua selector and navigation matcher, including an
empty live-terminal pool, the reported position, scanner exclusions at both
endpoints, finite-coordinate guards, history saturation and many player
positions. The actual old selector fails the empty-pool regression; a 120 m
clearance mutant fails the 100 m contract. The current VIP facade runs a full
boarding/delivery/payment/cleanup/new-assignment cycle with baked endpoints.

The native marker suite runs **all 360 pairs** through translated actual native
VIP/marker controllers: positive correct IDs, one active pin, stage switch,
exactly one completion, stale-handle isolation, cleanup and unchanged manual
waypoint. The engine's pin materialization and physical travel remain mocked.
Historical dispatch/actor traces use a pinned pre-change location provider at
the new helper boundary; they validate preserved actor/scheduler behavior,
**not unchanged geography**. The dedicated route tests cover new geography.

Candidate names and catalogue coordinates do not establish physical road
access. Metro terminals, private estates, apartment interiors and indoor H10
are excluded from this authored list, but all 60 candidates still need varied
in-game pickup/parking checks. Existing witness navmesh/path/height checks
remain active and may refuse an inaccessible point. The catalogue is not a
whole-map coverage guarantee. Mods that remove the underlying world node can
still prevent a native pin from resolving.

Fallback registration, marker proof/timers/session gates and all six archives
are unchanged. This change removes VIP's off-catalog endpoint choice; it does
not establish a fix for every fallback or earlier reload crash.

## In-game check

Fully restart after installing the complete v0.17f package. Request VIP via
CET Dispatch at several places, preferably with a manual waypoint already
set. Confirm the pickup marker remains visible, the delivery marker replaces
it only after actual boarding, completion removes it, and another dispatch can
start. If navigation fails, collect **Log VIP diagnostics** (route/sites) and
**Log active dispatch marker diagnostics** (native identity/proof). A site of
zero on a new baked VIP assignment would violate the tested catalogue contract.
