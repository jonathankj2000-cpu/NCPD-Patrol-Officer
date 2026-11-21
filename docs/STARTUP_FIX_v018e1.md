# v0.18e1 startup compilation fix

The supplied redscript log reports `UNRESOLVED_METHOD` at
`NCPDPatrolOfficerDownSystem.reds:165`: `vehicle.Dispose()` is not found on
`VehicleObject`. This is a v0.18e source defect. No dependency conflict or
in-game actor cleanup timeout is needed to explain this compiler failure.

The offline contract had incorrectly added `Entity.Dispose` based on engine/C++
entrypoints and a CET/RTTI method listing. That made the offline checker accept
code the installed game cache rejected. The declaration is removed. It is not
added to production as a workaround.

The native method is now `PrepareCreatedVehicleDisposal`: it checks the exact
created ID, cached object, private vehicle record, accepted Codeware deletion,
terminal assignment state and current world generation. It authorizes at most
one attempt per owned vehicle and never invokes Dispose. The Lua controller
optionally tries `object:Dispose()` through CET inside `pcall`. Unknown or rejected
CET capability emits `vehicle_dispose_unavailable` and keeps every ownership
receipt. Authorization/request remains distinct from physical detachment.
The diagnostics field is now `CET dispose attempts`, not `native disposals`.
The cleanup interface is version 2 so mixed old/native files are rejected before
creating a new catalogue scene. Full installation and a full restart are needed.

Portable compatibility lint now rejects direct REDscript Dispose calls and
invented native Dispose imports, including controls for the exact failing
statement and false contract. The gameplay suite additionally runs without a
CET Dispose method: cleanup remains pending, payment/success stay intact, logging
is bounded and later physical cleanup still releases ownership. Supported-CET
cases retain repeat requests, delayed cleanup, world/CET recovery and receipts.

The optional local source/API compile checks all 44 scripts with Browser
Extension present and absent under the corrected contracts. It also compiles the
exact previous v0.18e owner as a negative control and requires a Dispose/
VehicleObject failure. These are offline checks, not the installed game cache.
Optional CET capability and real engine teardown still need in-game validation.

Markers, other incident controllers, economy/ledgers, survey data and all eight
archives are unchanged. Existing gameplay logs are retained and not shipped in
the complete 115-file ZIP.
