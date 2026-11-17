// Transient references only: the CET modules register actors they created.
public class NCPDPatrolSupportSystem extends ScriptableSystem {
    private let m_partner: wref<NPCPuppet>;
    // 0 none, 1 active, 2 down, 3 treatment, 4 waiting for native recovery.
    private let m_partnerState: Int32;
    private let m_treatmentTime: Float;
    private let m_recoveryTime: Float;
    private let m_partnerRevision: Int32;
    private let m_backupRequested: Bool;
    private let m_backupActive: Bool;
    private let m_backupStatus: String;
    private let m_backupVehicle: wref<VehicleObject>;
    private let m_backupRepeatNoticeShown: Bool;

    public static func Get(game: GameInstance) -> ref<NCPDPatrolSupportSystem> {
        return GameInstance.GetScriptableSystemsContainer(game).Get(n"NCPDPatrolSupportSystem") as NCPDPatrolSupportSystem;
    }

    private func OnAttach() -> Void { this.ForgetWorld(); }
    private func OnRestored(saveVersion: Int32, gameVersion: Int32) -> Void { this.ForgetWorld(); }
    public func Version() -> Int32 { return 11; }

    private func ForgetWorld() -> Void {
        // Never issue cleanup operations using references from a loaded-away world.
        this.m_partner = null;
        this.m_partnerState = 0;
        this.m_treatmentTime = 0.0;
        this.m_recoveryTime = 0.0;
        this.m_partnerRevision += 1;
        this.m_backupRequested = false;
        this.m_backupActive = false;
        this.m_backupVehicle = null;
        this.m_backupRepeatNoticeShown = false;
        this.m_backupStatus = "Available on duty";
    }

    public func IsDutyEligible() -> Bool {
        let patrol: ref<NCPDPatrolSystem> = NCPDPatrolSystem.Get(this.GetGameInstance());
        return IsDefined(patrol) && patrol.IsOnDuty() && !patrol.HasWantedLevel();
    }

    private func Notice(text: String) -> Void {
        let patrol: ref<NCPDPatrolSystem> = NCPDPatrolSystem.Get(this.GetGameInstance());
        if IsDefined(patrol) { patrol.NotifyDispatch(text, 6.0); };
    }

    public func RegisterPartner(npc: ref<NPCPuppet>) -> Bool {
        let god: ref<GodModeSystem> = GameInstance.GetGodModeSystem(this.GetGameInstance());
        if !this.IsDutyEligible() || !IsDefined(npc) || !npc.IsAttached() || npc.IsDead() || !IsDefined(god) { return false; };
        if NotEquals(npc.GetRecordID(), t"Character.cvi_ncpd_police_ranged2_copperhead_ma") { return false; };
        if IsDefined(this.m_partner) { return this.m_partner == npc; };
        if !god.AddGodMode(npc.GetEntityID(), gameGodModeType.Immortal, n"NCPDPatrolPartner") { return false; };
        this.m_partner = npc;
        this.m_partnerState = 1;
        this.m_partnerRevision += 1;
        // Our immortal health floor and manual defeat state own this actor's cycle.
        npc.SetIsDefeatMechanicActive(false);
        return true;
    }

    public func UnregisterPartner() -> Void {
        let god: ref<GodModeSystem> = GameInstance.GetGodModeSystem(this.GetGameInstance());
        if IsDefined(this.m_partner) && this.m_partner.IsAttached() && IsDefined(god) {
            god.RemoveGodMode(this.m_partner.GetEntityID(), gameGodModeType.Invulnerable, n"NCPDPatrolPartnerDown");
            god.RemoveGodMode(this.m_partner.GetEntityID(), gameGodModeType.Immortal, n"NCPDPatrolPartner");
        };
        this.m_partner = null;
        this.m_partnerState = 0;
        this.m_treatmentTime = 0.0;
        this.m_recoveryTime = 0.0;
        this.m_partnerRevision += 1;
    }

    public const func IsPartner(const npc: ref<GameObject>) -> Bool { return IsDefined(npc) && npc == this.m_partner; }
    public const func IsDownPartner(const npc: ref<GameObject>) -> Bool { return this.IsPartner(npc) && (this.m_partnerState == 2 || this.m_partnerState == 3); }
    public func GetPartnerState() -> Int32 { return this.m_partnerState; }
    public func GetPartnerRevision() -> Int32 { return this.m_partnerRevision; }

    private func InTreatmentRange() -> Bool {
        let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
        if !IsDefined(player) || !IsDefined(this.m_partner) || player.IsDead() || !this.m_partner.IsAttached() || this.m_partner.IsDead() { return false; };
        if VehicleComponent.IsMountedToVehicle(this.GetGameInstance(), player) || VehicleComponent.IsMountedToVehicle(this.GetGameInstance(), this.m_partner) { return false; };
        return Vector4.Distance(player.GetWorldPosition(), this.m_partner.GetWorldPosition()) <= 2.5;
    }

    public func DownPartner() -> Bool {
        let god: ref<GodModeSystem> = GameInstance.GetGodModeSystem(this.GetGameInstance());
        if !this.IsDutyEligible() || this.m_partnerState != 1 || !IsDefined(this.m_partner) || this.m_partner.IsDead() || !IsDefined(god) { return false; };
        // Do not eject an injured passenger from a moving vehicle.
        if VehicleComponent.IsMountedToVehicle(this.GetGameInstance(), this.m_partner) { return false; };
        this.m_partnerState = 2;
        this.m_treatmentTime = 0.0;
        this.m_partnerRevision += 1;
        god.AddGodMode(this.m_partner.GetEntityID(), gameGodModeType.Invulnerable, n"NCPDPatrolPartnerDown");
        StatusEffectHelper.ApplyStatusEffect(this.m_partner, t"BaseStatusEffect.Defeated");
        this.m_partner.NCPDPatrolRefreshAidInteraction();
        this.Notice("NCPD: Partner down. Approach your partner to revive.");
        return true;
    }

    public func StartPartnerRevive() -> Bool {
        if !this.IsDutyEligible() || this.m_partnerState != 2 || !this.InTreatmentRange() { return false; };
        this.m_partnerState = 3;
        this.m_treatmentTime = 0.0;
        this.m_partnerRevision += 1;
        this.m_partner.NCPDPatrolRefreshAidInteraction();
        return true;
    }

    public func TickPartner(delta: Float) -> Void {
        let health: Float;
        let god: ref<GodModeSystem>;
        if !this.IsDutyEligible() || !IsDefined(this.m_partner) || !this.m_partner.IsAttached() || this.m_partner.IsDead() { return; };
        // Callers pause this tick in menus; do not fast-forward a treatment on a hitch.
        if delta <= 0.0 || delta > 0.5 { return; };
        if this.m_partnerState == 1 {
            health = GameInstance.GetStatPoolsSystem(this.GetGameInstance()).GetStatPoolValue(Cast<StatsObjectID>(this.m_partner.GetEntityID()), gamedataStatPoolType.Health, true);
            if health <= 10.0 || ScriptedPuppet.IsDefeated(this.m_partner) || ScriptedPuppet.IsUnconscious(this.m_partner) { this.DownPartner(); };
            return;
        };
        if this.m_partnerState == 2 { return; };
        if this.m_partnerState == 3 {
            if !this.InTreatmentRange() {
                this.m_partnerState = 2;
                this.m_treatmentTime = 0.0;
                this.m_partnerRevision += 1;
                this.m_partner.NCPDPatrolRefreshAidInteraction();
                this.Notice("NCPD: Revive interrupted. Return to your partner to try again.");
                return;
            };
            this.m_treatmentTime += delta;
            if this.m_treatmentTime < 3.0 { return; };
            this.m_partnerState = 4;
            this.m_recoveryTime = 0.0;
            this.m_partnerRevision += 1;
            this.m_partner.NCPDPatrolRefreshAidInteraction();
            GameInstance.GetStatPoolsSystem(this.GetGameInstance()).RequestSettingStatPoolValue(Cast<StatsObjectID>(this.m_partner.GetEntityID()), gamedataStatPoolType.Health, 100.0, null, true);
            StatusEffectHelper.RemoveStatusEffect(this.m_partner, t"BaseStatusEffect.Defeated");
            StatusEffectHelper.RemoveStatusEffect(this.m_partner, t"BaseStatusEffect.Unconscious");
            StatusEffectHelper.RemoveStatusEffect(this.m_partner, t"BaseStatusEffect.InvulnerableAfterDefeated");
            ScriptedPuppet.SendResurrectEvent(this.m_partner);
            return;
        };
        if this.m_partnerState == 4 {
            this.m_recoveryTime += delta;
            if this.m_recoveryTime < 1.0 { return; };
            if ScriptedPuppet.IsActive(this.m_partner) {
                god = GameInstance.GetGodModeSystem(this.GetGameInstance());
                if IsDefined(god) { god.RemoveGodMode(this.m_partner.GetEntityID(), gameGodModeType.Invulnerable, n"NCPDPatrolPartnerDown"); };
                this.m_partnerState = 1;
                this.m_partnerRevision += 1;
                this.m_partner.SetIsDefeatMechanicActive(false);
                this.m_partner.NCPDPatrolRefreshAidInteraction();
                this.Notice("NCPD: Partner revived. Returning to duty.");
            } else {
                if this.m_recoveryTime >= 5.0 {
                    this.m_partnerState = 2;
                    this.m_partnerRevision += 1;
                    this.m_partner.NCPDPatrolRefreshAidInteraction();
                    this.Notice("NCPD: Partner has not recovered. Try revive again.");
                };
            };
        };
    }

    public func CanUseTrunk(vehicle: ref<VehicleObject>) -> Bool {
        let patrol: ref<NCPDPatrolSystem> = NCPDPatrolSystem.Get(this.GetGameInstance());
        let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
        return this.IsDutyEligible() && IsDefined(patrol) && IsDefined(player) && IsDefined(vehicle) && patrol.IsOwnedPoliceVehicle(vehicle) && !vehicle.IsDestroyed() && !VehicleComponent.IsMountedToVehicle(this.GetGameInstance(), player);
    }

    public func RequestBackupAtTrunk(vehicle: ref<VehicleObject>) -> Bool {
        if !this.CanUseTrunk(vehicle) { return false; };
        if Vector4.Distance(GetPlayer(this.GetGameInstance()).GetWorldPosition(), vehicle.GetWorldPosition()) > 5.0 { return false; };
        if !this.RequestBackup() { return false; };
        this.m_backupVehicle = vehicle;
        return true;
    }

    public func RequestBackup() -> Bool {
        let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
        if !this.IsDutyEligible() || !IsDefined(player) || player.IsDead() { return false; };
        if this.m_backupRequested || this.m_backupActive {
            if !this.m_backupRepeatNoticeShown {
                this.Notice("NCPD: One backup patrol is already assigned. Leave the scene to release it.");
                this.m_backupRepeatNoticeShown = true;
            };
            return false;
        };
        this.m_backupRequested = true;
        this.m_backupRepeatNoticeShown = false;
        this.m_backupVehicle = null;
        this.m_backupStatus = "Requested; waiting for deployment";
        return true;
    }

    public func TakeBackupRequest() -> Bool {
        if !this.m_backupRequested || !this.IsDutyEligible() { return false; };
        this.m_backupRequested = false;
        this.m_backupActive = true;
        return true;
    }

    public func SetBackupStatus(text: String) -> Void { this.m_backupStatus = text; }
    public func GetBackupStatus() -> String { return this.m_backupStatus; }
    public func HasBackupUnit() -> Bool { return this.m_backupRequested || this.m_backupActive; }
    public func GetBackupVehicle() -> ref<VehicleObject> { return this.m_backupVehicle; }
    public func ReleaseBackup() -> Void {
        this.m_backupRequested = false;
        this.m_backupActive = false;
        this.m_backupVehicle = null;
        this.m_backupStatus = "Available on duty";
        this.m_backupRepeatNoticeShown = false;
    }
}
