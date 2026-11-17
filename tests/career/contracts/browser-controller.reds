import BrowserExtension.DataStructures.*

// Verified in browserController.overrides.reds; these extend the game controller.
@addMethod(BrowserGameController)
public final func LoadPageByAddress(address: String) -> Void {}

@addMethod(BrowserGameController)
public final func GetCustomSites() -> array<CustomInternetSite> {
 let sites: array<CustomInternetSite>;
 return sites;
}
