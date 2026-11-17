module BrowserExtension.Classes
import BrowserExtension.DataStructures.*

// Verified against BrowserExtension.Classes.reds (public source snapshot).
// Navigation is on BrowserGameController, never on BrowserEventsListener.
public class BrowserEventsListener extends IScriptable {
 protected let m_deviceLogicController: wref<BrowserGameController>;
 protected let m_deviceObject: wref<GameObject>;
 protected let m_siteData: CustomInternetSite;
 public func Init(logic: ref<BrowserGameController>) -> Void {}
 public func Uninit() -> Void {}
 public func GetWebPage(address: String) -> ref<inkCompoundWidget> { return null; }
}
