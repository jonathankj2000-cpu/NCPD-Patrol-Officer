// Offline contracts only, never installed. Codeware 1.21.4 generated imports:
// Base/Addons/EntityReference.reds; Base/Imports/gameEntityReferenceType.reds;
// questUseWorkspot{NodeFunctions,ParamsV1,NodeDefinition}.reds;
// quest{AICommandNodeBase,SignalStoppingNodeDefinition}.reds.
// ExecuteNode itself is the existing Codeware Quest/QuestsSystem.reds import.
public native struct EntityReference {
    public native let type: gameEntityReferenceType;
    public native let names: array<CName>;
}
public enum gameEntityReferenceType { EntityRef = 0, Tag = 1, SlotID = 2, SceneActorContextName = 3 }
public enum questUseWorkspotNodeFunctions { UseWorkspot = 0, JumpWorkspot = 1, StopWorkspot = 2, IdleOnlyMode = 3 }
public abstract native class AICommandParams extends IScriptable {}
public native class questUseWorkspotParamsV1 extends AICommandParams {
    public native let function: questUseWorkspotNodeFunctions;
    public native let enableIdleMode: Bool;
    public native let changeWorkspot: Bool;
    public native let teleport: Bool;
    public native let jumpToEntry: Bool;
    public native let isPlayer: Bool;
}
public abstract native class questSignalStoppingNodeDefinition extends questDisableableNodeDefinition {}
public abstract native class questAICommandNodeBase extends questSignalStoppingNodeDefinition {}
public native class questUseWorkspotNodeDefinition extends questAICommandNodeBase {
    public native let entityReference: EntityReference;
    public native let paramsV1: ref<questUseWorkspotParamsV1>;
}
