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

    public func Version() -> Int32 { return 1; }
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
    private func Objective(scope: Int32) -> String {
        let phase: String = this.Phase(scope);
        if scope < 6 { return s"\(phase)/resolve"; };
        if scope == 6 { return s"\(phase)/respond"; };
        if scope == 7 { return s"\(phase)/neutralize"; };
        if scope == 8 { return s"\(phase)/pickup"; };
        return s"\(phase)/deliver";
    }
    private func PinPath(scope: Int32, site: Int32) -> String {
        let objective: String = this.Objective(scope);
        return s"\(objective)/bank_\(site)";
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
        let entry: wref<JournalEntry> = this.Entry(path, "gameJournalQuestMapPin");
        if !IsDefined(entry) { return true; };
        if NotEquals(this.Journal().GetEntryState(entry), gameJournalEntryState.Inactive) {
            this.Journal().ChangeEntryState(path, "gameJournalQuestMapPin", gameJournalEntryState.Inactive, JournalNotifyOption.DoNotNotify);
        };
        return Equals(this.Journal().GetEntryState(entry), gameJournalEntryState.Inactive);
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
            if matches { map.UnregisterMappin(pins[i].GetNewMappinID()); };
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
        let ok: Bool = true;
        if !IsDefined(this.Map()) || !IsDefined(this.Journal()) { return false; };
        ArrayClear(this.m_ownHashes);
        while scope < 10 {
            site = 1;
            while site <= 323 {
                path = this.PinPath(scope, site); entry = this.Entry(path, "gameJournalQuestMapPin");
                if IsDefined(entry) {
                    ArrayPush(this.m_ownHashes, Cast<Uint32>(this.Journal().GetEntryHash(entry)));
                    if !this.Hide(path) { ok = false; };
                };
                site += 1;
            };
            scope += 1;
        };
        if !ok { return false; };
        return this.RemoveOwned(0u, true);
    }
    private func CleanupCurrent() -> Bool {
        if NotEquals(this.m_currentPath, "") && !this.Hide(this.m_currentPath) { return false; };
        if !this.RemoveOwned(this.m_hash, false) { return false; };
        this.m_currentPath = "";
        return true;
    }
    private func StartCurrent() -> Void {
        let empty: NewMappinID;
        let entry: wref<JournalEntry>;
        this.m_hash = 0u; this.m_age = 0.0; this.m_pinCount = 0;
        this.m_nativeID = empty; this.m_fallbackID = empty;
        this.m_confirmed = false; this.m_linked = false; this.m_positionOK = false; this.m_questPositionOK = false;
        this.m_fallback = false; this.m_fallbackPending = false;
        this.m_manualBefore = this.Map().GetManuallyTrackedMappinID();
        if this.m_site == 0 {
            this.m_fallbackPending = true; this.Report("Fallback queued", "Selected location has no matching fixed catalog entry"); return;
        };
        this.m_currentPath = this.PinPath(this.m_scope, this.m_site);
        entry = this.Entry(this.m_currentPath, "gameJournalQuestMapPin");
        if !IsDefined(entry) {
            this.m_currentPath = ""; this.m_fallbackPending = true;
            this.Report("Fallback queued", "Fixed journal pin resource unavailable; install complete r5 package"); return;
        };
        this.m_hash = Cast<Uint32>(this.Journal().GetEntryHash(entry));
        this.Journal().ChangeEntryState(this.m_currentPath, "gameJournalQuestMapPin", gameJournalEntryState.Active, JournalNotifyOption.DoNotNotify);
        this.m_manualAfter = this.Map().GetManuallyTrackedMappinID();
        this.Report("Fixed quest marker requested", "Entry activation is not confirmation; waiting for native pin and objective link");
    }
    private func ShowFallback() -> Void {
        let data: MappinData;
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
        let linkedID: NewMappinID;
        let i: Int32 = 0;
        this.m_pinCount = 0; this.m_positionOK = false; this.m_linked = false; this.m_questPositionOK = false;
        while i < ArraySize(pins) {
            pin = pins[i] as QuestMappin;
            if IsDefined(pin) && pin.IsQuestMappin() && pin.GetJournalPathHash() == this.m_hash {
                this.m_pinCount += 1; this.m_nativeID = pin.GetNewMappinID(); this.m_runtimePoint = pin.GetWorldPosition();
                this.m_positionOK = Vector4.Distance(this.m_runtimePoint, this.m_target) <= 2.0;
            };
            i += 1;
        };
        linked = map.GetMappinFromObjective(this.Entry(this.Phase(this.m_scope), "gameJournalQuestPhase"), this.Entry(this.Objective(this.m_scope), "gameJournalQuestObjective"));
        pin = linked as QuestMappin;
        if IsDefined(pin) { linkedID = pin.GetNewMappinID(); };
        this.m_linked = IsDefined(pin) && pin.GetJournalPathHash() == this.m_hash && linkedID.value == this.m_nativeID.value;
        known = map.GetQuestMappinPosition(this.m_hash, point); this.m_questPoint = point;
        questPoint.X = point.X; questPoint.Y = point.Y; questPoint.Z = point.Z; questPoint.W = 1.0;
        this.m_questPositionOK = known && Vector4.Distance(questPoint, this.m_target) <= 2.0;
        this.m_confirmed = this.m_pinCount == 1 && this.m_positionOK && this.m_questPositionOK && this.m_linked
            && this.Active(this.m_currentPath, "gameJournalQuestMapPin") && this.m_manualBefore.value == this.m_manualAfter.value;
        if this.m_confirmed { this.Report("Native quest marker confirmed", "Fixed site, correct native hash/ID, journal position and objective link; manual ID unchanged across activation"); };
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
            if !this.m_wanted { this.m_hash = 0u; this.Report("Idle", "Owned marker cleanup confirmed"); return; };
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
        return s"\(this.m_status) | token=\(this.m_token) | scope=\(this.m_scope) | site=\(this.m_site) | active=\(this.m_wanted) | cleanup/switch=\(this.m_switch) | restore cleanup=\(this.m_restorePending) | native confirmed=\(this.m_confirmed) | native pins=\(this.m_pinCount) | objective link=\(this.m_linked) | runtime position OK=\(this.m_positionOK) | quest position OK=\(this.m_questPositionOK) | pin ID=\(this.m_nativeID.value) | hash=\(this.m_hash) | target=\(this.m_target.X),\(this.m_target.Y),\(this.m_target.Z) | runtime=\(this.m_runtimePoint.X),\(this.m_runtimePoint.Y),\(this.m_runtimePoint.Z) | quest position=\(this.m_questPoint.X),\(this.m_questPoint.Y),\(this.m_questPoint.Z) | fallback=\(this.m_fallback) | manual before/after=\(this.m_manualBefore.value)/\(this.m_manualAfter.value) | manual current=\(current.value) | \(this.m_detail)";
    }
}
