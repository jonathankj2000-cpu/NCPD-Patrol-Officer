local f=CareerFixture
-- Existing save progress is read, never reconstructed from nearby scanners.
local ranks={
 {0,'Probationary Officer',0,10},{9,'Probationary Officer',90,10},
 {10,'Patrol Officer',0,20},{15,'Patrol Officer',50,20},
 {20,'Senior Officer',0,40},{39,'Senior Officer',95,40},
 {40,'Corporal',0,60},{60,'Sergeant',0,80},{80,'Lieutenant',0,100},
 {99,'Lieutenant',95,100},{100,'Captain',100,0},{150,'Captain',100,0}
}
for _,v in ipairs(ranks) do
 f:Reset(v[1]);assert(Career:GetRank()==v[2]);assert(Career:GetProgressPercent()==v[3]);assert(Career:GetNextMilestone()==v[4])
 assert(Career:GetRecordedActivities()==v[1] and Career:GetRecordedDispatches()==4 and Career:GetRecordedArrests()==7)
 assert(Core:GetRecordedScannerCount()==v[1] and wallet==0)
end
f:Reset(9);assert(not Career:ClaimNextReward() and wallet==0)
f:SetCount(10);assert(Career:GetAvailableRewards()==1 and Career:MilestoneStatus(0)=='AVAILABLE')
assert(Career:ClaimNextReward() and wallet==1000 and Career:GetClaimedRewards()==1)
assert(Career:MilestoneStatus(0)=='CLAIMED' and not Career:ClaimNextReward() and wallet==1000)
assert(Core:GetRecordedScannerCount()==10 and Career:GetProgressPercent()==0)
Career:OnRestored(1,1);assert(Career:GetClaimedRewards()==1 and not Career:ClaimNextReward() and wallet==1000)
assert(Core:GetRecordedScannerCount()==10 and Career:GetRecordedDispatches()==4 and Career:GetRecordedArrests()==7)

f:SetCount(20);assert(Career:ClaimNextReward() and wallet==2000 and #f.notices==2)
assert(f.notices[1].threshold==10 and f.notices[2].threshold==20)
assert(Career:GetRecordedDispatches()==4 and Career:GetRecordedArrests()==7)

-- Payment errors don't consume milestones, and loading doesn't claim for you.
f:Reset(100);paymentOK=false
assert(not Career:ClaimNextReward() and Career:GetClaimedRewards()==0 and wallet==0 and #f.notices==0)
Career:OnRestored(1,1);assert(Career:GetAvailableRewards()==6 and wallet==0)
paymentOK=true;transactionPresent=false;assert(not Career:ClaimNextReward() and Career:GetClaimedRewards()==0)
transactionPresent=true
for i=1,6 do assert(Career:ClaimNextReward());assert(wallet==i*1000 and Career:GetClaimedRewards()==i) end
assert(not Career:ClaimNextReward() and wallet==6000 and #f.notices==6 and Career:GetAvailableRewards()==0)

f:Reset(10);f.wanted=true;assert(not Career:ClaimNextReward());f.wanted=false
local player=GetPlayer();player.combat=true;assert(not Career:ClaimNextReward());player.combat=false
player.dead=true;assert(not Career:ClaimNextReward());player.dead=false
player.attached=false;assert(not Career:ClaimNextReward());player.attached=true
f.ready=false;assert(not Career:ClaimNextReward());f.ready=true
assert(wallet==0 and Career:GetClaimedRewards()==0)
assert(Career:ClaimNextReward() and wallet==1000,'off-duty computer claim was blocked')

-- Execute production renderer and handlers, including return-chain lifecycle.
f:Reset(15);local host=f:Host();local external={};f.registration[external]=true
assert(host:OnInitialize());local site=host.m_ncpdPatrolCareerSite
assert(site and site.m_siteData.address=='NETdir://ncpd.career' and site.m_siteData.shortName=='NCPD Career')
host.page=site:GetWebPage('NETdir://ncpd.career')
local text=f:Text(host.page)
assert(text:find('Patrol Officer',1,true) and text:find('5/10 activities in this rank',1,true))
assert(text:find('15/20 total',1,true) and text:find('Service bonus: €$1000',1,true))
assert(text:find('AVAILABLE',1,true) and text:find('LOCKED',1,true) and wallet==0)
local oldClaim=site.m_claimButton;local oldRefresh=site.m_refreshButton
assert(not f:Click(oldClaim,'hold') and wallet==0)
assert(f:Click(oldRefresh) and wallet==0 and #f.loads==1)
assert(not oldClaim.callbacks.OnRelease and not oldRefresh.callbacks.OnRelease,'old page callbacks leaked')
local claim=site.m_claimButton;assert(f:Click(claim) and wallet==1000)
assert(Career:GetClaimedRewards()==1 and f:Text(host.page):find('CLAIMED',1,true))
assert(f:Text(host.page):find('REWARD PAID',1,true) and not f:Click(claim),'stale page claim still bound')
assert(f:Click(site.m_claimButton) and wallet==1000,'same milestone paid again')
assert(f.loads[1]~=f.loads[2],'refresh address did not change')

-- Repeated browser initialization removes our old registration without touching others.
oldClaim=site.m_claimButton;assert(host:OnInitialize());assert(not f.registration[site])
assert(not oldClaim.callbacks.OnRelease and f.registration[external])
local replacement=host.m_ncpdPatrolCareerSite;host.page=replacement:GetWebPage('NETdir://ncpd.career')
oldClaim=replacement.m_claimButton;assert(host:OnUninitialize())
assert(not oldClaim.callbacks.OnRelease and not f.registration[replacement] and f.registration[external])
assert(not replacement:OnClaimReleased({IsAction=function() return true end}) and wallet==1000)

-- Native context becomes stale while changing worlds; reading or clicking cannot pay.
f:Reset(20);host=f:Host();host:OnInitialize();site=host.m_ncpdPatrolCareerSite
host.page=site:GetWebPage('NETdir://ncpd.career');GetPlayer().attached=false
assert(not f:Click(site.m_claimButton) and wallet==0)
host.page=site:GetWebPage('NETdir://ncpd.career');assert(not IsDefined(site.m_claimButton))
assert(not f:Text(host.page):find('ON-DUTY ACTIVITIES',1,true))
