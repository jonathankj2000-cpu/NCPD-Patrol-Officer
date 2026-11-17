module BrowserExtension.System
import BrowserExtension.Classes.*

// Public boundary inferred from the working Virtual Atelier/Car Dealer
// SetupNewSite.reds integration and BEF's own documented listener API.
// A shape contract, not the actual BEF runtime or a substitute game cache.
public class BrowserExtensionSystem extends ScriptableSystem {
 public func Register(listener: ref<BrowserEventsListener>) -> Void {}
 public func Unregister(listener: ref<BrowserEventsListener>) -> Void {}
 public static func GetInstance(obj: ref<GameObject>) -> ref<BrowserExtensionSystem> { return null; }
 public func IsEnabled() -> Bool { return true; }
 public func ShouldBypassBrowserExtension() -> Bool { return false; }
 public func IsAddressBlocked(address: String) -> Bool { return false; }
}
