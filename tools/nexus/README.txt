NCPD PATROL v0.20g - NEXUS RELEASE
================================
Patrol Night City with dispatches, a police partner, vehicle backup, arrests
and a persistent career. This is the patrol-only public package. Unreleased
story quests, their scenes/media and temporary audio-test helpers are omitted.

REQUIREMENTS - TESTED BASELINE (CYBERPUNK 2077 2.5)
- Cyber Engine Tweaks 1.38.1
- RED4ext 1.31.1
- redscript 0.5.32
- Codeware 1.21.4
- ArchiveXL 1.28.8
- TweakXL 1.12.2
These frameworks are required and are not bundled.

OPTIONAL
- Browser Extension Framework 0.9.7: adds the NCPD Career computer page.
  The rest of NCPD Patrol works without it. Career/reward/partner controls
  remain available in CET. Other appearance/UI mods are not requirements.

INSTALL / UPDATE
Exit the game. Install the complete ZIP through your mod manager, or extract
it into the Cyberpunk 2077 folder containing bin, r6 and archive. Restart the
whole game. CET announces v0.20g. Include all archive/.xl and tweak files.
For a mod-manager update, replace the previous NCPD Patrol version.
Normal career progress, reward receipts and completed-incident history remain
in the save. Do not remove your saves or delete existing JSON/JSONL log files.

PRIVATE DEVELOPMENT BUILD USERS
Keep this public package separate from private test profiles. Disable previous
full test packages, VO Lengths, WEM Header, Voss Audio Control, Audio Trace and
Voice A/B helpers before testing this public build. A private package loaded
after this release can restore its old scripts or omitted content.
Use a save from before activating the private story prototype: removing an
unfinished quest's assets/classes is not a supported migration of that quest.
Regular Nexus patrol saves do not need a progression reset.

For a manual update FROM a private story build, remove only these obsolete
files (a fresh install or a mod-manager replacement does not contain them):
  bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrol/quest_giver_test.lua
  bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrol/off_the_books.lua
  r6/scripts/NCPDPatrol/NCPDPatrolQuestGiverTest.reds
  r6/scripts/NCPDPatrol/NCPDPatrolVossSubtitles.reds
  r6/scripts/NCPDPatrol/NCPDPatrolOffBooksSystem.reds
  r6/scripts/NCPDPatrol/NCPDPatrolOffBooksEvents.reds
  r6/scripts/NCPDPatrol/NCPDPatrolOffBooksCombat.reds
  r6/scripts/NCPDPatrol/NCPDPatrolOffBooksLoot.reds
  r6/tweaks/NCPDPatrol_QuestGiverTest.yaml
  r6/tweaks/NCPDPatrol_OffTheBooks.yaml
  archive/pc/mod/NCPDPatrol_QuestGiverTest.archive
  archive/pc/mod/NCPDPatrol_QuestGiverTest.archive.xl
  archive/pc/mod/NCPDPatrol_OffTheBooks.archive
  archive/pc/mod/NCPDPatrol_OffTheBooks.archive.xl
Also remove/disable the separate developer-only folders if manually installed:
  r6/scripts/NCPDPatrolVossLengthTest
  bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrolAudioTrace
  bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrolVoiceAB

START / END A SHIFT
Use a Fast Travel terminal or CET's Start Shift / End Shift button. With the
optional browser framework, the NCPD Career computer page also has START SHIFT
and END SHIFT. Reloading a save ends the current shift; start another shift
to resume patrol. Earned career progress and claimed rewards stay saved.

PATROL CAR TRUNK
Tap R: request a backup patrol.
Hold R: open Patrol Menu. These follow the game's secondary interaction binding.
Menu keys (top row/numpad or mouse):
  1 Available / Busy      2 Vehicle repair (10 seconds, including damaged tyres)
  3 New partner           4 Cancel dispatch
  5 New dispatch          6 Cop Stats
  7 10-4: release backup  9 Close
Busy pauses new automatic calls. 10-4 releases backup without immediately
deleting the scene. Normal stash controls remain available.

DISPATCH / PARTNER / CAREER
- Scanner incidents, VIP transport, cyberpsycho and Officer Down dispatches.
- Automatic type weights: 45% scanner / 27% VIP / 18% cyberpsycho / 10% Officer
  Down; local availability and existing cleanup guards can cause fallback.
- Officer Down uses 54 approved locations. Revive the officer AND neutralize
  the armed suspects. Coverage is limited to the current authored catalogue.
- Dispatch navigation uses its own quest-style markers; your manual waypoint
  remains available. The existing fallback/cleanup logic is retained.
- The partner can be revived and can follow, fight and board the patrol car.
  Backup and partner equipment use their existing combat/readiness rules.
- Arrest living incapacitated suspects through the nearby interaction; dead
  bodies are not arrest targets. Arrest rewards are separate from scanner
  bonuses. Move an obstructed suspect to suitable ground when necessary.
- Career milestones retain their existing gear, vehicles, fixed-tier weapons
  and partner unlocks. The M2038 Bean Bagger remains available for V.
- CET retains the current Patrol, Dispatch, Career, Settings, Diagnostics and
  Testing tabs. Advanced test tools can grant real rewards; use a test save.

COMPATIBILITY / SUPPORT
Ordinary crime/wanted enforcement remains active. This package does not grant
global police immunity. Include your mod version and relevant CET or redscript
logs when reporting a reproducible problem.

CREDITS
See LICENSE and THIRD_PARTY_NOTICES.txt for the project license, Andrea Olivato
reference/adaptation credits and authoring-tool notices. Dependencies and
frameworks are not bundled.
