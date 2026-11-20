// Off-duty placement tests only. No journal, quest, payment or career calls.
// Lua owns Codeware IDs; this owner supplies typed native protection/teleport.
public class NCPDPatrolSceneSurveySystem extends ScriptableSystem {
    private let m_active: Bool;
    private let m_generation: Int32;
    private let m_player: EntityID;
    private let m_origin: Vector4;
    private let m_return: Vector4;
    private let m_returnYaw: Float;
    private let m_created: array<EntityID>;
    private let m_ids: array<EntityID>;
    private let m_objects: array<wref<GameObject>>;
    public func Version() -> Int32 { return 1; }
    private func OnAttach() -> Void { this.Forget(); }
    private func OnRestored(saveVersion: Int32, gameVersion: Int32) -> Void { this.Forget(); }
    private func Forget() -> Void {
        this.m_active = false; this.m_generation = -1;
        ArrayClear(this.m_ids); ArrayClear(this.m_objects); ArrayClear(this.m_created);
    }
    public func GetSessionGeneration() -> Int32 {
        let session: ref<NCPDPatrolMarkerSession> = NCPDPatrolMarkerSession.Get();
        if IsDefined(session) { return session.GetGeneration(); };
        return 0;
    }
    public func IsSessionReady() -> Bool {
        let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
        return NCPDPatrolMarkerSession.WorldReady() && IsDefined(player) && player.IsAttached();
    }
    public func IsMenuOpen() -> Bool {
        let patrol: ref<NCPDPatrolSystem> = NCPDPatrolSystem.Get(this.GetGameInstance());
        return !IsDefined(patrol) || patrol.IsDispatchMenuOpen();
    }
    public func CanRun() -> Bool {
        let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
        let patrol: ref<NCPDPatrolSystem> = NCPDPatrolSystem.Get(this.GetGameInstance());
        return this.IsSessionReady() && IsDefined(patrol) && !patrol.IsOnDuty() && !patrol.HasWantedLevel()
            && !player.IsDead() && !player.IsInCombat()
            && !VehicleComponent.IsMountedToVehicle(this.GetGameInstance(), player);
    }
    private func SamePlayer() -> Bool {
        let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
        return this.m_active && this.IsSessionReady() && this.m_generation == this.GetSessionGeneration()
            && player.GetEntityID() == this.m_player;
    }
    public func Begin() -> Bool {
        let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
        let god: ref<GodModeSystem> = GameInstance.GetGodModeSystem(this.GetGameInstance());
        let angle: EulerAngles;
        if this.m_active || !this.CanRun() || this.IsMenuOpen() || !IsDefined(god) { return false; };
        if !god.AddGodMode(player.GetEntityID(), gameGodModeType.Invulnerable, n"NCPDPatrolSurveyPlayer") { return false; };
        this.m_active = true; this.m_player = player.GetEntityID(); this.m_generation = this.GetSessionGeneration();
        this.m_return = player.GetWorldPosition(); angle = Quaternion.ToEulerAngles(player.GetWorldOrientation()); this.m_returnYaw = angle.Yaw;
        ArrayClear(this.m_ids); ArrayClear(this.m_objects);
        return true;
    }
    public func IsActive() -> Bool { return this.m_active; }
    public func GetRunGeneration() -> Int32 { return this.m_generation; }
    public func GetReturnPosition() -> Vector4 { return this.m_return; }
    public func GetReturnYaw() -> Float { return this.m_returnYaw; }
    public func GetCreatedCount() -> Int32 { return ArraySize(this.m_created); }
    public func GetCreatedID(index: Int32) -> EntityID {
        let empty: EntityID;
        if index >= 0 && index < ArraySize(this.m_created) { return this.m_created[index]; };
        return empty;
    }
    public func TrackCreatedID(id: EntityID) -> Bool {
        let empty: EntityID;
        if !this.SamePlayer() || id == empty || ArraySize(this.m_created) >= 10 { return false; };
        if !ArrayContains(this.m_created, id) { ArrayPush(this.m_created, id); };
        return true;
    }
    public func SetOrigin(point: Vector4) -> Bool {
        if !this.SamePlayer() || ArraySize(this.m_created) > 0 || point.X != point.X || point.Y != point.Y || point.Z != point.Z { return false; };
        this.m_origin = point; return true;
    }
    public func Orientation(yaw: Float) -> Quaternion {
        let angle: EulerAngles;
        angle.Roll = 0.0; angle.Pitch = 0.0; angle.Yaw = yaw;
        return EulerAngles.ToQuat(angle);
    }
    public func MovePlayer(point: Vector4, yaw: Float) -> Bool {
        let angle: EulerAngles;
        let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
        if !this.SamePlayer() || player.IsDead() || VehicleComponent.IsMountedToVehicle(this.GetGameInstance(), player)
            || ArraySize(this.m_created) > 0 || point.X != point.X || point.Y != point.Y || point.Z != point.Z || yaw != yaw { return false; };
        angle.Roll = 0.0; angle.Pitch = 0.0; angle.Yaw = yaw;
        GameInstance.GetTeleportationFacility(this.GetGameInstance()).Teleport(player, point, angle);
        return true;
    }
    private func AddActor(object: ref<GameObject>) -> Bool {
        let god: ref<GodModeSystem> = GameInstance.GetGodModeSystem(this.GetGameInstance());
        if !this.SamePlayer() || !this.CanRun() || !IsDefined(object) || !object.IsAttached() || !IsDefined(god)
            || Vector4.Distance(object.GetWorldPosition(), this.m_origin) > 35.0 { return false; };
        if ArrayContains(this.m_ids, object.GetEntityID()) { return true; };
        if ArraySize(this.m_ids) >= 10 || !god.AddGodMode(object.GetEntityID(), gameGodModeType.Invulnerable, n"NCPDPatrolSurveyActors") { return false; };
        ArrayPush(this.m_ids, object.GetEntityID()); ArrayPush(this.m_objects, object);
        return true;
    }
    public func ProtectVehicle(vehicle: ref<VehicleObject>) -> Bool {
        if !IsDefined(vehicle) || (vehicle.GetRecordID() != t"Vehicle.NCPDPatrol_OD_Police" && vehicle.GetRecordID() != t"Vehicle.NCPDPatrol_OD_GangCar") { return false; };
        return this.AddActor(vehicle);
    }
    public func ProtectNPC(npc: ref<NPCPuppet>) -> Bool {
        let record: TweakDBID;
        let already: Bool;
        if !IsDefined(npc) { return false; };
        record = npc.GetRecordID();
        if record != t"Character.NCPDPatrol_OD_Injured" && record != t"Character.NCPDPatrol_OD_Defender" && record != t"Character.NCPDPatrol_OD_Ganger" { return false; };
        already = ArrayContains(this.m_ids, npc.GetEntityID());
        if !this.AddActor(npc) { return false; };
        if !already && record == t"Character.NCPDPatrol_OD_Injured" {
            npc.SetIsDefeatMechanicActive(false);
            GameInstance.GetStatPoolsSystem(this.GetGameInstance()).RequestSettingStatPoolValue(Cast<StatsObjectID>(npc.GetEntityID()), gamedataStatPoolType.Health, 10.0, null, true);
            StatusEffectHelper.ApplyStatusEffect(npc, t"BaseStatusEffect.NCPDPatrolOfficerDown");
        };
        return true;
    }
    public func EndActors() -> Bool {
        let i: Int32 = 0;
        let god: ref<GodModeSystem> = GameInstance.GetGodModeSystem(this.GetGameInstance());
        let npc: wref<NPCPuppet>;
        if !this.SamePlayer() || !IsDefined(god) { return false; };
        while i < ArraySize(this.m_ids) {
            god.RemoveGodMode(this.m_ids[i], gameGodModeType.Invulnerable, n"NCPDPatrolSurveyActors");
            npc = this.m_objects[i] as NPCPuppet;
            if IsDefined(npc) && npc.IsAttached() && npc.GetRecordID() == t"Character.NCPDPatrol_OD_Injured" {
                StatusEffectHelper.RemoveStatusEffect(npc, t"BaseStatusEffect.NCPDPatrolOfficerDown");
            };
            i += 1;
        };
        ArrayClear(this.m_ids); ArrayClear(this.m_objects); ArrayClear(this.m_created);
        return true;
    }
    public func Finish() -> Bool {
        let god: ref<GodModeSystem> = GameInstance.GetGodModeSystem(this.GetGameInstance());
        if !this.SamePlayer() || ArraySize(this.m_created) > 0 || !IsDefined(god) { return false; };
        god.RemoveGodMode(this.m_player, gameGodModeType.Invulnerable, n"NCPDPatrolSurveyPlayer");
        this.Forget(); return true;
    }
}
