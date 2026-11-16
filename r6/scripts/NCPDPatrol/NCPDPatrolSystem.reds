// NCPD Patrol v0.5b. Paid activity IDs belong to the same save as the money.
// Duty and baseline state intentionally reset when loading a save.
public class NCPDPatrolSystem extends ScriptableSystem {
    private persistent let m_paidActivities: array<CName>;
    private let m_onDuty: Bool;
    private let m_requestedDuty: Int32;
    private let m_baselineReady: Bool;
    private let m_watchedKeys: array<CName>;
    private let m_watchedHashes: array<Uint32>;
    private let m_watchedMarkers: array<ref<PointOfInterestMappin>>;
    private let m_allMappins: Int32;
    private let m_scannerMarkers: Int32;
    private let m_unknownPhases: Int32;
    private let m_paymentFailures: Int32;
    private let m_monitorState: Int32;
    private let m_monitorReason: String;
    private let m_shiftJobs: Int32;
    private let m_shiftBonus: Int32;
    private let m_noticeSession: Int32;
    private let m_lastBonusAmount: Int32;
    private let m_noticeBusy: Bool;
    private let m_pendingNotices: array<ref<NCPDPatrolNotice>>;

    public static func Get(game: GameInstance) -> ref<NCPDPatrolSystem> {
        return GameInstance.GetScriptableSystemsContainer(game).Get(n"NCPDPatrolSystem") as NCPDPatrolSystem;
    }

    private func OnAttach() -> Void {
        this.ResetSession();
    }

    private func OnRestored(saveVersion: Int32, gameVersion: Int32) -> Void {
        this.ResetSession();
    }

    public func Version() -> Int32 { return 7; }
    public func IsOnDuty() -> Bool { return this.m_onDuty; }
    public func GetTerminalDutyState() -> Bool {
        if this.m_requestedDuty == 1 { return true; }
        if this.m_requestedDuty == 2 { return false; }
        return this.m_onDuty;
    }
    public func IsMonitorReady() -> Bool { return this.m_baselineReady; }
    public func GetShiftJobs() -> Int32 { return this.m_shiftJobs; }
    public func GetShiftBonus() -> Int32 { return this.m_shiftBonus; }
    public func GetLastBonusAmount() -> Int32 { return this.m_lastBonusAmount; }
    public func GetMonitorState() -> Int32 { return this.m_monitorState; }
    public func GetMonitorDiagnostics() -> String {
        let watched: Int32 = ArraySize(this.m_watchedKeys);
        let reason: String = this.m_onDuty ? this.m_monitorReason : "OFF DUTY";
        let duty: String = this.m_onDuty ? "ON DUTY" : "OFF DUTY";
        return s"\(duty) | \(reason) | source=POI mappins | all=\(this.m_allMappins) | NCPD=\(this.m_scannerMarkers) | watched=\(watched) | unknown phases=\(this.m_unknownPhases) | payment failures=\(this.m_paymentFailures) | paid=\(this.m_shiftJobs) | bonus=EUR$\(this.m_shiftBonus)";
    }

    public func ResetSession() -> Void {
        this.m_onDuty = false;
        this.m_requestedDuty = 0;
        this.m_baselineReady = false;
        this.m_shiftJobs = 0;
        this.m_shiftBonus = 0;
        this.m_noticeSession += 1;
        this.m_noticeBusy = false;
        ArrayClear(this.m_pendingNotices);
        this.m_lastBonusAmount = 0;
        this.m_allMappins = 0;
        this.m_scannerMarkers = 0;
        this.m_unknownPhases = 0;
        this.m_paymentFailures = 0;
        this.m_monitorState = 0;
        this.m_monitorReason = "OFF DUTY";
        ArrayClear(this.m_watchedKeys);
        ArrayClear(this.m_watchedHashes);
        ArrayClear(this.m_watchedMarkers);
    }

    // Desired state, not a blind toggle: a stale terminal choice is harmless.
    public func RequestDuty(endShift: Bool) -> Void {
        this.m_requestedDuty = endShift ? 2 : 1;
    }

    public func TakeDutyRequest() -> Int32 {
        let request: Int32 = this.m_requestedDuty;
        this.m_requestedDuty = 0;
        return request;
    }

    public func BeginShift() -> Void {
        if this.m_onDuty { return; }
        this.m_onDuty = true;
        this.m_shiftJobs = 0;
        this.m_shiftBonus = 0;
        this.m_lastBonusAmount = 0;
        this.m_baselineReady = false;
        ArrayClear(this.m_watchedKeys);
        ArrayClear(this.m_watchedHashes);
        ArrayClear(this.m_watchedMarkers);
        this.TickBonuses();
        this.ShowMessage("NCPD: Shift started. Partner called.");
    }

    public func FinishShift() -> Void {
        if !this.m_onDuty { return; }
        // Check completion before turning duty off, including the last second.
        this.TickBonuses();
        this.m_onDuty = false;
        this.m_monitorState = 0;
        this.m_monitorReason = "OFF DUTY";
        this.m_baselineReady = false;
        ArrayClear(this.m_watchedKeys);
        ArrayClear(this.m_watchedHashes);
        ArrayClear(this.m_watchedMarkers);
        this.ShowMessage(s"NCPD: Shift ended. \(this.m_shiftJobs) activities, +EUR$\(this.m_shiftBonus) bonus.");
    }

    private func IsScannerVariant(variant: gamedataMappinVariant) -> Bool {
        return Equals(variant, gamedataMappinVariant.GangWatchVariant) || Equals(variant, gamedataMappinVariant.OutpostVariant);
    }

    private func MarkerKey(hash: Uint32) -> CName {
        return StringToName(s"ncpd-poi-\(hash)");
    }

    private func ReadSavedPhase(system: ref<MappinSystem>, hash: Uint32) -> gamedataMappinPhase {
        let phase: Uint16;
        let variant: Uint16;
        let active: Bool;
        let found: Bool = system.GetPointOfInterestMappinSavedState(hash, phase, variant, active);
        if found {
            return IntEnum<gamedataMappinPhase>(Cast<Int32>(phase));
        };
        // Never interpret default-initialized zero as CompletedPhase.
        return gamedataMappinPhase.Invalid;
    }

    // Shared by rewards and dispatch. A live completion can precede the saved phase.
    public func GetScannerPhase(hash: Uint32, marker: ref<PointOfInterestMappin>) -> gamedataMappinPhase {
        let phase: gamedataMappinPhase = gamedataMappinPhase.Invalid;
        let livePhase: gamedataMappinPhase;
        let system: ref<MappinSystem> = GameInstance.GetMappinSystem(this.GetGameInstance());
        if IsDefined(system) { phase = this.ReadSavedPhase(system, hash); };
        if IsDefined(marker) {
            livePhase = marker.GetPhase();
            if Equals(livePhase, gamedataMappinPhase.CompletedPhase) || Equals(phase, gamedataMappinPhase.Invalid) {
                phase = livePhase;
            };
        };
        return phase;
    }

    public func GetDispatchCandidates() -> array<ref<PointOfInterestMappin>> {
        let result: array<ref<PointOfInterestMappin>>;
        let pins: array<ref<IMappin>>;
        let marker: ref<PointOfInterestMappin>;
        let hash: Uint32;
        let phase: gamedataMappinPhase;
        let i: Int32 = 0;
        let system: ref<MappinSystem> = GameInstance.GetMappinSystem(this.GetGameInstance());
        if !this.m_onDuty || !IsDefined(system) { return result; };
        pins = system.GetAllMappins();
        while i < ArraySize(pins) {
            marker = pins[i] as PointOfInterestMappin;
            if IsDefined(marker) && this.IsScannerVariant(marker.GetVariant()) && marker.IsActive() {
                hash = marker.GetJournalPathHash();
                if hash != 0u && !ArrayContains(this.m_paidActivities, this.MarkerKey(hash)) {
                    phase = this.GetScannerPhase(hash, marker);
                    if NotEquals(phase, gamedataMappinPhase.CompletedPhase) && NotEquals(phase, gamedataMappinPhase.Invalid) {
                        ArrayPush(result, marker);
                    };
                };
            };
            i += 1;
        };
        return result;
    }

    public func PlaceDispatchWaypoint(position: Vector4) -> NewMappinID {
        let data: MappinData;
        let emptyID: NewMappinID;
        let system: ref<MappinSystem> = GameInstance.GetMappinSystem(this.GetGameInstance());
        if !this.m_onDuty || !IsDefined(system) { return emptyID; };
        data.mappinType = t"Mappins.DefaultStaticMappin";
        data.variant = gamedataMappinVariant.CustomPositionVariant;
        data.active = true;
        data.visibleThroughWalls = true;
        data.debugCaption = "NCPD DISPATCH";
        data.scriptData = new NCPDPatrolDispatchMappinData();
        return system.RegisterMappin(data, position);
    }

    // Tag-based cleanup avoids reusing an entity/mappin ID from a previous load.
    public func ClearDispatchWaypoints() -> Void {
        let pins: array<ref<IMappin>>;
        let tag: ref<NCPDPatrolDispatchMappinData>;
        let i: Int32 = 0;
        let system: ref<MappinSystem> = GameInstance.GetMappinSystem(this.GetGameInstance());
        if !IsDefined(system) { return; };
        pins = system.GetAllMappins();
        while i < ArraySize(pins) {
            tag = pins[i].GetScriptData() as NCPDPatrolDispatchMappinData;
            if IsDefined(tag) { system.UnregisterMappin(pins[i].GetNewMappinID()); };
            i += 1;
        };
    }

    public func NotifyDispatch(text: String, duration: Float, opt alert: Bool) -> Void {
        this.ShowMessage(text, false, duration, alert);
    }

    public func PlayDispatchAlert() -> Bool {
        let player: ref<GameObject> = GetPlayer(this.GetGameInstance());
        if !IsDefined(player) { return false; };
        // Existing short notification event. No looping vehicle siren is started.
        GameObject.PlaySoundEvent(player, n"ui_phone_sms");
        return true;
    }

    public func PreviewPoliceRadio() -> Bool {
        let radio: ref<PoliceRadioSystem> = GameInstance.GetPoliceRadioSystem(this.GetGameInstance());
        if !IsDefined(radio) { return false; };
        // Audition only: this documented entry is a pursuit line, not a bespoke brief.
        // Do not alter heat, district, vehicle or police AI state to make it play.
        radio.PoliceRadioRequest(n"nc_heat_1_start");
        return true;
    }

    public func IsDispatchMenuOpen() -> Bool {
        return GameInstance.GetBlackboardSystem(this.GetGameInstance()).Get(GetAllBlackboardDefs().UI_System)
            .GetBool(GetAllBlackboardDefs().UI_System.IsInMenu);
    }

    public func TickBonuses() -> Void {
        let system: ref<MappinSystem>;
        let pins: array<ref<IMappin>>;
        let marker: ref<PointOfInterestMappin>;
        let hash: Uint32;
        let key: CName;
        let phase: gamedataMappinPhase;
        let index: Int32;
        let player: ref<GameObject>;
        let transaction: ref<TransactionSystem>;
        let awarded: Int32 = 0;
        let i: Int32 = 0;
        if !this.m_onDuty { return; }
        this.m_baselineReady = false;
        this.m_unknownPhases = 0;
        this.m_paymentFailures = 0;
        this.m_allMappins = 0;
        this.m_scannerMarkers = 0;
        system = GameInstance.GetMappinSystem(this.GetGameInstance());
        if !IsDefined(system) {
            this.m_monitorState = 1;
            this.m_monitorReason = "ERROR: MappinSystem unavailable";
            return;
        };
        pins = system.GetAllMappins();
        this.m_allMappins = ArraySize(pins);
        this.m_scannerMarkers = 0;
        this.m_baselineReady = true;
        while i < ArraySize(pins) {
            marker = pins[i] as PointOfInterestMappin;
            if IsDefined(marker) && this.IsScannerVariant(marker.GetVariant()) {
                hash = marker.GetJournalPathHash();
                if hash != 0u {
                    this.m_scannerMarkers += 1;
                    key = this.MarkerKey(hash);
                    phase = marker.GetPhase();
                    index = ArrayFindFirst(this.m_watchedKeys, key);
                    if index >= 0 {
                        // A streamed-in replacement may have the same journal ID.
                        this.m_watchedMarkers[index] = marker;
                    } else {
                        if NotEquals(phase, gamedataMappinPhase.CompletedPhase) && NotEquals(phase, gamedataMappinPhase.Invalid) && !ArrayContains(this.m_paidActivities, key) {
                            ArrayPush(this.m_watchedKeys, key);
                            ArrayPush(this.m_watchedHashes, hash);
                            ArrayPush(this.m_watchedMarkers, marker);
                        };
                    };
                };
            };
            i += 1;
        };
        // Completion can remove a marker from the live list. Check the game's
        // saved POI phase for each previously seen scanner ID as well.
        player = GetPlayer(this.GetGameInstance());
        transaction = GameInstance.GetTransactionSystem(this.GetGameInstance());
        i = 0;
        while i < ArraySize(this.m_watchedKeys) {
            key = this.m_watchedKeys[i];
            if !ArrayContains(this.m_paidActivities, key) {
                marker = this.m_watchedMarkers[i];
                phase = this.GetScannerPhase(this.m_watchedHashes[i], marker);
                if Equals(phase, gamedataMappinPhase.Invalid) { this.m_unknownPhases += 1; };
                if Equals(phase, gamedataMappinPhase.CompletedPhase) {
                    if IsDefined(player) && IsDefined(transaction) {
                        if transaction.GiveItem(player, ItemID.FromTDBID(t"Items.money"), 1000) {
                            ArrayPush(this.m_paidActivities, key);
                            this.m_shiftJobs += 1;
                            this.m_shiftBonus += 1000;
                            awarded += 1000;
                        } else {
                            this.m_paymentFailures += 1;
                        };
                    } else {
                        this.m_paymentFailures += 1;
                    };
                };
            };
            i += 1;
        };
        if this.m_allMappins == 0 && ArraySize(this.m_watchedKeys) == 0 {
            this.m_monitorState = 2;
            this.m_monitorReason = "NO LIVE MAPPINS";
        } else {
            if this.m_scannerMarkers == 0 && ArraySize(this.m_watchedKeys) == 0 {
                this.m_monitorState = 3;
                this.m_monitorReason = "NO NCPD MARKERS OBSERVED YET";
            } else {
                this.m_monitorState = 4;
                this.m_monitorReason = this.m_scannerMarkers > 0 ? "MONITORING" : "MONITORING SAVED POI STATES";
            };
        };
        if this.m_unknownPhases > 0 {
            this.m_monitorState = 5;
            this.m_monitorReason = "SOME TRACKED POI PHASES UNAVAILABLE";
        };
        if this.m_paymentFailures > 0 {
            this.m_monitorState = 6;
            this.m_monitorReason = "PAYMENT FAILED (WILL RETRY)";
        };
        if awarded > 0 {
            this.m_lastBonusAmount = awarded;
            this.QueueBonusReceipt(awarded);
        };
    }

    private func QueueBonusReceipt(amount: Int32) -> Void {
        let delay: ref<DelaySystem> = GameInstance.GetDelaySystem(this.GetGameInstance());
        if IsDefined(delay) {
            delay.DelayCallback(NCPDPatrolBonusReceipt.Create(this, amount, this.m_noticeSession), 2.0, false);
        } else {
            this.ShowBonusReceipt(amount, this.m_noticeSession);
        };
    }

    public func ShowBonusReceipt(amount: Int32, session: Int32) -> Void {
        if session == this.m_noticeSession {
            this.ShowMessage(s"NCPD BONUS PAID: +€$\(amount)", true);
        };
    }

    private func ShowMessage(text: String, opt money: Bool, opt duration: Float, opt alert: Bool) -> Void {
        let notice: ref<NCPDPatrolNotice> = new NCPDPatrolNotice();
        notice.text = text;
        notice.money = money;
        notice.alert = alert;
        notice.duration = duration;
        if notice.duration <= 0.0 { notice.duration = money ? 8.0 : 4.0; };
        this.QueueNotice(notice);
    }

    private func QueueNotice(notice: ref<NCPDPatrolNotice>) -> Void {
        let delay: ref<DelaySystem> = GameInstance.GetDelaySystem(this.GetGameInstance());
        if !IsDefined(delay) {
            this.PresentNotice(notice);
            return;
        };
        if this.m_noticeBusy {
            ArrayPush(this.m_pendingNotices, notice);
            return;
        };
        this.m_noticeBusy = true;
        this.PresentNotice(notice);
        delay.DelayCallback(NCPDPatrolNoticeFinished.Create(this, this.m_noticeSession), notice.duration, false);
    }

    public func FinishNotice(session: Int32) -> Void {
        let notice: ref<NCPDPatrolNotice>;
        if session != this.m_noticeSession { return; };
        this.m_noticeBusy = false;
        if ArraySize(this.m_pendingNotices) > 0 {
            notice = this.m_pendingNotices[0];
            ArrayErase(this.m_pendingNotices, 0);
            this.QueueNotice(notice);
        };
    }

    private func PresentNotice(notice: ref<NCPDPatrolNotice>) -> Void {
        let message: SimpleScreenMessage;
        message.isShown = true;
        message.duration = notice.duration;
        message.message = notice.text;
        message.isInstant = true;
        message.type = notice.money ? SimpleMessageType.Money : SimpleMessageType.Neutral;
        GameInstance.GetBlackboardSystem(this.GetGameInstance()).Get(GetAllBlackboardDefs().UI_Notifications)
            .SetVariant(GetAllBlackboardDefs().UI_Notifications.WarningMessage, ToVariant(message), true);
        if notice.alert { this.PlayDispatchAlert(); };
    }
}
