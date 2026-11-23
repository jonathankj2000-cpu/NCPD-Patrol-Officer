// Off-duty assassination/evidence slice. Facts and native inventory/journal
// ownership persist; transient actor/marker references are rebuilt after load.
public class NCPDPatrolOffBooksSystem extends ScriptableSystem {
    private let m_target: wref<NPCPuppet>;
    private let m_guard1: wref<NPCPuppet>;
    private let m_guard2: wref<NPCPuppet>;
    private let m_holdTarget: ref<AIHoldPositionCommand>;
    private let m_hold1: ref<AIHoldPositionCommand>;
    private let m_hold2: ref<AIHoldPositionCommand>;
    private let m_marker: ref<NCPDPatrolSceneMarker>;
    private let m_syncedStage: Int32;
    private let m_previous: wref<JournalEntry>;
    private let m_lastObjective: wref<JournalEntry>;
    private func OnRestored(saveVersion: Int32, gameVersion: Int32) -> Void {
        this.m_target = null; this.m_guard1 = null; this.m_guard2 = null;
        this.m_holdTarget = null; this.m_hold1 = null; this.m_hold2 = null;
        this.m_marker = null; this.m_syncedStage = -1;
        this.m_previous = null; this.m_lastObjective = null;
    }
    public func Version() -> Int32 { return 1; }
    private func Quests() -> ref<QuestsSystem> { return GameInstance.GetQuestsSystem(this.GetGameInstance()); }
    private func Journal() -> ref<JournalManager> { return GameInstance.GetJournalManager(this.GetGameInstance()); }
    private func Patrol() -> ref<NCPDPatrolSystem> { return NCPDPatrolSystem.Get(this.GetGameInstance()); }
    private func Fact(name: String) -> Int32 { return this.Quests().GetFactStr("ncpd_patrol_otb_" + name); }
    private func Set(name: String, value: Int32) -> Void { this.Quests().SetFactStr("ncpd_patrol_otb_" + name, value); }
    private func Root() -> String { return "quests/minor_quest/ncpd_patrol_off_the_books"; }
    public func ShardPath() -> String { return "onscreens/emails/quests/ncpd_patrol_off_the_books/onscreens/evidence01"; }
    public func GetStage() -> Int32 { return this.Fact("stage"); }
    public func GetCycle() -> Int32 { return this.Fact("cycle"); }
    public func IsActive() -> Bool { return this.GetStage() >= 1 && this.GetStage() <= 4; }
    public func BlocksDuty() -> Bool { return this.GetStage() >= 1 && this.GetStage() <= 3; }
    public func IsMenuOpen() -> Bool {
        let board: ref<IBlackboard> = GameInstance.GetBlackboardSystem(this.GetGameInstance()).Get(GetAllBlackboardDefs().UI_System);
        return !IsDefined(board) || board.GetBool(GetAllBlackboardDefs().UI_System.IsInMenu);
    }
    public func OnDuty() -> Bool {
        let patrol: ref<NCPDPatrolSystem> = this.Patrol();
        return !IsDefined(patrol) || patrol.IsOnDuty();
    }
    public func Wanted() -> Bool {
        let patrol: ref<NCPDPatrolSystem> = this.Patrol();
        return !IsDefined(patrol) || patrol.HasWantedLevel();
    }
    public static func Site() -> Vector4 {
        let p: Vector4; p.X = -649.795; p.Y = 929.771; p.Z = 9.400; p.W = 1.0; return p;
    }
    private func Position(stage: Int32) -> Vector4 {
        if stage == 4 { return NCPDPatrolQuestGiverTest.Position(); };
        return NCPDPatrolOffBooksSystem.Site();
    }
    private func Objective(stage: Int32) -> String {
        if stage == 1 { return this.Root() + "/main/eliminate"; };
        if stage == 2 { return this.Root() + "/main/retrieve"; };
        if stage == 3 { return this.Root() + "/main/escape"; };
        return this.Root() + "/main/return";
    }
    public func RecordsReady() -> Bool {
        let item: wref<Item_Record> = TweakDBInterface.GetItemRecord(t"Items.NCPDPatrol_VossEvidence01");
        let read: wref<ObjectAction_Record>;
        if !IsDefined(item) || !IsDefined(TweakDBInterface.GetCharacterRecord(t"Character.NCPDPatrol_VossContractor01"))
            || !IsDefined(TweakDBInterface.GetCharacterRecord(t"Character.NCPDPatrol_VossGuard01"))
            || !IsDefined(TweakDBInterface.GetCharacterRecord(t"Character.NCPDPatrol_VossGuard02"))
            || !IsDefined(TweakDBInterface.GetCharacterRecord(t"Character.CorpoManArasaka"))
            || !IsDefined(TweakDBInterface.GetCharacterRecord(t"Character.arasaka_cyborg_franged3_shingen_ma_elite"))
            || !IsDefined(TweakDBInterface.GetItemRecord(t"Items.generic_arasaka_family_backstory_shard")) { return false; };
        read = ItemActionsHelper.GetReadAction(ItemID.FromTDBID(t"Items.NCPDPatrol_VossEvidence01"));
        return IsDefined(read) && read.GetID() == t"ItemAction.NCPDPatrol_VossEvidenceRead01"
            && ReadAction.GetJournalEntryFromAction(read.GetID()) == this.ShardPath();
    }
    public func IsReady() -> Bool {
        return NCPDPatrolMarkerSession.WorldReady() && IsDefined(this.Quests()) && IsDefined(this.Journal())
            && this.RecordsReady() && IsDefined(this.Journal().GetEntryByString(this.Root(), "gameJournalQuest"))
            && IsDefined(this.Journal().GetEntryByString(this.ShardPath(), "gameJournalOnscreen"));
    }
    public func Begin() -> Bool {
        let first: ref<NCPDPatrolQuestGiverTest>;
        if !this.IsReady() || this.IsMenuOpen() || this.OnDuty() || this.GetStage() != 0 { return false; };
        first = GameInstance.GetScriptableSystemsContainer(this.GetGameInstance()).Get(n"NCPDPatrolQuestGiverTest") as NCPDPatrolQuestGiverTest;
        if !IsDefined(first) || !first.IsSucceeded() { return false; };
        this.Set("cycle", this.GetCycle() + 1);
        this.Set("killed", 0); this.Set("acquired", 0); this.Set("seeded", 0);
        this.Set("provoked", 0); this.Set("player_provoked", 0); this.Set("returned", 0); this.Set("escape_used", 0);
        this.Set("created_target", 0); this.Set("created_guard1", 0); this.Set("created_guard2", 0);
        this.m_previous = this.Journal().GetTrackedEntry();
        this.Set("stage", 1); this.m_syncedStage = -1; this.SyncJournal(true);
        if !this.ObjectiveVisible() { this.Cancel(); return false; };
        return true;
    }
    public func WasCreated(role: CName) -> Bool {
        if Equals(role, n"target") { return this.Fact("created_target") > 0; };
        if Equals(role, n"guard1") { return this.Fact("created_guard1") > 0; };
        if Equals(role, n"guard2") { return this.Fact("created_guard2") > 0; };
        return true;
    }
    public func MarkCreated(role: CName, cycle: Int32) -> Bool {
        if !this.IsActive() || cycle != this.GetCycle() { return false; };
        if Equals(role, n"target") { this.Set("created_target", 1); return true; };
        if Equals(role, n"guard1") { this.Set("created_guard1", 1); return true; };
        if Equals(role, n"guard2") { this.Set("created_guard2", 1); return true; };
        return false;
    }
    private func ValidActor(role: CName, npc: ref<NPCPuppet>) -> Bool {
        if !IsDefined(npc) || !npc.IsAttached() { return false; };
        if Equals(role, n"target") { return npc.GetRecordID() == t"Character.NCPDPatrol_VossContractor01"; };
        if Equals(role, n"guard1") { return npc.GetRecordID() == t"Character.NCPDPatrol_VossGuard01"; };
        if Equals(role, n"guard2") { return npc.GetRecordID() == t"Character.NCPDPatrol_VossGuard02"; };
        return false;
    }
    private func RoleTag(role: CName) -> CName {
        if Equals(role, n"target") { return n"ncpd_patrol_off_the_books_target"; };
        if Equals(role, n"guard1") { return n"ncpd_patrol_off_the_books_guard1"; };
        return n"ncpd_patrol_off_the_books_guard2";
    }
    private func Owns(role: CName, npc: ref<NPCPuppet>) -> Bool {
        let entities: ref<DynamicEntitySystem> = GameInstance.GetDynamicEntitySystem();
        return IsDefined(entities) && entities.IsReady() && this.ValidActor(role, npc)
            && entities.IsManaged(npc.GetEntityID()) && entities.IsTagged(npc.GetEntityID(), n"ncpd_patrol_off_the_books")
            && entities.IsTagged(npc.GetEntityID(), this.RoleTag(role));
    }
    private func RefreshActors() -> Void {
        let entities: ref<DynamicEntitySystem> = GameInstance.GetDynamicEntitySystem();
        let npc: ref<NPCPuppet>;
        if !IsDefined(entities) || !entities.IsReady() { return; };
        npc = entities.GetEntity(entities.GetTaggedID(this.RoleTag(n"target"))) as NPCPuppet;
        this.BindActor(n"target", npc, this.GetCycle());
        npc = entities.GetEntity(entities.GetTaggedID(this.RoleTag(n"guard1"))) as NPCPuppet;
        this.BindActor(n"guard1", npc, this.GetCycle());
        npc = entities.GetEntity(entities.GetTaggedID(this.RoleTag(n"guard2"))) as NPCPuppet;
        this.BindActor(n"guard2", npc, this.GetCycle());
    }
    private func Hold(npc: ref<NPCPuppet>) -> ref<AIHoldPositionCommand> {
        let command: ref<AIHoldPositionCommand>;
        let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
        if npc.IsDead() { return null; };
        npc.GetAttitudeAgent().SetAttitudeGroup(n"neutral");
        if IsDefined(player) { npc.GetAttitudeAgent().SetAttitudeTowards(player.GetAttitudeAgent(), EAIAttitude.AIA_Neutral); };
        if this.Fact("provoked") > 0 || Equals(npc.GetHighLevelStateFromBlackboard(), gamedataNPCHighLevelState.Combat) { return null; };
        command = new AIHoldPositionCommand(); command.duration = -1.0;
        command.ignoreInCombat = true; command.removeAfterCombat = true;
        AIComponent.SendCommand(npc, command);
        return command;
    }
    public func BindActor(role: CName, npc: ref<NPCPuppet>, cycle: Int32) -> Bool {
        let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
        if !this.IsReady() || !this.IsActive() || cycle != this.GetCycle() || !this.WasCreated(role) || !this.Owns(role, npc) { return false; };
        if Equals(role, n"target") {
            if this.m_target != npc { this.m_target = npc; this.m_holdTarget = this.Hold(npc); };
        } else {
            if Equals(role, n"guard1") {
                if this.m_guard1 != npc { this.m_guard1 = npc; this.m_hold1 = this.Hold(npc); };
            } else {
                if this.m_guard2 != npc { this.m_guard2 = npc; this.m_hold2 = this.Hold(npc); };
            };
            if this.Fact("player_provoked") > 0 && IsDefined(player) { this.Engage(npc, player); };
        };
        return true;
    }
    public func SeedEvidence() -> Bool {
        let tx: ref<TransactionSystem>;
        let item: ItemID = ItemID.FromTDBID(t"Items.NCPDPatrol_VossEvidence01");
        if !this.IsActive() || !this.ValidActor(n"target", this.m_target) { return false; };
        if this.Fact("seeded") > 0 { return true; };
        tx = GameInstance.GetTransactionSystem(this.GetGameInstance());
        if !IsDefined(tx) { return false; };
        if tx.GetItemQuantity(this.m_target, item) < 1 {
            if !tx.GiveItem(this.m_target, item, 1) { return false; };
        };
        if tx.GetItemQuantity(this.m_target, item) < 1 { return false; };
        this.Set("seeded", 1);
        return true;
    }
    public func HasEvidence() -> Bool { return this.Fact("acquired") > 0; }
    public func TargetDead() -> Bool { return this.Fact("killed") > 0; }
    public func ObserveEvidence(player: ref<PlayerPuppet>, item: ItemID) -> Void {
        // Gen_Readable has already been consumed into the Shards journal by
        // the original player handler. The real acquisition event is proof.
        if !NCPDPatrolMarkerSession.WorldReady() || !this.IsActive() || this.Fact("seeded") <= 0
            || !IsDefined(player) || player != GetPlayer(this.GetGameInstance()) || !ItemID.IsValid(item)
            || ItemID.GetTDBID(item) != t"Items.NCPDPatrol_VossEvidence01" || this.Fact("acquired") > 0 { return; };
        this.Set("acquired", 1);
    }
    private func ReleaseHolds() -> Void {
        if IsDefined(this.m_target) && IsDefined(this.m_holdTarget) { AIComponent.CancelCommand(this.m_target, this.m_holdTarget); };
        if IsDefined(this.m_guard1) && IsDefined(this.m_hold1) { AIComponent.CancelCommand(this.m_guard1, this.m_hold1); };
        if IsDefined(this.m_guard2) && IsDefined(this.m_hold2) { AIComponent.CancelCommand(this.m_guard2, this.m_hold2); };
        this.m_holdTarget = null; this.m_hold1 = null; this.m_hold2 = null;
    }
    private func Engage(guard: ref<NPCPuppet>, attacker: ref<GameObject>) -> Void {
        if !IsDefined(guard) || !guard.IsAttached() || guard.IsDead() || !IsDefined(attacker) || !attacker.IsAttached() { return; };
        if !IsDefined(attacker.GetAttitudeAgent()) { return; };
        guard.GetAttitudeAgent().SetAttitudeTowards(attacker.GetAttitudeAgent(), EAIAttitude.AIA_Hostile);
        TargetTrackingExtension.InjectThreat(guard, attacker);
    }
    public func ObserveHit(victim: ref<NPCPuppet>, hit: ref<gameHitEvent>) -> Void {
        let attacker: ref<GameObject>;
        if !NCPDPatrolMarkerSession.WorldReady() || !this.IsActive() || !IsDefined(victim)
            || (!this.Owns(n"target", victim) && !this.Owns(n"guard1", victim) && !this.Owns(n"guard2", victim))
            || !IsDefined(hit) || hit.target != victim || !IsDefined(hit.attackData) { return; };
        attacker = hit.attackData.GetInstigator();
        if !IsDefined(attacker) || attacker == this.m_target || attacker == this.m_guard1 || attacker == this.m_guard2 { return; };
        this.Set("provoked", 1);
        if attacker == GetPlayer(this.GetGameInstance()) { this.Set("player_provoked", 1); };
        this.RefreshActors();
        if IsDefined(this.m_target) && this.m_target.IsDead() { this.Set("killed", 1); };
        this.ReleaseHolds(); this.Engage(this.m_guard1, attacker); this.Engage(this.m_guard2, attacker);
    }
    private func Entry(path: String, className: String, state: gameJournalEntryState) -> Void {
        this.Journal().ChangeEntryState(path, className, state, JournalNotifyOption.DoNotNotify);
    }
    public func ObjectiveVisible() -> Bool {
        let entry: ref<JournalEntry>;
        if !this.IsActive() || !IsDefined(this.Journal()) { return false; };
        entry = this.Journal().GetEntryByString(this.Objective(this.GetStage()), "gameJournalQuestObjective");
        return IsDefined(entry) && Equals(this.Journal().GetEntryState(entry), gameJournalEntryState.Active);
    }
    private func OwnTracking(entry: wref<JournalEntry>) -> Bool {
        let i: Int32 = 1;
        if !IsDefined(entry) { return false; };
        while i <= 4 {
            if entry == this.Journal().GetEntryByString(this.Objective(i), "gameJournalQuestObjective") { return true; };
            i += 1;
        };
        return false;
    }
    private func SyncJournal(forceTrack: Bool) -> Void {
        let stage: Int32 = this.GetStage();
        let i: Int32 = 1;
        let tracked: wref<JournalEntry> = this.Journal().GetTrackedEntry();
        let objective: wref<JournalEntry>;
        let pin: ref<NCPDPatrolSceneMarker>;
        let state: gameJournalEntryState;
        if IsDefined(this.m_marker) { this.m_marker.Close(this.GetGameInstance()); this.m_marker = null; };
        this.Entry(this.Root(), "gameJournalQuest", gameJournalEntryState.Active);
        this.Entry(this.Root() + "/main", "gameJournalQuestPhase", gameJournalEntryState.Active);
        while i <= 4 {
            if i == stage { state = gameJournalEntryState.Active; } else {
                if i < stage { state = gameJournalEntryState.Succeeded; } else { state = gameJournalEntryState.Inactive; };
            };
            if i == 3 && stage != 3 && this.Fact("escape_used") == 0 { state = gameJournalEntryState.Inactive; };
            this.Entry(this.Objective(i), "gameJournalQuestObjective", state);
            // Close only our own fixed pins on restore and transitions.
            if i != 3 {
                pin = new NCPDPatrolSceneMarker(); pin.Configure(this.Objective(i), this.Root() + "/main", this.Position(i));
                pin.Close(this.GetGameInstance());
            };
            i += 1;
        };
        objective = this.Journal().GetEntryByString(this.Objective(stage), "gameJournalQuestObjective");
        if !this.ObjectiveVisible() { this.m_syncedStage = -1; return; };
        if forceTrack || !IsDefined(tracked) || tracked == this.m_lastObjective || this.OwnTracking(tracked) { this.Journal().TrackEntry(objective); };
        this.m_lastObjective = objective;
        if stage != 3 {
            this.m_marker = new NCPDPatrolSceneMarker();
            this.m_marker.Configure(this.Objective(stage), this.Root() + "/main", this.Position(stage)); this.m_marker.Open(this.GetGameInstance());
        };
        this.m_syncedStage = stage;
    }
    public func Tick(delta: Float) -> Void {
        let stage: Int32;
        let next: Int32;
        let player: ref<PlayerPuppet>;
        if !NCPDPatrolMarkerSession.WorldReady() || !this.IsActive() || this.IsMenuOpen() || delta <= 0.0 || delta > 0.5 { return; };
        player = GetPlayer(this.GetGameInstance());
        if !IsDefined(player) || !player.IsAttached() || player.IsDead() { return; };
        // A real death, not defeated/unconscious, fulfils Voss's instruction.
        if IsDefined(this.m_target) && this.m_target.IsAttached() && this.m_target.IsDead() { this.Set("killed", 1); };
        stage = this.GetStage(); next = stage;
        // Facts survive shift/session reset, but this operation progresses off duty.
        if !this.OnDuty() {
            if this.TargetDead() {
                if !this.HasEvidence() { next = 2; } else {
                    if this.Wanted() { next = 3; this.Set("escape_used", 1); } else { next = 4; };
                };
            };
            if next != stage { this.Set("stage", next); };
        };
        if this.m_syncedStage != this.GetStage() || !this.ObjectiveVisible() { this.SyncJournal(false); };
        if IsDefined(this.m_marker) { this.m_marker.Tick(this.GetGameInstance(), delta); };
    }
    public func AtVoss(npc: ref<NPCPuppet>) -> Bool {
        let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
        if this.GetStage() != 4 || this.OnDuty() || this.Wanted() || !IsDefined(player) || player.IsInCombat()
            || !IsDefined(npc) || !npc.IsAttached() || npc.IsDead() || npc.GetRecordID() != t"Character.NCPDPatrol_QG_Investigator"
            || Vector4.Distance(player.GetWorldPosition(), npc.GetWorldPosition()) > 3.0 { return false; };
        this.Set("returned", 1);
        return true;
    }
    public func Cancel() -> Void {
        let i: Int32 = 1;
        let pin: ref<NCPDPatrolSceneMarker>;
        if !NCPDPatrolMarkerSession.WorldReady() || !IsDefined(this.Journal()) { return; };
        this.ReleaseHolds();
        if IsDefined(this.m_marker) { this.m_marker.Close(this.GetGameInstance()); this.m_marker = null; };
        while i <= 4 {
            if i != 3 {
                pin = new NCPDPatrolSceneMarker(); pin.Configure(this.Objective(i), this.Root() + "/main", this.Position(i)); pin.Close(this.GetGameInstance());
            };
            this.Entry(this.Objective(i), "gameJournalQuestObjective", gameJournalEntryState.Inactive); i += 1;
        };
        this.Entry(this.Root() + "/main", "gameJournalQuestPhase", gameJournalEntryState.Inactive);
        this.Entry(this.Root(), "gameJournalQuest", gameJournalEntryState.Inactive);
        if this.Journal().GetTrackedEntry() == this.m_lastObjective && IsDefined(this.m_previous) { this.Journal().TrackEntry(this.m_previous); };
        this.Set("stage", 0); this.m_syncedStage = -1;
        this.m_target = null; this.m_guard1 = null; this.m_guard2 = null;
        this.m_lastObjective = null; this.m_previous = null;
    }
    public func GetDiagnostics() -> String {
        let marker: String = "No scene pin during escape";
        let killed: Int32 = this.Fact("killed");
        let acquired: Int32 = this.Fact("acquired");
        let seeded: Int32 = this.Fact("seeded");
        if IsDefined(this.m_marker) { marker = this.m_marker.GetDiagnostics(); };
        return s"stage=\(this.GetStage()) | cycle=\(this.GetCycle()) | killed=\(killed) | acquired=\(acquired) | seeded=\(seeded) | wanted=\(this.Wanted()) | off duty=\(!this.OnDuty()) | \(marker)";
    }
}
