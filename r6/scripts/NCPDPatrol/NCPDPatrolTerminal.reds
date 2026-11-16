// Add one ordinary interaction beside the existing Fast Travel action.
public class NCPDPatrolShiftAction extends ActionBool {
    public let endShift: Bool;

    public func SetProperties(active: Bool) -> Void {
        this.endShift = active;
        this.actionName = n"NCPDPatrolShiftAction";
        this.prop = DeviceActionPropertyFunctions.SetUpProperty_Bool(this.actionName, active, n"NCPDPatrol-StartShift", n"NCPDPatrol-EndShift");
        this.CreateActionWidgetPackage();
        this.CreateInteraction();
        this.interactionChoice.caption = GetLocalizedTextByKey(active ? n"NCPDPatrol-EndShift" : n"NCPDPatrol-StartShift");
        InteractionChoiceCaption.Clear(this.interactionChoice.captionParts);
        InteractionChoiceCaption.AddTextPart(this.interactionChoice.captionParts, this.interactionChoice.caption);
    }

    public func GetTweakDBChoiceRecord() -> String {
        return this.endShift ? "NCPDPatrolEndShift" : "NCPDPatrolStartShift";
    }
}

@wrapMethod(DataTermControllerPS)
public func GetActions(out actions: array<ref<DeviceAction>>, context: GetActionsContext) -> Bool {
    let result: Bool = wrappedMethod(actions, context);
    let system: ref<NCPDPatrolSystem>;
    let action: ref<NCPDPatrolShiftAction>;
    let hasFastTravel: Bool = false;
    let i: Int32 = 0;
    if !result || NotEquals(context.requestType, gamedeviceRequestType.Direct) { return result; }
    if this.IsDisabled() || this.IsUnpowered() { return result; }
    if Equals(this.GetFastravelDeviceType(), EFastTravelDeviceType.SubwayGate) { return result; }
    // Respect vanilla availability and other mods that remove Fast Travel.
    while i < ArraySize(actions) {
        if IsDefined(actions[i] as OpenWorldMapDeviceAction) { hasFastTravel = true; }
        if IsDefined(actions[i] as NCPDPatrolShiftAction) { return result; }
        i += 1;
    };
    if !hasFastTravel { return result; }
    system = NCPDPatrolSystem.Get(this.GetGameInstance());
    if !IsDefined(system) { return result; }
    action = new NCPDPatrolShiftAction();
    action.SetUp(this);
    action.SetProperties(system.GetTerminalDutyState());
    action.AddDeviceName(this.m_deviceName);
    ArrayPush(actions, action);
    return result;
}

@addMethod(DataTermControllerPS)
public func OnNCPDPatrolShiftAction(evt: ref<NCPDPatrolShiftAction>) -> EntityNotificationType {
    let system: ref<NCPDPatrolSystem>;
    let notifier: ref<ActionNotifier>;
    if this.IsDisabled() || this.IsUnpowered() { return EntityNotificationType.DoNotNotifyEntity; }
    system = NCPDPatrolSystem.Get(this.GetGameInstance());
    if IsDefined(system) { system.RequestDuty(evt.endShift); }
    notifier = new ActionNotifier();
    notifier.SetNone();
    this.Notify(notifier, evt);
    return EntityNotificationType.SendThisEventToEntity;
}

@addMethod(DataTerm)
protected cb func OnNCPDPatrolShiftAction(evt: ref<NCPDPatrolShiftAction>) -> Bool {
    this.DetermineInteractionStateByTask();
    return true;
}
