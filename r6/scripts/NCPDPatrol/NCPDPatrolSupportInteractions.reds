public class NCPDPatrolBackupAction extends ActionBool {
    public func SetProperties() -> Void {
        this.actionName = n"NCPDPatrolBackupAction";
        this.prop = DeviceActionPropertyFunctions.SetUpProperty_Bool(this.actionName, false, n"NCPDPatrol-Backup", n"NCPDPatrol-Backup");
        this.CreateActionWidgetPackage();
        this.CreateInteraction();
        this.interactionChoice.caption = GetLocalizedTextByKey(n"NCPDPatrol-Backup");
        InteractionChoiceCaption.Clear(this.interactionChoice.captionParts);
        InteractionChoiceCaption.AddTextPart(this.interactionChoice.captionParts, this.interactionChoice.caption);
    }
    public func GetTweakDBChoiceRecord() -> String { return "NCPDPatrolBackup"; }
}

@addMethod(VehicleComponentPS)
private func NCPDPatrolAddBackupAction(actions: script_ref<[ref<DeviceAction>]>) -> Void {
    let support: ref<NCPDPatrolSupportSystem> = NCPDPatrolSupportSystem.Get(this.GetGameInstance());
    let action: ref<NCPDPatrolBackupAction>;
    let i: Int32 = 0;
    if !IsDefined(support) || !support.CanUseTrunk(this.GetOwnerEntity()) { return; };
    while i < ArraySize(Deref(actions)) {
        if IsDefined(Deref(actions)[i] as NCPDPatrolBackupAction) { return; };
        i += 1;
    };
    action = new NCPDPatrolBackupAction();
    action.clearanceLevel = 2;
    action.SetUp(this);
    action.SetProperties();
    action.AddDeviceName(this.GetDeviceName());
    ArrayPush(Deref(actions), action);
}

@wrapMethod(VehicleComponentPS)
public final func GetTrunkActions(actions: script_ref<[ref<DeviceAction>]>, const context: script_ref<VehicleActionsContext>) -> Void {
    wrappedMethod(actions, context);
    // The vanilla stash choice must remain available beside this new action.
    if this.GetOwnerEntity().MatchVisualTag(n"NoTrunk") || this.GetOwnerEntity().IsCrowdVehicle() || this.GetIsDestroyed() { return; };
    this.NCPDPatrolAddBackupAction(actions);
}

@wrapMethod(VehicleComponentPS)
public final func GetPlayerTrunkActions(actions: script_ref<[ref<DeviceAction>]>, const context: script_ref<VehicleActionsContext>) -> Void {
    wrappedMethod(actions, context);
    if this.GetIsDestroyed() { return; };
    this.NCPDPatrolAddBackupAction(actions);
}

@addMethod(VehicleComponentPS)
public final func OnNCPDPatrolBackupAction(evt: ref<NCPDPatrolBackupAction>) -> EntityNotificationType {
    let support: ref<NCPDPatrolSupportSystem> = NCPDPatrolSupportSystem.Get(this.GetGameInstance());
    if IsDefined(support) { support.RequestBackupAtTrunk(this.GetOwnerEntity()); };
    return EntityNotificationType.SendThisEventToEntity;
}

@addMethod(VehicleComponent)
protected cb func OnNCPDPatrolBackupAction(evt: ref<NCPDPatrolBackupAction>) -> Bool {
    this.EvaluateTrunkInteractions();
    return true;
}

@addMethod(NPCPuppet)
public func NCPDPatrolRefreshAidInteraction() -> Void {
    this.DetermineInteractionStateByTask();
    this.UpdateLootInteraction();
}

@wrapMethod(ScriptedPuppet)
protected final func UpdateLootInteraction() -> Void {
    let support: ref<NCPDPatrolSupportSystem> = NCPDPatrolSupportSystem.Get(this.GetGame());
    // A companion's inventory may be inaccessible. Aid uses the existing body
    // interaction range without requiring that its inventory can be looted.
    if IsDefined(support) && support.IsDownPartner(this) {
        this.EnableInteraction(n"Loot", true);
        return;
    };
    wrappedMethod();
}

@wrapMethod(NPCPuppet)
public final const func CanEnableRagdollComponent(opt fromSetDeathParams: Bool) -> Bool {
    let support: ref<NCPDPatrolSupportSystem> = NCPDPatrolSupportSystem.Get(this.GetGame());
    // Allow the downed pose for our protected partner, despite its god-mode flags.
    if IsDefined(support) && support.IsDownPartner(this) { return true; };
    return wrappedMethod(fromSetDeathParams);
}

@wrapMethod(ScriptedPuppetPS)
public final const func GetValidChoices(const actions: script_ref<[wref<ObjectAction_Record>]>, const context: script_ref<GetActionsContext>, objectActionsCallbackController: wref<gameObjectActionsCallbackController>, checkPlayerQuickHackList: Bool, choices: script_ref<[InteractionChoice]>) -> Void {
    let support: ref<NCPDPatrolSupportSystem> = NCPDPatrolSupportSystem.Get(this.GetGameInstance());
    let choice: InteractionChoice;
    if IsDefined(support) && support.IsDownPartner(this.GetOwnerEntity()) && Equals(Deref(context).requestType, gamedeviceRequestType.Direct) {
        // Replace our partner's body/loot choices; all other NPCs use vanilla.
        ArrayClear(Deref(choices));
        if Equals(Deref(context).interactionLayerTag, n"Loot") {
            choice.choiceMetaData.tweakDBName = "NCPDPatrolRevive";
            choice.choiceMetaData.tweakDBID = t"Interactions.NCPDPatrolRevive";
            choice.caption = GetLocalizedTextByKey(n"NCPDPatrol-Revive");
            if support.GetPartnerState() == 3 {
                choice.choiceMetaData.tweakDBName = "NCPDPatrolReviving";
                choice.choiceMetaData.tweakDBID = t"Interactions.NCPDPatrolReviving";
                choice.caption = GetLocalizedTextByKey(n"NCPDPatrol-Reviving");
                ChoiceTypeWrapper.SetType(choice.choiceMetaData.type, gameinteractionsChoiceType.Inactive);
            };
            InteractionChoiceCaption.AddTextPart(choice.captionParts, choice.caption);
            ArrayPush(Deref(choices), choice);
        };
        return;
    };
    wrappedMethod(actions, context, objectActionsCallbackController, checkPlayerQuickHackList, choices);
}

@wrapMethod(ScriptedPuppet)
protected cb func OnInteractionUsed(evt: ref<InteractionChoiceEvent>) -> Bool {
    let support: ref<NCPDPatrolSupportSystem> = NCPDPatrolSupportSystem.Get(this.GetGame());
    if IsDefined(support) && support.IsDownPartner(this) {
        if Equals(evt.choice.choiceMetaData.tweakDBName, "NCPDPatrolRevive") { support.StartPartnerRevive(); };
        return true;
    };
    return wrappedMethod(evt);
}

@wrapMethod(ScriptedPuppet)
protected cb func OnInteraction(choiceEvent: ref<InteractionChoiceEvent>) -> Bool {
    let support: ref<NCPDPatrolSupportSystem> = NCPDPatrolSupportSystem.Get(this.GetGame());
    if IsDefined(support) && support.IsDownPartner(this) {
        if Equals(choiceEvent.choice.choiceMetaData.tweakDBName, "NCPDPatrolRevive") { support.StartPartnerRevive(); };
        return true;
    };
    return wrappedMethod(choiceEvent);
}
