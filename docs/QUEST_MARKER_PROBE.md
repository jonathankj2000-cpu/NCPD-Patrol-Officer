R4c replaces the direct-node/tagged-entity experiment with a real archived
quest phase. It is a static control for native quest markers, not a conversion
of normal scanner/VIP/cyberpsycho navigation.

The supplied r4b diagnostics proved an attached entity at the intended position
but zero QuestMappins. The tag-based position assumption was incorrect for
ArchiveXL's cooked quest-mappin path: its implementation collects the reference
NodeRef and offset, not EntityReference tag names.

[ArchiveXL Journal Extension](https://github.com/psiberx/cp2077-archive-xl/blob/1bf3bf3a823b3995fbf18285a54a7817c75ecf4d/src/App/Extensions/Journal/Extension.cpp)
also explicitly supports a null NodeRef: the authored offset becomes an absolute
cooked position, and the entry offset is cleared to avoid applying it twice.
R4c uses that static form, removing target-resolution/spawning from this test.
It does not prove arbitrary runtime destinations can be moved after cooking.

The [Cyberpunk.Codes source](https://github.com/andreaolivato/cyberpunk-codes)
shows ArchiveXL phase registration with parent cyberpunk2077.quest, authored
quest/journal resources and native facts conditions. This test's graph and
private data are newly authored; no third-party quests or game assets are shipped.
The [WolvenKit Mappin Manager editor](https://github.com/WolvenKit/WolvenKit/blob/c6065b22f70cb0a53913f5440d112ab1b7dd00a4/WolvenKit.App/ViewModels/GraphEditor/Nodes/Quest/questMappinManagerNodeDefinitionWrapper.cs)
defines Active/Inactive state inputs. The
[quest authoring reference](https://hlky.github.io/cyberpunk-quest-authoring/journal/mappins.html#activating-and-hiding-a-quest-pin)
documents the typed journal path and containing quest index.

Implementation:
- A private 22-node, 21-edge .questphase is injected by the existing ArchiveXL
  dependency. Its graph owns all test journal and marker state transitions.
- It initializes into a passive wait. Start changes only the private request
  fact. Active is followed by a private stage=1 acknowledgement. Remove sets
  request=0; the graph uses Inactive and returns to the start wait.
- All three facts start with ncpd_patrol_marker_probe_r4c_. No reward, incident,
  career, police, conversation or story facts are written.
- The native controller observes the graph and actual mappins, tracks the test
  objective once it becomes active, and preserves manual waypoint IDs.
- Cleanup waits for graph stage=0 and an inactive private quest. It then removes
  only a current-world QuestMappin with the private journal hash if native
  Inactive retained its presentation. Restart remains blocked until confirmed.
- Native probe interface 4 rejects mixed installations. Ordinary mod interfaces
  are unchanged. The older private anchor template remains packed for package
  compatibility but is never spawned by r4c.

Install the COMPLETE package into the game root and fully restart. Include the
probe archive AND .archive.xl (the latter now registers the quest phase).
Existing dependencies remain; Browser Extension stays optional.
Do not use CET hot reload. Use a test save for this engine-owned phase experiment.

1. Stay OFF DUTY, outside combat/wanted status and game menus.
2. Set an ordinary manual waypoint.
3. CET > Testing > Quest marker experiment > Start static quest marker.
4. Wait five seconds. Inspect the WORLD MAP alongside the ordinary waypoint.
   The fixed test point is (-1549.817505, -1544.082886, 70.155853), copied from
   the last reported test destination. It does not follow V or change on start.
   Its elevation is a display control, not a promise of a drivable GPS endpoint.
5. Log diagnostics, then Remove. Wait for cleanup before starting again.

Interpretation:
- journal ready=false: journal/archive unavailable.
- graph ready=0: the registered phase has not completed initialization. Check
  ArchiveXL phase/resource loading logs, not just whether the journal exists.
- graph ready=4, stage=0: phase waiting/passive.
- stage=1: the activation route passed its mappin node, which alone is NOT proof
  of native marker creation.
- quest/objective active show whether journal operations took effect.
- confirmed=true additionally requires exactly one real QuestMappin matching
  the private hash, near the fixed position, linked to the objective.
- If stage=1 but pins=0, inspect ArchiveXL messages for cooked mappin #3466779148
  before inferring UI color, GPS or position problems.
- Menus pause the test lifetime. Duty/combat/wanted status or ten active minutes
  signal cleanup. A newer story selection/waypoint is respected.
- Save load forgets cached handles and signals the phase off. Earned mod rewards
  and progression remain outside this experiment.

For rollback, remove the test and wait for its cleanup, then fully restart with
the earlier complete package. The four installed probe files are listed in the
verification report. Never delete another mod's files or patch a vanilla sector.

Validation executes the actual authored graph data through a small test runner,
mocking native engine operations. No-pin behavior is the default: graph progress
alone must fail confirmation. Cases include passive/missing phase, asynchronous
activation/cleanup, start-stop-start, retained/failed deletion, foreign pins and
types, hash/position/objective failures, manual waypoint changes, save restore,
menu, duty and timeout. Source guards preserve existing gameplay, and earlier
dispatch/VIP/CET comparison suites still run. WolvenKit compile/round-trip and
archive extraction compare all four resources. Offline redscript compilation is
checked with and without Browser Extension. Actual game-cache compilation,
ArchiveXL phase execution, marker appearance, navigation and save behavior still
require the above in-game checks.
