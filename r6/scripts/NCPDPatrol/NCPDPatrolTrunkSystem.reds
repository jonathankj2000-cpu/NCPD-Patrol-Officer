// Independent, transient bridge. No changes to scanner or arrest payments.
public class NCPDPatrolTrunkSystem extends ScriptableSystem {
    private let m_player: wref<PlayerPuppet>;
    private let m_input: CName;
    private let m_keyDown: Bool;
    private let m_pressedAt: Float;
    private let m_serial: Int32;
    private let m_handledSerial: Int32;
    private let m_releaseSerial: Int32;
    private let m_releasedAt: Float;
    private let m_releaseDuration: Float;
    private let m_pendingVehicle: wref<VehicleObject>;
    private let m_pendingAt: Float;
    private let m_waitingForPress: Bool;
    private let m_menuVehicle: wref<VehicleObject>;
    private let m_busy: Bool;
    private let m_command: Int32;
    private let m_repairVehicle: wref<VehicleObject>;
    private let m_repairPending: Bool;
    private let m_repairElapsed: Float;

    public static func Get(game: GameInstance) -> ref<NCPDPatrolTrunkSystem> {
        return GameInstance.GetScriptableSystemsContainer(game).Get(n"NCPDPatrolTrunkSystem") as NCPDPatrolTrunkSystem;
    }
    public func Version() -> Int32 { return 1; }
    private func OnAttach() -> Void { this.ForgetWorld(); }
    private func OnRestored(saveVersion: Int32, gameVersion: Int32) -> Void { this.ForgetWorld(); }
    private func OnDetach() -> Void { this.FinishSession(); }

    private func ForgetWorld() -> Void {
        // Loading already invalidated the previous world's listeners and objects.
        this.m_player = null;
        this.m_keyDown = false;
        this.m_serial = 0;
        this.m_handledSerial = -1;
        this.m_releaseSerial = 0;
        this.m_releasedAt = -999.0;
        this.m_pendingVehicle = null;
        this.m_waitingForPress = false;
        this.m_menuVehicle = null;
        this.m_busy = false;
        this.m_command = 0;
        this.m_repairVehicle = null;
        this.m_repairPending = false;
        this.m_repairElapsed = 0.0;
    }

    private func Now() -> Float {
        return EngineTime.ToFloat(GameInstance.GetEngineTime(this.GetGameInstance()));
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
        return Cast<Int32>(CeilF(10.0 - this.m_repairElapsed));
    }

    private func Refresh(vehicle: ref<VehicleObject>) -> Void {
        if IsDefined(vehicle) && vehicle.IsAttached() && IsDefined(vehicle.GetVehicleComponent()) {
            vehicle.GetVehicleComponent().NCPDPatrolRefreshTrunk();
        };
    }
    public func CloseMenu() -> Void {
        let vehicle: ref<VehicleObject> = this.m_menuVehicle;
        this.m_menuVehicle = null;
        this.m_pendingVehicle = null;
        this.m_waitingForPress = false;
        this.Refresh(vehicle);
    }
    private func OpenMenu(vehicle: ref<VehicleObject>) -> Void {
        if !this.CanUseTrunk(vehicle) { return; };
        this.m_menuVehicle = vehicle;
        this.m_pendingVehicle = null;
        this.m_waitingForPress = false;
        this.Refresh(vehicle);
    }

    // The native interaction authorizes this particular trunk; an R press by
    // itself never requests backup or opens a menu elsewhere in the world.
    public func BeginGesture(vehicle: ref<VehicleObject>) -> Void {
        let age: Float = this.Now() - this.m_releasedAt;
        if !this.CanUseTrunk(vehicle) || IsDefined(this.m_menuVehicle) { return; };
        if this.m_keyDown {
            if this.m_serial == this.m_handledSerial { return; };
            this.m_pendingVehicle = vehicle;
            this.m_waitingForPress = false;
            this.ResolveHold();
            return;
        };
        if this.m_releaseSerial > 0 && age >= 0.0 && age <= 0.20 {
            if this.m_releaseSerial == this.m_handledSerial { return; };
            this.ResolveReleasedGesture(vehicle);
            return;
        };
        // Some interaction handlers run before the input listener in a frame.
        this.m_pendingVehicle = vehicle;
        this.m_pendingAt = this.Now();
        this.m_waitingForPress = true;
    }
    private func ResolveHold() -> Void {
        if !this.m_keyDown || this.m_waitingForPress || !IsDefined(this.m_pendingVehicle)
            || this.m_serial == this.m_handledSerial || this.Now() - this.m_pressedAt < 0.50 { return; };
        this.m_handledSerial = this.m_serial;
        this.OpenMenu(this.m_pendingVehicle);
    }
    private func ResolveReleasedGesture(vehicle: ref<VehicleObject>) -> Void {
        let support: ref<NCPDPatrolSupportSystem>;
        if this.m_releaseSerial == this.m_handledSerial { return; };
        this.m_handledSerial = this.m_releaseSerial;
        this.m_pendingVehicle = null;
        this.m_waitingForPress = false;
        if !this.CanUseTrunk(vehicle) { return; };
        if this.m_releaseDuration >= 0.50 {
            this.OpenMenu(vehicle);
        } else {
            support = NCPDPatrolSupportSystem.Get(this.GetGameInstance());
            if IsDefined(support) { support.RequestBackupAtTrunk(vehicle); };
        };
    }

    protected cb func OnAction(action: ListenerAction, consumer: ListenerActionConsumer) -> Bool {
        if NotEquals(ListenerAction.GetName(action), this.m_input) || !this.IsEligible() { return false; };
        if ListenerAction.IsButtonJustPressed(action) {
            if !this.m_keyDown {
                this.m_keyDown = true;
                this.m_serial += 1;
                this.m_pressedAt = this.Now();
                this.m_waitingForPress = false;
            };
        };
        if ListenerAction.IsButtonJustReleased(action) && this.m_keyDown {
            this.m_keyDown = false;
            this.m_releaseSerial = this.m_serial;
            this.m_releasedAt = this.Now();
            this.m_releaseDuration = this.m_releasedAt - this.m_pressedAt;
            if IsDefined(this.m_pendingVehicle) && !this.m_waitingForPress {
                this.ResolveReleasedGesture(this.m_pendingVehicle);
            };
        };
        // Observe only. Vanilla input consumption and all other keys are intact.
        return false;
    }

    public func Select(command: Int32, vehicle: ref<VehicleObject>) -> Void {
        if !this.IsOpenFor(vehicle) { return; };
        if command == 0 {
            // Releasing the R used to open the menu must not close it again.
            if this.m_keyDown && this.m_serial == this.m_handledSerial { return; };
            if !this.m_keyDown && this.m_releaseSerial == this.m_handledSerial
                && this.Now() - this.m_releasedAt <= 0.20 { return; };
            this.m_handledSerial = this.m_serial;
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
        let patrol: ref<NCPDPatrolSystem> = NCPDPatrolSystem.Get(this.GetGameInstance());
        let count: Int32;
        let next: Int32 = 10;
        if !this.IsEligible() { return; };
        count = patrol.GetRecordedScannerCount();
        if count >= 10 { next = 20; };
        while next <= count { next += 20; };
        this.Notice(s"COP STATS | Recorded on-duty scanner completions: \(count) | Next milestone: \(next) | Progression rewards: planned.", 10.0);
    }

    public func Tick(delta: Float) -> Void {
        let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
        let patrol: ref<NCPDPatrolSystem> = NCPDPatrolSystem.Get(this.GetGameInstance());
        if !this.IsEligible() { this.FinishSession(); return; };
        if !IsDefined(this.m_player) {
            this.m_player = player;
            this.m_input = TweakDBInterface.GetCName(t"Interactions.NCPDPatrolBackup.action", n"Choice2");
            player.RegisterInputListener(this, this.m_input);
        };
        if patrol.IsDispatchMenuOpen() {
            this.CloseMenu();
            this.m_keyDown = false;
            this.m_handledSerial = this.m_serial;
            return;
        };
        if IsDefined(this.m_menuVehicle) && !this.CanUseTrunk(this.m_menuVehicle) { this.CloseMenu(); };
        if IsDefined(this.m_pendingVehicle) {
            if !this.CanUseTrunk(this.m_pendingVehicle) {
                this.m_pendingVehicle = null;
                this.m_waitingForPress = false;
            } else {
                if this.m_waitingForPress && this.Now() - this.m_pendingAt > 0.30 {
                    this.m_pendingVehicle = null;
                    this.m_waitingForPress = false;
                    this.Notice("NCPD: Trunk input not received. Try releasing and pressing the secondary interaction again.");
                } else {
                    this.ResolveHold();
                };
            };
        };
        // A paused game never advances the ten-second service timer.
        if delta > 0.0 && delta <= 0.50 { this.TickRepair(delta); };
    }

    public func FinishSession() -> Void {
        if IsDefined(this.m_player) { this.m_player.UnregisterInputListener(this, this.m_input); };
        this.m_player = null;
        this.CloseMenu();
        this.m_keyDown = false;
        this.m_handledSerial = this.m_serial;
        this.m_busy = false;
        this.m_command = 0;
        this.m_repairPending = false;
        this.m_repairElapsed = 0.0;
        this.m_repairVehicle = null;
    }
}

