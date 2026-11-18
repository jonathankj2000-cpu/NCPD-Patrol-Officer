// Test incident: exact mod-created target, independent of scanner POI phases.
// No scanner/career/reward ledger is written by this first encounter prototype.
public class NCPDPatrolCyberpsychoSystem extends ScriptableSystem {
    // 0 idle, 2 active, 3 succeeded, 4 failed, 5 cancelled, 6 journal error.
    private let m_stage: Int32;
    private let m_token: Int32;
    private let m_target: wref<NPCPuppet>;
    private let m_origin: Vector4;
    private let m_stable: Float;
    private let m_missing: Float;
    private let m_away: Float;
    private let m_age: Float;
    private let m_reason: String;
    private let m_restorePending: Bool;
    private let m_previousTracked: wref<JournalEntry>;

    public static func Get(game: GameInstance) -> ref<NCPDPatrolCyberpsychoSystem> {
        return GameInstance.GetScriptableSystemsContainer(game).Get(n"NCPDPatrolCyberpsychoSystem") as NCPDPatrolCyberpsychoSystem;
    }
    public func Version() -> Int32 { return 1; }
    private func OnAttach() -> Void { this.ForgetWorld(); }
    private func OnRestored(saveVersion: Int32, gameVersion: Int32) -> Void { this.ForgetWorld(); }
    private func ForgetWorld() -> Void {
        this.m_stage = 0; this.m_token += 1; this.m_target = null;
        this.m_stable = 0.0; this.m_missing = 0.0; this.m_away = 0.0; this.m_age = 0.0;
        this.m_reason = "Cyberpsycho test ready";
        this.m_restorePending = true; this.m_previousTracked = null;
    }
    private func Journal() -> ref<JournalManager> {
        return GameInstance.GetJournalManager(this.GetGameInstance());
    }
    private func QuestPath() -> String { return "quests/minor_quest/ncpd_patrol_cyberpsycho"; }
    private func PhasePath() -> String { return "quests/minor_quest/ncpd_patrol_cyberpsycho/main"; }
    private func ObjectivePath() -> String { return "quests/minor_quest/ncpd_patrol_cyberpsycho/main/neutralize"; }
    private func DescriptionPath() -> String { return "quests/minor_quest/ncpd_patrol_cyberpsycho/main/neutralize/briefing"; }
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
            && IsDefined(this.Entry(this.DescriptionPath(), "gameJournalQuestDescription"));
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
        if !this.Write(this.PhasePath(), "gameJournalQuestPhase", gameJournalEntryState.Inactive) { ok = false; };
        if !this.Write(this.QuestPath(), "gameJournalQuest", gameJournalEntryState.Inactive) { ok = false; };
        return ok;
    }
    private func ReconcileLoadedJournal() -> Void {
        if !this.m_restorePending || !this.IsReady() { return; };
        if Equals(this.State(this.QuestPath(), "gameJournalQuest"), gameJournalEntryState.Active)
            || Equals(this.State(this.ObjectivePath(), "gameJournalQuestObjective"), gameJournalEntryState.Active) {
            if !this.HideJournal() { this.m_reason = "Loaded cyberpsycho journal could not close"; return; };
        };
        this.m_restorePending = false;
    }
    public func IsTargetRecord(npc: ref<NPCPuppet>) -> Bool {
        return IsDefined(npc) && Equals(npc.GetRecordID(), t"Character.NCPDPatrol_Cyberpsycho");
    }
    public func IsTargetReady(npc: ref<NPCPuppet>) -> Bool {
        return this.IsTargetRecord(npc) && npc.IsAttached() && ScriptedPuppet.IsActive(npc)
            && !npc.IsDead() && !npc.IsDeadNoStatPool() && !ScriptedPuppet.IsDefeated(npc) && !ScriptedPuppet.IsUnconscious(npc);
    }
    public func BeginTarget(npc: ref<NPCPuppet>) -> Int32 {
        let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
        if !this.Eligible() || this.m_stage == 2 || !this.IsTargetReady(npc) { return 0; };
        if Vector4.Distance(player.GetWorldPosition(), npc.GetWorldPosition()) > 120.0 { return 0; };
        if !this.IsReady() { this.m_reason = "Install the complete Cyberpsycho archive/.xl and restart"; return 0; };
        this.ReconcileLoadedJournal();
        if this.m_restorePending { return 0; };
        this.m_previousTracked = null;
        if !this.OursTracked() { this.m_previousTracked = this.Journal().GetTrackedEntry(); };
        if !this.HideJournal() { this.m_reason = "Cyberpsycho journal reset rejected"; this.m_previousTracked = null; return 0; };
        if !this.Write(this.QuestPath(), "gameJournalQuest", gameJournalEntryState.Active, true)
            || !this.Write(this.PhasePath(), "gameJournalQuestPhase", gameJournalEntryState.Active)
            || !this.Write(this.DescriptionPath(), "gameJournalQuestDescription", gameJournalEntryState.Active)
            || !this.Write(this.ObjectivePath(), "gameJournalQuestObjective", gameJournalEntryState.Active) {
            this.HideJournal(); this.m_previousTracked = null; this.m_reason = "Cyberpsycho journal activation rejected"; return 0;
        };
        this.m_token += 1; this.m_target = npc; this.m_origin = npc.GetWorldPosition();
        this.m_stage = 2; this.m_stable = 0.0; this.m_missing = 0.0; this.m_away = 0.0; this.m_age = 0.0;
        this.m_reason = "Neutralize the marked cyberpsycho; lethal or non-lethal";
        this.Journal().TrackEntry(this.Entry(this.ObjectivePath(), "gameJournalQuestObjective"));
        return this.m_token;
    }
    private func Finish(result: Int32, reason: String) -> Void {
        let state: gameJournalEntryState = gameJournalEntryState.Succeeded;
        let wasOurs: Bool = this.OursTracked();
        let ok: Bool;
        if result == 4 { state = gameJournalEntryState.Failed; };
        ok = this.Write(this.ObjectivePath(), "gameJournalQuestObjective", state);
        if !this.Write(this.PhasePath(), "gameJournalQuestPhase", state) { ok = false; };
        if !this.Write(this.QuestPath(), "gameJournalQuest", state, true) { ok = false; };
        this.m_stage = result; this.m_reason = reason;
        if !ok { this.m_stage = 6; this.m_reason = "Cyberpsycho journal result rejected"; this.HideJournal(); };
        this.RestoreTracking(wasOurs);
    }
    public func Cancel(token: Int32, reason: String) -> Void {
        let wasOurs: Bool;
        let patrol: ref<NCPDPatrolSystem> = NCPDPatrolSystem.Get(this.GetGameInstance());
        if token != this.m_token || this.m_stage != 2 { return; };
        if IsDefined(patrol) && patrol.HasWantedLevel() { this.Finish(4, "Shift terminated due to criminal activity"); return; };
        wasOurs = this.OursTracked(); this.m_stage = 5; this.m_reason = reason;
        if !this.HideJournal() { this.m_stage = 6; this.m_reason = "Cyberpsycho journal cancellation rejected"; };
        this.RestoreTracking(wasOurs);
    }
    public func Tick(delta: Float) -> Void {
        let patrol: ref<NCPDPatrolSystem> = NCPDPatrolSystem.Get(this.GetGameInstance());
        let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
        if !IsDefined(player) || !player.IsAttached() || !IsDefined(patrol) { return; };
        this.ReconcileLoadedJournal();
        if this.m_stage != 2 { return; };
        if patrol.HasWantedLevel() || player.IsDead() { this.Finish(4, "Shift terminated or officer down"); return; };
        if !this.Eligible() { this.Cancel(this.m_token, "Shift ended"); return; };
        if patrol.IsDispatchMenuOpen() || delta <= 0.0 || delta > 0.50 { return; };
        this.m_age += delta;
        if this.m_age >= 1.0 && (!Equals(this.State(this.QuestPath(), "gameJournalQuest"), gameJournalEntryState.Active)
            || !Equals(this.State(this.ObjectivePath(), "gameJournalQuestObjective"), gameJournalEntryState.Active)) {
            this.Finish(4, "Active cyberpsycho journal state lost"); return;
        };
        // A disappeared or streamed-out target is never proof of elimination.
        if !IsDefined(this.m_target) || !this.m_target.IsAttached() {
            this.m_stable = 0.0; this.m_missing += delta;
            if this.m_missing >= 8.0 { this.Finish(4, "Cyberpsycho target unavailable"); };
            return;
        };
        this.m_missing = 0.0;
        if Vector4.Distance(player.GetWorldPosition(), this.m_origin) > 350.0 {
            this.m_stable = 0.0; this.m_away += delta;
            if this.m_away >= 5.0 { this.Finish(4, "Patrol left the incident area"); };
            return;
        };
        this.m_away = 0.0;
        if this.m_target.IsDead() || this.m_target.IsDeadNoStatPool()
            || ScriptedPuppet.IsDefeated(this.m_target) || ScriptedPuppet.IsUnconscious(this.m_target) {
            this.m_stable += delta;
            if this.m_stable >= 0.75 { this.Finish(3, "Cyberpsycho neutralized"); };
        } else { this.m_stable = 0.0; };
    }
    public func GetStage() -> Int32 { return this.m_stage; }
    public func GetToken() -> Int32 { return this.m_token; }
    public func GetReason() -> String { return this.m_reason; }
    public func GetTargetPosition() -> Vector4 {
        if IsDefined(this.m_target) && this.m_target.IsAttached() { return this.m_target.GetWorldPosition(); };
        return this.m_origin;
    }
    public func GetDiagnostics() -> String {
        let ready: Bool = this.IsReady();
        let attached: Bool = IsDefined(this.m_target) && this.m_target.IsAttached();
        return s"ready=\(ready) | stage=\(this.m_stage) | token=\(this.m_token) | target attached=\(attached) | confirmed down=\(this.m_stable) s | missing=\(this.m_missing) s | \(this.m_reason)";
    }
}
