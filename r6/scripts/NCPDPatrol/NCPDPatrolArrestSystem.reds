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

    public static func Get(game: GameInstance) -> ref<NCPDPatrolArrestSystem> {
        return GameInstance.GetScriptableSystemsContainer(game).Get(n"NCPDPatrolArrestSystem") as NCPDPatrolArrestSystem;
    }

    public func Version() -> Int32 { return 2; }
    public func Reward() -> Int32 { return 250; }
    public func GetHelperTemplate() -> ResRef { return r"base\\ncpd_patrol\\arrest_workspot.ent"; }
    public func GetWorkspotResource() -> ResRef { return r"base\\workspots\\common\\ground\\generic__lie_ground_lean_front_handcuffs_a__aggressive__01.workspot"; }
    public func AnimationName(name: CName) -> String { return NameToString(name); }
    private func OnAttach() -> Void { this.ForgetWorld(); }
    private func OnRestored(saveVersion: Int32, gameVersion: Int32) -> Void { this.ForgetWorld(); }

    private func ForgetWorld() -> Void {
        // The saved payment ledger survives loads and shift changes. References
        // and workspot ownership from the old world must never be reused.
        this.m_target = null;
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
            this.SetStatus("Securing complete; waiting for the lying arrest animation");
        };
        if this.m_stage == 2 && this.m_elapsed > 10.0 { this.FailPose(this.m_token, "Arrest animation timed out"); };
    }

    // The CET workspot controller calls this only after observing the expected
    // clip for a stable interval. Repeat/stale callbacks are rejected here too.
    public func ConfirmArrestPose(npc: ref<NPCPuppet>, token: Int32) -> Bool {
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
