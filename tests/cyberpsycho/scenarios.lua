local f=CyberFixture;local c=CyberNative
local function begin(actor) local token=c:BeginTarget(actor);assert(token>0,c:GetReason());return token end
local function reset() f:Reset() end

-- The registered actor alone controls the result, including both non-lethal states.
for _,state in ipairs({'dead','deadNoPool','defeated','unconscious'}) do
 reset();local target=f:Actor();local story=JournalFixture:Story();JournalFixture.tracked=story
 local token=begin(target);assert(f:State()==2)
 local other=f:Actor();other.dead=true;f:Advance(2);assert(c:GetStage()==2)
 target[state]=true;f:Advance(0.5);assert(c:GetStage()==2)
 target[state]=false;f:Advance(0.25);target[state]=true;f:Advance(0.5);assert(c:GetStage()==2)
 f:Advance(0.25);assert(c:GetStage()==3 and f:State()==3 and JournalFixture.tracked==story)
 local writes=#JournalFixture.writes;f:Advance(5);assert(#JournalFixture.writes==writes)
 assert(f.managed[990]=='ambient' and DispatchRewardFixture.wallet==0)
end
reset();assert(c:BeginTarget(nil)==0 and c:BeginTarget(f:Actor('Character.unrelated'))==0)
local target=f:Actor();target.dead=true;assert(c:BeginTarget(target)==0)
target.dead=false;target.active=false;assert(c:BeginTarget(target)==0)
target.active=true;target.pos.x=121;assert(c:BeginTarget(target)==0)
reset();JournalFixture.ready=false;assert(c:BeginTarget(f:Actor())==0)
reset();JournalFixture.rejectState=2;assert(c:BeginTarget(f:Actor())==0 and f:State()==1)
reset();target=f:Actor();local token=begin(target)
assert(c:BeginTarget(f:Actor())==0);c:Cancel(token-1,'stale');assert(c:GetStage()==2)
c:Cancel(token,'manual');target.dead=true;f:Advance(5);assert(c:GetStage()==5 and f:State()==1)
reset();target=f:Actor();begin(target);target.attached=false;target.dead=true;f:Advance(7.75)
assert(c:GetStage()==2);f:Advance(0.25);assert(c:GetStage()==4 and f:State()==4)
reset();target=f:Actor();begin(target);c.m_target=nil;f:Advance(8);assert(c:GetStage()==4)
reset();target=f:Actor();begin(target);target.defeated=true;f.paused=true;f:Advance(5)
assert(c:GetStage()==2);f.paused=false;c:Tick(30);c:Tick(-1);assert(c:GetStage()==2)
f:Advance(0.75);assert(c:GetStage()==3)
reset();target=f:Actor();begin(target);f.playerPosition.x=451;f:Advance(5);assert(c:GetStage()==4)
reset();target=f:Actor();begin(target);target.pos.x=200;assert(c:GetTargetPosition().x==200)
f.playerPosition.x=416;f:Advance(5);assert(c:GetStage()==4,'moving target changed the original scene position')
reset();target=f:Actor();begin(target);f.wanted=true;target.dead=true;f:Advance(1);assert(c:GetStage()==4)
reset();target=f:Actor();begin(target);f.playerDead=true;f:Advance(1);assert(c:GetStage()==4)
reset();target=f:Actor();begin(target);f.duty=false;f:Advance(1);assert(c:GetStage()==5)
reset();target=f:Actor();begin(target);local changed=JournalFixture:Story('changed');JournalFixture.tracked=changed
c:Cancel(c:GetToken(),'manual');assert(JournalFixture.tracked==changed)
reset();target=f:Actor();token=begin(target);local writes=#JournalFixture.writes;c:OnRestored(1,1)
assert(#JournalFixture.writes==writes);f.duty=false;c:Tick(0.25);assert(c:GetStage()==0 and f:State()==1)
c:Cancel(token,'stale');assert(c:GetStage()==0)
reset();target=f:Actor();begin(target);target.dead=true;JournalFixture.rejectState=3;f:Advance(0.75)
assert(c:GetStage()==6 and f:State()~=3)
reset();target=f:Actor();begin(target);target.dead=true;f:Advance(0.75);c:OnRestored(1,1);c:Tick(0.25)
assert(f:State()==3 and c:GetStage()==0)

-- Actual CET module: native creation/navigation/AI calls are mocked, not its logic.
local Cyber=require('cyberpsycho');local HUD=require('dispatch_hud')
local function status(text) f:Status(text) end
local function fresh() reset();Cyber.reset() end
local function update(seconds) for _=1,math.floor(seconds*4+0.0001) do Cyber.update(0.25,f.duty,f.patrol,status,HUD) end end
local function request() assert(Cyber.request(f.patrol,status,true,false),Cyber.state()) end
fresh();request();assert(#f.creates==1 and #JournalFixture.writes==0)
assert(not Cyber.request(f.patrol,status) and #f.creates==1)
update(0.25);assert(c:GetStage()==2 and f:State()==2 and #f.markers==1 and f.hud.visible)
target=f.actors[1001];assert(target.attitudes.group=='hostile' and target.attitudes.hostile==2 and #target.commands==1)
target.unconscious=true;update(0.75);assert(c:GetStage()==3 and Cyber.isActive())
assert(Cyber.state():find('COMPLETED',1,true) and #f.deletes==0 and DispatchRewardFixture.wallet==0)
f.playerPosition.x=216;update(0.25);assert(not Cyber.isActive() and #f.deletes==1 and f.managed[990]=='ambient')
fresh();request();f.actorVisible=false;update(12);assert(not Cyber.isActive() and f:State()~=3)
fresh();request();f.aiMissing=true;update(12);assert(not Cyber.isActive() and f:State()~=3)
fresh();request();f.actors[1001].active=false;update(1);assert(Cyber.isActive() and c:GetStage()==0)
assert(#f.actors[1001].commands==0);f.actors[1001].active=true;update(0.25);assert(c:GetStage()==2)
Cyber.cancel(f.patrol,status)
fresh();f.navOK=false;assert(not Cyber.request(f.patrol,status) and #f.creates==0)
fresh();f.pathOK=false;assert(not Cyber.request(f.patrol,status) and #f.creates==0)
for _,bad in ipairs({{x=0,y=0,z=0},{x=65,y=0,z=50},{x=0/0,y=0,z=0}}) do
 fresh();f.navOverride=bad;assert(not Cyber.request(f.patrol,status) and #f.creates==0)
end
for _,guard in ipairs({'wanted','paused','mounted','combat','playerDead'}) do
 fresh();f[guard]=true;assert(not Cyber.request(f.patrol,status) and #f.creates==0)
end
for _,guard in ipairs({'recordOK','entityReady','nativePresent','playerPresent','playerAttached','createOK'}) do
 fresh();f[guard]=false;assert(not Cyber.request(f.patrol,status) and not Cyber.isActive())
end
fresh();request();f.actors[1001].record='Character.unrelated';update(0.25)
assert(not Cyber.isActive() and f.actors[1001]==nil and f:State()~=3)
fresh();request();f.markerOK=false;update(0.25);assert(not Cyber.isActive() and f:State()==1)
fresh();request();update(0.25);f.deleteOK=false
assert(not Cyber.cancel(f.patrol,status) and Cyber.isActive())
assert(not Cyber.request(f.patrol,status) and #f.creates==1)
update(2);assert(Cyber.isActive() and f.managed[1001])
f.deleteOK=true;update(1);assert(not Cyber.isActive() and not f.managed[1001])
fresh();request();update(0.25);f.deleteDeferred=true
assert(not Cyber.cancel(f.patrol,status) and Cyber.isActive())
f.managed[1001]=nil;update(1);assert(not Cyber.isActive())
fresh();request();update(0.25);writes=#f.deletes;Cyber.reset();c:OnRestored(1,1)
update(0.25);assert(#f.deletes==writes and f:State()==1 and not Cyber.isActive(),'load deleted an old-world ID')
fresh();request();update(0.25);f.duty=false;update(0.25);assert(not Cyber.isActive() and f:State()==1)

-- Real dispatcher shares one reservation and routes trunk/CET cancel/replace.
local Dispatch=require('dispatch')
local function dispatcher(seconds) for _=1,math.floor(seconds*4+0.0001) do Dispatch.update(0.25,f.duty,status,function() return f.patrol end) end end
fresh();Dispatch.reset();Dispatch.start(f.patrol,status)
assert(Dispatch.requestCyberpsycho(f.patrol,status));dispatcher(1)
assert(Dispatch.isActive() and not Dispatch.request(f.patrol,status) and #f.creates==1)
dispatcher(65);assert(#f.creates==1 and DispatchJournalNative:GetStage()==0)
assert(Dispatch.cancel(f.patrol,status) and not Dispatch.isActive())
local scanner={phase='active',GetJournalPathHash=function() return 77 end,GetWorldPosition=function() return {x=800,y=0,z=0,w=1} end,
 GetVariant=function() return 'assault' end}
f.scanners={scanner};assert(Dispatch.request(f.patrol,status));assert(not Dispatch.requestCyberpsycho(f.patrol,status))
assert(Dispatch.cancel(f.patrol,status));assert(Dispatch.requestCyberpsycho(f.patrol,status));dispatcher(1)
f.scanners[2]={phase='active',GetJournalPathHash=function() return 78 end,
 GetWorldPosition=scanner.GetWorldPosition,GetVariant=scanner.GetVariant}
assert(Dispatch.replace(f.patrol,status) and DispatchJournalNative:GetStage()==1)
Dispatch.cancel(f.patrol,status)
assert(Dispatch.requestCyberpsycho(f.patrol,status));dispatcher(1);f.deleteOK=false
Dispatch.finish(f.patrol,status);f.duty=false;dispatcher(2)
assert(Cyber.isActive(),'off-duty reset discarded pending owned-entity cleanup')
f.deleteOK=true;dispatcher(1);assert(not Cyber.isActive())
assert(f.managed[990]=='ambient' and DispatchRewardFixture.wallet==0)

-- Exercise the actual shipped CET request and cancel button handlers.
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
assert(labels[pressed] and Dispatch.isActive() and #f.creates==1)
dispatcher(0.25);assert(c:GetStage()==2)
pressed='Cancel active dispatch';callbacks.onDraw()
assert(labels[pressed] and not Dispatch.isActive() and f:State()==1)
