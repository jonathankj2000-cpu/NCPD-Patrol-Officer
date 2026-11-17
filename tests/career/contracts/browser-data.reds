module BrowserExtension.DataStructures

// Actual BEF value type, not the reference carrier used in the v0.10a test.
public struct CustomInternetSite {
 public let address: String;
 public let shortName: String;
 public let iconAtlasPath: ResRef;
 public let iconTexturePart: CName;
}
