// Officer Down owns its private actors' aid/protection and native quest result.
// Lua owns Codeware IDs, placement, position locking and physical cleanup.
public class NCPDPatrolOfficerDownSystem extends ScriptableSystem {
    private let m_stage: Int32;
    private let m_token: Int32;
    private let m_reward: Int32;
    private let m_reason: String;
    private let m_npcs: array<wref<NPCPuppet>>;
    private let m_cars: array<wref<VehicleObject>>;
    private let m_injured: wref<NPCPuppet>;
    private let m_defender: wref<NPCPuppet>;
    private let m_aid: Int32;
    private let m_aidTime: Float;
    private let m_remaining: Float;
    private let m_downTime: Float;
    private let m_missing: Float;
    private let m_restore: Bool;
    private let m_previous: wref<JournalEntry>;
    private let m_marker: ref<NCPDPatrolSceneMarker>;
    public func Version() -> Int32 { return 1; }
    public static func Get(game: GameInstance) -> ref<NCPDPatrolOfficerDownSystem> {
        return GameInstance.GetScriptableSystemsContainer(game).Get(n"NCPDPatrolOfficerDownSystem") as NCPDPatrolOfficerDownSystem;
    }
    private func OnAttach() -> Void { this.Forget(); }
    private func OnRestored(saveVersion: Int32, gameVersion: Int32) -> Void { this.Forget(); }
    private func Root() -> String { return "quests/minor_quest/ncpd_patrol_officer_down"; }
    private func Phase() -> String { return "quests/minor_quest/ncpd_patrol_officer_down/main"; }
    private func Objective() -> String { return "quests/minor_quest/ncpd_patrol_officer_down/main/assist"; }
    private func Briefing() -> String { return "quests/minor_quest/ncpd_patrol_officer_down/main/assist/briefing"; }
    private func Journal() -> ref<JournalManager> { return GameInstance.GetJournalManager(this.GetGameInstance()); }
    private func Forget() -> Void {
        this.m_stage = 0; this.m_token += 1; this.m_reward = 0;
        this.m_aid = 0; this.m_aidTime = 0.0; this.m_downTime = 0.0; this.m_missing = 0.0;
        ArrayClear(this.m_npcs); ArrayClear(this.m_cars);
        this.m_injured = null; this.m_defender = null; this.m_previous = null;
        this.m_restore = true; this.m_reason = "Officer Down test ready";
        this.m_marker = new NCPDPatrolSceneMarker();
        this.m_marker.Configure(this.Objective(), this.Phase(), NCPDPatrolOfficerDownSite.Position());
    }
    private func Eligible() -> Bool {
        let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
        let patrol: ref<NCPDPatrolSystem> = NCPDPatrolSystem.Get(this.GetGameInstance());
        return NCPDPatrolMarkerSession.WorldReady() && IsDefined(player) && player.IsAttached() && !player.IsDead()
            && IsDefined(patrol) && patrol.IsOnDuty() && !patrol.HasWantedLevel();
    }
    public func IsSessionReady() -> Bool {
        let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
        return NCPDPatrolMarkerSession.WorldReady() && IsDefined(player) && player.IsAttached();
    }
    public func GetSessionGeneration() -> Int32 {
        let session: ref<NCPDPatrolMarkerSession> = NCPDPatrolMarkerSession.Get();
        if IsDefined(session) { return session.GetGeneration(); };
        return 0;
    }
    public func IsReady() -> Bool {
        return IsDefined(this.Journal()) && IsDefined(this.Journal().GetEntryByString(this.Objective(), "gameJournalQuestObjective"))
            && IsDefined(this.Journal().GetEntryByString(this.Objective() + "/location", "gameJournalQuestMapPin"));
    }
    private func Write(path: String, kind: String, state: gameJournalEntryState) -> Bool {
        return NCPDPatrolFixedMarkerSystem.WriteNavigationState(this.Journal(), path, kind, state);
    }
    private func ResetJournal() -> Bool {
        return this.Write(this.Briefing(), "gameJournalQuestDescription", gameJournalEntryState.Inactive)
            && this.Write(this.Objective(), "gameJournalQuestObjective", gameJournalEntryState.Inactive)
            && this.Write(this.Phase(), "gameJournalQuestPhase", gameJournalEntryState.Inactive)
            && this.Write(this.Root(), "gameJournalQuest", gameJournalEntryState.Inactive);
    }
    public func BeginDispatch() -> Int32 {
        let rewards: ref<NCPDPatrolIncidentSystem> = NCPDPatrolIncidentSystem.Get(this.GetGameInstance());
        if !this.Eligible() || !this.IsReady() || this.m_stage == 1 || this.m_stage == 2 || !IsDefined(rewards) { return 0; };
        this.m_marker.Close(this.GetGameInstance());
        if !this.ResetJournal() { return 0; };
        this.m_marker = new NCPDPatrolSceneMarker();
        this.m_marker.Configure(this.Objective(), this.Phase(), NCPDPatrolOfficerDownSite.Position());
        this.m_previous = this.Journal().GetTrackedEntry();
        if !this.Write(this.Root(), "gameJournalQuest", gameJournalEntryState.Active)
            || !this.Write(this.Phase(), "gameJournalQuestPhase", gameJournalEntryState.Active)
            || !this.Write(this.Objective(), "gameJournalQuestObjective", gameJournalEntryState.Active)
            || !this.Write(this.Briefing(), "gameJournalQuestDescription", gameJournalEntryState.Active) { this.ResetJournal(); return 0; };
        this.m_reward = rewards.Reserve(n"officer_down");
        if this.m_reward <= 0 { this.ResetJournal(); return 0; };
        this.m_token += 1; this.m_stage = 1; this.m_remaining = 300.0;
        this.m_aid = 0; this.m_aidTime = 0.0; this.m_downTime = 0.0; this.m_missing = 0.0;
        ArrayClear(this.m_npcs); ArrayClear(this.m_cars); this.m_injured = null; this.m_defender = null;
        this.m_restore = false; this.m_reason = "Respond to the injured patrol";
        this.Journal().TrackEntry(this.Journal().GetEntryByString(this.Objective(), "gameJournalQuestObjective"));
        this.m_marker.Open(this.GetGameInstance());
        return this.m_token;
    }
    public func ProtectNPC(npc: ref<NPCPuppet>) -> Bool {
        let god: ref<GodModeSystem> = GameInstance.GetGodModeSystem(this.GetGameInstance());
        let record: TweakDBID;
        if !this.Eligible() || this.m_stage != 1 || !IsDefined(npc) || !npc.IsAttached() || npc.IsDead() || !IsDefined(god) { return false; };
        record = npc.GetRecordID();
        if record != t"Character.NCPDPatrol_OD_Injured" && record != t"Character.NCPDPatrol_OD_Defender" && record != t"Character.NCPDPatrol_OD_Ganger" { return false; };
        if ArrayContains(this.m_npcs, npc) { return true; };
        if !god.AddGodMode(npc.GetEntityID(), gameGodModeType.Invulnerable, n"NCPDPatrolODStaging") { return false; };
        ArrayPush(this.m_npcs, npc);
        if record == t"Character.NCPDPatrol_OD_Injured" {
            this.m_injured = npc; this.m_aid = 2;
            npc.SetIsDefeatMechanicActive(false);
            GameInstance.GetStatPoolsSystem(this.GetGameInstance()).RequestSettingStatPoolValue(Cast<StatsObjectID>(npc.GetEntityID()), gamedataStatPoolType.Health, 10.0, null, true);
            StatusEffectHelper.ApplyStatusEffect(npc, t"BaseStatusEffect.NCPDPatrolOfficerDown");
            npc.NCPDPatrolRefreshAidInteraction();
        };
        if record == t"Character.NCPDPatrol_OD_Defender" { this.m_defender = npc; };
        return true;
    }
    public func ProtectVehicle(vehicle: ref<VehicleObject>) -> Bool {
        let god: ref<GodModeSystem> = GameInstance.GetGodModeSystem(this.GetGameInstance());
        if !this.Eligible() || this.m_stage != 1 || !IsDefined(vehicle) || !vehicle.IsAttached() || !IsDefined(god) { return false; };
        if vehicle.GetRecordID() != t"Vehicle.NCPDPatrol_OD_Police" && vehicle.GetRecordID() != t"Vehicle.NCPDPatrol_OD_GangCar" { return false; };
        if ArrayContains(this.m_cars, vehicle) { return true; };
        if !god.AddGodMode(vehicle.GetEntityID(), gameGodModeType.Invulnerable, n"NCPDPatrolODStaging") { return false; };
        ArrayPush(this.m_cars, vehicle); return true;
    }
    public func Orientation(yaw: Float) -> Quaternion {
        let rotation: EulerAngles;
        rotation.Roll = 0.0; rotation.Pitch = 0.0; rotation.Yaw = yaw;
        return EulerAngles.ToQuat(rotation);
    }
    public func LockPosition(object: ref<GameObject>, point: Vector4, yaw: Float) -> Bool {
        let i: Int32 = 0;
        let owned: Bool = false;
        let rotation: EulerAngles;
        if !this.Eligible() || this.m_stage != 1 || !IsDefined(object) || !object.IsAttached()
            || point.X != point.X || point.Y != point.Y || point.Z != point.Z
            || Vector4.Distance(point, NCPDPatrolOfficerDownSite.Position()) > 35.0 { return false; };
        while i < ArraySize(this.m_npcs) { if this.m_npcs[i] == object { owned = true; }; i += 1; };
        i = 0;
        while i < ArraySize(this.m_cars) { if this.m_cars[i] == object { owned = true; }; i += 1; };
        if !owned { return false; };
        rotation.Roll = 0.0; rotation.Pitch = 0.0; rotation.Yaw = yaw;
        GameInstance.GetTeleportationFacility(this.GetGameInstance()).Teleport(object, point, rotation);
        return true;
    }
    private func ReleaseProtection(keepInjured: Bool) -> Void {
        let god: ref<GodModeSystem> = GameInstance.GetGodModeSystem(this.GetGameInstance());
        let i: Int32 = 0;
        if !IsDefined(god) { return; };
        while i < ArraySize(this.m_npcs) {
            if IsDefined(this.m_npcs[i]) && this.m_npcs[i].IsAttached() && (!keepInjured || this.m_npcs[i] != this.m_injured) {
                god.RemoveGodMode(this.m_npcs[i].GetEntityID(), gameGodModeType.Invulnerable, n"NCPDPatrolODStaging");
            };
            i += 1;
        };
        i = 0;
        while i < ArraySize(this.m_cars) {
            if IsDefined(this.m_cars[i]) && this.m_cars[i].IsAttached() {
                god.RemoveGodMode(this.m_cars[i].GetEntityID(), gameGodModeType.Invulnerable, n"NCPDPatrolODStaging");
            };
            i += 1;
        };
    }
    public func Activate(token: Int32) -> Bool {
        let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
        let i: Int32 = 0;
        let enemy: wref<NPCPuppet>;
        if !this.Eligible() || token != this.m_token || this.m_stage != 1 || ArraySize(this.m_npcs) != 7 || ArraySize(this.m_cars) != 3
            || !IsDefined(this.m_injured) || !IsDefined(this.m_defender) || Vector4.Distance(player.GetWorldPosition(), NCPDPatrolOfficerDownSite.Position()) > 55.0 { return false; };
        this.m_stage = 2; this.m_remaining = 600.0; this.m_reason = "Neutralize the suspects and revive the officer";
        this.ReleaseProtection(true);
        while i < ArraySize(this.m_npcs) {
            enemy = this.m_npcs[i];
            if IsDefined(enemy) && enemy.GetRecordID() == t"Character.NCPDPatrol_OD_Ganger" {
                enemy.GetAttitudeAgent().SetAttitudeGroup(n"hostile");
                enemy.GetAttitudeAgent().SetAttitudeTowards(player.GetAttitudeAgent(), EAIAttitude.AIA_Hostile);
                enemy.GetAttitudeAgent().SetAttitudeTowards(this.m_defender.GetAttitudeAgent(), EAIAttitude.AIA_Hostile);
                this.m_defender.GetAttitudeAgent().SetAttitudeTowards(enemy.GetAttitudeAgent(), EAIAttitude.AIA_Hostile);
                TargetTrackingExtension.InjectThreat(enemy, player);
                TargetTrackingExtension.InjectThreat(enemy, this.m_defender);
                TargetTrackingExtension.InjectThreat(this.m_defender, enemy);
            };
            i += 1;
        };
        this.m_injured.NCPDPatrolRefreshAidInteraction();
        return true;
    }
    public const func IsDownOfficer(const object: ref<GameObject>) -> Bool {
        return (this.m_stage == 1 || this.m_stage == 2) && IsDefined(this.m_injured) && object == this.m_injured && this.m_aid >= 2 && this.m_aid <= 4;
    }
    private func InAidRange() -> Bool {
        let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
        return this.Eligible() && IsDefined(this.m_injured) && this.m_injured.IsAttached() && !this.m_injured.IsDead()
            && !VehicleComponent.IsMountedToVehicle(this.GetGameInstance(), player)
            && Vector4.Distance(player.GetWorldPosition(), this.m_injured.GetWorldPosition()) <= 2.5;
    }
    public func StartRevive() -> Bool {
        if this.m_stage != 2 || this.m_aid != 2 || !this.InAidRange() { return false; };
        this.m_aid = 3; this.m_aidTime = 0.0; this.m_injured.NCPDPatrolRefreshAidInteraction(); return true;
    }
    public func GetAidState() -> Int32 { return this.m_aid; }
    public func GetRemainingEnemies() -> Int32 {
        let i: Int32 = 0; let count: Int32 = 0; let npc: wref<NPCPuppet>;
        let arrest: ref<NCPDPatrolArrestSystem> = NCPDPatrolArrestSystem.Get(this.GetGameInstance());
        if this.m_stage == 3 { return 0; };
        if this.m_stage == 1 && ArraySize(this.m_npcs) < 7 { return 5; };
        while i < ArraySize(this.m_npcs) {
            npc = this.m_npcs[i];
            if !IsDefined(npc) || !npc.IsAttached() { count += 1; } else {
                if npc.GetRecordID() == t"Character.NCPDPatrol_OD_Ganger" && !npc.IsDead() && !npc.IsDeadNoStatPool()
                    && !ScriptedPuppet.IsDefeated(npc) && !ScriptedPuppet.IsUnconscious(npc)
                    && (!IsDefined(arrest) || !arrest.IsArrested(npc)) { count += 1; };
            };
            i += 1;
        };
        return count;
    }
    private func Finish(stage: Int32, reason: String) -> Bool {
        let state: gameJournalEntryState = gameJournalEntryState.Failed;
        let tracked: wref<JournalEntry> = this.Journal().GetTrackedEntry();
        let rewards: ref<NCPDPatrolIncidentSystem> = NCPDPatrolIncidentSystem.Get(this.GetGameInstance());
        if stage == 3 { state = gameJournalEntryState.Succeeded; };
        this.m_stage = stage; this.m_reason = reason; this.m_marker.Close(this.GetGameInstance());
        this.ReleaseProtection(false);
        if IsDefined(this.m_injured) && this.m_injured.IsAttached() && this.m_aid != 1 {
            StatusEffectHelper.RemoveStatusEffect(this.m_injured, t"BaseStatusEffect.NCPDPatrolOfficerDown");
            this.m_injured.NCPDPatrolRefreshAidInteraction();
        };
        if !this.Write(this.Briefing(), "gameJournalQuestDescription", state) || !this.Write(this.Objective(), "gameJournalQuestObjective", state)
            || !this.Write(this.Phase(), "gameJournalQuestPhase", state) || !this.Write(this.Root(), "gameJournalQuest", state) {
            this.m_stage = 6; this.m_reason = "Officer Down journal closure failed";
        };
        if tracked == this.Journal().GetEntryByString(this.Objective(), "gameJournalQuestObjective") && IsDefined(this.m_previous) {
            this.Journal().TrackEntry(this.m_previous);
        };
        if IsDefined(rewards) {
            if this.m_stage == 3 { return rewards.CompleteOfficerDown(this.m_reward); };
            rewards.Cancel(this.m_reward, n"officer_down");
        };
        return this.m_stage != 6;
    }
    public func Cancel(token: Int32, reason: String) -> Bool {
        if !this.IsSessionReady() || token != this.m_token || (this.m_stage != 1 && this.m_stage != 2) { return false; };
        return this.Finish(5, reason);
    }
    public func Fail(token: Int32, reason: String) -> Bool {
        if !this.IsSessionReady() || token != this.m_token || (this.m_stage != 1 && this.m_stage != 2) { return false; };
        return this.Finish(4, reason);
    }
    public func Tick(delta: Float) -> Void {
        let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
        let patrol: ref<NCPDPatrolSystem> = NCPDPatrolSystem.Get(this.GetGameInstance());
        let i: Int32 = 0;
        let missing: Bool = false;
        if !NCPDPatrolMarkerSession.WorldReady() || !IsDefined(player) || !player.IsAttached() || !this.IsReady() { return; };
        if this.m_restore { this.m_marker.Close(this.GetGameInstance()); if !this.ResetJournal() { return; }; this.m_restore = false; };
        if this.m_stage != 1 && this.m_stage != 2 { return; };
        if !this.Eligible() { this.Finish(5, "Shift ended or criminal activity"); return; };
        if delta <= 0.0 || delta > 0.5 || patrol.IsDispatchMenuOpen() { return; };
        this.m_marker.Tick(this.GetGameInstance(), delta);
        this.m_remaining -= delta;
        if this.m_remaining <= 0.0 { this.Finish(4, "Officer Down response expired"); return; };
        if this.m_stage == 1 { return; };
        if Vector4.Distance(player.GetWorldPosition(), NCPDPatrolOfficerDownSite.Position()) > 300.0 { this.Finish(4, "Patrol assistance abandoned"); return; };
        while i < ArraySize(this.m_npcs) {
            if !IsDefined(this.m_npcs[i]) || !this.m_npcs[i].IsAttached() { missing = true; };
            i += 1;
        };
        if missing { this.m_missing += delta; } else { this.m_missing = 0.0; };
        if this.m_missing >= 5.0 { this.Finish(4, "Scene actor missing; no completion awarded"); return; };
        if !IsDefined(this.m_injured) || this.m_injured.IsDead() || this.m_injured.IsDeadNoStatPool() { this.Finish(4, "Injured officer lost"); return; };
        if this.m_aid == 3 {
            if !this.InAidRange() { this.m_aid = 2; this.m_aidTime = 0.0; this.m_injured.NCPDPatrolRefreshAidInteraction(); } else {
                this.m_aidTime += delta;
                if this.m_aidTime >= 3.0 {
                    this.m_aid = 4; this.m_aidTime = 0.0;
                    StatusEffectHelper.RemoveStatusEffect(this.m_injured, t"BaseStatusEffect.NCPDPatrolOfficerDown");
                    StatusEffectHelper.RemoveStatusEffectsWithTag(this.m_injured, n"FollowerDefeated");
                    GameInstance.GetStatPoolsSystem(this.GetGameInstance()).RequestSettingStatPoolValue(Cast<StatsObjectID>(this.m_injured.GetEntityID()), gamedataStatPoolType.Health, 100.0, null, true);
                };
            };
        } else {
            if this.m_aid == 4 {
                this.m_aidTime += delta;
                if this.m_aidTime >= 1.0 && !StatusEffectSystem.ObjectHasStatusEffect(this.m_injured, t"BaseStatusEffect.NCPDPatrolOfficerDown")
                    && !StatusEffectSystem.ObjectHasStatusEffectWithTag(this.m_injured, n"FollowerDefeated")
                    && ScriptedPuppet.IsActive(this.m_injured)
                    && !ScriptedPuppet.IsDefeated(this.m_injured) && !ScriptedPuppet.IsUnconscious(this.m_injured)
                    && NotEquals(this.m_injured.GetHighLevelStateFromBlackboard(), gamedataNPCHighLevelState.Unconscious)
                    && NotEquals(this.m_injured.GetHighLevelStateFromBlackboard(), gamedataNPCHighLevelState.Dead)
                    && GameInstance.GetStatPoolsSystem(this.GetGameInstance()).GetStatPoolValue(Cast<StatsObjectID>(this.m_injured.GetEntityID()), gamedataStatPoolType.Health, true) >= 99.0 {
                    this.m_aid = 1;
                    GameInstance.GetGodModeSystem(this.GetGameInstance()).RemoveGodMode(this.m_injured.GetEntityID(), gameGodModeType.Invulnerable, n"NCPDPatrolODStaging");
                    this.m_injured.NCPDPatrolRefreshAidInteraction();
                } else {
                    if this.m_aidTime >= 5.0 { this.m_aid = 2; this.m_aidTime = 0.0; StatusEffectHelper.ApplyStatusEffect(this.m_injured, t"BaseStatusEffect.NCPDPatrolOfficerDown"); this.m_injured.NCPDPatrolRefreshAidInteraction(); };
                };
            };
        };
        if this.m_aid == 1 && !missing && this.GetRemainingEnemies() == 0 { this.m_downTime += delta; } else { this.m_downTime = 0.0; };
        if this.m_downTime >= 1.0 { this.Finish(3, "Officer rescued and armed suspects neutralized"); };
    }
    public func GetStage() -> Int32 { return this.m_stage; }
    public func GetToken() -> Int32 { return this.m_token; }
    public func GetReason() -> String { return this.m_reason; }
    public func GetRemainingSeconds() -> Int32 { return Cast<Int32>(MaxF(0.0, this.m_remaining)); }
    public func GetDiagnostics() -> String {
        let marker: String = "not configured";
        if IsDefined(this.m_marker) { marker = this.m_marker.GetDiagnostics(); };
        return s"stage=\(this.m_stage) | token=\(this.m_token) | aid=\(this.m_aid) | enemies remaining=\(this.GetRemainingEnemies()) | \(marker) | \(this.m_reason)";
    }
}
