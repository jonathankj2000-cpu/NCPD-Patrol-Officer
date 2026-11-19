// Source-derived contracts: NPCPuppet.swift, animCommunication.swift and native
// TeleportationFacility. Offline checks only; never shipped to the game.
@addMethod(NPCPuppet)
public native func IsRagdolling() -> Bool;
@addMethod(NPCPuppet)
public native func IsRagdollEnabled() -> Bool;
@addMethod(NPCPuppet)
public native func SetDisableRagdoll(disableRagdoll: Bool, opt force: Bool, opt leaveRagdollEnabled: Bool) -> Void;
@addMethod(GameObject)
public native func GetWorldOrientation() -> Quaternion;
@addMethod(Entity)
public native func QueueEvent(evt: ref<Event>) -> Void;
@addMethod(GameInstance)
public static native func GetTeleportationFacility(game: GameInstance) -> ref<TeleportationFacility>;
public native struct Quaternion {
 public static native func ToEulerAngles(value: Quaternion) -> EulerAngles;
}
public native struct EulerAngles {}
public native class TeleportationFacility extends IScriptable {
 public native func Teleport(objectToTeleport: ref<GameObject>, position: Vector4, orientation: EulerAngles) -> Void;
}
public native class RagdollDisableEvent extends Event {}
public native class RagdollActivationRequestEvent extends Event {}
public native func CreateDisableRagdollEvent(debugSourceName: CName) -> ref<RagdollDisableEvent>;
public native func CreateForceRagdollNoPowerPoseEvent(debugSourceName: CName) -> ref<RagdollActivationRequestEvent>;
