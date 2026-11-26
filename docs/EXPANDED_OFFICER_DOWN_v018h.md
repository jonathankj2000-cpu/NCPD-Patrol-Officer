# v0.18h: import approved Officer Down discoveries

The user approved integrating the successful entries from the supplied discovery
report into production dispatch. This release appends **38 compact sites** to
the original 16, giving **54 enabled Officer Down sites**. The 38 standard
variants are retained as survey evidence rather than creating duplicate production
assignments at each anchor. The production scene continues to use compact layout.

## Imported coverage

| District | Added compact sites |
|---|---:|
| City Center | 6 |
| Heywood | 10 |
| Pacifica | 2 |
| Santo Domingo | 14 |
| Watson | 6 |
| Total | 38 |

The original 16 entries are preserved verbatim, including indices 1-16, stable
IDs, quest roots, positions, successful headings and enabled states. New entries
append at 17-54. None is within 30 m of an original site or another imported
site in this report. The import also enforces a 5 m horizontal/same-level
proximity deduplication rule. Another elevation is treated separately.

No unverified entry is inferred from the incomplete tour. Grand Imperial Mall,
Woodhaven Street, interrupted Allen Street and the untested remainder are not
added. All imported sites have cleanup-confirmed functional proof, regardless
of the later interruption of the overall developer tour.

## Source and validation

`assets/officer_down_sites/discovery_import.json` contains the accepted compact
proofs and source metadata once, excluding rejected-attempt history and raw
motion logs. Each entry retains the original full report's SHA256, original
catalogue/layout revisions, timestamp, actual grounded coordinates, heading,
source terminal identity/offset and ten-actor/aid-access evidence.

`tools/build_officer_down_sites.py --import-discovery-report /path/to/scene_discovery_report.json`
checks the known 60-anchor source, original nominal offset, bounded same-level
grounding, exact candidate/proven-result match, compact/profile/revision,
finite coordinates/headings, all ten actor kinds, three-second observation and
readiness, supported/clear injured body, complete walking route, aid range,
scene radius, no claimed revive execution and physical cleanup. A valid navmesh
point alone cannot approve a site. Import planning validates all entries before
writing; repeated imports preserve stable indices and disabled states.

Accepted evidence is merged by site ID so future partial reports do not discard
existing provenance. The older recorded-site report importer also preserves
expanded district coverage. Neither live gameplay logs nor discovery runs
silently mutate the production catalogue.

## Fixed markers

The generated Lua/native catalogues and independent journal archive use the
actual approved scene center and successful compact heading. A new site gets a
distinct quest/objective path and fixed authored pin. The 15 old journal quest
chunks, including handles and offsets, remain exactly equal. The expanded
archive contains those 15 plus 38 new inactive quest/pin chunks. The original
legacy quest/pin remains in its unchanged original archive.

Only the selected journal quest is activated through the existing native marker
controller. There is no relocated pin, global marker-bank change, custom manual
waypoint or new simultaneous assignment. The selected index and root remain
stable for loading/cleanup. The original seven other archives are byte-identical.
The expanded journal was compiled with WolvenKit, serialized back for contract
validation, packed, extracted and compared byte-for-byte with the compiled resource.

To rebuild the marker archive after a reviewed import:

```bash
python tools/build_officer_down_sites.py --wk-cli /path/to/WolvenKit.CLI
```

A full game restart is required after installing the generated native catalogue
and marker resource. Updating a JSON report alone cannot add runtime quest pins.

## Runtime behavior and testing

The dispatch scheduler, nearest search bands, recent-site avoidance, cooldown,
spawn layout/records, runtime geometry/traffic rechecks, staged protection,
50 m mounted activation, combat, revive, dual completion conditions, payout,
career credit and cleanup code remain byte-identical to v0.18g1. Automatic mix
remains 45% scanner, 27% VIP, 18% cyberpsycho and 10% Officer Down. Failure to find
a usable Officer Down site still allows another incident type to be selected.

Install the complete package and fully restart. Go on duty and use **CET >
Dispatch > Request Officer Down dispatch**, or the existing test dispatch action.
Automatic dispatch and the existing trunk action use the same expanded catalogue.
The exact location is chosen from the closest available 500-1000 m / 2 km / 5 km
search band, so travel through the added districts to exercise their locations.

Keep both gameplay evidence files, `officer_down_dispatch.jsonl` and
`officer_down_dispatch_report.json`. Existing logging automatically includes the
new IDs/catalogue revision, placements, marker state, arrival/revive, terminal
outcome and cleanup. Export through the existing Diagnostics action after testing.
Survey/discovery logs, recorded candidate sites and formats remain unchanged.

31 portable suites execute every one of the 54 targets through one active fixed
pin, ten-actor spawning, combat/revive, both completion conditions, EUR$2000 exactly
once, one career credit and physical cleanup, preserving the manual waypoint.
Additional controls validate evidence rejection, idempotence, old-entry/quest
identity, same-level deduplication and CET/save cleanup of the final index.
All 44 native files pass offline source/API checks with Browser Extension present
and absent; 43 native files are unchanged, and the changed file is generated data.

The user's source report provides actual in-game off-duty placement evidence.
Portable engine boundaries remain mocked. New fixed-marker rendering and live
dispatch combat/revive/long-session reliability still need normal gameplay tests.
