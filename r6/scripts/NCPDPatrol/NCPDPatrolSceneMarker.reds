// One authored, fixed quest pin. Engine-owned instances are deactivated/reused,
// never unregistered. No actors, rewards or manual-waypoint writes.
public class NCPDPatrolSceneMarker extends IScriptable {
    private let m_objective: String;
    private let m_phase: String;
    private let m_path: String;
    private let m_target: Vector4;
    private let m_hash: Uint32;
    private let m_before: NewMappinID;
    private let m_after: NewMappinID;
    private let m_id: NewMappinID;
    private let m_confirmed: Bool;
    private let m_count: Int32;
    private let m_attempts: Int32;
    private let m_poll: Float;
    public func Configure(objective: String, phase: String, target: Vector4) -> Void {
        this.m_objective = objective; this.m_phase = phase;
        this.m_path = s"\(objective)/location"; this.m_target = target;
        this.m_hash = NCPDPatrolFixedMarkerCatalog.PathHash(this.m_path);
    }
    private func Write(game: GameInstance, active: Bool) -> Void {
        let journal: ref<JournalManager> = GameInstance.GetJournalManager(game);
        let node: ref<questMappinManagerNodeDefinition>;
        let path: ref<gameJournalPath>;
        let quests: ref<QuestsSystem> = GameInstance.GetQuestsSystem(game);
        if !IsDefined(journal) || !IsDefined(quests) || !IsDefined(journal.GetEntryByString(this.m_path, "gameJournalQuestMapPin")) { return; };
        path = new gameJournalPath(); path.realPath = this.m_path;
        path.fileEntryIndex = 1; path.className = n"gameJournalQuestMapPin";
        node = new questMappinManagerNodeDefinition(); node.id = Cast<Uint16>(0);
        node.path = path; node.disablePreviousMappins = false;
        if active { quests.ExecuteNode(node, n"Active"); } else { quests.ExecuteNode(node, n"Inactive"); };
    }
    public func Open(game: GameInstance) -> Void {
        let map: ref<MappinSystem> = GameInstance.GetMappinSystem(game);
        if !NCPDPatrolMarkerSession.WorldReady() || !IsDefined(map) { return; };
        this.m_before = map.GetManuallyTrackedMappinID();
        this.Write(game, true); this.m_after = map.GetManuallyTrackedMappinID();
        this.m_attempts += 1; this.m_poll = 0.0;
    }
    public func Close(game: GameInstance) -> Void {
        let map: ref<MappinSystem> = GameInstance.GetMappinSystem(game);
        let pins: array<ref<IMappin>>;
        let pin: ref<QuestMappin>;
        let i: Int32 = 0;
        if !NCPDPatrolMarkerSession.WorldReady() || !IsDefined(map) { return; };
        this.Write(game, false); pins = map.GetAllMappins();
        while i < ArraySize(pins) {
            pin = pins[i] as QuestMappin;
            if IsDefined(pin) && pin.GetJournalPathHash() == this.m_hash && pin.IsActive() {
                map.SetMappinActive(pin.GetNewMappinID(), false);
            };
            i += 1;
        };
        this.m_confirmed = false; this.m_count = 0;
    }
    public func Tick(game: GameInstance, delta: Float) -> Void {
        let map: ref<MappinSystem> = GameInstance.GetMappinSystem(game);
        let journal: ref<JournalManager> = GameInstance.GetJournalManager(game);
        let pins: array<ref<IMappin>>;
        let pin: ref<QuestMappin>;
        let selected: ref<QuestMappin>;
        let linked: wref<IMappin>;
        let linkedID: NewMappinID;
        let point: Vector3;
        let world: Vector4;
        let known: Bool;
        let i: Int32 = 0;
        this.m_confirmed = false; this.m_count = 0;
        if !NCPDPatrolMarkerSession.WorldReady() || !IsDefined(map) || !IsDefined(journal) { return; };
        pins = map.GetAllMappins();
        while i < ArraySize(pins) {
            pin = pins[i] as QuestMappin;
            if IsDefined(pin) && pin.GetJournalPathHash() == this.m_hash {
                selected = pin;
                if pin.IsActive() { this.m_count += 1; this.m_id = pin.GetNewMappinID(); };
            };
            i += 1;
        };
        if this.m_count == 0 && IsDefined(selected) && !selected.IsActive() && Vector4.Distance(selected.GetWorldPosition(), this.m_target) <= 2.0 {
            map.SetMappinActive(selected.GetNewMappinID(), true);
        };
        linked = map.GetMappinFromObjective(journal.GetEntryByString(this.m_phase, "gameJournalQuestPhase"), journal.GetEntryByString(this.m_objective, "gameJournalQuestObjective"));
        if IsDefined(linked) { linkedID = linked.GetNewMappinID(); };
        known = map.GetQuestMappinPosition(this.m_hash, point);
        world.X = point.X; world.Y = point.Y; world.Z = point.Z; world.W = 1.0;
        this.m_confirmed = this.m_count == 1 && IsDefined(selected) && IsDefined(linked)
            && linkedID.value == this.m_id.value
            && Vector4.Distance(selected.GetWorldPosition(), this.m_target) <= 2.0
            && known && Vector4.Distance(world, this.m_target) <= 2.0
            && this.m_before.value == this.m_after.value;
        this.m_poll += delta;
        if this.m_count == 0 && this.m_poll >= 1.0 && this.m_attempts < 6 { this.Open(game); };
    }
    public func GetDiagnostics() -> String {
        return s"native confirmed=\(this.m_confirmed) | active pins=\(this.m_count) | pin ID=\(this.m_id.value) | activation attempts=\(this.m_attempts) | hash=\(this.m_hash) | manual before/after=\(this.m_before.value)/\(this.m_after.value)";
    }
}
