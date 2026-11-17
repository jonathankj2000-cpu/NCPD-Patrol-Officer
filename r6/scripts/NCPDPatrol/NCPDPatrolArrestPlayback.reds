// Scoped native workspot callbacks. No payment, animation commands or NPC life
// changes occur here. A fresh listener belongs to one actor and arrest token.
public class NCPDPatrolArrestPlayback extends IScriptable {
    private let m_actor: wref<GameObject>;
    private let m_token: Int32;
    private let m_armed: Bool;
    private let m_setups: Int32;
    private let m_path: String;
    private let m_clip: CName;
    private let m_revision: Int32;
    private let m_seenLying: Bool;
    private let m_failed: Bool;
    private let m_finished: Bool;

    public func Arm(actor: ref<GameObject>, token: Int32) -> Void {
        this.m_actor = actor;
        this.m_token = token;
        this.m_armed = true;
        this.m_setups = 0;
        this.m_path = "";
        this.m_clip = n"None";
        this.m_revision = 0;
        this.m_seenLying = false;
        this.m_failed = false;
        this.m_finished = false;
    }

    public func Disarm() -> Void { this.m_armed = false; }
    public func GetPath() -> String { return this.m_path; }
    public func GetClip() -> CName { return this.m_clip; }
    public func GetRevision() -> Int32 { return this.m_revision; }
    public func HasSeenLying() -> Bool { return this.m_seenLying; }
    public func IsFailed() -> Bool { return this.m_failed; }
    public func IsFinished() -> Bool { return this.m_finished; }

    public func OwnsPlayback() -> Bool {
        return this.m_armed && this.m_setups == 1 && !this.m_failed && !this.m_finished
            && Equals(this.m_path, "base\\workspots\\common\\ground\\generic__lie_ground_lean_front_handcuffs_a__aggressive__01.workspot");
    }

    public func IsLyingClip() -> Bool {
        return Equals(this.m_clip, n"lie_ground_0__2h_back_handcuffs_a__01")
            || Equals(this.m_clip, n"lie_ground_0__2h_back_handcuffs_a__01__shuffle__01")
            || Equals(this.m_clip, n"lie_ground_0__2h_back_handcuffs_a__01__shuffle__02")
            || Equals(this.m_clip, n"lie_ground_0__2h_back_handcuffs_a__01__shuffle__03")
            || Equals(this.m_clip, n"lie_ground_0__2h_back_handcuffs_a__01__shuffle__04")
            || Equals(this.m_clip, n"lie_ground_0__2h_back_handcuffs_a__01__shuffle__05");
    }

    public func Matches(actor: ref<GameObject>, token: Int32) -> Bool {
        return this.m_actor == actor && this.m_token == token && this.OwnsPlayback() && this.IsLyingClip();
    }

    protected cb func OnInstanceCreated() -> Bool { return true; }
    protected cb func OnWorkspotStarted() -> Bool { return true; }
    protected cb func OnTeleportRequest() -> Bool { return true; }
    protected cb func OnMovementRequest() -> Bool { return true; }
    protected cb func OnSkipOverflow() -> Bool {
        if this.m_armed { this.m_failed = true; this.m_revision += 1; };
        return true;
    }

    protected cb func OnWorkspotSetup(path: String) -> Bool {
        if !this.m_armed { return true; };
        this.m_setups += 1;
        this.m_path = path;
        this.m_clip = n"None";
        this.m_revision += 1;
        // Another setup supersedes this request, including reuse of the same
        // bank by another device/mod. Do not control or pay the new context.
        if this.m_setups > 1 { this.Disarm(); };
        return true;
    }

    protected cb func OnAnimationChanged(animName: CName, workEntryID: WorkEntryId) -> Bool {
        if !this.m_armed { return true; };
        this.m_clip = animName;
        this.m_revision += 1;
        if this.OwnsPlayback() && this.IsLyingClip() { this.m_seenLying = true; };
        return true;
    }

    protected cb func OnAnimationMissing(animName: CName, workEntryID: WorkEntryId) -> Bool {
        if this.m_armed { this.m_failed = true; this.m_clip = n"None"; this.m_revision += 1; };
        return true;
    }

    protected cb func OnAnimationSkipped(animName: CName, workEntryID: WorkEntryId) -> Bool {
        if this.m_armed && Equals(animName, this.m_clip) { this.m_clip = n"None"; this.m_revision += 1; };
        return true;
    }

    protected cb func OnWorkspotFinished() -> Bool {
        if this.m_armed { this.m_finished = true; this.m_clip = n"None"; this.m_revision += 1; };
        return true;
    }

    protected cb func OnInstanceRemoved() -> Bool {
        return this.OnWorkspotFinished();
    }
}
