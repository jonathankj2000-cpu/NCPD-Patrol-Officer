# CET interface contract tests

Run `python tests/cet_ui/check_cet_ui.py` with `lupa==2.6` and Git history containing
`3c20841bba35d69289e5f70784b3202a5fbf8881`. `--report <path>` saves JSON results.

The actual old entrypoint and new entrypoint/UI render against the same engine
boundary recorder. Button discovery verifies all 52 controls; 156 old/new action
traces compare off-duty/on-duty and enabled-toggle states. A deliberate valid but
incorrect dispatch target must fail the comparison. Source checks prove that
session/update/shift/native checks remain unchanged except two build labels.

The ImGui fixture selects one tab at a time and enforces Begin/End scopes even
when Begin returns false. It checks closed/clipped controls, independent content
and footer scopes, native single-result tab overload, font-scaled footer, live
session/status getters, test override warning, progress clamping, repair status,
missing native modules and optional browser. A failing panel must preserve its
ImGui scopes and log once. Idle rendering must cause no writes.
`cet-api-contract.json` records declarations verified from CET 1.37.1 upstream.

The existing career/shift/cyberpsycho fixtures add the same native ImGui methods
and navigate to the moved controls. Their actual native reward/quest/entry logic
still executes. Other gameplay suites are unchanged.

These checks exercise authored Lua/controller routing, not actual game rendering
or pointer hit-testing. See `docs/CET_UI_REFACTOR.md` for in-game checks.
