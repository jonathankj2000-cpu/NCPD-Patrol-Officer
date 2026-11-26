// Temporary metadata experiment. Only the six private English Voss IDs are
// added to the game's native VO length report. No playback/scene overrides.
public class NCPDPatrolVossLengthTest extends ScriptableService {
    private let m_registered: Bool;
    private let m_callbacks: Int32;
    private let m_added: Int32;
    private let m_updated: Int32;
    private let m_verified: Int32;
    private let m_failure: String;

    protected cb func OnLoad() -> Void {
        let callbacks: ref<CallbackSystem> = GameInstance.GetCallbackSystem();
        this.m_registered = false;
        this.m_callbacks = 0;
        this.m_added = 0;
        this.m_updated = 0;
        this.m_verified = 0;
        this.m_failure = "No matching resource load observed yet";
        if !IsDefined(callbacks) { this.m_failure = "CallbackSystem unavailable"; return; };
        callbacks.UnregisterCallback(n"Resource/PostLoad", this, n"OnLengthsLoaded");
        callbacks.RegisterCallback(n"Resource/PostLoad", this, n"OnLengthsLoaded", true)
            .AddTarget(ResourceTarget.Path(r"base\\localization\\en-us\\stringidvariantlengthsreport.json"));
        this.m_registered = true;
    }

    protected cb func OnLengthsLoaded(event: ref<ResourceEvent>) -> Void {
        let resource: ref<JsonResource> = event.GetResource() as JsonResource;
        let map: ref<locVoiceoverLengthMap>;
        this.m_callbacks += 1;
        this.m_added = 0;
        this.m_updated = 0;
        this.m_verified = 0;
        if !IsDefined(resource) { this.m_failure = "Expected JsonResource"; return; };
        map = resource.root as locVoiceoverLengthMap;
        if !IsDefined(map) { this.m_failure = "Expected locVoiceoverLengthMap"; return; };
        this.ApplyLengths(map);
        this.m_verified = this.VerifyLengths(map);
        if this.m_verified == 6 {
            this.m_failure = "All six private native lengths read back correctly";
        } else {
            this.m_failure = "Length map readback incomplete";
        };
    }

    public func ApplyLengths(map: ref<locVoiceoverLengthMap>) -> Void {
        let i: Int32 = 0;
        let j: Int32;
        let found: Bool;
        let expected: CRUID;
        let seconds: Float;
        let entry: locVoLengthEntry;
        this.m_added = 0;
        this.m_updated = 0;
        if !IsDefined(map) { return; };
        while i < 6 {
            expected = this.OwnID(i);
            seconds = this.OwnLength(i);
            found = false;
            j = 0;
            while j < ArraySize(map.entries) {
                if CRUIDToHash(map.entries[j].stringId) == CRUIDToHash(expected) {
                    entry = map.entries[j];
                    entry.femaleLength = seconds;
                    entry.maleLength = seconds;
                    map.entries[j] = entry;
                    found = true;
                    this.m_updated += 1;
                };
                j += 1;
            };
            if !found {
                entry.stringId = expected;
                entry.femaleLength = seconds;
                entry.maleLength = seconds;
                ArrayPush(map.entries, entry);
                this.m_added += 1;
            };
            i += 1;
        };
    }

    public func VerifyLengths(map: ref<locVoiceoverLengthMap>) -> Int32 {
        let i: Int32 = 0;
        let j: Int32;
        let verified: Int32 = 0;
        let found: Bool;
        if !IsDefined(map) { return 0; };
        while i < 6 {
            found = false;
            j = 0;
            while j < ArraySize(map.entries) {
                if CRUIDToHash(map.entries[j].stringId) == CRUIDToHash(this.OwnID(i))
                    && map.entries[j].femaleLength == this.OwnLength(i)
                    && map.entries[j].maleLength == this.OwnLength(i) { found = true; };
                j += 1;
            };
            if found { verified += 1; };
            i += 1;
        };
        return verified;
    }

    public func OwnID(index: Int32) -> CRUID {
        if index == 0 { return HashToCRUID(7936178618028821476ul); };
        if index == 1 { return HashToCRUID(7936181916563706109ul); };
        if index == 2 { return HashToCRUID(7936180817052077898ul); };
        if index == 3 { return HashToCRUID(7936175319493936843ul); };
        if index == 4 { return HashToCRUID(7936174219982308632ul); };
        if index == 5 { return HashToCRUID(7936177518517193265ul); };
        return HashToCRUID(0ul);
    }

    public func OwnLength(index: Int32) -> Float {
        if index == 0 { return 13.871020317077637; };
        if index == 1 { return 20.035919189453125; };
        if index == 2 { return 9.63918399810791; };
        if index == 3 { return 27.167346954345703; };
        if index == 4 { return 20.035919189453125; };
        if index == 5 { return 10.605713844299316; };
        return 0.0;
    }

    public func GetDiagnostics() -> String {
        return s"Voss VO lengths | callback registered=\(this.m_registered) | resource callbacks=\(this.m_callbacks) | added=\(this.m_added) | updated=\(this.m_updated) | verified=\(this.m_verified)/6 | \(this.m_failure)";
    }
}
