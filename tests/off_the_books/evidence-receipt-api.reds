// Offline only. Source 81d996b5: baseDeviceActions.swift BaseScriptableAction
// GetExecutor; baseItemAction.swift GetItemData; readAction.swift CompleteAction;
// orphans.swift gameItemData.GetID. No new game imports are installed.
public native class gameItemData extends IScriptable {
    public final native func GetID() -> ItemID;
}
@addMethod(ReadAction)
public final const func GetExecutor() -> wref<GameObject> { return null; }
@addMethod(ReadAction)
public final func GetItemData() -> wref<gameItemData> { return null; }
@addMethod(ReadAction)
public func CompleteAction(gameInstance: GameInstance) -> Void {}
