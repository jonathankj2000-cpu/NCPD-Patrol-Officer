// Offline source-derived boundaries; NEVER installed. Equipment signatures:
// core/systems/transactionSystem.swift, core/ai/actions/tweakAISubActions.swift,
// scriptedPuppet.swift, aiHumanComponent/aiActionHelper and weapon.swift.
// Codeware DynamicEntitySystem: v1.21.4, 6dfdbceff7882d8ad8632ab1ff8d42bcef20a8ad.
public native struct ScriptExecutionContext {}
public struct NPCItemToEquip {
 public let itemID: ItemID;
 public let slotID: TweakDBID;
 public let bodySlotID: TweakDBID;
}
public enum gamedataItemType { Invalid = 0 }
public native class ItemObject extends GameObject {
 public native func GetItemID() -> ItemID;
}
public native class WeaponObject extends ItemObject {
 public static native func IsFists(id: ItemID) -> Bool;
 public static native func GetWeaponType(id: ItemID) -> gamedataItemType;
}
public native class DynamicEntitySystem extends IScriptable {
 public native func IsManaged(id: EntityID) -> Bool;
 public native func IsTagged(id: EntityID, tag: CName) -> Bool;
}
@addMethod(GameInstance)
public static native func GetDynamicEntitySystem() -> ref<DynamicEntitySystem>;
@addMethod(ScriptedPuppet)
public static native func GetActiveWeapon(obj: ref<GameObject>) -> wref<WeaponObject>;
@addMethod(AIHumanComponent)
public static native func GetScriptContext(puppet: ref<ScriptedPuppet>, out context: ScriptExecutionContext) -> Bool;
@addMethod(NPCPuppet)
public static native func SetAnimWrapperBasedOnEquippedItem(npc: wref<NPCPuppet>, slot: TweakDBID, item: ItemID, value: Float) -> Void;
@addMethod(TransactionSystem)
public native func GetItemInSlot(obj: wref<GameObject>, slot: TweakDBID) -> wref<ItemObject>;
@addMethod(TransactionSystem)
public native func HasItemInSlot(obj: ref<GameObject>, slot: TweakDBID, opt item: ItemID) -> Bool;
public native class AIActionTransactionSystem extends IScriptable {
 public static native func GetEquipment(const context: ScriptExecutionContext, checkPrimaryEquipment: Bool, itemsList: script_ref<[NPCItemToEquip]>) -> Bool;
 public static native func GetItemsBodySlot(owner: wref<ScriptedPuppet>, const itemID: ItemID, out onBodySlotID: TweakDBID) -> Bool;
}
public abstract native class AISubActionEquipOnSlot_Record_Implementation extends IScriptable {
 public static native func Equip(context: ScriptExecutionContext, const itemsToEquip: script_ref<[NPCItemToEquip]>, cacheEquipped: Bool) -> Bool;
}
public abstract native class AISubActionUnequipOnSlot_Record_Implementation extends IScriptable {
 public static native func Unequip(context: ScriptExecutionContext, dropItem: Bool, itemsToUnequip: array<NPCItemToEquip>) -> Bool;
}
public native class AIActionHelper extends IScriptable {
 public static native func ClearItemsUnequipped(puppet: ref<ScriptedPuppet>) -> Void;
}
