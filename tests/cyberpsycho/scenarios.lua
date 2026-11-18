local f=CyberFixture;local c=CyberNative
local site={x=800,y=0,z=0,w=1}
local function reset() f:Reset() end
local function dispatch() local token=c:BeginDispatch(site);assert(token>0,c:GetReason());return token end
local function begin(target)
 local token=dispatch();f.playerPosition.x=700;c:Tick(0.25)
 assert(c:CanSpawn(token) and c:BindTarget(token,target),c:GetReason())
 return token
end

-- Respond first; no absent target is ever considered eliminated while travelling.
reset();local token=dispatch()
assert(c:GetStage()==1 and f:ResponseState()==2 and f:ObjectiveState()==1 and c:GetRemainingSeconds()==180)
assert(not c:CanSpawn(token) and not c:BindTarget(token,f:Actor()))
f:Advance(179.75);assert(c:GetStage()==1 and c:GetRemainingSeconds()==1)
f:Advance(0.25);assert(c:GetStage()==4 and f:ResponseState()==4 and f:ObjectiveState()==1)
reset();token=dispatch();f:Advance(179.75);f.playerPosition.x=660;c:Tick(0.25)
assert(c:GetStage()==1 and c:CanSpawn(token) and c:GetRemainingSeconds()==0,'arrival lost to deadline boundary')
assert(c:BindTarget(token,f:Actor()) and f:ResponseState()==3 and f:ObjectiveState()==2)
assert(not c:BindTarget(token,f:Actor()),'target replacement admitted')
reset();token=dispatch();f.paused=true;f:Advance(200);assert(c:GetRemainingSeconds()==180)
f.paused=false;c:Tick(20);c:Tick(-1);assert(c:GetRemainingSeconds()==180)
reset();token=dispatch();f.playerPosition.x=700;c:Tick(0.25);f:Advance(30)
assert(c:GetStage()==4 and f:ObjectiveState()==1,'on-scene target setup had no bound')
for _,x in ipairs({499,2001,0/0}) do reset();assert(c:BeginDispatch({x=x,y=0,z=0,w=1})==0) end
reset();assert(c:BeginDispatch({x=500,y=0,z=0,w=1})>0)
reset();JournalFixture.ready=false;assert(c:BeginDispatch(site)==0)
reset();JournalFixture.rejectState=2;assert(c:BeginDispatch(site)==0 and f:State()==1)
reset();token=dispatch();assert(c:BeginDispatch(site)==0)
c:Cancel(token-1,'stale');assert(c:GetStage()==1)
f.playerPosition.x=700;c:Tick(0.25)
assert(not c:BindTarget(token,nil) and not c:BindTarget(token,f:Actor('Character.unrelated')))
local target=f:Actor();target.dead=true;assert(not c:BindTarget(token,target))
target.dead=false;target.active=false;assert(not c:BindTarget(token,target))
target.active=true;target.pos.x=851;assert(not c:BindTarget(token,target))
c:Cancel(token,'manual');assert(c:GetStage()==5 and f:State()==1 and f:ResponseState()==1)

-- The registered actor alone controls lethal and both non-lethal outcomes.
for _,state in ipairs({'dead','deadNoPool','defeated','unconscious'}) do
 reset();target=f:Actor();local story=JournalFixture:Story();JournalFixture.tracked=story
 token=begin(target);assert(f:State()==2)
 local other=f:Actor();other.dead=true;f:Advance(2);assert(c:GetStage()==2)
 target[state]=true;f:Advance(0.5);assert(c:GetStage()==2)
 target[state]=false;f:Advance(0.25);target[state]=true;f:Advance(0.5);assert(c:GetStage()==2)
 f:Advance(0.25);assert(c:GetStage()==3 and f:State()==3 and JournalFixture.tracked==story)
 local writes=#JournalFixture.writes;f:Advance(5);assert(#JournalFixture.writes==writes)
 assert(f.managed[990]=='ambient' and DispatchRewardFixture.wallet==0)
end
reset();target=f:Actor();token=begin(target);c:Cancel(token,'manual');target.dead=true
f:Advance(5);assert(c:GetStage()==5 and f:State()==1)
reset();target=f:Actor();begin(target);target.attached=false;target.dead=true;f:Advance(8)
assert(c:GetStage()==4 and f:State()==4)
reset();target=f:Actor();begin(target);c.m_target=nil;f:Advance(8);assert(c:GetStage()==4)
reset();target=f:Actor();begin(target);target.defeated=true;f.paused=true;f:Advance(5)
assert(c:GetStage()==2);f.paused=false;f:Advance(0.75);assert(c:GetStage()==3)
reset();target=f:Actor();begin(target);target.pos.x=1000;assert(c:GetTargetPosition().x==1000)
f.playerPosition.x=1151;f:Advance(5);assert(c:GetStage()==4,'moving target moved the scene origin')
for _,active in ipairs({false,true}) do
 for _,guard in ipairs({'wanted','playerDead'}) do
  reset();target=f:Actor();if active then begin(target) else dispatch() end
  f[guard]=true;target.dead=true;f:Advance(1);assert(c:GetStage()==4)
 end
 reset();if active then begin(f:Actor()) else dispatch() end
 f.duty=false;f:Advance(1);assert(c:GetStage()==5)
end
reset();token=dispatch();local changed=JournalFixture:Story('changed');JournalFixture.tracked=changed
f.playerPosition.x=700;c:Tick(0.25);assert(c:BindTarget(token,f:Actor()))
assert(JournalFixture.tracked==changed,'arrival stole a manually selected objective')
c:Cancel(token,'manual');assert(JournalFixture.tracked==changed)
for _,active in ipairs({false,true}) do
 reset();if active then begin(f:Actor()) else dispatch() end
 local writes=#JournalFixture.writes;c:OnRestored(1,1);assert(#JournalFixture.writes==writes)
 f.duty=false;c:Tick(0.25);assert(c:GetStage()==0 and f:State()==1 and f:ResponseState()==1)
end
reset();target=f:Actor();begin(target);target.dead=true;JournalFixture.rejectState=3;f:Advance(0.75)
assert(c:GetStage()==6 and f:State()~=3)
reset();target=f:Actor();begin(target);target.dead=true;f:Advance(0.75);c:OnRestored(1,1);c:Tick(0.25)
assert(f:State()==3 and c:GetStage()==0)

-- Actual CET code: destination selection now precedes every navigation/spawn call.
local Cyber=require('cyberpsycho');local HUD=require('dispatch_hud')
local function status(text) f:Status(text) end
local function fresh() reset();Cyber.reset() end
local function update(seconds) for _=1,math.floor(seconds*4+0.0001) do Cyber.update(0.25,f.duty,f.patrol,status,HUD) end end
local function request() assert(Cyber.request(f.patrol,status,true,false),Cyber.state()) end
local function arrive() f.playerPosition.x=700;update(1);assert(c:GetStage()==2,Cyber.state()) end
fresh();request();assert(#f.creates==0 and #f.probes==0 and #f.markers==1 and c:GetStage()==1)
assert(not Cyber.request(f.patrol,status) and #f.creates==0)
update(30);assert(#f.creates==0 and #f.probes==0 and f.hud.text:find('Respond to the incident',1,true))
arrive();assert(#f.creates==1 and f:ResponseState()==3 and f:ObjectiveState()==2 and f.hud.visible)
target=f.actors[1001];assert(math.abs(target.pos.x-800)<=50 and target.pos.x>=500)
assert(target.attitudes.group=='hostile' and target.attitudes.hostile==2 and #target.commands==1)
target.unconscious=true;update(0.75);assert(c:GetStage()==3 and Cyber.isActive())
assert(Cyber.state():find('COMPLETED',1,true) and #f.deletes==0 and DispatchRewardFixture.wallet==0)
f.playerPosition.x=951;update(0.25);assert(not Cyber.isActive() and #f.deletes==1 and f.managed[990]=='ambient')
fresh();request();update(180);assert(not Cyber.isActive() and #f.creates==0 and f:State()==4)
fresh();request();assert(Cyber.cancel(f.patrol,status) and #f.deletes==0 and f:State()==1)
fresh();f.mounted=true;request();assert(#f.creates==0);arrive();assert(#f.creates==1);Cyber.cancel(f.patrol,status)

-- Range tiers, minimum distance, NCART/inactive filtering and occupied scanner areas.
for _,x in ipairs({800,1300,1800}) do
 fresh();f.places={f:Place(100),f:Place(x),f:Place(2100)};request()
 assert(c:GetTargetPosition().x==x and #f.creates==0)
 assert(Cyber.diagnostics():find('search radius='..(x<=1000 and 1000 or x<=1500 and 1500 or 2000),1,true))
 Cyber.cancel(f.patrol,status)
end
fresh();f.places={f:Place(1300),f:Place(800)};request();assert(c:GetTargetPosition().x==800);Cyber.cancel(f.patrol,status)
for _,places in ipairs({{}, {f:Place(499)}, {f:Place(2001)}, {f:Place(800,0,0,'ncart')},
 {f:Place(800,0,0,nil,false)}, {f:Place(0/0)}, {f:Place(800),f:Place(830,0,0,'assault')},
 {f:Place(800),f:Place(830,0,0,'assault',false)}}) do
 fresh();f.places=places;assert(not Cyber.request(f.patrol,status) and #f.creates==0 and not Cyber.isActive())
end
fresh();f.places={f:Place(800),f:Place(830,0,0,'assault',true,gamedataMappinPhase.CompletedPhase)}
request();Cyber.cancel(f.patrol,status)
fresh();f.playerPosition.x=800;f.places={f:Place(0)}
assert(not Cyber.request(f.patrol,status) and #f.creates==0,'invalid origin marker became a dispatch destination')
for _,guard in ipairs({'wanted','paused','combat','playerDead'}) do
 fresh();f[guard]=true;assert(not Cyber.request(f.patrol,status) and #f.creates==0)
end
for _,guard in ipairs({'recordOK','entityReady','nativePresent','playerPresent','playerAttached','mapPresent'}) do
 fresh();f[guard]=false;assert(not Cyber.request(f.patrol,status) and not Cyber.isActive())
end

-- Validate only the assigned scene after arrival; never move the encounter back to V.
for _,guard in ipairs({'navOK','pathOK','createOK'}) do
 fresh();f[guard]=false;request();assert(#f.probes==0)
 f.playerPosition.x=700;update(10);assert(not Cyber.isActive() and f:State()==4 and not f.managed[1001])
end
for _,bad in ipairs({{x=700,y=0,z=0},{x=832,y=0,z=50},{x=0/0,y=0,z=0}}) do
 fresh();f.navOverride=bad;request();f.playerPosition.x=700;update(10)
 assert(not Cyber.isActive() and #f.creates==0 and f:State()==4)
end
fresh();request();f.actorVisible=false;f.playerPosition.x=700;update(14)
assert(not Cyber.isActive() and f:State()==4)
fresh();request();f.aiMissing=true;f.playerPosition.x=700;update(14)
assert(not Cyber.isActive() and f:State()==4)
fresh();request();f.playerPosition.x=700;update(0.75);f.actors[1001].active=false;update(1)
assert(#f.actors[1001].commands==0 and c:GetStage()==1)
f.actors[1001].active=true;update(0.25);assert(c:GetStage()==2);Cyber.cancel(f.patrol,status)
fresh();request();f.playerPosition.x=700;update(0.75);f.actors[1001].record='Character.unrelated';update(0.25)
assert(not Cyber.isActive() and f.actors[1001]==nil and f:State()==4)
fresh();f.markerOK=false;assert(not Cyber.request(f.patrol,status) and #f.creates==0 and f:State()==4)
fresh();request();arrive();f.deleteOK=false
assert(not Cyber.cancel(f.patrol,status) and Cyber.isActive())
assert(not Cyber.request(f.patrol,status) and #f.creates==1)
update(2);assert(Cyber.isActive() and f.managed[1001])
f.deleteOK=true;update(1);assert(not Cyber.isActive() and not f.managed[1001])
fresh();request();arrive();f.deleteDeferred=true;assert(not Cyber.cancel(f.patrol,status))
f.managed[1001]=nil;update(1);assert(not Cyber.isActive())
for _,active in ipairs({false,true}) do
 fresh();request();if active then arrive() end
 local writes=#f.deletes;Cyber.reset();c:OnRestored(1,1);update(0.25)
 assert(#f.deletes==writes and f:State()==1 and not Cyber.isActive(),'load deleted an old-world ID')
 fresh();request();if active then arrive() end
 f.duty=false;update(0.25);assert(not Cyber.isActive() and f:State()==1)
end

-- Real dispatch routing shares one reservation across travel, fight and cleanup.
local Dispatch=require('dispatch')
local function dispatcher(seconds) for _=1,math.floor(seconds*4+0.0001) do Dispatch.update(0.25,f.duty,status,function() return f.patrol end) end end
fresh();Dispatch.reset();Dispatch.start(f.patrol,status)
assert(Dispatch.requestCyberpsycho(f.patrol,status));dispatcher(65)
assert(Dispatch.isActive() and not Dispatch.request(f.patrol,status) and #f.creates==0 and c:GetStage()==1)
assert(Dispatch.cancel(f.patrol,status) and not Dispatch.isActive())
local scanner={phase='active',GetJournalPathHash=function() return 77 end,GetWorldPosition=function() return site end,GetVariant=function() return 'assault' end}
f.scanners={scanner};assert(Dispatch.request(f.patrol,status));assert(not Dispatch.requestCyberpsycho(f.patrol,status))
assert(Dispatch.cancel(f.patrol,status));assert(Dispatch.requestCyberpsycho(f.patrol,status))
f.scanners[2]={phase='active',GetJournalPathHash=function() return 78 end,GetWorldPosition=scanner.GetWorldPosition,GetVariant=scanner.GetVariant}
assert(Dispatch.replace(f.patrol,status) and DispatchJournalNative:GetStage()==1)
Dispatch.cancel(f.patrol,status);assert(Dispatch.requestCyberpsycho(f.patrol,status))
f.playerPosition.x=700;dispatcher(1);f.deleteOK=false
Dispatch.finish(f.patrol,status);f.duty=false;dispatcher(2)
assert(Cyber.isActive(),'off-duty reset discarded pending cleanup')
f.deleteOK=true;dispatcher(1);assert(not Cyber.isActive())
assert(f.managed[990]=='ambient' and DispatchRewardFixture.wallet==0)

-- Actual shipped CET button: initial request creates a journey, not an enemy beside V.
fresh();Dispatch.reset();Dispatch.start(f.patrol,status)
local function no() return false end
local function noop() end
local function display() return 'fixture' end
package.loaded.partner={state=display,activeProfile=display,vehicleState=display,aidState=display}
package.loaded.vehicle_radio={isEnabled=no,state=display};package.loaded.backup={state=display}
package.loaded.arrest={state=display};package.loaded.trunk={repairSeconds=function() return 0 end}
local callbacks,pressed,labels={},nil,{}
function registerForEvent(name,callback) callbacks[name]=callback end
function registerHotkey() end
ImGui={Begin=function() return true end,End=noop,Text=noop,TextWrapped=noop,Separator=noop,CollapsingHeader=no,
 Button=function(label) labels[label]=true;return pressed==label end}
dofile(MOD_DIR..'/init.lua');callbacks.onOverlayOpen()
pressed='TEST: Request cyberpsycho dispatch';callbacks.onDraw()
assert(labels[pressed] and Dispatch.isActive() and #f.creates==0 and c:GetStage()==1)
pressed='Cancel active dispatch';callbacks.onDraw()
assert(labels[pressed] and not Dispatch.isActive() and f:State()==1)
