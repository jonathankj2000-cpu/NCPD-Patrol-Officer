// Opt-in MIT reference experiment. The archived phase owns journal state.
// The separate visual control cannot satisfy native journal proof.
public class NCPDPatrolQuestMarkerProbeSystem extends ScriptableSystem {
    private let m_requested: Bool;
    private let m_visualMode: Bool;
    private let m_visualConfirmed: Bool;
    private let m_visualID: NewMappinID;
    private let m_legacyPending: Bool;
    private let m_cleanup: Bool;
    private let m_restorePending: Bool;
    private let m_confirmed: Bool;
    private let m_trackPending: Bool;
    private let m_activationSampled: Bool;
    private let m_previousTracked: wref<JournalEntry>;
    private let m_target: Vector4;
    private let m_beforeCreate: NewMappinID;
    private let m_afterCreate: NewMappinID;
    private let m_beforeRemove: NewMappinID;
    private let m_afterRemove: NewMappinID;
    private let m_lastMarker: NewMappinID;
    private let m_pinCount: Int32;
    private let m_positionOK: Bool;
    private let m_linked: Bool;
    private let m_poll: Float;
    private let m_elapsed: Float;
    private let m_revision: Int32;
    private let m_reason: String;

    protected cb func OnAttach() -> Bool { this.ForgetWorld(); return true; }
    protected cb func OnRestored(saveVersion: Int32, gameVersion: Int32) -> Bool { this.ForgetWorld(); return true; }
    private func ForgetWorld() -> Void {
        let empty: NewMappinID;
        this.m_visualID = empty; this.m_lastMarker = empty;
        this.m_beforeCreate = empty; this.m_afterCreate = empty;
        this.m_beforeRemove = empty; this.m_afterRemove = empty;
        this.m_requested = false; this.m_cleanup = false; this.m_confirmed = false;
        this.m_visualMode = false; this.m_visualConfirmed = false; this.m_legacyPending = true;
        this.m_trackPending = false; this.m_activationSampled = false; this.m_previousTracked = null;
        this.m_pinCount = 0; this.m_positionOK = false; this.m_linked = false;
        this.m_poll = 0.0; this.m_elapsed = 0.0; this.m_restorePending = true;
        this.Report("Andrea reference experiment ready (off duty only)");
    }
    public func Version() -> Int32 { return 5; }
    private func Root() -> String { return "quests/street_stories/ncpd_patrol_marker_reference"; }
    private func PhasePath() -> String { return this.Root() + "/main"; }
    private func ObjectivePath() -> String { return this.PhasePath() + "/inspect"; }
    private func PinPath() -> String { return this.ObjectivePath() + "/location"; }
    private func Facts() -> ref<QuestsSystem> { return GameInstance.GetQuestsSystem(this.GetGameInstance()); }
    private func Journal() -> ref<JournalManager> { return GameInstance.GetJournalManager(this.GetGameInstance()); }
    private func Map() -> ref<MappinSystem> { return GameInstance.GetMappinSystem(this.GetGameInstance()); }
    private func Entry(path: String, kind: String) -> wref<JournalEntry> {
        let journal: ref<JournalManager> = this.Journal();
        if IsDefined(journal) { return journal.GetEntryByString(path, kind); };
        return null;
    }
    private func JournalReady() -> Bool {
        return IsDefined(this.Entry(this.Root(), "gameJournalQuest"))
            && IsDefined(this.Entry(this.PhasePath(), "gameJournalQuestPhase"))
            && IsDefined(this.Entry(this.ObjectivePath(), "gameJournalQuestObjective"))
            && IsDefined(this.Entry(this.PinPath(), "gameJournalQuestMapPin"));
    }
    public func GetGraphReady() -> Int32 {
        if IsDefined(this.Facts()) { return this.Facts().GetFactStr("ncpd_patrol_marker_reference_r4d_ready"); };
        return 0;
    }
    public func GetGraphStage() -> Int32 {
        if IsDefined(this.Facts()) { return this.Facts().GetFactStr("ncpd_patrol_marker_reference_r4d_stage"); };
        return 0;
    }
    public func IsReady() -> Bool { return this.JournalReady() && this.GetGraphReady() == 5; }
    private func SetRequest(value: Int32) -> Void {
        if IsDefined(this.Facts()) { this.Facts().SetFactStr("ncpd_patrol_marker_reference_r4d_request", value); };
    }
    private func Report(reason: String) -> Void {
        if NotEquals(reason, this.m_reason) { this.m_revision += 1; this.m_reason = reason; };
    }
    private func PinHash() -> Uint32 {
        let entry: wref<JournalEntry> = this.Entry(this.PinPath(), "gameJournalQuestMapPin");
        if IsDefined(entry) { return Cast<Uint32>(this.Journal().GetEntryHash(entry)); };
        return 0u;
    }
    private func RuntimeAllowed() -> Bool {
        let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
        let patrol: ref<NCPDPatrolSystem> = NCPDPatrolSystem.Get(this.GetGameInstance());
        return IsDefined(player) && player.IsAttached() && !player.IsDead() && !player.IsInCombat()
            && IsDefined(patrol) && !patrol.IsOnDuty() && !patrol.HasWantedLevel();
    }
    private func CloseLegacy() -> Void {
        let journal: ref<JournalManager> = this.Journal();
        let root: wref<JournalEntry>;
        let pin: wref<JournalEntry>;
        if !IsDefined(journal) || !IsDefined(this.Facts()) { return; };
        this.Facts().SetFactStr("ncpd_patrol_marker_probe_r4c_request", 0);
        root = this.Entry("quests/minor_quest/ncpd_patrol_marker_probe", "gameJournalQuest");
        if IsDefined(root) && Equals(journal.GetEntryState(root), gameJournalEntryState.Active) { return; };
        if this.Facts().GetFactStr("ncpd_patrol_marker_probe_r4c_stage") != 0 { return; };
        pin = this.Entry("quests/minor_quest/ncpd_patrol_marker_probe/main/inspect/location", "gameJournalQuestMapPin");
        if IsDefined(pin) && this.RemovePins(Cast<Uint32>(journal.GetEntryHash(pin))) > 0 { return; };
        this.m_legacyPending = false;
    }
    public func BeginVisual() -> Bool {
        let map: ref<MappinSystem> = this.Map();
        if this.m_requested || this.m_cleanup || this.m_legacyPending { this.Report("Remove the current test and wait for cleanup"); return false; };
        if !this.RuntimeAllowed() || !IsDefined(map) { this.Report("Run this visual control off duty, outside combat/wanted status"); return false; };
        if NCPDPatrolSystem.Get(this.GetGameInstance()).IsDispatchMenuOpen() { this.Report("Close game menus before starting the test"); return false; };
        if !this.CleanupVisual() { this.Report("Previous visual marker cleanup is pending"); return false; };
        this.m_target = GetPlayer(this.GetGameInstance()).GetWorldPosition();
        this.m_target.X = -1259.598; this.m_target.Y = -989.166; this.m_target.Z = 12.037; this.m_target.W = 1.0;
        this.m_beforeCreate = map.GetManuallyTrackedMappinID();
        this.m_visualID = NCPDPatrolReferenceMappins.Show(this.GetGameInstance(), this.m_target);
        this.m_afterCreate = map.GetManuallyTrackedMappinID();
        this.m_elapsed = 0.0; this.m_poll = 0.0;
        this.m_visualMode = true; this.m_visualConfirmed = false; this.m_confirmed = false;
        this.m_activationSampled = false; this.m_restorePending = false;
        this.m_requested = true; this.m_trackPending = false; this.m_previousTracked = null;
        this.m_pinCount = 0; this.m_linked = false; this.m_positionOK = false;
        this.Report("VISUAL CONTROL ONLY: inspect El Coyote Cojo on the map; no journal binding or GPS claim");
        return true;
    }
    private func InspectVisual() -> Void {
        let map: ref<MappinSystem> = this.Map();
        let pin: ref<IMappin>;
        this.m_confirmed = false;
        this.m_visualConfirmed = false;
        if !IsDefined(map) || !NCPDPatrolReferenceMappins.IsOwned(this.GetGameInstance(), this.m_visualID) { return; };
        pin = map.GetMappin(this.m_visualID);
        this.m_visualConfirmed = Equals(pin.GetVariant(), gamedataMappinVariant.QuestGiverVariant)
            && Vector4.Distance(pin.GetWorldPosition(), this.m_target) <= 2.0;
        if this.m_visualConfirmed { this.Report("VISUAL CONTROL confirmed at Coyote; native journal proof remains false"); };
    }
    private func CleanupVisual() -> Bool {
        let map: ref<MappinSystem> = this.Map();
        let pins: array<ref<IMappin>>;
        let i: Int32 = 0;
        if !IsDefined(map) { return false; };
        // Rediscover current-world private scriptData; never trust a saved ID.
        pins = map.GetAllMappins();
        while i < ArraySize(pins) {
            NCPDPatrolReferenceMappins.Hide(this.GetGameInstance(), pins[i].GetNewMappinID());
            i += 1;
        };
        pins = map.GetAllMappins(); i = 0;
        while i < ArraySize(pins) {
            if NCPDPatrolReferenceMappins.IsOwned(this.GetGameInstance(), pins[i].GetNewMappinID()) { return false; };
            i += 1;
        };
        return true;
    }
    public func Begin() -> Bool {
        let journal: ref<JournalManager> = this.Journal();
        let map: ref<MappinSystem> = this.Map();
        if this.m_legacyPending { this.Report("Previous r4c test is closing; wait a moment and retry"); return false; };
        if this.m_requested || this.m_cleanup { this.Report("Remove the current test and wait for phase cleanup"); return false; };
        if !this.RuntimeAllowed() { this.Report("Run this experiment off duty, outside combat/wanted status"); return false; };
        if NCPDPatrolSystem.Get(this.GetGameInstance()).IsDispatchMenuOpen() { this.Report("Close game menus before starting the test"); return false; };
        if !this.IsReady() || !IsDefined(map) { this.Report("Archived probe phase not ready: install the complete r4d archive/.xl and restart"); return false; };
        if this.GetGraphStage() != 0 { this.Report("The archived phase is still closing a previous test"); return false; };
        this.m_restorePending = false; this.m_requested = true; this.m_confirmed = false;
        this.m_visualMode = false; this.m_visualConfirmed = false;
        this.m_trackPending = true; this.m_activationSampled = false;
        this.m_elapsed = 0.0; this.m_poll = 0.0;
        this.m_pinCount = 0; this.m_positionOK = false; this.m_linked = false;
        this.m_target = GetPlayer(this.GetGameInstance()).GetWorldPosition();
        // Same Coyote point used by CCGig01Places.Coyote() in Negative Balance.
        this.m_target.X = -1259.598; this.m_target.Y = -989.166;
        this.m_target.Z = 12.037; this.m_target.W = 1.0;
        this.m_beforeCreate = map.GetManuallyTrackedMappinID();
        this.m_previousTracked = journal.GetTrackedEntry();
        this.SetRequest(1);
        this.Report("Requested reference quest phase; waiting for its marker and stage acknowledgement");
        return true;
    }
    private func Inspect() -> Void {
        let map: ref<MappinSystem> = this.Map();
        let journal: ref<JournalManager> = this.Journal();
        let pins: array<ref<IMappin>>;
        let pin: ref<QuestMappin>;
        let linked: wref<IMappin>;
        let objective: wref<JournalEntry> = this.Entry(this.ObjectivePath(), "gameJournalQuestObjective");
        let expected: Uint32 = this.PinHash();
        let i: Int32 = 0;
        if !IsDefined(map) || expected == 0u { return; };
        if this.m_trackPending && IsDefined(objective) && Equals(journal.GetEntryState(objective), gameJournalEntryState.Active) {
            journal.TrackEntry(objective); this.m_trackPending = false;
        };
        if !this.m_activationSampled && this.GetGraphStage() == 1 {
            this.m_afterCreate = map.GetManuallyTrackedMappinID(); this.m_activationSampled = true;
        };
        pins = map.GetAllMappins(); this.m_pinCount = 0; this.m_positionOK = false; this.m_linked = false;
        while i < ArraySize(pins) {
            pin = pins[i] as QuestMappin;
            if IsDefined(pin) && pin.IsQuestMappin() && pin.GetJournalPathHash() == expected {
                this.m_pinCount += 1; this.m_lastMarker = pin.GetNewMappinID();
                this.m_positionOK = Vector4.Distance(pin.GetWorldPosition(), this.m_target) <= 2.0;
            };
            i += 1;
        };
        linked = map.GetMappinFromObjective(this.Entry(this.PhasePath(), "gameJournalQuestPhase"), objective);
        pin = linked as QuestMappin;
        this.m_linked = IsDefined(pin) && pin.GetJournalPathHash() == expected;
        this.m_confirmed = this.GetGraphStage() == 1 && this.m_pinCount == 1 && this.m_positionOK && this.m_linked;
        if this.m_confirmed {
            if this.m_beforeCreate.value == this.m_afterCreate.value {
                this.Report("CONFIRMED native quest pin, objective link and Coyote position; manual ID unchanged across activation");
            } else {
                this.Report("Native quest pin confirmed, but manual ID changed during activation; inspect before integration");
            };
        } else {
            if this.m_elapsed >= 5.0 { this.Report("NOT CONFIRMED: log reference graph, pin/link/position and ArchiveXL diagnostics, then remove the test"); };
        };
    }
    private func RemovePins(expected: Uint32) -> Int32 {
        let map: ref<MappinSystem> = this.Map();
        let pins: array<ref<IMappin>>;
        let pin: ref<QuestMappin>;
        let i: Int32 = 0;
        let remaining: Int32 = 0;
        if expected == 0u { return 0; };
        if !IsDefined(map) { return 1; };
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
    private func TryCleanup() -> Void {
        let root: wref<JournalEntry> = this.Entry(this.Root(), "gameJournalQuest");
        if this.m_visualMode {
            if !this.CleanupVisual() { return; };
            this.m_cleanup = false; this.m_visualMode = false;
            this.m_afterRemove = this.Map().GetManuallyTrackedMappinID();
            this.Report("Visual control removed; no native journal claim was made"); return;
        };
        if this.GetGraphReady() != 5 || this.GetGraphStage() != 0 || !IsDefined(root) { return; };
        if Equals(this.Journal().GetEntryState(root), gameJournalEntryState.Active) { return; };
        // The phase has passed Inactive. Remove only a matching current-world
        // quest pin if the engine retained its presentation after that request.
        if this.RemovePins(this.PinHash()) > 0 { return; };
        this.m_cleanup = false; this.m_pinCount = 0; this.m_linked = false; this.m_positionOK = false;
        this.m_afterRemove = this.Map().GetManuallyTrackedMappinID();
        this.Report("Archived phase cleanup confirmed; test ready again");
    }
    public func Stop(reason: String) -> Void {
        let journal: ref<JournalManager> = this.Journal();
        let map: ref<MappinSystem> = this.Map();
        let tracked: wref<JournalEntry>;
        let wasOurs: Bool = false;
        if IsDefined(journal) {
            tracked = journal.GetTrackedEntry();
            wasOurs = IsDefined(tracked) && (tracked == this.Entry(this.ObjectivePath(), "gameJournalQuestObjective")
                || tracked == this.Entry(this.PhasePath(), "gameJournalQuestPhase")
                || tracked == this.Entry(this.Root(), "gameJournalQuest"));
        };
        if IsDefined(map) { this.m_beforeRemove = map.GetManuallyTrackedMappinID(); };
        this.SetRequest(0);
        this.m_requested = false; this.m_confirmed = false; this.m_visualConfirmed = false; this.m_trackPending = false; this.m_cleanup = true;
        if wasOurs && IsDefined(this.m_previousTracked) && Equals(journal.GetEntryState(this.m_previousTracked), gameJournalEntryState.Active) { journal.TrackEntry(this.m_previousTracked); };
        this.m_previousTracked = null; this.Report(reason);
        this.TryCleanup();
    }
    public func Tick(delta: Float) -> Void {
        let entry: wref<JournalEntry>;
        if this.m_legacyPending { this.CloseLegacy(); };
        if this.m_restorePending {
            if !IsDefined(this.Journal()) || !IsDefined(this.Facts()) || !IsDefined(this.Map()) { return; };
            this.m_restorePending = false; this.SetRequest(0);
            if !this.CleanupVisual() { this.m_visualMode = true; this.m_cleanup = true; };
            entry = this.Entry(this.Root(), "gameJournalQuest");
            if (IsDefined(entry) && Equals(this.Journal().GetEntryState(entry), gameJournalEntryState.Active)) || this.GetGraphStage() != 0 {
                this.Stop("Loaded test is closing; previous-world handles were forgotten");
            };
        };
        if delta <= 0.0 || delta > 0.5 { return; };
        if this.m_requested {
            if !this.RuntimeAllowed() { this.Stop("Test ended: normal duty/combat/player rules resumed"); return; };
            if NCPDPatrolSystem.Get(this.GetGameInstance()).IsDispatchMenuOpen() { return; };
            this.m_elapsed += delta;
            if this.m_elapsed >= 600.0 { this.Stop("Test expired after ten minutes"); return; };
        };
        this.m_poll += delta;
        if this.m_poll < 0.25 { return; };
        this.m_poll = 0.0;
        if this.m_requested {
            if this.m_visualMode { this.InspectVisual(); } else { this.Inspect(); };
        };
        if this.m_cleanup { this.TryCleanup(); };
    }
    public func HasRequest() -> Bool { return this.m_requested; }
    public func HasPendingCleanup() -> Bool { return this.m_cleanup; }
    public func IsConfirmed() -> Bool { return this.m_confirmed; }
    public func GetRevision() -> Int32 { return this.m_revision; }
    public func GetDiagnostics() -> String {
        let current: NewMappinID;
        let questActive: Bool = false;
        let objectiveActive: Bool = false;
        if this.JournalReady() {
            questActive = Equals(this.Journal().GetEntryState(this.Entry(this.Root(), "gameJournalQuest")), gameJournalEntryState.Active);
            objectiveActive = Equals(this.Journal().GetEntryState(this.Entry(this.ObjectivePath(), "gameJournalQuestObjective")), gameJournalEntryState.Active);
        };
        if IsDefined(this.Map()) { current = this.Map().GetManuallyTrackedMappinID(); };
        return s"mode visual=\(this.m_visualMode) | visual confirmed=\(this.m_visualConfirmed) | visual ID=\(this.m_visualID.value) | legacy cleanup=\(this.m_legacyPending) | journal ready=\(this.JournalReady()) | graph ready=\(this.GetGraphReady()) | graph stage=\(this.GetGraphStage()) | quest active=\(questActive) | objective active=\(objectiveActive) | requested=\(this.m_requested) | confirmed=\(this.m_confirmed) | pending cleanup=\(this.m_cleanup) | native quest pins=\(this.m_pinCount) | objective link=\(this.m_linked) | position OK=\(this.m_positionOK) | pin ID=\(this.m_lastMarker.value) | journal hash=\(this.PinHash()) | target=\(this.m_target.X),\(this.m_target.Y),\(this.m_target.Z) | activation sampled=\(this.m_activationSampled) | manual before/after create=\(this.m_beforeCreate.value)/\(this.m_afterCreate.value) | manual current=\(current.value) | manual before/after remove=\(this.m_beforeRemove.value)/\(this.m_afterRemove.value) | \(this.m_reason)";
    }
}
