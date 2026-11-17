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
        this.Text("NCPDPatrol-Revive", "Revive Partner");
        this.Text("NCPDPatrol-Reviving", "Reviving Partner - stay close (3 s)");
    }
}
