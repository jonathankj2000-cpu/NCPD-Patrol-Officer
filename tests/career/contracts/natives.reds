// Offline signatures from MOD_Development_Reference, never installed in game.
// Core/UI widget declarations: core/ui/baseWidgets/{abstractWidgets,textWidget}
// and orphans.swift. Player combat: cyberpunk/player/player.swift.
public native func OperatorSubtract(a: Int32, b: Int32) -> Int32;
public native func OperatorMultiply(a: Int32, b: Int32) -> Int32;
public native func OperatorDivide(a: Int32, b: Int32) -> Int32;
public native func OperatorMultiply(a: Float, b: Float) -> Float;
public native func Cast(a: Int32) -> Float;

public native struct HDRColor {
 public native let Red: Float;
 public native let Green: Float;
 public native let Blue: Float;
 public native let Alpha: Float;
}
public enum inkEAnchor { TopLeft = 0, Centered = 4, Fill = 15 }
public enum textHorizontalAlignment { Left = 0, Center = 1, Right = 2 }
public abstract native class inkWidget extends IScriptable {
 public final native func SetName(name: CName) -> Void;
 public final native func SetAnchor(anchor: inkEAnchor) -> Void;
 public final func SetAnchorPoint(x: Float, y: Float) -> Void {}
 public final func SetSize(width: Float, height: Float) -> Void {}
 public final func SetMargin(left: Float, top: Float, right: Float, bottom: Float) -> Void {}
 public final native func SetTintColor(color: HDRColor) -> Void;
 public final native func SetInteractive(value: Bool) -> Void;
 public final native func SetFitToContent(value: Bool) -> Void;
 public final native func Reparent(parent: wref<inkCompoundWidget>, opt index: Int32) -> Void;
 public final native func RegisterToCallback(name: CName, object: ref<IScriptable>, method: CName) -> Void;
 public final native func UnregisterFromCallback(name: CName, object: ref<IScriptable>, method: CName) -> Void;
}
public abstract native class inkCompoundWidget extends inkWidget {}
public native class inkCanvas extends inkCompoundWidget {}
public native class inkRectangle extends inkWidget {}
public native class inkVerticalPanel extends inkCompoundWidget {}
public native class inkHorizontalPanel extends inkCompoundWidget {}
public native class inkText extends inkWidget {
 public final native func SetText(text: String, opt params: ref<IScriptable>) -> Void;
 public final native func SetFontFamily(path: String, opt style: CName) -> Void;
 public final native func SetFontStyle(style: CName) -> Void;
 public final native func SetFontSize(size: Int32) -> Void;
 public final native func SetHorizontalAlignment(alignment: textHorizontalAlignment) -> Void;
}
public native class inkPointerEvent extends IScriptable {
 public final native const func IsAction(action: CName) -> Bool;
}
public native class inkGameController extends IScriptable {
 public final native func GetOwnerEntity() -> ref<Entity>;
 public final native func GetPlayerControlledObject() -> ref<GameObject>;
}
public class BrowserGameController extends inkGameController {
 protected cb func OnInitialize() -> Bool { return true; }
 protected cb func OnUninitialize() -> Bool { return true; }
}
public class BrowserController extends IScriptable {
 private let m_gameController: wref<BrowserGameController>;
 public final func SetWebsiteData() -> Void {}
}
