// Career reads the existing scanner ledger; it never adds scanner/dispatch XP.
// Claimed service milestones are stored in the same save as the granted money.
public class NCPDPatrolCareerSystem extends ScriptableSystem {
    private persistent let m_claimedMilestones: array<Int32>;
    private let m_lastStatus: String;

    public static func Get(game: GameInstance) -> ref<NCPDPatrolCareerSystem> {
        return GameInstance.GetScriptableSystemsContainer(game).Get(n"NCPDPatrolCareerSystem") as NCPDPatrolCareerSystem;
    }
    public func Version() -> Int32 { return 1; }
    private func OnAttach() -> Void { this.m_lastStatus = "Service record ready"; }
    private func OnRestored(saveVersion: Int32, gameVersion: Int32) -> Void {
        this.m_lastStatus = "Service record restored";
    }
    public func MilestoneCount() -> Int32 { return 6; }
    public func MilestoneThreshold(index: Int32) -> Int32 {
        if index == 0 { return 10; };
        if index == 1 { return 20; };
        if index == 2 { return 40; };
        if index == 3 { return 60; };
        if index == 4 { return 80; };
        if index == 5 { return 100; };
        return 0;
    }
    public func RankName(index: Int32) -> String {
        if index == 0 { return "Probationary Officer"; };
        if index == 1 { return "Patrol Officer"; };
        if index == 2 { return "Senior Officer"; };
        if index == 3 { return "Corporal"; };
        if index == 4 { return "Sergeant"; };
        if index == 5 { return "Lieutenant"; };
        return "Captain";
    }
    // Prototype reward catalog. Future vehicle/item rewards belong here and in
    // GrantReward, without changing counting, rank math or the browser widgets.
    public func RewardKind(index: Int32) -> CName {
        if index < 0 || index >= this.MilestoneCount() { return n"None"; };
        return n"Money";
    }
    public func RewardAmount(index: Int32) -> Int32 {
        if index < 0 || index >= this.MilestoneCount() { return 0; };
        return 1000;
    }
    public func RewardLabel(index: Int32) -> String {
        let amount: Int32 = this.RewardAmount(index);
        if amount <= 0 { return "No further reward scheduled"; };
        return s"Service bonus: €$\(amount)";
    }
    public func GetRecordedActivities() -> Int32 {
        let patrol: ref<NCPDPatrolSystem> = NCPDPatrolSystem.Get(this.GetGameInstance());
        let count: Int32;
        if !IsDefined(patrol) { return 0; };
        count = patrol.GetRecordedScannerCount();
        if count < 0 { return 0; };
        return count;
    }
    public func GetRankIndex() -> Int32 {
        let count: Int32 = this.GetRecordedActivities();
        let i: Int32 = 0;
        while i < this.MilestoneCount() {
            if count < this.MilestoneThreshold(i) { return i; };
            i += 1;
        };
        return this.MilestoneCount();
    }
    public func GetRank() -> String { return this.RankName(this.GetRankIndex()); }
    public func GetProgressInRank() -> Int32 {
        let rank: Int32 = this.GetRankIndex();
        if rank >= this.MilestoneCount() { return 0; };
        if rank == 0 { return this.GetRecordedActivities(); };
        return this.GetRecordedActivities() - this.MilestoneThreshold(rank - 1);
    }
    public func GetRankSpan() -> Int32 {
        let rank: Int32 = this.GetRankIndex();
        if rank >= this.MilestoneCount() { return 0; };
        if rank == 0 { return this.MilestoneThreshold(0); };
        return this.MilestoneThreshold(rank) - this.MilestoneThreshold(rank - 1);
    }
    public func GetProgressPercent() -> Int32 {
        let span: Int32 = this.GetRankSpan();
        if span <= 0 { return 100; };
        return this.GetProgressInRank() * 100 / span;
    }
    public func GetNextMilestone() -> Int32 { return this.MilestoneThreshold(this.GetRankIndex()); }
    public func GetNextReward() -> String { return this.RewardLabel(this.GetRankIndex()); }
    public func GetRecordedDispatches() -> Int32 {
        let dispatch: ref<NCPDPatrolDispatchJournalSystem> = NCPDPatrolDispatchJournalSystem.Get(this.GetGameInstance());
        if !IsDefined(dispatch) { return 0; };
        return dispatch.GetPaidDispatches() + dispatch.GetPendingDispatchRewards();
    }
    public func GetRecordedArrests() -> Int32 {
        let arrest: ref<NCPDPatrolArrestSystem> = NCPDPatrolArrestSystem.Get(this.GetGameInstance());
        if !IsDefined(arrest) { return 0; };
        return arrest.GetPaidArrests();
    }
    public func HasClaimed(index: Int32) -> Bool {
        let threshold: Int32 = this.MilestoneThreshold(index);
        return threshold > 0 && ArrayContains(this.m_claimedMilestones, threshold);
    }
    public func MilestoneStatus(index: Int32) -> String {
        if index < 0 || index >= this.MilestoneCount() { return "UNAVAILABLE"; };
        if this.HasClaimed(index) { return "CLAIMED"; };
        if this.GetRecordedActivities() >= this.MilestoneThreshold(index) { return "AVAILABLE"; };
        return "LOCKED";
    }
    private func NextAvailableReward() -> Int32 {
        let i: Int32 = 0;
        let count: Int32 = this.GetRecordedActivities();
        while i < this.MilestoneCount() {
            if count >= this.MilestoneThreshold(i) && !this.HasClaimed(i) { return i; };
            i += 1;
        };
        return -1;
    }
    public func GetAvailableRewards() -> Int32 {
        let i: Int32 = 0;
        let count: Int32 = 0;
        while i < this.MilestoneCount() {
            if this.GetRecordedActivities() >= this.MilestoneThreshold(i) && !this.HasClaimed(i) { count += 1; };
            i += 1;
        };
        return count;
    }
    public func GetClaimedRewards() -> Int32 { return ArraySize(this.m_claimedMilestones); }
    public func GetLastStatus() -> String { return this.m_lastStatus; }
    private func CanClaim() -> Bool {
        let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
        let patrol: ref<NCPDPatrolSystem> = NCPDPatrolSystem.Get(this.GetGameInstance());
        // Computer access is allowed off duty. Browser menus are not a blocker.
        return IsDefined(player) && player.IsAttached() && !player.IsDead() && !player.IsInCombat()
            && IsDefined(patrol) && !patrol.HasWantedLevel();
    }
    private func GrantReward(index: Int32) -> Bool {
        let transaction: ref<TransactionSystem> = GameInstance.GetTransactionSystem(this.GetGameInstance());
        let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
        let amount: Int32 = this.RewardAmount(index);
        if !Equals(this.RewardKind(index), n"Money") || amount <= 0 || !IsDefined(transaction) { return false; };
        return transaction.GiveItem(player, ItemID.FromTDBID(t"Items.money"), amount);
    }
    public func ClaimNextReward() -> Bool {
        let index: Int32;
        let threshold: Int32;
        let amount: Int32;
        let patrol: ref<NCPDPatrolSystem>;
        if !this.CanClaim() {
            this.m_lastStatus = "Reward unavailable during combat, wanted status or an unloaded game";
            return false;
        };
        index = this.NextAvailableReward();
        if index < 0 { this.m_lastStatus = "No unclaimed milestone reward is available"; return false; };
        if !this.GrantReward(index) {
            this.m_lastStatus = "Reward payment failed; nothing claimed. Try again.";
            return false;
        };
        threshold = this.MilestoneThreshold(index);
        amount = this.RewardAmount(index);
        ArrayPush(this.m_claimedMilestones, threshold);
        this.m_lastStatus = s"REWARD PAID: +€$\(amount) | \(threshold)-activity milestone";
        patrol = NCPDPatrolSystem.Get(this.GetGameInstance());
        patrol.NotifyCareerReward(amount, threshold);
        return true;
    }
    public func GetSummary() -> String {
        let rank: String = this.GetRank();
        let count: Int32 = this.GetRecordedActivities();
        let next: Int32 = this.GetNextMilestone();
        let reward: String = this.GetNextReward();
        let available: Int32 = this.GetAvailableRewards();
        if next == 0 { return s"NCPD CAREER | \(rank) | Recorded activities: \(count) | All milestones reached | Rewards available: \(available)"; };
        return s"NCPD CAREER | \(rank) | Activities: \(count)/\(next) | Next reward: \(reward) | Rewards available: \(available)";
    }
}
