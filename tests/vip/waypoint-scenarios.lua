local v,f,n=VIPFixture,CyberFixture,VIPNative
local VIP=require('vip')
local function log(text) f.logs[#f.logs+1]=text end
local function update(seconds)
 for _=1,math.floor(seconds*4+.001) do VIP.update(.25,f.duty,f.patrol,log,{set=function() end}) end
end
local function reset()
 VIP.reset();v:Reset()
 assert(VIP.request(f.patrol,log,true,true))
end
local function ownPin(x)
 local count,found=0,nil
 for _,pin in pairs(v.pins) do if pin.point.x==x then count=count+1;found=pin end end
 assert(count==1,'expected exactly one VIP waypoint at '..x)
 return found
end

-- Reported failure: an accepted pickup marker disappears while the native
-- quest remains in responding/stage 1. Restore pickup, not the hidden drop-off.
reset();local token=n:GetToken();local pin=ownPin(800)
Game.GetMappinSystem():UnregisterMappin(pin.id)
update(3)
assert(n:GetStage()==1 and n:GetToken()==token and #f.creates==0)
assert(ownPin(800).active and v.registrations==2,'missing pickup marker was not restored')
assert(VIP.diagnostics():find('waypoint=',1,true) and VIP.diagnostics():find('waypoint repairs=1',1,true))
update(10);assert(v.registrations==2,'healthy marker was recreated continuously')
VIP.cancel(f.patrol,log)

-- Nonzero registration with no published pin is treated as pending, then
-- recovered. A short registry delay is allowed without repeated registration.
reset();pin=ownPin(800);pin.hidden=true
update(1.5);assert(v.registrations==1)
pin.hidden=false;update(3);assert(v.registrations==1 and ownPin(800).active)
VIP.cancel(f.patrol,log)
reset();pin=ownPin(800);pin.hidden=true
update(3);assert(v.registrations==2 and ownPin(800).active)
assert(not v.pins[pin.id.value],'pending old ID was kept alongside replacement')
VIP.cancel(f.patrol,log)

-- An inactive or displaced marker is reactivated/repositioned in place.
reset();pin=ownPin(800);pin.active=false;pin.point=Vector4.new(2200,10,50,1)
update(2);assert(ownPin(800)==pin and pin.active and v.registrations==1)
assert(pin.point.y==0 and pin.point.z==0)
VIP.cancel(f.patrol,log)

-- Temporary API/registration failure keeps the live quest/token and retries
-- at most once every five seconds. Restoring the API needs no new dispatch.
reset();token=n:GetToken();pin=ownPin(800)
Game.GetMappinSystem():UnregisterMappin(pin.id)
f.mapPresent=false;update(3);assert(n:GetStage()==1 and v.registrations==1)
f.mapPresent=true;f.markerOK=false
local attempts=0;local place=f.patrol.PlaceDispatchWaypoint
function f.patrol:PlaceDispatchWaypoint(point) attempts=attempts+1;return place(self,point) end
update(12);assert(attempts==3,'missing marker requests were not throttled')
assert(n:GetStage()==1 and n:GetToken()==token and v.registrations==1)
f.markerOK=true;update(5)
assert(ownPin(800).active and n:GetStage()==1 and n:GetToken()==token)
f.patrol.PlaceDispatchWaypoint=place
VIP.cancel(f.patrol,log)

-- Native stage two after actual boarding replaces pickup with delivery.
-- A missing delivery marker is restored to the delivery, not the old pickup.
reset();pin=ownPin(800);f.playerPosition.x=780;update(1)
local witness=f.actors[1001];v:Drive();update(.25)
v:Mount(witness,v.car);update(.5)
assert(n:GetStage()==2 and not v.pins[pin.id.value])
pin=ownPin(1800);Game.GetMappinSystem():UnregisterMappin(pin.id)
token=n:GetToken();update(3)
assert(ownPin(1800).active and n:GetStage()==2 and n:GetToken()==token)
assert(v.registrations==3 and IncidentRewardFixture.wallet==0)
VIP.cancel(f.patrol,log)

-- Scoped repair/cancellation never clears a different dispatch marker. There
-- is no delayed restore after cancellation, completion or a loaded-world reset.
reset();pin=ownPin(800)
local foreign=f.patrol:PlaceDispatchWaypoint(Vector4.new(2600,0,0,1))
Game.GetMappinSystem():UnregisterMappin(pin.id);update(3)
assert(v.pins[foreign.value] and ownPin(800))
VIP.cancel(f.patrol,log);local registrations=v.registrations;update(10)
assert(v.pins[foreign.value] and v.registrations==registrations)
for _,id in ipairs(v.unregistrations) do assert(id~=foreign.value,'foreign marker removed') end
reset();local removes=#v.unregistrations;registrations=v.registrations
VIP.reset();n:OnRestored(0,0);update(5)
assert(#v.unregistrations==removes and v.registrations==registrations,'old-world ID was touched')

-- Opening game menus pauses inspection/repair; close the menu to recover.
reset();pin=ownPin(800);Game.GetMappinSystem():UnregisterMappin(pin.id)
f.paused=true;update(20);assert(v.registrations==1)
f.paused=false;update(3);assert(ownPin(800).active and v.registrations==2)
VIP.cancel(f.patrol,log)

-- Initial failure still closes the assignment rather than reporting a usable
-- pickup when the native API never returned a valid ID.
VIP.reset();v:Reset();f.markerOK=false
assert(not VIP.request(f.patrol,log,true,true) and not VIP.isActive())
assert(n:GetStage()==4 and IncidentRewardFixture.wallet==0)

-- Explicit refresh replaces a valid registered pin too, for a renderer issue
-- that registry inspection alone cannot detect. It preserves journal/token.
reset();pin=ownPin(800);token=n:GetToken()
assert(VIP.refreshWaypoint(f.patrol,log) and n:GetStage()==1 and n:GetToken()==token)
assert(not v.pins[pin.id.value] and ownPin(800).active and v.registrations==2)
VIP.cancel(f.patrol,log)
registrations=v.registrations
assert(not VIP.refreshWaypoint(f.patrol,log) and v.registrations==registrations)
