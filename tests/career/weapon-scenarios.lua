-- Tier eligibility follows the milestone, independent of V's level/current XP.
local f=CareerFixture
local expected={
 {index=2,part=1,tier=2,base='Items.Preset_Lexington_Military',quality='Quality.Uncommon'},
 {index=4,part=0,tier=3,base='Items.Preset_Masamune_Military',quality='Quality.Rare'},
 {index=6,part=3,tier=5,base='Items.Preset_Defender_Military',quality='Quality.Legendary'}}
f:Reset(100)
for _,v in ipairs(expected) do
 local grant=Career:RewardGrantRecord(v.index,v.part)
 assert(Career:RewardWeaponTier(v.index,v.part)==v.tier)
 assert(Career:RewardRecord(v.index,v.part)==v.base,'stable receipt identity changed')
 assert(TieredRewardRecords[grant].base==v.base and TieredRewardRecords[grant].quality==v.quality)
end
assert(Career:WeaponTierAtMilestone(0)==2 and Career:WeaponTierAtMilestone(2)==2)
assert(Career:WeaponTierAtMilestone(3)==3 and Career:WeaponTierAtMilestone(4)==3)
assert(Career:WeaponTierAtMilestone(5)==4 and Career:WeaponTierAtMilestone(6)==5)
assert(Career:WeaponTierAtMilestone(-1)==0 and Career:WeaponTierAtMilestone(7)==0)
assert(Career:RewardWeaponTier(2,0)==0 and Career:RewardWeaponTier(5,0)==0)
assert(Career:RewardLabel(2):find('Tier 2',1,true) and Career:RewardLabel(4):find('Tier 3',1,true))
assert(Career:RewardLabel(6):find('Tier 5',1,true))

-- A missing fixed-tier record cannot fall back to the old random-tier preset.
assert(Career:ClaimNextReward() and Career:ClaimNextReward())
local lex=Career:RewardGrantRecord(2,1)
f.missingRecords[lex]=true;assert(not Career:ClaimNextReward() and Career:GetIssuedParts(2)==1)
assert(not f.inventory['Items.Preset_Lexington_Military'] and not f.inventory[lex])
f.missingRecords={};assert(Career:ClaimNextReward() and f.inventory[lex]==1)
assert(ArrayContains(Career.m_issuedRewards,'Items.Preset_Lexington_Military'))
assert(not ArrayContains(Career.m_issuedRewards,lex))

-- Existing v0.11a claims remain consumed; no duplicate guns on upgrade/load.
f:Reset(100)
for index=0,Career:MilestoneCount()-1 do for part=0,Career:RewardPartCount(index)-1 do
 ArrayPush(Career.m_issuedRewards,Career:RewardRecord(index,part))
end end
Career:OnRestored(1,1)
assert(Career:GetClaimedRewards()==7 and not Career:ClaimNextReward() and #f.itemCalls==0)
assert(not Career:TestGiveTieredWeapons() and #f.itemCalls==0)
assert(Career:SetTestUnlocks(true) and Career:TestGiveTieredWeapons())
for _,v in ipairs(expected) do assert(f.inventory[Career:RewardGrantRecord(v.index,v.part)]==1) end
assert(Career:GetClaimedRewards()==7 and ArraySize(Career.m_issuedRewards)==16 and Core:GetRecordedScannerCount()==100)
assert(not Career:TestGiveTieredWeapons() and #f.itemCalls==3,'test button duplicated guns on double click')
Career:SetTestUnlocks(false);Career:SetTestUnlocks(true)
assert(not Career:TestGiveTieredWeapons() and #f.itemCalls==3)

-- Test retries issue remaining guns only and never write normal claim receipts.
f:Reset(0);Career:SetTestUnlocks(true)
local mas=Career:RewardGrantRecord(4,0);f.failItems[mas]=true
assert(not Career:TestGiveTieredWeapons() and f.inventory[lex]==1 and Career.m_testWeaponsIssued.n==1)
f.failItems={};assert(Career:TestGiveTieredWeapons())
assert(f.inventory[lex]==1 and f.inventory[mas]==1 and Career.m_testWeaponsIssued.n==3)
assert(Career.m_issuedRewards.n==0 and Core:GetRecordedScannerCount()==0 and #f.vehicleCalls==0)
assert(not Career:TestGiveTieredWeapons())
Career:OnRestored(1,1);assert(not Career:IsTestUnlockActive() and Career.m_testWeaponsIssued.n==0)
assert(not Career:TestGiveTieredWeapons());Career:SetTestUnlocks(true)
f.wanted=true;assert(not Career:TestGiveTieredWeapons());f.wanted=false
assert(Career:TestGiveTieredWeapons() and f.inventory[lex]==2)
