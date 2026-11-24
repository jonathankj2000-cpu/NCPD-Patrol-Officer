// Recovery stub for the rejected duration experiment. Keeping its class/path
// allows an ordinary overwrite to disable the old service without deleting
// any production files. A full game restart restores the stock report.
public class NCPDPatrolVossLengthTest extends ScriptableService {
    protected cb func OnLoad() -> Void {
        let callbacks: ref<CallbackSystem> = GameInstance.GetCallbackSystem();
        if IsDefined(callbacks) {
            callbacks.UnregisterCallback(n"Resource/PostLoad", this, n"OnLengthsLoaded");
        };
    }

    public func GetDiagnostics() -> String {
        return "Voss VO lengths | disabled=true | No duration metadata registered; original v0.20f1 playback restored after restart";
    }
}
