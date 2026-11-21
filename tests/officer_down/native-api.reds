// Source-derived offline contracts, never installed. MOD_Development_Reference
// 81d996b: gameObject.swift, orphans.swift AttitudeAgent/EAIAttitude, and
// core/components/targetTrackingComponent.swift:166.
public enum EAIAttitude { AIA_Friendly = 0, AIA_Neutral = 1, AIA_Hostile = 2 }
// entEntity.Dispose native signature; Codeware Entity.hpp/StaticEntitySystem
// uses the same engine teardown entrypoint. Never included in the install.
@addMethod(Entity)
public final native func Dispose() -> Void;
public native class AttitudeAgent extends IScriptable {
 public native func SetAttitudeGroup(group: CName) -> Void;
 public native func SetAttitudeTowards(other: ref<AttitudeAgent>, attitude: EAIAttitude) -> Void;
}
@addMethod(GameObject)
public native func GetAttitudeAgent() -> ref<AttitudeAgent>;
public native class TargetTrackingExtension extends IScriptable {
 public static native func InjectThreat(puppet: wref<ScriptedPuppet>, threat: wref<Entity>) -> Void;
}
