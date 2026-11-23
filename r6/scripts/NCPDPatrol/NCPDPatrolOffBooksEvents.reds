// Preserve native damage/crime and native readable-shard handling. These
// observers only forward hits on bound private actors and the exact item ID.
@wrapMethod(NPCPuppet)
protected cb func OnHit(evt: ref<gameHitEvent>) -> Bool {
    let result: Bool = wrappedMethod(evt);
    let system: ref<NCPDPatrolOffBooksSystem>;
    if this.GetRecordID() == t"Character.NCPDPatrol_VossContractor01"
        || this.GetRecordID() == t"Character.NCPDPatrol_VossGuard01"
        || this.GetRecordID() == t"Character.NCPDPatrol_VossGuard02" {
        system = GameInstance.GetScriptableSystemsContainer(this.GetGame()).Get(n"NCPDPatrolOffBooksSystem") as NCPDPatrolOffBooksSystem;
        if IsDefined(system) { system.ObserveHit(this, evt); };
    };
    return result;
}

@wrapMethod(PlayerPuppet)
protected cb func OnItemAddedToInventory(evt: ref<ItemAddedEvent>) -> Bool {
    let result: Bool = wrappedMethod(evt);
    let system: ref<NCPDPatrolOffBooksSystem>;
    if IsDefined(evt) && evt.currentQuantity > 0 && ItemID.IsValid(evt.itemID)
        && ItemID.GetTDBID(evt.itemID) == t"Items.NCPDPatrol_VossEvidence01" {
        system = GameInstance.GetScriptableSystemsContainer(this.GetGame()).Get(n"NCPDPatrolOffBooksSystem") as NCPDPatrolOffBooksSystem;
        if IsDefined(system) { system.ObserveEvidence(this, evt.itemID); };
    };
    return result;
}
