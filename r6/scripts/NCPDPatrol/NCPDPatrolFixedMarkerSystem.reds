// Finite journal-pin bank. Owns presentation only; no actors, quest results,
// rewards, career state, story tracking or manual-waypoint writes.
public class NCPDPatrolFixedMarkerSystem extends ScriptableSystem {
    private let m_token: Int32;
    private let m_wanted: Bool;
    private let m_switch: Bool;
    private let m_restorePending: Bool;
    private let m_scope: Int32;
    private let m_site: Int32;
    private let m_target: Vector4;
    private let m_currentPath: String;
    private let m_hash: Uint32;
    private let m_nativeID: NewMappinID;
    private let m_fallbackID: NewMappinID;
    private let m_fallback: Bool;
    private let m_fallbackPending: Bool;
    private let m_fallbackRetry: Float;
    private let m_age: Float;
    private let m_poll: Float;
    private let m_pinCount: Int32;
    private let m_confirmed: Bool;
    private let m_linked: Bool;
    private let m_positionOK: Bool;
    private let m_questPositionOK: Bool;
    private let m_runtimePoint: Vector4;
    private let m_questPoint: Vector3;
    private let m_manualBefore: NewMappinID;
    private let m_manualAfter: NewMappinID;
    private let m_revision: Int32;
    private let m_status: String;
    private let m_detail: String;
    private let m_ownHashes: array<Uint32>;
    private let m_ownPaths: array<String>;
    private let m_activeBankPins: Int32;
    private let m_otherBankPins: Int32;
    private let m_targetActive: Bool;
    private let m_linkHash: Uint32;
    private let m_linkID: NewMappinID;
    private let m_sweepPoll: Float;
    private let m_pruned: Int32;

    public func Version() -> Int32 { return 2; }
    public static func WriteNavigationState(journal: ref<JournalManager>, path: String, kind: String, state: gameJournalEntryState) -> Bool {
        let entry: wref<JournalEntry> = journal.GetEntryByString(path, kind);
        if !IsDefined(entry) { return false; };
        if Equals(journal.GetEntryState(entry), state) { return true; };
        journal.ChangeEntryState(path, kind, state, JournalNotifyOption.DoNotNotify);
        return Equals(journal.GetEntryState(entry), state);
    }
    // Called by the original quest owner. Its stage, token, timers, actor and
    // reward state stay with that owner; only its active objective path changes.
    public static func SwitchNavigationObjective(game: GameInstance, basePath: String, oldPath: String, newPath: String, first: Int32, last: Int32) -> Bool {
        let journal: ref<JournalManager> = GameInstance.GetJournalManager(game);
        let oldEntry: wref<JournalEntry>;
        let newEntry: wref<JournalEntry>;
        let tracked: Bool;
        let oldDescription: String = s"\(oldPath)/briefing";
        let newDescription: String = s"\(newPath)/briefing";
        let candidate: String;
        let description: String;
        let entry: wref<JournalEntry>;
        let site: Int32 = first;
        let ok: Bool = true;
        if !IsDefined(journal) { return false; };
        oldEntry = journal.GetEntryByString(oldPath, "gameJournalQuestObjective");
        newEntry = journal.GetEntryByString(newPath, "gameJournalQuestObjective");
        if !IsDefined(oldEntry) || !IsDefined(newEntry) || !IsDefined(journal.GetEntryByString(newDescription, "gameJournalQuestDescription")) { return false; };
        tracked = journal.GetTrackedEntry() == oldEntry;
        // Reused quest templates must not retain older site objectives.
        while site <= last {
            candidate = s"\(basePath)_bank_\(site)";
            if NotEquals(candidate, oldPath) && NotEquals(candidate, newPath) {
                entry = journal.GetEntryByString(candidate, "gameJournalQuestObjective");
                if IsDefined(entry) && NotEquals(journal.GetEntryState(entry), gameJournalEntryState.Inactive) {
                    description = s"\(candidate)/briefing";
                    if !NCPDPatrolFixedMarkerSystem.WriteNavigationState(journal, description, "gameJournalQuestDescription", gameJournalEntryState.Inactive)
                        || !NCPDPatrolFixedMarkerSystem.WriteNavigationState(journal, candidate, "gameJournalQuestObjective", gameJournalEntryState.Inactive) { return false; };
                };
            };
            site += 1;
        };
        if NotEquals(oldPath, newPath) {
            ok = NCPDPatrolFixedMarkerSystem.WriteNavigationState(journal, oldDescription, "gameJournalQuestDescription", gameJournalEntryState.Inactive)
                && NCPDPatrolFixedMarkerSystem.WriteNavigationState(journal, oldPath, "gameJournalQuestObjective", gameJournalEntryState.Inactive);
        };
        if ok {
            ok = NCPDPatrolFixedMarkerSystem.WriteNavigationState(journal, newDescription, "gameJournalQuestDescription", gameJournalEntryState.Active)
                && NCPDPatrolFixedMarkerSystem.WriteNavigationState(journal, newPath, "gameJournalQuestObjective", gameJournalEntryState.Active);
        };
        if !ok {
            if NotEquals(oldPath, newPath) {
                NCPDPatrolFixedMarkerSystem.WriteNavigationState(journal, newDescription, "gameJournalQuestDescription", gameJournalEntryState.Inactive);
                NCPDPatrolFixedMarkerSystem.WriteNavigationState(journal, newPath, "gameJournalQuestObjective", gameJournalEntryState.Inactive);
                NCPDPatrolFixedMarkerSystem.WriteNavigationState(journal, oldDescription, "gameJournalQuestDescription", gameJournalEntryState.Active);
                NCPDPatrolFixedMarkerSystem.WriteNavigationState(journal, oldPath, "gameJournalQuestObjective", gameJournalEntryState.Active);
            };
            return false;
        };
        // A newer player-selected story is respected.
        if tracked && NotEquals(oldPath, newPath) { journal.TrackEntry(newEntry); };
        return true;
    }
    protected cb func OnAttach() -> Bool { this.Forget(); return true; }
    protected cb func OnRestored(saveVersion: Int32, gameVersion: Int32) -> Bool { this.Forget(); return true; }
    private func Forget() -> Void {
        let empty: NewMappinID;
        this.m_token += 1; this.m_wanted = false; this.m_switch = false;
        this.m_restorePending = true; this.m_currentPath = ""; this.m_hash = 0u;
        this.m_nativeID = empty; this.m_fallbackID = empty;
        this.m_manualBefore = empty; this.m_manualAfter = empty;
        this.m_fallback = false; this.m_fallbackPending = false;
        this.m_confirmed = false; this.m_pinCount = 0;
        this.m_linked = false; this.m_positionOK = false; this.m_questPositionOK = false;
        this.m_age = 0.0; this.m_poll = 0.0; this.m_fallbackRetry = 0.0;
        ArrayClear(this.m_ownHashes);
        ArrayClear(this.m_ownPaths);
        this.m_activeBankPins = 0; this.m_otherBankPins = 0;
        this.m_targetActive = false; this.m_linkHash = 0u; this.m_linkID = empty;
        this.m_sweepPoll = 0.0; this.m_pruned = 0;
        this.Report("Idle", "Fixed marker bank ready; old world handles forgotten");
    }
    private func Journal() -> ref<JournalManager> { return GameInstance.GetJournalManager(this.GetGameInstance()); }
    private func Map() -> ref<MappinSystem> { return GameInstance.GetMappinSystem(this.GetGameInstance()); }
    private func Root(scope: Int32) -> String {
        if scope < 0 || scope > 9 { return ""; };
        if scope == 0 { return "quests/minor_quest/ncpd_patrol_dispatch"; };
        if scope < 6 { return s"quests/minor_quest/ncpd_patrol_dispatch_\(scope)"; };
        if scope < 8 { return "quests/minor_quest/ncpd_patrol_cyberpsycho"; };
        return "quests/minor_quest/ncpd_patrol_vip";
    }
    private func Phase(scope: Int32) -> String { return this.Root(scope) + "/main"; }
    private func BaseObjective(scope: Int32) -> String {
        let phase: String = this.Phase(scope);
        if scope < 6 { return s"\(phase)/resolve"; };
        if scope == 6 { return s"\(phase)/respond"; };
        if scope == 7 { return s"\(phase)/neutralize"; };
        if scope == 8 { return s"\(phase)/pickup"; };
        return s"\(phase)/deliver";
    }
    private func SiteObjective(scope: Int32, site: Int32) -> String {
        let base: String = this.BaseObjective(scope);
        if site > 0 { return s"\(base)_bank_\(site)"; };
        return base;
    }
    private func CurrentSite(scope: Int32) -> Int32 {
        let scanner: ref<NCPDPatrolDispatchJournalSystem>;
        let cyber: ref<NCPDPatrolCyberpsychoSystem>;
        let vip: ref<NCPDPatrolVIPSystem>;
        if scope < 6 {
            scanner = NCPDPatrolDispatchJournalSystem.Get(this.GetGameInstance());
            if IsDefined(scanner) { return scanner.GetNavigationSite(); };
        } else {
            if scope < 8 {
                cyber = NCPDPatrolCyberpsychoSystem.Get(this.GetGameInstance());
                if IsDefined(cyber) { return cyber.GetNavigationSite(); };
            } else {
                vip = NCPDPatrolVIPSystem.Get(this.GetGameInstance());
                if IsDefined(vip) {
                    if scope == 8 { return vip.GetNavigationSite(1); };
                    return vip.GetNavigationSite(2);
                };
            };
        };
        return 0;
    }
    private func Objective(scope: Int32) -> String { return this.SiteObjective(scope, this.CurrentSite(scope)); }
    private func SelectSite(scope: Int32, site: Int32) -> Bool {
        let scanner: ref<NCPDPatrolDispatchJournalSystem>;
        let cyber: ref<NCPDPatrolCyberpsychoSystem>;
        let vip: ref<NCPDPatrolVIPSystem>;
        if scope < 6 {
            scanner = NCPDPatrolDispatchJournalSystem.Get(this.GetGameInstance());
            return IsDefined(scanner) && scanner.SelectNavigationSite(site);
        };
        if scope < 8 {
            cyber = NCPDPatrolCyberpsychoSystem.Get(this.GetGameInstance());
            return IsDefined(cyber) && cyber.SelectNavigationSite(site);
        };
        vip = NCPDPatrolVIPSystem.Get(this.GetGameInstance());
        return IsDefined(vip) && vip.SelectNavigationSite(site);
    }
    private func PinPath(scope: Int32, site: Int32) -> String {
        let objective: String = this.SiteObjective(scope, site);
        return s"\(objective)/location";
    }
    private func LegacyPath(scope: Int32, site: Int32) -> String {
        let objective: String = this.BaseObjective(scope);
        return s"\(objective)/bank_\(site)";
    }
    private func PathHash(path: String) -> Uint32 {
        let journalPath: ref<gameJournalPath> = new gameJournalPath();
        journalPath.realPath = path; journalPath.fileEntryIndex = 1;
        journalPath.className = n"gameJournalQuestMapPin";
        return journalPath.GetHash();
    }
    private func WriteMarker(path: String, active: Bool) -> Void {
        let system: ref<QuestsSystem> = GameInstance.GetQuestsSystem(this.GetGameInstance());
        let journalPath: ref<gameJournalPath>;
        let node: ref<questMappinManagerNodeDefinition>;
        if Equals(path, "") || !IsDefined(system) || !IsDefined(this.Entry(path, "gameJournalQuestMapPin")) { return; };
        journalPath = new gameJournalPath();
        journalPath.realPath = path; journalPath.fileEntryIndex = 1; journalPath.className = n"gameJournalQuestMapPin";
        node = new questMappinManagerNodeDefinition(); node.id = Cast<Uint16>(0);
        node.path = journalPath; node.disablePreviousMappins = false;
        if active { system.ExecuteNode(node, n"Active"); } else { system.ExecuteNode(node, n"Inactive"); };
    }
    private func KnownPath(hash: Uint32) -> String {
        let i: Int32 = 0;
        while i < ArraySize(this.m_ownHashes) {
            if this.m_ownHashes[i] == hash { return this.m_ownPaths[i]; };
            i += 1;
        };
        return "";
    }
    private func Entry(path: String, kind: String) -> wref<JournalEntry> {
        if IsDefined(this.Journal()) { return this.Journal().GetEntryByString(path, kind); };
        return null;
    }
    private func Active(path: String, kind: String) -> Bool {
        let entry: wref<JournalEntry> = this.Entry(path, kind);
        return IsDefined(entry) && Equals(this.Journal().GetEntryState(entry), gameJournalEntryState.Active);
    }
    private func Eligible() -> Bool {
        let patrol: ref<NCPDPatrolSystem> = NCPDPatrolSystem.Get(this.GetGameInstance());
        let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
        return IsDefined(patrol) && patrol.IsOnDuty() && !patrol.HasWantedLevel()
            && IsDefined(player) && player.IsAttached() && !player.IsDead();
    }
    public func GetScope() -> Int32 {
        let scope: Int32 = 0;
        let selected: Int32 = -1;
        while scope < 10 {
            if this.Active(this.Root(scope), "gameJournalQuest") && this.Active(this.Phase(scope), "gameJournalQuestPhase")
                && this.Active(this.Objective(scope), "gameJournalQuestObjective") {
                if selected >= 0 { return -1; };
                selected = scope;
            };
            scope += 1;
        };
        return selected;
    }
    private func Report(status: String, detail: String) -> Void {
        if NotEquals(status, this.m_status) || NotEquals(detail, this.m_detail) { this.m_revision += 1; };
        this.m_status = status; this.m_detail = detail;
    }
    public func Request(site: Int32, target: Vector4) -> Int32 {
        let scope: Int32 = this.GetScope();
        if !this.Eligible() || scope < 0 || !IsDefined(this.Map()) || site < 0 || site > 323 { return 0; };
        if target.X != target.X || target.Y != target.Y || target.Z != target.Z
            || AbsF(target.X) > 100000.0 || AbsF(target.Y) > 100000.0 || AbsF(target.Z) > 100000.0 { return 0; };
        // A replacement has a fresh token immediately; old cleanup remains owned.
        this.m_token += 1; this.m_scope = scope; this.m_site = site; this.m_target = target;
        this.m_wanted = true; this.m_switch = true; this.m_confirmed = false;
        this.Report("Marker queued", "Waiting for previous owned marker cleanup");
        return this.m_token;
    }
    public func Stop(token: Int32) -> Void {
        if token != 0 && token != this.m_token { return; };
        this.m_wanted = false; this.m_switch = true; this.m_confirmed = false;
        this.Report("Closing marker", "Waiting for owned marker removal");
    }
    private func Hide(path: String) -> Bool {
        this.WriteMarker(path, false);
        // Node calls have no success return. RemoveOwned verifies the registry.
        return true;
    }
    private func RemoveOwned(hash: Uint32, allBankPins: Bool) -> Bool {
        let map: ref<MappinSystem> = this.Map();
        let pins: array<ref<IMappin>>;
        let pin: ref<QuestMappin>;
        let tag: ref<NCPDPatrolFixedMarkerData>;
        let i: Int32 = 0;
        let matches: Bool;
        let remaining: Bool = false;
        if !IsDefined(map) { return false; };
        pins = map.GetAllMappins();
        while i < ArraySize(pins) {
            pin = pins[i] as QuestMappin; tag = pins[i].GetScriptData() as NCPDPatrolFixedMarkerData;
            matches = IsDefined(tag);
            if IsDefined(pin) {
                if (hash != 0u && pin.GetJournalPathHash() == hash)
                    || (allBankPins && ArrayContains(this.m_ownHashes, pin.GetJournalPathHash())) { matches = true; };
            };
            if matches {
                if IsDefined(pin) { this.WriteMarker(this.KnownPath(pin.GetJournalPathHash()), false); };
                map.SetMappinActive(pins[i].GetNewMappinID(), false);
                map.UnregisterMappin(pins[i].GetNewMappinID());
            };
            i += 1;
        };
        pins = map.GetAllMappins(); i = 0;
        while i < ArraySize(pins) {
            pin = pins[i] as QuestMappin; tag = pins[i].GetScriptData() as NCPDPatrolFixedMarkerData;
            if IsDefined(tag) { remaining = true; };
            if IsDefined(pin) && ((hash != 0u && pin.GetJournalPathHash() == hash)
                || (allBankPins && ArrayContains(this.m_ownHashes, pin.GetJournalPathHash()))) { remaining = true; };
            i += 1;
        };
        return !remaining;
    }
    private func RestoreCleanup() -> Bool {
        let scope: Int32 = 0;
        let site: Int32;
        let path: String;
        let entry: wref<JournalEntry>;
        let objective: String;
        let description: String;
        let last: Int32;
        let ok: Bool = true;
        if !IsDefined(this.Map()) || !IsDefined(this.Journal()) { return false; };
        ArrayClear(this.m_ownHashes);
        ArrayClear(this.m_ownPaths);
        while scope < 10 {
            site = 1; last = 132;
            if scope >= 6 { site = 133; last = 323; };
            while site <= last {
                path = this.PinPath(scope, site); entry = this.Entry(path, "gameJournalQuestMapPin");
                if IsDefined(entry) {
                    ArrayPush(this.m_ownHashes, Cast<Uint32>(this.Journal().GetEntryHash(entry)));
                    ArrayPush(this.m_ownPaths, path);
                    objective = this.SiteObjective(scope, site); description = s"\(objective)/briefing";
                    if this.Active(objective, "gameJournalQuestObjective") {
                        if !NCPDPatrolFixedMarkerSystem.WriteNavigationState(this.Journal(), description, "gameJournalQuestDescription", gameJournalEntryState.Inactive)
                            || !NCPDPatrolFixedMarkerSystem.WriteNavigationState(this.Journal(), objective, "gameJournalQuestObjective", gameJournalEntryState.Inactive) { ok = false; };
                    };
                };
                path = this.LegacyPath(scope, site);
                ArrayPush(this.m_ownHashes, this.PathHash(path)); ArrayPush(this.m_ownPaths, path);
                site += 1;
            };
            scope += 1;
        };
        if !ok { return false; };
        return this.RemoveOwned(0u, true);
    }
    private func CleanupCurrent() -> Bool {
        if NotEquals(this.m_currentPath, "") && !this.Hide(this.m_currentPath) { return false; };
        if !this.RemoveOwned(this.m_hash, true) { return false; };
        this.m_currentPath = "";
        return true;
    }
    // Enumerate our private hashes, never cached IDs or other quests. This also
    // catches a legacy r5 pin that the engine recreates after initial cleanup.
    private func PruneOtherPins() -> Void {
        let map: ref<MappinSystem> = this.Map();
        let pins: array<ref<IMappin>> = map.GetAllMappins();
        let pin: ref<QuestMappin>;
        let keep: Uint32 = 0u;
        let i: Int32 = 0;
        if this.m_wanted && !this.m_switch && !this.m_fallback && !this.m_fallbackPending { keep = this.m_hash; };
        while i < ArraySize(pins) {
            pin = pins[i] as QuestMappin;
            if IsDefined(pin) && ArrayContains(this.m_ownHashes, pin.GetJournalPathHash()) && pin.GetJournalPathHash() != keep {
                this.WriteMarker(this.KnownPath(pin.GetJournalPathHash()), false);
                map.SetMappinActive(pin.GetNewMappinID(), false);
                map.UnregisterMappin(pin.GetNewMappinID());
                this.m_pruned += 1;
            };
            i += 1;
        };
    }
    private func ClearProof() -> Void {
        let empty: NewMappinID;
        let runtimePoint: Vector4;
        let questPoint: Vector3;
        this.m_nativeID = empty; this.m_pinCount = 0; this.m_confirmed = false;
        this.m_linked = false; this.m_targetActive = false;
        this.m_positionOK = false; this.m_questPositionOK = false;
        this.m_linkHash = 0u; this.m_linkID = empty;
        this.m_runtimePoint = runtimePoint; this.m_questPoint = questPoint;
        this.m_activeBankPins = 0; this.m_otherBankPins = 0;
    }
    private func StartCurrent() -> Void {
        let empty: NewMappinID;
        let entry: wref<JournalEntry>;
        this.ClearProof(); this.m_hash = 0u; this.m_age = 0.0;
        this.m_fallbackID = empty;
        this.m_fallback = false; this.m_fallbackPending = false;
        this.m_manualBefore = this.Map().GetManuallyTrackedMappinID();
        if this.m_site == 0 {
            this.m_fallbackPending = true; this.Report("Fallback queued", "Selected location has no matching fixed catalog entry"); return;
        };
        this.m_currentPath = this.PinPath(this.m_scope, this.m_site);
        entry = this.Entry(this.m_currentPath, "gameJournalQuestMapPin");
        if !IsDefined(entry) {
            this.m_currentPath = ""; this.m_fallbackPending = true;
            this.Report("Fallback queued", "Fixed journal pin resource unavailable; install complete r5a package"); return;
        };
        if !this.SelectSite(this.m_scope, this.m_site) {
            this.m_currentPath = ""; this.m_fallbackPending = true;
            this.Report("Fallback queued", "Selected site objective could not activate; attempting common-objective recovery"); return;
        };
        this.m_hash = Cast<Uint32>(this.Journal().GetEntryHash(entry));
        this.WriteMarker(this.m_currentPath, true);
        this.m_manualAfter = this.Map().GetManuallyTrackedMappinID();
        this.Report("Fixed quest marker requested", "One site objective selected and MappinManager Active requested; waiting for registry and objective-link proof");
    }
    private func ShowFallback() -> Void {
        let data: MappinData;
        if !this.SelectSite(this.m_scope, 0) {
            this.Report("Fallback pending", "Common objective recovery not confirmed; no second marker created"); return;
        };
        this.ClearProof();
        data.mappinType = t"Mappins.QuestStaticMappinDefinition";
        data.variant = gamedataMappinVariant.QuestGiverVariant;
        data.active = true; data.visibleThroughWalls = true;
        data.debugCaption = "NCPD DISPATCH"; data.scriptData = new NCPDPatrolFixedMarkerData();
        this.m_fallbackID = this.Map().RegisterMappin(data, this.m_target);
        this.m_manualAfter = this.Map().GetManuallyTrackedMappinID();
        this.m_fallback = true; this.m_fallbackPending = false; this.m_confirmed = false;
        this.m_fallbackRetry = 5.0;
        this.Report("Independent quest-style fallback", "Native journal marker not confirmed or location unmapped; manual waypoint is not tracked or replaced");
    }
    private func Inspect() -> Void {
        let map: ref<MappinSystem> = this.Map();
        let pins: array<ref<IMappin>> = map.GetAllMappins();
        let pin: ref<QuestMappin>;
        let linked: wref<IMappin>;
        let point: Vector3;
        let questPoint: Vector4;
        let known: Bool;
        let i: Int32 = 0;
        this.ClearProof();
        while i < ArraySize(pins) {
            pin = pins[i] as QuestMappin;
            if IsDefined(pin) && ArrayContains(this.m_ownHashes, pin.GetJournalPathHash()) {
                if pin.IsActive() { this.m_activeBankPins += 1; };
                if pin.GetJournalPathHash() != this.m_hash { this.m_otherBankPins += 1; };
            };
            if IsDefined(pin) && pin.IsQuestMappin() && pin.GetJournalPathHash() == this.m_hash {
                this.m_pinCount += 1; this.m_nativeID = pin.GetNewMappinID(); this.m_runtimePoint = pin.GetWorldPosition();
                this.m_positionOK = Vector4.Distance(this.m_runtimePoint, this.m_target) <= 2.0;
                this.m_targetActive = pin.IsActive();
            };
            i += 1;
        };
        linked = map.GetMappinFromObjective(this.Entry(this.Phase(this.m_scope), "gameJournalQuestPhase"), this.Entry(this.Objective(this.m_scope), "gameJournalQuestObjective"));
        pin = linked as QuestMappin;
        if IsDefined(pin) { this.m_linkID = pin.GetNewMappinID(); this.m_linkHash = pin.GetJournalPathHash(); };
        this.m_linked = IsDefined(pin) && this.m_linkHash == this.m_hash && this.m_linkID.value == this.m_nativeID.value;
        known = map.GetQuestMappinPosition(this.m_hash, point); this.m_questPoint = point;
        questPoint.X = point.X; questPoint.Y = point.Y; questPoint.Z = point.Z; questPoint.W = 1.0;
        this.m_questPositionOK = known && Vector4.Distance(questPoint, this.m_target) <= 2.0;
        this.m_confirmed = this.m_pinCount == 1 && this.m_activeBankPins == 1 && this.m_otherBankPins == 0
            && this.m_targetActive && this.m_positionOK && this.m_questPositionOK && this.m_linked
            && this.Active(this.Objective(this.m_scope), "gameJournalQuestObjective") && this.m_manualBefore.value == this.m_manualAfter.value;
        if this.m_confirmed { this.Report("Native quest marker confirmed", "Exactly one active bank pin; selected objective, native hash/ID and both positions match; manual ID unchanged across activation"); };
    }
    public func Tick(delta: Float) -> Void {
        let scope: Int32;
        let patrol: ref<NCPDPatrolSystem>;
        let live: ref<IMappin>;
        if !IsDefined(this.Map()) || !IsDefined(this.Journal()) || !IsDefined(GetPlayer(this.GetGameInstance())) { return; };
        if this.m_restorePending {
            if !this.RestoreCleanup() { return; };
            this.m_restorePending = false;
        };
        if delta > 0.0 && delta <= 0.5 { this.m_sweepPoll += delta; };
        if this.m_sweepPoll >= 1.0 {
            this.PruneOtherPins(); this.m_sweepPoll = 0.0;
        };
        if this.m_wanted {
            scope = this.GetScope();
            if !this.Eligible() || scope < 0 { this.Stop(this.m_token); } else {
                if scope != this.m_scope {
                    if Equals(this.Root(scope), this.Root(this.m_scope)) { this.m_scope = scope; this.m_switch = true; } else { this.Stop(this.m_token); };
                };
            };
        };
        if this.m_switch {
            if !this.CleanupCurrent() { return; };
            this.m_switch = false;
            if !this.m_wanted { this.ClearProof(); this.m_hash = 0u; this.Report("Idle", "Owned marker cleanup confirmed"); return; };
            this.StartCurrent();
        };
        if !this.m_wanted { return; };
        if this.m_fallbackPending {
            if !this.CleanupCurrent() { return; };
            this.ShowFallback();
            this.m_poll = 0.0;
            return;
        };
        if delta <= 0.0 || delta > 0.5 { return; };
        patrol = NCPDPatrolSystem.Get(this.GetGameInstance());
        if patrol.IsDispatchMenuOpen() { return; };
        this.m_poll += delta;
        if this.m_poll < 0.25 { return; };
        if this.m_fallback {
            this.m_fallbackRetry = MaxF(0.0, this.m_fallbackRetry - this.m_poll);
            live = this.Map().GetMappin(this.m_fallbackID);
            if this.m_fallbackRetry <= 0.0 && (!IsDefined(live) || !IsDefined(live.GetScriptData() as NCPDPatrolFixedMarkerData)) {
                this.ShowFallback();
            };
        } else {
            this.Inspect();
            if this.m_confirmed { this.m_age = 0.0; } else { this.m_age += this.m_poll; };
            if !this.m_confirmed && this.m_age >= 5.0 {
                this.m_fallbackPending = true;
                this.Report("Fallback queued", "No proven fixed native pin within five active seconds; retained native pin will be hidden first");
            };
        };
        this.m_poll = 0.0;
    }
    public func IsActive(token: Int32) -> Bool { return token == this.m_token && this.m_wanted; }
    public func HasWork() -> Bool { return this.m_wanted || this.m_switch; }
    public func GetStatus() -> String { return this.m_status; }
    public func GetRevision() -> Int32 { return this.m_revision; }
    public func GetDiagnostics() -> String {
        let current: NewMappinID;
        if IsDefined(this.Map()) { current = this.Map().GetManuallyTrackedMappinID(); };
        return s"\(this.m_status) | token=\(this.m_token) | scope=\(this.m_scope) | site=\(this.m_site) | active=\(this.m_wanted) | cleanup/switch=\(this.m_switch) | restore cleanup=\(this.m_restorePending) | native confirmed=\(this.m_confirmed) | native pins=\(this.m_pinCount) | active bank pins=\(this.m_activeBankPins) | other bank pins=\(this.m_otherBankPins) | target active=\(this.m_targetActive) | pruned=\(this.m_pruned) | objective=\(this.Objective(this.m_scope)) | link hash=\(this.m_linkHash) | link ID=\(this.m_linkID.value) | objective link=\(this.m_linked) | runtime position OK=\(this.m_positionOK) | quest position OK=\(this.m_questPositionOK) | pin ID=\(this.m_nativeID.value) | hash=\(this.m_hash) | target=\(this.m_target.X),\(this.m_target.Y),\(this.m_target.Z) | runtime=\(this.m_runtimePoint.X),\(this.m_runtimePoint.Y),\(this.m_runtimePoint.Z) | quest position=\(this.m_questPoint.X),\(this.m_questPoint.Y),\(this.m_questPoint.Z) | fallback=\(this.m_fallback) | manual before/after=\(this.m_manualBefore.value)/\(this.m_manualAfter.value) | manual current=\(current.value) | \(this.m_detail)";
    }
}
