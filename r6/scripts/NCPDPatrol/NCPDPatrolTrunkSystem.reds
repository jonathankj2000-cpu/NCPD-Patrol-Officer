// Independent, transient bridge. No changes to scanner or arrest payments.
public class NCPDPatrolTrunkSystem extends ScriptableSystem {
    private let m_menuVehicle: wref<VehicleObject>;
    private let m_busy: Bool;
    private let m_command: Int32;
    private let m_repairVehicle: wref<VehicleObject>;
    private let m_repairPending: Bool;
    private let m_repairElapsed: Float;

    public static func Get(game: GameInstance) -> ref<NCPDPatrolTrunkSystem> {
        return GameInstance.GetScriptableSystemsContainer(game).Get(n"NCPDPatrolTrunkSystem") as NCPDPatrolTrunkSystem;
    }
    public func Version() -> Int32 { return 2; }
    private func OnAttach() -> Void { this.ForgetWorld(); }
    private func OnRestored(saveVersion: Int32, gameVersion: Int32) -> Void { this.ForgetWorld(); }
    private func OnDetach() -> Void { this.FinishSession(); }

    private func ForgetWorld() -> Void {
        // Loading invalidated the previous world's objects; never refresh them here.
        this.m_menuVehicle = null;
        this.m_busy = false;
        this.m_command = 0;
        this.m_repairVehicle = null;
        this.m_repairPending = false;
        this.m_repairElapsed = 0.0;
    }

    private func Notice(text: String, opt seconds: Float) -> Void {
        let patrol: ref<NCPDPatrolSystem> = NCPDPatrolSystem.Get(this.GetGameInstance());
        if seconds <= 0.0 { seconds = 6.0; };
        if IsDefined(patrol) { patrol.NotifyDispatch(text, seconds); };
    }
    private func IsEligible() -> Bool {
        let patrol: ref<NCPDPatrolSystem> = NCPDPatrolSystem.Get(this.GetGameInstance());
        let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
        return IsDefined(patrol) && patrol.IsOnDuty() && !patrol.HasWantedLevel()
            && IsDefined(player) && player.IsAttached() && !player.IsDead();
    }
    public func CanUseTrunk(vehicle: ref<VehicleObject>) -> Bool {
        let support: ref<NCPDPatrolSupportSystem> = NCPDPatrolSupportSystem.Get(this.GetGameInstance());
        let patrol: ref<NCPDPatrolSystem> = NCPDPatrolSystem.Get(this.GetGameInstance());
        let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
        return this.IsEligible() && IsDefined(support) && support.CanUseTrunk(vehicle)
            && !patrol.IsDispatchMenuOpen() && vehicle.IsAttached()
            && !vehicle.MatchVisualTag(n"NoTrunk") && !vehicle.IsCrowdVehicle()
            && Vector4.Distance(player.GetWorldPosition(), vehicle.GetWorldPosition()) <= 5.0;
    }
    public func IsOpenFor(vehicle: ref<VehicleObject>) -> Bool {
        return IsDefined(this.m_menuVehicle) && this.m_menuVehicle == vehicle && this.CanUseTrunk(vehicle);
    }
    public func IsBusy() -> Bool { return this.m_busy; }
    public func SetBusy(value: Bool) -> Void {
        if !this.IsEligible() { return; };
        this.m_busy = value;
        if value {
            this.Notice("NCPD: Status BUSY. Automatic dispatches paused; current assignment retained.");
        } else {
            this.Notice("NCPD: Status AVAILABLE. Automatic dispatches resumed.");
        };
    }
    public func IsRepairPending() -> Bool { return this.m_repairPending; }
    public func GetRepairSeconds() -> Int32 {
        if !this.m_repairPending { return 0; };
        return CeilF(10.0 - this.m_repairElapsed);
    }

    private func Refresh(vehicle: ref<VehicleObject>) -> Void {
        if IsDefined(vehicle) && vehicle.IsAttached() && IsDefined(vehicle.GetVehicleComponent()) {
            vehicle.GetVehicleComponent().NCPDPatrolRefreshTrunk();
        };
    }
    public func CloseMenu() -> Void {
        let vehicle: ref<VehicleObject> = this.m_menuVehicle;
        this.m_menuVehicle = null;
        this.Refresh(vehicle);
    }
    // Native interaction records select release versus hold. Choice2 only
    // delivers BUTTON_RELEASED; Choice2_Hold delivers BUTTON_HOLD_COMPLETE.
    // No raw key listener, press event or local hold timer is required.
    public func OpenMenu(vehicle: ref<VehicleObject>) -> Bool {
        if !this.CanUseTrunk(vehicle) || IsDefined(this.m_menuVehicle) { return false; };
        this.m_menuVehicle = vehicle;
        this.Refresh(vehicle);
        return true;
    }
    public func RequestBackupAtTrunk(vehicle: ref<VehicleObject>) -> Bool {
        let support: ref<NCPDPatrolSupportSystem> = NCPDPatrolSupportSystem.Get(this.GetGameInstance());
        // Discard an old queued release if the hold already opened the menu.
        if !this.CanUseTrunk(vehicle) || IsDefined(this.m_menuVehicle) || !IsDefined(support) { return false; };
        return support.RequestBackupAtTrunk(vehicle);
    }

    public func Select(command: Int32, vehicle: ref<VehicleObject>) -> Void {
        if !this.IsOpenFor(vehicle) { return; };
        if command == 0 {
            this.CloseMenu();
            return;
        };
        if command < 1 || command > 6 { return; };
        this.CloseMenu();
        if command == 1 { this.SetBusy(!this.m_busy); return; };
        if command == 2 { this.RequestRepair(vehicle); return; };
        if command == 6 { this.ShowStats(); return; };
        if this.m_command != 0 {
            this.Notice("NCPD: Previous request is still being processed.");
            return;
        };
        this.m_command = command;
    }
    public func TakeCommand() -> Int32 {
        let command: Int32 = this.m_command;
        this.m_command = 0;
        if !this.IsEligible() { return 0; };
        return command;
    }
    public func ReportCommand(text: String) -> Void { this.Notice(text); }

    public func RequestRepair(vehicle: ref<VehicleObject>) -> Bool {
        if !this.CanUseTrunk(vehicle) { return false; };
        if this.m_repairPending {
            this.Notice("NCPD: Vehicle repair is already pending (10-second service).");
            return false;
        };
        this.m_repairVehicle = vehicle;
        this.m_repairPending = true;
        this.m_repairElapsed = 0.0;
        this.Notice("NCPD: Vehicle repair requested. Repair in 10 seconds.");
        return true;
    }
    private func TickRepair(delta: Float) -> Void {
        let patrol: ref<NCPDPatrolSystem> = NCPDPatrolSystem.Get(this.GetGameInstance());
        let component: ref<VehicleComponent>;
        if !this.m_repairPending { return; };
        if !IsDefined(this.m_repairVehicle) || !this.m_repairVehicle.IsAttached()
            || this.m_repairVehicle.IsDestroyed() || !patrol.IsOwnedPoliceVehicle(this.m_repairVehicle) {
            this.m_repairPending = false;
            this.m_repairVehicle = null;
            this.Notice("NCPD: Vehicle repair cancelled. Requested vehicle is unavailable.");
            return;
        };
        this.m_repairElapsed += delta;
        if this.m_repairElapsed < 10.0 { return; };
        component = this.m_repairVehicle.GetVehicleComponent();
        this.m_repairPending = false;
        this.m_repairVehicle = null;
        if IsDefined(component) {
            component.NCPDPatrolRepairVehicle();
            this.Notice("NCPD: Vehicle repair complete.");
        } else {
            this.Notice("NCPD: Vehicle repair failed. Vehicle component unavailable.");
        };
    }

    public func ShowStats() -> Void {
        let career: ref<NCPDPatrolCareerSystem> = NCPDPatrolCareerSystem.Get(this.GetGameInstance());
        let summary: String;
        if !this.IsEligible() || !IsDefined(career) { return; };
        summary = career.GetSummary();
        this.Notice(s"COP STATS | \(summary) | Open NCPD Career in your computer browser.", 10.0);
    }

    public func Tick(delta: Float) -> Void {
        let patrol: ref<NCPDPatrolSystem> = NCPDPatrolSystem.Get(this.GetGameInstance());
        if !this.IsEligible() { this.FinishSession(); return; };
        if patrol.IsDispatchMenuOpen() {
            this.CloseMenu();
            return;
        };
        if IsDefined(this.m_menuVehicle) && !this.CanUseTrunk(this.m_menuVehicle) { this.CloseMenu(); };
        // A paused game never advances the ten-second service timer.
        if delta > 0.0 && delta <= 0.50 { this.TickRepair(delta); };
    }

    public func FinishSession() -> Void {
        this.CloseMenu();
        this.m_busy = false;
        this.m_command = 0;
        this.m_repairPending = false;
        this.m_repairElapsed = 0.0;
        this.m_repairVehicle = null;
    }
}

