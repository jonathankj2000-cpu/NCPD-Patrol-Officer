# Observed game compiler compatibility

`python tests/compile_compatibility/check_legacy_api.py` runs without dependencies.

The v0.15c game log reported `NO_MATCHING_OVERLOAD` for Bool `!=` and
`UNRESOLVED_TYPE CustomPopup` at `CustomPopupManager.ShowPopup` when the caller
imported only `CustomPopupManager`. The prior offline checker uses a newer
compiler front end and accepted both constructs. It cannot represent the exact
installed game cache or compiler.

The compatibility lint rejects native comparisons involving declared Bool
values/Bool method results and requires the popup parameter type in callers'
imports. Negative controls reproduce the rejected forms. Production uses
`Equals`/`NotEquals` and imports the complete `Codeware.UI` namespace.

All production scripts are scanned in CI, alongside the existing behavior tests.
This lint and the separate offline API check are not a full game-cache build;
successful compilation in the user's installed game still needs confirmation.
