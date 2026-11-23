// Keep the corporate actor and its native inventory/loot UI. Inventory quantity
// alone does not enable Loot or initialise an invalid loot-quality cache.
@addMethod(ScriptedPuppet)
public final func NCPDPatrolOffBooksRefreshLoot() -> Bool {
    let access: ref<SetLootInteractionAccessibilityEvent>;
    if this.GetRecordID() != t"Character.NCPDPatrol_VossContractor01" || !this.IsDead()
        || !IsDefined(this.m_inventoryComponent) || !IsDefined(this.m_interactionComponent)
        || !this.m_interactionComponent.isEnabled { return false; };
    if !this.m_inventoryComponent.IsAccessible() {
        access = new SetLootInteractionAccessibilityEvent();
        access.accessible = true;
        this.QueueEvent(access);
    };
    // Requests are asynchronous: the owner retries with readback, not success
    // inferred from QueueEvent. Do not transfer anything to the player here.
    this.EvaluateLootQualityEvent();
    this.UpdateLootInteraction();
    this.DetermineInteractionStateByTask();
    return true;
}

@addMethod(ScriptedPuppet)
public final func NCPDPatrolOffBooksLootReady() -> Bool {
    return IsDefined(this.m_inventoryComponent) && this.m_inventoryComponent.IsAccessible()
        && IsDefined(this.m_interactionComponent) && this.m_interactionComponent.isEnabled && this.IsContainer();
}

@addMethod(ScriptedPuppet)
public final func NCPDPatrolOffBooksLootDiagnostics() -> String {
    let layers: array<gameinteractionsActiveLayerData>;
    let i: Int32 = 0;
    let active: Bool = false;
    let inventory: Bool = IsDefined(this.m_inventoryComponent);
    let interaction: Bool = IsDefined(this.m_interactionComponent);
    let accessible: Bool;
    let enabled: Bool;
    let availability: String = "unavailable (native prerequisites missing)";
    if inventory { accessible = this.m_inventoryComponent.IsAccessible(); };
    if interaction {
        enabled = this.m_interactionComponent.isEnabled;
        this.m_interactionComponent.GetActiveInputLayers(layers);
        while i < ArraySize(layers) {
            if Equals(layers[i].layerName, n"Loot") && layers[i].activator == GetPlayer(this.GetGame()) { active = true; };
            i += 1;
        };
    };
    if this.IsDead() && this.NCPDPatrolOffBooksLootReady() {
        availability = "not observed (native prerequisites ready; approach/look at body)";
    };
    if active { availability = "available (native Loot input layer active for V)"; };
    return s"corpse loot=\(availability) | Inventory component=\(inventory) | inventory accessible=\(accessible) | Interaction component=\(interaction) | interaction enabled=\(enabled) | native container=\(this.IsContainer()) | Loot layer active=\(active)";
}
