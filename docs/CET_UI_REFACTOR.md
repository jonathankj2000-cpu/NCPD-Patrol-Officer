# CET interface refactor r2

Builds on dispatch refactor r1 (`3c20841bba35d69289e5f70784b3202a5fbf8881`)
on `git-checkout--b-refactor/cleanup`. This is a complete branch test package.

## Menu organization

| Tab | Contents |
| --- | --- |
| Patrol | Partner state, spawn/replace/dismiss/revive, backup and 10-4. Vehicle/uniform and arrest help expand when needed. |
| Dispatch | Current assignment, next-call status, completion counts, request/cancel and automatic-call toggle. Rules/payments are collapsible. |
| Career | Rank, incident count, progress bar, next reward, claims, Cop Stats, optional computer browser and partner selection. |
| Settings | Dispatch audio, vehicle chatter, ambush car preference and binding help. |
| Diagnostics | Grouped dispatch/journal/navigation, officer AI, scanner/radio, career and equipment logs. Includes VIP marker recovery. |
| Testing | Session milestone override and clearing, typed incidents, timeout, ambush, partner downing, weapon grants and audio previews. |

Duty/availability and their controls remain above the tabs. The latest action's
status is in a separate footer. Each tab scrolls independently; long diagnostic
text cannot push the header/footer out of its content area. The footer reservation
scales with text line height, and its own text can scroll if the message is long.
The window defaults to 660 x 620 on first use, can be resized, and has a stable
ImGui window ID for future title updates. Native tab-bar fitting handles tabs.
Active milestone test overrides show a warning across all tabs. A failing panel
keeps its ImGui scopes balanced, reports the error once, and leaves other tabs
available.

All 52 existing controls remain available. Only their grouping and help text
change. The normal Patrol view has six feature actions plus the two fixed header
controls, instead of mixing all features, logs and tests into one long page.

## Code ownership

`cet_ui.lua` owns rendering and forwards actions to the existing owners. It
registers no game callbacks or hotkeys and has no update loop. `init.lua` supplies
module references, existing action callbacks and **live getters** for duty and
last status. It keeps shift/session state, start/end, native interface checks,
save/load handling, bonus polling, controller update order and shutdown.

The full pre-draw portion of `init.lua` must match r1 byte for byte after two
build-label replacements. The UI does not capture an initial duty boolean or
cache a native handle across frames/world loads. Different menu instances bind
to the entrypoint that created them.

The 20 other existing Lua modules remain unchanged. The extracted dispatch modules, mission/cleanup behavior, partner,
backup, arrests, vehicle repair, radio, all 28 native scripts, persistent records,
localization, tweaks and archives are identical to r1. Browser Extension remains
optional. Reapply an optional Chinese preview overlay after a full installation,
as with previous full packages.

## Verification

`python tools/build_cet_ui_refactor_release.py` with `lupa==2.6` runs all 14
existing suites plus the new CET UI suite, parses 22 Lua modules, guards unrelated
payload hashes, then builds/verifies the complete 70-file ZIP.

The new suite materializes the previous actual `init.lua` from the pinned commit.
Both entrypoints run against the same native/controller boundaries. It discovers
every old/new button and compares 156 action routes across off-duty, on-duty and
enabled-toggle states. This exercises the real callback bodies; a deliberately
misrouted mixed dispatch must be detected. Existing career tests continue to
execute actual native claim/test/partner logic through the moved buttons.

Additional checks cover one active tab at a time, closed headers, collapsed
windows, clipped child regions, balanced ImGui Begin/End calls, footer scaling at
four line heights, live duty/status, test-warning changes, repair countdown,
progress limits and absent native modules/optional browser. Unpressed rendering
and hidden controls cannot produce recorded gameplay actions.

ImGui calls were checked against the CET **v1.37.1** bindings at
`maximegmd/CyberEngineTweaks@61bd6214f0f5f8748589c9e476538614a13908c0`.
The checked declarations are in `tests/cet_ui/cet-api-contract.json`. The menu uses
the single-result, one-argument `BeginTabItem` overload. This is a source/API check,
not an actual game renderer. No dependency version is raised.

The r1 dispatch comparison also runs unchanged: 17,374 matching trace rows against
v0.17d, including native tokens, RNG, timers, money, markers and actor cleanup.
CI publishes the verified ZIP/report only on the refactor branch; main is separate.

## In-game acceptance

Install the entire ZIP into the game root and restart. CET announces
`v0.17d CET refactor r2`.

1. Open CET and check all six tabs, window resizing, per-tab scrolling, header and
   status footer. Check readability at your CET font/UI scale.
2. Start/end a shift from CET and from fast travel. Duty text should update; test
   availability, partner replacement, backup and 10-4 through the normal controls.
3. Request/cancel a normal dispatch, then use the typed tests under Testing. Check
   that the new location does not change the action or spawn a second assignment.
4. Use a test save for milestone/weapon grants. Confirm the test-warning banner,
   clearing, partner selection and same-frame status messages. Claims stay saved.
5. Complete a VIP and wait for the next automatic call while Available. Scene
   cleanup should behave as in r1; the menu adds no timer/mission logic.

Actual CET rendering, pointer interaction, fonts and game behavior still require
this in-game check. The automated tests mock those engine boundaries.
