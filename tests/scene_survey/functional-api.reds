// Offline contracts only. MOD_Development_Reference 81d996b, decompiled
// cyberpunk/ai/aiNavigationSystem.swift:10 and NavigationPath native metadata.
public native class NavigationCostModCircle extends IScriptable {}
public native class NavigationPath extends IScriptable {
 public let path: array<Vector4>;
}
public native class AINavigationSystem extends IScriptable {
 public native func CalculatePathForCharacter(startPoint: Vector4, endPoint: Vector4, findPointTolerance: Float, owner: ref<Entity>, opt costModCircle: ref<NavigationCostModCircle>) -> ref<NavigationPath>;
 public native func FindPointInSphereForCharacter(center: Vector4, radius: Float, owner: ref<Entity>) -> NavigationFindPointResult;
}
public enum worldNavigationRequestStatus { OK = 0, Failed = 1 }
public native struct NavigationFindPointResult { public let point: Vector4; public let status: worldNavigationRequestStatus; }
@addMethod(GameInstance)
public static native func GetAINavigationSystem(game: GameInstance) -> ref<AINavigationSystem>;
