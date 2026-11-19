// Explicit CET experiment only. Own journal/marker scope; no incident or money API.
public class NCPDPatrolQuestMarkerProbeSystem extends ScriptableSystem {
    private let m_requested: Bool;
    private let m_cleanup: Bool;
    private let m_restorePending: Bool;
    private let m_confirmed: Bool;
    private let m_anchor: wref<GameObject>;
    private let m_target: Vector4;
    private let m_node: ref<questMappinManagerNodeDefinition>;
    private let m_previousTracked: wref<JournalEntry>;
    private let m_beforeCreate: NewMappinID;
    private let m_afterCreate: NewMappinID;
    private let m_beforeRemove: NewMappinID;
    private let m_afterRemove: NewMappinID;
    private let m_lastMarker: NewMappinID;
    private let m_pathHash: Uint32;
    private let m_pinCount: Int32;
    private let m_positionOK: Bool;
    private let m_linked: Bool;
    private let m_mode: Int32;
    private let m_poll: Float;
    private let m_elapsed: Float;
    private let m_revision: Int32;
    private let m_reason: String;

    protected cb func OnAttach() -> Bool { this.ForgetWorld(); return true; }
    protected cb func OnRestored(saveVersion: Int32, gameVersion: Int32) -> Bool { this.ForgetWorld(); return true; }
    private func ForgetWorld() -> Void {
        this.m_requested = false; this.m_cleanup = false; this.m_confirmed = false;
        this.m_anchor = null; this.m_node = null; this.m_previousTracked = null;
        this.m_pinCount = 0; this.m_positionOK = false; this.m_linked = false;
        this.m_poll = 0.0; this.m_elapsed = 0.0; this.m_restorePending = true;
        this.Report("Quest marker experiment ready (off duty only)");
    }
    public func Version() -> Int32 { return 1; }
    public func GetAnchorTemplate() -> ResRef { return r"base\\ncpd_patrol\\quest_marker_probe\\probe_anchor.ent"; }
    private func Root() -> String { return "quests/minor_quest/ncpd_patrol_marker_probe"; }
    private func PhasePath() -> String { return this.Root() + "/main"; }
    private func ObjectivePath() -> String { return this.PhasePath() + "/inspect"; }
    private func PinPath() -> String { return this.ObjectivePath() + "/location"; }
    private func Journal() -> ref<JournalManager> { return GameInstance.GetJournalManager(this.GetGameInstance()); }
    private func Map() -> ref<MappinSystem> { return GameInstance.GetMappinSystem(this.GetGameInstance()); }
    private func Entry(path: String, kind: String) -> wref<JournalEntry> {
        let journal: ref<JournalManager> = this.Journal();
        if IsDefined(journal) { return journal.GetEntryByString(path, kind); };
        return null;
    }
    public func IsReady() -> Bool {
        return IsDefined(this.Entry(this.Root(), "gameJournalQuest"))
            && IsDefined(this.Entry(this.PhasePath(), "gameJournalQuestPhase"))
            && IsDefined(this.Entry(this.ObjectivePath(), "gameJournalQuestObjective"))
            && IsDefined(this.Entry(this.PinPath(), "gameJournalQuestMapPin"));
    }
    private func Report(reason: String) -> Void {
        if NotEquals(reason, this.m_reason) { this.m_revision += 1; this.m_reason = reason; };
    }
    private func Write(path: String, kind: String, state: gameJournalEntryState) -> Bool {
        let journal: ref<JournalManager> = this.Journal();
        let entry: wref<JournalEntry> = this.Entry(path, kind);
        if !IsDefined(journal) || !IsDefined(entry) { return false; };
        if Equals(journal.GetEntryState(entry), state) { return true; };
        if journal.ChangeEntryState(path, kind, state, JournalNotifyOption.DoNotNotify) { return true; };
        return Equals(journal.GetEntryState(entry), state);
    }
    private func PinHash() -> Uint32 {
        let entry: wref<JournalEntry> = this.Entry(this.PinPath(), "gameJournalQuestMapPin");
        if IsDefined(entry) { return Cast<Uint32>(this.Journal().GetEntryHash(entry)); };
        return 0u;
    }
    private func MakeNode() -> ref<questMappinManagerNodeDefinition> {
        let path: ref<gameJournalPath> = new gameJournalPath();
        let node: ref<questMappinManagerNodeDefinition> = new questMappinManagerNodeDefinition();
        path.realPath = this.PinPath(); path.className = n"gameJournalQuestMapPin"; path.fileEntryIndex = -1;
        node.id = 0; node.path = path; node.disablePreviousMappins = false;
        this.m_pathHash = path.GetHash();
        return node;
    }
    private func RuntimeAllowed() -> Bool {
        let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
        let patrol: ref<NCPDPatrolSystem> = NCPDPatrolSystem.Get(this.GetGameInstance());
        return IsDefined(player) && player.IsAttached() && !player.IsDead() && !player.IsInCombat()
            && IsDefined(patrol) && !patrol.IsOnDuty() && !patrol.HasWantedLevel();
    }
    public func Begin(anchor: ref<GameObject>, target: Vector4, mode: Int32) -> Bool {
        let journal: ref<JournalManager> = this.Journal();
        let map: ref<MappinSystem> = this.Map();
        let quests: ref<QuestsSystem> = GameInstance.GetQuestsSystem(this.GetGameInstance());
        if this.m_requested || this.m_cleanup { this.Report("Remove the current probe before starting another"); return false; };
        if !this.RuntimeAllowed() { this.Report("Load a save; run this experiment off duty, outside menus/combat/wanted status"); return false; };
        if NCPDPatrolSystem.Get(this.GetGameInstance()).IsDispatchMenuOpen() { this.Report("Close game menus before starting the probe"); return false; };
        if !this.IsReady() || !IsDefined(map) || !IsDefined(quests) { this.Report("Probe journal or quest/map API unavailable; install the complete marker-test package and restart"); return false; };
        if !IsDefined(anchor) || Vector4.Distance(anchor.GetWorldPosition(), target) > 2.0 { this.Report("Private stationary anchor not confirmed at the test position"); return false; };
        this.m_beforeCreate = map.GetManuallyTrackedMappinID();
        this.m_previousTracked = journal.GetTrackedEntry();
        if !this.Write(this.Root(), "gameJournalQuest", gameJournalEntryState.Active)
            || !this.Write(this.PhasePath(), "gameJournalQuestPhase", gameJournalEntryState.Active)
            || !this.Write(this.ObjectivePath(), "gameJournalQuestObjective", gameJournalEntryState.Active)
            || !this.Write(this.PinPath(), "gameJournalQuestMapPin", gameJournalEntryState.Active) {
            this.Stop("Probe journal activation rejected"); return false;
        };
        this.m_restorePending = false; this.m_requested = true; this.m_confirmed = false;
        this.m_anchor = anchor; this.m_target = target; this.m_mode = mode;
        this.m_elapsed = 0.0; this.m_poll = 0.0;
        journal.TrackEntry(this.Entry(this.ObjectivePath(), "gameJournalQuestObjective"));
        this.m_node = this.MakeNode();
        if mode == 1 { quests.ExecuteNode(this.m_node, n"Enable"); } else {
            if mode == 2 { quests.ExecuteNode(this.m_node, n"In"); } else {
                quests.ExecuteNode(this.m_node);
            };
        };
        this.m_afterCreate = map.GetManuallyTrackedMappinID();
        this.Report("Native mappin node requested; awaiting actual QuestMappin + journal link + fixed-position proof");
        this.Inspect();
        return true;
    }
    private func Inspect() -> Void {
        let map: ref<MappinSystem> = this.Map();
        let pins: array<ref<IMappin>>;
        let pin: ref<QuestMappin>;
        let linked: wref<IMappin>;
        let expected: Uint32 = this.PinHash();
        let i: Int32 = 0;
        if !IsDefined(map) || expected == 0u { return; };
        pins = map.GetAllMappins(); this.m_pinCount = 0; this.m_positionOK = false; this.m_linked = false;
        while i < ArraySize(pins) {
            pin = pins[i] as QuestMappin;
            if IsDefined(pin) && pin.IsQuestMappin() && pin.GetJournalPathHash() == expected {
                this.m_pinCount += 1; this.m_lastMarker = pin.GetNewMappinID();
                this.m_positionOK = Vector4.Distance(pin.GetWorldPosition(), this.m_target) <= 2.0;
            };
            i += 1;
        };
        linked = map.GetMappinFromObjective(this.Entry(this.PhasePath(), "gameJournalQuestPhase"), this.Entry(this.ObjectivePath(), "gameJournalQuestObjective"));
        pin = linked as QuestMappin;
        this.m_linked = IsDefined(pin) && pin.GetJournalPathHash() == expected;
        this.m_confirmed = this.m_pinCount == 1 && this.m_positionOK && this.m_linked;
        if this.m_confirmed {
            if this.m_beforeCreate.value == this.m_afterCreate.value {
                this.Report("CONFIRMED native quest pin, journal objective link and fixed position; manual ID unchanged across activation");
            } else {
                this.Report("Native quest pin confirmed, but manual ID changed across activation; investigate before normal dispatch integration");
            };
        } else {
            if this.m_elapsed >= 5.0 { this.Report("NOT CONFIRMED: node call alone is not success. Inspect diagnostics; remove the test before changing activation input"); };
        };
    }
    private func RemoveOwnPins() -> Int32 {
        let map: ref<MappinSystem> = this.Map();
        let pins: array<ref<IMappin>>;
        let pin: ref<QuestMappin>;
        let expected: Uint32 = this.PinHash();
        let i: Int32 = 0;
        let remaining: Int32 = 0;
        if !IsDefined(map) || expected == 0u { return 1; };
        pins = map.GetAllMappins();
        while i < ArraySize(pins) {
            pin = pins[i] as QuestMappin;
            if IsDefined(pin) && pin.GetJournalPathHash() == expected { map.UnregisterMappin(pin.GetNewMappinID()); };
            i += 1;
        };
        pins = map.GetAllMappins(); i = 0;
        while i < ArraySize(pins) {
            pin = pins[i] as QuestMappin;
            if IsDefined(pin) && pin.GetJournalPathHash() == expected { remaining += 1; };
            i += 1;
        };
        return remaining;
    }
    public func Stop(reason: String) -> Void {
        let journal: ref<JournalManager> = this.Journal();
        let map: ref<MappinSystem> = this.Map();
        let wasOurs: Bool = IsDefined(journal) && journal.GetTrackedEntry() == this.Entry(this.ObjectivePath(), "gameJournalQuestObjective");
        let quests: ref<QuestsSystem> = GameInstance.GetQuestsSystem(this.GetGameInstance());
        if !this.IsReady() { this.m_requested = false; this.m_cleanup = false; this.Report(reason); return; };
        if IsDefined(map) { this.m_beforeRemove = map.GetManuallyTrackedMappinID(); };
        if !IsDefined(this.m_node) { this.m_node = this.MakeNode(); };
        if IsDefined(quests) { quests.ExecuteNode(this.m_node, n"Disable"); };
        this.Write(this.PinPath(), "gameJournalQuestMapPin", gameJournalEntryState.Inactive);
        this.Write(this.ObjectivePath(), "gameJournalQuestObjective", gameJournalEntryState.Inactive);
        this.Write(this.PhasePath(), "gameJournalQuestPhase", gameJournalEntryState.Inactive);
        this.Write(this.Root(), "gameJournalQuest", gameJournalEntryState.Inactive);
        this.m_cleanup = this.RemoveOwnPins() > 0;
        if wasOurs && IsDefined(this.m_previousTracked) && Equals(journal.GetEntryState(this.m_previousTracked), gameJournalEntryState.Active) { journal.TrackEntry(this.m_previousTracked); };
        this.m_previousTracked = null; this.m_anchor = null; this.m_requested = false; this.m_confirmed = false;
        if IsDefined(map) { this.m_afterRemove = map.GetManuallyTrackedMappinID(); };
        this.Report(reason);
    }
    public func Tick(delta: Float) -> Void {
        let entry: wref<JournalEntry>;
        if this.m_restorePending {
            if !this.IsReady() { return; };
            this.m_restorePending = false; entry = this.Entry(this.Root(), "gameJournalQuest");
            if Equals(this.Journal().GetEntryState(entry), gameJournalEntryState.Active) { this.Stop("Loaded probe journal closed; previous-world handles were forgotten"); };
        };
        if delta <= 0.0 || delta > 0.5 { return; };
        if this.m_requested {
            if !this.RuntimeAllowed() { this.Stop("Probe ended: normal duty/combat/player rules resumed"); return; };
            // Opening the map is part of this experiment: retain both markers
            // and pause its lifetime rather than ending the test in menus.
            if NCPDPatrolSystem.Get(this.GetGameInstance()).IsDispatchMenuOpen() { return; };
            this.m_elapsed += delta;
            if this.m_elapsed >= 600.0 { this.Stop("Probe expired after ten minutes"); return; };
        };
        this.m_poll += delta;
        if this.m_poll < 1.0 { return; };
        this.m_poll = 0.0;
        if this.m_requested { this.Inspect(); };
        if this.m_cleanup { this.m_cleanup = this.RemoveOwnPins() > 0; };
    }
    public func HasRequest() -> Bool { return this.m_requested; }
    public func HasPendingCleanup() -> Bool { return this.m_cleanup; }
    public func IsConfirmed() -> Bool { return this.m_confirmed; }
    public func GetRevision() -> Int32 { return this.m_revision; }
    public func GetDiagnostics() -> String {
        let current: NewMappinID;
        let map: ref<MappinSystem> = this.Map();
        if IsDefined(map) { current = map.GetManuallyTrackedMappinID(); };
        return s"ready=\(this.IsReady()) | requested=\(this.m_requested) | confirmed=\(this.m_confirmed) | pending marker cleanup=\(this.m_cleanup) | native quest pins=\(this.m_pinCount) | objective link=\(this.m_linked) | position OK=\(this.m_positionOK) | pin ID=\(this.m_lastMarker.value) | journal hash=\(this.PinHash()) | node path hash=\(this.m_pathHash) | activation mode=\(this.m_mode) | target=\(this.m_target.X),\(this.m_target.Y),\(this.m_target.Z) | manual before/after create=\(this.m_beforeCreate.value)/\(this.m_afterCreate.value) | manual current=\(current.value) | manual before/after remove=\(this.m_beforeRemove.value)/\(this.m_afterRemove.value) | \(this.m_reason)";
    }
}
