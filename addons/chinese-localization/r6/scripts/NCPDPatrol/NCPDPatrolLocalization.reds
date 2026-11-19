import Codeware.Localization.*

// Native interaction captions resolve the TweakDB caption key, not just the
// ScriptableDeviceAction's custom caption. Register both keys with Codeware.
public class NCPDPatrolLocalizationProvider extends ModLocalizationProvider {
    public func GetPackage(language: CName) -> ref<ModLocalizationPackage> {
        if Equals(language, n"en-us") { return new NCPDPatrolEnglishText(); }
        if Equals(language, n"zh-cn") { return new NCPDPatrolChineseSimplifiedText(); }
        if Equals(language, n"zh-tw") { return new NCPDPatrolChineseTraditionalText(); }
        return null;
    }

    public func GetFallback() -> CName { return n"en-us"; }
}

public class NCPDPatrolEnglishText extends ModLocalizationPackage {
    protected func DefineTexts() -> Void {
        this.Text("NCPD_BeanBagger_WeaponName", "M2038 NCPD Bean Bagger");
        this.Text("NCPD_BeanBagger_Description", "NCPD-issued less-lethal 12-gauge beanbag shotgun. Tier 2. Intended for non-lethal takedowns of human suspects.");
        this.Text("NCPDPatrol-StartShift", "Start NCPD Shift");
        this.Text("NCPDPatrol-EndShift", "End NCPD Shift");
        this.Text("NCPDPatrol-Backup", "Request NCPD Backup");
        this.Text("NCPDPatrol-PatrolMenu", "Patrol Menu");
        this.Text("NCPDPatrol-Available", "Set AVAILABLE - accept dispatches");
        this.Text("NCPDPatrol-Busy", "Set BUSY - pause dispatches");
        this.Text("NCPDPatrol-Repair", "Request vehicle repair (10 s)");
        this.Text("NCPDPatrol-NewPartner", "Request new partner");
        this.Text("NCPDPatrol-CancelDispatch", "Cancel dispatch");
        this.Text("NCPDPatrol-NewDispatch", "Request new dispatch");
        this.Text("NCPDPatrol-CopStats", "Cop Stats");
        this.Text("NCPDPatrol-ReleaseBackup", "10-4 - Release backup");
        this.Text("NCPDPatrol-CloseMenu", "Close Patrol Menu");
        this.Text("NCPDPatrol-Revive", "Revive Partner");
        this.Text("NCPDPatrol-Reviving", "Reviving Partner - stay close (3 s)");
        this.Text("NCPDPatrol-Arrest", "Arrest suspect");
        this.Text("NCPDPatrol-Arresting", "Arresting suspect - stay close");
    }
}

public class NCPDPatrolChineseSimplifiedText extends ModLocalizationPackage {
    protected func DefineTexts() -> Void {
        this.Text("NCPD_BeanBagger_WeaponName", "M2038 NCPD 布袋弹霰弹枪");
        this.Text("NCPD_BeanBagger_Description", "NCPD配发的非致命12号口径布袋弹霰弹枪。2阶。用于以非致命方式制服人类嫌疑人。");
        this.Text("NCPDPatrol-StartShift", "开始NCPD执勤");
        this.Text("NCPDPatrol-EndShift", "结束NCPD执勤");
        this.Text("NCPDPatrol-Backup", "请求NCPD增援");
        this.Text("NCPDPatrol-PatrolMenu", "巡逻菜单");
        this.Text("NCPDPatrol-Available", "设为待命 — 接受派遣");
        this.Text("NCPDPatrol-Busy", "设为忙碌 — 暂停派遣");
        this.Text("NCPDPatrol-Repair", "请求车辆维修（10秒）");
        this.Text("NCPDPatrol-NewPartner", "呼叫新搭档");
        this.Text("NCPDPatrol-CancelDispatch", "取消当前派遣");
        this.Text("NCPDPatrol-NewDispatch", "请求新的派遣任务");
        this.Text("NCPDPatrol-CopStats", "警员统计");
        this.Text("NCPDPatrol-ReleaseBackup", "10-4 — 结束增援");
        this.Text("NCPDPatrol-CloseMenu", "关闭巡逻菜单");
        this.Text("NCPDPatrol-Revive", "救助搭档");
        this.Text("NCPDPatrol-Reviving", "正在救助搭档 — 请保持靠近（3秒）");
        this.Text("NCPDPatrol-Arrest", "逮捕嫌疑人");
        this.Text("NCPDPatrol-Arresting", "正在逮捕嫌疑人 — 请保持靠近");
    }
}

public class NCPDPatrolChineseTraditionalText extends ModLocalizationPackage {
    protected func DefineTexts() -> Void {
        this.Text("NCPD_BeanBagger_WeaponName", "M2038 NCPD 布袋彈霰彈槍");
        this.Text("NCPD_BeanBagger_Description", "NCPD配發的非致命12號口徑布袋彈霰彈槍。2階。用於以非致命方式制伏人類嫌犯。");
        this.Text("NCPDPatrol-StartShift", "開始NCPD執勤");
        this.Text("NCPDPatrol-EndShift", "結束NCPD執勤");
        this.Text("NCPDPatrol-Backup", "請求NCPD增援");
        this.Text("NCPDPatrol-PatrolMenu", "巡邏選單");
        this.Text("NCPDPatrol-Available", "設為待命 — 接受派遣");
        this.Text("NCPDPatrol-Busy", "設為忙碌 — 暫停派遣");
        this.Text("NCPDPatrol-Repair", "請求車輛維修（10秒）");
        this.Text("NCPDPatrol-NewPartner", "呼叫新搭檔");
        this.Text("NCPDPatrol-CancelDispatch", "取消目前的派遣");
        this.Text("NCPDPatrol-NewDispatch", "請求新的派遣任務");
        this.Text("NCPDPatrol-CopStats", "員警統計");
        this.Text("NCPDPatrol-ReleaseBackup", "10-4 — 結束增援");
        this.Text("NCPDPatrol-CloseMenu", "關閉巡邏選單");
        this.Text("NCPDPatrol-Revive", "救助搭檔");
        this.Text("NCPDPatrol-Reviving", "正在救助搭檔 — 請留在附近（3秒）");
        this.Text("NCPDPatrol-Arrest", "逮捕嫌犯");
        this.Text("NCPDPatrol-Arresting", "正在逮捕嫌犯 — 請留在附近");
    }
}
