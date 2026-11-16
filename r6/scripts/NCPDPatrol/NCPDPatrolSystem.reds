// NCPD Patrol v0.4a. Paid activity IDs belong to the same save as the money.
// Duty and baseline state intentionally reset when loading a save.
public class NCPDPatrolSystem extends ScriptableSystem {
    private persistent let m_paidActivities: array<CName>;
    private let m_onDuty: Bool;
    private let m_requestedDuty: Int32;
    private let m_baselineReady: Bool;
    private let m_eligibleActivities: array<CName>;
    private let m_shiftJobs: Int32;
    private let m_shiftBonus: Int32;

    public static func Get(game: GameInstance) -> ref<NCPDPatrolSystem> {
        return GameInstance.GetScriptableSystemsContainer(game).Get(n"NCPDPatrolSystem") as NCPDPatrolSystem;
    }

    private func OnAttach() -> Void {
        this.ResetSession();
    }

    private func OnRestored(saveVersion: Int32, gameVersion: Int32) -> Void {
        this.ResetSession();
    }

    public func Version() -> Int32 { return 4; }
    public func IsOnDuty() -> Bool { return this.m_onDuty; }
    public func GetTerminalDutyState() -> Bool {
        if this.m_requestedDuty == 1 { return true; }
        if this.m_requestedDuty == 2 { return false; }
        return this.m_onDuty;
    }
    public func IsMonitorReady() -> Bool { return this.m_baselineReady; }
    public func GetShiftJobs() -> Int32 { return this.m_shiftJobs; }
    public func GetShiftBonus() -> Int32 { return this.m_shiftBonus; }

    public func ResetSession() -> Void {
        this.m_onDuty = false;
        this.m_requestedDuty = 0;
        this.m_baselineReady = false;
        this.m_shiftJobs = 0;
        this.m_shiftBonus = 0;
        ArrayClear(this.m_eligibleActivities);
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
        this.m_baselineReady = false;
        ArrayClear(this.m_eligibleActivities);
        this.TickBonuses();
        this.ShowMessage("NCPD: Shift started. Partner called.");
    }

    public func FinishShift() -> Void {
        if !this.m_onDuty { return; }
        // Check completion before turning duty off, including the last second.
        this.TickBonuses();
        this.m_onDuty = false;
        this.m_baselineReady = false;
        ArrayClear(this.m_eligibleActivities);
        this.ShowMessage(s"NCPD: Shift ended. \(this.m_shiftJobs) activities, +EUR$\(this.m_shiftBonus) bonus.");
    }

    public func TickBonuses() -> Void {
        let world: ref<OpenWorldSystem>;
        let activities: array<OpenWorldActivityState>;
        let player: ref<GameObject>;
        let transaction: ref<TransactionSystem>;
        let activity: OpenWorldActivityState;
        let awarded: Int32 = 0;
        let i: Int32 = 0;
        if !this.m_onDuty { return; }
        world = GameInstance.GetOpenWorldSystem();
        if !IsDefined(world) || !world.IsReady() { return; }
        activities = world.GetActivities();
        // An empty/streaming registry is not a valid baseline.
        if ArraySize(activities) == 0 { return; }
        if !this.m_baselineReady {
            while i < ArraySize(activities) {
                activity = activities[i];
                if Equals(activity.kind, n"ncpd") && !activity.completed && !ArrayContains(this.m_paidActivities, activity.name) {
                    ArrayPush(this.m_eligibleActivities, activity.name);
                };
                i += 1;
            };
            this.m_baselineReady = true;
            return;
        };
        player = GetPlayer(this.GetGameInstance());
        if !IsDefined(player) { return; }
        transaction = GameInstance.GetTransactionSystem(this.GetGameInstance());
        if !IsDefined(transaction) { return; }
        while i < ArraySize(activities) {
            activity = activities[i];
            if Equals(activity.kind, n"ncpd") && !ArrayContains(this.m_paidActivities, activity.name) {
                if !activity.completed {
                    // Newly registered, unfinished activities can become eligible.
                    if !ArrayContains(this.m_eligibleActivities, activity.name) {
                        ArrayPush(this.m_eligibleActivities, activity.name);
                    };
                } else {
                    if ArrayContains(this.m_eligibleActivities, activity.name) {
                        if transaction.GiveItem(player, ItemID.FromTDBID(t"Items.money"), 1000) {
                            ArrayPush(this.m_paidActivities, activity.name);
                            ArrayRemove(this.m_eligibleActivities, activity.name);
                            this.m_shiftJobs += 1;
                            this.m_shiftBonus += 1000;
                            awarded += 1000;
                        };
                    };
                };
            };
            i += 1;
        };
        if awarded > 0 {
            this.ShowMessage(s"NCPD patrol bonus: +EUR$\(awarded)");
        };
    }

    private func ShowMessage(text: String) -> Void {
        let message: SimpleScreenMessage;
        message.isShown = true;
        message.duration = 4.0;
        message.message = text;
        GameInstance.GetBlackboardSystem(this.GetGameInstance()).Get(GetAllBlackboardDefs().UI_Notifications)
            .SetVariant(GetAllBlackboardDefs().UI_Notifications.WarningMessage, ToVariant(message), true);
    }
}
