// One pre-authored journal entry, driven by the existing scanner dispatcher.
// No scripted-quest cloning APIs, vanilla quest writes or money transactions.
public class NCPDPatrolDispatchJournalSystem extends ScriptableSystem {
    // 0 idle, 1 responding, 2 on scene, 3 succeeded, 4 failed, 5 cancelled,
    // 6 journal error. Tokens prevent a stale call finishing a replacement.
    private let m_stage: Int32;
    private let m_token: Int32;
    private let m_hash: Uint32;
    private let m_target: Vector4;
    private let m_remaining: Float;
    private let m_activationTime: Float;
    private let m_reason: String;
    private let m_restorePending: Bool;
    private let m_previousTracked: wref<JournalEntry>;

    public static func Get(game: GameInstance) -> ref<NCPDPatrolDispatchJournalSystem> {
        return GameInstance.GetScriptableSystemsContainer(game).Get(n"NCPDPatrolDispatchJournalSystem") as NCPDPatrolDispatchJournalSystem;
    }
    public func Version() -> Int32 { return 1; }
    private func OnAttach() -> Void { this.ForgetWorld(); }
    private func OnRestored(saveVersion: Int32, gameVersion: Int32) -> Void { this.ForgetWorld(); }
    private func ForgetWorld() -> Void {
        // Resolve the journal afresh on a loaded-world Tick; never use old refs.
        this.m_stage = 0;
        this.m_token += 1;
        this.m_hash = 0u;
        this.m_remaining = 0.0;
        this.m_activationTime = 0.0;
        this.m_reason = "Waiting for journal resources";
        this.m_restorePending = true;
        this.m_previousTracked = null;
    }
    private func Journal() -> ref<JournalManager> {
        return GameInstance.GetJournalManager(this.GetGameInstance());
    }
    private func QuestPath() -> String { return "quests/minor_quest/ncpd_patrol_dispatch"; }
    private func PhasePath() -> String { return "quests/minor_quest/ncpd_patrol_dispatch/main"; }
    private func ObjectivePath() -> String { return "quests/minor_quest/ncpd_patrol_dispatch/main/resolve"; }
    private func DescriptionPath() -> String { return "quests/minor_quest/ncpd_patrol_dispatch/main/resolve/briefing"; }
    private func Eligible() -> Bool {
        let patrol: ref<NCPDPatrolSystem> = NCPDPatrolSystem.Get(this.GetGameInstance());
        let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
        return IsDefined(patrol) && patrol.IsOnDuty() && !patrol.HasWantedLevel()
            && IsDefined(player) && player.IsAttached() && !player.IsDead();
    }
    public func IsReady() -> Bool {
        let journal: ref<JournalManager> = this.Journal();
        return IsDefined(journal)
            && IsDefined(journal.GetEntryByString(this.QuestPath(), "gameJournalQuest"))
            && IsDefined(journal.GetEntryByString(this.PhasePath(), "gameJournalQuestPhase"))
            && IsDefined(journal.GetEntryByString(this.ObjectivePath(), "gameJournalQuestObjective"))
            && IsDefined(journal.GetEntryByString(this.DescriptionPath(), "gameJournalQuestDescription"));
    }
    public func GetStage() -> Int32 { return this.m_stage; }
    public func GetToken() -> Int32 { return this.m_token; }
    public func GetRemainingSeconds() -> Int32 {
        if this.m_stage != 1 { return 0; };
        return CeilF(this.m_remaining);
    }
    public func GetReason() -> String { return this.m_reason; }
    private func Running() -> Bool { return this.m_stage == 1 || this.m_stage == 2; }
    private func State(path: String, className: String) -> gameJournalEntryState {
        let journal: ref<JournalManager> = this.Journal();
        let entry: wref<JournalEntry>;
        if IsDefined(journal) { entry = journal.GetEntryByString(path, className); };
        if !IsDefined(entry) { return gameJournalEntryState.Undefined; };
        return journal.GetEntryState(entry);
    }
    private func Write(path: String, className: String, state: gameJournalEntryState, opt notify: Bool) -> Bool {
        let journal: ref<JournalManager> = this.Journal();
        let entry: wref<JournalEntry>;
        let option: JournalNotifyOption = JournalNotifyOption.DoNotNotify;
        if !IsDefined(journal) { return false; };
        entry = journal.GetEntryByString(path, className);
        if !IsDefined(entry) { return false; };
        if Equals(journal.GetEntryState(entry), state) { return true; };
        if notify { option = JournalNotifyOption.Notify; };
        if journal.ChangeEntryState(path, className, state, option) { return true; };
        return Equals(journal.GetEntryState(entry), state);
    }
    private func OursTracked() -> Bool {
        let journal: ref<JournalManager> = this.Journal();
        let entry: wref<JournalEntry>;
        if !IsDefined(journal) { return false; };
        entry = journal.GetTrackedEntry();
        if !IsDefined(entry) { return false; };
        return entry == journal.GetEntryByString(this.QuestPath(), "gameJournalQuest")
            || entry == journal.GetEntryByString(this.PhasePath(), "gameJournalQuestPhase")
            || entry == journal.GetEntryByString(this.ObjectivePath(), "gameJournalQuestObjective");
    }
    private func RestoreTracking(wasOurs: Bool) -> Void {
        let journal: ref<JournalManager> = this.Journal();
        if wasOurs && IsDefined(journal) && IsDefined(this.m_previousTracked)
            && Equals(journal.GetEntryState(this.m_previousTracked), gameJournalEntryState.Active) {
            journal.TrackEntry(this.m_previousTracked);
        };
        this.m_previousTracked = null;
    }
    private func HideJournal() -> Bool {
        let ok: Bool = this.Write(this.ObjectivePath(), "gameJournalQuestObjective", gameJournalEntryState.Inactive);
        if !this.Write(this.DescriptionPath(), "gameJournalQuestDescription", gameJournalEntryState.Inactive) { ok = false; };
        if !this.Write(this.PhasePath(), "gameJournalQuestPhase", gameJournalEntryState.Inactive) { ok = false; };
        if !this.Write(this.QuestPath(), "gameJournalQuest", gameJournalEntryState.Inactive) { ok = false; };
        return ok;
    }
    private func ReconcileLoadedJournal() -> Void {
        if !this.m_restorePending || !this.IsReady() { return; };
        // Current duty sessions intentionally end on load. Retain finished
        // history, but hide an active entry saved in a previous session.
        if Equals(this.State(this.QuestPath(), "gameJournalQuest"), gameJournalEntryState.Active)
            || Equals(this.State(this.ObjectivePath(), "gameJournalQuestObjective"), gameJournalEntryState.Active) {
            if !this.HideJournal() {
                this.m_reason = "Loaded dispatch could not be deactivated";
                return;
            };
            this.m_reason = "Previous active dispatch closed after loading";
        } else {
            this.m_reason = "Journal entry available";
        };
        this.m_restorePending = false;
    }

    public func BeginDispatch(hash: Uint32, target: Vector4) -> Int32 {
        let journal: ref<JournalManager> = this.Journal();
        if !this.Eligible() || hash == 0u || this.Running() { return 0; };
        if !this.IsReady() {
            this.m_reason = "Journal entry unavailable: install ArchiveXL and the complete NCPDPatrol_Dispatch archive/.xl files; restart the game";
            return 0;
        };
        this.ReconcileLoadedJournal();
        if this.m_restorePending { return 0; };
        this.m_previousTracked = null;
        if !this.OursTracked() { this.m_previousTracked = journal.GetTrackedEntry(); };
        if !this.HideJournal() {
            this.m_reason = "Journal reset rejected; reusable entry must be tested in game";
            this.m_previousTracked = null;
            return 0;
        };
        if !this.Write(this.QuestPath(), "gameJournalQuest", gameJournalEntryState.Active, true)
            || !this.Write(this.PhasePath(), "gameJournalQuestPhase", gameJournalEntryState.Active)
            || !this.Write(this.DescriptionPath(), "gameJournalQuestDescription", gameJournalEntryState.Active)
            || !this.Write(this.ObjectivePath(), "gameJournalQuestObjective", gameJournalEntryState.Active) {
            this.HideJournal();
            this.m_previousTracked = null;
            this.m_reason = "Journal activation rejected";
            return 0;
        };
        this.m_token += 1;
        this.m_hash = hash;
        this.m_target = target;
        this.m_remaining = 180.0;
        this.m_activationTime = 0.0;
        this.m_stage = 1;
        this.m_reason = "Respond within 3 minutes";
        journal.TrackEntry(journal.GetEntryByString(this.ObjectivePath(), "gameJournalQuestObjective"));
        return this.m_token;
    }
    private func Finish(result: Int32, reason: String) -> Bool {
        let state: gameJournalEntryState = gameJournalEntryState.Succeeded;
        let wasOurs: Bool = this.OursTracked();
        let ok: Bool;
        if result == 4 { state = gameJournalEntryState.Failed; };
        ok = this.Write(this.ObjectivePath(), "gameJournalQuestObjective", state);
        if !this.Write(this.PhasePath(), "gameJournalQuestPhase", state) { ok = false; };
        if !this.Write(this.QuestPath(), "gameJournalQuest", state, true) { ok = false; };
        this.m_remaining = 0.0;
        this.m_stage = result;
        this.m_reason = reason;
        if !ok {
            this.m_stage = 6;
            this.m_reason = "Journal terminal transition rejected: " + reason;
            this.HideJournal();
        };
        this.RestoreTracking(wasOurs);
        return ok;
    }
    public func CompleteDispatch(token: Int32) -> Bool {
        if token != this.m_token || this.m_stage != 2 || !this.Eligible() { return false; };
        return this.Finish(3, "Scanner activity resolved after attendance");
    }
    public func CancelDispatch(token: Int32, reason: String) -> Void {
        let wasOurs: Bool;
        if !this.Running() || (token != 0 && token != this.m_token) { return; };
        wasOurs = this.OursTracked();
        this.m_stage = 5;
        this.m_remaining = 0.0;
        this.m_reason = reason;
        if !this.HideJournal() {
            this.m_stage = 6;
            this.m_reason = "Journal cancellation rejected: " + reason;
        };
        this.RestoreTracking(wasOurs);
    }
    public func ArmTimeoutTest(token: Int32) -> Bool {
        let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
        if token != this.m_token || this.m_stage != 1 || !this.Eligible()
            || Vector4.Distance(player.GetWorldPosition(), this.m_target) <= 60.0 { return false; };
        this.m_remaining = 15.0;
        this.m_reason = "TEST: response deadline shortened to 15 seconds";
        return true;
    }
    public func Tick(delta: Float) -> Void {
        let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
        let patrol: ref<NCPDPatrolSystem> = NCPDPatrolSystem.Get(this.GetGameInstance());
        if !IsDefined(player) || !player.IsAttached() || !IsDefined(patrol) { return; };
        this.ReconcileLoadedJournal();
        if !this.Running() { return; };
        if patrol.HasWantedLevel() { this.Finish(4, "Shift terminated due to criminal activity"); return; };
        if !this.Eligible() { this.CancelDispatch(this.m_token, "Shift ended or player unavailable"); return; };
        if patrol.IsDispatchMenuOpen() { return; };
        if this.m_stage == 1 && Vector4.Distance(player.GetWorldPosition(), this.m_target) <= 60.0 {
            this.m_stage = 2;
            this.m_remaining = 0.0;
            this.m_reason = "On scene; response deadline cleared";
        };
        if delta <= 0.0 || delta > 0.50 { return; };
        this.m_activationTime += delta;
        if this.m_activationTime >= 1.0
            && (!Equals(this.State(this.QuestPath(), "gameJournalQuest"), gameJournalEntryState.Active)
            || !Equals(this.State(this.ObjectivePath(), "gameJournalQuestObjective"), gameJournalEntryState.Active)) {
            this.CancelDispatch(this.m_token, "Active journal state was not observed");
            this.m_stage = 6;
            return;
        };
        if this.m_stage != 1 { return; };
        // Arrival was checked before expiry, independently of POI polling.
        this.m_remaining -= delta;
        if this.m_remaining <= 0.0 { this.Finish(4, "Response time exceeded"); };
    }
    public func GetDiagnostics() -> String {
        let ready: Bool = this.IsReady();
        let remaining: Int32 = this.GetRemainingSeconds();
        let questState: gameJournalEntryState = this.State(this.QuestPath(), "gameJournalQuest");
        let objectiveState: gameJournalEntryState = this.State(this.ObjectivePath(), "gameJournalQuestObjective");
        return s"ready=\(ready) | stage=\(this.m_stage) | token=\(this.m_token) | POI=\(this.m_hash) | remaining=\(remaining) s | quest=\(questState) | objective=\(objectiveState) | \(this.m_reason)";
    }
}
