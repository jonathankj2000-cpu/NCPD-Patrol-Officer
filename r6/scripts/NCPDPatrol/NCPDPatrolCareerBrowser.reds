module NCPDPatrol.Career

@if(ModuleExists("BrowserExtension.System"))
import BrowserExtension.DataStructures.*
@if(ModuleExists("BrowserExtension.System"))
import BrowserExtension.Classes.*
@if(ModuleExists("BrowserExtension.System"))
import BrowserExtension.System.*

// Optional surface: no framework dependency is introduced to the career model
// or the rest of NCPD Patrol. Registration follows BEF's public listener API.
@if(ModuleExists("BrowserExtension.System"))
public class NCPDPatrolCareerSiteListener extends BrowserEventsListener {
    private let m_owner: wref<GameObject>;
    private let m_claimButton: wref<inkCanvas>;
    private let m_refreshButton: wref<inkCanvas>;
    private let m_revision: Int32;
    private let m_state: ref<NCPDPatrolCareerBrowserState>;

    public func Init(logic: ref<BrowserGameController>) -> Void {
        super.Init(logic);
        this.m_owner = this.m_deviceObject;
        this.m_siteData.address = "NETdir://ncpd.career";
        this.m_siteData.shortName = "NCPD Career";
        // Keep BEF's valid default icon until a dedicated icon is authored.
        this.m_revision = 0;
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
        super.Uninit();
    }
    private func ReleasePageCallbacks() -> Void {
        if IsDefined(this.m_claimButton) {
            this.m_claimButton.UnregisterFromCallback(n"OnRelease", this, n"OnClaimReleased");
        };
        if IsDefined(this.m_refreshButton) {
            this.m_refreshButton.UnregisterFromCallback(n"OnRelease", this, n"OnRefreshReleased");
        };
        this.m_claimButton = null;
        this.m_refreshButton = null;
    }
    private func Career() -> ref<NCPDPatrolCareerSystem> {
        if !IsDefined(this.m_owner) || !this.m_owner.IsAttached() { return null; };
        return NCPDPatrolCareerSystem.Get(this.m_owner.GetGame());
    }
    private func Color(red: Float, green: Float, blue: Float, alpha: Float) -> HDRColor {
        let color: HDRColor;
        color.Red = red;
        color.Green = green;
        color.Blue = blue;
        color.Alpha = alpha;
        return color;
    }
    private func AddText(parent: ref<inkCompoundWidget>, value: String, size: Int32, color: HDRColor) -> ref<inkText> {
        let text: ref<inkText> = new inkText();
        text.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
        text.SetFontStyle(n"Medium");
        text.SetFontSize(size);
        text.SetSize(1400.0, Cast<Float>(size) * 1.45);
        text.SetTintColor(color);
        text.SetText(value);
        text.SetInteractive(false);
        text.Reparent(parent);
        return text;
    }
    private func AddButton(parent: ref<inkCompoundWidget>, label: String, handler: CName, width: Float) -> ref<inkCanvas> {
        let button: ref<inkCanvas> = new inkCanvas();
        let background: ref<inkRectangle> = new inkRectangle();
        let text: ref<inkText>;
        button.SetSize(width, 54.0);
        button.SetMargin(0.0, 12.0, 20.0, 8.0);
        button.SetInteractive(true);
        background.SetAnchor(inkEAnchor.Fill);
        background.SetTintColor(this.Color(0.04, 0.28, 0.40, 1.0));
        background.SetInteractive(false);
        background.Reparent(button);
        text = this.AddText(button, label, 26, this.Color(0.92, 0.97, 1.0, 1.0));
        text.SetAnchor(inkEAnchor.Centered);
        text.SetAnchorPoint(0.5, 0.5);
        text.SetSize(width - 24.0, 40.0);
        text.SetHorizontalAlignment(textHorizontalAlignment.Center);
        button.RegisterToCallback(n"OnRelease", this, handler);
        button.Reparent(parent);
        return button;
    }
    private func RefreshPage() -> Void {
        if !IsDefined(this.m_owner) || !this.m_owner.IsAttached() { return; };
        this.m_revision += 1;
        this.m_deviceLogicController.LoadPageByAddress(s"NETdir://ncpd.career/record?revision=\(this.m_revision)");
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
        this.RefreshPage();
        return true;
    }
    public func GetWebPage(address: String) -> ref<inkCompoundWidget> {
        let root: ref<inkCanvas> = new inkCanvas();
        let background: ref<inkRectangle> = new inkRectangle();
        let body: ref<inkVerticalPanel> = new inkVerticalPanel();
        let bar: ref<inkCanvas>;
        let track: ref<inkRectangle>;
        let fill: ref<inkRectangle>;
        let actions: ref<inkHorizontalPanel>;
        let career: ref<NCPDPatrolCareerSystem> = this.Career();
        let white: HDRColor = this.Color(0.88, 0.94, 0.98, 1.0);
        let blue: HDRColor = this.Color(0.28, 0.76, 0.95, 1.0);
        let grey: HDRColor = this.Color(0.55, 0.66, 0.72, 1.0);
        let gold: HDRColor = this.Color(0.96, 0.78, 0.32, 1.0);
        let rowColor: HDRColor;
        let rank: String;
        let count: Int32;
        let next: Int32;
        let into: Int32;
        let span: Int32;
        let percent: Int32;
        let dispatches: Int32;
        let arrests: Int32;
        let available: Int32;
        let i: Int32 = 0;
        let threshold: Int32;
        let promotion: String;
        let reward: String;
        let status: String;
        if IsDefined(this.m_state) { this.m_state.ReportPage(address); };
        this.ReleasePageCallbacks();
        root.SetName(n"NCPDPatrolCareerPage");
        root.SetSize(1600.0, 1000.0);
        root.SetAnchor(inkEAnchor.Fill);
        background.SetAnchor(inkEAnchor.Fill);
        background.SetTintColor(this.Color(0.02, 0.045, 0.065, 1.0));
        background.Reparent(root);
        body.SetMargin(56.0, 28.0, 40.0, 24.0);
        body.SetSize(1400.0, 940.0);
        body.SetFitToContent(true);
        body.Reparent(root);
        this.AddText(body, "NIGHT CITY POLICE DEPARTMENT // PERSONNEL SERVICES", 24, blue);
        this.AddText(body, "CAREER SERVICE RECORD", 48, white);
        if !IsDefined(career) {
            this.AddText(body, "Service record unavailable. Reopen the browser after loading your game.", 28, gold);
            return root;
        };
        rank = career.GetRank();
        count = career.GetRecordedActivities();
        next = career.GetNextMilestone();
        into = career.GetProgressInRank();
        span = career.GetRankSpan();
        percent = career.GetProgressPercent();
        dispatches = career.GetRecordedDispatches();
        arrests = career.GetRecordedArrests();
        available = career.GetAvailableRewards();
        this.AddText(body, s"RANK  //  \(rank)", 36, gold);
        if next > 0 {
            this.AddText(body, s"PROMOTION PROGRESS  \(into)/\(span) activities in this rank  |  \(count)/\(next) total", 26, white);
        } else {
            this.AddText(body, "ALL CURRENT PROMOTION MILESTONES REACHED", 26, blue);
        };
        bar = new inkCanvas();
        bar.SetSize(1000.0, 18.0);
        bar.SetMargin(0.0, 8.0, 0.0, 12.0);
        bar.Reparent(body);
        track = new inkRectangle();
        track.SetSize(1000.0, 18.0);
        track.SetTintColor(this.Color(0.08, 0.16, 0.21, 1.0));
        track.Reparent(bar);
        fill = new inkRectangle();
        fill.SetSize(Cast<Float>(percent) * 10.0, 18.0);
        fill.SetTintColor(blue);
        fill.Reparent(bar);
        this.AddText(body, s"ON-DUTY ACTIVITIES  \(count)     COMPLETED DISPATCHES  \(dispatches)     ARRESTS  \(arrests)", 24, white);
        if next > 0 {
            reward = career.GetNextReward();
            this.AddText(body, s"NEXT REWARD  //  \(next) recorded activities  //  \(reward)", 28, gold);
        } else {
            this.AddText(body, "NEXT REWARD  //  All current milestones unlocked", 28, gold);
        };
        this.AddText(body, "SERVICE MILESTONES", 28, blue);
        while i < career.MilestoneCount() {
            threshold = career.MilestoneThreshold(i);
            promotion = career.RankName(i + 1);
            reward = career.RewardLabel(i);
            status = career.MilestoneStatus(i);
            rowColor = grey;
            if Equals(status, "AVAILABLE") { rowColor = gold; };
            if Equals(status, "CLAIMED") { rowColor = blue; };
            this.AddText(body, s"\(threshold) activities  |  \(promotion)  |  \(reward)  |  \(status)", 24, rowColor);
            i += 1;
        };
        actions = new inkHorizontalPanel();
        actions.SetFitToContent(true);
        actions.Reparent(body);
        this.m_claimButton = this.AddButton(actions, s"CLAIM REWARD  (\(available) available)", n"OnClaimReleased", 500.0);
        this.m_refreshButton = this.AddButton(actions, "REFRESH RECORD", n"OnRefreshReleased", 300.0);
        status = career.GetLastStatus();
        this.AddText(body, status, 24, white);
        this.AddText(body, "Progress includes scanner activities recorded by NCPD Patrol while on duty, across shifts.", 21, grey);
        this.AddText(body, "Dispatches and arrests have separate records. Claiming a service reward does not spend progress.", 21, grey);
        return root;
    }
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
    this.NCPDPatrolEnsureCareerSite();
    return result;
}

// The native game controller calls SetWebsiteData before loading homepage data.
// Register here too, before BEF composes the custom slots, without depending on
// which mod's OnInitialize wrapper is outermost.
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
