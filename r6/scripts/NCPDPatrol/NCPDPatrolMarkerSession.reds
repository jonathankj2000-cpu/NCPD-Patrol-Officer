// Codeware session callbacks change only local readiness flags. Native marker
// work is deferred to a later CET update, never run inside restore/detach.
public class NCPDPatrolMarkerSession extends ScriptableService {
    private let m_ready: Bool;
    private let m_generation: Int32;

    protected cb func OnLoad() -> Void {
        this.m_ready = false; this.m_generation = 0;
    }
    protected cb func OnInitialize() -> Void {
        let callbacks: ref<CallbackSystem> = GameInstance.GetCallbackSystem();
        this.m_ready = false;
        if !IsDefined(callbacks) { return; };
        // Explicit lifetime survives reloads; unregister first for idempotence.
        callbacks.UnregisterCallback(n"Session/BeforeStart", this, n"OnUnavailable");
        callbacks.UnregisterCallback(n"Session/BeforeEnd", this, n"OnUnavailable");
        callbacks.UnregisterCallback(n"Session/End", this, n"OnUnavailable");
        callbacks.UnregisterCallback(n"Session/Ready", this, n"OnReady");
        callbacks.RegisterCallback(n"Session/BeforeStart", this, n"OnUnavailable", true);
        callbacks.RegisterCallback(n"Session/BeforeEnd", this, n"OnUnavailable", true);
        callbacks.RegisterCallback(n"Session/End", this, n"OnUnavailable", true);
        callbacks.RegisterCallback(n"Session/Ready", this, n"OnReady", true);
    }
    protected cb func OnUnavailable(event: ref<CallbackSystemEvent>) -> Void {
        if this.m_ready { this.m_generation += 1; }; this.m_ready = false;
    }
    protected cb func OnReady(event: ref<CallbackSystemEvent>) -> Void {
        if !this.m_ready { this.m_generation += 1; }; this.m_ready = true;
    }
    public func IsReady() -> Bool { return this.m_ready; }
    public func GetGeneration() -> Int32 { return this.m_generation; }
    public static func Get() -> ref<NCPDPatrolMarkerSession> {
        return GameInstance.GetScriptableServiceContainer().GetService(n"NCPDPatrolMarkerSession") as NCPDPatrolMarkerSession;
    }
    public static func WorldReady() -> Bool {
        let session: ref<NCPDPatrolMarkerSession> = NCPDPatrolMarkerSession.Get();
        return IsDefined(session) && session.IsReady();
    }
}
