# Officer readiness regression checks

Run `python tests/officer_readiness/check_ready.py` with Python 3 and lupa.

The actual `officer_ready.lua`, partner, shared officer AI and backup modules
execute. Native creation, equipment acknowledgements, drive/mount animation and
revive-state boundaries are mocked. Cases cover prompt primary draw, stable
calm holster, empty-hand fists, already-correct weapons without repeated orders,
pending holster cancellation when an officer enters native alert/combat,
player combat, post-combat delay, pause, vehicle/boarding/down/revive guards,
bounded refused-command retries, isolated API failure, actual partner recovery
and backup drive/brake/exit before mirroring. Ambient actors are not touched.
Only the helper's own equipment commands are stopped; native combat and existing
follow/move/hold commands are preserved. This cannot prove live weapon poses or
whether a particular NPC's behavior tree accepts the request.

Primary API evidence in
[MOD_Development_Reference](https://github.com/In-Question/MOD_Development_Reference):

- `cyberpunk/ai/Tasks/aiSendCommandTasks.swift` sends
  `AISwitchToPrimaryWeaponCommand` through the AI controller.
- `cyberpunk/ai/commands/aiEquipWeaponCommand.swift` reads its `unEquip` flag;
  the command declaration also appears in `orphans.swift`.
- `cyberpunk/puppet/scriptedPuppet.swift` implements `GetActiveWeapon` from actual
  right/left weapon slots and reads `GetHighLevelStateFromBlackboard`.
- `cyberpunk/items/weapon.swift` implements `WeaponObject.IsFists`.
- Game high-level-state definitions distinguish Relaxed, Alerted and Combat.

The helper never writes a high-level state, combat target, attitude, invulnerability
or follower role. Only the partner and this mod's own two backup officers call it,
and only after normal actor setup. The unarmed VIP does not use this helper.
