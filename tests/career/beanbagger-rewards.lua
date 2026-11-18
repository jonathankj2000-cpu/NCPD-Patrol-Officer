local f=CareerFixture
local id='Items.NCPDBeanBagger_M2038'
-- Upgrade a save with every pre-Bean-Bagger reward already claimed: only the
-- newly appended part reopens, and existing equipment/vehicles are not reissued.
f:Reset(100)
for index=0,Career:MilestoneCount()-1 do for part=0,Career:RewardPartCount(index)-1 do
 local record=Career:RewardRecord(index,part)
 if record~=id then ArrayPush(Career.m_issuedRewards,record) end
end end
assert(Career.m_issuedRewards.n==16 and Career:GetIssuedParts(2)==3 and Career:GetAvailableRewards()==1)
Career:OnRestored(1,1)
assert(Career:ClaimNextReward() and #f.itemCalls==1 and f.itemCalls[1]==id and #f.vehicleCalls==0)
assert(not Career:ClaimNextReward() and Career.m_issuedRewards.n==17 and Core:GetRecordedScannerCount()==100)
-- A failed Bean Bagger delivery keeps all three prior receipts for a safe retry.
f:Reset(20);assert(Career:ClaimNextReward() and Career:ClaimNextReward());f.failItems[id]=true
assert(not Career:ClaimNextReward() and Career:GetIssuedParts(2)==3 and Career:MilestoneStatus(2)=='PARTIAL - RETRY')
local count=#f.itemCalls;Career:OnRestored(1,1);f.failItems={}
assert(Career:ClaimNextReward() and #f.itemCalls==count+1 and f.itemCalls[#f.itemCalls]==id)
assert(f.inventory['Items.Vest_03_basic_01']==1 and f.inventory['Items.Preset_Lexington_Military_NCPDPatrol_Tier2']==1)
-- The dedicated button works without a milestone override. Test receipts are
-- transient and separate from normal reward receipts and real incident counts.
f:Reset(0);f.wanted=true;assert(not Career:TestGiveBeanBagger());f.wanted=false
GetPlayer().combat=true;assert(not Career:TestGiveBeanBagger());GetPlayer().combat=false
f.missingRecords[id]=true;assert(not Career:TestGiveBeanBagger() and Career.m_testWeaponsIssued.n==0)
f.missingRecords={};assert(Career:TestGiveBeanBagger() and f.inventory[id]==1)
assert(not Career:IsTestUnlockActive() and Career.m_issuedRewards.n==0 and Core:GetRecordedScannerCount()==0)
assert(not Career:TestGiveBeanBagger() and f.inventory[id]==1)
Career:SetTestUnlocks(true);assert(Career:TestGiveTieredWeapons() and f.inventory[id]==1)
assert(Career.m_testWeaponsIssued.n==4 and Career.m_issuedRewards.n==0)
Career:OnRestored(1,1);assert(Career:TestGiveBeanBagger() and f.inventory[id]==2)
