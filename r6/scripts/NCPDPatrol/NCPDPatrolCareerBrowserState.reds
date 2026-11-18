module NCPDPatrol.Career

@if(ModuleExists("BrowserExtension.System"))
import BrowserExtension.System.*
@if(ModuleExists("BrowserExtension.System"))
import BrowserExtension.DataStructures.*

// Transient diagnostics only. Does not alter progression, awards or BEF settings.
public class NCPDPatrolCareerBrowserState extends ScriptableSystem {
    private let m_browser: wref<BrowserGameController>;
    private let m_open: Bool;
    private let m_hooks: Int32;
    private let m_sites: Int32;
    private let m_found: Bool;
    private let m_requests: Int32;
    private let m_lastAddress: String;
    private let m_viewportWidth: Float;
    private let m_viewportHeight: Float;
    private let m_layoutScale: Float;
    private let m_layoutFallback: Bool;
    public static func Get(game: GameInstance) -> ref<NCPDPatrolCareerBrowserState> {
        return GameInstance.GetScriptableSystemsContainer(game).Get(n"NCPDPatrol.Career.NCPDPatrolCareerBrowserState") as NCPDPatrolCareerBrowserState;
    }
    public func Version() -> Int32 { return 1; }
    private func OnAttach() -> Void { this.ForgetWorld(); }
    private func OnRestored(saveVersion: Int32, gameVersion: Int32) -> Void { this.ForgetWorld(); }
    private func ForgetWorld() -> Void {
        this.m_browser = null;
        this.m_open = false;
        this.m_hooks = 0;
        this.m_sites = 0;
        this.m_found = false;
        this.m_requests = 0;
        this.m_lastAddress = "none";
        this.m_viewportWidth = 0.0;
        this.m_viewportHeight = 0.0;
        this.m_layoutScale = 0.0;
        this.m_layoutFallback = false;
    }
    public func ReportBrowser(browser: ref<BrowserGameController>) -> Void {
        this.m_browser = browser;
        this.m_open = IsDefined(browser);
        this.m_hooks += 1;
        this.CheckRegistry();
    }
    public func ReportClosed() -> Void {
        this.m_browser = null;
        this.m_open = false;
    }
    public func ReportPage(address: String) -> Void {
        this.m_requests += 1;
        this.m_lastAddress = address;
    }
    public func ReportLayout(width: Float, height: Float, scale: Float, fallback: Bool) -> Void {
        this.m_viewportWidth = width;
        this.m_viewportHeight = height;
        this.m_layoutScale = scale;
        this.m_layoutFallback = fallback;
    }
    @if(ModuleExists("BrowserExtension.System"))
    private func CheckRegistry() -> Void {
        let sites: array<CustomInternetSite>;
        let i: Int32 = 0;
        if !IsDefined(this.m_browser) { return; };
        sites = this.m_browser.GetCustomSites();
        this.m_sites = ArraySize(sites);
        this.m_found = false;
        while i < ArraySize(sites) {
            if Equals(sites[i].address, "NETdir://ncpd.career") { this.m_found = true; };
            i += 1;
        };
    }
    @if(!ModuleExists("BrowserExtension.System"))
    private func CheckRegistry() -> Void {}

    @if(ModuleExists("BrowserExtension.System"))
    private func FrameworkStatus() -> String {
        let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
        let system: ref<BrowserExtensionSystem>;
        let enabled: Bool;
        let bypass: Bool;
        let blocked: Bool;
        if !IsDefined(player) || !player.IsAttached() { return "BEF module=present | load a save to check runtime"; };
        system = BrowserExtensionSystem.GetInstance(player);
        if !IsDefined(system) { return "BEF module=present | runtime system unavailable"; };
        enabled = system.IsEnabled();
        bypass = system.ShouldBypassBrowserExtension();
        blocked = system.IsAddressBlocked("NETdir://ncpd.career");
        return s"BEF module=present | enabled=\(enabled) | bypass=\(bypass) | address blocked=\(blocked)";
    }
    @if(!ModuleExists("BrowserExtension.System"))
    private func FrameworkStatus() -> String {
        return "BEF module=MISSING at script compilation; the optional career page was not compiled";
    }
    public func GetDiagnostics() -> String {
        let framework: String = this.FrameworkStatus();
        this.CheckRegistry();
        return s"\(framework) | browser open=\(this.m_open) | init hooks=\(this.m_hooks) | last registry sites=\(this.m_sites) | career registered=\(this.m_found) | page requests=\(this.m_requests) | viewport=\(this.m_viewportWidth)x\(this.m_viewportHeight) | UI scale=\(this.m_layoutScale) | fallback=\(this.m_layoutFallback) | last=\(this.m_lastAddress)";
    }
    @if(ModuleExists("BrowserExtension.System"))
    public func OpenCareer() -> Bool {
        let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
        let system: ref<BrowserExtensionSystem>;
        if !this.m_open || !IsDefined(this.m_browser) || !IsDefined(player) || !player.IsAttached() { return false; };
        system = BrowserExtensionSystem.GetInstance(player);
        if !IsDefined(system) || !system.IsEnabled() || system.ShouldBypassBrowserExtension()
            || system.IsAddressBlocked("NETdir://ncpd.career") { return false; };
        this.m_browser.LoadPageByAddress("NETdir://ncpd.career");
        return true;
    }
    @if(!ModuleExists("BrowserExtension.System"))
    public func OpenCareer() -> Bool { return false; }
}
