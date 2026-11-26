// Offline signatures, NOT installed game imports. DecompiledGameScripts
// 81d996b5: orphans.swift State{Context,GameScriptInterface}, SceneTier/Data,
// ActiveLayerData, InteractionComponent, SetLootInteractionAccessibilityEvent;
// highLevelTransitions.swift three decision methods; scriptedPuppet.swift
// inventory/interaction fields and native loot functions; inventoryComponent.swift.
// Existing Codeware 1.21.4: SceneTierData.userDebugInfo, InteractionComponent.isEnabled.
public enum GameplayTier { Undefined = 0, Tier1_FullGameplay = 1, Tier2_StagedGameplay = 2, Tier3_LimitedGameplay = 3, Tier4_FPPCinematic = 4, Tier5_Cinematic = 5 }
public native class SceneTierData extends IScriptable {
    public native let tier: GameplayTier;
    public native let emptyHands: Bool;
    public native let userDebugInfo: String;
}
public native class SceneTier extends IScriptable {
    public final native func GetTierData() -> ref<SceneTierData>;
}
public native class StateContext extends IScriptable {
    public final native const func GetPermanentScriptableParameter(name: CName) -> ref<IScriptable>;
    public final native const func GetBoolParameter(name: CName, opt isPermanent: Bool) -> Bool;
    public final native const func IsStateMachineActive(name: CName) -> Bool;
}
public native struct BlackboardID_Int {}
public native class PlayerStateMachineDef extends IBlackboardDef {
    public native let HighLevel: BlackboardID_Int;
    public native let UpperBody: BlackboardID_Int;
}
@addField(AllBlackboardDefinitions)
public native let PlayerStateMachine: ref<PlayerStateMachineDef>;
@addMethod(IBlackboard)
public native const func GetInt(id: BlackboardID_Int) -> Int32;
public native class StateGameScriptInterface extends IScriptable {
    public native let executionOwner: wref<GameObject>;
    public native let localBlackboard: ref<IBlackboard>;
    public final native const func IsSceneAnimationActive() -> Bool;
    public final native const func GetSceneSystem() -> ref<SceneSystem>;
}
public native class SceneSystem extends IScriptable {
    public final native func GetScriptInterface() -> ref<SceneSystemInterface>;
}
public native class SceneSystemInterface extends IScriptable {
    public final native func IsEntityInDialogue(entity: EntityID) -> Bool;
}
public native class SceneTierInitialDecisions extends IScriptable {
    protected final const func EnterCondition(const stateContext: ref<StateContext>, const scriptInterface: ref<StateGameScriptInterface>) -> Bool { return false; }
}
public native class SceneTierIIDecisions extends IScriptable {
    protected final const func EnterCondition(const stateContext: ref<StateContext>, const scriptInterface: ref<StateGameScriptInterface>) -> Bool { return false; }
}
public native class SceneTierAbstractDecisions extends IScriptable {
    protected final const func ToExploration(const stateContext: ref<StateContext>, const scriptInterface: ref<StateGameScriptInterface>) -> Bool { return false; }
}
public native class Inventory extends IScriptable {
public final native func IsAccessible() -> Bool;
}
public native struct gameinteractionsActiveLayerData {
    public native let activator: wref<GameObject>;
    public native let linkedLayersName: CName;
    public native let layerName: CName;
}
public native class InteractionComponent extends IScriptable {
    public native let isEnabled: Bool;
    public final native const func GetActiveInputLayers(out activeInputLayers: array<gameinteractionsActiveLayerData>) -> Bool;
}
public native class SetLootInteractionAccessibilityEvent extends Event {
    public native let accessible: Bool;
}
@addField(ScriptedPuppet)
private native let m_inventoryComponent: wref<Inventory>;
@addMethod(ScriptedPuppet)
public native func GetRecordID() -> TweakDBID;
@addField(ScriptedPuppet)
private native let m_interactionComponent: wref<InteractionComponent>;
@addMethod(ScriptedPuppet)
public final const func EvaluateLootQualityEvent() -> Void {}
@addMethod(ScriptedPuppet)
public const func IsContainer() -> Bool { return false; }
@addMethod(TDBID)
public final static native func ToStringDEBUG(id: TweakDBID) -> String;
public native func IntToString(value: Int32) -> String;
