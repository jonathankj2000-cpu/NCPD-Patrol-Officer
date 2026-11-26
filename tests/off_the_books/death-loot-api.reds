// Not installed. Signatures from game reference 81d996b5 orphans.swift:
// gamePuppet, ItemID, TransactionSystem, Character/LootTable/LootItem records.
// NPCPuppet.swift OnIncapacitated calls ProcessLoot; disposalDevice.swift uses
// WasLootGenerated before ProcessLoot. No new native game declarations ship.
@addMethod(ItemID)
public final static native func CreateQuery(tdbID: TweakDBID) -> ItemID;
@addMethod(TransactionSystem)
public final native func RemoveItemByTDBID(obj: ref<GameObject>, tdbID: TweakDBID, amount: Int32, opt checkMultipleInstances: Bool) -> Bool;
@addMethod(ScriptedPuppet)
public final native func WasLootGenerated() -> Bool;
@addMethod(ScriptedPuppet)
public final native func ProcessLoot() -> Void;
@addMethod(Character_Record)
public final native func LootDrop() -> wref<LootTable_Record>;
@addMethod(Item_Record)
public final native func GetID() -> TweakDBID;
public native class LootTable_Record extends IScriptable {
    public final native func GetID() -> TweakDBID;
    public final native func GetLootItemsCount() -> Int32;
    public final native func GetLootItemsItem(index: Int32) -> wref<LootItem_Record>;
    public final native func MinItemsToLoot() -> Int32;
    public final native func MaxItemsToLoot() -> Int32;
}
public native class LootItem_Record extends IScriptable {
    public final native func ItemID() -> wref<Item_Record>;
    public final native func DropChance() -> Float;
    public final native func DropCountMin() -> Int32;
    public final native func DropCountMax() -> Int32;
}
