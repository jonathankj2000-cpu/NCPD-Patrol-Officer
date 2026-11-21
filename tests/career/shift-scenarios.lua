-- Both browser actions queue desired states; the existing CET controller owns
-- actor creation, dispatch cancellation and final shift cleanup.
local f=CareerFixture
f:Reset(0)
local host=f:Host();host:OnInitialize()
local site=host.m_ncpdPatrolCareerSite
host.page=site:GetWebPage('NETdir://ncpd.career')
assert(f:Text(host.page):find('START SHIFT',1,true))
local first=site.m_dutyButton
assert(not f:Click(first,'hold') and Core:TakeDutyRequest()==0)
assert(f:Click(first) and Core:TakeDutyRequest()==1)
assert(f:Text(host.page):find('SHIFT REQUESTED',1,true) and not site.m_dutyButton.interactive)
assert(not f:Click(site.m_dutyButton) and Core:TakeDutyRequest()==0)
assert(not Core:IsOnDuty() and #f.itemCalls==0 and #f.vehicleCalls==0)
assert(not first.callbacks.OnRelease and not f:Click(first))
assert(f:Click(site.m_refreshButton) and f:Click(site.m_dutyButton))
assert(f:Click(site.m_refreshButton) and f:Click(site.m_dutyButton))
assert(Core:TakeDutyRequest()==1 and Core:TakeDutyRequest()==0)
Core.m_onDuty=true;assert(f:Click(site.m_refreshButton))
assert(f:Text(host.page):find('END SHIFT',1,true) and site.m_dutyButton.interactive)
assert(not site:OnStartShiftReleased({IsAction=function() return true end}))
assert(not f:Click(site.m_dutyButton,'hold') and Core:TakeDutyRequest()==0)
local oldEnd=site.m_dutyButton
assert(f:Click(oldEnd) and Core:TakeDutyRequest()==2)
assert(Core:IsOnDuty(), 'The page must not bypass CET end-shift cleanup')
assert(f:Text(host.page):find('ENDING SHIFT',1,true) and not site.m_dutyButton.interactive)
assert(not f:Click(site.m_dutyButton) and Core:TakeDutyRequest()==0)
assert(not oldEnd.callbacks.OnRelease and not f:Click(oldEnd))
assert(f:Click(site.m_refreshButton) and f:Click(site.m_dutyButton))
assert(f:Click(site.m_refreshButton) and f:Click(site.m_dutyButton))
assert(Core:TakeDutyRequest()==2 and Core:TakeDutyRequest()==0)
-- Ending never clears heat or bypasses the normal criminal-termination rule.
f.wanted=true;assert(f:Click(site.m_refreshButton) and f:Click(site.m_dutyButton))
assert(Core:TakeDutyRequest()==2 and f.wanted)
Core.m_onDuty=false;assert(f:Click(site.m_refreshButton))
assert(not site:OnEndShiftReleased({IsAction=function() return true end}) and Core:TakeDutyRequest()==0)
assert(f:Text(host.page):find('START SHIFT',1,true))
assert(f:Click(site.m_dutyButton) and Core:TakeDutyRequest()==0)
assert(f.notices[#f.notices].text:find('while wanted',1,true))
f.wanted=false
for _,duty in ipairs({false,true}) do
 Core.m_onDuty=duty
 for _,condition in ipairs({'session','attached','dead','player','device'}) do
  assert(f:Click(site.m_refreshButton))
  if condition=='session' then f.sessionReady=false end
  if condition=='attached' then GetPlayer().attached=false end
  if condition=='dead' then GetPlayer().dead=true end
  if condition=='player' then f.ready=false end
  if condition=='device' then host.device.attached=false end
  assert(not f:Click(site.m_dutyButton) and Core:TakeDutyRequest()==0,condition)
  f.sessionReady=true;f.ready=true;GetPlayer().attached=true;GetPlayer().dead=false;host.device.attached=true
 end
end
for _,tab in ipairs({'m_serviceTab','m_rewardsTab','m_partnerTab'}) do
 assert(f:Click(site[tab]))
 assert(f:Text(host.page):find('END SHIFT',1,true) and site.m_dutyButton.interactive)
 assert(f:Click(site.m_dutyButton) and Core:TakeDutyRequest()==2)
 assert(f:Click(site.m_refreshButton))
end
local stale=site.m_dutyButton;host:OnUninitialize()
assert(not stale.callbacks.OnRelease and not f:Click(stale))
assert(not site:OnStartShiftReleased({IsAction=function() return true end}))
assert(not site:OnEndShiftReleased({IsAction=function() return true end}))
assert(Core:IsOnDuty() and #f.itemCalls==0 and #f.vehicleCalls==0 and Career:GetRecordedActivities()==0)
