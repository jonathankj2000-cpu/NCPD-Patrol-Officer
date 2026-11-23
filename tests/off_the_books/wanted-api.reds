// Source: core/systems/preventionSystem.swift, pinned in game_reference.json.
// Test-only declarations; never installed in the mod.
public native class ScriptableSystemRequest extends IScriptable {}
public class SetWantedLevel extends ScriptableSystemRequest {
    public let m_wantedLevel: EPreventionHeatStage;
    public let m_forceGreyStars: Bool;
    public let m_resetGreyStars: Bool;
    public let m_forcePlayerPositionAsLastCrimePoint: Bool;
    public let m_forceIgnoreSecurityAreas: Bool;
}
@addMethod(PreventionSystem)
public final static func QueueRequest(context: GameInstance, request: ref<ScriptableSystemRequest>, opt delay: Float) -> Bool { return false; }
