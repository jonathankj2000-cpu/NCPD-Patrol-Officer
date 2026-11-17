// NCPD Patrol v0.6d. Paid activity IDs belong to the same save as the money.
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
    private let m_noticeToken: Int32;
    private let m_criminalTermination: Bool;
    private let m_chatterVehicle: wref<VehicleObject>;
    private let m_chatterActive: Bool;
    private let m_chatterPausedForVoice: Bool;
    private let m_voiceToken: Int32;
    private let m_ownsRadioRequest: Bool;
    private let m_voiceRequests: Int32;
    private let m_voiceRestarts: Int32;
    private let m_lastVoiceSource: String;
    private let m_lastVoiceStatus: String;
    private let m_recentBeforeVoice: String;
    private let m_recentAfterVoice: String;
    private let m_voiceAttempts: Int32;
    private let m_voiceRevision: Int32;
    private let m_voicePending: Bool;
    private let m_voiceRequiresDuty: Bool;
    private let m_heat1FlagBefore: Bool;
    private let m_heat1FlagAfter: Bool;

    public static func Get(game: GameInstance) -> ref<NCPDPatrolSystem> {
        return GameInstance.GetScriptableSystemsContainer(game).Get(n"NCPDPatrolSystem") as NCPDPatrolSystem;
    }

    private func OnAttach() -> Void {
        this.ResetSession();
    }

    private func OnRestored(saveVersion: Int32, gameVersion: Int32) -> Void {
        this.ResetSession();
    }

    public func Version() -> Int32 { return 14; }
    public func IsOnDuty() -> Bool { return this.m_onDuty; }
    public func WasTerminatedForCrime() -> Bool { return this.m_criminalTermination; }
    public func HasWantedLevel() -> Bool {
        let prevention: ref<PreventionSystem> = GameInstance.GetScriptableSystemsContainer(this.GetGameInstance()).Get(n"PreventionSystem") as PreventionSystem;
        return IsDefined(prevention) && NotEquals(prevention.GetHeatStage(), EPreventionHeatStage.Heat_0);
    }

    public func EnforceDutyRules() -> Void {
        if this.m_onDuty && this.HasWantedLevel() {
            // Stop eligibility before another completion/payment can be processed.
            this.m_onDuty = false;
            this.m_requestedDuty = 0;
            this.m_criminalTermination = true;
            this.m_baselineReady = false;
            this.m_monitorState = 0;
            this.m_monitorReason = "SHIFT TERMINATED: CRIMINAL ACTIVITY";
            ArrayClear(this.m_watchedKeys);
            ArrayClear(this.m_watchedHashes);
            ArrayClear(this.m_watchedMarkers);
            this.CancelDispatchVoiceWindow();
            this.StopVehicleChatter();
            this.ClearDispatchWaypoints();
            this.ShowPriorityMessage("NCPD: Shift terminated due to criminal activity.", 8.0);
        };
    }
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
        this.m_noticeToken += 1;
        this.m_noticeBusy = false;
        this.m_criminalTermination = false;
        // Loading a save discards emitters from the old world; forget their IDs.
        this.m_chatterVehicle = null;
        this.m_chatterActive = false;
        this.CancelDispatchVoiceWindow();
        this.m_voiceRequests = 0;
        this.m_voiceAttempts = 0;
        this.m_voiceRestarts = 0;
        this.m_lastVoiceSource = "none";
        this.m_lastVoiceStatus = "No request this session";
        this.m_recentBeforeVoice = "none";
        this.m_recentAfterVoice = "not sampled";
        this.m_heat1FlagBefore = false;
        this.m_heat1FlagAfter = false;
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
        if !endShift && this.HasWantedLevel() {
            this.m_requestedDuty = 0;
            this.ShowPriorityMessage("NCPD: Cannot start a shift while wanted.", 8.0);
            return;
        };
        this.m_requestedDuty = endShift ? 2 : 1;
    }

    public func TakeDutyRequest() -> Int32 {
        let request: Int32 = this.m_requestedDuty;
        this.m_requestedDuty = 0;
        return request;
    }

    public func BeginShift() -> Void {
        if this.m_onDuty { return; }
        if this.HasWantedLevel() {
            this.ShowPriorityMessage("NCPD: Cannot start a shift while wanted.", 8.0);
            return;
        };
        this.m_criminalTermination = false;
        this.CancelDispatchVoiceWindow();
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
        if !this.m_onDuty { return; };
        this.m_onDuty = false;
        this.m_criminalTermination = false;
        this.CancelDispatchVoiceWindow();
        this.StopVehicleChatter();
        this.ClearDispatchWaypoints();
        this.m_monitorState = 0;
        this.m_monitorReason = "OFF DUTY";
        this.m_baselineReady = false;
        ArrayClear(this.m_watchedKeys);
        ArrayClear(this.m_watchedHashes);
        ArrayClear(this.m_watchedMarkers);
        this.ShowPriorityMessage(s"NCPD: Shift ended. \(this.m_shiftJobs) activities, +EUR$\(this.m_shiftBonus) bonus.", 4.0);
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

    public func NotifyDispatch(text: String, duration: Float, opt alert: Bool, opt voice: Bool) -> Void {
        this.ShowMessage(text, false, duration, alert, voice);
    }

    public func PlayDispatchAlert() -> Bool {
        let player: ref<GameObject> = GetPlayer(this.GetGameInstance());
        if !IsDefined(player) { return false; };
        // Existing short notification event. No looping vehicle siren is started.
        GameObject.PlaySoundEvent(player, n"ui_phone_sms");
        return true;
    }

    public func PreviewPoliceRadio() -> Bool {
        return this.RequestPoliceRadio("test");
    }

    public func GetVoiceRequestCount() -> Int32 { return this.m_voiceRequests; }
    public func GetVoiceDiagnosticRevision() -> Int32 { return this.m_voiceRevision; }
    public func IsVehicleChatterPausedForVoice() -> Bool { return this.m_chatterPausedForVoice; }
    public func GetVoiceDiagnostics() -> String {
        let queued: Int32 = ArraySize(this.m_pendingNotices);
        return s"requests=\(this.m_voiceRequests) | attempts=\(this.m_voiceAttempts) | restarts=\(this.m_voiceRestarts) | last=\(this.m_lastVoiceSource) | entry=nc_heat_1_start | pending native send=\(this.m_voicePending) | pending notices=\(queued) | heat1 flag before/after=\(this.m_heat1FlagBefore)/\(this.m_heat1FlagAfter) | \(this.m_lastVoiceStatus) | recent before=\(this.m_recentBeforeVoice) | recent after=\(this.m_recentAfterVoice)";
    }

    private func RequestPoliceRadio(source: String) -> Bool {
        let radio: ref<PoliceRadioSystem> = GameInstance.GetPoliceRadioSystem(this.GetGameInstance());
        let delay: ref<DelaySystem> = GameInstance.GetDelaySystem(this.GetGameInstance());
        if !IsDefined(radio) {
            this.m_lastVoiceStatus = "Radio system unavailable";
            this.m_voiceRevision += 1;
            return false;
        };
        if this.HasWantedLevel() {
            this.m_lastVoiceStatus = "Skipped while wanted";
            this.m_voiceRevision += 1;
            return false;
        };
        this.m_voiceToken += 1;
        this.m_voiceAttempts += 1;
        this.m_voiceRevision += 1;
        this.m_voicePending = true;
        this.m_voiceRequiresDuty = this.m_onDuty;
        this.m_lastVoiceSource = source;
        this.m_recentBeforeVoice = this.ReadRecentRadioRequests(radio);
        this.m_recentAfterVoice = "not sampled";
        this.m_chatterPausedForVoice = false;
        if this.m_onDuty && IsDefined(delay) {
            this.StopVehicleChatter();
            this.m_chatterPausedForVoice = true;
        };
        if this.m_onDuty && this.m_ownsRadioRequest && IsDefined(delay) {
            // Do not issue the new request in the same call as aborting the old one.
            radio.AbortCurrentRadioLine();
            this.m_voiceRestarts += 1;
            this.m_lastVoiceStatus = "Waiting 0.5 s after abort; native request not sent yet";
            delay.DelayCallback(NCPDPatrolRadioStep.Create(this, this.m_noticeSession, this.m_voiceToken, 1), 0.5, false);
        } else {
            this.SendPreparedRadio(this.m_noticeSession, this.m_voiceToken);
        };
        return true;
    }

    private func SendPreparedRadio(session: Int32, token: Int32) -> Void {
        let radio: ref<PoliceRadioSystem>;
        let delay: ref<DelaySystem>;
        if session != this.m_noticeSession || token != this.m_voiceToken || !this.m_voicePending { return; };
        this.m_voicePending = false;
        this.m_voiceRevision += 1;
        if (this.m_voiceRequiresDuty && !this.m_onDuty) || this.HasWantedLevel() {
            this.m_lastVoiceStatus = "Cancelled before native send: duty/wanted state changed";
            this.CancelDispatchVoiceWindow();
            return;
        };
        radio = GameInstance.GetPoliceRadioSystem(this.GetGameInstance());
        delay = GameInstance.GetDelaySystem(this.GetGameInstance());
        if !IsDefined(radio) {
            this.m_lastVoiceStatus = "Radio system unavailable at native send";
            this.CancelDispatchVoiceWindow();
            return;
        };
        this.m_heat1FlagBefore = radio.isHeat1LineRequestOngoing;
        // Mirror PoliceRadioScriptSystem.PlayRadio for its documented heat-1 entry.
        // This is a radio scheduling flag; wanted heat is never changed here.
        radio.isHeat1LineRequestOngoing = false;
        radio.PoliceRadioRequest(n"nc_heat_1_start");
        this.m_heat1FlagAfter = radio.isHeat1LineRequestOngoing;
        this.m_ownsRadioRequest = this.m_onDuty;
        this.m_voiceRequests += 1;
        this.m_lastVoiceStatus = "Native request sent; awaiting history sample; audio unconfirmed";
        if IsDefined(delay) {
            if this.m_onDuty {
                delay.DelayCallback(NCPDPatrolVoiceWindow.Create(this, session, token), 12.0, false);
            };
            delay.DelayCallback(NCPDPatrolRadioStep.Create(this, session, token, 2), 1.0, false);
        } else {
            this.m_chatterPausedForVoice = false;
            this.m_recentAfterVoice = this.ReadRecentRadioRequests(radio);
        };
    }

    public func AdvanceRadioStep(session: Int32, token: Int32, step: Int32) -> Void {
        let radio: ref<PoliceRadioSystem>;
        if session != this.m_noticeSession || token != this.m_voiceToken { return; };
        if step == 1 {
            this.SendPreparedRadio(session, token);
        } else {
            radio = GameInstance.GetPoliceRadioSystem(this.GetGameInstance());
            if IsDefined(radio) {
                this.m_recentAfterVoice = this.ReadRecentRadioRequests(radio);
                this.m_lastVoiceStatus = "Native history sampled after 1 s; audible playback remains unconfirmed";
                this.m_voiceRevision += 1;
            };
        };
    }

    private func ReadRecentRadioRequests(radio: ref<PoliceRadioSystem>) -> String {
        let recent = radio.GetRecentRequests();
        let result: String = "";
        let i: Int32 = 0;
        while i < ArraySize(recent) {
            if i > 0 { result = result + ", "; };
            result = result + ToString(recent[i]);
            i += 1;
        };
        return result;
    }

    private func CancelDispatchVoiceWindow() -> Void {
        this.m_voiceToken += 1;
        this.m_voiceRevision += 1;
        if this.m_voicePending { this.m_lastVoiceStatus = "Pending voice cancelled"; };
        this.m_voicePending = false;
        this.m_voiceRequiresDuty = false;
        this.m_chatterPausedForVoice = false;
        this.m_ownsRadioRequest = false;
    }

    public func EndDispatchVoiceWindow(session: Int32, token: Int32) -> Void {
        if session == this.m_noticeSession && token == this.m_voiceToken {
            this.m_chatterPausedForVoice = false;
        };
    }

    public func IsOwnedPoliceVehicle(vehicle: ref<VehicleObject>) -> Bool {
        let record: wref<Vehicle_Record>;
        if !IsDefined(vehicle) || !vehicle.IsPlayerVehicle() { return false; };
        record = vehicle.GetRecord();
        if !IsDefined(record) { return false; };
        return Equals(vehicle.GetRecordID(), t"Vehicle.v_standard2_archer_hella_police")
            || StrContains(ToString(record.Player_audio_resource()), "police");
    }

    public func BeginVehicleChatter(vehicle: ref<VehicleObject>) -> Bool {
        let audio: ref<AudioSystem> = GameInstance.GetAudioSystem(this.GetGameInstance());
        if !this.m_onDuty || this.m_chatterPausedForVoice || this.HasWantedLevel() || !this.IsOwnedPoliceVehicle(vehicle) || !vehicle.IsPlayerMounted() || !IsDefined(audio) {
            return false;
        };
        this.StopVehicleChatter();
        this.m_chatterVehicle = vehicle;
        // This vanilla NPC radio event is attached to the car's own audio object.
        audio.Play(n"radio_car_police_npc", vehicle.GetEntityID());
        this.m_chatterActive = true;
        return true;
    }

    public func StopVehicleChatter() -> Void {
        let audio: ref<AudioSystem> = GameInstance.GetAudioSystem(this.GetGameInstance());
        if this.m_chatterActive && IsDefined(this.m_chatterVehicle) && IsDefined(audio) {
            audio.Stop(n"radio_car_police_npc", this.m_chatterVehicle.GetEntityID());
        };
        this.m_chatterVehicle = null;
        this.m_chatterActive = false;
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
        this.EnforceDutyRules();
        if !this.m_onDuty { return; };
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

    private func ShowMessage(text: String, opt money: Bool, opt duration: Float, opt alert: Bool, opt voice: Bool) -> Void {
        let notice: ref<NCPDPatrolNotice> = new NCPDPatrolNotice();
        notice.text = text;
        notice.money = money;
        notice.alert = alert;
        notice.voice = voice;
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
        this.m_noticeToken += 1;
        this.PresentNotice(notice);
        delay.DelayCallback(NCPDPatrolNoticeFinished.Create(this, this.m_noticeSession, this.m_noticeToken), notice.duration, false);
    }

    public func FinishNotice(session: Int32, token: Int32) -> Void {
        let notice: ref<NCPDPatrolNotice>;
        if session != this.m_noticeSession || token != this.m_noticeToken { return; };
        this.m_noticeBusy = false;
        if ArraySize(this.m_pendingNotices) > 0 {
            notice = this.m_pendingNotices[0];
            ArrayErase(this.m_pendingNotices, 0);
            this.QueueNotice(notice);
        };
    }

    private func ShowPriorityMessage(text: String, duration: Float) -> Void {
        let keep: array<ref<NCPDPatrolNotice>>;
        let i: Int32 = 0;
        // Keep receipts for money already paid, discard stale duty/dispatch messages.
        while i < ArraySize(this.m_pendingNotices) {
            if this.m_pendingNotices[i].money { ArrayPush(keep, this.m_pendingNotices[i]); };
            i += 1;
        };
        this.m_pendingNotices = keep;
        this.m_noticeToken += 1;
        this.m_noticeBusy = false;
        this.ShowMessage(text, false, duration);
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
        if this.m_onDuty && notice.alert { this.PlayDispatchAlert(); };
        if this.m_onDuty && notice.voice { this.RequestPoliceRadio("dispatch"); };
    }
}
