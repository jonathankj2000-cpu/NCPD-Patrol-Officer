module BrowserExtension.Classes
import BrowserExtension.DataStructures.*

// Place the listener outside System to check the imports used by the real
// integration examples, without assuming BEF's private data type names.
public class BrowserEventsListener extends IScriptable {
 protected let m_siteData: ref<CareerBrowserSiteData>;
 public func Init(logic: ref<BrowserGameController>) -> Void {}
 public func Uninit() -> Void {}
 public func GetWebPage(address: String) -> ref<inkCompoundWidget> { return null; }
 public func LoadPageByAddress(address: String) -> Void {}
}
