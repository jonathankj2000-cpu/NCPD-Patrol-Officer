@addMethod(VehicleComponent)
public func NCPDPatrolRefreshTrunk() -> Void {
    this.DetermineInteractionState();
    this.EvaluateTrunkInteractions();
}

@addMethod(VehicleComponent)
public func NCPDPatrolRepairVehicle() -> Void {
    let vehicle: ref<VehicleObject> = this.GetVehicle();
    let wheeled: ref<WheeledObject> = vehicle as WheeledObject;
    let i: Int32 = 0;
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
    if IsDefined(wheeled) {
        while i < 4 { wheeled.ToggleBrokenTire(Cast<Uint32>(i), false); i += 1; };
    };
    vehicle.DestructionResetGrid();
    vehicle.DestructionResetGlass();
    this.UpdateDamageEngineEffects();
    this.VehicleVisualDestructionSetup();
}
