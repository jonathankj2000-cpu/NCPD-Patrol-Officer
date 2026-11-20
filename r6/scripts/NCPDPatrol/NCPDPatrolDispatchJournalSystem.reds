// One active, one-objective dispatch selected from six authored briefings.
// Dispatch supplements use their own persistent ledger, separate from scanners.
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
    private let m_briefing: Int32;
    private let m_navigationSite: Int32;
    private persistent let m_paidDispatches: array<CName>;
    private persistent let m_pendingDispatchRewards: array<CName>;
    private let m_rewardPoll: Float;
    private let m_receipts: array<String>;

    public static func Get(game: GameInstance) -> ref<NCPDPatrolDispatchJournalSystem> {
        return GameInstance.GetScriptableSystemsContainer(game).Get(n"NCPDPatrolDispatchJournalSystem") as NCPDPatrolDispatchJournalSystem;
    }
    public func Version() -> Int32 { return 2; }
    private func OnAttach() -> Void { this.ForgetWorld(); }
    private func OnRestored(saveVersion: Int32, gameVersion: Int32) -> Void { this.ForgetWorld(); }
    private func ForgetWorld() -> Void {
        // Resolve the journal afresh on a loaded-world Tick; never use old refs.
        this.m_stage = 0; this.m_navigationSite = 0;
        this.m_token += 1;
        this.m_hash = 0u;
        this.m_remaining = 0.0;
        this.m_activationTime = 0.0;
        this.m_reason = "Waiting for journal resources";
        this.m_restorePending = true;
        this.m_previousTracked = null;
        this.m_briefing = 0;
        this.m_rewardPoll = 1.0;
        ArrayClear(this.m_receipts);
    }
    private func Journal() -> ref<JournalManager> {
        return GameInstance.GetJournalManager(this.GetGameInstance());
    }
    private func VariantPath(briefing: Int32) -> String {
        // Variant zero retains the v0.9a path so saved active calls can close.
        if briefing == 0 { return "quests/minor_quest/ncpd_patrol_dispatch"; };
        return s"quests/minor_quest/ncpd_patrol_dispatch_\(briefing)";
    }
    private func QuestPath() -> String { return this.VariantPath(this.m_briefing); }
    private func PhasePath() -> String {
        let root: String = this.QuestPath();
        return s"\(root)/main";
    }
    private func ObjectivePath() -> String {
        let root: String = this.QuestPath();
        if this.m_navigationSite > 0 { return s"\(root)/main/resolve_bank_\(this.m_navigationSite)"; };
        return s"\(root)/main/resolve";
    }
    private func DescriptionPath() -> String {
        let objective: String;
        if this.m_navigationSite > 0 { objective = this.ObjectivePath(); return s"\(objective)/briefing"; };
        let root: String = this.QuestPath();
        return s"\(root)/main/resolve/briefing";
    }
    private func Eligible() -> Bool {
        let patrol: ref<NCPDPatrolSystem> = NCPDPatrolSystem.Get(this.GetGameInstance());
        let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
        return IsDefined(patrol) && patrol.IsOnDuty() && !patrol.HasWantedLevel()
            && IsDefined(player) && player.IsAttached() && !player.IsDead();
    }
    private func VariantReady(briefing: Int32) -> Bool {
        let journal: ref<JournalManager> = this.Journal();
        let root: String = this.VariantPath(briefing);
        let phase: String = s"\(root)/main";
        let objective: String = s"\(root)/main/resolve";
        let description: String = s"\(root)/main/resolve/briefing";
        return IsDefined(journal)
            && IsDefined(journal.GetEntryByString(root, "gameJournalQuest"))
            && IsDefined(journal.GetEntryByString(phase, "gameJournalQuestPhase"))
            && IsDefined(journal.GetEntryByString(objective, "gameJournalQuestObjective"))
            && IsDefined(journal.GetEntryByString(description, "gameJournalQuestDescription"));
    }
    public func IsReady() -> Bool {
        let i: Int32 = 0;
        while i < 6 {
            if !this.VariantReady(i) { return false; };
            i += 1;
        };
        return true;
    }
    public func GetNavigationSite() -> Int32 { return this.m_navigationSite; }
    public func SelectNavigationSite(site: Int32) -> Bool {
        let base: String;
        let root: String = this.QuestPath();
        let selected: String;
        if !this.Running() || site < 0 || site > 132 { return false; };
        base = s"\(root)/main/resolve"; selected = base;
        if site > 0 { selected = s"\(base)_bank_\(site)"; };
        if !NCPDPatrolFixedMarkerSystem.SwitchNavigationObjective(this.GetGameInstance(), base, this.ObjectivePath(), selected, 1, 132) { return false; };
        this.m_navigationSite = site; return true;
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
        let i: Int32 = 0;
        let root: String;
        let phase: String;
        let objective: String;
        if !IsDefined(journal) { return false; };
        entry = journal.GetTrackedEntry();
        if this.m_navigationSite > 0 && entry == journal.GetEntryByString(this.ObjectivePath(), "gameJournalQuestObjective") { return true; };
        if !IsDefined(entry) { return false; };
        while i < 6 {
            root = this.VariantPath(i);
            phase = s"\(root)/main";
            objective = s"\(root)/main/resolve";
            if entry == journal.GetEntryByString(root, "gameJournalQuest")
                || entry == journal.GetEntryByString(phase, "gameJournalQuestPhase")
                || entry == journal.GetEntryByString(objective, "gameJournalQuestObjective") { return true; };
            i += 1;
        };
        return false;
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
        let previous: Int32 = this.m_briefing;
        let i: Int32 = 0;
        let closed: Bool = false;
        if !this.m_restorePending || !this.IsReady() { return; };
        // Current duty sessions intentionally end on load. Retain finished
        // history, but hide an active entry saved in a previous session.
        while i < 6 {
            this.m_briefing = i;
            if Equals(this.State(this.QuestPath(), "gameJournalQuest"), gameJournalEntryState.Active)
                || Equals(this.State(this.ObjectivePath(), "gameJournalQuestObjective"), gameJournalEntryState.Active) {
                if !this.HideJournal() {
                    this.m_briefing = previous;
                    this.m_reason = "Loaded dispatch could not be deactivated";
                    return;
                };
                closed = true;
            };
            i += 1;
        };
        this.m_briefing = previous;
        if closed {
            this.m_reason = "Previous active dispatch closed after loading";
        } else {
            this.m_reason = "Journal entry available";
        };
        this.m_restorePending = false;
    }

    public func BeginDispatch(hash: Uint32, target: Vector4, opt briefing: Int32) -> Int32 {
        let journal: ref<JournalManager> = this.Journal();
        let key: CName = this.RewardKey(hash);
        if !this.Eligible() || hash == 0u || this.Running() { return 0; };
        if briefing < 0 || briefing >= 6 { this.m_reason = "Unknown dispatch briefing"; return 0; };
        if ArrayContains(this.m_paidDispatches, key) || ArrayContains(this.m_pendingDispatchRewards, key) {
            this.m_reason = "This incident already earned its dispatch supplement";
            return 0;
        };
        if !this.IsReady() {
            this.m_reason = "Journal entry unavailable: install ArchiveXL and the complete NCPDPatrol_Dispatch archive/.xl files; restart the game";
            return 0;
        };
        this.ReconcileLoadedJournal();
        if this.m_restorePending { return 0; };
        this.m_previousTracked = null;
        if !this.OursTracked() { this.m_previousTracked = journal.GetTrackedEntry(); };
        this.m_briefing = briefing;
        if !this.HideJournal() {
            this.m_reason = "Journal reset rejected; reusable entry must be tested in game";
            this.m_previousTracked = null;
            return 0;
        };
        this.m_navigationSite = 0;
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
    public func CompleteDispatch(token: Int32, opt marker: ref<PointOfInterestMappin>) -> Bool {
        let patrol: ref<NCPDPatrolSystem> = NCPDPatrolSystem.Get(this.GetGameInstance());
        let key: CName = this.RewardKey(this.m_hash);
        if token != this.m_token || this.m_stage != 2 || !this.Eligible() { return false; };
        if IsDefined(marker) && marker.GetJournalPathHash() != this.m_hash { return false; };
        if !Equals(patrol.GetScannerPhase(this.m_hash, marker), gamedataMappinPhase.CompletedPhase) { return false; };
        if !this.Finish(3, "Scanner activity resolved after attendance") { return false; };
        if !ArrayContains(this.m_paidDispatches, key) && !ArrayContains(this.m_pendingDispatchRewards, key) {
            ArrayPush(this.m_pendingDispatchRewards, key);
        };
        this.TryDispatchReward();
        return true;
    }
    public func DispatchReward() -> Int32 { return 500; }
    private func RewardKey(hash: Uint32) -> CName { return StringToName(s"ncpd-dispatch-\(hash)"); }
    public func GetPaidDispatches() -> Int32 { return ArraySize(this.m_paidDispatches); }
    public func GetPendingDispatchRewards() -> Int32 { return ArraySize(this.m_pendingDispatchRewards); }
    public func TakeDispatchReceipt() -> String {
        let receipt: String;
        if ArraySize(this.m_receipts) == 0 { return ""; };
        receipt = this.m_receipts[0];
        ArrayErase(this.m_receipts, 0);
        return receipt;
    }
    private func TryDispatchReward() -> Void {
        let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
        let transaction: ref<TransactionSystem> = GameInstance.GetTransactionSystem(this.GetGameInstance());
        let patrol: ref<NCPDPatrolSystem> = NCPDPatrolSystem.Get(this.GetGameInstance());
        let key: CName;
        let amount: Int32 = this.DispatchReward();
        if ArraySize(this.m_pendingDispatchRewards) == 0 { return; };
        if !IsDefined(player) || !player.IsAttached() || player.IsDead() || !IsDefined(transaction) || !IsDefined(patrol) { return; };
        key = this.m_pendingDispatchRewards[0];
        if ArrayContains(this.m_paidDispatches, key) {
            ArrayErase(this.m_pendingDispatchRewards, 0);
            return;
        };
        if !transaction.GiveItem(player, ItemID.FromTDBID(t"Items.money"), amount) { return; };
        // Synchronous native payment and ledger update; never credit on failure.
        ArrayPush(this.m_paidDispatches, key);
        ArrayErase(this.m_pendingDispatchRewards, 0);
        ArrayPush(this.m_receipts, s"DISPATCH BONUS PAID: +EUR$\(amount) | incident=\(key)");
        patrol.NotifyDispatchReward(amount);
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
        // These supplements were earned by completed calls. Retry them after
        // a failed transaction, including after a shift ends or a save loads.
        if delta > 0.0 && delta <= 0.50 && !patrol.IsDispatchMenuOpen() {
            this.m_rewardPoll += delta;
            if this.m_rewardPoll >= 1.0 {
                this.m_rewardPoll = 0.0;
                this.TryDispatchReward();
            };
        };
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
        let paid: Int32 = this.GetPaidDispatches();
        let pending: Int32 = this.GetPendingDispatchRewards();
        return s"ready=\(ready) | stage=\(this.m_stage) | token=\(this.m_token) | briefing=\(this.m_briefing) | POI=\(this.m_hash) | remaining=\(remaining) s | quest=\(questState) | objective=\(objectiveState) | dispatch supplements paid=\(paid) | pending=\(pending) | \(this.m_reason)";
    }
}
