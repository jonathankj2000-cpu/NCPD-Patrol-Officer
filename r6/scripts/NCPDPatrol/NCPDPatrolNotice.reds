// Presentation data only. Notifications never grant money or finish activities.
public class NCPDPatrolNotice extends IScriptable {
    public let text: String;
    public let duration: Float;
    public let money: Bool;
    public let alert: Bool;
    public let voice: Bool;
}

public class NCPDPatrolNoticeFinished extends DelayCallback {
    private let m_system: wref<NCPDPatrolSystem>;
    private let m_session: Int32;
    private let m_token: Int32;

    public func Call() -> Void {
        if IsDefined(this.m_system) { this.m_system.FinishNotice(this.m_session, this.m_token); };
    }

    public static func Create(system: ref<NCPDPatrolSystem>, session: Int32, token: Int32) -> ref<NCPDPatrolNoticeFinished> {
        let callback: ref<NCPDPatrolNoticeFinished> = new NCPDPatrolNoticeFinished();
        callback.m_system = system;
        callback.m_session = session;
        callback.m_token = token;
        return callback;
    }
}
