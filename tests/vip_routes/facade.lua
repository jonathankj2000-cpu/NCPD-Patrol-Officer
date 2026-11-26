-- Real VIP facade, current baked selector and translated native VIP/reward
-- controllers. Only travel, physical attachment, seats and rendering are faked.
local VIP,Ambush=require('vip'),require('vip_ambush')
local f,v,n=CyberFixture,VIPFixture,VIPNative
local function status(text) f:Status(text) end
local HUD={set=function() end}
local function step(seconds)
    for _=1,math.floor(seconds*4+.001) do VIP.update(.25,f.duty,f.patrol,status,HUD) end
end
local function at(point) f.playerPosition={x=point.x,y=point.y,z=point.z} end
VIP.reset();v:Reset();assert(Ambush.configure(1))
f.places={} -- no FT markers at all, including when driving.
at({x=-976.574707,y=-1155.406494,z=11.359848})
assert(VIP.request(f.patrol,status,true,true),table.concat(f.logs,'\n'))
assert(n:GetStage()==1 and #f.creates==0 and #f.markers==1)
assert(VIP.diagnostics():find('baked endpoints=60 | routes=360',1,true))
local pickup=f.markers[1]
assert(math.abs(pickup.x+976.574707)>2 or math.abs(pickup.y+1155.406494)>2,'Off-catalog target was reused')
at({x=pickup.x-20,y=pickup.y,z=pickup.z});v.car.pos={x=pickup.x,y=pickup.y,z=pickup.z}
step(1)
local witness=f.actors[1001]
assert(witness and witness.role and #f.creates==1,table.concat(f.logs,'\n'))
v:Drive();step(.5)
assert(n:GetStage()==1 and witness.commands[#witness.commands].kind=='mount','Sent command completed the pickup too early')
v:Mount(witness,v.car,'seat_back_right');step(.5)
assert(n:GetStage()==2 and #f.markers==1,'Delivery marker not switched after actual boarding')
local drop=f.markers[1]
assert(drop.x~=pickup.x or drop.y~=pickup.y)
v.car.pos={x=drop.x,y=drop.y,z=drop.z};at(drop)
step(.5);assert(witness.commands[#witness.commands].kind=='unmount')
witness.mounted=nil;witness.pos={x=drop.x,y=drop.y,z=drop.z};step(.5)
assert(n:GetStage()==3 and IncidentRewardFixture.wallet==2000 and IncidentNative:GetCompletedCount()==1)
assert(#f.markers==0,'Completed assignment retained its marker')
step(21);assert(not VIP.isActive() and not VIP.hasCleanup(),'Completed route blocked the next call')
assert(VIP.request(f.patrol,status,true,true),table.concat(f.logs,'\n'))
assert(n:GetStage()==1 and #f.markers==1)
assert(VIP.cancel(f.patrol,status) and #f.markers==0)
assert(IncidentRewardFixture.wallet==2000 and IncidentNative:GetCompletedCount()==1,'Cancel paid or progressed')
-- Ending a shift and world reset preserve the existing scoped cleanup rules.
assert(VIP.request(f.patrol,status,true,true))
f.duty=false;step(.5);assert(not VIP.isActive() and #f.markers==0)
VIP.reset();v:Reset();f.places={};assert(VIP.request(f.patrol,status,true,true))
assert(VIP.cancel(f.patrol,status))
