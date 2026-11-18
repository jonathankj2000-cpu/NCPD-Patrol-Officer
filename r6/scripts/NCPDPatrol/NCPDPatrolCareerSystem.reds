// Career reads the existing scanner ledger. Test unlocks never fabricate activity
// records. Each successfully issued reward part has its own save-local receipt.
public class NCPDPatrolCareerSystem extends ScriptableSystem {
    // Keep the v0.10 cash ledger for save compatibility. Those cash claims must
    // not consume the new equipment/vehicle rewards at overlapping thresholds.
    private persistent let m_claimedMilestones: array<Int32>;
    private persistent let m_issuedRewards: array<TweakDBID>;
    private persistent let m_selectedPartner: Int32;
    private let m_testUnlocks: Bool;
    private let m_testWeaponsIssued: array<TweakDBID>;
    private let m_lastStatus: String;

    public static func Get(game: GameInstance) -> ref<NCPDPatrolCareerSystem> {
        return GameInstance.GetScriptableSystemsContainer(game).Get(n"NCPDPatrolCareerSystem") as NCPDPatrolCareerSystem;
    }
    public func Version() -> Int32 { return 3; }
    private func OnAttach() -> Void {
        this.m_testUnlocks = false;
        ArrayClear(this.m_testWeaponsIssued);
        this.m_lastStatus = "Service record ready";
    }
    private func OnRestored(saveVersion: Int32, gameVersion: Int32) -> Void {
        this.m_testUnlocks = false;
        ArrayClear(this.m_testWeaponsIssued);
        this.m_lastStatus = "Service record restored";
    }
    public func MilestoneCount() -> Int32 { return 7; }
    public func MilestoneThreshold(index: Int32) -> Int32 {
        if index == 0 { return 5; };
        if index == 1 { return 10; };
        if index == 2 { return 20; };
        if index == 3 { return 35; };
        if index == 4 { return 50; };
        if index == 5 { return 75; };
        if index == 6 { return 100; };
        return 0;
    }
    public func RankName(index: Int32) -> String {
        if index == 0 { return "Probationary Officer"; };
        if index == 1 { return "Police Officer"; };
        if index == 2 { return "Patrol Officer"; };
        if index == 3 { return "Senior Officer"; };
        if index == 4 { return "Corporal"; };
        if index == 5 { return "Sergeant"; };
        if index == 6 { return "Lieutenant"; };
        return "Captain";
    }
    public func RewardPartCount(index: Int32) -> Int32 {
        if index < 0 || index >= this.MilestoneCount() { return 0; };
        if index == 2 { return 4; };
        if index == 3 || index == 6 { return 4; };
        if index == 4 { return 2; };
        return 1;
    }
    // Record identity, rather than rank/index, is the durable receipt key.
    public func RewardRecord(index: Int32, part: Int32) -> String {
        if part < 0 || part >= this.RewardPartCount(index) { return ""; };
        if index == 0 { return "Items.Helmet_02_basic_01"; };
        if index == 1 { return "Vehicle.v_standard2_villefort_cortes_police"; };
        if index == 2 {
            if part == 0 { return "Items.Vest_03_basic_01"; };
            if part == 1 { return "Items.Preset_Lexington_Military"; };
            if part == 2 { return "Vehicle.v_standard25_thorton_merrimac_police"; };
            return "Items.NCPDBeanBagger_M2038";
        };
        if index == 3 {
            if part == 0 { return "Items.Cop_01_Set_Jacket"; };
            if part == 1 { return "Items.Cop_01_Set_Pants"; };
            if part == 2 { return "Items.Cop_01_Set_Boots"; };
            return "Items.Cop_01_Set_Glasses";
        };
        if index == 4 {
            if part == 0 { return "Items.Preset_Masamune_Military"; };
            return "Vehicle.v_standard3_chevalier_emperor_police";
        };
        if index == 5 { return "Vehicle.v_standard3_militech_hellhound_police"; };
        if index == 6 {
            if part == 0 { return "Items.SQ030_MaxTac_Helmet"; };
            if part == 1 { return "Items.SQ030_MaxTac_Chest"; };
            if part == 2 { return "Items.SQ030_MaxTac_Pants"; };
            return "Items.Preset_Defender_Military";
        };
        return "";
    }
    public func RewardLabel(index: Int32) -> String {
        if index == 0 { return "NCPD anti-shrapnel helmet"; };
        if index == 1 { return "Villefort Cortes NCPD Overlord"; };
        if index == 2 { return "NCPD vest + Lexington Military (Tier 2) + Merrimac Police + Bean Bagger T2"; };
        if index == 3 { return "Full NCPD Badge Set (4 pieces)"; };
        if index == 4 { return "Masamune Military (Tier 3) + Emperor NCPD Ironclad"; };
        if index == 5 { return "Militech Hellhound Man o' War"; };
        if index == 6 { return "MaxTac gear (3 pieces) + Defender Military (Tier 5)"; };
        return "No further reward scheduled";
    }
    public func WeaponTierAtMilestone(index: Int32) -> Int32 {
        let incidents: Int32 = this.MilestoneThreshold(index);
        if incidents <= 0 { return 0; };
        if incidents <= 20 { return 2; };
        if incidents <= 50 { return 3; };
        if incidents <= 75 { return 4; };
        return 5;
    }
    public func RewardWeaponTier(index: Int32, part: Int32) -> Int32 {
        let name: String = this.RewardRecord(index, part);
        if Equals(name, "Items.NCPDBeanBagger_M2038") { return 2; };
        if Equals(name, "Items.Preset_Lexington_Military") || Equals(name, "Items.Preset_Masamune_Military")
            || Equals(name, "Items.Preset_Defender_Military") {
            return this.WeaponTierAtMilestone(index);
        };
        return 0;
    }
    // Preserve the original RewardRecord as the durable receipt key. Only the
    // item delivered changes; old claims must not silently become claimable again.
    public func RewardGrantRecord(index: Int32, part: Int32) -> String {
        let name: String = this.RewardRecord(index, part);
        // The handoff's stable public ID is already a fixed Tier 2 record.
        if Equals(name, "Items.NCPDBeanBagger_M2038") { return name; };
        let tier: Int32 = this.RewardWeaponTier(index, part);
        if tier > 0 { return s"\(name)_NCPDPatrol_Tier\(tier)"; };
        return name;
    }
    public func PartnerCount() -> Int32 { return 4; }
    public func PartnerThreshold(index: Int32) -> Int32 {
        if index == 0 { return 0; };
        if index == 1 { return 20; };
        if index == 2 { return 50; };
        if index == 3 { return 100; };
        return -1;
    }
    public func PartnerName(index: Int32) -> String {
        if index == 1 { return "NCPD Shotgun Enforcer"; };
        if index == 2 { return "NCPD Tactical Officer"; };
        if index == 3 { return "MaxTac Netrunner"; };
        return "Standard NCPD Patrol Officer";
    }
    public func PartnerEquipment(index: Int32) -> String {
        if index == 1 { return "Zhuo shotgun"; };
        if index == 2 { return "M2067 Defender"; };
        if index == 3 { return "Omaha / Kappa; netrunner archetype"; };
        return "Copperhead assault rifle";
    }
    public func PartnerRecord(index: Int32) -> String {
        if index == 1 { return "Character.nok_ncpd_enforcer_shotgun2_tactician_ma_rare"; };
        if index == 2 { return "Character.ncpd_hwp_gunner2_defender_mb_rare"; };
        if index == 3 { return "Character.maxtac_av_netrunner_ma"; };
        return "Character.cvi_ncpd_police_ranged2_copperhead_ma";
    }
    public func IsSupportedPartnerRecord(record: TweakDBID) -> Bool {
        let i: Int32 = 0;
        while i < this.PartnerCount() {
            if Equals(record, TDBID.Create(this.PartnerRecord(i))) { return true; };
            i += 1;
        };
        return false;
    }
    private func UnlockCount() -> Int32 {
        let count: Int32 = this.GetRecordedActivities();
        if this.m_testUnlocks && count < 100 { return 100; };
        return count;
    }
    public func IsPartnerUnlocked(index: Int32) -> Bool {
        let threshold: Int32 = this.PartnerThreshold(index);
        return threshold >= 0 && this.UnlockCount() >= threshold;
    }
    public func GetSelectedPartnerIndex() -> Int32 {
        if this.IsPartnerUnlocked(this.m_selectedPartner) { return this.m_selectedPartner; };
        return 0;
    }
    public func GetSelectedPartnerName() -> String { return this.PartnerName(this.GetSelectedPartnerIndex()); }
    public func GetSelectedPartnerRecord() -> String { return this.PartnerRecord(this.GetSelectedPartnerIndex()); }
    public func SelectPartner(index: Int32) -> Bool {
        let name: String;
        if !this.CanClaim() {
            this.m_lastStatus = "Partner selection unavailable during combat, wanted status or an unloaded game";
            return false;
        };
        if !this.IsPartnerUnlocked(index) {
            this.m_lastStatus = "Partner locked; complete the required on-duty incidents first";
            return false;
        };
        this.m_selectedPartner = index;
        name = this.PartnerName(index);
        this.m_lastStatus = s"PARTNER ASSIGNED: \(name). Applies at shift start or Request new partner.";
        return true;
    }
    public func IsTestUnlockActive() -> Bool { return this.m_testUnlocks; }
    public func SetTestUnlocks(enabled: Bool) -> Bool {
        if enabled && !this.CanClaim() { return false; };
        this.m_testUnlocks = enabled;
        if enabled {
            this.m_lastStatus = "TEST UNLOCK ACTIVE: all rewards and partners available. Recorded incidents unchanged.";
        } else {
            this.m_lastStatus = "Test unlocks cleared. Normal incident requirements apply.";
        };
        return true;
    }
    public func TestGiveTieredWeapons() -> Bool {
        let transaction: ref<TransactionSystem> = GameInstance.GetTransactionSystem(this.GetGameInstance());
        let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
        let index: Int32 = 0;
        let part: Int32;
        let issued: Int32 = 0;
        let receipt: TweakDBID;
        let grant: TweakDBID;
        if !this.m_testUnlocks || !this.CanClaim() || !IsDefined(transaction) {
            this.m_lastStatus = "Enable TEST unlocks first; weapon testing requires a loaded, safe game.";
            return false;
        };
        while index < this.MilestoneCount() {
            part = 0;
            while part < this.RewardPartCount(index) {
                if this.RewardWeaponTier(index, part) > 0 {
                    receipt = TDBID.Create(this.RewardRecord(index, part));
                    if !ArrayContains(this.m_testWeaponsIssued, receipt) {
                        grant = TDBID.Create(this.RewardGrantRecord(index, part));
                        if !transaction.GiveItem(player, ItemID.FromTDBID(grant), 1) {
                            this.m_lastStatus = "Test weapon delivery incomplete; retry issues remaining test weapons only.";
                            return false;
                        };
                        ArrayPush(this.m_testWeaponsIssued, receipt);
                        issued += 1;
                    };
                };
                part += 1;
            };
            index += 1;
        };
        if issued == 0 {
            this.m_lastStatus = "Tiered test weapons already issued this session. Load a save to start a fresh test.";
            return false;
        };
        this.m_lastStatus = "TEST WEAPONS ISSUED: Bean Bagger Tier 2, Lexington Tier 2, Masamune Tier 3, Defender Tier 5. Career claims unchanged.";
        return true;
    }

    public func TestGiveBeanBagger() -> Bool {
        let transaction: ref<TransactionSystem> = GameInstance.GetTransactionSystem(this.GetGameInstance());
        let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
        let record: TweakDBID = t"Items.NCPDBeanBagger_M2038";
        if !this.CanClaim() || !IsDefined(transaction) {
            this.m_lastStatus = "Bean Bagger test requires a loaded game, outside combat and without wanted status.";
            return false;
        };
        if ArrayContains(this.m_testWeaponsIssued, record) {
            this.m_lastStatus = "Bean Bagger test copy already issued this session. Career claims unchanged.";
            return false;
        };
        if !transaction.GiveItem(player, ItemID.FromTDBID(record), 1) {
            this.m_lastStatus = "Bean Bagger unavailable. Install the complete package, including its TweakXL file, and restart.";
            return false;
        };
        ArrayPush(this.m_testWeaponsIssued, record);
        this.m_lastStatus = "TEST BEAN BAGGER ISSUED: Tier 2. Career claims unchanged. Check actual living/downed targets before arrest.";
        return true;
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
    public func GetIssuedParts(index: Int32) -> Int32 {
        let part: Int32 = 0;
        let count: Int32 = 0;
        while part < this.RewardPartCount(index) {
            if ArrayContains(this.m_issuedRewards, TDBID.Create(this.RewardRecord(index, part))) { count += 1; };
            part += 1;
        };
        return count;
    }
    public func HasClaimed(index: Int32) -> Bool {
        return this.RewardPartCount(index) > 0 && this.GetIssuedParts(index) == this.RewardPartCount(index);
    }
    public func MilestoneStatus(index: Int32) -> String {
        if index < 0 || index >= this.MilestoneCount() { return "UNAVAILABLE"; };
        if this.HasClaimed(index) { return "CLAIMED"; };
        if this.UnlockCount() >= this.MilestoneThreshold(index) {
            if this.GetIssuedParts(index) > 0 { return "PARTIAL - RETRY"; };
            return "AVAILABLE";
        };
        return "LOCKED";
    }
    private func NextAvailableReward() -> Int32 {
        let i: Int32 = 0;
        let count: Int32 = this.UnlockCount();
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
            if this.UnlockCount() >= this.MilestoneThreshold(i) && !this.HasClaimed(i) { count += 1; };
            i += 1;
        };
        return count;
    }
    public func GetClaimedRewards() -> Int32 {
        let index: Int32 = 0;
        let count: Int32 = 0;
        while index < this.MilestoneCount() {
            if this.HasClaimed(index) { count += 1; };
            index += 1;
        };
        return count;
    }
    public func GetLastStatus() -> String { return this.m_lastStatus; }
    private func CanClaim() -> Bool {
        let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
        let patrol: ref<NCPDPatrolSystem> = NCPDPatrolSystem.Get(this.GetGameInstance());
        // Computer access is allowed off duty. Browser menus are not a blocker.
        return IsDefined(player) && player.IsAttached() && !player.IsDead() && !player.IsInCombat()
            && IsDefined(patrol) && !patrol.HasWantedLevel();
    }
    private func GrantRewardPart(index: Int32, part: Int32) -> Bool {
        let transaction: ref<TransactionSystem> = GameInstance.GetTransactionSystem(this.GetGameInstance());
        let vehicles: ref<VehicleSystem> = GameInstance.GetVehicleSystem(this.GetGameInstance());
        let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
        let name: String = this.RewardRecord(index, part);
        let record: TweakDBID;
        if Equals(name, "") { return false; };
        record = TDBID.Create(name);
        if ArrayContains(this.m_issuedRewards, record) { return true; };
        if StrBeginsWith(name, "Vehicle.") {
            if !IsDefined(vehicles) { return false; };
            if !vehicles.IsVehiclePlayerUnlocked(record) {
                if !vehicles.EnablePlayerVehicle(name, true, false) { return false; };
                if !vehicles.IsVehiclePlayerUnlocked(record) { return false; };
            };
        } else {
            if !IsDefined(transaction) || !transaction.GiveItem(player, ItemID.FromTDBID(TDBID.Create(this.RewardGrantRecord(index, part))), 1) { return false; };
        };
        ArrayPush(this.m_issuedRewards, record);
        return true;
    }
    public func ClaimNextReward() -> Bool {
        let index: Int32;
        let threshold: Int32;
        let part: Int32 = 0;
        let issued: Int32;
        let total: Int32;
        let patrol: ref<NCPDPatrolSystem>;
        if !this.CanClaim() {
            this.m_lastStatus = "Reward unavailable during combat, wanted status or an unloaded game";
            return false;
        };
        index = this.NextAvailableReward();
        if index < 0 { this.m_lastStatus = "No unclaimed milestone reward is available"; return false; };
        threshold = this.MilestoneThreshold(index);
        total = this.RewardPartCount(index);
        while part < total {
            if !this.GrantRewardPart(index, part) {
                issued = this.GetIssuedParts(index);
                this.m_lastStatus = s"REWARD INCOMPLETE: \(issued)/\(total) parts issued at \(threshold) incidents. Retry collects remaining parts only.";
                return false;
            };
            part += 1;
        };
        this.m_lastStatus = s"REWARD ISSUED: \(threshold) incidents | " + this.RewardLabel(index);
        patrol = NCPDPatrolSystem.Get(this.GetGameInstance());
        patrol.NotifyDispatch(this.m_lastStatus, 8.0);
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
