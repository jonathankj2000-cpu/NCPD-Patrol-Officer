// Offline signatures only, derived from Codeware 1.21.4 (6dfdbce):
// App/Callback/{CallbackSystem,CallbackSystemHandler,Events/ResourceEvent,
// Targets/ResourceTarget}.hpp and Base/Imports/{JsonResource,locVoLengthEntry,
// locVoiceoverLengthMap}.reds; Utils/CRUID.reds. Never installed.
public native class ISerializable {}
public native class ScriptableService extends IScriptable {}
public native struct GameInstance {
    public static native func GetCallbackSystem() -> ref<CallbackSystem>;
}
public native class CallbackSystem extends IScriptable {
    public native func RegisterCallback(event: CName, context: ref<IScriptable>, function: CName, opt sticky: Bool) -> ref<CallbackSystemHandler>;
    public native func UnregisterCallback(event: CName, context: ref<IScriptable>, opt function: CName) -> Void;
}
public native class CallbackSystemHandler extends IScriptable {
    public native func AddTarget(target: ref<CallbackSystemTarget>) -> ref<CallbackSystemHandler>;
}
public native class CallbackSystemTarget extends IScriptable {}
public native class ResourceTarget extends CallbackSystemTarget {
    public static native func Path(path: ResRef) -> ref<ResourceTarget>;
}
public native struct ResRef {}
public native class CallbackSystemEvent extends IScriptable {}
public native class ResourceEvent extends CallbackSystemEvent {
    public native func GetResource() -> ref<CResource>;
}
public native class CResource extends ISerializable {}
public native class JsonResource extends CResource { public native let root: ref<ISerializable>; }
public native struct CRUID {}
public native func HashToCRUID(value: Uint64) -> CRUID;
public native func CRUIDToHash(value: CRUID) -> Uint64;
public native func OperatorEqual(left: Uint64, right: Uint64) -> Bool;
public native func OperatorEqual(left: Float, right: Float) -> Bool;
public native struct locVoLengthEntry {
    public native let stringId: CRUID;
    public native let femaleLength: Float;
    public native let maleLength: Float;
}
public native class locVoiceoverLengthMap extends ISerializable {
    public native let entries: array<locVoLengthEntry>;
}
// The ordinary native operators are not part of the compiler's boot library.
public native func OperatorLogicNot(value: Bool) -> Bool;
public native func OperatorLogicAnd(left: Bool, right: Bool) -> Bool;
public native func OperatorLess(left: Int32, right: Int32) -> Bool;
public native func OperatorEqual(left: Int32, right: Int32) -> Bool;
public native func OperatorAssignAdd(out left: Int32, right: Int32) -> Int32;
public native func OperatorAdd(left: String, right: String) -> String;
