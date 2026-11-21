module NCPDPatrol.Career

@if(ModuleExists("BrowserExtension.System"))
import BrowserExtension.DataStructures.*
@if(ModuleExists("BrowserExtension.System"))
import BrowserExtension.Classes.*
@if(ModuleExists("BrowserExtension.System"))
import BrowserExtension.System.*

// Optional, device-scoped portal. Rendering only reads the existing career.
@if(ModuleExists("BrowserExtension.System"))
public class NCPDPatrolCareerSiteListener extends BrowserEventsListener {
    private let m_owner: wref<GameObject>;
    private let m_claimButton: wref<inkCanvas>;
    private let m_refreshButton: wref<inkCanvas>;
    private let m_dutyButton: wref<inkCanvas>;
    private let m_startRequested: Bool;
    private let m_endRequested: Bool;
    private let m_serviceTab: wref<inkCanvas>;
    private let m_rewardsTab: wref<inkCanvas>;
    private let m_partnerTab: wref<inkCanvas>;
    private let m_partnerButtons: array<wref<inkCanvas>>;
    private let m_buttons: array<wref<inkCanvas>>;
    private let m_handlers: array<CName>;
    private let m_faces: array<wref<inkRectangle>>;
    private let m_primary: array<Bool>;
    private let m_section: Int32;
    private let m_revision: Int32;
    private let m_state: ref<NCPDPatrolCareerBrowserState>;

    public func Init(logic: ref<BrowserGameController>) -> Void {
        super.Init(logic);
        this.m_owner = this.m_deviceObject;
        this.m_siteData.address = "NETdir://ncpd.career";
        this.m_siteData.shortName = "NCPD Career";
        this.m_revision = 0;
        this.m_section = 0;
        this.m_startRequested = false;
        this.m_endRequested = false;
        if IsDefined(this.m_owner) {
            this.m_state = NCPDPatrolCareerBrowserState.Get(this.m_owner.GetGame());
            if IsDefined(this.m_state) { this.m_state.ReportBrowser(logic); };
        };
    }
    public func Uninit() -> Void {
        this.ReleasePageCallbacks();
        if IsDefined(this.m_state) { this.m_state.ReportClosed(); };
        this.m_state = null;
        this.m_owner = null;
        this.m_startRequested = false;
        this.m_endRequested = false;
        super.Uninit();
    }
    private func ReleasePageCallbacks() -> Void {
        let i: Int32 = 0;
        while i < ArraySize(this.m_buttons) {
            if IsDefined(this.m_buttons[i]) {
                this.m_buttons[i].UnregisterFromCallback(n"OnRelease", this, this.m_handlers[i]);
                this.m_buttons[i].UnregisterFromCallback(n"OnEnter", this, n"OnButtonEnter");
                this.m_buttons[i].UnregisterFromCallback(n"OnLeave", this, n"OnButtonLeave");
            };
            i += 1;
        };
        ArrayClear(this.m_buttons);
        ArrayClear(this.m_handlers);
        ArrayClear(this.m_faces);
        ArrayClear(this.m_primary);
        ArrayClear(this.m_partnerButtons);
        this.m_claimButton = null;
        this.m_refreshButton = null;
        this.m_dutyButton = null;
        this.m_serviceTab = null;
        this.m_rewardsTab = null;
        this.m_partnerTab = null;
    }
    private func Career() -> ref<NCPDPatrolCareerSystem> {
        if !IsDefined(this.m_owner) || !this.m_owner.IsAttached() { return null; };
        return NCPDPatrolCareerSystem.Get(this.m_owner.GetGame());
    }
    private func Color(red: Float, green: Float, blue: Float, alpha: Float) -> HDRColor {
        let color: HDRColor;
        color.Red = red; color.Green = green; color.Blue = blue; color.Alpha = alpha;
        return color;
    }
    private func Ink() -> HDRColor { return this.Color(0.020, 0.042, 0.062, 1.0); }
    private func Surface() -> HDRColor { return this.Color(0.035, 0.075, 0.105, 1.0); }
    private func Line() -> HDRColor { return this.Color(0.10, 0.23, 0.29, 1.0); }
    private func Cyan() -> HDRColor { return this.Color(0.29, 0.81, 0.93, 1.0); }
    private func Gold() -> HDRColor { return this.Color(0.95, 0.76, 0.37, 1.0); }
    private func White() -> HDRColor { return this.Color(0.88, 0.94, 0.97, 1.0); }
    private func Muted() -> HDRColor { return this.Color(0.48, 0.63, 0.69, 1.0); }

    private func Canvas(parent: ref<inkCompoundWidget>, name: CName, x: Float, y: Float, width: Float, height: Float) -> ref<inkCanvas> {
        let canvas: ref<inkCanvas> = new inkCanvas();
        canvas.SetName(name);
        canvas.SetSize(width, height);
        canvas.SetMargin(x, y, 0.0, 0.0);
        canvas.Reparent(parent);
        return canvas;
    }
    private func Rect(parent: ref<inkCompoundWidget>, x: Float, y: Float, width: Float, height: Float, color: HDRColor) -> ref<inkRectangle> {
        let rectangle: ref<inkRectangle> = new inkRectangle();
        rectangle.SetSize(width, height);
        rectangle.SetMargin(x, y, 0.0, 0.0);
        rectangle.SetTintColor(color);
        rectangle.SetInteractive(false);
        rectangle.Reparent(parent);
        return rectangle;
    }
    private func Label(parent: ref<inkCompoundWidget>, value: String, x: Float, y: Float, width: Float, height: Float, size: Int32, color: HDRColor) -> ref<inkText> {
        let text: ref<inkText> = new inkText();
        text.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
        text.SetFontStyle(n"Medium");
        text.SetFontSize(size);
        text.SetSize(width, height);
        text.SetMargin(x, y, 0.0, 0.0);
        text.SetWrappingAtPosition(width);
        text.SetTintColor(color);
        text.SetText(value);
        text.SetInteractive(false);
        text.Reparent(parent);
        return text;
    }
    private func Card(parent: ref<inkCompoundWidget>, name: CName, x: Float, y: Float, width: Float, height: Float, border: HDRColor) -> ref<inkCanvas> {
        let card: ref<inkCanvas> = this.Canvas(parent, name, x, y, width, height);
        this.Rect(card, 0.0, 0.0, width, height, border);
        this.Rect(card, 1.0, 1.0, width - 2.0, height - 2.0, this.Surface());
        return card;
    }
    private func Button(parent: ref<inkCompoundWidget>, label: String, handler: CName, x: Float, y: Float, width: Float, height: Float, primary: Bool, enabled: Bool) -> ref<inkCanvas> {
        let button: ref<inkCanvas> = this.Canvas(parent, n"NCPDPatrolButton", x, y, width, height);
        let face: ref<inkRectangle>;
        let text: ref<inkText>;
        let border: HDRColor = this.Line();
        let background: HDRColor = this.Color(0.04, 0.13, 0.18, 1.0);
        let foreground: HDRColor = this.White();
        if primary { border = this.Gold(); background = this.Gold(); foreground = this.Ink(); };
        if !enabled { border = this.Line(); background = this.Surface(); foreground = this.Muted(); };
        button.SetInteractive(enabled);
        this.Rect(button, 0.0, 0.0, width, height, border);
        face = this.Rect(button, 1.0, 1.0, width - 2.0, height - 2.0, background);
        text = this.Label(button, label, 12.0, (height - 30.0) * 0.5, width - 24.0, 32.0, 22, foreground);
        text.SetHorizontalAlignment(textHorizontalAlignment.Center);
        button.RegisterToCallback(n"OnRelease", this, handler);
        button.RegisterToCallback(n"OnEnter", this, n"OnButtonEnter");
        button.RegisterToCallback(n"OnLeave", this, n"OnButtonLeave");
        ArrayPush(this.m_buttons, button);
        ArrayPush(this.m_handlers, handler);
        ArrayPush(this.m_faces, face);
        ArrayPush(this.m_primary, primary);
        return button;
    }
    private func Hover(event: ref<inkPointerEvent>, entered: Bool) -> Bool {
        let i: Int32 = 0;
        let target: wref<inkWidget> = event.GetCurrentTarget();
        let color: HDRColor;
        while i < ArraySize(this.m_buttons) {
            if this.m_buttons[i] == target && this.m_buttons[i].IsInteractive() {
                color = this.Color(0.04, 0.13, 0.18, 1.0);
                if entered { color = this.Color(0.08, 0.26, 0.33, 1.0); };
                if this.m_primary[i] {
                    color = this.Gold();
                    if entered { color = this.Color(1.0, 0.87, 0.56, 1.0); };
                };
                this.m_faces[i].SetTintColor(color);
                return true;
            };
            i += 1;
        };
        return false;
    }
    protected cb func OnButtonEnter(event: ref<inkPointerEvent>) -> Bool { return this.Hover(event, true); }
    protected cb func OnButtonLeave(event: ref<inkPointerEvent>) -> Bool { return this.Hover(event, false); }
    private func Chip(parent: ref<inkCompoundWidget>, value: String, x: Float, y: Float, width: Float, color: HDRColor) -> Void {
        let chip: ref<inkCanvas> = this.Canvas(parent, n"NCPDPatrolStatusChip", x, y, width, 30.0);
        let label: ref<inkText>;
        this.Rect(chip, 0.0, 0.0, width, 30.0, this.Line());
        this.Rect(chip, 1.0, 1.0, width - 2.0, 28.0, this.Ink());
        this.Rect(chip, 0.0, 0.0, 3.0, 30.0, color);
        label = this.Label(chip, value, 8.0, 3.0, width - 16.0, 24.0, 16, color);
        label.SetHorizontalAlignment(textHorizontalAlignment.Center);
    }
    private func Progress(parent: ref<inkCompoundWidget>, x: Float, y: Float, width: Float, height: Float, fraction: Float, color: HDRColor) -> Void {
        let value: Float = fraction;
        if value < 0.0 { value = 0.0; };
        if value > 1.0 { value = 1.0; };
        this.Rect(parent, x, y, width, height, this.Line());
        if value > 0.0 { this.Rect(parent, x, y, width * value, height, color); };
    }
    private func Badge(parent: ref<inkCompoundWidget>, x: Float, y: Float, color: HDRColor) -> Void {
        let badge: ref<inkCanvas> = this.Canvas(parent, n"NCPDPatrolBadge", x, y, 82.0, 106.0);
        let edge: ref<inkRectangle>;
        let text: ref<inkText>;
        this.Rect(badge, 0.0, 0.0, 80.0, 2.0, color);
        this.Rect(badge, 0.0, 0.0, 2.0, 70.0, color);
        this.Rect(badge, 78.0, 0.0, 2.0, 70.0, color);
        edge = this.Rect(badge, 0.0, 70.0, 55.0, 2.0, color); edge.SetRenderTransformPivot(0.0, 0.0); edge.SetRotation(40.0);
        edge = this.Rect(badge, 80.0, 70.0, 55.0, 2.0, color); edge.SetRenderTransformPivot(0.0, 0.0); edge.SetRotation(140.0);
        text = this.Label(badge, "NC", 4.0, 11.0, 72.0, 48.0, 38, color);
        text.SetHorizontalAlignment(textHorizontalAlignment.Center);
        this.Rect(badge, 20.0, 61.0, 40.0, 3.0, color);
        this.Rect(badge, 27.0, 70.0, 26.0, 3.0, color);
    }
    private func RefreshPage() -> Void {
        let section: String = "record";
        if !IsDefined(this.m_owner) || !this.m_owner.IsAttached() { return; };
        if this.m_section == 1 { section = "rewards"; };
        if this.m_section == 2 { section = "partners"; };
        this.m_revision += 1;
        this.m_deviceLogicController.LoadPageByAddress(s"NETdir://ncpd.career/\(section)?revision=\(this.m_revision)");
    }
    protected cb func OnClaimReleased(event: ref<inkPointerEvent>) -> Bool {
        let career: ref<NCPDPatrolCareerSystem>;
        if !event.IsAction(n"click") { return false; };
        career = this.Career();
        if !IsDefined(career) { return false; };
        career.ClaimNextReward();
        this.RefreshPage();
        return true;
    }
    protected cb func OnRefreshReleased(event: ref<inkPointerEvent>) -> Bool {
        if !event.IsAction(n"click") { return false; };
        this.m_startRequested = false;
        this.m_endRequested = false;
        this.RefreshPage(); return true;
    }
    protected cb func OnStartShiftReleased(event: ref<inkPointerEvent>) -> Bool {
        let player: ref<PlayerPuppet>;
        let patrol: ref<NCPDPatrolSystem>;
        if !event.IsAction(n"click") || this.m_startRequested || !IsDefined(this.Career()) || !NCPDPatrolMarkerSession.WorldReady() { return false; };
        player = GetPlayer(this.m_owner.GetGame());
        if !IsDefined(player) || !player.IsAttached() || player.IsDead() { return false; };
        patrol = NCPDPatrolSystem.Get(this.m_owner.GetGame());
        if !IsDefined(patrol) || patrol.IsOnDuty() { return false; };
        // Desired-state request, consumed by the existing CET shift controller.
        // This page never starts actors, awards or a second shift on its own.
        patrol.RequestDuty(false);
        this.m_startRequested = !patrol.HasWantedLevel();
        this.RefreshPage();
        return true;
    }
    protected cb func OnEndShiftReleased(event: ref<inkPointerEvent>) -> Bool {
        let player: ref<PlayerPuppet>;
        let patrol: ref<NCPDPatrolSystem>;
        if !event.IsAction(n"click") || this.m_endRequested || !IsDefined(this.Career()) || !NCPDPatrolMarkerSession.WorldReady() { return false; };
        player = GetPlayer(this.m_owner.GetGame());
        if !IsDefined(player) || !player.IsAttached() || player.IsDead() { return false; };
        patrol = NCPDPatrolSystem.Get(this.m_owner.GetGame());
        if !IsDefined(patrol) || !patrol.IsOnDuty() { return false; };
        // Keep the normal CET end-shift path responsible for actors/dispatch.
        // A stale end button can never request a new shift.
        patrol.RequestDuty(true);
        this.m_endRequested = true;
        this.RefreshPage();
        return true;
    }
    protected cb func OnServiceTabReleased(event: ref<inkPointerEvent>) -> Bool {
        if !event.IsAction(n"click") { return false; };
        this.m_section = 0; this.RefreshPage(); return true;
    }
    protected cb func OnRewardsTabReleased(event: ref<inkPointerEvent>) -> Bool {
        if !event.IsAction(n"click") { return false; };
        this.m_section = 1; this.RefreshPage(); return true;
    }
    protected cb func OnPartnerTabReleased(event: ref<inkPointerEvent>) -> Bool {
        if !event.IsAction(n"click") { return false; };
        this.m_section = 2; this.RefreshPage(); return true;
    }
    private func PartnerHandler(index: Int32) -> CName {
        if index == 0 { return n"OnStandardPartnerReleased"; };
        if index == 1 { return n"OnShotgunPartnerReleased"; };
        if index == 2 { return n"OnTacticalPartnerReleased"; };
        return n"OnMaxTacPartnerReleased";
    }
    private func AssignPartner(event: ref<inkPointerEvent>, index: Int32) -> Bool {
        let career: ref<NCPDPatrolCareerSystem>;
        if !event.IsAction(n"click") { return false; };
        career = this.Career();
        if !IsDefined(career) { return false; };
        career.SelectPartner(index); this.RefreshPage(); return true;
    }
    protected cb func OnStandardPartnerReleased(event: ref<inkPointerEvent>) -> Bool { return this.AssignPartner(event, 0); }
    protected cb func OnShotgunPartnerReleased(event: ref<inkPointerEvent>) -> Bool { return this.AssignPartner(event, 1); }
    protected cb func OnTacticalPartnerReleased(event: ref<inkPointerEvent>) -> Bool { return this.AssignPartner(event, 2); }
    protected cb func OnMaxTacPartnerReleased(event: ref<inkPointerEvent>) -> Bool { return this.AssignPartner(event, 3); }

    private func Sidebar(root: ref<inkCompoundWidget>, width: Float, height: Float, career: ref<NCPDPatrolCareerSystem>, duty: Bool) -> Void {
        let sidebar: ref<inkCanvas> = this.Canvas(root, n"NCPDPatrolCareerSidebar", 0.0, 96.0, width, height - 96.0);
        let rank: String = career.GetRank();
        let count: Int32 = career.GetRecordedActivities();
        let active: ref<inkCanvas>;
        let state: String = "OFF DUTY";
        let shiftLabel: String = "START SHIFT";
        let shiftHandler: CName = n"OnStartShiftReleased";
        this.Rect(sidebar, 0.0, 0.0, width, height - 96.0, this.Color(0.025, 0.058, 0.080, 1.0));
        this.Rect(sidebar, width - 1.0, 0.0, 1.0, height - 96.0, this.Line());
        this.Label(sidebar, "PERSONNEL DIVISION", 28.0, 30.0, width - 56.0, 30.0, 20, this.Muted());
        this.Badge(sidebar, 108.0, 94.0, this.Gold());
        this.Label(sidebar, rank, 28.0, 238.0, width - 56.0, 76.0, 30, this.White());
        this.Label(sidebar, "SERVICE STATUS", 28.0, 330.0, width - 56.0, 28.0, 18, this.Muted());
        if duty { state = "ON DUTY"; };
        this.Chip(sidebar, state, 28.0, 365.0, width - 56.0, this.Cyan());
        if duty {
            this.m_startRequested = false;
            shiftLabel = "END SHIFT";
            shiftHandler = n"OnEndShiftReleased";
            if this.m_endRequested { shiftLabel = "ENDING SHIFT"; };
        } else { this.m_endRequested = false; };
        if !duty && this.m_startRequested { shiftLabel = "SHIFT REQUESTED"; };
        this.m_dutyButton = this.Button(sidebar, shiftLabel, shiftHandler, 24.0, 414.0, width - 48.0, 44.0, true, !this.m_startRequested && !this.m_endRequested);
        this.Rect(sidebar, 28.0, 478.0, width - 56.0, 1.0, this.Line());
        this.m_serviceTab = this.Button(sidebar, "SERVICE RECORD", n"OnServiceTabReleased", 24.0, 502.0, width - 48.0, 60.0, false, true);
        this.m_rewardsTab = this.Button(sidebar, "REWARDS & EQUIPMENT", n"OnRewardsTabReleased", 24.0, 578.0, width - 48.0, 60.0, false, true);
        this.m_partnerTab = this.Button(sidebar, "PARTNER ASSIGNMENT", n"OnPartnerTabReleased", 24.0, 654.0, width - 48.0, 60.0, false, true);
        active = this.m_serviceTab;
        if this.m_section == 1 { active = this.m_rewardsTab; };
        if this.m_section == 2 { active = this.m_partnerTab; };
        this.Rect(active, 0.0, 0.0, 4.0, 60.0, this.Cyan());
        this.Label(sidebar, "CAREER INCIDENTS", 28.0, height - 280.0, width - 56.0, 28.0, 18, this.Muted());
        this.Label(sidebar, s"\(count) / 100", 28.0, height - 248.0, width - 56.0, 50.0, 36, this.White());
        this.Progress(sidebar, 28.0, height - 184.0, width - 56.0, 6.0, Cast<Float>(count) / 100.0, this.Cyan());
        this.Label(sidebar, "NETdir://ncpd.career", 28.0, height - 145.0, width - 56.0, 30.0, 17, this.Muted());
    }
    private func PageTitle(parent: ref<inkCompoundWidget>, title: String, section: String, width: Float) -> Void {
        this.Label(parent, section, 0.0, 0.0, width - 230.0, 28.0, 18, this.Cyan());
        this.Label(parent, title, 0.0, 30.0, width - 230.0, 66.0, 46, this.White());
        this.m_refreshButton = this.Button(parent, "REFRESH RECORD", n"OnRefreshReleased", width - 202.0, 20.0, 202.0, 48.0, false, true);
    }
    private func Stat(parent: ref<inkCompoundWidget>, x: Float, y: Float, width: Float, label: String, value: Int32) -> Void {
        let card: ref<inkCanvas> = this.Card(parent, n"NCPDPatrolServiceStatistic", x, y, width, 120.0, this.Line());
        this.Rect(card, 0.0, 0.0, 4.0, 120.0, this.Cyan());
        this.Label(card, s"\(value)", 24.0, 14.0, width - 48.0, 62.0, 46, this.White());
        this.Label(card, label, 24.0, 82.0, width - 48.0, 28.0, 18, this.Muted());
    }
    private func MilestoneName(index: Int32) -> String {
        if index == 0 { return "HELMET"; };
        if index == 1 { return "CORTES"; };
        if index == 2 { return "FIELD KIT"; };
        if index == 3 { return "BADGE SET"; };
        if index == 4 { return "TACTICAL"; };
        if index == 5 { return "HELLHOUND"; };
        return "MAXTAC";
    }
    private func Overview(parent: ref<inkCompoundWidget>, career: ref<NCPDPatrolCareerSystem>, width: Float, height: Float) -> Void {
        let left: Float = (width - 20.0) * 0.63;
        let right: Float = width - left - 20.0;
        let card: ref<inkCanvas>;
        let label: ref<inkText>;
        let rank: String = career.GetRank();
        let grade: Int32 = career.GetRankIndex() + 1;
        let grades: Int32 = career.MilestoneCount() + 1;
        let count: Int32 = career.GetRecordedActivities();
        let next: Int32 = career.GetNextMilestone();
        let into: Int32 = career.GetProgressInRank();
        let span: Int32 = career.GetRankSpan();
        let percent: Int32 = career.GetProgressPercent();
        let available: Int32 = career.GetAvailableRewards();
        let reward: String = career.GetNextReward();
        let name: String = career.GetSelectedPartnerName();
        let equipment: String = career.PartnerEquipment(career.GetSelectedPartnerIndex());
        let statWidth: Float = (width - 48.0) / 4.0;
        let track: ref<inkCanvas>;
        let cell: Float = (left - 48.0) / 7.0;
        let i: Int32 = 0;
        let threshold: Int32;
        let reached: Int32 = 0;
        let color: HDRColor;
        let short: String;
        this.PageTitle(parent, "Service record", "OFFICER SERVICES / CAREER OVERVIEW", width);
        card = this.Card(parent, n"NCPDPatrolOfficerSummary", 0.0, 110.0, left, 240.0, this.Cyan());
        this.Label(card, "CURRENT RANK", 26.0, 20.0, left - 52.0, 28.0, 18, this.Cyan());
        this.Badge(card, 28.0, 62.0, this.Gold());
        this.Label(card, rank, 136.0, 63.0, left - 162.0, 68.0, 44, this.White());
        this.Label(card, s"SERVICE GRADE  \(grade) / \(grades)", 136.0, 135.0, left - 162.0, 32.0, 20, this.Muted());
        this.Progress(card, 26.0, 184.0, left - 52.0, 12.0, Cast<Float>(percent) / 100.0, this.Cyan());
        if next > 0 {
            this.Label(card, s"\(into)/\(span) incidents in this rank  |  \(count)/\(next) total  |  \(percent)%", 26.0, 207.0, left - 52.0, 28.0, 20, this.White());
        } else {
            this.Label(card, "ALL CURRENT PROMOTION MILESTONES REACHED", 26.0, 207.0, left - 52.0, 28.0, 20, this.Cyan());
        };
        card = this.Card(parent, n"NCPDPatrolNextMilestone", left + 20.0, 110.0, right, 240.0, this.Line());
        this.Label(card, "NEXT MILESTONE", 24.0, 20.0, right - 48.0, 26.0, 18, this.Gold());
        if next > 0 {
            this.Label(card, s"\(next)", 24.0, 51.0, 120.0, 62.0, 48, this.White());
            this.Label(card, "INCIDENTS RESOLVED", 148.0, 69.0, right - 172.0, 30.0, 19, this.Muted());
        } else {
            this.Label(card, "SERVICE COMPLETE", 24.0, 63.0, right - 48.0, 48.0, 32, this.White());
        };
        this.Label(card, reward, 24.0, 119.0, right - 48.0, 64.0, 23, this.White());
        this.Button(card, "VIEW REWARDS", n"OnRewardsTabReleased", 24.0, 190.0, right - 48.0, 36.0, false, true);
        this.Stat(parent, 0.0, 370.0, statWidth, "INCIDENTS RESOLVED", count);
        this.Stat(parent, statWidth + 16.0, 370.0, statWidth, "COMPLETED DISPATCHES", career.GetRecordedDispatches());
        this.Stat(parent, (statWidth + 16.0) * 2.0, 370.0, statWidth, "ARRESTS RECORDED", career.GetRecordedArrests());
        this.Stat(parent, (statWidth + 16.0) * 3.0, 370.0, statWidth, "SERVICE REWARDS ISSUED", career.GetClaimedRewards());
        track = this.Card(parent, n"NCPDPatrolCareerTimeline", 0.0, 510.0, left, height - 510.0, this.Line());
        this.Label(track, "MILESTONE TRACK", 24.0, 22.0, left - 48.0, 32.0, 23, this.White());
        this.Label(track, "Incident thresholds reached across all recorded shifts", 24.0, 62.0, left - 48.0, 28.0, 19, this.Muted());
        while i < career.MilestoneCount() {
            threshold = career.MilestoneThreshold(i);
            short = this.MilestoneName(i);
            color = this.Muted();
            if count >= threshold { color = this.Cyan(); reached += 1; };
            this.Rect(track, 24.0 + cell * Cast<Float>(i), 105.0, cell - 10.0, 3.0, color);
            label = this.Label(track, s"\(threshold)", 24.0 + cell * Cast<Float>(i), 125.0, cell - 10.0, 42.0, 28, color);
            label.SetHorizontalAlignment(textHorizontalAlignment.Center);
            label = this.Label(track, short, 24.0 + cell * Cast<Float>(i), 174.0, cell - 10.0, 28.0, 16, color);
            label.SetHorizontalAlignment(textHorizontalAlignment.Center);
            i += 1;
        };
        this.Label(track, s"\(reached) / 7 thresholds reached  |  \(available) rewards available", 24.0, 218.0, left - 48.0, 30.0, 20, this.Muted());
        this.m_claimButton = this.Button(track, "CLAIM NEXT REWARD", n"OnClaimReleased", 24.0, height - 510.0 - 76.0, left - 48.0, 50.0, true, available > 0);
        card = this.Card(parent, n"NCPDPatrolPartnerSummary", left + 20.0, 510.0, right, height - 510.0, this.Line());
        this.Label(card, "ASSIGNED PARTNER", 24.0, 22.0, right - 48.0, 30.0, 18, this.Cyan());
        this.Label(card, name, 24.0, 65.0, right - 48.0, 82.0, 32, this.White());
        this.Label(card, equipment, 24.0, 155.0, right - 48.0, 56.0, 23, this.Gold());
        this.Label(card, "For your next shift or partner replacement.", 24.0, 218.0, right - 48.0, 32.0, 19, this.Muted());
        this.Button(card, "CHANGE ASSIGNMENT", n"OnPartnerTabReleased", 24.0, height - 510.0 - 76.0, right - 48.0, 50.0, false, true);
    }
    private func RewardCategory(index: Int32) -> String {
        if index == 0 { return "PROTECTIVE EQUIPMENT"; };
        if index == 1 { return "PATROL VEHICLE"; };
        if index == 2 { return "FIELD KIT"; };
        if index == 3 { return "UNIFORM ALLOCATION"; };
        if index == 4 { return "TACTICAL EQUIPMENT"; };
        if index == 5 { return "ARMORED RESPONSE"; };
        return "MAXTAC ALLOCATION";
    }
    private func Rewards(parent: ref<inkCompoundWidget>, career: ref<NCPDPatrolCareerSystem>, width: Float, height: Float) -> Void {
        let column: Float = (width - 32.0) / 3.0;
        let rowHeight: Float = (height - 142.0 - 32.0) / 3.0;
        let i: Int32 = 0;
        let row: Int32 = 0;
        let col: Int32 = 0;
        let card: ref<inkCanvas>;
        let threshold: Int32;
        let reward: String;
        let status: String;
        let category: String;
        let tier: Int32;
        let part: Int32;
        let available: Int32 = career.GetAvailableRewards();
        let claimed: Int32 = career.GetClaimedRewards();
        let color: HDRColor;
        this.PageTitle(parent, "Service entitlements", "QUARTERMASTER / REWARDS & EQUIPMENT", width);
        this.Label(parent, s"\(claimed) / 7 allocations issued  |  \(available) available to collect", 0.0, 100.0, width, 30.0, 22, this.Muted());
        while i < career.MilestoneCount() {
            threshold = career.MilestoneThreshold(i);
            reward = career.RewardLabel(i);
            category = this.RewardCategory(i);
            status = career.MilestoneStatus(i);
            color = this.Muted();
            if Equals(status, "AVAILABLE") || Equals(status, "PARTIAL - RETRY") { color = this.Gold(); };
            if Equals(status, "CLAIMED") { color = this.Cyan(); };
            card = this.Card(parent, StringToName(s"NCPDPatrolReward\(threshold)"), (column + 16.0) * Cast<Float>(col), 142.0 + (rowHeight + 16.0) * Cast<Float>(row), column, rowHeight, color);
            this.Label(card, s"\(threshold)", 20.0, 12.0, 94.0, 58.0, 42, color);
            this.Chip(card, status, column - 172.0, 22.0, 150.0, color);
            this.Label(card, category, 20.0, 77.0, column - 40.0, 28.0, 18, this.Muted());
            this.Label(card, reward, 20.0, 111.0, column - 40.0, 70.0, 24, this.White());
            tier = 0; part = 0;
            while part < career.RewardPartCount(i) {
                if career.RewardWeaponTier(i, part) > 0 { tier = career.RewardWeaponTier(i, part); };
                part += 1;
            };
            if tier > 0 { this.Chip(card, s"TIER \(tier)", 20.0, rowHeight - 38.0, 86.0, this.Cyan()); };
            if threshold == 20 || threshold == 50 || threshold == 100 {
                this.Label(card, "+ PARTNER ACCESS", 124.0, rowHeight - 34.0, column - 144.0, 28.0, 17, this.Gold());
            };
            i += 1;
            col += 1;
            if col == 3 { col = 0; row += 1; };
        };
        card = this.Card(parent, n"NCPDPatrolCollectionDesk", column + 16.0, 142.0 + (rowHeight + 16.0) * 2.0, column * 2.0 + 16.0, rowHeight, this.Line());
        this.Label(card, "QUARTERMASTER DESK", 24.0, 22.0, column * 2.0 - 32.0, 28.0, 18, this.Cyan());
        this.Label(card, s"\(available) allocations awaiting collection", 24.0, 61.0, column * 2.0 - 32.0, 44.0, 30, this.White());
        this.Label(card, "Equipment goes to inventory. Vehicles become available in your garage. Collection does not spend service progress.", 24.0, 117.0, column * 2.0 - 404.0, rowHeight - 129.0, 20, this.Muted());
        this.m_claimButton = this.Button(card, "CLAIM NEXT REWARD", n"OnClaimReleased", column * 2.0 - 352.0, rowHeight - 72.0, 344.0, 50.0, true, available > 0);
    }
    private func PartnerRole(index: Int32) -> String {
        if index == 1 { return "SG"; };
        if index == 2 { return "LMG"; };
        if index == 3 { return "NET"; };
        return "AR";
    }
    private func PartnerBrief(index: Int32) -> String {
        if index == 1 { return "Close-range firearms assignment."; };
        if index == 2 { return "Heavy weapons assignment."; };
        if index == 3 { return "MaxTac specialist netrunner profile."; };
        return "General patrol assignment.";
    }
    private func Partners(parent: ref<inkCompoundWidget>, career: ref<NCPDPatrolCareerSystem>, width: Float, height: Float) -> Void {
        let column: Float = (width - 20.0) * 0.5;
        let rowHeight: Float = (height - 154.0 - 20.0) * 0.5;
        let i: Int32 = 0;
        let row: Int32 = 0;
        let col: Int32 = 0;
        let card: ref<inkCanvas>;
        let role: ref<inkCanvas>;
        let button: ref<inkCanvas>;
        let label: ref<inkText>;
        let name: String;
        let equipment: String;
        let brief: String;
        let roleName: String;
        let state: String;
        let action: String;
        let threshold: Int32;
        let count: Int32 = career.GetRecordedActivities();
        let fraction: Float;
        let unlocked: Bool;
        let selected: Bool;
        let color: HDRColor;
        name = career.GetSelectedPartnerName();
        this.PageTitle(parent, "Partner assignment", "PERSONNEL / AVAILABLE ASSIGNMENTS", width);
        this.Label(parent, s"Selected for your next shift or replacement: \(name)", 0.0, 100.0, width, 32.0, 22, this.Muted());
        while i < career.PartnerCount() {
            name = career.PartnerName(i); equipment = career.PartnerEquipment(i);
            brief = this.PartnerBrief(i); roleName = this.PartnerRole(i);
            threshold = career.PartnerThreshold(i);
            unlocked = career.IsPartnerUnlocked(i); selected = i == career.GetSelectedPartnerIndex();
            state = "LOCKED"; action = s"\(threshold) INCIDENTS REQUIRED"; color = this.Muted();
            if unlocked { state = "AVAILABLE"; action = "ASSIGN PARTNER"; color = this.Cyan(); };
            if selected { state = "SELECTED"; action = "ASSIGNED"; color = this.Gold(); };
            card = this.Card(parent, StringToName(s"NCPDPatrolPartner\(i)"), (column + 20.0) * Cast<Float>(col), 154.0 + (rowHeight + 20.0) * Cast<Float>(row), column, rowHeight, color);
            role = this.Card(card, n"NCPDPatrolPartnerRole", 24.0, 24.0, 80.0, 80.0, color);
            label = this.Label(role, roleName, 5.0, 18.0, 70.0, 42.0, 29, this.Cyan());
            label.SetHorizontalAlignment(textHorizontalAlignment.Center);
            this.Rect(role, 20.0, 66.0, 40.0, 3.0, color);
            this.Chip(card, state, column - 170.0, 24.0, 146.0, color);
            this.Label(card, name, 128.0, 62.0, column - 152.0, 64.0, 30, this.White());
            this.Label(card, brief, 24.0, 133.0, column - 48.0, 34.0, 20, this.Muted());
            this.Label(card, equipment, 24.0, 175.0, column - 48.0, 34.0, 23, this.Gold());
            fraction = 1.0;
            if threshold > 0 { fraction = Cast<Float>(count) / Cast<Float>(threshold); };
            if unlocked {
                this.Label(card, s"ACCESS GRANTED  /  \(threshold) incidents", 24.0, 220.0, column - 48.0, 28.0, 19, this.Cyan());
            } else {
                this.Label(card, s"SERVICE REQUIREMENT  /  \(count) of \(threshold) incidents", 24.0, 220.0, column - 48.0, 28.0, 19, this.Muted());
            };
            this.Progress(card, 24.0, 252.0, column - 48.0, 5.0, fraction, color);
            button = this.Button(card, action, this.PartnerHandler(i), 24.0, rowHeight - 70.0, column - 48.0, 48.0, unlocked && !selected, unlocked && !selected);
            ArrayPush(this.m_partnerButtons, button);
            i += 1;
            col += 1;
            if col == 2 { col = 0; row += 1; };
        };
    }
    public func GetWebPage(address: String) -> ref<inkCompoundWidget> {
        let root: ref<inkCanvas> = new inkCanvas();
        let design: ref<inkCanvas>;
        let content: ref<inkCanvas>;
        let status: ref<inkCanvas>;
        let career: ref<NCPDPatrolCareerSystem> = this.Career();
        let patrol: ref<NCPDPatrolSystem>;
        let viewport: Vector2;
        let scale: Float;
        let transform: Vector2;
        let width: Float;
        let height: Float;
        let mainWidth: Float;
        let mainHeight: Float;
        let duty: Bool;
        let fallback: Bool;
        let message: String;
        if IsDefined(this.m_state) { this.m_state.ReportPage(address); };
        this.ReleasePageCallbacks();
        this.m_section = 0;
        if StrContains(address, "/rewards") { this.m_section = 1; };
        if StrContains(address, "/partners") { this.m_section = 2; };
        if IsDefined(this.m_deviceLogicController) { viewport = this.m_deviceLogicController.NCPDPatrolCareerViewport(); };
        fallback = viewport.X < 1.0 || viewport.Y < 1.0;
        if fallback { viewport.X = 1920.0; viewport.Y = 1080.0; };
        scale = MinF(viewport.X / 1920.0, viewport.Y / 1080.0);
        width = viewport.X / scale; height = viewport.Y / scale;
        transform.X = scale; transform.Y = scale;
        root.SetName(n"NCPDPatrolCareerPage"); root.SetSize(viewport.X, viewport.Y); root.SetAnchor(inkEAnchor.Fill);
        design = this.Canvas(root, n"NCPDPatrolCareerDesign", 0.0, 0.0, width, height);
        design.SetRenderTransformPivot(0.0, 0.0); design.SetScale(transform);
        if IsDefined(this.m_state) { this.m_state.ReportLayout(viewport.X, viewport.Y, scale, fallback); };
        this.Rect(design, 0.0, 0.0, width, height, this.Ink());
        this.Rect(design, 0.0, 0.0, width, 96.0, this.Color(0.03, 0.075, 0.105, 1.0));
        this.Rect(design, 0.0, 94.0, width, 2.0, this.Cyan());
        this.Label(design, "NCPD", 28.0, 14.0, 210.0, 70.0, 54, this.White());
        this.Rect(design, 247.0, 22.0, 1.0, 52.0, this.Line());
        this.Label(design, "NIGHT CITY POLICE DEPARTMENT", 276.0, 17.0, width - 680.0, 30.0, 21, this.Cyan());
        this.Label(design, "PERSONNEL SERVICES NETWORK", 276.0, 51.0, width - 680.0, 26.0, 17, this.Muted());
        if !IsDefined(career) {
            this.Label(design, "Service record unavailable. Reopen the browser after loading your game.", 360.0, 180.0, width - 420.0, 120.0, 32, this.Gold());
            return root;
        };
        if career.IsTestUnlockActive() {
            this.Chip(design, "TEST UNLOCK ACTIVE", width - 330.0, 32.0, 296.0, this.Gold());
        } else {
            this.Label(design, "OFFICER ACCESS / NC", width - 330.0, 34.0, 296.0, 30.0, 21, this.Muted());
        };
        patrol = NCPDPatrolSystem.Get(this.m_owner.GetGame());
        if IsDefined(patrol) { duty = patrol.IsOnDuty(); };
        this.Sidebar(design, 300.0, height, career, duty);
        mainWidth = width - 372.0; mainHeight = height - 240.0;
        content = this.Canvas(design, n"NCPDPatrolCareerContent", 336.0, 128.0, mainWidth, mainHeight);
        if this.m_section == 1 {
            this.Rewards(content, career, mainWidth, mainHeight);
        } else {
            if this.m_section == 2 {
                this.Partners(content, career, mainWidth, mainHeight);
            } else {
                this.Overview(content, career, mainWidth, mainHeight);
            };
        };
        status = this.Card(design, n"NCPDPatrolLatestUpdate", 336.0, height - 96.0, mainWidth, 72.0, this.Line());
        this.Rect(status, 0.0, 0.0, 3.0, 72.0, this.Cyan());
        this.Label(status, "LATEST SERVICE UPDATE", 20.0, 7.0, mainWidth - 40.0, 22.0, 14, this.Cyan());
        message = career.GetLastStatus();
        this.Label(status, message, 20.0, 30.0, mainWidth - 40.0, 36.0, 20, this.White());
        return root;
    }
}

// Read the actual browser content viewport, excluding the computer's chrome.
@if(ModuleExists("BrowserExtension.System"))
@addMethod(BrowserController)
public func NCPDPatrolCareerViewport() -> Vector2 {
    let empty: Vector2;
    let content: ref<inkWidget> = inkWidgetRef.Get(this.m_pageContentRoot);
    if IsDefined(content) { return content.GetSize(); };
    return empty;
}

@if(ModuleExists("BrowserExtension.System"))
@addMethod(BrowserGameController)
public func NCPDPatrolCareerViewport() -> Vector2 {
    let empty: Vector2;
    let logic: wref<BrowserController> = inkWidgetRef.GetController(this.m_logicControllerRef) as BrowserController;
    if IsDefined(logic) { return logic.NCPDPatrolCareerViewport(); };
    return empty;
}

@if(ModuleExists("BrowserExtension.System"))
@addField(BrowserGameController)
private let m_ncpdPatrolCareerSite: ref<NCPDPatrolCareerSiteListener>;

@if(ModuleExists("BrowserExtension.System"))
@addMethod(BrowserGameController)
public func NCPDPatrolEnsureCareerSite() -> Void {
    if IsDefined(this.m_ncpdPatrolCareerSite) { return; };
    this.m_ncpdPatrolCareerSite = new NCPDPatrolCareerSiteListener();
    this.m_ncpdPatrolCareerSite.Init(this);
}

@if(ModuleExists("BrowserExtension.System"))
@wrapMethod(BrowserGameController)
protected cb func OnInitialize() -> Bool {
    let result: Bool = wrappedMethod();
    this.NCPDPatrolEnsureCareerSite(); return result;
}

@if(ModuleExists("BrowserExtension.System"))
@wrapMethod(BrowserController)
public final func SetWebsiteData() -> Void {
    if IsDefined(this.m_gameController) { this.m_gameController.NCPDPatrolEnsureCareerSite(); };
    wrappedMethod();
}

@if(ModuleExists("BrowserExtension.System"))
@wrapMethod(BrowserGameController)
protected cb func OnUninitialize() -> Bool {
    if IsDefined(this.m_ncpdPatrolCareerSite) { this.m_ncpdPatrolCareerSite.Uninit(); };
    this.m_ncpdPatrolCareerSite = null;
    return wrappedMethod();
}
