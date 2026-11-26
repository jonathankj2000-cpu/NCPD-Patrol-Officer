// Offline signatures only; never installed. Game reference 81d996b5:
// orphans.swift ItemAddedEvent, ItemID, TransactionSystem and AIHoldPositionCommand;
// core/components/aiComponent.swift; player/player.swift;
// items/actions/{itemActionsHelper,readAction}.swift. No new production imports.
public native class Item_Record extends IScriptable {}
public native class Character_Record extends IScriptable {}
@addMethod(TweakDBInterface)
public final static native func GetItemRecord(path: TweakDBID) -> ref<Item_Record>;
@addMethod(TweakDBInterface)
public final static native func GetCharacterRecord(path: TweakDBID) -> ref<Character_Record>;
@addMethod(ObjectAction_Record)
public final native func GetID() -> TweakDBID;
public native class ItemActionsHelper extends IScriptable {
    public final static native func GetReadAction(itemID: ItemID) -> wref<ObjectAction_Record>;
}
public native class ReadAction extends IScriptable {
    public final static native func GetJournalEntryFromAction(actionID: TweakDBID) -> String;
}
@addMethod(ItemID)
public final static native func IsValid(itemID: ItemID) -> Bool;
@addMethod(TransactionSystem)
public final native func GetItemQuantity(obj: ref<GameObject>, itemID: ItemID) -> Int32;
public native class ItemAddedEvent extends Event {
    public native let itemID: ItemID;
    public native let currentQuantity: Int32;
}
@addMethod(PlayerPuppet)
protected cb func OnItemAddedToInventory(evt: ref<ItemAddedEvent>) -> Bool { return false; }
public native class AICommand extends IScriptable {}
public native class AIHoldPositionCommand extends AICommand {
    public let duration: Float;
    public native let removeAfterCombat: Bool;
    public native let ignoreInCombat: Bool;
}
public native class AIComponent extends IScriptable {
    public final static native func SendCommand(obj: wref<ScriptedPuppet>, cmd: ref<AICommand>) -> Void;
    public final static native func CancelCommand(obj: wref<ScriptedPuppet>, cmd: ref<AICommand>) -> Void;
}
