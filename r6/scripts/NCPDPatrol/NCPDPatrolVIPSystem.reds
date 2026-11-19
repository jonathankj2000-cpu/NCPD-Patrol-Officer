// Two-stage escort: progress requires actual mounting and a live VIP drop-off.
// No scanner/career/reward ledger is written by this first encounter prototype.
public class NCPDPatrolVIPSystem extends ScriptableSystem {
    // 0 idle, 1 pickup, 2 transport, 3 succeeded,
    // 4 failed, 5 cancelled, 6 journal error.
    private let m_stage: Int32;
    private let m_token: Int32;
    private let m_target: wref<NPCPuppet>;
    private let m_origin: Vector4;
    private let m_destination: Vector4;
    private let m_vehicle: wref<VehicleObject>;
    private let m_dropStarted: Bool;
    private let m_missing: Float;
    private let m_away: Float;
    private let m_age: Float;
    private let m_remaining: Float;
    private let m_arrived: Bool;
    private let m_reason: String;
    private let m_restorePending: Bool;
    private let m_previousTracked: wref<JournalEntry>;

    public static func Get(game: GameInstance) -> ref<NCPDPatrolVIPSystem> {
        return GameInstance.GetScriptableSystemsContainer(game).Get(n"NCPDPatrolVIPSystem") as NCPDPatrolVIPSystem;
    }
    public func Version() -> Int32 { return 3; }
    // A conservative sphere encloses the Hella and the temporary crew spawn
    // positions. Reject any overlap with the active camera's padded frustum.
    // Native script owns the camera transform's output parameter.
    public func CanSpawnAmbushAt(position: Vector4) -> Bool {
        let camera: ref<CameraSystem>;
        let transform: Transform;
        let origin: Vector4;
        let forward: Vector4;
        let right: Vector4;
        let up: Vector4;
        let x: Float;
        let y: Float;
        let z: Float;
        let depth: Float;
        let horizontal: Float;
        let vertical: Float;
        let fov: Float;
        let aspect: Float;
        let tangent: Float;
        let horizontalTangent: Float;
        let radius: Float = 12.0;
        if this.m_stage != 2 || !this.Eligible() { return false; };
        if position.X != position.X || position.Y != position.Y || position.Z != position.Z
            || AbsF(position.X) > 100000.0 || AbsF(position.Y) > 100000.0 || AbsF(position.Z) > 100000.0 { return false; };
        camera = GameInstance.GetCameraSystem(this.GetGameInstance());
        if !IsDefined(camera) || !camera.GetActiveCameraWorldTransform(transform) { return false; };
        origin = Transform.GetPosition(transform);
        forward = Transform.GetForward(transform);
        right = Transform.GetRight(transform);
        up = Transform.GetUp(transform);
        fov = camera.GetActiveCameraFOV(); aspect = camera.GetAspectRatio();
        if fov != fov || aspect != aspect || fov <= 1.0 || fov >= 175.0 || aspect < 0.25 || aspect > 8.0 { return false; };
        // Treat FOV as vertical and never shrink for portrait aspect. This is
        // deliberately wider if a camera reports horizontal FOV instead.
        tangent = TanF(Deg2Rad(fov * 0.50 + 2.0));
        horizontalTangent = tangent * MaxF(1.0, aspect);
        x = position.X - origin.X; y = position.Y - origin.Y; z = position.Z + 1.0 - origin.Z;
        depth = x * forward.X + y * forward.Y + z * forward.Z;
        horizontal = x * right.X + y * right.Y + z * right.Z;
        vertical = x * up.X + y * up.Y + z * up.Z;
        // Invalid camera output never becomes permission to spawn.
        if depth != depth || horizontal != horizontal || vertical != vertical { return false; };
        if depth < -radius { return true; };
        if AbsF(horizontal) - depth * horizontalTangent > radius * SqrtF(1.0 + horizontalTangent * horizontalTangent) { return true; };
        if AbsF(vertical) - depth * tangent > radius * SqrtF(1.0 + tangent * tangent) { return true; };
        return false;
    }
    private func OnAttach() -> Void { this.ForgetWorld(); }
    private func OnRestored(saveVersion: Int32, gameVersion: Int32) -> Void { this.ForgetWorld(); }
    private func ForgetWorld() -> Void {
        this.m_stage = 0; this.m_token += 1; this.m_target = null;
        this.m_missing = 0.0; this.m_away = 0.0; this.m_age = 0.0;
        this.m_remaining = 0.0; this.m_arrived = false;
        this.m_reason = "VIP transport ready";
        this.m_vehicle = null; this.m_dropStarted = false;
        this.m_restorePending = true; this.m_previousTracked = null;
    }
    private func Journal() -> ref<JournalManager> {
        return GameInstance.GetJournalManager(this.GetGameInstance());
    }
    private func QuestPath() -> String { return "quests/minor_quest/ncpd_patrol_vip"; }
    private func PhasePath() -> String { return "quests/minor_quest/ncpd_patrol_vip/main"; }
    private func ObjectivePath() -> String { return "quests/minor_quest/ncpd_patrol_vip/main/deliver"; }
    private func DescriptionPath() -> String { return "quests/minor_quest/ncpd_patrol_vip/main/deliver/briefing"; }
    private func ResponsePath() -> String { return "quests/minor_quest/ncpd_patrol_vip/main/pickup"; }
    private func ResponseDescriptionPath() -> String { return "quests/minor_quest/ncpd_patrol_vip/main/pickup/briefing"; }
    private func Running() -> Bool { return this.m_stage == 1 || this.m_stage == 2; }
    private func ActiveObjectivePath() -> String {
        if this.m_stage == 1 { return this.ResponsePath(); };
        return this.ObjectivePath();
    }
    private func Eligible() -> Bool {
        let patrol: ref<NCPDPatrolSystem> = NCPDPatrolSystem.Get(this.GetGameInstance());
        let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
        return IsDefined(patrol) && patrol.IsOnDuty() && !patrol.HasWantedLevel()
            && IsDefined(player) && player.IsAttached() && !player.IsDead();
    }
    private func Entry(path: String, kind: String) -> wref<JournalEntry> {
        let journal: ref<JournalManager> = this.Journal();
        if !IsDefined(journal) { return null; };
        return journal.GetEntryByString(path, kind);
    }
    public func IsReady() -> Bool {
        return IsDefined(this.Entry(this.QuestPath(), "gameJournalQuest"))
            && IsDefined(this.Entry(this.PhasePath(), "gameJournalQuestPhase"))
            && IsDefined(this.Entry(this.ObjectivePath(), "gameJournalQuestObjective"))
            && IsDefined(this.Entry(this.DescriptionPath(), "gameJournalQuestDescription"))
            && IsDefined(this.Entry(this.ResponsePath(), "gameJournalQuestObjective"))
            && IsDefined(this.Entry(this.ResponseDescriptionPath(), "gameJournalQuestDescription"));
    }
    private func State(path: String, kind: String) -> gameJournalEntryState {
        let entry: wref<JournalEntry> = this.Entry(path, kind);
        if !IsDefined(entry) { return gameJournalEntryState.Undefined; };
        return this.Journal().GetEntryState(entry);
    }
    private func Write(path: String, kind: String, state: gameJournalEntryState, opt notify: Bool) -> Bool {
        let entry: wref<JournalEntry> = this.Entry(path, kind);
        let option: JournalNotifyOption = JournalNotifyOption.DoNotNotify;
        if !IsDefined(entry) { return false; };
        if Equals(this.State(path, kind), state) { return true; };
        if notify { option = JournalNotifyOption.Notify; };
        if !this.Journal().ChangeEntryState(path, kind, state, option) { return false; };
        return Equals(this.State(path, kind), state);
    }
    private func OursTracked() -> Bool {
        let journal: ref<JournalManager> = this.Journal();
        let entry: wref<JournalEntry>;
        if !IsDefined(journal) { return false; };
        entry = journal.GetTrackedEntry();
        return IsDefined(entry) && (entry == this.Entry(this.QuestPath(), "gameJournalQuest")
            || entry == this.Entry(this.PhasePath(), "gameJournalQuestPhase")
            || entry == this.Entry(this.ResponsePath(), "gameJournalQuestObjective")
            || entry == this.Entry(this.ObjectivePath(), "gameJournalQuestObjective"));
    }
    private func RestoreTracking(wasOurs: Bool) -> Void {
        if wasOurs && IsDefined(this.m_previousTracked) && IsDefined(this.Journal())
            && Equals(this.Journal().GetEntryState(this.m_previousTracked), gameJournalEntryState.Active) {
            this.Journal().TrackEntry(this.m_previousTracked);
        };
        this.m_previousTracked = null;
    }
    private func HideJournal() -> Bool {
        let ok: Bool = this.Write(this.ObjectivePath(), "gameJournalQuestObjective", gameJournalEntryState.Inactive);
        if !this.Write(this.DescriptionPath(), "gameJournalQuestDescription", gameJournalEntryState.Inactive) { ok = false; };
        if !this.Write(this.ResponsePath(), "gameJournalQuestObjective", gameJournalEntryState.Inactive) { ok = false; };
        if !this.Write(this.ResponseDescriptionPath(), "gameJournalQuestDescription", gameJournalEntryState.Inactive) { ok = false; };
        if !this.Write(this.PhasePath(), "gameJournalQuestPhase", gameJournalEntryState.Inactive) { ok = false; };
        if !this.Write(this.QuestPath(), "gameJournalQuest", gameJournalEntryState.Inactive) { ok = false; };
        return ok;
    }
    private func ReconcileLoadedJournal() -> Void {
        if !this.m_restorePending || !this.IsReady() { return; };
        if Equals(this.State(this.QuestPath(), "gameJournalQuest"), gameJournalEntryState.Active)
            || Equals(this.State(this.ResponsePath(), "gameJournalQuestObjective"), gameJournalEntryState.Active)
            || Equals(this.State(this.ObjectivePath(), "gameJournalQuestObjective"), gameJournalEntryState.Active) {
            if !this.HideJournal() { this.m_reason = "Loaded VIP journal could not close"; return; };
        };
        this.m_restorePending = false;
    }
    public func IsVIPReady(npc: ref<NPCPuppet>) -> Bool {
        return IsDefined(npc) && Equals(npc.GetRecordID(), t"Character.NCPDPatrol_VIP")
            && npc.IsAttached() && !npc.IsDead() && !npc.IsDeadNoStatPool()
            && !ScriptedPuppet.IsDefeated(npc) && !ScriptedPuppet.IsUnconscious(npc);
    }
    public func BeginDispatch(pickup: Vector4, destination: Vector4) -> Int32 {
        let distance: Float;
        let responseDistance: Float;
        let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
        if !this.Eligible() || this.Running() || !this.IsReady() { return 0; };
        distance = Vector4.Distance(player.GetWorldPosition(), pickup);
        if distance != distance || distance < 250.0 || distance > 5000.0 { return 0; };
        responseDistance = distance;
        distance = Vector4.Distance(pickup, destination);
        if distance != distance || distance < 500.0 || distance > 5000.0 { return 0; };
        this.ReconcileLoadedJournal();
        if this.m_restorePending { return 0; };
        this.m_previousTracked = null;
        if !this.OursTracked() { this.m_previousTracked = this.Journal().GetTrackedEntry(); };
        if !this.HideJournal() { this.m_reason = "VIP journal reset rejected"; this.m_previousTracked = null; return 0; };
        if !this.Write(this.QuestPath(), "gameJournalQuest", gameJournalEntryState.Active, true)
            || !this.Write(this.PhasePath(), "gameJournalQuestPhase", gameJournalEntryState.Active)
            || !this.Write(this.ResponseDescriptionPath(), "gameJournalQuestDescription", gameJournalEntryState.Active)
            || !this.Write(this.ResponsePath(), "gameJournalQuestObjective", gameJournalEntryState.Active) {
            this.HideJournal(); this.m_previousTracked = null; this.m_reason = "VIP journal activation rejected"; return 0;
        };
        this.m_token += 1; this.m_target = null; this.m_vehicle = null;
        this.m_origin = pickup; this.m_destination = destination; this.m_dropStarted = false;
        this.m_arrived = false;
        this.m_stage = 1; this.m_missing = 0.0; this.m_away = 0.0; this.m_age = 0.0; this.m_remaining = 300.0;
        if responseDistance > 2000.0 { this.m_remaining = 300.0 + (responseDistance - 2000.0) / 10.0; };
        this.m_reason = "Collect the protected witness in an owned police vehicle";
        this.Journal().TrackEntry(this.Entry(this.ResponsePath(), "gameJournalQuestObjective"));
        return this.m_token;
    }
    public func CanSpawn(token: Int32) -> Bool {
        let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
        return token == this.m_token && this.m_stage == 1 && !IsDefined(this.m_target) && this.Eligible()
            && Vector4.Distance(player.GetWorldPosition(), this.m_origin) <= 140.0;
    }
    public func BindVIP(token: Int32, npc: ref<NPCPuppet>) -> Bool {
        if !this.CanSpawn(token) || !this.IsVIPReady(npc)
            || Vector4.Distance(npc.GetWorldPosition(), this.m_origin) > 50.0 { return false; };
        this.m_target = npc;
        this.m_arrived = true;
        this.m_reason = "Witness located. Stop nearby in an owned police car with a free passenger seat";
        return true;
    }
    public func CanUseVehicle(vehicle: ref<VehicleObject>) -> Bool {
        let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
        let patrol: ref<NCPDPatrolSystem> = NCPDPatrolSystem.Get(this.GetGameInstance());
        let info: MountingInfo;
        if !this.Eligible() || !IsDefined(vehicle) || !vehicle.IsAttached() || vehicle.IsDestroyed()
            || !patrol.IsOwnedPoliceVehicle(vehicle) || GetMountedVehicle(player) != vehicle { return false; };
        info = GameInstance.GetMountingFacility(this.GetGameInstance()).GetMountingInfoSingleWithObjects(player);
        return Equals(info.slotId.id, n"seat_front_left");
    }
    public func ConfirmBoarded(token: Int32, vehicle: ref<VehicleObject>) -> Bool {
        let wasOurs: Bool;
        if token != this.m_token || this.m_stage != 1 || !this.IsVIPReady(this.m_target)
            || !this.CanUseVehicle(vehicle) || GetMountedVehicle(this.m_target) != vehicle { return false; };
        wasOurs = this.OursTracked();
        if !this.Write(this.ResponsePath(), "gameJournalQuestObjective", gameJournalEntryState.Succeeded)
            || !this.Write(this.ResponseDescriptionPath(), "gameJournalQuestDescription", gameJournalEntryState.Inactive)
            || !this.Write(this.DescriptionPath(), "gameJournalQuestDescription", gameJournalEntryState.Active)
            || !this.Write(this.ObjectivePath(), "gameJournalQuestObjective", gameJournalEntryState.Active) {
            this.Fail(token, "VIP objective transition rejected"); return false;
        };
        this.m_vehicle = vehicle; this.m_stage = 2; this.m_age = 0.0; this.m_remaining = 900.0;
        this.m_reason = "Witness aboard. Deliver the VIP alive to the marked safe location";
        if wasOurs { this.Journal().TrackEntry(this.Entry(this.ObjectivePath(), "gameJournalQuestObjective")); };
        return true;
    }
    public func CanDropOff(token: Int32) -> Bool {
        let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
        return token == this.m_token && this.m_stage == 2 && this.Eligible() && this.IsVIPReady(this.m_target)
            && IsDefined(this.m_vehicle) && this.m_vehicle.IsAttached() && !this.m_vehicle.IsDestroyed()
            && GetMountedVehicle(this.m_target) == this.m_vehicle
            && AbsF(this.m_vehicle.GetCurrentSpeed()) < 1.0
            && Vector4.Distance(this.m_vehicle.GetWorldPosition(), this.m_destination) <= 30.0
            && Vector4.Distance(player.GetWorldPosition(), this.m_destination) <= 40.0;
    }
    public func BeginDropOff(token: Int32) -> Bool {
        if !this.CanDropOff(token) { return false; };
        this.m_dropStarted = true; this.m_reason = "Stop here while the witness exits the vehicle";
        return true;
    }
    private func Finish(result: Int32, reason: String) -> Void {
        let state: gameJournalEntryState = gameJournalEntryState.Succeeded;
        let wasOurs: Bool = this.OursTracked();
        let ok: Bool;
        if result == 4 { state = gameJournalEntryState.Failed; };
        ok = this.Write(this.ActiveObjectivePath(), "gameJournalQuestObjective", state);
        if !this.Write(this.PhasePath(), "gameJournalQuestPhase", state) { ok = false; };
        if !this.Write(this.QuestPath(), "gameJournalQuest", state, true) { ok = false; };
        this.m_stage = result; this.m_remaining = 0.0; this.m_reason = reason;
        if !ok { this.m_stage = 6; this.m_reason = "VIP journal result rejected"; this.HideJournal(); };
        this.RestoreTracking(wasOurs);
    }
    public func Fail(token: Int32, reason: String) -> Void {
        if token == this.m_token && this.Running() { this.Finish(4, reason); };
    }
    public func Cancel(token: Int32, reason: String) -> Void {
        let wasOurs: Bool;
        let patrol: ref<NCPDPatrolSystem> = NCPDPatrolSystem.Get(this.GetGameInstance());
        if token != this.m_token || !this.Running() { return; };
        if IsDefined(patrol) && patrol.HasWantedLevel() { this.Finish(4, "Shift terminated due to criminal activity"); return; };
        wasOurs = this.OursTracked(); this.m_stage = 5; this.m_remaining = 0.0; this.m_reason = reason;
        if !this.HideJournal() { this.m_stage = 6; this.m_reason = "VIP journal cancellation rejected"; };
        this.RestoreTracking(wasOurs);
    }
    public func Tick(delta: Float) -> Void {
        let patrol: ref<NCPDPatrolSystem> = NCPDPatrolSystem.Get(this.GetGameInstance());
        let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
        let mounted: wref<VehicleObject>;
        if !IsDefined(player) || !player.IsAttached() || !IsDefined(patrol) { return; };
        this.ReconcileLoadedJournal();
        if !this.Running() { return; };
        if patrol.HasWantedLevel() || player.IsDead() { this.Finish(4, "Shift terminated or officer down"); return; };
        if !this.Eligible() { this.Cancel(this.m_token, "Shift ended"); return; };
        if patrol.IsDispatchMenuOpen() || delta <= 0.0 || delta > 0.50 { return; };
        this.m_age += delta; this.m_remaining -= delta;
        if this.m_remaining <= 0.0 { this.Finish(4, "VIP transport time exceeded"); return; };
        if this.m_age >= 1.0 && (!Equals(this.State(this.QuestPath(), "gameJournalQuest"), gameJournalEntryState.Active)
            || !Equals(this.State(this.ActiveObjectivePath(), "gameJournalQuestObjective"), gameJournalEntryState.Active)) {
            this.Finish(4, "Active VIP journal state lost"); return;
        };
        if !IsDefined(this.m_target) {
            if this.m_arrived {
                this.m_missing += delta;
                if this.m_missing >= 8.0 { this.Finish(4, "VIP unavailable"); };
            };
            return;
        };
        if !this.m_target.IsAttached() {
            this.m_missing += delta;
            if this.m_missing >= 8.0 { this.Finish(4, "VIP unavailable"); };
            return;
        };
        this.m_missing = 0.0;
        if !this.IsVIPReady(this.m_target) { this.Finish(4, "Protected witness killed or incapacitated"); return; };
        if Vector4.Distance(player.GetWorldPosition(), this.m_target.GetWorldPosition()) > 200.0 {
            this.m_away += delta;
            if this.m_away >= 10.0 { this.Finish(4, "Protected witness abandoned"); };
            return;
        };
        this.m_away = 0.0;
        if this.m_stage == 1 { return; };
        if !IsDefined(this.m_vehicle) || !this.m_vehicle.IsAttached() || this.m_vehicle.IsDestroyed() {
            this.Finish(4, "Transport vehicle unavailable"); return;
        };
        mounted = GetMountedVehicle(this.m_target);
        if IsDefined(mounted) && mounted != this.m_vehicle { this.Finish(4, "VIP entered a different vehicle"); return; };
        if this.m_dropStarted && !IsDefined(mounted)
            && Vector4.Distance(this.m_target.GetWorldPosition(), this.m_destination) <= 35.0
            && Vector4.Distance(player.GetWorldPosition(), this.m_destination) <= 50.0 {
            this.Finish(3, "Protected witness delivered safely");
        };
    }
    public func GetStage() -> Int32 { return this.m_stage; }
    public func GetToken() -> Int32 { return this.m_token; }
    public func GetRemainingSeconds() -> Int32 { return CeilF(MaxF(0.0, this.m_remaining)); }
    public func GetReason() -> String { return this.m_reason; }
    public func GetDiagnostics() -> String {
        let ready: Bool = this.IsReady();
        let alive: Bool = this.IsVIPReady(this.m_target);
        return s"ready=\(ready) | stage=\(this.m_stage) | token=\(this.m_token) | VIP alive=\(alive) | drop started=\(this.m_dropStarted) | \(this.m_reason)";
    }
}
