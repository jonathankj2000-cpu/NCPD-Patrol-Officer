// Both deferred sending and later observation are bound to the current request.
public class NCPDPatrolRadioStep extends DelayCallback {
    private let m_system: wref<NCPDPatrolSystem>;
    private let m_session: Int32;
    private let m_token: Int32;
    private let m_step: Int32;

    public func Call() -> Void {
        if IsDefined(this.m_system) {
            this.m_system.AdvanceRadioStep(this.m_session, this.m_token, this.m_step);
        };
    }

    public static func Create(system: ref<NCPDPatrolSystem>, session: Int32, token: Int32, step: Int32) -> ref<NCPDPatrolRadioStep> {
        let callback: ref<NCPDPatrolRadioStep> = new NCPDPatrolRadioStep();
        callback.m_system = system;
        callback.m_session = session;
        callback.m_token = token;
        callback.m_step = step;
        return callback;
    }
}
