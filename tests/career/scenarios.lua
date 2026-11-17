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

-- Initialization is idempotent, and the same listener is present before BEF
-- composes a homepage. Registry lookup must match the computer, not the player.
local sites=host:GetCustomSites()
assert(sites.n==1 and sites[0].address=='NETdir://ncpd.career' and sites[0].shortName=='NCPD Career')
assert(FrameworkSystem:GetSitesData(GetPlayer()).n==0,'registered against the player instead of the computer')
oldClaim=site.m_claimButton;assert(host:OnInitialize());assert(f.registration[site] and host:GetCustomSites().n==1)
local spawn=setmetatable({m_gameController=host},{__index=PageSpawnPrototype})
spawn:SetWebsiteData();assert(host:GetCustomSites().n==1)
assert(BrowserState:GetDiagnostics():find('career registered=true',1,true))
assert(f.registration[external])
local replacement=host.m_ncpdPatrolCareerSite;host.page=replacement:GetWebPage('NETdir://ncpd.career')
oldClaim=replacement.m_claimButton;assert(host:OnUninitialize())
assert(not oldClaim.callbacks.OnRelease and not f.registration[replacement] and f.registration[external])
local foreign={GetDevice=function() return host.device end,GetSiteData=function() return {address='NETdir://other.site',shortName='Other site'} end}
FrameworkSystem:Register(foreign)
assert(host:GetCustomSites().n==1 and host:GetCustomSites()[0].address=='NETdir://other.site')
host:OnInitialize();assert(host:GetCustomSites().n==2);host:OnUninitialize()
assert(host:GetCustomSites().n==1 and host:GetCustomSites()[0].address=='NETdir://other.site','other site registration was removed')
assert(not replacement:OnClaimReleased({IsAction=function() return true end}) and wallet==1000)

-- Native context becomes stale while changing worlds; reading or clicking cannot pay.
f:Reset(20);host=f:Host();host:OnInitialize();site=host.m_ncpdPatrolCareerSite
host.page=site:GetWebPage('NETdir://ncpd.career');GetPlayer().attached=false;host.device.attached=false
assert(not f:Click(site.m_claimButton) and wallet==0)
host.page=site:GetWebPage('NETdir://ncpd.career');assert(not IsDefined(site.m_claimButton))
assert(not f:Text(host.page):find('ON-DUTY ACTIVITIES',1,true))

-- A page-spawn callback can initialize registration even when it precedes our
-- normal initialization hook. Other devices cannot use this site's listener.
f:Reset(15);host=f:Host();spawn=setmetatable({m_gameController=host},{__index=PageSpawnPrototype})
assert(host:GetCustomSites().n==0);spawn:SetWebsiteData();assert(host:GetCustomSites().n==1)
assert(FrameworkSystem:GetWebPage('NETdir://ncpd.career',{})==nil)
assert(BrowserState:OpenCareer() and host.page and wallet==0)
assert(BrowserState:GetDiagnostics():find('page requests=1',1,true))
f.befEnabled=false;assert(not BrowserState:OpenCareer())
assert(BrowserState:GetDiagnostics():find('enabled=false',1,true));f.befEnabled=true
f.befBypass=true;assert(not BrowserState:OpenCareer());f.befBypass=false
ArrayPush(FrameworkSystem.m_blockedAddress,'NETdir://ncpd.career')
assert(not BrowserState:OpenCareer() and BrowserState:GetDiagnostics():find('address blocked=true',1,true))
ArrayClear(FrameworkSystem.m_blockedAddress);host:OnUninitialize()
assert(not BrowserState:OpenCareer() and host:GetCustomSites().n==0)
