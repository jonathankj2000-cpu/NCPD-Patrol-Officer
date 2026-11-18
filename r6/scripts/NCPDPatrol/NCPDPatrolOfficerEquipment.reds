// Native equipment fallback for this mod's explicitly tagged, dynamic officers.
// Uses their existing inventory; never creates, removes or drops inventory items.
public class NCPDPatrolOfficerEquipment extends ScriptableSystem {
    public static func Get(game: GameInstance) -> ref<NCPDPatrolOfficerEquipment> {
        return GameInstance.GetScriptableSystemsContainer(game).Get(n"NCPDPatrolOfficerEquipment") as NCPDPatrolOfficerEquipment;
    }
    public func Version() -> Int32 { return 1; }

    private func IsOurs(actor: ref<NPCPuppet>) -> Bool {
        let entities: ref<DynamicEntitySystem> = GameInstance.GetDynamicEntitySystem();
        return IsDefined(actor) && actor.IsAttached() && IsDefined(entities)
            && entities.IsManaged(actor.GetEntityID()) && entities.IsTagged(actor.GetEntityID(), n"NCPDPatrolOfficer");
    }
    // 0: native AI owns equipment; 1: draw assistance only; 2: calm draw/holster.
    public func Mode(actor: ref<NPCPuppet>) -> Int32 {
        let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
        let patrol: ref<NCPDPatrolSystem> = NCPDPatrolSystem.Get(this.GetGameInstance());
        let high: gamedataNPCHighLevelState;
        if !this.IsOurs(actor) || !IsDefined(player) || !IsDefined(patrol)
            || !patrol.IsOnDuty() || patrol.HasWantedLevel() || patrol.IsDispatchMenuOpen()
            || !ScriptedPuppet.IsActive(actor) || actor.IsDead() || actor.IsDeadNoStatPool()
            || ScriptedPuppet.IsDefeated(actor) || ScriptedPuppet.IsUnconscious(actor)
            || IsDefined(GetMountedVehicle(actor)) || IsDefined(GetMountedVehicle(player)) || player.IsInCombat() { return 0; };
        high = actor.GetHighLevelStateFromBlackboard();
        if Equals(high, gamedataNPCHighLevelState.Relaxed) { return 2; };
        if Equals(high, gamedataNPCHighLevelState.Alerted) { return 1; };
        return 0;
    }
    public func IsReady(actor: ref<ScriptedPuppet>) -> Bool {
        let weapon: ref<WeaponObject>;
        let transaction: ref<TransactionSystem> = GameInstance.GetTransactionSystem(this.GetGameInstance());
        if !IsDefined(actor) { return false; };
        weapon = transaction.GetItemInSlot(actor, t"AttachmentSlots.WeaponRight") as WeaponObject;
        if IsDefined(weapon) && !WeaponObject.IsFists(weapon.GetItemID()) { return true; };
        weapon = transaction.GetItemInSlot(actor, t"AttachmentSlots.WeaponLeft") as WeaponObject;
        return IsDefined(weapon) && !WeaponObject.IsFists(weapon.GetItemID());
    }
    public func WantsReady() -> Bool { return this.IsReady(GetPlayer(this.GetGameInstance())); }

    private func CollectHand(actor: ref<NPCPuppet>, slot: TweakDBID, items: script_ref<[NPCItemToEquip]>) -> Void {
        let weapon: ref<WeaponObject> = GameInstance.GetTransactionSystem(this.GetGameInstance()).GetItemInSlot(actor, slot) as WeaponObject;
        let item: NPCItemToEquip;
        let bodySlot: TweakDBID;
        if !IsDefined(weapon) || WeaponObject.IsFists(weapon.GetItemID()) { return; };
        item.itemID = weapon.GetItemID();
        item.slotID = slot;
        AIActionTransactionSystem.GetItemsBodySlot(actor, item.itemID, bodySlot);
        item.bodySlotID = bodySlot;
        ArrayPush(Deref(items), item);
    }
    // Only a confirmed held-weapon change is success (1); accepted requests
    // without a slot change return -1. Recheck combat/mount state here as well.
    public func Apply(actor: ref<NPCPuppet>, wanted: Bool) -> Int32 {
        let mode: Int32 = this.Mode(actor);
        let context: ScriptExecutionContext;
        let candidates: array<NPCItemToEquip>;
        let items: array<NPCItemToEquip>;
        let i: Int32 = 0;
        let transaction: ref<TransactionSystem> = GameInstance.GetTransactionSystem(this.GetGameInstance());
        if mode == 0 || (!wanted && mode != 2) || NotEquals(wanted, this.WantsReady()) { return 0; };
        if Equals(this.IsReady(actor), wanted) { return 1; };
        if !AIHumanComponent.GetScriptContext(actor, context) { return -1; };
        if wanted {
            // GetEquipment only returns items the officer already owns.
            AIActionTransactionSystem.GetEquipment(context, true, candidates);
            while i < ArraySize(candidates) {
                if (candidates[i].slotID == t"AttachmentSlots.WeaponRight" || candidates[i].slotID == t"AttachmentSlots.WeaponLeft")
                    && NotEquals(WeaponObject.GetWeaponType(candidates[i].itemID), gamedataItemType.Invalid)
                    && !WeaponObject.IsFists(candidates[i].itemID) {
                    ArrayPush(items, candidates[i]);
                };
                i += 1;
            };
            if ArraySize(items) == 0 { return -1; };
            AISubActionEquipOnSlot_Record_Implementation.Equip(context, items, true);
            i = 0;
            while i < ArraySize(items) {
                if transaction.HasItemInSlot(actor, items[i].slotID, items[i].itemID) {
                    NPCPuppet.SetAnimWrapperBasedOnEquippedItem(actor, items[i].slotID, items[i].itemID, 1.0);
                };
                i += 1;
            };
        } else {
            this.CollectHand(actor, t"AttachmentSlots.WeaponRight", items);
            this.CollectHand(actor, t"AttachmentSlots.WeaponLeft", items);
            // false means holster/remove from hand, never drop/delete inventory.
            AISubActionUnequipOnSlot_Record_Implementation.Unequip(context, false, items);
            while i < ArraySize(items) {
                if !transaction.HasItemInSlot(actor, items[i].slotID, items[i].itemID) {
                    NPCPuppet.SetAnimWrapperBasedOnEquippedItem(actor, items[i].slotID, items[i].itemID, 0.0);
                };
                i += 1;
            };
            AIActionHelper.ClearItemsUnequipped(actor);
        };
        if Equals(this.IsReady(actor), wanted) { return 1; };
        return -1;
    }
    public func GetDiagnostics(actor: ref<NPCPuppet>) -> String {
        let high: String;
        let ours: Bool = this.IsOurs(actor);
        let mode: Int32 = this.Mode(actor);
        let held: Bool = this.IsReady(actor);
        let wanted: Bool = this.WantsReady();
        if IsDefined(actor) { high = ToString(actor.GetHighLevelStateFromBlackboard()); };
        return s"owned=\(ours) | mode=\(mode) | high=\(high) | V weapon=\(wanted) | officer weapon=\(held)";
    }
}
