local f=CareerFixture
local function find(root,name)
 if root.name==name then return root end
 for _,child in ipairs(root.children) do local match=find(child,name);if match then return match end end
end
local function bounds(root)
 local function walk(parent)
  for _,child in ipairs(parent.children) do
   local x,y=(child.margin and child.margin[1] or 0),(child.margin and child.margin[2] or 0)
   local w,h=child.width or 0,child.height or 0
   local sx,sy=child.scale and child.scale.X or 1,child.scale and child.scale.Y or 1
   if not child.rotation then
    assert(x>=-0.1 and y>=-0.1 and w>=0 and h>=0,'negative authored geometry: '..tostring(child.name or child.text))
    assert(x+w*sx<=(parent.width or 0)+0.1 and y+h*sy<=(parent.height or 0)+0.1,
     'overflow in '..tostring(parent.name)..': '..tostring(child.name or child.text)..' '..x..','..y..' '..w..'x'..h)
   end
   walk(child)
  end
 end
 walk(root)
end
local function hover(widget,entered)
 local callback=widget.callbacks[entered and 'OnEnter' or 'OnLeave'];assert(callback)
 return callback.listener[callback.method](callback.listener,{GetCurrentTarget=function() return widget end})
end

-- Device viewport comes from the production game-controller -> browser ->
-- m_pageContentRoot helpers, not the full monitor/window or a guessed size.
for _,resolution in ipairs({{1920,1080},{3840,2160},{3440,1440},{1280,720},{3840,1800}}) do
 f:Reset(15);f.viewportWidth=resolution[1];f.viewportHeight=resolution[2]
 local host=f:Host();host:OnInitialize();local site=host.m_ncpdPatrolCareerSite
 for _,section in ipairs({'record','rewards','partners'}) do
  host.page=site:GetWebPage('NETdir://ncpd.career/'..section)
  local design=find(host.page,'NCPDPatrolCareerDesign');assert(design)
  assert(host.page.width==resolution[1] and host.page.height==resolution[2])
  assert(math.abs(design.width*design.scale.X-resolution[1])<0.1)
  assert(math.abs(design.height*design.scale.Y-resolution[2])<0.1)
  bounds(host.page)
  assert(Career:GetRecordedActivities()==15 and #f.itemCalls==0 and #f.vehicleCalls==0)
 end
 assert(BrowserState:GetDiagnostics():find('viewport='..resolution[1]..'x'..resolution[2],1,true))
 host:OnUninitialize()
end

f:Reset(15);local host=f:Host();local external={};f.registration[external]=true
assert(host:OnInitialize());local site=host.m_ncpdPatrolCareerSite
host.page=site:GetWebPage('NETdir://ncpd.career');local text=f:Text(host.page)
assert(text:find('Patrol Officer',1,true) and text:find('5/10 incidents in this rank',1,true))
assert(text:find('15/20 total',1,true) and text:find('NCPD vest + Lexington Military (Tier 2)',1,true))
assert(find(host.page,'NCPDPatrolOfficerSummary') and find(host.page,'NCPDPatrolCareerTimeline'))
assert(find(host.page,'NCPDPatrolPartnerSummary') and #f.itemCalls==0)
local oldClaim,oldRefresh,oldTab=site.m_claimButton,site.m_refreshButton,site.m_partnerTab
local serviceIndex=0
while site.m_buttons[serviceIndex]~=site.m_serviceTab do serviceIndex=serviceIndex+1 end
assert(hover(site.m_serviceTab,true));assert(site.m_faces[serviceIndex].color.Green>0.13)
assert(hover(site.m_serviceTab,false) and site.m_faces[serviceIndex].color.Green==0.13)
assert(not f:Click(oldClaim,'hold'));assert(f:Click(oldRefresh) and #f.loads==1)
assert(not oldClaim.callbacks.OnRelease and not oldRefresh.callbacks.OnRelease and not oldTab.callbacks.OnRelease)
assert(not oldClaim.callbacks.OnEnter and not oldClaim.callbacks.OnLeave)
local claim=site.m_claimButton;assert(f:Click(claim) and f.inventory['Items.Helmet_02_basic_01']==1)
assert(Career:GetClaimedRewards()==1 and f:Text(host.page):find('REWARD ISSUED',1,true) and not f:Click(claim))
assert(f:Click(site.m_rewardsTab));text=f:Text(host.page)
assert(text:find('Service entitlements',1,true) and text:find('CLAIMED',1,true) and text:find('AVAILABLE',1,true) and text:find('LOCKED',1,true))
for _,n in ipairs({5,10,20,35,50,75,100}) do assert(find(host.page,'NCPDPatrolReward'..n)) end
assert(f:Click(site.m_claimButton) and Career:GetClaimedRewards()==2)
assert(f:Click(site.m_claimButton) and Career:GetClaimedRewards()==2 and f.loads[1]~=f.loads[2])
assert(f:Click(site.m_partnerTab));text=f:Text(host.page)
assert(text:find('Zhuo shotgun',1,true) and not IsDefined(site.m_claimButton) and site.m_partnerButtons.n==4)
for i=0,3 do assert(find(host.page,'NCPDPatrolPartner'..i)) end
local locked=site.m_partnerButtons[3]
assert(not locked.interactive and not hover(locked,true))
assert(f:Click(locked) and Career:GetSelectedPartnerIndex()==0 and not locked.callbacks.OnRelease)
Career:SetTestUnlocks(true);assert(f:Click(site.m_refreshButton) and f:Text(host.page):find('TEST UNLOCK ACTIVE',1,true))
local assignment=site.m_partnerButtons[3]
assert(assignment.interactive and f:Click(assignment) and Career:GetSelectedPartnerIndex()==3)
assert(not assignment.callbacks.OnRelease and not assignment.callbacks.OnEnter and not f:Click(assignment))
assert(f:Text(host.page):find('PARTNER ASSIGNED',1,true) and #f.itemCalls==1 and #f.vehicleCalls==1)
local oldButtons={};for i=0,site.m_buttons.n-1 do oldButtons[#oldButtons+1]=site.m_buttons[i] end
assert(f:Click(site.m_serviceTab) and site.m_partnerButtons.n==0)
for _,button in ipairs(oldButtons) do assert(not button.callbacks.OnRelease and not button.callbacks.OnEnter and not button.callbacks.OnLeave) end
bounds(host.page)
assert(host:GetCustomSites().n==1 and FrameworkSystem:GetSitesData(GetPlayer()).n==0)
assert(host:OnInitialize() and host:GetCustomSites().n==1)
host.logic:SetWebsiteData();assert(host:GetCustomSites().n==1 and BrowserState:GetDiagnostics():find('career registered=true',1,true))
assert(f:Click(site.m_partnerTab));local oldButton=site.m_partnerButtons[2]
assert(host:OnUninitialize() and not oldButton.callbacks.OnRelease and f.registration[external])
local foreign={GetDevice=function() return host.device end,GetSiteData=function() return {address='NETdir://other.site',shortName='Other site'} end}
FrameworkSystem:Register(foreign);host:OnInitialize();assert(host:GetCustomSites().n==2);host:OnUninitialize()
assert(host:GetCustomSites().n==1 and host:GetCustomSites()[0].address=='NETdir://other.site')
assert(not site:OnClaimReleased({IsAction=function() return true end}))
-- Stale page rendering must also guard its released native controller.
local stale=site:GetWebPage('NETdir://ncpd.career');assert(f:Text(stale):find('Service record unavailable',1,true))

f:Reset(20);host=f:Host();host:OnInitialize();site=host.m_ncpdPatrolCareerSite
host.page=site:GetWebPage('NETdir://ncpd.career');GetPlayer().attached=false;host.device.attached=false
assert(not f:Click(site.m_claimButton) and #f.itemCalls==0)
host.page=site:GetWebPage('NETdir://ncpd.career');assert(not IsDefined(site.m_claimButton))
f:Reset(0);host=f:Host();host.viewport:SetSize(0,0);host.logic:SetWebsiteData();site=host.m_ncpdPatrolCareerSite
host.page=site:GetWebPage('NETdir://ncpd.career');assert(host.page.width==1920 and host.page.height==1080)
assert(BrowserState:GetDiagnostics():find('fallback=true',1,true));bounds(host.page)
host.viewport:SetSize(3440,1440);assert(f:Click(site.m_refreshButton))
assert(host.page.width==3440 and host.page.height==1440 and BrowserState:GetDiagnostics():find('fallback=false',1,true))
assert(FrameworkSystem:GetWebPage('NETdir://ncpd.career',{})==nil and BrowserState:OpenCareer())
f.befEnabled=false;assert(not BrowserState:OpenCareer());f.befEnabled=true
f.befBypass=true;assert(not BrowserState:OpenCareer());f.befBypass=false
ArrayPush(FrameworkSystem.m_blockedAddress,'NETdir://ncpd.career');assert(not BrowserState:OpenCareer())
ArrayClear(FrameworkSystem.m_blockedAddress);host:OnUninitialize();assert(not BrowserState:OpenCareer())
-- Complete and partial states use the same bounds; opening never grants gear.
f:Reset(100);Career:SetTestUnlocks(true);host=f:Host();host:OnInitialize();site=host.m_ncpdPatrolCareerSite
for _,section in ipairs({'record','rewards','partners'}) do
 host.page=site:GetWebPage('NETdir://ncpd.career/'..section);bounds(host.page)
 assert(f:Text(host.page):find('TEST UNLOCK ACTIVE',1,true))
end
assert(#f.itemCalls==0 and #f.vehicleCalls==0 and Career:GetRecordedActivities()==100)
host:OnUninitialize()
