local f=CareerFixture
-- Real scanner records determine rank; rewards never add activity credits.
local ranks={{0,'Probationary Officer',0,5},{4,'Probationary Officer',80,5},
 {5,'Police Officer',0,10},{9,'Police Officer',80,10},{10,'Patrol Officer',0,20},
 {15,'Patrol Officer',50,20},{20,'Senior Officer',0,35},{35,'Corporal',0,50},
 {50,'Sergeant',0,75},{75,'Lieutenant',0,100},{99,'Lieutenant',96,100},
 {100,'Captain',100,0},{150,'Captain',100,0}}
for _,v in ipairs(ranks) do
 f:Reset(v[1]);assert(Career:GetRank()==v[2] and Career:GetProgressPercent()==v[3] and Career:GetNextMilestone()==v[4])
 assert(Core:GetRecordedScannerCount()==v[1] and Career:GetRecordedDispatches()==4 and Career:GetRecordedArrests()==7 and wallet==0)
end
local expected={
 {'Items.Helmet_02_basic_01'}, {'Vehicle.v_standard2_villefort_cortes_police'},
 {'Items.Vest_03_basic_01','Items.Preset_Lexington_Military','Vehicle.v_standard25_thorton_merrimac_police','Items.NCPDBeanBagger_M2038'},
 {'Items.Cop_01_Set_Jacket','Items.Cop_01_Set_Pants','Items.Cop_01_Set_Boots','Items.Cop_01_Set_Glasses'},
 {'Items.Preset_Masamune_Military','Vehicle.v_standard3_chevalier_emperor_police'},
 {'Vehicle.v_standard3_militech_hellhound_police'},
 {'Items.SQ030_MaxTac_Helmet','Items.SQ030_MaxTac_Chest','Items.SQ030_MaxTac_Pants','Items.Preset_Defender_Military'}}
local thresholds={5,10,20,35,50,75,100}
f:Reset(4);assert(not Career:ClaimNextReward() and #f.itemCalls==0 and #f.vehicleCalls==0)
f:Reset(100)
-- Migrating from prototype cash receipts cannot consume equipment rewards.
for _,n in ipairs({10,20,40,60,80,100}) do ArrayPush(Career.m_claimedMilestones,n) end
assert(Career:GetAvailableRewards()==7 and Career:GetClaimedRewards()==0)
for i,records in ipairs(expected) do
 assert(Career:MilestoneThreshold(i-1)==thresholds[i] and Career:RewardPartCount(i-1)==#records)
 assert(Career:ClaimNextReward() and Career:GetClaimedRewards()==i)
 for p,record in ipairs(records) do
  assert(Career:RewardRecord(i-1,p-1)==record)
  if record:find('Vehicle.',1,true)==1 then assert(f.unlockedVehicles[record])
  else assert(f.inventory[Career:RewardGrantRecord(i-1,p-1)]==1) end
 end
 assert(Career:MilestoneStatus(i-1)=='CLAIMED')
end
assert(#f.itemCalls==13 and #f.vehicleCalls==4 and #f.notices==7 and wallet==0)
assert(not Career:ClaimNextReward() and Career:GetAvailableRewards()==0)
Career:OnRestored(1,1);assert(not Career:ClaimNextReward() and #f.itemCalls==13 and #f.vehicleCalls==4)
assert(Core:GetRecordedScannerCount()==100 and Career:GetRecordedDispatches()==4 and Career:GetRecordedArrests()==7)
assert(f.notices[3].text:find('20 incidents',1,true) and f.notices[3].duration==8)
-- Reward cars must work with trunk/chatter, while ambient/stolen cars cannot.
local function car(record,owned,audio)
 return {IsPlayerVehicle=function() return owned end,GetRecordID=function() return record end,
  GetRecord=function() return {Player_audio_resource=function() return audio or '' end} end}
end
for _,records in ipairs(expected) do for _,record in ipairs(records) do
 if record:find('Vehicle.',1,true)==1 then
  assert(Core:IsOwnedPoliceVehicle(car(record,true)) and not Core:IsOwnedPoliceVehicle(car(record,false)))
 end
end end
assert(not Core:IsOwnedPoliceVehicle(car('Vehicle.v_standard2_archer_hella_player',true,'hella')))
assert(Core:IsOwnedPoliceVehicle(car('Vehicle.external_police',true,'modded_police')))

-- Composite reward failures retain successful parts, including across load.
f:Reset(20);assert(Career:ClaimNextReward());assert(Career:ClaimNextReward())
f.failItems['Items.Preset_Lexington_Military_NCPDPatrol_Tier2']=true
assert(not Career:ClaimNextReward() and Career:GetIssuedParts(2)==1 and Career:MilestoneStatus(2)=='PARTIAL - RETRY')
Career:OnRestored(1,1);f.failItems={};f.vehiclePresent=false
assert(not Career:ClaimNextReward() and Career:GetIssuedParts(2)==2)
f.vehiclePresent=true;f.enableAccepted=false;assert(not Career:ClaimNextReward() and Career:GetIssuedParts(2)==2)
f.enableAccepted=true;f.unlockConfirmed=false
assert(not Career:ClaimNextReward() and Career:GetIssuedParts(2)==2,'unconfirmed garage unlock was recorded')
f.unlockConfirmed=true;assert(Career:ClaimNextReward() and Career:GetIssuedParts(2)==4)
assert(f.inventory['Items.Vest_03_basic_01']==1 and f.inventory['Items.Preset_Lexington_Military_NCPDPatrol_Tier2']==1)
assert(not Career:ClaimNextReward() and #f.notices==3)
f:Reset(10);transactionPresent=false;assert(not Career:ClaimNextReward() and Career:GetClaimedRewards()==0)
transactionPresent=true;paymentOK=false;assert(not Career:ClaimNextReward())
paymentOK=true;assert(Career:ClaimNextReward());f.unlockedVehicles['Vehicle.v_standard2_villefort_cortes_police']=true
assert(Career:ClaimNextReward() and #f.vehicleCalls==0,'already-owned vehicle enabled again')

-- Test unlocks don't fake progress, grant automatically or survive loading.
f:Reset(0);assert(Career:SetTestUnlocks(true) and Career:IsTestUnlockActive())
assert(Career:GetAvailableRewards()==7 and Career:IsPartnerUnlocked(3) and Career:GetRank()=='Probationary Officer')
assert(Core:GetRecordedScannerCount()==0 and #f.itemCalls==0 and #f.vehicleCalls==0 and #f.notices==0)
assert(Career:SelectPartner(3) and Career:ClaimNextReward())
assert(Career:SetTestUnlocks(false) and Career:GetAvailableRewards()==0 and Career:GetSelectedPartnerIndex()==0)
assert(f.inventory['Items.Helmet_02_basic_01']==1 and Career:SetTestUnlocks(true) and Career:GetAvailableRewards()==6)
Career:OnRestored(1,1)
assert(not Career:IsTestUnlockActive() and not Career:IsPartnerUnlocked(3) and Career:GetSelectedPartnerIndex()==0)
assert(Career:HasClaimed(0) and Core:GetRecordedScannerCount()==0)
for index,threshold in ipairs({0,20,50,100}) do
 f:Reset(math.max(0,threshold-1));if threshold>0 then assert(not Career:SelectPartner(index-1)) end
 f:SetCount(threshold);assert(Career:SelectPartner(index-1) and Career:GetSelectedPartnerIndex()==index-1)
 local record=Career:GetSelectedPartnerRecord();Career:OnRestored(1,1)
 assert(Career:GetSelectedPartnerRecord()==record and Career:GetSelectedPartnerIndex()==index-1)
end
assert(not Career:SelectPartner(-1) and not Career:SelectPartner(4))
Career.m_selectedPartner=999;assert(Career:GetSelectedPartnerIndex()==0)
f:Reset(100);f.wanted=true
assert(not Career:ClaimNextReward() and not Career:SelectPartner(3) and not Career:SetTestUnlocks(true));f.wanted=false
local player=GetPlayer();player.combat=true;assert(not Career:ClaimNextReward() and not Career:SelectPartner(3));player.combat=false
player.dead=true;assert(not Career:ClaimNextReward());player.dead=false
player.attached=false;assert(not Career:ClaimNextReward());player.attached=true
f.ready=false;assert(not Career:ClaimNextReward());f.ready=true
assert(#f.itemCalls==0 and Career:ClaimNextReward() and Career:SelectPartner(3),'off-duty claim/assignment blocked')
