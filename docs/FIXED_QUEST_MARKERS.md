Fixed quest markers r5a

R5 failed in game: VIP/cyberpsycho exposed the terminal pool, and scanner
selection found a catalog entry without producing a linked native pin.
The supplied scanner log also retained an old runtime position. Evidence is
recorded in assets/fixed_markers/r5-game-evidence.json. R5a changes the journal
layout and activation boundary; its game rendering remains unverified.

Layout and activation

The catalog still contains 132 scanner sites (114 GangWatch, 18 Outpost) and
191 named world terminals. Pinned provenance and licensing are unchanged.
Existing location selection, dispatch mix, radius expansion, RNG order and
scanner exclusions stay with their existing owners. Unknown/shifted sites
receive an independent quest-style fallback without replacing a manual pin.

Each existing quest phase now contains private site objectives named, for
example, resolve_bank_42, pickup_bank_204 or deliver_bank_205. Every such
objective contains its original briefing and exactly ONE map pin, location.
Original common objectives remain intact for fallback. There are 1556 private
objectives/pins across six scanner briefings and the two stages of VIP and
cyberpsycho. There is no additional quest root or moving-target support.

All authored map-pin definitions start INACTIVE. Journal map-pin entry state is
not used as a visibility control: game quest-log code includes map-pin children
regardless of ordinary journal-entry state and resolves the first declared pin.
That invalidated r5's model of many sibling pins under one active objective.

NCPDPatrolFixedMarkerSystem (interface 2) asks the original native quest owner
to select its site objective. The switch hides the previous objective, selects
one new objective and briefing, and moves tracking only when the previous
NCPD objective was tracked. A newer story choice is respected. Rejected writes
restore the previous objective; fallback recovers the original common path.

The bank requests questMappinManagerNodeDefinition Active/Inactive explicitly
through Codeware QuestsSystem.ExecuteNode, with a typed Uint16 node ID,
gameJournalPath.fileEntryIndex=1 and disablePreviousMappins=false. It never
uses global marker disabling. Calling the node is not confirmation.

Terminal pins retain their named world NodeRef and zero relative offset.
Scanner pins use fixed authored offsets relative to #coyote_performance_test,
the anchor confirmed by the user's r4d test. The null-NodeRef absolute-position
path from r5 is removed. No runtime pin movement is requested.

Proof and cleanup

Native confirmation requires exactly one active private bank pin overall,
exactly one selected native QuestMappin, no other retained private pins, correct
selected-objective hash/ID link, and runtime AND quest-log position within 2 m
of the actual dispatch target. Manual waypoint ID must remain unchanged across
activation. Evidence/positions are cleared before each new observation and on
fallback/closure; missing pins cannot inherit another site's coordinates.

Other private bank pins are pruned on a bounded poll, including while idle.
Save/load rediscovers current hashes rather than trusting old handles. Cleanup
recognizes both new site paths and legacy r5 paths, so cached pool markers can
be removed after upgrading. Fallback data has its own private script class.
Foreign, story, manual and legacy Coyote experiment markers are not owned by
this cleanup. A replacement or fallback waits for owned registry removal;
refused deletion retries before another presentation is created.

Five consecutive active seconds without proof trigger native cleanup and
common-objective recovery before an independent fallback. Menus pause the
timer. Fallback is explicitly reported as native confirmed=false; its visual
presence does not prove journal binding or GPS. Lost/failed fallback rendering
retries at most once per five active seconds.

Original gameplay ownership

Scanner, VIP and cyberpsycho native owners gain transient site fields and
objective-path helpers. Their original attendance, timer, boarding, target,
result, reward and progression methods are preserved. Only the selected path
flows through those methods. Source guards compare these methods to r5, and
the bank-present suite executes the actual owner transitions and rewards.

marker_navigation.lua still returns logical generation tokens, never engine
IDs. Stale scanner/cyberpsycho cleanup cannot stop a newer owner; VIP releases
its own token. The compatibility path for an unavailable bank is retained for
the historical comparison fixtures. A complete r5a install uses interface 2.

Building and verification

DOTNET_ROOT=<runtime> python tools/build_fixed_marker_assets.py --wk-cli <WolvenKit.CLI>

The builder extends the original authored journal inputs, round-trips both
baseline and extended resources, removes only added site objectives for the
semantic comparison, and extracts each archive to compare compiled bytes.
The three installed archive paths and their .xl registration files are retained.
Use this builder after journal/localization changes; standalone older builders
produce journals without the site bank.

18 portable suites cover existing dispatch/VIP/CET comparisons plus explicit
bank-present tests. The latter execute production native/Lua code with engine
boundaries mocked. No-pin creation is the default. The positive fixture models
the FIRST DECLARED child behavior and explicit MappinManager activation; it
does not turn a map-pin journal state write into a successful engine spawn.
Checks cover one-pin layout, inactive definitions, scanner site 42 in all six
briefings, selection rollback, duplicate/wrong pins, legacy/flood cleanup,
actual VIP/CP stage changes and success, scanner timeout/payment/reuse, story
tracking, manual waypoints, stale tokens, load and refused deletion.
Offline source/API compilation runs with Browser Extension present and absent;
it is not the actual installed game script cache.

In-game check

Install the complete r5a ZIP and restart the game. Start a shift, set a manual
waypoint and use the existing scanner/VIP/cyberpsycho request controls. After
five unpaused gameplay seconds use:
CET > Diagnostics > Fixed quest markers > Log active dispatch marker diagnostics

Expected native proof: native confirmed=true, native pins=1, active bank pins=1,
other bank pins=0, target active=true, objective link=true, both positions OK,
fallback=false. Confirm only the chosen location is visible. Check scanner
completion/next dispatch, VIP pickup-to-delivery, cyberpsycho arrival/completion,
cancel/replace, wanted/end shift and load. GPS still requires a game check.

The separate Testing > Legacy Coyote marker experiment controls are the r4d
static / r4e relocation experiments, not active dispatch diagnostics. Their
archived resources remain byte-identical. R4d static passed in game; r4e
relocation failed. Neither result proves r5a activation works in game.

Rollback uses the entire earlier package including its three journal archives.
Use a pre-test save to discard added journal presentation state. Reward and
progression receipts are not migrated by this feature.
