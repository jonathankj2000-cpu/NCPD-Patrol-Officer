# Off the Books — wanted report and private dialogue mix, v0.20f

The author confirmed that v0.20e successfully advances after taking the evidence.
That receipt, native loot table, corpse retention, restaurant PSM exception,
actors, Voss conversation, dispatch and duty implementation are retained.

## Assassination report

The active off-duty encounter reports a confirmed contractor death once using
the game's `SetWantedLevel` request with `Heat_3` and the current player position
as the last crime point. `PreventionSystem.QueueRequest` and its native
`OnSetWantedLevel` handler are documented in game source commit
`81d996b584a693e8b0f0b20526a9fa38b5c83fe7`,
`core/systems/preventionSystem.swift:3522` and `:3259`.

The native handler owns enabling the pursuit, heat transition, audio, spawning,
UI and subsequent search/cooldown. We do not change heat limits, force grey
stars, reset an existing quest's grey-star flag, ignore security areas, clear
the crime at cancellation, or continuously set stars. An existing heat of three
or more is preserved without another request. Other NPC deaths and a merely
defeated contractor do not trigger this report.

New encounters arm the policy at Begin. Legacy encounters arm only when the
owned target is observed alive; already-dead or completed legacy saves receive
no retrospective chase. The policy and send receipt use new facts under the
existing `ncpd_patrol_otb_` prefix, reset only by a new Begin. Transient resets do
not remove that receipt. Missing PreventionSystem defers the report. The same
tick that sends a request stays at Retrieve, allowing the native request queue
to process before selecting Escape/Return on the subsequent update.

Death still cannot complete Retrieve. After the real evidence receipt, the
existing journal owner selects Escape while wanted and Return once wanted
clears. Players can escape first and return for the evidence. The mod does not
enforce a second pursuit if the first one has already cooled off.

## Dialogue ambience experiment

Both speakers used `Vo_Context_Quest` in their private scene events. The common
native VO mix context is a candidate for the reported short ambience dips, but
the native mixer cause is not proven from source or a game recording.

The isolated test changes those ten event contexts to the supported
`Vo_Context_Minor_Activity` and updates the scene cache hash. There is no global
audio override, volume write, sound-bank replacement or new dependency. Six
Voss WEM files, supplied lipsync, four native V line IDs, voice mapping,
subtitles, scene durations, event timing, workspot and LookAt are unchanged.

WolvenKit deserialization/serialization and archive extraction validate the
resources. Comparing the previous and new archives confirms only
`conversation.scene` changes among the sixteen resources; the other fifteen,
including all seven media assets, are byte-identical. Only this private archive
changes; the other nine archives are untouched. This establishes the package
delta, not whether the audible symptom is fixed. Playback, voice level and
continuous ambience need in-game confirmation.

## Test

1. Install the complete 131-file package and restart the game fully. API 6
   prevents the new Lua controller from running against an older encounter
   bridge. The first Voss scene bridge remains API 5.
2. Use a save before the briefing, or the existing explicit test replay. Listen
   around both Voss and V replies, including first/last lines and pauses. Check
   that all voices, captions and lipsync still play normally.
3. Use a save before killing the contractor. Confirm three stars at death,
   Retrieve still active and a shard in the native corpse loot. A higher
   existing wanted level must remain higher.
4. Take or Read the evidence. Escape becomes active if still wanted; the
   ordinary native cooldown activates Return when cleared. Alternatively,
   escape first, retrieve the shard afterwards and return without a new chase.
5. Save/load during pursuit and after escape. No renewed report, duplicate
   contractor, shard, payment or Voss briefing should occur. Loading the
   already-dead v0.20e encounter alone must not start a chase.

Existing Off the Books diagnostics add the policy, send receipt and transient
pending flag; no additional debugging interface is installed.

## Verification limits

46 portable suites include the actual native request/handler source over a
recording asynchronous queue, exact three-star parameters, higher heat,
non-lethal targets, evidence before/after death, missing service, pause/duty/
cancel guards, legacy migration and no repeat report after escape/reset.
Dedicated scene checks compare every other scene field and all original media.
Offline source/API compilation checks Browser Extension present and absent.
These checks do not verify real police spawning/cooldown, audible mix behavior,
actual game-cache compilation or save serialization. Those require the test
above. Existing Andrea Olivato attribution and MIT notices remain in place.
