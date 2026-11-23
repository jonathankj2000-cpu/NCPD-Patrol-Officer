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
    private let m_reason: String;
    private let m_syncPoll: Float;
    private let m_writeStage: Int32;
    private let m_trackPending: Bool;
    private let m_lootPoll: Float;
    private let m_lootAttempts: Int32;
    private let m_lootRefreshed: Bool;
    private let m_processLootRequested: Bool;
    private let m_evidenceLootReason: String;
    private let m_combatSampled: Bool;
    private let m_combatAllowed: Bool;
    private let m_requestedTier: Int32;
    private let m_tierSource: String;
    private let m_emptyHandsRequested: Bool;
    private let m_forceEmptyHandsSample: Bool;
    private let m_upperBodySample: Int32;
    private let m_highLevelSample: Int32;
    private func OnRestored(saveVersion: Int32, gameVersion: Int32) -> Void {
        this.m_target = null; this.m_guard1 = null; this.m_guard2 = null;
        this.m_holdTarget = null; this.m_hold1 = null; this.m_hold2 = null;
        this.m_marker = null; this.m_syncedStage = -1;
        this.m_previous = null; this.m_lastObjective = null;
        this.m_syncPoll = 0.0; this.m_writeStage = 0;
        this.m_trackPending = false;
        this.ResetEncounterProbes();
    }
    private func ResetEncounterProbes() -> Void {
        this.m_lootPoll = 0.0; this.m_lootAttempts = 0; this.m_lootRefreshed = false;
        this.m_processLootRequested = false; this.m_evidenceLootReason = "Waiting for native death loot";
        this.m_combatSampled = false; this.m_combatAllowed = false;
        this.m_requestedTier = 0; this.m_tierSource = "not sampled";
        this.m_emptyHandsRequested = false; this.m_forceEmptyHandsSample = false;
        this.m_upperBodySample = 0; this.m_highLevelSample = 0;
    }
    // A decision exception, not a blackboard writer. ExplorationEvents owns the
    // native exit/reset; the untouched SceneTier request resumes outside scope.
    // Tier 2's empty-hands flag and WeaponReady's HighLevel listener both matter.
    public func CombatAreaEligible(player: ref<PlayerPuppet>) -> Bool {
        let position: Vector4;
        let site: Vector4 = NCPDPatrolOffBooksSystem.Site();
        let first: ref<NCPDPatrolQuestGiverTest>;
        if !NCPDPatrolMarkerSession.WorldReady() || (this.GetStage() != 1 && this.GetStage() != 2)
            || this.HasEvidence() || this.OnDuty() || this.IsMenuOpen() || !this.ObjectiveVisible()
            || !IsDefined(player) || player != GetPlayer(this.GetGameInstance()) || !player.IsAttached() || player.IsDead()
            || !this.Owns(n"target", this.m_target) { return false; };
        first = this.FirstBriefing();
        if !IsDefined(first) || !first.HasBriefingReceipt() || first.GetStage() == 2 { return false; };
        position = player.GetWorldPosition();
        return Vector4.Distance(position, site) <= 20.0
            && AbsF(position.Z - site.Z) <= 3.0;
    }

    public func AllowRestaurantExploration(const stateContext: ref<StateContext>, const scriptInterface: ref<StateGameScriptInterface>) -> Bool {
        let tier: ref<SceneTier>;
        let data: ref<SceneTierData>;
        let player: ref<PlayerPuppet>;
        let workspots: ref<WorkspotGameSystem>;
        let scene: ref<SceneSystem>;
        let sceneInterface: ref<SceneSystemInterface>;
        let high: Int32;
        let allowed: Bool;
        if !IsDefined(stateContext) || !IsDefined(scriptInterface) { return false; };
        player = scriptInterface.executionOwner as PlayerPuppet;
        if !this.CombatAreaEligible(player) || !IsDefined(scriptInterface.localBlackboard) { return false; };
        tier = stateContext.GetPermanentScriptableParameter(n"SceneTier") as SceneTier;
        if !IsDefined(tier) { return false; };
        data = tier.GetTierData();
        if !IsDefined(data) { return false; };
        high = scriptInterface.localBlackboard.GetInt(GetAllBlackboardDefs().PlayerStateMachine.HighLevel);
        workspots = GameInstance.GetWorkspotSystem(this.GetGameInstance());
        scene = scriptInterface.GetSceneSystem();
        if !IsDefined(scene) { return false; };
        sceneInterface = scene.GetScriptInterface();
        if !IsDefined(sceneInterface) { return false; };
        // Independent restrictions, real dialogue, workspots, takedowns, swimming
        // and higher cinematic tiers retain their original decisions.
        allowed = Equals(data.tier, GameplayTier.Tier2_StagedGameplay) && data.emptyHands
            && (high == 1 || high == 2) && IsDefined(workspots) && !workspots.IsActorInWorkspot(player)
            && !VehicleComponent.IsMountedToVehicle(this.GetGameInstance(), player)
            && !sceneInterface.IsEntityInDialogue(player.GetEntityID())
            && !scriptInterface.IsSceneAnimationActive()
            && !stateContext.IsStateMachineActive(n"LocomotionTakedown")
            && !stateContext.GetBoolParameter(n"enteredWaterFromSceneTierII", true)
            && !stateContext.GetBoolParameter(n"ForceEmptyHandsByZone", true)
            && this.Quests().GetFactStr("ForceEmptyHands") == 0
            && !StatusEffectSystem.ObjectHasStatusEffect(player, t"GameplayRestriction.NoCombat")
            && !StatusEffectSystem.ObjectHasStatusEffect(player, t"GameplayRestriction.NoWeapons")
            && !StatusEffectSystem.ObjectHasStatusEffect(player, t"GameplayRestriction.InDaClub")
            && !StatusEffectSystem.ObjectHasStatusEffect(player, t"GameplayRestriction.NoWorldInteractions");
        // Diagnostic samples only. They never own or modify the player's states.
        this.m_combatSampled = true;
        this.m_combatAllowed = allowed;
        this.m_requestedTier = EnumInt(data.tier);
        this.m_tierSource = data.userDebugInfo;
        this.m_emptyHandsRequested = data.emptyHands;
        this.m_forceEmptyHandsSample = stateContext.GetBoolParameter(n"ForceEmptyHands", true);
        this.m_upperBodySample = scriptInterface.localBlackboard.GetInt(GetAllBlackboardDefs().PlayerStateMachine.UpperBody);
        this.m_highLevelSample = high;
        return allowed;
    }

    public static func RestaurantExploration(const stateContext: ref<StateContext>, const scriptInterface: ref<StateGameScriptInterface>) -> Bool {
        let owner: ref<NCPDPatrolOffBooksSystem>;
        if !IsDefined(scriptInterface) || !IsDefined(scriptInterface.executionOwner) { return false; };
        owner = GameInstance.GetScriptableSystemsContainer(scriptInterface.executionOwner.GetGame()).Get(n"NCPDPatrolOffBooksSystem") as NCPDPatrolOffBooksSystem;
        return IsDefined(owner) && owner.AllowRestaurantExploration(stateContext, scriptInterface);
    }


    public func Version() -> Int32 { return 4; }
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
        if !IsDefined(item) || !this.EvidenceLootConfigured()
            || !IsDefined(TweakDBInterface.GetCharacterRecord(t"Character.NCPDPatrol_VossContractor01"))
            || !IsDefined(TweakDBInterface.GetCharacterRecord(t"Character.NCPDPatrol_VossGuard01"))
            || !IsDefined(TweakDBInterface.GetCharacterRecord(t"Character.NCPDPatrol_VossGuard02"))
            || !IsDefined(TweakDBInterface.GetCharacterRecord(t"Character.CorpoManArasaka"))
            || !IsDefined(TweakDBInterface.GetCharacterRecord(t"Character.arasaka_cyborg_franged3_shingen_ma_elite"))
            || !IsDefined(TweakDBInterface.GetItemRecord(t"Items.generic_arasaka_family_backstory_shard")) { return false; };
        read = ItemActionsHelper.GetReadAction(ItemID.FromTDBID(t"Items.NCPDPatrol_VossEvidence01"));
        return IsDefined(read) && read.GetID() == t"ItemAction.NCPDPatrol_VossEvidenceRead01"
            && Equals(ReadAction.GetJournalEntryFromAction(read.GetID()), this.ShardPath());
    }
    public func EvidenceLootConfigured() -> Bool {
        let actor: wref<Character_Record> = TweakDBInterface.GetCharacterRecord(t"Character.NCPDPatrol_VossContractor01");
        let drop: wref<LootTable_Record>;
        let entry: wref<LootItem_Record>;
        if !IsDefined(actor) { return false; };
        drop = actor.LootDrop();
        if !IsDefined(drop) || drop.GetID() != t"LootTables.NCPDPatrol_VossEvidence01"
            || drop.GetLootItemsCount() != 1 || drop.MinItemsToLoot() != 1 || drop.MaxItemsToLoot() != 1 { return false; };
        entry = drop.GetLootItemsItem(0);
        return IsDefined(entry) && IsDefined(entry.ItemID()) && entry.ItemID().GetID() == t"Items.NCPDPatrol_VossEvidence01"
            && entry.DropChance() >= 1.0 && entry.DropCountMin() == 1 && entry.DropCountMax() == 1;
    }
    public func IsReady() -> Bool {
        return NCPDPatrolMarkerSession.WorldReady() && IsDefined(this.Quests()) && IsDefined(this.Journal())
            && this.RecordsReady() && IsDefined(this.Journal().GetEntryByString(this.Root(), "gameJournalQuest"))
            && IsDefined(this.Journal().GetEntryByString(this.ShardPath(), "gameJournalOnscreen"));
    }
    private func FirstBriefing() -> ref<NCPDPatrolQuestGiverTest> {
        return GameInstance.GetScriptableSystemsContainer(this.GetGameInstance()).Get(n"NCPDPatrolQuestGiverTest") as NCPDPatrolQuestGiverTest;
    }
    public func AutoSuppressed() -> Bool {
        let first: ref<NCPDPatrolQuestGiverTest> = this.FirstBriefing();
        return this.Fact("suppress_auto") > 0 && IsDefined(first)
            && this.Fact("suppressed_cycle") == first.GetBriefingCycle();
    }
    public func StartBlocker() -> String {
        let first: ref<NCPDPatrolQuestGiverTest>;
        let i: Int32 = 1;
        let path: String;
        if !NCPDPatrolMarkerSession.WorldReady() { return "Game session is not ready"; };
        if !IsDefined(this.Quests()) || !IsDefined(this.Journal()) { return "Native quest/journal service unavailable"; };
        if this.IsMenuOpen() { return "Close in-game menus before continuing"; };
        if this.OnDuty() { return "Go OFF DUTY before continuing"; };
        first = this.FirstBriefing();
        if !IsDefined(first) { return "Voss briefing bridge unavailable; install the complete v0.20d package"; };
        if !first.HasBriefingReceipt() { return "Voss final dialogue receipt not yet recorded; inspect quest giver diagnostics"; };
        if !this.RecordsReady() { return "Contractor/guard/shard records, native evidence loot table or exact Read action unavailable in TweakDB"; };
        if !IsDefined(this.Journal().GetEntryByString(this.Root(), "gameJournalQuest")) { return "Missing journal quest: " + this.Root(); };
        if !IsDefined(this.Journal().GetEntryByString(this.Root() + "/main", "gameJournalQuestPhase")) { return "Missing journal phase: " + this.Root() + "/main"; };
        while i <= 4 {
            path = this.Objective(i);
            if !IsDefined(this.Journal().GetEntryByString(path, "gameJournalQuestObjective")) { return "Missing journal objective: " + path; };
            if !IsDefined(this.Journal().GetEntryByString(path + "/briefing", "gameJournalQuestDescription")) { return "Missing journal description: " + path; };
            i += 1;
        };
        if !IsDefined(this.Journal().GetEntryByString(this.ShardPath(), "gameJournalOnscreen")) { return "Missing readable journal entry: " + this.ShardPath(); };
        return "";
    }
    public func GetStartReason() -> String { return this.m_reason; }
    public func Begin() -> Bool {
        if this.GetStage() != 0 { return this.IsActive(); };
        this.m_reason = this.StartBlocker();
        if NotEquals(this.m_reason, "") { return false; };
        this.Set("cycle", this.GetCycle() + 1);
        this.Set("killed", 0); this.Set("acquired", 0); this.Set("seeded", 0);
        this.Set("qty_before_seen", 0); this.Set("qty_after_seen", 0);
        this.Set("qty_before", 0); this.Set("qty_after", 0); this.Set("acquisition_event", 0);
        this.Set("corpse_confirmed", 0); this.Set("corpse_repair_used", 0);
        this.ResetEncounterProbes();
        this.Set("provoked", 0); this.Set("player_provoked", 0); this.Set("returned", 0); this.Set("escape_used", 0);
        this.Set("created_target", 0); this.Set("created_guard1", 0); this.Set("created_guard2", 0);
        this.Set("suppress_auto", 0);
        this.Set("activation_complete", 0);
        this.m_previous = this.Journal().GetTrackedEntry();
        this.m_trackPending = true;
        this.Set("stage", 1); this.m_syncedStage = -1; this.m_writeStage = 0; this.m_syncPoll = 0.0;
        this.SyncJournal(true);
        // Acceptance is not journal activation proof. Tick keeps the same
        // request alive until native state is observed; no eager rollback.
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
            if this.m_target != npc {
                this.m_target = npc; this.m_holdTarget = this.Hold(npc);
                this.m_lootPoll = 0.0; this.m_lootAttempts = 0; this.m_lootRefreshed = false;
                this.m_processLootRequested = false;
            };
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
        if this.EvidenceQuantity() < 1 {
            if !tx.GiveItem(this.m_target, item, 1) { return false; };
        };
        if this.EvidenceQuantity() < 1 { return false; };
        this.Set("seeded", 1);
        this.SampleEvidenceInventory();
        return true;
    }
    private func EvidenceQuantity() -> Int32 {
        let tx: ref<TransactionSystem> = GameInstance.GetTransactionSystem(this.GetGameInstance());
        if !this.ValidActor(n"target", this.m_target) || !IsDefined(tx) { return -1; };
        return tx.GetItemQuantity(this.m_target, ItemID.CreateQuery(t"Items.NCPDPatrol_VossEvidence01"));
    }
    private func SampleEvidenceInventory() -> Void {
        let quantity: Int32 = this.EvidenceQuantity();
        if quantity < 0 { return; };
        if this.m_target.IsDead() {
            if this.Fact("qty_after_seen") == 0 {
                this.Set("qty_after", quantity); this.Set("qty_after_seen", 1);
            };
        } else {
            if this.Fact("qty_before_seen") == 0 || this.Fact("qty_before") != quantity {
                this.Set("qty_before", quantity); this.Set("qty_before_seen", 1);
            };
        };
    }
    private func MaintainEvidenceLoot(delta: Float) -> Void {
        let tx: ref<TransactionSystem>;
        let quantity: Int32;
        let player: ref<PlayerPuppet>;
        this.SampleEvidenceInventory();
        if !this.Owns(n"target", this.m_target) || !this.m_target.IsDead() { return; };
        this.m_lootPoll += delta;
        if this.m_lootPoll < 1.0 || this.m_lootAttempts >= 8 { return; };
        this.m_lootPoll = 0.0;
        tx = GameInstance.GetTransactionSystem(this.GetGameInstance());
        if !IsDefined(tx) { return; };
        quantity = this.EvidenceQuantity();
        if this.HasEvidence() {
            // A restored/generated extra copy is never offered after receipt.
            if quantity > 0 { tx.RemoveItemByTDBID(this.m_target, t"Items.NCPDPatrol_VossEvidence01", quantity, true); };
            this.m_evidenceLootReason = "Evidence already acquired; no corpse replenishment";
            return;
        };
        if this.m_lootRefreshed && quantity == 1 && this.m_target.NCPDPatrolOffBooksLootReady() { return; };
        this.m_lootAttempts += 1;
        if !this.m_target.WasLootGenerated() {
            // The vanilla disposal path uses this same guard before ProcessLoot.
            // Never insert evidence ahead of a pending native inventory rebuild.
            if !this.m_processLootRequested { this.m_processLootRequested = true; this.m_target.ProcessLoot(); };
            if !this.m_target.WasLootGenerated() {
                this.m_evidenceLootReason = "Waiting for native ProcessLoot completion; no corpse grant"; return;
            };
        };
        quantity = this.EvidenceQuantity();
        if quantity > 1 {
            tx.RemoveItemByTDBID(this.m_target, t"Items.NCPDPatrol_VossEvidence01", quantity - 1, true);
            quantity = this.EvidenceQuantity();
        };
        if quantity == 0 {
            player = GetPlayer(this.GetGameInstance());
            if this.Fact("seeded") <= 0 || this.Fact("corpse_confirmed") > 0 || this.Fact("corpse_repair_used") > 0
                || !IsDefined(player) || tx.GetItemQuantity(player, ItemID.CreateQuery(t"Items.NCPDPatrol_VossEvidence01")) > 0 {
                this.m_evidenceLootReason = "Empty corpse retained; evidence previously confirmed, pending pickup or recovery already used"; return;
            };
            // One migration for the reported v0.20c empty corpse. The item goes
            // to the owned body only; this never records player acquisition.
            this.Set("corpse_repair_used", 1);
            if !tx.GiveItem(this.m_target, ItemID.FromTDBID(t"Items.NCPDPatrol_VossEvidence01"), 1) {
                this.Set("corpse_repair_used", 0); this.m_evidenceLootReason = "Native corpse evidence restore rejected"; return;
            };
            quantity = this.EvidenceQuantity();
        };
        if quantity != 1 { this.m_evidenceLootReason = "Waiting for exactly one evidence item in native corpse inventory"; return; };
        this.Set("seeded", 1); this.Set("corpse_confirmed", 1);
        this.m_lootRefreshed = this.m_target.NCPDPatrolOffBooksRefreshLoot();
        this.m_evidenceLootReason = "Native death loot confirmed; one shard in corpse, player pickup still required";
    }
    public func HasEvidence() -> Bool { return this.Fact("acquired") > 0; }
    public func TargetDead() -> Bool { return this.Fact("killed") > 0; }
    public func ObserveEvidence(player: ref<PlayerPuppet>, item: ItemID) -> Void {
        // Gen_Readable has already been consumed into the Shards journal by
        // the original player handler. The real acquisition event is proof.
        if !NCPDPatrolMarkerSession.WorldReady() || !this.IsActive() || this.Fact("seeded") <= 0
            || !IsDefined(player) || player != GetPlayer(this.GetGameInstance()) || !ItemID.IsValid(item)
            || ItemID.GetTDBID(item) != t"Items.NCPDPatrol_VossEvidence01" || this.Fact("acquired") > 0 { return; };
        this.Set("acquisition_event", 1);
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
    private func Entry(path: String, className: String, state: gameJournalEntryState) -> Bool {
        let entry: wref<JournalEntry> = this.Journal().GetEntryByString(path, className);
        if !IsDefined(entry) { this.m_reason = "Missing journal entry: " + path; return false; };
        if Equals(this.Journal().GetEntryState(entry), state) { return true; };
        if !this.Journal().ChangeEntryState(path, className, state, JournalNotifyOption.DoNotNotify) {
            this.m_reason = "Journal state request rejected: " + path; return false;
        };
        if !Equals(this.Journal().GetEntryState(entry), state) {
            this.m_reason = "Waiting for native journal state: " + path; return false;
        };
        return true;
    }
    public func ObjectiveVisible() -> Bool {
        let entry: ref<JournalEntry>;
        if !this.IsActive() || !IsDefined(this.Journal()) { return false; };
        entry = this.Journal().GetEntryByString(this.Objective(this.GetStage()), "gameJournalQuestObjective");
        return IsDefined(entry) && Equals(this.Journal().GetEntryState(entry), gameJournalEntryState.Active)
            && this.ActiveEntry(this.Root(), "gameJournalQuest")
            && this.ActiveEntry(this.Root() + "/main", "gameJournalQuestPhase")
            && this.ActiveEntry(this.Objective(this.GetStage()) + "/briefing", "gameJournalQuestDescription");
    }
    private func ActiveEntry(path: String, kind: String) -> Bool {
        let entry: wref<JournalEntry> = this.Journal().GetEntryByString(path, kind);
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
        let description: gameJournalEntryState;
        this.m_syncPoll = 0.0;
        if this.m_writeStage != stage {
            if IsDefined(this.m_marker) { this.m_marker.Close(this.GetGameInstance()); this.m_marker = null; };
            while i <= 4 {
                if i != 3 {
                    pin = new NCPDPatrolSceneMarker(); pin.Configure(this.Objective(i), this.Root() + "/main", this.Position(i)); pin.Close(this.GetGameInstance());
                };
                i += 1;
            };
            this.m_writeStage = stage;
        };
        // Activate the next objective before retiring the previous one. Keep
        // parents and descriptions active as in the working incident owners.
        if !this.Entry(this.Root(), "gameJournalQuest", gameJournalEntryState.Active)
            || !this.Entry(this.Root() + "/main", "gameJournalQuestPhase", gameJournalEntryState.Active)
            || !this.Entry(this.Objective(stage) + "/briefing", "gameJournalQuestDescription", gameJournalEntryState.Active)
            || !this.Entry(this.Objective(stage), "gameJournalQuestObjective", gameJournalEntryState.Active) { return; };
        i = 1;
        while i <= 4 {
            if i == stage { state = gameJournalEntryState.Active; } else {
                if i < stage { state = gameJournalEntryState.Succeeded; } else { state = gameJournalEntryState.Inactive; };
            };
            if i == 3 && stage != 3 && this.Fact("escape_used") == 0 { state = gameJournalEntryState.Inactive; };
            description = gameJournalEntryState.Inactive;
            if Equals(state, gameJournalEntryState.Active) || Equals(state, gameJournalEntryState.Succeeded) { description = gameJournalEntryState.Active; };
            if !this.Entry(this.Objective(i) + "/briefing", "gameJournalQuestDescription", description)
                || !this.Entry(this.Objective(i), "gameJournalQuestObjective", state) { return; };
            i += 1;
        };
        objective = this.Journal().GetEntryByString(this.Objective(stage), "gameJournalQuestObjective");
        if !this.ObjectiveVisible() { this.m_syncedStage = -1; return; };
        if forceTrack || (this.m_trackPending && tracked == this.m_previous)
            || !IsDefined(tracked) || tracked == this.m_lastObjective || this.OwnTracking(tracked) { this.Journal().TrackEntry(objective); };
        this.m_trackPending = false;
        this.m_lastObjective = objective;
        if stage != 3 {
            this.m_marker = new NCPDPatrolSceneMarker();
            this.m_marker.Configure(this.Objective(stage), this.Root() + "/main", this.Position(stage)); this.m_marker.Open(this.GetGameInstance());
        };
        this.m_syncedStage = stage;
        this.Set("activation_complete", 1);
        this.m_reason = "Journal objective active; continuation confirmed";
    }
    public func Tick(delta: Float) -> Void {
        let stage: Int32;
        let next: Int32;
        let player: ref<PlayerPuppet>;
        if !NCPDPatrolMarkerSession.WorldReady() || !this.IsActive() || this.IsMenuOpen() || delta <= 0.0 || delta > 0.5 { return; };
        player = GetPlayer(this.GetGameInstance());
        if !IsDefined(player) || !player.IsAttached() || player.IsDead() { return; };
        if this.GetStage() == 1 && this.Fact("activation_complete") == 0 {
            this.m_trackPending = true;
            if !IsDefined(this.m_previous) { this.m_previous = this.Journal().GetTrackedEntry(); };
        };
        // A real death, not defeated/unconscious, fulfils Voss's instruction.
        if IsDefined(this.m_target) && this.m_target.IsAttached() && this.m_target.IsDead() { this.Set("killed", 1); };
        this.MaintainEvidenceLoot(delta);
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
        this.m_syncPoll += delta;
        if this.m_writeStage != this.GetStage()
            || ((this.m_syncedStage != this.GetStage() || !this.ObjectiveVisible()) && this.m_syncPoll >= 1.0) { this.SyncJournal(false); };
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
        this.Set("suppress_auto", 1);
        if IsDefined(this.FirstBriefing()) { this.Set("suppressed_cycle", this.FirstBriefing().GetBriefingCycle()); };
        this.ReleaseHolds();
        if IsDefined(this.m_marker) { this.m_marker.Close(this.GetGameInstance()); this.m_marker = null; };
        while i <= 4 {
            if i != 3 {
                pin = new NCPDPatrolSceneMarker(); pin.Configure(this.Objective(i), this.Root() + "/main", this.Position(i)); pin.Close(this.GetGameInstance());
            };
            this.Entry(this.Objective(i), "gameJournalQuestObjective", gameJournalEntryState.Inactive);
            this.Entry(this.Objective(i) + "/briefing", "gameJournalQuestDescription", gameJournalEntryState.Inactive); i += 1;
        };
        this.Entry(this.Root() + "/main", "gameJournalQuestPhase", gameJournalEntryState.Inactive);
        this.Entry(this.Root(), "gameJournalQuest", gameJournalEntryState.Inactive);
        if this.Journal().GetTrackedEntry() == this.m_lastObjective && IsDefined(this.m_previous) { this.Journal().TrackEntry(this.m_previous); };
        this.Set("stage", 0); this.m_syncedStage = -1;
        this.m_target = null; this.m_guard1 = null; this.m_guard2 = null;
        this.m_lastObjective = null; this.m_previous = null;
        this.m_writeStage = 0; this.m_syncPoll = 0.0; this.m_reason = "Explicitly cancelled; waiting for owned actor cleanup";
        this.m_trackPending = false;
        this.ResetEncounterProbes();
    }
    public func GetDiagnostics() -> String {
        let marker: String = "No scene pin during escape";
        let record: String = "unloaded";
        let death: String = "unloaded";
        let loot: String = "corpse loot=unavailable (contractor not attached)";
        let before: String = "unobserved";
        let after: String = "unobserved";
        let itemValid: Bool = IsDefined(TweakDBInterface.GetItemRecord(t"Items.NCPDPatrol_VossEvidence01"));
        let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
        let killed: Int32 = this.Fact("killed");
        let acquired: Int32 = this.Fact("acquired");
        let seeded: Int32 = this.Fact("seeded");
        let acquisition: Bool = this.Fact("acquisition_event") > 0;
        let confirmed: Int32 = this.Fact("corpse_confirmed");
        let repaired: Int32 = this.Fact("corpse_repair_used");
        let generated: Bool = IsDefined(this.m_target) && this.m_target.IsAttached() && this.m_target.WasLootGenerated();
        if this.ValidActor(n"target", this.m_target) {
            record = TDBID.ToStringDEBUG(this.m_target.GetRecordID());
            death = "alive"; if this.m_target.IsDead() { death = "dead"; };
            loot = this.m_target.NCPDPatrolOffBooksLootDiagnostics();
        };
        if this.Fact("qty_before_seen") > 0 { before = IntToString(this.Fact("qty_before")); };
        if this.Fact("qty_after_seen") > 0 { after = IntToString(this.Fact("qty_after")); };
        if IsDefined(this.m_marker) { marker = this.m_marker.GetDiagnostics(); };
        return s"stage=\(this.GetStage()) | cycle=\(this.GetCycle()) | killed=\(killed) | acquired=\(acquired) | seeded=\(seeded) | wanted=\(this.Wanted()) | off duty=\(!this.OnDuty()) | contractor record=\(record) | shard registered=\(itemValid) | shard before death=\(before) | shard after death=\(after) | shard now=\(this.EvidenceQuantity()) | contractor=\(death) | acquisition event=\(acquisition) | \(loot) | death loot configured=\(this.EvidenceLootConfigured()) | native loot generated=\(generated) | corpse confirmed=\(confirmed) | corpse repair used=\(repaired) | evidence loot status=\(this.m_evidenceLootReason) | loot refresh attempts=\(this.m_lootAttempts) | combat area eligible=\(this.CombatAreaEligible(player)) | PSM sampled=\(this.m_combatSampled) | Tier2 exception last sample=\(this.m_combatAllowed) | requested tier=\(this.m_requestedTier) | tier source=\(this.m_tierSource) | requested empty hands=\(this.m_emptyHandsRequested) | ForceEmptyHands last sample=\(this.m_forceEmptyHandsSample) | UpperBody last sample=\(this.m_upperBodySample) | HighLevel last sample=\(this.m_highLevelSample) | \(marker) | \(this.m_reason)";
    }
}
