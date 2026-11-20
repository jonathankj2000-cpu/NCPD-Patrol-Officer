-- The actual browser handler queues the actual native desired-state request.
-- Shift ownership, actor creation and rewards stay in the existing CET path.
local f=CareerFixture
f:Reset(0)
local host=f:Host();host:OnInitialize()
local site=host.m_ncpdPatrolCareerSite
host.page=site:GetWebPage('NETdir://ncpd.career')
assert(f:Text(host.page):find('START SHIFT',1,true))
local first=site.m_startShiftButton
assert(not f:Click(first,'hold') and Core:TakeDutyRequest()==0)
assert(f:Click(first) and Core:TakeDutyRequest()==1)
assert(f:Text(host.page):find('SHIFT REQUESTED',1,true) and not site.m_startShiftButton.interactive)
assert(not f:Click(site.m_startShiftButton) and Core:TakeDutyRequest()==0)
assert(not Core:IsOnDuty() and #f.itemCalls==0 and #f.vehicleCalls==0)
assert(not first.callbacks.OnRelease and not f:Click(first))
-- Repeated requests collapse to the same desired state.
assert(f:Click(site.m_refreshButton) and f:Click(site.m_startShiftButton))
assert(f:Click(site.m_refreshButton) and f:Click(site.m_startShiftButton))
assert(Core:TakeDutyRequest()==1 and Core:TakeDutyRequest()==0)
Core.m_onDuty=true;assert(f:Click(site.m_refreshButton))
assert(f:Text(host.page):find('SHIFT ACTIVE',1,true) and not site.m_startShiftButton.interactive)
assert(not f:Click(site.m_startShiftButton) and Core:TakeDutyRequest()==0)
Core.m_onDuty=false;f.wanted=true;assert(f:Click(site.m_refreshButton))
assert(f:Click(site.m_startShiftButton) and Core:TakeDutyRequest()==0)
assert(f.notices[#f.notices].text:find('while wanted',1,true))
f.wanted=false
for _,condition in ipairs({'session','attached','dead'}) do
 assert(f:Click(site.m_refreshButton))
 if condition=='session' then f.sessionReady=false end
 if condition=='attached' then GetPlayer().attached=false end
 if condition=='dead' then GetPlayer().dead=true end
 assert(not f:Click(site.m_startShiftButton) and Core:TakeDutyRequest()==0,condition)
 f.sessionReady=true;GetPlayer().attached=true;GetPlayer().dead=false
end
local stale=site.m_startShiftButton;host:OnUninitialize()
assert(not stale.callbacks.OnRelease and not f:Click(stale))
assert(not site:OnStartShiftReleased({IsAction=function() return true end}))
assert(not Core:IsOnDuty() and #f.itemCalls==0 and #f.vehicleCalls==0 and Career:GetRecordedActivities()==0)
