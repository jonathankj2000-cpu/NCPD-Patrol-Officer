// Pure private-path catalogue. No journal, world, marker or session access.
public class NCPDPatrolFixedMarkerCatalog extends IScriptable {
    public static func Root(scope: Int32) -> String {
        if scope < 0 || scope > 9 { return ""; };
        if scope == 0 { return "quests/minor_quest/ncpd_patrol_dispatch"; };
        if scope < 6 { return s"quests/minor_quest/ncpd_patrol_dispatch_\(scope)"; };
        if scope < 8 { return "quests/minor_quest/ncpd_patrol_cyberpsycho"; };
        return "quests/minor_quest/ncpd_patrol_vip";
    }
    public static func Phase(scope: Int32) -> String { return NCPDPatrolFixedMarkerCatalog.Root(scope) + "/main"; }
    public static func BaseObjective(scope: Int32) -> String {
        let phase: String = NCPDPatrolFixedMarkerCatalog.Phase(scope);
        if scope < 6 { return s"\(phase)/resolve"; };
        if scope == 6 { return s"\(phase)/respond"; };
        if scope == 7 { return s"\(phase)/neutralize"; };
        if scope == 8 { return s"\(phase)/pickup"; };
        return s"\(phase)/deliver";
    }
    public static func SiteObjective(scope: Int32, site: Int32) -> String {
        let base: String = NCPDPatrolFixedMarkerCatalog.BaseObjective(scope);
        if site > 0 { return s"\(base)_bank_\(site)"; };
        return base;
    }
    public static func PinPath(scope: Int32, site: Int32) -> String {
        let objective: String = NCPDPatrolFixedMarkerCatalog.SiteObjective(scope, site);
        return s"\(objective)/location";
    }
    public static func LegacyPath(scope: Int32, site: Int32) -> String {
        let objective: String = NCPDPatrolFixedMarkerCatalog.BaseObjective(scope);
        return s"\(objective)/bank_\(site)";
    }
    public static func PathHash(path: String) -> Uint32 {
        // ArchiveXL/RED4ext journal path hashing, explicit standard seed.
        // Pure identity: independent of entry availability during restoration.
        return Murmur3(path, 1592638046u);
    }
    public static func Build(out hashes: array<Uint32>, out paths: array<String>, out objectives: array<String>) -> Void {
        let scope: Int32 = 0;
        let site: Int32;
        let last: Int32;
        let path: String;
        ArrayClear(hashes); ArrayClear(paths); ArrayClear(objectives);
        while scope < 10 {
            site = 1; last = 132;
            if scope >= 6 { site = 133; last = 323; };
            while site <= last {
                path = NCPDPatrolFixedMarkerCatalog.PinPath(scope, site);
                NCPDPatrolFixedMarkerCatalog.AddPath(hashes, paths, path);
                ArrayPush(objectives, NCPDPatrolFixedMarkerCatalog.SiteObjective(scope, site));
                path = NCPDPatrolFixedMarkerCatalog.LegacyPath(scope, site);
                NCPDPatrolFixedMarkerCatalog.AddPath(hashes, paths, path);
                site += 1;
            };
            scope += 1;
        };
    }
    public static func AddPath(out hashes: array<Uint32>, out paths: array<String>, path: String) -> Void {
        let hash: Uint32 = NCPDPatrolFixedMarkerCatalog.PathHash(path);
        let left: Int32 = 0;
        let right: Int32 = ArraySize(hashes);
        let middle: Int32;
        while left < right {
            middle = (left + right) / 2;
            if hashes[middle] < hash { left = middle + 1; } else { right = middle; };
        };
        if left < ArraySize(hashes) && hashes[left] == hash { return; };
        ArrayInsert(hashes, left, hash); ArrayInsert(paths, left, path);
    }
    // Pass the array by reference; this lookup never writes to it.
    public static func Index(out hashes: array<Uint32>, hash: Uint32) -> Int32 {
        let left: Int32 = 0;
        let right: Int32 = ArraySize(hashes) - 1;
        let middle: Int32;
        while left <= right {
            middle = (left + right) / 2;
            if hashes[middle] == hash { return middle; };
            if hashes[middle] < hash { left = middle + 1; } else { right = middle - 1; };
        };
        return -1;
    }
}
