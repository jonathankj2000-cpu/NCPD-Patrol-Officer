# v0.19a — separate quest-giver prototype

The requested test uses a native scene and a separately registered journal
quest. The CET button activates it; dialogue choices are shown in the game's
normal interaction UI. No dialogue choices are implemented as CET buttons.

## Actors and location

- Source NPC: `Character.ncpd_investigator_officer_omaha_wa`.
- Appearance: `corpo__ncpd_wa_investigator__lvl3_02`.
- NPC: X 1424.737, Y -2754.759, Z 204.665; yaw -143.376 degrees.
- Private Hella clone: `Vehicle.v_standard2_archer_hella_police`.
- Car: 4 m behind the NPC, at NPC yaw + 90 degrees.
- A 120 m approach stages both actors; entering 3 m on foot requests dialogue.
- Static support, slope, full car footprint, vehicle/static obstructions and
  nearby NPC navigation are checked before creating either entity. There is
  no fallback to another floor or an arbitrary replacement coordinate.

Both records are private clones. The original NPC/vehicle records are not
modified. Codeware assigns the private tags to the real entity tag system;
the scene acquires the investigator through `findInWorld` with an `EntityRef`
of type `Tag`, rather than spawning a second actor or requiring a community.
The supplied appearance is set on the clone and on the dynamic spawn spec.

## Dialogue and quest structure

The archive contains a nine-node scene: start, hello, a native two-choice hub,
two choice-result fact nodes, two V-reply sections, one shared goodbye section
and the end node. Each choice enters its quest-fact node on the mapped **In**
socket, not CutDestination. The dialogue lines use private localization IDs;
there are no voice-over, lipsync, workspot or original story dependencies.

The rearmable quest phase starts passive. A private request fact activates the
journal quest/phase/objective. A separate approach/talk fact starts the native
scene. Its normal output and a selected choice are required before the journal
objective/phase/quest succeed. Stage 3 is written after those success writes.
The Lua bridge verifies actual journal success; neither timers nor a successful
start call are treated as quest completion. There is no money/career credit.

Cancel uses the quest graph's CutSource connections to cut its private waits
and scene. Cleanup waits for both graph stage 0 and the scene system's actual
entity-ownership release before requesting actor deletion. Physical detachment
and pending-spawn checks retain refused/deferred work. Deleted-ID tag receipts
can retire after physical proof, following Codeware 1.21.4 DeleteEntity and
IsSpawned/IsSpawning semantics. Private tags plus record identity scope deletion.

The fixed journal pin uses the existing proven static-anchor offset contract
and existing SceneMarker helper. Completion/cancellation explicitly deactivate
only its pin; the player's manual waypoint is never written. Previous journal
tracking is restored only while this prototype remains the tracked objective.

## Isolation and recovery

`quest_giver_test.lua` and `NCPDPatrolQuestGiverTest.reds` own this prototype;
production dispatch code and all 54 Officer Down catalogue entries remain
unchanged. The small entrypoint/menu additions are explicitly bounded. Active
tests block a shift/survey start; the normal shift can start after completion.
A completed test remains at the location until cleared.

On CET/world recovery, only current-world private tagged actors are recovered;
old Lua IDs are forgotten. The prototype is cancelled and drained, not resumed.
Cleanup is asynchronous. A new test is blocked until the prior test is cleared.
Clearing also resets its journal entry, so both choices can be tested repeatedly.

## Validation and limits

The asset builder compiles all six resources, serializes them again, validates
scene branches/handles and quest graph connections, then extracts the packed
archive and compares the resource bytes. The source/API compiler checks all
45 native scripts with Browser Extension present and absent; it is not an
actual game-cache compilation. The historical unavailable Dispose declaration
negative control stays in place.

Portable tests execute the actual Lua module/native bridge and interpret the
authored quest/scene graphs at the mocked engine boundary. They cover both
choices, no early completion, exact placeholder text, scoped marker ownership,
pre-spawn geometry failures, cancellation while choosing, deferred/refused
cleanup, stale tag receipts, restart and current-world recovery. A malformed
choice-to-quest input socket is rejected by a negative control. Existing CET
routes and production gameplay suites continue to run (33 suites total).

Real-game checks remain necessary for the supplied character record/appearance,
streamed geometry at Z 204.665, native acquisition by tag, silent subtitle
rendering, dialog selection and interruption. If the scene stalls, use
Testing > Quest giver prototype > Log quest giver diagnostics; stage, choice,
marker proof, ownership phase and the last failure are included.

## Attribution

Minimal native scene/quest/localization schemas are adapted from Andrea
Olivato's MIT-licensed cyberpunk-codes fixer01 example at
`4aeaad5d235e3a0244c0f1857757d1b01cbcd58e`. The source and MIT notice are recorded
in THIRD_PARTY_NOTICES.txt and reference-templates.json. No original dialogue,
voice, animation or streaming/community resources are shipped.
