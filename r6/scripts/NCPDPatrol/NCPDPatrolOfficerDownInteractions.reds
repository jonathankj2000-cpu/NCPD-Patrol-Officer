// Scoped to this dispatch's exact injured actor; ordinary bodies and the main
// partner continue through the existing wrappers unchanged.
@wrapMethod(ScriptedPuppet)
protected final func UpdateLootInteraction() -> Void {
    let incident: ref<NCPDPatrolOfficerDownSystem> = NCPDPatrolOfficerDownSystem.Get(this.GetGame());
    if IsDefined(incident) && incident.IsDownOfficer(this) { this.EnableInteraction(n"Loot", true); return; };
    wrappedMethod();
}
@wrapMethod(NPCPuppet)
public final const func CanEnableRagdollComponent(opt fromSetDeathParams: Bool) -> Bool {
    let incident: ref<NCPDPatrolOfficerDownSystem> = NCPDPatrolOfficerDownSystem.Get(this.GetGame());
    if IsDefined(incident) && incident.IsDownOfficer(this) { return true; };
    return wrappedMethod(fromSetDeathParams);
}
@wrapMethod(ScriptedPuppetPS)
public final const func GetValidChoices(const actions: script_ref<[wref<ObjectAction_Record>]>, const context: script_ref<GetActionsContext>, objectActionsCallbackController: wref<gameObjectActionsCallbackController>, checkPlayerQuickHackList: Bool, choices: script_ref<[InteractionChoice]>) -> Void {
    let incident: ref<NCPDPatrolOfficerDownSystem> = NCPDPatrolOfficerDownSystem.Get(this.GetGameInstance());
    let choice: InteractionChoice;
    if IsDefined(incident) && incident.IsDownOfficer(this.GetOwnerEntity()) && Equals(Deref(context).requestType, gamedeviceRequestType.Direct) {
        ArrayClear(Deref(choices));
        if incident.GetStage() == 2 && Equals(Deref(context).interactionLayerTag, n"Loot") {
            choice.choiceMetaData.tweakDBName = "NCPDPatrolOfficerAid";
            choice.choiceMetaData.tweakDBID = t"Interactions.NCPDPatrolOfficerAid";
            choice.caption = GetLocalizedTextByKey(n"NCPDPatrol_OfficerDown_Revive");
            if incident.GetAidState() != 2 {
                choice.choiceMetaData.tweakDBName = "NCPDPatrolOfficerTreating";
                choice.choiceMetaData.tweakDBID = t"Interactions.NCPDPatrolOfficerTreating";
                choice.caption = GetLocalizedTextByKey(n"NCPDPatrol_OfficerDown_Reviving");
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
    let incident: ref<NCPDPatrolOfficerDownSystem> = NCPDPatrolOfficerDownSystem.Get(this.GetGame());
    if IsDefined(incident) && incident.IsDownOfficer(this) {
        if Equals(evt.choice.choiceMetaData.tweakDBName, "NCPDPatrolOfficerAid") { incident.StartRevive(); };
        return true;
    };
    return wrappedMethod(evt);
}
@wrapMethod(ScriptedPuppet)
protected cb func OnInteraction(evt: ref<InteractionChoiceEvent>) -> Bool {
    let incident: ref<NCPDPatrolOfficerDownSystem> = NCPDPatrolOfficerDownSystem.Get(this.GetGame());
    if IsDefined(incident) && incident.IsDownOfficer(this) {
        if Equals(evt.choice.choiceMetaData.tweakDBName, "NCPDPatrolOfficerAid") { incident.StartRevive(); };
        return true;
    };
    return wrappedMethod(evt);
}
