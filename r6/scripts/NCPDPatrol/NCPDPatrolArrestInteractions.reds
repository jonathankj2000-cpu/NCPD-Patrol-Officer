@addMethod(NPCPuppet)
public func NCPDPatrolRefreshArrestInteraction() -> Void {
    this.DetermineInteractionStateByTask();
    this.UpdateLootInteraction();
}

@wrapMethod(NPCPuppet)
public final const func CanEnableRagdollComponent(opt fromSetDeathParams: Bool) -> Bool {
    let arrests: ref<NCPDPatrolArrestSystem> = NCPDPatrolArrestSystem.Get(this.GetGame());
    if IsDefined(arrests) && arrests.OwnsPosePhysics(this) { return false; };
    return wrappedMethod(fromSetDeathParams);
}

@wrapMethod(ScriptedPuppet)
protected final func UpdateLootInteraction() -> Void {
    let arrest: ref<NCPDPatrolArrestSystem> = NCPDPatrolArrestSystem.Get(this.GetGame());
    let npc: ref<NPCPuppet> = this as NPCPuppet;
    // An eligible suspect need not have any inventory left. The arrest action
    // uses the same body interaction range as the working partner revive.
    if IsDefined(arrest) && arrest.IsDutyEligible() && IsDefined(npc)
        && (arrest.CanStartArrest(npc) || arrest.IsPendingSuspect(npc)) {
        this.EnableInteraction(n"Loot", true);
        return;
    };
    wrappedMethod();
}

@wrapMethod(ScriptedPuppetPS)
public final const func GetValidChoices(const actions: script_ref<[wref<ObjectAction_Record>]>, const context: script_ref<GetActionsContext>, objectActionsCallbackController: wref<gameObjectActionsCallbackController>, checkPlayerQuickHackList: Bool, choices: script_ref<[InteractionChoice]>) -> Void {
    let arrest: ref<NCPDPatrolArrestSystem> = NCPDPatrolArrestSystem.Get(this.GetGameInstance());
    let npc: ref<NPCPuppet> = this.GetOwnerEntity() as NPCPuppet;
    let choice: InteractionChoice;
    let i: Int32;
    wrappedMethod(actions, context, objectActionsCallbackController, checkPlayerQuickHackList, choices);
    if IsDefined(arrest) && IsDefined(npc) && arrest.IsDutyEligible()
        && (arrest.CanStartArrest(npc) || arrest.IsPendingSuspect(npc))
        && Equals(Deref(context).requestType, gamedeviceRequestType.Direct)
        && Equals(Deref(context).interactionLayerTag, n"Loot") {
        // Replace only primary Loot/F. Preserve native secondary choices,
        // including R pickup, so a suspect can be moved before securing.
        // During the short securing/playback request, stale pickup is guarded
        // below; failure restores native choices on the next refresh.
        if arrest.IsPendingSuspect(npc) {
            ArrayClear(Deref(choices));
        } else {
            i = ArraySize(Deref(choices)) - 1;
            while i >= 0 {
                if Equals(Deref(choices)[i].choiceMetaData.tweakDBName, "Loot")
                    || Deref(choices)[i].choiceMetaData.tweakDBID == t"Interactions.Loot" {
                    ArrayErase(Deref(choices), i);
                };
                i = i - 1;
            };
        };
        choice.choiceMetaData.tweakDBName = "NCPDPatrolArrest";
        choice.choiceMetaData.tweakDBID = t"Interactions.NCPDPatrolArrest";
        choice.caption = GetLocalizedTextByKey(n"NCPDPatrol-Arrest");
        if arrest.IsPendingSuspect(npc) {
            choice.choiceMetaData.tweakDBName = "NCPDPatrolArresting";
            choice.choiceMetaData.tweakDBID = t"Interactions.NCPDPatrolArresting";
            choice.caption = GetLocalizedTextByKey(n"NCPDPatrol-Arresting");
            ChoiceTypeWrapper.SetType(choice.choiceMetaData.type, gameinteractionsChoiceType.Inactive);
        };
        InteractionChoiceCaption.AddTextPart(choice.captionParts, choice.caption);
        ArrayInsert(Deref(choices), 0, choice);
        return;
    };
}

@wrapMethod(ScriptedPuppet)
protected cb func OnInteractionUsed(evt: ref<InteractionChoiceEvent>) -> Bool {
    let arrest: ref<NCPDPatrolArrestSystem> = NCPDPatrolArrestSystem.Get(this.GetGame());
    if Equals(evt.choice.choiceMetaData.tweakDBName, "NCPDPatrolArrest") {
        if IsDefined(arrest) { arrest.StartArrest(this as NPCPuppet); };
        return true;
    };
    if IsDefined(arrest) && arrest.IsPendingSuspect(this) { return true; };
    return wrappedMethod(evt);
}

@wrapMethod(ScriptedPuppet)
protected cb func OnInteraction(choiceEvent: ref<InteractionChoiceEvent>) -> Bool {
    let arrest: ref<NCPDPatrolArrestSystem> = NCPDPatrolArrestSystem.Get(this.GetGame());
    if Equals(choiceEvent.choice.choiceMetaData.tweakDBName, "NCPDPatrolArrest") {
        if IsDefined(arrest) { arrest.StartArrest(this as NPCPuppet); };
        return true;
    };
    if IsDefined(arrest) && arrest.IsPendingSuspect(this) { return true; };
    return wrappedMethod(choiceEvent);
}
