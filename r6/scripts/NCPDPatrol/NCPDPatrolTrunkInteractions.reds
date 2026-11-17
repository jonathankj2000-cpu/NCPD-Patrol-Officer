public class NCPDPatrolTrunkMenuAction extends ActionBool {
    private let m_command: Int32;
    private let m_busy: Bool;

    public func Initialize(command: Int32, busy: Bool) -> Void {
        this.m_command = command;
        this.m_busy = busy;
        this.SetProperties();
    }
    public func GetCommand() -> Int32 { return this.m_command; }
    private func CaptionKey() -> CName {
        if this.m_command == 1 {
            if this.m_busy { return n"NCPDPatrol-Available"; };
            return n"NCPDPatrol-Busy";
        };
        if this.m_command == 2 { return n"NCPDPatrol-Repair"; };
        if this.m_command == 3 { return n"NCPDPatrol-NewPartner"; };
        if this.m_command == 4 { return n"NCPDPatrol-CancelDispatch"; };
        if this.m_command == 5 { return n"NCPDPatrol-NewDispatch"; };
        if this.m_command == 6 { return n"NCPDPatrol-CopStats"; };
        return n"NCPDPatrol-CloseMenu";
    }
    public func SetProperties() -> Void {
        let key: CName = this.CaptionKey();
        this.actionName = StringToName(this.GetTweakDBChoiceRecord());
        this.prop = DeviceActionPropertyFunctions.SetUpProperty_Bool(this.actionName, false, key, key);
        this.CreateActionWidgetPackage();
        this.CreateInteraction();
        this.interactionChoice.caption = GetLocalizedTextByKey(key);
        InteractionChoiceCaption.Clear(this.interactionChoice.captionParts);
        InteractionChoiceCaption.AddTextPart(this.interactionChoice.captionParts, this.interactionChoice.caption);
    }
    public func GetTweakDBChoiceRecord() -> String {
        if this.m_command == 1 {
            if this.m_busy { return "NCPDPatrolAvailable"; };
            return "NCPDPatrolBusy";
        };
        if this.m_command == 2 { return "NCPDPatrolRepair"; };
        if this.m_command == 3 { return "NCPDPatrolNewPartner"; };
        if this.m_command == 4 { return "NCPDPatrolCancelDispatch"; };
        if this.m_command == 5 { return "NCPDPatrolNewDispatch"; };
        if this.m_command == 6 { return "NCPDPatrolCopStats"; };
        return "NCPDPatrolCloseMenu";
    }
}

@addMethod(VehicleComponentPS)
private func NCPDPatrolAddTrunkMenu(actions: script_ref<[ref<DeviceAction>]>) -> Bool {
    let trunk: ref<NCPDPatrolTrunkSystem> = NCPDPatrolTrunkSystem.Get(this.GetGameInstance());
    let action: ref<NCPDPatrolTrunkMenuAction>;
    let command: Int32 = 1;
    if !IsDefined(trunk) || !trunk.IsOpenFor(this.GetOwnerEntity()) { return false; };
    // The native interaction list provides scrolling and the player's F binding.
    // Closing restores the original stash and backup actions immediately.
    ArrayClear(Deref(actions));
    while command <= 7 {
        action = new NCPDPatrolTrunkMenuAction();
        action.clearanceLevel = 2;
        action.SetUp(this);
        if command == 7 { action.Initialize(0, trunk.IsBusy()); }
        else { action.Initialize(command, trunk.IsBusy()); };
        action.AddDeviceName(this.GetDeviceName());
        ArrayPush(Deref(actions), action);
        command += 1;
    };
    return true;
}

@addMethod(VehicleComponentPS)
public final func OnNCPDPatrolTrunkMenuAction(evt: ref<NCPDPatrolTrunkMenuAction>) -> EntityNotificationType {
    let trunk: ref<NCPDPatrolTrunkSystem> = NCPDPatrolTrunkSystem.Get(this.GetGameInstance());
    if IsDefined(trunk) { trunk.Select(evt.GetCommand(), this.GetOwnerEntity()); };
    return EntityNotificationType.SendThisEventToEntity;
}

@addMethod(VehicleComponent)
protected cb func OnNCPDPatrolTrunkMenuAction(evt: ref<NCPDPatrolTrunkMenuAction>) -> Bool {
    this.NCPDPatrolRefreshTrunk();
    return true;
}
