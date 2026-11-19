-- Actual convoy manager plus independent car controllers. Only engine state,
-- actor movement/attachment and mount completion are supplied by the fixture.
local v,f,n=VIPFixture,CyberFixture,VIPNative
local VIP,Ambush,Dispatch=require('vip'),require('vip_ambush'),require('dispatch')
local function log(text) f.logs[#f.logs+1]=text end
local function step(seconds)
 for _=1,math.floor((seconds or .25)*4+.0001) do VIP.update(.25,f.duty,f.patrol,log,{set=function() end}) end
end
local function enter(count)
 VIP.reset();v:Reset();assert(Ambush.configure(count))
 assert(VIP.request(f.patrol,log,true,true))
 f.playerPosition.x=780;step(1)
 local actor=f.actors[1001];assert(actor and n:GetStage()==1)
 v:Drive();step(.25);assert(actor.commands[#actor.commands].kind=='mount')
 v:Mount(actor,v.car);step(.5);assert(n:GetStage()==2)
 return actor
end
local function drive(steps)
 v.car.speed=16
 for _=1,steps or 40 do
  v.car.pos.x=v.car.pos.x+4;f.playerPosition.x=v.car.pos.x;step(.25)
 end
end
local function notices()
 local count=0
 for _,notice in ipairs(f.notices) do if notice.text:find('Possible hostile vehicle',1,true) then count=count+1 end end
 return count
end
local function carCrew(car)
 local crew={}
 for _,actor in pairs(f.actors) do
  if actor.record=='Character.NCPDPatrol_VIPAttacker' then
   local command=actor.commands[#actor.commands]
   if command and command.mountData and command.mountData.mountParentEntityId.hash==car.id.hash then crew[#crew+1]=actor end
  end
 end
 return crew
end
local function verifyConvoy(count,seated)
 assert(#v.ambushCars==count and #f.creates==1+count*3,table.concat(f.logs,'\n'))
 for i,car in ipairs(v.ambushCars) do
  assert(f.managed[car.id.hash] and (not seated or car.initCmd and car.initCmd.kind=='chase'))
  local crew=carCrew(car);assert(#crew==2,'convoy car did not own exactly two attackers')
  local seats={}
  for _,actor in ipairs(crew) do
   assert(f.managed[actor.id.hash] and (not seated or actor.mounted==car))
   local data=actor.commands[#actor.commands].mountData
   seats[data.slotName]=true
  end
  assert(seats.seat_front_left and seats.seat_front_right)
  for j=1,i-1 do
   local other=v.ambushCars[j]
   local x,y,z=car.pos.x-other.pos.x,car.pos.y-other.pos.y,car.pos.z-other.pos.z
   assert(x*x+y*y+z*z>=144,'convoy cars overlapped their 12 m reservations')
  end
 end
 assert(n:GetStage()==2 and f.managed[990]=='ambient')
end

-- The actual dispatcher/VIP adapters expose the CET preference. It cycles
-- Random -> 1 -> 2 -> 3 -> Random, rejects invalid input and starts no actors.
VIP.reset();v:Reset();assert(Ambush.configure(0))
assert(Dispatch.vipAmbushCars()=='Random (1-3)')
for _,name in ipairs({'1 car','2 cars','3 cars','Random (1-3)'}) do
 assert(Dispatch.cycleVIPAmbushCars(log) and Dispatch.vipAmbushCars()==name)
end
for _,invalid in ipairs({-1,4,1.5,0/0,'3'}) do assert(not Ambush.configure(invalid)) end
assert(#f.creates==0 and Dispatch.vipAmbushCars()=='Random (1-3)')

-- Fixed sizes create a single convoy of separate cars. Re-arming a pending
-- request is idempotent; once a car has started, new requests cannot add cars.
for count=1,3 do
 enter(count);assert(VIP.requestAmbush(log));assert(VIP.requestAmbush(log));drive();step(1)
 verifyConvoy(count,true);assert(not VIP.requestAmbush(log) and notices()==1)
 local before=#f.creates
 assert(Ambush.configure(count==3 and 1 or 3,log));step(1)
 assert(#f.creates==before,'changing preference rebuilt a live convoy')
 assert(VIP.cancel(f.patrol,log) and not VIP.isActive())
 for id in pairs(f.managed) do assert(id==990,'convoy cancel leaked an owned actor') end
end

-- Six accepted mount requests cannot trigger a warning by themselves. Cars
-- start separately after their own two actual mount completions; one warning.
enter(3);v.autoCrewMount=false;assert(VIP.requestAmbush(log))
for _=1,40 do drive(1);if #f.creates==10 then break end end
step(1)
verifyConvoy(3,false);assert(notices()==0)
local first=v.ambushCars[1];local crew=carCrew(first)
v:Mount(crew[1],first,crew[1].commands[#crew[1].commands].mountData.slotName)
step(.25);assert(not first.initCmd and notices()==0)
v:Mount(crew[2],first,crew[2].commands[#crew[2].commands].mountData.slotName)
step(.25);assert(first.initCmd and notices()==1 and not v.ambushCars[2].initCmd)
for _,car in ipairs(v.ambushCars) do
 for _,actor in ipairs(carCrew(car)) do v:Mount(actor,car,actor.commands[#actor.commands].mountData.slotName) end
end
step(.25);verifyConvoy(3,true);assert(notices()==1)

-- Defeating one crew retains its scene without stopping the other pursuers.
for _,actor in ipairs(carCrew(first)) do actor.defeated=true end
step(.25)
assert(Ambush.isActive() and Ambush.state():find('scene retained',1,true))
assert(v.ambushCars[2].initCmd and not v.ambushCars[2].stopped and f.managed[first.id.hash])

-- Every deferred ID remains reserved on cancellation. Partial cleanup cannot
-- permit another transport; after all IDs are really gone the reservation ends.
f.deleteDeferred=true
assert(not VIP.cancel(f.patrol,log) and VIP.isActive())
local ids={}
for id in pairs(f.managed) do if id>=1000 then ids[#ids+1]=id end end
f.managed[first.id.hash]=nil;step(2)
assert(VIP.isActive() and not VIP.request(f.patrol,log,true,true))
for _,id in ipairs(ids) do f.managed[id]=nil;f.actors[id]=nil end
step(2.25);assert(not VIP.isActive() and f.managed[990]=='ambient')

-- A failure building car 3's crew cleans only that car, without cancelling the
-- transport or the two already independent attacker crews.
enter(3);assert(VIP.requestAmbush(log))
local create=v.entities.CreateEntity
function v.entities:CreateEntity(spec)
 local third=v.ambushCars[3]
 if third and spec.recordID=='Character.NCPDPatrol_VIPAttacker'
  and math.abs(spec.position.x-third.pos.x)<.01 and math.abs(spec.position.y-third.pos.y)<.01 then return {hash=0} end
 return create(self,spec)
end
drive();step(1);v.entities.CreateEntity=create
assert(#v.ambushCars==3 and not f.managed[v.ambushCars[3].id.hash])
assert(f.managed[v.ambushCars[1].id.hash] and f.managed[v.ambushCars[2].id.hash] and notices()==1 and n:GetStage()==2)
VIP.cancel(f.patrol,log)

-- A blocked road may only have room for part of the planned convoy. Waiting
-- cars are closed after 20 gameplay seconds; clearing the road later cannot
-- produce a surprise second wave from the original request.
enter(3);assert(VIP.requestAmbush(log))
for _=1,40 do drive(1);if #f.creates>1 then break end end
v.roadBlocked=true;v.car.speed=0;step(22)
assert(#v.ambushCars==1 and #f.creates==4 and v.ambushCars[1].initCmd)
v.roadBlocked=false;drive();step(1)
assert(#v.ambushCars==1 and #f.creates==4 and not VIP.requestAmbush(log))
VIP.cancel(f.patrol,log)

-- Random mode stays within the requested 1-3 cars. With a deterministic RNG
-- seed, all three sizes are exercised through actual creation and cleanup.
math.randomseed(1968)
local sizes={}
for _=1,18 do
 enter(0);assert(VIP.requestAmbush(log));drive();step(1)
 local count=#v.ambushCars;assert(count>=1 and count<=3)
 sizes[count]=true;verifyConvoy(count,true);assert(notices()==1)
 assert(VIP.cancel(f.patrol,log))
end
assert(sizes[1] and sizes[2] and sizes[3])

-- Reset/load forgets the whole fleet without deleting IDs in a new world.
enter(3);assert(VIP.requestAmbush(log));drive();step(1)
local deletes=#f.deletes
VIP.reset();n:OnRestored(0,0);step(.25)
assert(#f.deletes==deletes and not Ambush.isActive())
Ambush.configure(1)
