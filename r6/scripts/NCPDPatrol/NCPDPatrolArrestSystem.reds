// Arrest rewards are owned by this system. Scanner activities, scanner payment
// history, bonus counters and the bonus receipt queue are never used here.
public class NCPDPatrolArrestSystem extends ScriptableSystem {
    private persistent let m_paidSuspects: array<CName>;
    private let m_target: wref<NPCPuppet>;
    // 0 idle, 1 securing suspect, 2 awaiting the observed arrest workspot.
    private let m_stage: Int32;
    private let m_token: Int32;
    private let m_elapsed: Float;
    private let m_status: String;
    private let m_revision: Int32;
    private let m_receipts: array<String>;
    private let m_receiptTime: Float;
    private let m_playback: ref<NCPDPatrolArrestPlayback>;
    private let m_posePhysics: array<wref<NPCPuppet>>;
    private let m_recoveryTarget: wref<NPCPuppet>;
    private let m_recoveryToken: Int32;
    private let m_recoveryOrigin: Vector4;

    public static func Get(game: GameInstance) -> ref<NCPDPatrolArrestSystem> {
        return GameInstance.GetScriptableSystemsContainer(game).Get(n"NCPDPatrolArrestSystem") as NCPDPatrolArrestSystem;
    }

    public func Version() -> Int32 { return 6; }
    public func Reward() -> Int32 { return 250; }
    public func GetHelperTemplate() -> ResRef { return r"base\\ncpd_patrol\\arrest_workspot.ent"; }
    public func GetLoopResource() -> ResRef { return r"base\\ncpd_patrol\\arrest_lying_loop.workspot"; }
    public func GetWorkspotResource() -> ResRef { return r"base\\workspots\\common\\ground\\generic__lie_ground_lean_front_handcuffs_a__aggressive__01.workspot"; }
    public func AnimationName(name: CName) -> String { return NameToString(name); }
    private func OnAttach() -> Void { this.ForgetWorld(); }
    private func OnRestored(saveVersion: Int32, gameVersion: Int32) -> Void { this.ForgetWorld(); }

    private func ForgetWorld() -> Void {
        // The saved payment ledger survives loads and shift changes. References
        // and workspot ownership from the old world must never be reused.
        this.m_target = null;
        ArrayClear(this.m_posePhysics);
        this.m_recoveryTarget = null;
        this.m_recoveryToken = 0;
        this.m_playback = null;
        this.m_stage = 0;
        this.m_elapsed = 0.0;
        this.m_token += 1;
        ArrayClear(this.m_receipts);
        this.m_receiptTime = 0.0;
        this.SetStatus("Ready on duty; EUR$250 per arrest");
    }

    public func IsDutyEligible() -> Bool {
        let duty: ref<NCPDPatrolSystem> = NCPDPatrolSystem.Get(this.GetGameInstance());
        return IsDefined(duty) && duty.IsOnDuty() && !duty.HasWantedLevel();
    }

    private func SuspectKey(npc: ref<NPCPuppet>) -> CName {
        let id: String = EntityID.ToDebugStringDecimal(npc.GetEntityID());
        return StringToName(s"ncpd-arrest-\(id)");
    }

    public func IsArrested(npc: ref<NPCPuppet>) -> Bool {
        return IsDefined(npc) && ArrayContains(this.m_paidSuspects, this.SuspectKey(npc));
    }

    public func IsEligibleSuspect(npc: ref<NPCPuppet>) -> Bool {
        if !this.IsDutyEligible() || !IsDefined(npc) || !npc.IsAttached() { return false; };
        if npc.IsDead() || npc.IsDeadNoStatPool() || this.IsArrested(npc) { return false; };
        if NotEquals(npc.GetNPCType(), gamedataNPCType.Human) || npc.IsCharacterCivilian() || npc.IsCharacterPolice() || npc.IsPlayerCompanion() { return false; };
        // Quest loot also sets IsQuest; this conservative first build deliberately
        // excludes those bodies rather than replacing their story interaction.
        if npc.IsQuest() || npc.IsBoss() || !npc.IsEnemy() { return false; };
        if VehicleComponent.IsMountedToVehicle(this.GetGameInstance(), npc) { return false; };
        return ScriptedPuppet.IsDefeated(npc) || ScriptedPuppet.IsUnconscious(npc);
    }

    public func CanStartArrest(npc: ref<NPCPuppet>) -> Bool {
        return this.m_stage == 0 && this.IsEligibleSuspect(npc);
    }

    public func IsPendingSuspect(npc: ref<GameObject>) -> Bool {
        return this.m_stage != 0 && IsDefined(npc) && npc == this.m_target;
    }

    public func OwnsPosePhysics(const npc: ref<NPCPuppet>) -> Bool {
        let i: Int32 = 0;
        if !IsDefined(npc) { return false; };
        while i < ArraySize(this.m_posePhysics) {
            if this.m_posePhysics[i] == npc { return true; };
            i += 1;
        };
        return false;
    }

    public func BeginPoseRecovery(npc: ref<NPCPuppet>, token: Int32) -> Bool {
        if this.m_stage != 2 || token != this.m_token || npc != this.m_target { return false; };
        if !this.IsEligibleSuspect(npc) || !this.InRange(npc) { return false; };
        if this.OwnsPosePhysics(npc) { return this.m_recoveryTarget == npc && this.m_recoveryToken == token; };
        if !npc.IsRagdollEnabled() { return false; };
        this.m_recoveryTarget = npc;
        this.m_recoveryToken = token;
        this.m_recoveryOrigin = npc.GetWorldPosition();
        ArrayPush(this.m_posePhysics, npc);
        npc.QueueEvent(CreateDisableRagdollEvent(n"NCPDPatrolArrest"));
        npc.SetDisableRagdoll(true);
        return true;
    }

    public func PlaceRecoveredSuspect(npc: ref<NPCPuppet>, token: Int32, point: Vector4) -> Bool {
        let teleport: ref<TeleportationFacility> = GameInstance.GetTeleportationFacility(this.GetGameInstance());
        if this.m_stage != 2 || token != this.m_token || npc != this.m_target { return false; };
        if npc != this.m_recoveryTarget || token != this.m_recoveryToken || !this.OwnsPosePhysics(npc) { return false; };
        if !this.IsEligibleSuspect(npc) || !this.InRange(npc) || npc.IsRagdollEnabled() || !IsDefined(teleport) { return false; };
        if point.X != point.X || point.Y != point.Y || point.Z != point.Z { return false; };
        if AbsF(point.X) > 100000.0 || AbsF(point.Y) > 100000.0 || AbsF(point.Z) > 100000.0 { return false; };
        if Vector4.Distance(point, this.m_recoveryOrigin) > 2.0 || AbsF(point.Z - this.m_recoveryOrigin.Z) > 0.75 { return false; };
        if Vector4.Distance(GetPlayer(this.GetGameInstance()).GetWorldPosition(), point) > 2.5 { return false; };
        teleport.Teleport(npc, point, Quaternion.ToEulerAngles(npc.GetWorldOrientation()));
        return true;
    }

    public func ReleasePosePhysics(npc: ref<NPCPuppet>) -> Void {
        let i: Int32 = 0;
        let found: Bool = false;
        while i < ArraySize(this.m_posePhysics) {
            if this.m_posePhysics[i] == npc {
                ArrayErase(this.m_posePhysics, i);
                found = true;
            } else { i += 1; };
        };
        if !found { return; };
        if this.m_recoveryTarget == npc { this.m_recoveryTarget = null; this.m_recoveryToken = 0; };
        if !IsDefined(npc) || !npc.IsAttached() { return; };
        // Pickup/mounting can take ownership after payment. Its own unmount
        // sequence restores physics; do not force a carried body to drop.
        if GameInstance.GetMountingFacility(this.GetGameInstance()).IsMountedToAnything(npc.GetEntityID()) { return; };
        // Remove our gate first; other mods and native restrictions keep priority.
        npc.SetDisableRagdoll(false);
        if !npc.IsDead() && !npc.IsDeadNoStatPool() && (ScriptedPuppet.IsDefeated(npc) || ScriptedPuppet.IsUnconscious(npc))
            && npc.CanEnableRagdollComponent() && !GameInstance.GetWorkspotSystem(this.GetGameInstance()).IsActorInWorkspot(npc) {
            npc.QueueEvent(CreateForceRagdollNoPowerPoseEvent(n"NCPDPatrolArrestReleased"));
        };
    }

    private func InRange(npc: ref<NPCPuppet>) -> Bool {
        let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
        if !IsDefined(player) || player.IsDead() || !IsDefined(npc) || !npc.IsAttached() { return false; };
        if VehicleComponent.IsMountedToVehicle(this.GetGameInstance(), player) { return false; };
        return Vector4.Distance(player.GetWorldPosition(), npc.GetWorldPosition()) <= 2.5;
    }

    public func StartArrest(npc: ref<NPCPuppet>) -> Bool {
        if !this.CanStartArrest(npc) || !this.InRange(npc) { return false; };
        this.m_target = npc;
        this.m_stage = 1;
        this.m_elapsed = 0.0;
        this.m_token += 1;
        npc.NCPDPatrolRefreshArrestInteraction();
        this.SetStatus("Securing suspect; stay within 2.5 m for 2 seconds");
        return true;
    }

    public func CancelArrest(reason: String) -> Void {
        let npc: ref<NPCPuppet> = this.m_target;
        this.m_target = null;
        this.m_playback = null;
        this.m_stage = 0;
        this.m_elapsed = 0.0;
        this.m_token += 1;
        this.SetStatus(reason);
        if IsDefined(npc) && npc.IsAttached() { npc.NCPDPatrolRefreshArrestInteraction(); };
    }

    public func FailPose(token: Int32, reason: String) -> Void {
        if this.m_stage != 2 || token != this.m_token { return; };
        this.CancelArrest(reason);
        this.ShowMessage("NCPD: Arrest not registered. " + reason, false);
    }

    public func GetStage() -> Int32 { return this.m_stage; }
    public func GetToken() -> Int32 { return this.m_token; }
    public func GetTarget() -> ref<NPCPuppet> { return this.m_target; }
    public func GetStatus() -> String { return this.m_status; }
    public func GetRevision() -> Int32 { return this.m_revision; }
    public func GetPaidArrests() -> Int32 { return ArraySize(this.m_paidSuspects); }

    private func SetStatus(text: String) -> Void {
        this.m_status = text;
        this.m_revision += 1;
    }

    public func Tick(delta: Float, paused: Bool) -> Void {
        if this.m_stage != 0 && !this.IsDutyEligible() { this.CancelArrest("Arrest cancelled: off duty or wanted"); };
        if paused || delta <= 0.0 || delta > 0.5 { return; };
        // An independent queue displays already-paid arrest receipts, including
        // after ending duty. No receipt callback can award money.
        if this.m_receiptTime > 0.0 { this.m_receiptTime -= delta; };
        if this.m_receiptTime <= 0.0 && ArraySize(this.m_receipts) > 0 {
            this.ShowMessage(this.m_receipts[0], true);
            ArrayErase(this.m_receipts, 0);
            this.m_receiptTime = 5.0;
        };
        if this.m_stage == 0 { return; };
        if !this.IsEligibleSuspect(this.m_target) || !this.InRange(this.m_target) {
            this.CancelArrest("Arrest interrupted: suspect unavailable or out of range");
            return;
        };
        this.m_elapsed += delta;
        if this.m_stage == 1 && this.m_elapsed >= 2.0 {
            this.m_stage = 2;
            this.m_elapsed = 0.0;
            this.m_target.NCPDPatrolRefreshArrestInteraction();
            this.SetStatus("Securing complete; waiting for arrest playback activation");
        };
        if this.m_stage == 2 && this.m_elapsed > 10.0 { this.FailPose(this.m_token, "Arrest animation timed out"); };
    }

    public func ArmPlayback(npc: ref<NPCPuppet>, helper: ref<GameObject>, token: Int32, proof: ref<NCPDPatrolArrestPlayback>) -> Bool {
        if this.m_stage != 2 || token != this.m_token || npc != this.m_target || IsDefined(this.m_playback) { return false; };
        if !IsDefined(proof) || !this.IsEligibleSuspect(npc) || !this.InRange(npc) { return false; };
        if !proof.Arm(npc, helper, token) { return false; };
        this.m_playback = proof;
        return true;
    }

    public func AcceptPlayResult(helperID: EntityID, success: Bool) -> Bool {
        if this.m_stage != 2 || !IsDefined(this.m_playback) { return false; };
        if !this.m_playback.AcceptResult(helperID, success) { return false; };
        if !success { this.FailPose(this.m_token, "Native arrest playback was rejected"); };
        return true;
    }

    public func ConfirmActivatedArrest(npc: ref<NPCPuppet>, token: Int32, proof: ref<NCPDPatrolArrestPlayback>) -> Bool {
        if !IsDefined(proof) || proof != this.m_playback || !proof.Matches(npc, token) { return false; };
        return this.ConfirmArrestPose(npc, token);
    }

    // Registration credits completed securing and acknowledged native
    // activation. It does not claim to have inspected the rendered clip.
    private func ConfirmArrestPose(npc: ref<NPCPuppet>, token: Int32) -> Bool {
        let transaction: ref<TransactionSystem>;
        let player: ref<PlayerPuppet>;
        let amount: Int32;
        let receipt: String;
        if this.m_stage != 2 || token != this.m_token || npc != this.m_target { return false; };
        if !this.IsEligibleSuspect(npc) || !this.InRange(npc) { this.CancelArrest("Suspect no longer eligible"); return false; };
        player = GetPlayer(this.GetGameInstance());
        transaction = GameInstance.GetTransactionSystem(this.GetGameInstance());
        if !IsDefined(player) || !IsDefined(transaction) { this.CancelArrest("Arrest payment unavailable; no reward paid"); return false; };
        amount = this.Reward();
        if !transaction.GiveItem(player, ItemID.FromTDBID(t"Items.money"), amount) { this.CancelArrest("Arrest payment failed; no reward paid"); return false; };
        ArrayPush(this.m_paidSuspects, this.SuspectKey(npc));
        receipt = s"NCPD ARREST REGISTERED | +EUR$\(amount)";
        ArrayPush(this.m_receipts, receipt);
        this.CancelArrest(receipt);
        return true;
    }

    private func ShowMessage(text: String, money: Bool) -> Void {
        let message: SimpleScreenMessage;
        message.isShown = true;
        message.duration = 5.0;
        message.message = text;
        message.isInstant = true;
        message.type = money ? SimpleMessageType.Money : SimpleMessageType.Neutral;
        GameInstance.GetBlackboardSystem(this.GetGameInstance()).Get(GetAllBlackboardDefs().UI_Notifications)
            .SetVariant(GetAllBlackboardDefs().UI_Notifications.WarningMessage, ToVariant(message), true);
    }
}
