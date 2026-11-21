// Generated from assets/officer_down_sites/catalog.json. Stable indices and authored pins.
public class NCPDPatrolOfficerDownCatalog extends IScriptable {
    public static func Count() -> Int32 { return 16; }
    public static func Root(index: Int32) -> String {
        if index == 1 { return "quests/minor_quest/ncpd_patrol_officer_down"; };
        if index == 2 { return "quests/minor_quest/ncpd_patrol_officer_down_kryss_02"; };
        if index == 3 { return "quests/minor_quest/ncpd_patrol_officer_down_kryss_03"; };
        if index == 4 { return "quests/minor_quest/ncpd_patrol_officer_down_kryss_04"; };
        if index == 5 { return "quests/minor_quest/ncpd_patrol_officer_down_kryss_05"; };
        if index == 6 { return "quests/minor_quest/ncpd_patrol_officer_down_kryss_06"; };
        if index == 7 { return "quests/minor_quest/ncpd_patrol_officer_down_kryss_07"; };
        if index == 8 { return "quests/minor_quest/ncpd_patrol_officer_down_kryss_08"; };
        if index == 9 { return "quests/minor_quest/ncpd_patrol_officer_down_kryss_09"; };
        if index == 10 { return "quests/minor_quest/ncpd_patrol_officer_down_kryss_10"; };
        if index == 11 { return "quests/minor_quest/ncpd_patrol_officer_down_kryss_11"; };
        if index == 12 { return "quests/minor_quest/ncpd_patrol_officer_down_kryss_12"; };
        if index == 13 { return "quests/minor_quest/ncpd_patrol_officer_down_kryss_14"; };
        if index == 14 { return "quests/minor_quest/ncpd_patrol_officer_down_kryss_15"; };
        if index == 15 { return "quests/minor_quest/ncpd_patrol_officer_down_kryss_16"; };
        if index == 16 { return "quests/minor_quest/ncpd_patrol_officer_down_kryss_17"; };
        return "";
    }
    public static func Enabled(index: Int32) -> Bool {
        if index == 1 { return true; };
        if index == 2 { return true; };
        if index == 3 { return true; };
        if index == 4 { return true; };
        if index == 5 { return true; };
        if index == 6 { return true; };
        if index == 7 { return true; };
        if index == 8 { return true; };
        if index == 9 { return true; };
        if index == 10 { return true; };
        if index == 11 { return true; };
        if index == 12 { return true; };
        if index == 13 { return true; };
        if index == 14 { return true; };
        if index == 15 { return true; };
        if index == 16 { return true; };
        return false;
    }
    public static func Position(index: Int32) -> Vector4 {
        let point: Vector4;
        point.W = 1.0;
        if index == 1 { point.X = -490.911377000; point.Y = -173.816315000; point.Z = 7.887070000; return point; };
        if index == 2 { point.X = -1960.316650000; point.Y = -1216.668457000; point.Z = 10.327583000; return point; };
        if index == 3 { point.X = -1832.878174000; point.Y = -869.848999000; point.Z = 7.484634000; return point; };
        if index == 4 { point.X = -1854.235840000; point.Y = -95.590836000; point.Z = 7.551308000; return point; };
        if index == 5 { point.X = -1840.118164000; point.Y = 214.088165000; point.Z = 7.082535000; return point; };
        if index == 6 { point.X = -1572.332642000; point.Y = 30.731720000; point.Z = 16.555321000; return point; };
        if index == 7 { point.X = -1503.422485000; point.Y = 1571.012939000; point.Z = 18.000000000; return point; };
        if index == 8 { point.X = -1423.498535000; point.Y = 2204.005615000; point.Z = 17.999985000; return point; };
        if index == 9 { point.X = -1156.895386000; point.Y = 2365.504639000; point.Z = 6.728867000; return point; };
        if index == 10 { point.X = -1017.527283000; point.Y = 2576.913818000; point.Z = 22.164085000; return point; };
        if index == 11 { point.X = -1577.779541000; point.Y = 3236.467773000; point.Z = 7.118637000; return point; };
        if index == 12 { point.X = -1889.254150000; point.Y = 3637.462646000; point.Z = 7.118637000; return point; };
        if index == 13 { point.X = -713.949585000; point.Y = 2196.259033000; point.Z = 52.904289000; return point; };
        if index == 14 { point.X = -868.048889000; point.Y = -290.759155000; point.Z = 7.695068000; return point; };
        if index == 15 { point.X = -967.523193000; point.Y = -218.141068000; point.Z = 7.250000000; return point; };
        if index == 16 { point.X = -1295.443359000; point.Y = -167.141464000; point.Z = 7.931709000; return point; };
        return point;
    }
}
