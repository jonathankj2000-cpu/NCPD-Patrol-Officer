// Generated dispatches have their own save-local completion/payment history.
// Scanner IDs, arrest receipts and existing milestone reward IDs stay separate.
public class NCPDPatrolIncidentSystem extends ScriptableSystem {
    private persistent let m_serial: Int32;
    private persistent let m_completedIds: array<Int32>;
    private persistent let m_completedKinds: array<CName>;
    private persistent let m_completedAmounts: array<Int32>;
    private persistent let m_paidIds: array<Int32>;
    private let m_openIds: array<Int32>;
    private let m_openKinds: array<CName>;
    private let m_receipts: array<String>;
    private let m_poll: Float;
    private let m_noticeDelay: Float;
    private let m_revision: Int32;
    private let m_status: String;

    public static func Get(game: GameInstance) -> ref<NCPDPatrolIncidentSystem> {
        return GameInstance.GetScriptableSystemsContainer(game).Get(n"NCPDPatrolIncidentSystem") as NCPDPatrolIncidentSystem;
    }
    public func Version() -> Int32 { return 1; }
    private func OnAttach() -> Void { this.ResetRuntime(); }
    private func OnRestored(saveVersion: Int32, gameVersion: Int32) -> Void { this.ResetRuntime(); }
    private func ResetRuntime() -> Void {
        // In-flight dispatches are cancelled on load. Earned money/completions
        // survive; the saved serial prevents an old token being reused.
        ArrayClear(this.m_openIds); ArrayClear(this.m_openKinds); ArrayClear(this.m_receipts);
        this.m_poll = 1.0; this.m_noticeDelay = 0.0;
        this.m_status = "Generated dispatch rewards ready";
        this.m_revision += 1;
    }
    private func Eligible() -> Bool {
        let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
        let patrol: ref<NCPDPatrolSystem> = NCPDPatrolSystem.Get(this.GetGameInstance());
        return IsDefined(player) && player.IsAttached() && !player.IsDead()
            && IsDefined(patrol) && patrol.IsOnDuty() && !patrol.HasWantedLevel();
    }
    public func Reserve(kind: CName) -> Int32 {
        if !this.Eligible() || (NotEquals(kind, n"vip") && NotEquals(kind, n"cyberpsycho")) { return 0; };
        if this.m_serial >= 2147483647 { return 0; };
        this.m_serial += 1;
        ArrayPush(this.m_openIds, this.m_serial); ArrayPush(this.m_openKinds, kind);
        return this.m_serial;
    }
    public func Cancel(id: Int32, kind: CName) -> Void {
        let index: Int32 = ArrayFindFirst(this.m_openIds, id);
        if index < 0 || NotEquals(this.m_openKinds[index], kind) { return; };
        ArrayErase(this.m_openIds, index); ArrayErase(this.m_openKinds, index);
    }
    public func CompleteVIP(id: Int32) -> Bool { return this.Complete(id, n"vip", 2000); }
    public func CompleteCyberpsycho(id: Int32, nonLethal: Bool) -> Bool {
        let amount: Int32 = 3000;
        if nonLethal { amount += 500; };
        return this.Complete(id, n"cyberpsycho", amount);
    }
    private func Complete(id: Int32, kind: CName, amount: Int32) -> Bool {
        let index: Int32 = ArrayFindFirst(this.m_completedIds, id);
        if id <= 0 { return false; };
        if index >= 0 { return Equals(this.m_completedKinds[index], kind); };
        if !this.Eligible() { return false; };
        index = ArrayFindFirst(this.m_openIds, id);
        if index < 0 || NotEquals(this.m_openKinds[index], kind) { return false; };
        ArrayErase(this.m_openIds, index); ArrayErase(this.m_openKinds, index);
        ArrayPush(this.m_completedIds, id); ArrayPush(this.m_completedKinds, kind);
        ArrayPush(this.m_completedAmounts, amount);
        this.m_revision += 1;
        this.m_status = "Incident completed; payment pending";
        this.TryPayment();
        return true;
    }
    public func GetCompletedCount() -> Int32 { return ArraySize(this.m_completedIds); }
    public func GetPendingPayments() -> Int32 { return ArraySize(this.m_completedIds) - ArraySize(this.m_paidIds); }
    private func CountKind(kind: CName) -> Int32 {
        let i: Int32 = 0;
        let count: Int32 = 0;
        while i < ArraySize(this.m_completedKinds) {
            if Equals(this.m_completedKinds[i], kind) { count += 1; };
            i += 1;
        };
        return count;
    }
    public func GetCompletedVIP() -> Int32 { return this.CountKind(n"vip"); }
    public func GetCompletedCyberpsychos() -> Int32 { return this.CountKind(n"cyberpsycho"); }
    private func TryPayment() -> Void {
        let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
        let transaction: ref<TransactionSystem> = GameInstance.GetTransactionSystem(this.GetGameInstance());
        let i: Int32 = ArraySize(this.m_paidIds);
        let id: Int32;
        let amount: Int32;
        let receipt: String;
        if !IsDefined(player) || !player.IsAttached() || player.IsDead() || !IsDefined(transaction) { return; };
        // Payments are FIFO: paid IDs are the completed-record prefix. Use its
        // length as the next index instead of rescanning all historic payments.
        if i < ArraySize(this.m_completedIds) {
            id = this.m_completedIds[i];
            if !ArrayContains(this.m_paidIds, id) {
                amount = this.m_completedAmounts[i];
                if !transaction.GiveItem(player, ItemID.FromTDBID(t"Items.money"), amount) { return; };
                // One native money grant includes any non-lethal supplement.
                ArrayPush(this.m_paidIds, id);
                if Equals(this.m_completedKinds[i], n"vip") {
                    receipt = s"VIP TRANSPORT PAID | +EUR$\(amount)";
                } else {
                    receipt = s"CYBERPSYCHO DISPATCH PAID | +EUR$\(amount)";
                    if amount == 3500 { receipt = receipt + " | Non-lethal bonus included: EUR$500"; };
                };
                ArrayPush(this.m_receipts, receipt);
                if this.m_noticeDelay <= 0.0 { this.m_noticeDelay = 8.0; };
                this.m_status = receipt; this.m_revision += 1;
                return;
            };
        };
    }
    private func ShowReceipt(text: String) -> Void {
        let message: SimpleScreenMessage;
        message.isShown = true; message.duration = 6.0; message.message = text;
        message.isInstant = true; message.type = SimpleMessageType.Money;
        GameInstance.GetBlackboardSystem(this.GetGameInstance()).Get(GetAllBlackboardDefs().UI_Notifications)
            .SetVariant(GetAllBlackboardDefs().UI_Notifications.WarningMessage, ToVariant(message), true);
    }
    public func Tick(delta: Float) -> Void {
        let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
        let patrol: ref<NCPDPatrolSystem> = NCPDPatrolSystem.Get(this.GetGameInstance());
        if delta <= 0.0 || delta > 0.5 || !IsDefined(player) || !player.IsAttached() || player.IsDead() { return; };
        if !IsDefined(patrol) || patrol.IsDispatchMenuOpen() { return; };
        this.m_poll += delta;
        if this.m_poll >= 1.0 { this.m_poll = 0.0; this.TryPayment(); };
        if this.m_noticeDelay > 0.0 { this.m_noticeDelay -= delta; };
        if this.m_noticeDelay <= 0.0 && ArraySize(this.m_receipts) > 0 {
            this.ShowReceipt(this.m_receipts[0]); ArrayErase(this.m_receipts, 0);
            this.m_noticeDelay = 6.0;
        };
    }
    public func GetRevision() -> Int32 { return this.m_revision; }
    public func GetDiagnostics() -> String {
        let count: Int32 = this.GetCompletedCount();
        let pending: Int32 = this.GetPendingPayments();
        let vip: Int32 = this.GetCompletedVIP();
        let cyber: Int32 = this.GetCompletedCyberpsychos();
        return s"\(this.m_status) | generated incidents=\(count) | VIP=\(vip) | cyberpsychos=\(cyber) | pending payments=\(pending)";
    }
}
