// The voice window owns no audio or vehicle ID. Expiry only allows the controller
// to resume ambient chatter if the player is still on duty in an eligible car.
public class NCPDPatrolVoiceWindow extends DelayCallback {
    private let m_system: wref<NCPDPatrolSystem>;
    private let m_session: Int32;
    private let m_token: Int32;

    public func Call() -> Void {
        if IsDefined(this.m_system) {
            this.m_system.EndDispatchVoiceWindow(this.m_session, this.m_token);
        };
    }

    public static func Create(system: ref<NCPDPatrolSystem>, session: Int32, token: Int32) -> ref<NCPDPatrolVoiceWindow> {
        let callback: ref<NCPDPatrolVoiceWindow> = new NCPDPatrolVoiceWindow();
        callback.m_system = system;
        callback.m_session = session;
        callback.m_token = token;
        return callback;
    }
}
