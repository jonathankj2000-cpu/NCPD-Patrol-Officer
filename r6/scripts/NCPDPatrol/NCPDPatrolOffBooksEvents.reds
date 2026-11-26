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
    let result: Bool;
    let item: ItemID;
    let quantity: Int32;
    let evidence: Bool;
    let system: ref<NCPDPatrolOffBooksSystem>;
    // Preserve the incoming identity before native readable auto-consumption.
    // currentQuantity is not a durable ownership test for a readable shard.
    if IsDefined(evt) && ItemID.IsValid(evt.itemID)
        && ItemID.GetTDBID(evt.itemID) == t"Items.NCPDPatrol_VossEvidence01" {
        item = evt.itemID; quantity = evt.currentQuantity; evidence = true;
    };
    result = wrappedMethod(evt);
    if evidence {
        system = GameInstance.GetScriptableSystemsContainer(this.GetGame()).Get(n"NCPDPatrolOffBooksSystem") as NCPDPatrolOffBooksSystem;
        if IsDefined(system) { system.ObserveEvidence(this, item, quantity); };
    };
    return result;
}

@wrapMethod(ReadAction)
public func CompleteAction(gameInstance: GameInstance) -> Void {
    let data: wref<gameItemData> = this.GetItemData();
    let player: ref<PlayerPuppet> = this.GetExecutor() as PlayerPuppet;
    let item: ItemID;
    let evidence: Bool;
    let system: ref<NCPDPatrolOffBooksSystem>;
    if IsDefined(data) && ItemID.IsValid(data.GetID())
        && ItemID.GetTDBID(data.GetID()) == t"Items.NCPDPatrol_VossEvidence01" {
        item = data.GetID(); evidence = true;
    };
    wrappedMethod(gameInstance);
    // Reading directly from loot need not leave an item in V's backpack.
    if evidence && IsDefined(player) && player == GetPlayer(gameInstance) {
        system = GameInstance.GetScriptableSystemsContainer(gameInstance).Get(n"NCPDPatrolOffBooksSystem") as NCPDPatrolOffBooksSystem;
        if IsDefined(system) { system.ObserveEvidenceRead(player, item); };
    };
}
