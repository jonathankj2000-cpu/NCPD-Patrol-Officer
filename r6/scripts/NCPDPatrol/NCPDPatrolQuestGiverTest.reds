// Isolated test bridge. The archived quest/scene owns dialogue and its result.
// No scanner, career, reward, wanted or production dispatch state is written.
public class NCPDPatrolQuestGiverTest extends ScriptableSystem {
    private let m_marker: ref<NCPDPatrolSceneMarker>;
    private let m_previous: wref<JournalEntry>;
    private let m_tracking: Bool;
    private func OnRestored(saveVersion: Int32, gameVersion: Int32) -> Void {
        this.m_marker = null; this.m_previous = null; this.m_tracking = false;
    }
    public func Version() -> Int32 { return 2; }
    public func GetPoseHelperTemplate() -> ResRef { return r"base\\ncpd_patrol\\quest_giver_test\\voss_wait_pose.ent"; }
    public func GetPoseResource() -> ResRef { return r"base\\workspots\\common\\ground\\generic__stand_ground_arms_crossed__stand_around__02.workspot"; }
    public func IsMenuOpen() -> Bool {
        let board: ref<IBlackboard> = GameInstance.GetBlackboardSystem(this.GetGameInstance()).Get(GetAllBlackboardDefs().UI_System);
        return !IsDefined(board) || board.GetBool(GetAllBlackboardDefs().UI_System.IsInMenu);
    }
    public static func Position() -> Vector4 {
        let p: Vector4;
        p.X = 1424.737; p.Y = -2754.759; p.Z = 204.665; p.W = 1.0;
        return p;
    }
    private func Root() -> String { return "quests/minor_quest/ncpd_patrol_quest_giver_test"; }
    private func Objective() -> String { return this.Root() + "/main/talk"; }
    private func Journal() -> ref<JournalManager> { return GameInstance.GetJournalManager(this.GetGameInstance()); }
    private func Quests() -> ref<QuestsSystem> { return GameInstance.GetQuestsSystem(this.GetGameInstance()); }
    public func GetStage() -> Int32 { return this.Quests().GetFactStr("ncpd_patrol_qgiver_test_stage"); }
    public func GetChoice() -> Int32 { return this.Quests().GetFactStr("ncpd_patrol_qgiver_test_choice"); }
    public func IsReady() -> Bool {
        return NCPDPatrolMarkerSession.WorldReady() && IsDefined(this.Journal()) && IsDefined(this.Quests())
            && this.Quests().GetFactStr("ncpd_patrol_qgiver_test_ready") == 1
            && IsDefined(this.Journal().GetEntryByString(this.Objective() + "/location", "gameJournalQuestMapPin"));
    }
    public func Begin() -> Bool {
        let patrol: ref<NCPDPatrolSystem>;
        let player: ref<PlayerPuppet>;
        if !this.IsReady() || this.IsMenuOpen() || this.GetStage() != 0 || this.Quests().GetFactStr("ncpd_patrol_qgiver_test_request") != 0 { return false; };
        patrol = GameInstance.GetScriptableSystemsContainer(this.GetGameInstance()).Get(n"NCPDPatrolSystem") as NCPDPatrolSystem;
        player = GetPlayer(this.GetGameInstance());
        if !IsDefined(player) || player.IsInCombat() || !IsDefined(patrol) || patrol.IsOnDuty() || patrol.HasWantedLevel() { return false; };
        this.m_previous = this.Journal().GetTrackedEntry();
        this.Quests().SetFactStr("ncpd_patrol_qgiver_test_choice", 0);
        this.Quests().SetFactStr("ncpd_patrol_qgiver_test_talk", 0);
        this.Quests().SetFactStr("ncpd_patrol_qgiver_test_request", 1);
        return true;
    }
    public func RequestTalk(npc: ref<NPCPuppet>) -> Bool {
        let player: ref<PlayerPuppet>;
        let patrol: ref<NCPDPatrolSystem>;
        if !NCPDPatrolMarkerSession.WorldReady() || this.GetStage() != 1 || !IsDefined(npc)
            || !npc.IsAttached() || npc.IsDead() || npc.GetRecordID() != t"Character.NCPDPatrol_QG_Investigator" { return false; };
        player = GetPlayer(this.GetGameInstance());
        patrol = GameInstance.GetScriptableSystemsContainer(this.GetGameInstance()).Get(n"NCPDPatrolSystem") as NCPDPatrolSystem;
        if !IsDefined(player) || player.IsInCombat() || !IsDefined(patrol) || patrol.IsOnDuty() || patrol.HasWantedLevel()
            || Vector4.Distance(player.GetWorldPosition(), npc.GetWorldPosition()) > 3.0 { return false; };
        this.Quests().SetFactStr("ncpd_patrol_qgiver_test_talk", 1);
        return true;
    }
    public func RequestClear() -> Void {
        if NCPDPatrolMarkerSession.WorldReady() && IsDefined(this.Quests()) {
            this.Quests().SetFactStr("ncpd_patrol_qgiver_test_request", 0);
        };
    }
    public func IsSucceeded() -> Bool {
        let entry: ref<JournalEntry>;
        if !NCPDPatrolMarkerSession.WorldReady() || this.GetStage() != 3 || (this.GetChoice() != 1 && this.GetChoice() != 2) { return false; };
        entry = this.Journal().GetEntryByString(this.Root(), "gameJournalQuest");
        return IsDefined(entry) && Equals(this.Journal().GetEntryState(entry), gameJournalEntryState.Succeeded);
    }
    public func Tick(delta: Float) -> Void {
        let stage: Int32;
        let tracked: wref<JournalEntry>;
        if !NCPDPatrolMarkerSession.WorldReady() { return; };
        stage = this.GetStage();
        if stage == 1 || stage == 2 {
            if !IsDefined(this.m_marker) {
                this.m_marker = new NCPDPatrolSceneMarker();
                this.m_marker.Configure(this.Objective(), this.Root() + "/main", NCPDPatrolQuestGiverTest.Position());
                this.m_marker.Open(this.GetGameInstance());
            };
            if !this.m_tracking {
                this.Journal().TrackEntry(this.Journal().GetEntryByString(this.Objective(), "gameJournalQuestObjective"));
                this.m_tracking = true;
            };
            this.m_marker.Tick(this.GetGameInstance(), delta);
        } else {
            if IsDefined(this.m_marker) { this.m_marker.Close(this.GetGameInstance()); this.m_marker = null; };
            if this.m_tracking {
                tracked = this.Journal().GetTrackedEntry();
                if tracked == this.Journal().GetEntryByString(this.Objective(), "gameJournalQuestObjective") && IsDefined(this.m_previous) {
                    this.Journal().TrackEntry(this.m_previous);
                };
                this.m_tracking = false; this.m_previous = null;
            };
        };
    }
    public func GetDiagnostics() -> String {
        let marker: String = "No active test marker";
        let ready: Int32 = this.Quests().GetFactStr("ncpd_patrol_qgiver_test_ready");
        let request: Int32 = this.Quests().GetFactStr("ncpd_patrol_qgiver_test_request");
        if IsDefined(this.m_marker) { marker = this.m_marker.GetDiagnostics(); };
        return s"stage=\(this.GetStage()) | graph ready=\(ready) | request=\(request) | choice=\(this.GetChoice()) | succeeded=\(this.IsSucceeded()) | \(marker)";
    }
}
