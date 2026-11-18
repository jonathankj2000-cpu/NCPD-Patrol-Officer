// Offline declarations copied from the game's vehicles.swift/vehicleComponent,
// orphans.swift and mounting definitions; these are NEVER installed in game.
public native func GetMountedVehicle(object: ref<GameObject>) -> wref<VehicleObject>;
public native func AbsF(value: Float) -> Float;
public native func MaxF(a: Float, b: Float) -> Float;
public native class Event extends IScriptable {}
public native struct MountingSlotId { public native let id: CName; }
public native struct MountingInfo { public native let slotId: MountingSlotId; }
public native class IMountingFacility extends IScriptable {
 public native func GetMountingInfoSingleWithObjects(child: ref<GameObject>, opt parent: ref<GameObject>, opt slotId: MountingSlotId) -> MountingInfo;
}
@addMethod(GameInstance)
public static native func GetMountingFacility(game: GameInstance) -> ref<IMountingFacility>;
@addMethod(VehicleObject)
public native func GetCurrentSpeed() -> Float;
@addMethod(WheeledObject)
public native func GetFlatTireIndex() -> Int32;
@addMethod(VehicleComponentPS)
public native func ForcePersistentStateChanged() -> Void;
@addMethod(VehicleComponent)
public native func GetPS() -> ref<VehicleComponentPS>;
@addMethod(DelaySystem)
public native func DelayEvent(entity: wref<Entity>, eventToDelay: ref<Event>, delay: Float, opt isAffectedByTimeDilation: Bool) -> DelayID;
public class VehicleToggleBrokenTireEvent extends Event { public let tireIndex: Uint32; public let toggle: Bool; }
public class VehicleFinishedMountingEvent extends Event {}
public class UnmountingEvent extends Event {}
@addMethod(VehicleComponent)
protected cb func OnToggleBrokenTireEvent(evt: ref<VehicleToggleBrokenTireEvent>) -> Bool { return true; }
@addMethod(VehicleComponent)
protected cb func OnVehicleFinishedMountingEvent(evt: ref<VehicleFinishedMountingEvent>) -> Bool { return true; }
@addMethod(VehicleComponent)
protected cb func OnUnmountingEvent(evt: ref<UnmountingEvent>) -> Bool { return true; }
