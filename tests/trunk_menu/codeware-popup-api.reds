// Offline signatures from the pinned Codeware v1.21.4 scripts, never shipped.
module Codeware.UI
public abstract native class CustomPopup extends inkLogicController {
 public func UseCursor() -> Bool { return false; }
 public func Close() -> Void {}
 public native func GetRootCompoundWidget() -> wref<inkCompoundWidget>;
 protected native func SetContainerWidget(widget: ref<inkCompoundWidget>) -> Void;
 protected native func IsTopPopup() -> Bool;
 protected cb func OnAttach() -> Void {}
 protected cb func OnDetach() -> Void {}
}
public abstract native class InGamePopup extends CustomPopup {
 protected let m_container: wref<inkCompoundWidget>;
 protected func CreateContainer() -> Void {}
}
public native class CustomPopupManager extends IScriptable {
 public static native func GetInstance() -> ref<CustomPopupManager>;
 public native func IsInitialized() -> Bool;
 public native func ShowPopup(popup: ref<CustomPopup>) -> Void;
}
