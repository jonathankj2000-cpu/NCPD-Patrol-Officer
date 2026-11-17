// One clean-start playback request. This proves native activation, not the
// rendered clip. A production result can acknowledge/reject the exact helper;
// if it is absent, continuous native activation supplies the slower fallback.
public class NCPDPatrolArrestPlayback extends IScriptable {
    private let m_actor: wref<NPCPuppet>;
    private let m_helper: wref<GameObject>;
    private let m_token: Int32;
    private let m_armed: Bool;
    private let m_seenActive: Bool;
    private let m_finished: Bool;
    private let m_hasResult: Bool;
    private let m_resultSuccess: Bool;
    private let m_stable: Float;
    private let m_present: Bool;
    private let m_active: Bool;
    private let m_entering: Bool;
    private let m_exiting: Bool;

    private func IsActorValid() -> Bool {
        if !IsDefined(this.m_actor) || !IsDefined(this.m_helper) { return false; };
        if !this.m_actor.IsAttached() || !this.m_helper.IsAttached() { return false; };
        if this.m_actor.IsDead() || this.m_actor.IsDeadNoStatPool() { return false; };
        if VehicleComponent.IsMountedToVehicle(this.m_actor.GetGame(), this.m_actor) { return false; };
        if !ScriptedPuppet.IsDefeated(this.m_actor) && !ScriptedPuppet.IsUnconscious(this.m_actor) { return false; };
        return true;
    }

    public func Arm(actor: ref<NPCPuppet>, helper: ref<GameObject>, token: Int32) -> Bool {
        let workspots: ref<WorkspotGameSystem>;
        this.m_actor = actor;
        this.m_helper = helper;
        this.m_token = token;
        this.m_armed = false;
        this.m_seenActive = false;
        this.m_finished = false;
        this.m_hasResult = false;
        this.m_resultSuccess = false;
        this.m_stable = 0.0;
        this.m_present = false;
        this.m_active = false;
        this.m_entering = false;
        this.m_exiting = false;
        if !this.IsActorValid() { return false; };
        workspots = GameInstance.GetWorkspotSystem(actor.GetGame());
        if !IsDefined(workspots) || workspots.IsActorInWorkspot(actor) { return false; };
        this.m_armed = true;
        return true;
    }

    public func AcceptResult(helperID: EntityID, success: Bool) -> Bool {
        let expectedID: EntityID;
        if !this.m_armed || this.m_hasResult || !IsDefined(this.m_helper) { return false; };
        expectedID = this.m_helper.GetEntityID();
        if helperID.hash != expectedID.hash { return false; };
        this.m_hasResult = true;
        this.m_resultSuccess = success;
        if !success { this.Disarm(); };
        return true;
    }

    public func Tick(delta: Float, paused: Bool) -> Void {
        let workspots: ref<WorkspotGameSystem>;
        let info: ref<ExtendedWorkspotInfo>;
        if !this.m_armed || paused || delta <= 0.0 || delta > 0.5 { return; };
        if !this.IsActorValid() { this.Disarm(); return; };
        workspots = GameInstance.GetWorkspotSystem(this.m_actor.GetGame());
        if !IsDefined(workspots) { this.Disarm(); return; };
        info = workspots.GetExtendedInfo(this.m_actor);
        if !IsDefined(info) { this.m_stable = 0.0; return; };
        this.m_present = workspots.IsActorInWorkspot(this.m_actor);
        this.m_active = info.isActive;
        this.m_entering = info.entering;
        this.m_exiting = info.exiting;
        if this.m_exiting || (this.m_seenActive && (!this.m_present || (!this.m_active && !this.m_entering))) { this.Disarm(); return; };
        if !this.m_present || !this.m_active || this.m_entering { this.m_stable = 0.0; return; };
        this.m_seenActive = true;
        this.m_stable += delta;
        if this.m_stable > 1.5 { this.m_stable = 1.5; };
    }

    public func IsActive() -> Bool {
        let workspots: ref<WorkspotGameSystem>;
        let info: ref<ExtendedWorkspotInfo>;
        if !this.m_armed || !this.m_seenActive || !this.IsActorValid() { return false; };
        workspots = GameInstance.GetWorkspotSystem(this.m_actor.GetGame());
        if !IsDefined(workspots) || !workspots.IsActorInWorkspot(this.m_actor) { return false; };
        info = workspots.GetExtendedInfo(this.m_actor);
        return IsDefined(info) && info.isActive && !info.entering && !info.exiting;
    }

    public func RequiredTime() -> Float { if this.m_hasResult && this.m_resultSuccess { return 0.75; }; return 1.5; }
    public func Matches(actor: ref<NPCPuppet>, token: Int32) -> Bool {
        return this.m_actor == actor && this.m_token == token && this.m_stable >= this.RequiredTime() && this.IsActive();
    }
    public func Disarm() -> Void { this.m_armed = false; this.m_finished = true; this.m_stable = 0.0; }
    public func IsFinished() -> Bool { return this.m_finished; }
    public func HasResult() -> Bool { return this.m_hasResult; }
    public func ResultSucceeded() -> Bool { return this.m_resultSuccess; }
    public func StableTime() -> Float { return this.m_stable; }
    public func IsPresent() -> Bool { return this.m_present; }
    public func NativeActive() -> Bool { return this.m_active; }
    public func Entering() -> Bool { return this.m_entering; }
    public func Exiting() -> Bool { return this.m_exiting; }
}
