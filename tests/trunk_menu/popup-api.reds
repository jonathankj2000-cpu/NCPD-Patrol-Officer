// Offline boundaries only. Codeware v1.21.4 commit
// 6dfdbceff7882d8ad8632ab1ff8d42bcef20a8ad: KeyInputEvent.reds,
// CallbackSystem.hpp and UI/Popups/{InGamePopup,CustomPopup,Manager/*}.reds.
public enum EInputAction { IACT_None = 0, IACT_Press = 1, IACT_Release = 2, IACT_Axis = 3 }
public enum EInputKey {
 IK_None = 0, IK_1 = 49, IK_2 = 50, IK_3 = 51, IK_4 = 52, IK_5 = 53, IK_6 = 54, IK_7 = 55, IK_9 = 57,
 IK_NumPad1 = 97, IK_NumPad2 = 98, IK_NumPad3 = 99, IK_NumPad4 = 100, IK_NumPad5 = 101, IK_NumPad6 = 102, IK_NumPad7 = 103, IK_NumPad9 = 105
}
public native class CallbackSystemHandler extends IScriptable {}
public native class KeyInputEvent extends IScriptable {
 public native func GetAction() -> EInputAction;
 public native func GetKey() -> EInputKey;
 public native func IsShiftDown() -> Bool;
 public native func IsControlDown() -> Bool;
 public native func IsAltDown() -> Bool;
}
public native class CallbackSystem extends IScriptable {
 public native func RegisterCallback(event: CName, context: ref<IScriptable>, function: CName, opt sticky: Bool) -> ref<CallbackSystemHandler>;
 public native func UnregisterCallback(event: CName, context: ref<IScriptable>, opt function: CName) -> Void;
}
@addMethod(GameInstance)
public static native func GetCallbackSystem() -> ref<CallbackSystem>;
