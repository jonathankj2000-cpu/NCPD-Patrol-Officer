import Codeware.Localization.*

// Native interaction captions resolve the TweakDB caption key, not just the
// ScriptableDeviceAction's custom caption. Register both keys with Codeware.
public class NCPDPatrolLocalizationProvider extends ModLocalizationProvider {
    public func GetPackage(language: CName) -> ref<ModLocalizationPackage> {
        if Equals(language, n"en-us") { return new NCPDPatrolEnglishText(); }
        return null;
    }

    public func GetFallback() -> CName { return n"en-us"; }
}

public class NCPDPatrolEnglishText extends ModLocalizationPackage {
    protected func DefineTexts() -> Void {
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
        this.Text("NCPDPatrol-CloseMenu", "Close Patrol Menu");
        this.Text("NCPDPatrol-Revive", "Revive Partner");
        this.Text("NCPDPatrol-Reviving", "Reviving Partner - stay close (3 s)");
        this.Text("NCPDPatrol-Arrest", "Arrest suspect");
        this.Text("NCPDPatrol-Arresting", "Arresting suspect - stay close");
    }
}
