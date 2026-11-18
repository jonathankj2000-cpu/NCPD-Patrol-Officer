@addMethod(VehicleComponent)
public func NCPDPatrolRefreshTrunk() -> Void {
    this.DetermineInteractionState();
    this.EvaluateTrunkInteractions();
}

@addMethod(VehicleComponent)
public func NCPDPatrolRepairVehicle() -> Void {
    let vehicle: ref<VehicleObject> = this.GetVehicle();
    if !IsDefined(vehicle) || !vehicle.IsAttached() || vehicle.IsDestroyed() { return; };
    // Use the game's repair routine plus its visual deformation/tyre resets.
    this.RepairVehicle();
    this.m_damageLevel = 0;
    this.m_bumperFrontState = 0;
    this.m_bumperBackState = 0;
    AnimationControllerComponent.SetInputFloat(vehicle, n"hood_destruction", 0.0);
    AnimationControllerComponent.SetInputFloat(vehicle, n"wheel_f_l_destruction", 0.0);
    AnimationControllerComponent.SetInputFloat(vehicle, n"wheel_f_r_destruction", 0.0);
    AnimationControllerComponent.SetInputFloat(vehicle, n"bumper_b_destruction", 0.0);
    AnimationControllerComponent.SetInputFloat(vehicle, n"bumper_f_destruction", 0.0);
    AnimationControllerComponent.SetInputFloat(vehicle, n"door_f_l_destruction", 0.0);
    AnimationControllerComponent.SetInputFloat(vehicle, n"door_f_r_destruction", 0.0);
    AnimationControllerComponent.SetInputFloat(vehicle, n"trunk_destruction", 0.0);
    AnimationControllerComponent.SetInputFloat(vehicle, n"bumper_b_destruction_side_2", 0.0);
    AnimationControllerComponent.SetInputFloat(vehicle, n"bumper_f_destruction_side_2", 0.0);
    vehicle.DestructionResetGrid();
    vehicle.DestructionResetGlass();
    this.UpdateDamageEngineEffects();
    this.VehicleVisualDestructionSetup();
    // A parked vehicle can recreate wheel physics on the next mount. Keep a
    // repair receipt, reapply after activation, and invalidate it on a NEW hit.
    this.m_ncpdTyreRepairGeneration += 1;
    this.m_ncpdTyreRepairArmed = true;
    this.NCPDPatrolRepairTyres();
    this.NCPDPatrolScheduleTyres(4);
}

public class NCPDPatrolTyreRepairEvent extends Event {
    public let generation: Int32;
    public let remaining: Int32;
}

@addField(VehicleComponent)
private let m_ncpdTyreRepairArmed: Bool;
@addField(VehicleComponent)
private let m_ncpdTyreRepairGeneration: Int32;

@addMethod(VehicleComponent)
private func NCPDPatrolRepairTyres() -> Void {
    let vehicle: ref<VehicleObject> = this.GetVehicle();
    let wheeled: ref<WheeledObject> = vehicle as WheeledObject;
    let i: Int32 = 0;
    let flat: Int32;
    if !IsDefined(wheeled) || !vehicle.IsAttached() || vehicle.IsDestroyed() { return; };
    flat = wheeled.GetFlatTireIndex();
    // Reset after the body/visual repair, then again after physics wakes up.
    while i < 4 { wheeled.ToggleBrokenTire(Cast<Uint32>(i), false); i += 1; };
    if flat >= 4 && flat < 16 { wheeled.ToggleBrokenTire(Cast<Uint32>(flat), false); };
    this.GetPS().ForcePersistentStateChanged();
}

@addMethod(VehicleComponent)
private func NCPDPatrolScheduleTyres(remaining: Int32) -> Void {
    let vehicle: ref<VehicleObject> = this.GetVehicle();
    let evt: ref<NCPDPatrolTyreRepairEvent>;
    if !this.m_ncpdTyreRepairArmed || remaining <= 0 || !IsDefined(vehicle) { return; };
    evt = new NCPDPatrolTyreRepairEvent();
    evt.generation = this.m_ncpdTyreRepairGeneration; evt.remaining = remaining;
    GameInstance.GetDelaySystem(vehicle.GetGame()).DelayEvent(vehicle, evt, 0.50);
}

@addMethod(VehicleComponent)
protected cb func OnNCPDPatrolTyreRepairEvent(evt: ref<NCPDPatrolTyreRepairEvent>) -> Bool {
    if this.m_ncpdTyreRepairArmed && evt.generation == this.m_ncpdTyreRepairGeneration {
        this.NCPDPatrolRepairTyres();
        this.NCPDPatrolScheduleTyres(evt.remaining - 1);
    };
    return true;
}

@wrapMethod(VehicleComponent)
protected cb func OnToggleBrokenTireEvent(evt: ref<VehicleToggleBrokenTireEvent>) -> Bool {
    // Fresh damage must stay damage; repair must never make tyres invulnerable.
    if evt.toggle {
        this.m_ncpdTyreRepairArmed = false;
        this.m_ncpdTyreRepairGeneration += 1;
    };
    return wrappedMethod(evt);
}

@wrapMethod(VehicleComponent)
protected cb func OnVehicleFinishedMountingEvent(evt: ref<VehicleFinishedMountingEvent>) -> Bool {
    let result: Bool = wrappedMethod(evt);
    this.NCPDPatrolScheduleTyres(4);
    return result;
}

@wrapMethod(VehicleComponent)
protected cb func OnUnmountingEvent(evt: ref<UnmountingEvent>) -> Bool {
    let result: Bool = wrappedMethod(evt);
    this.NCPDPatrolScheduleTyres(4);
    return result;
}
