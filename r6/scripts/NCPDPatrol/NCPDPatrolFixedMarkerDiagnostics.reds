// Value-only diagnostic snapshot. Formatting has no engine access or state writes.
public class NCPDPatrolFixedMarkerDiagnostics extends IScriptable {
    public let token: Int32;
    public let wanted: Bool;
    public let switch: Bool;
    public let restorePending: Bool;
    public let scope: Int32;
    public let site: Int32;
    public let target: Vector4;
    public let currentPath: String;
    public let hash: Uint32;
    public let nativeID: NewMappinID;
    public let fallbackID: NewMappinID;
    public let fallback: Bool;
    public let pinCount: Int32;
    public let confirmed: Bool;
    public let linked: Bool;
    public let positionOK: Bool;
    public let questPositionOK: Bool;
    public let runtimePoint: Vector4;
    public let questPoint: Vector3;
    public let manualBefore: NewMappinID;
    public let manualAfter: NewMappinID;
    public let status: String;
    public let detail: String;
    public let catalogBuilds: Int32;
    public let restoreCursor: Int32;
    public let sessionGeneration: Int32;
    public let activeBankPins: Int32;
    public let otherBankPins: Int32;
    public let targetActive: Bool;
    public let linkHash: Uint32;
    public let linkID: NewMappinID;
    public let pruned: Int32;
    public let registeredBankPins: Int32;
    public let registeredMatches: Int32;
    public let retained: Bool;
    public let lastNativeReason: String;
    public let fallbackRegistered: Bool;
    public let fallbackActive: Bool;
    public let fallbackVisible: Bool;
    public let fallbackPositionOK: Bool;
    public let fallbackAttempts: Int32;
    public let cachedActivations: Int32;
    public let objective: String;
    public let siteObjective: String;
    public let expectedHash: Uint32;
    public let selectedInCatalog: Bool;
    public let ownershipEntries: Int32;
    public func Evidence() -> String {
        return s"token=\(this.token) | scope=\(this.scope) | site=\(this.site) | objective=\(this.siteObjective) | hash=\(this.hash) | ownership entries=\(this.ownershipEntries) | expected path hash=\(this.expectedHash) | selected in catalog=\(this.selectedInCatalog) | active matches=\(this.pinCount) | registered matches=\(this.registeredMatches) | registered bank pins=\(this.registeredBankPins) | active bank pins=\(this.activeBankPins) | other ACTIVE bank pins=\(this.otherBankPins) | native confirmed=\(this.confirmed) | retained=\(this.retained) | target active=\(this.targetActive) | link hash=\(this.linkHash) | link ID=\(this.linkID.value) | objective link=\(this.linked) | runtime position OK=\(this.positionOK) | quest position OK=\(this.questPositionOK) | target=\(this.target.X),\(this.target.Y),\(this.target.Z) | runtime=\(this.runtimePoint.X),\(this.runtimePoint.Y),\(this.runtimePoint.Z) | quest position=\(this.questPoint.X),\(this.questPoint.Y),\(this.questPoint.Z)";
    }
    public func Current(sessionReady: Bool, current: NewMappinID) -> String {
        return s"\(this.status) | token=\(this.token) | scope=\(this.scope) | site=\(this.site) | active=\(this.wanted) | cleanup/switch=\(this.switch) | restore cleanup=\(this.restorePending) | restore cursor=\(this.restoreCursor)/1556 | session ready=\(sessionReady) | session generation=\(this.sessionGeneration) | ownership entries=\(this.ownershipEntries) | ownership builds=\(this.catalogBuilds) | expected path hash=\(this.expectedHash) | selected in catalog=\(this.selectedInCatalog) | native confirmed=\(this.confirmed) | native pins=\(this.pinCount) | registered bank pins=\(this.registeredBankPins) | registered matches=\(this.registeredMatches) | retained=\(this.retained) | cached activations=\(this.cachedActivations) | active bank pins=\(this.activeBankPins) | other bank pins=\(this.otherBankPins) | target active=\(this.targetActive) | pruned=\(this.pruned) | objective=\(this.objective) | link hash=\(this.linkHash) | link ID=\(this.linkID.value) | objective link=\(this.linked) | runtime position OK=\(this.positionOK) | quest position OK=\(this.questPositionOK) | pin ID=\(this.nativeID.value) | hash=\(this.hash) | target=\(this.target.X),\(this.target.Y),\(this.target.Z) | runtime=\(this.runtimePoint.X),\(this.runtimePoint.Y),\(this.runtimePoint.Z) | quest position=\(this.questPoint.X),\(this.questPoint.Y),\(this.questPoint.Z) | fallback=\(this.fallback) | fallback ID=\(this.fallbackID.value) | fallback registered=\(this.fallbackRegistered) | fallback active=\(this.fallbackActive) | fallback visible flag=\(this.fallbackVisible) | fallback position OK=\(this.fallbackPositionOK) | fallback attempts=\(this.fallbackAttempts) | last native reason=\(this.lastNativeReason) | manual before/after=\(this.manualBefore.value)/\(this.manualAfter.value) | manual current=\(current.value) | \(this.detail)";
    }
}
