Fixed quest markers r5

This feature replaces dispatch presentation with selection from a finite bank.
R4d proved one native journal-linked Coyote marker with an unchanged manual
waypoint. R4e showed SetMappinPosition left both runtime and quest-log positions
at Coyote. R5 does not relocate pins or introduce moving-target support.

Catalog and resources

assets/fixed_markers/catalog.json contains only identifiers, numeric positions
and exact terminal NodeRefs, with pinned provenance in sources.json. It covers
132 scanner sites (114 GangWatch, 18 Outpost) and 191 terminals. It is not a
claim of complete current-build coverage. Existing location selection, RNG,
radius expansion and scanner exclusion are unchanged. Unknown or shifted sites
stay eligible and get an independent quest-style marker.

build_fixed_marker_assets.py appends bank_<site> JournalQuestMapPin children to
the existing six scanner /resolve objectives, both VIP objectives and both
cyberpsycho objectives. There are 1556 fixed pins. It preserves all original
quest/phase/objective/description content and localization. Terminal pins use
the exact CyberCAT world NodeRef (zero relative offset). Scanner pins have null
NodeRef plus their authored absolute XYZ, using ArchiveXL's static-offset path.
Definitions use active=1, QuestGiverVariant, GPS enabled, no dynamic entity name.
An inactive journal child is activated only for the selected site/objective.

The generated compact journals live in assets/fixed_markers. Original authored
journals stay available as baseline inputs. Build with:
DOTNET_ROOT=<runtime> python tools/build_fixed_marker_assets.py --wk-cli <WolvenKit.CLI>
This replaces the three normal archives with extended resources, preserving
their depot paths and .xl registrations. It round-trips extended AND baseline
journals, removes only bank children for the semantic preservation comparison,
then extracts archives and compares compiled resource bytes exactly.
Use this builder after any edit to original journals/localization; the older
standalone builders produce the earlier journals without the bank.

Runtime ownership

marker_navigation.lua matches the selected runtime coordinate to the relevant
catalog kind within 2 m. Its logical handle contains a generation token, not an
engine mappin ID. Such handles are never passed to UnregisterMappin/SetPosition.
Scanner and cyberpsycho adapters release only their current named owner; VIP
releases only its token. Older cleanup cannot cancel a newer token/owner.
Missing native backend retains the historical compatibility path; the complete
r5 package uses the new backend and never registers CustomPositionVariant.

NCPDPatrolFixedMarkerSystem owns presentation only. It requires exactly one
active known NCPD objective, observes a private bank child, and activates it
through JournalManager.ChangeEntryState. It does not change quest results,
timers, tracked stories, actors, payments or progression. The archived R4d
control used Journal nodes; the direct state call inside actual dispatch
journals is a new engine boundary and must be confirmed in game.

Native confirmation requires one real QuestMappin with the child hash, its
objective link and same ID, runtime and GetQuestMappinPosition readback within
2 m of the selected target, active map-pin state and unchanged manual ID across
activation. Inactive/absent/wrong/multiple pins are not success. Five consecutive
active seconds without proof trigger cleanup before fallback. Menus pause that
timer. Confirmation revokes immediately on a failed observation.

On VIP delivery or cyberpsycho arrival, the old child is deactivated and its
retained presentation removed before the next fixed child is activated. Actor
and reward controllers retain their transitions. Replacements keep old cleanup
owned while queuing the new token. Failed deletion retries and cannot create a
second bank presentation. Root/objective completion, cancellation, off duty and
wanted termination close presentation without modifying the outcome.

Load forgets IDs/tokens and discovers active bank children from current journal
paths, builds their current hashes and removes only those quest pins plus the
private NCPDPatrolFixedMarkerData fallback class. Other mods, manual waypoints,
story markers and the legacy test marker namespace are not cleanup targets.

Fallback

Unmapped sites, missing bank resources or unconfirmed native creation use
QuestStaticMappinDefinition/QuestGiverVariant with NCPDPatrolFixedMarkerData.
This is an independent renderer, not evidence of journal binding or GPS.
It is labeled fallback in status/diagnostics; native confirmed stays false.
Failed/missing fallback registration retries at most once per five active
seconds. It never takes over the manual waypoint. Existing journal completion,
dispatch bonuses and career ledgers continue through their original owners.

Test and limits

Install the complete ZIP and fully restart. Start a shift and use existing
manual dispatch buttons. Record a manual waypoint. After five active seconds,
log CET > Diagnostics > Fixed quest markers. Check native confirmed, pins,
objective link, runtime/quest position, fallback, site/scope and manual IDs.
Verify scanner completion; VIP pickup-to-delivery; cyberpsycho response-to-
neutralize; timeout/cancel/replace; wanted/end shift; load and next assignment.
GPS still needs an actual game check. Do not infer it from icon color.

Automated verification runs actual translated native and Lua production code
with engine boundaries mocked. Native creation is disabled by default: state
activation alone must reach an honest fallback. Positive fixtures separately
exercise exact position/hash/link, duplicate and wrong pins, stage switching,
tokens, foreign data preservation, refused deletion, menu timing and save/load.
Old dispatch/VIP/CET comparisons cover the unavailable-bank compatibility path;
the bank-present path has its own new suite. Narrow source guards preserve
unrelated actor/selection/scheduler/reward behavior. All previously installed
native files remain byte-identical. Offline source/API compile runs with BEF
present and absent, not the real game script cache.

Rollback: end/clear the active assignment and wait for marker cleanup, then
exit and reinstall the complete r4e (or earlier) package, including its three
journal archives. Remove the four new payload files listed in the r5 report
if fully rolling back. Use a pre-test save to discard added journal presentation
state. Reward/progression receipts are never migrated by this feature.
