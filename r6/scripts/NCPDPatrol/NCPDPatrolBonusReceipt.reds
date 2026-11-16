// A receipt displays already-paid money; this callback never grants money.
public class NCPDPatrolBonusReceipt extends DelayCallback {
    private let m_system: wref<NCPDPatrolSystem>;
    private let m_amount: Int32;
    private let m_session: Int32;

    public func Call() -> Void {
        if IsDefined(this.m_system) {
            this.m_system.ShowBonusReceipt(this.m_amount, this.m_session);
        };
    }

    public static func Create(system: ref<NCPDPatrolSystem>, amount: Int32, session: Int32) -> ref<NCPDPatrolBonusReceipt> {
        let callback: ref<NCPDPatrolBonusReceipt> = new NCPDPatrolBonusReceipt();
        callback.m_system = system;
        callback.m_amount = amount;
        callback.m_session = session;
        return callback;
    }
}
