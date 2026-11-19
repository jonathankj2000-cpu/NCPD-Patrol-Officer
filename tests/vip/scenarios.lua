local v,f,n=VIPFixture,CyberFixture,VIPNative
local pickup={x=800,y=0,z=0,w=1};local drop={x=1800,y=0,z=0,w=1}
local function begin()
 local token=n:BeginDispatch(pickup,drop);assert(token>0,n:GetReason());return token
end
local function bind()
 local token=begin();f.playerPosition.x=780
 local actor=v:Actor();assert(n:CanSpawn(token) and n:BindVIP(token,actor))
 return token,actor
end
local function boarded()
 local token,actor=bind();v:Drive();v:Mount(actor,v.car)
 assert(n:ConfirmBoarded(token,v.car));return token,actor
end
-- Only this private witness and actual engine mounting can advance objective 1.
v:Reset();local token=begin();assert(v:State('/main/pickup')==2 and v:State('/main/deliver')==1)
assert(not n:CanSpawn(token) and not n:BindVIP(token,v:Actor()))
f.playerPosition.x=780
assert(not n:BindVIP(token,v:Actor('Character.unrelated')))
local actor=v:Actor();actor.dead=true;assert(not n:BindVIP(token,actor));actor.dead=false
assert(n:BindVIP(token,actor) and not n:BindVIP(token,v:Actor()))
v:Drive();assert(not n:ConfirmBoarded(token,v.car),'sent command was mistaken for actual mounting')
v:Mount(actor,v.car);v.player.seat='seat_front_right';assert(not n:ConfirmBoarded(token,v.car),'passenger accepted as driver')
v.player.seat='seat_front_left';v.car.owned=false;assert(not n:ConfirmBoarded(token,v.car))
v.car.owned=true;v:Mount(actor,v:Car({hash=90}));assert(not n:ConfirmBoarded(token,v.car))
v:Mount(actor,v.car);assert(n:ConfirmBoarded(token,v.car));assert(v:State('/main/pickup')==3 and v:State('/main/deliver')==2)
assert(not n:ConfirmBoarded(token,v.car),'duplicate boarding transition')
-- Delivery requires a live, actually unmounted witness at the safe location.
v.car.pos.x=1800;f.playerPosition.x=1800;v.car.speed=5
assert(not n:CanDropOff(token));v.car.speed=0
assert(n:CanDropOff(token) and n:BeginDropOff(token));v:Advance(1)
assert(n:GetStage()==2,'unmount request alone completed quest')
actor.mounted=nil;actor.pos.x=1500;v:Advance(0.25);assert(n:GetStage()==2)
actor.pos.x=1800;v:Advance(0.25);assert(n:GetStage()==3 and v:State()==3)
local writes=#JournalFixture.writes;v:Advance(2);assert(#JournalFixture.writes==writes and DispatchRewardFixture.wallet==0)
-- Fresh requests do not inherit a previous target/drop-off or accept stale tokens.
f.playerPosition.x=0;local fresh=begin();assert(fresh~=token and n.m_arrived==false and n.m_dropStarted==false)
n:Cancel(token,'stale');assert(n:GetStage()==1);n:Cancel(fresh,'cancel');assert(v:State()==1)
for _,condition in ipairs({'dead','deadNoPool','defeated','unconscious'}) do
 v:Reset();token,actor=boarded();actor[condition]=true;v:Advance(0.25);assert(n:GetStage()==4 and v:State()==4)
end
v:Reset();token,actor=boarded();actor.attached=false;v:Advance(7.75);assert(n:GetStage()==2)
v:Advance(0.25);assert(n:GetStage()==4,'streamed-out witness succeeded or did not fail')
v:Reset();token,actor=boarded();n.m_target=nil;v:Advance(8);assert(n:GetStage()==4)
v:Reset();token,actor=boarded();v.car.destroyed=true;v:Advance(0.25);assert(n:GetStage()==4)
v:Reset();token,actor=bind();f.playerPosition.x=1200;v:Advance(10);assert(n:GetStage()==4)
v:Reset();token=begin();f.paused=true;v:Advance(400);assert(n:GetRemainingSeconds()==300)
f.paused=false;v:Advance(300);assert(n:GetStage()==4)
v:Reset();token=begin();f.wanted=true;v:Advance(0.25);assert(n:GetStage()==4)
v:Reset();token=begin();f.duty=false;v:Advance(0.25);assert(n:GetStage()==5)
v:Reset();local story=JournalFixture:Story();JournalFixture.tracked=story;token,actor=boarded()
n:Cancel(token,'cancel');assert(JournalFixture.tracked==story)
v:Reset();token=begin();n:OnRestored(0,0);n:Tick(0.25);assert(n:GetStage()==0 and v:State()==1)
for _,coords in ipairs({{x=499,y=0,z=0},{x=2001,y=0,z=0},{x=0/0,y=0,z=0}}) do
 v:Reset();assert(n:BeginDispatch(coords,drop)==0)
end
v:Reset();JournalFixture.ignoreWrites=true;assert(n:BeginDispatch(pickup,drop)==0)

-- Run actual Lua transport modules with the same native controller.
local VIP=require('vip');local Ambush=require('vip_ambush')
local HUD={set=function(text,visible) v.hud=visible and text or '' end}
local function log(text) f.logs[#f.logs+1]=text end
local function reset() VIP.reset();v:Reset() end
-- Selection reads terminal geography, not fast-travel interaction availability
-- (which can be false in a car). Drop points cover sparse/empty discovered FT
-- networks without registering/unlocking any fast-travel node.
for case=1,4 do
 reset();v:Drive()
 if case==1 then
  f.places={f:Place(800,0,0,'fasttravel',false),f:Place(1800,0,0,'fasttravel',false)}
 elseif case==2 then
  f.places={f:Place(800,0,0,'drop-point',false),f:Place(1800,0,0,'drop-point',false)}
 elseif case==3 then
  f.places={f:Place(800,0,0,'fasttravel',false),f:Place(1800,0,0,'drop-point',false)}
 else
  f.places={f:Place(800,0,0,'fasttravel',false),f:Place(1800,0,0,'fasttravel',false),f:Place(850,0,0,'drop-point')}
 end
 for _,pin in ipairs(f.places) do function pin:IsActive() error('interaction availability must not filter VIP locations') end end
 assert(VIP.request(f.patrol,log,true,true),table.concat(f.logs,'\n'))
 assert(#f.creates==0 and f.markers[1].x==800 and n:GetStage()==1)
 assert(VIP.diagnostics():find(case==2 and 'selected=drop point -> drop point' or case==3 and 'selected=fast travel -> drop point' or 'selected=fast travel -> fast travel',1,true))
 assert(VIP.cancel(f.patrol,log))
end
-- Drop-point fallback keeps the distance, scanner safety and finite-coordinate
-- checks. A blocked terminal is never used as a fallback destination.
for _,bad in ipairs({'near','far','short-trip','scanner','nan','unrelated'}) do
 reset()
 local x=bad=='near' and 100 or bad=='far' and 2500 or 800
 local other=bad=='short-trip' and 1000 or 1800
 local variant=bad=='unrelated' and 'unrelated' or 'drop-point'
 f.places={f:Place(x,0,0,variant),f:Place(other,0,0,variant)}
 if bad=='near' then f.places[2]=f:Place(200,0,0,variant) end
 if bad=='far' then f.places[2]=f:Place(3500,0,0,variant) end
 if bad=='scanner' then f.places[#f.places+1]=f:Place(800,0,0,'assault',true,2) end
 if bad=='nan' then f.places[1]=f:Place(0/0,0,0,variant) end
 assert(not VIP.request(f.patrol,log,true,true),'unsafe fallback pair '..bad)
 assert(#f.creates==0 and n:GetStage()==0 and not VIP.isActive())
end
reset()
local function step(seconds)
 for _=1,math.floor((seconds or .25)*4+0.0001) do VIP.update(.25,f.duty,f.patrol,log,HUD) end
end
local function request()
 assert(VIP.request(f.patrol,log,true,true),table.concat(f.logs,'\n'))
 assert(#f.creates==0 and #f.markers==1 and f.markers[1].x==800,'spawned beside player or revealed delivery too early')
 assert(not VIP.request(f.patrol,log,true,true) and not VIP.requestAmbush(log))
end
local function ready()
 request();f.playerPosition.x=780;step(1)
 assert(#f.creates==1 and f.creates[1].recordID=='Character.NCPDPatrol_VIP',table.concat(f.logs,'\n'))
 local a=f.actors[1001];assert(a and a.role)
 v:Drive();v.car.occupied.seat_front_right=true;step(.5)
 return a
end
local function enter()
 local a=ready();local cmd=a.commands[#a.commands]
 assert(cmd.kind=='mount' and cmd.mountData.slotName=='seat_back_right','partner seat not respected')
 assert(n:GetStage()==1 and v:State('/main/deliver')==1)
 v:Mount(a,v.car,'seat_back_right');step(.5)
 assert(n:GetStage()==2 and v:State('/main/deliver')==2 and f.markers[1].x==1800)
 return a
end
reset();actor=enter();assert(not VIP.request(f.patrol,log))
-- Destination is hidden until genuine mounting; occupied seats are never stolen.
reset();request();f.playerPosition.x=780;step(1);actor=f.actors[1001]
v:Drive();v.car.occupied={seat_front_right=true,seat_back_right=true,seat_back_left=true};step(1)
assert(actor.commands[#actor.commands].kind=='follow' and n:GetStage()==1)
v.car.occupied.seat_back_right=false;step(.25);assert(actor.commands[#actor.commands].mountData.slotName=='seat_back_right')
-- Cancelling from the coordinated dispatcher blocks new work until deletes finish.
local Dispatch=require('dispatch')
Dispatch.reset();v:Reset();Dispatch.start(f.patrol,log)
assert(Dispatch.requestVIP(f.patrol,log))
assert(not Dispatch.requestCyberpsycho(f.patrol,log) and not Dispatch.request(f.patrol,log))
f.playerPosition.x=780;Dispatch.update(.25,true,log,function() return f.patrol end)
Dispatch.update(.25,true,log,function() return f.patrol end)
f.deleteOK=false;assert(not Dispatch.cancel(f.patrol,log) and Dispatch.isActive())
assert(not Dispatch.replace(f.patrol,log));f.deleteOK=true
for _=1,12 do Dispatch.update(.25,true,log,function() return f.patrol end) end
assert(not Dispatch.isActive() and f.managed[990]=='ambient')
-- A pending deletion remains reserved even when DeleteEntity returned true.
reset();actor=enter();f.deleteDeferred=true
assert(not VIP.cancel(f.patrol,log) and VIP.isActive())
f.managed[1001]=nil;step(2);assert(not VIP.isActive())
-- Load reconciliation closes the old journal and never deletes old-world IDs.
reset();actor=enter();local oldDeletes=#f.deletes
VIP.reset();n:OnRestored(0,0);step(.25)
assert(v:State()==1 and #f.deletes==oldDeletes)
-- Paused UI hides the custom HUD, with neither timer nor ambush advancing.
reset();actor=enter();local seconds=n:GetRemainingSeconds();f.paused=true;step(2)
assert(n:GetRemainingSeconds()==seconds and v.hud=='');f.paused=false
-- Manual ambush waits for actual driven road history; one car, two gang members.
reset();actor=enter();assert(VIP.requestAmbush(log));step(1);assert(#f.creates==1)
v.car.speed=16
for _=1,40 do v.car.pos.x=v.car.pos.x+4;f.playerPosition.x=v.car.pos.x;step(.25) end
assert(#f.creates==4 and v.ambushCar and v.lastAmbushSpawnDistance>=35 and v.lastAmbushSpawnDistance<=65,table.concat(f.logs,'\n'))
step(1)
local enemy=v.ambushCar
assert(enemy.initCmd and enemy.initCmd.kind=='chase' and enemy.initCmd.target==v.player)
assert(enemy.initCmd.ignoreChaseVehiclesLimit and enemy.chaseDestination)
assert(not VIP.requestAmbush(log) and #f.creates==4)
-- Three stopped seconds -> brake -> wait for actual standstill -> animated exit.
v.car.speed=0;enemy.speed=8;enemy.pos.x=v.car.pos.x-25
step(2.75);assert(enemy.brakes~=8)
step(.25);assert(enemy.brakes==8 and enemy.stopped==enemy.initCmd, tostring(enemy.brakes)..' | '..Ambush.state()..' | '..VIP.state()..' | '..n:GetReason()..' | '..table.concat(f.logs,'\n'))
local first,second=f.actors[1003],f.actors[1004]
assert(first.commands[#first.commands].kind=='mount','crew exited before car stopped')
enemy.speed=0;step(.5)
assert(first.commands[#first.commands].kind=='unmount' and not first.commands[#first.commands].mountData.isInstant)
assert(not first.commands[#first.commands].targetPuppetRef,'attacked before actual exit')
first.mounted=nil;second.mounted=nil;step(.25)
assert(first.commands[#first.commands].targetPuppetRef and first.attitude==EAIAttitude.AIA_Hostile)
-- Completing transport does not require killing those pursuers.
v.car.pos.x=1800;f.playerPosition.x=1800;step(.5)
assert(actor.commands[#actor.commands].kind=='unmount' and n:GetStage()==2)
actor.mounted=nil;actor.pos.x=1800;step(.25)
assert(n:GetStage()==3 and v:State()==3 and not Ambush.isActive() and #f.markers==0)
step(20);assert(not VIP.isActive() and f.managed[990]=='ambient' and DispatchRewardFixture.wallet==0)
-- Escape alone ends an ambush and must never spawn a replacement this trip.
reset();actor=enter();assert(VIP.requestAmbush(log));v.car.speed=16
for _=1,40 do v.car.pos.x=v.car.pos.x+4;f.playerPosition.x=v.car.pos.x;step(.25) end
step(1);enemy=v.ambushCar;enemy.pos.x=v.car.pos.x-400;step(10)
assert(not Ambush.isActive() and not VIP.requestAmbush(log));step(1);assert(#f.creates==4)
VIP.cancel(f.patrol,log);assert(not VIP.isActive())
-- Partial creation failure cleans the already-created car; no ambient deletion.
reset();actor=enter();assert(VIP.requestAmbush(log));v.car.speed=16
local create=v.entities.CreateEntity
function v.entities:CreateEntity(spec)
 if spec.recordID=='Character.NCPDPatrol_VIPAttacker' then return {hash=0} end
 return create(self,spec)
end
for _=1,40 do v.car.pos.x=v.car.pos.x+4;f.playerPosition.x=v.car.pos.x;step(.25) end
assert(not Ambush.isActive() and n:GetStage()==2 and f.managed[990]=='ambient')
v.entities.CreateEntity=create;VIP.cancel(f.patrol,log)
-- Shutdown keeps refused deletions reserved; a genuine world reset forgets them.
Dispatch.reset();v:Reset();Dispatch.start(f.patrol,log)
assert(Dispatch.requestVIP(f.patrol,log));f.playerPosition.x=780
for _=1,4 do Dispatch.update(.25,true,log,function() return f.patrol end) end
f.deleteOK=false;Dispatch.shutdown(f.patrol);assert(Dispatch.isActive())
f.deleteOK=true
for _=1,12 do Dispatch.update(.25,false,log,function() return f.patrol end) end
assert(not Dispatch.isActive())
-- Active camera, not vehicle facing: full padded scene bounds must be hidden.
v:Reset();token,actor=boarded()
local function point(x,y,z) return Vector4.new(x,y or 0,z or 0,1) end
for _,fov in ipairs({45,75,110}) do
 for _,aspect in ipairs({4/3,21/9,32/9}) do
  v.cameraFOV=fov;v.cameraAspect=aspect;v.cameraYaw=0
  assert(n:CanSpawnAmbushAt(point(755)))
  assert(not n:CanSpawnAmbushAt(point(845)))
  v.cameraYaw=math.pi
  assert(not n:CanSpawnAmbushAt(point(755)),'looking backwards allowed visible spawning')
 end
end
v.cameraYaw=0;v.cameraFOV=60;v.cameraAspect=16/9
assert(not n:CanSpawnAmbushAt(point(839,55)),'visible edge of crew/car bounds ignored')
assert(n:CanSpawnAmbushAt(point(839,85)),'fully off-screen scene was blocked')
v.cameraPresent=false;assert(not n:CanSpawnAmbushAt(point(755)));v.cameraPresent=true
v.cameraTransformOK=false;assert(not n:CanSpawnAmbushAt(point(755)));v.cameraTransformOK=true
for _,fov in ipairs({0,180,0/0}) do v.cameraFOV=fov;assert(not n:CanSpawnAmbushAt(point(755))) end
v.cameraFOV=75;v.cameraAspect=0/0;assert(not n:CanSpawnAmbushAt(point(755)))
v.cameraAspect=16/9;assert(not n:CanSpawnAmbushAt(point(0/0)))
f.wanted=true;assert(not n:CanSpawnAmbushAt(point(755)));f.wanted=false
n:Cancel(token,'test');assert(not n:CanSpawnAmbushAt(point(755)))
local function driveTrail()
 v.car.speed=16
 for _=1,40 do v.car.pos.x=v.car.pos.x+4;f.playerPosition.x=v.car.pos.x;step(.25) end
end
local function spawnAmbush()
 reset();local witness=enter();assert(VIP.requestAmbush(log));driveTrail();step(1)
 assert(v.ambushCar and #f.creates==4)
 return witness,v.ambushCar,f.actors[1003],f.actors[1004]
end
-- A bridge keeps its actual collision height. Crew are created over the
-- verified car, never on the old +3/+6 m roadside offsets.
reset();actor=enter();v.car.pos.z=20;f.playerPosition.z=20;v.roadHeight=20
assert(VIP.requestAmbush(log));driveTrail();step(1)
assert(v.ambushCar and math.abs(v.ambushCar.pos.z-20.15)<.001 and v.ambushCar.initCmd)
assert(#f.creates==4 and f.creates[3].position.x==f.creates[2].position.x
 and f.creates[3].position.y==f.creates[2].position.y)
VIP.cancel(f.patrol,log)
-- If native creation settles under the bridge, no crew/hostile warning is
-- started. Delete the failed owned car before retry; bound retries to three.
reset();actor=enter();v.car.pos.z=20;f.playerPosition.z=20;v.roadHeight=20
v.carSpawnOffset={z=-12};assert(VIP.requestAmbush(log));v.car.speed=16
for _=1,130 do v.car.pos.x=v.car.pos.x+4;f.playerPosition.x=v.car.pos.x;step(.25) end
step(2)
local failedCars=0
for _,spec in ipairs(f.creates) do
 if spec.recordID=='Vehicle.NCPDPatrol_VIPAmbush' then failedCars=failedCars+1 end
 assert(spec.recordID~='Character.NCPDPatrol_VIPAttacker','crew spawned on the wrong road level')
end
assert(failedCars==3 and not Ambush.isActive() and n:GetStage()==2)
for _,notice in ipairs(f.notices) do assert(not notice.text:find('Possible hostile vehicle',1,true)) end
assert(not VIP.requestAmbush(log),'failed road placement bypassed retry bound')
VIP.cancel(f.patrol,log)
-- A lateral native displacement beyond the lane is also rejected. A later
-- checked attempt can succeed, without consuming multiple active ambushes.
reset();actor=enter();v.carSpawnOffset={y=4};assert(VIP.requestAmbush(log));v.car.speed=16
for _=1,40 do
 v.car.pos.x=v.car.pos.x+4;f.playerPosition.x=v.car.pos.x;step(.25)
 if #f.creates>1 then break end
end
step(2)
assert(not Ambush.isActive() and #f.creates==2)
v.carSpawnOffset=nil;driveTrail();step(1)
assert(Ambush.isActive() and v.ambushCar.initCmd and #f.creates==5)
VIP.cancel(f.patrol,log)
-- Failed road placement must keep its reservation while native deletion is
-- deferred, even if DeleteEntity returns true. Only confirmed cleanup retries.
reset();actor=enter();v.carSpawnOffset={y=4};f.deleteDeferred=true
assert(VIP.requestAmbush(log));v.car.speed=16
for _=1,40 do
 v.car.pos.x=v.car.pos.x+4;f.playerPosition.x=v.car.pos.x;step(.25)
 if #f.creates>1 then break end
end
step(3);assert(Ambush.isActive() and #f.creates==2 and not VIP.requestAmbush(log))
driveTrail();assert(#f.creates==2,'retried before the wrong-lane car was actually gone')
f.managed[1002]=nil;f.actors[1002]=nil;f.deleteDeferred=false;v.carSpawnOffset=nil
step(2.25);driveTrail();step(1)
assert(#f.creates==5 and v.ambushCar.initCmd and f.managed[990]=='ambient')
VIP.cancel(f.patrol,log)
-- No surface query, missing bridge deck, or a barrier in the swept car
-- corridor waits safely without creating entities or consuming the request.
for _,blocked in ipairs({'query','floor','barrier'}) do
 reset();actor=enter();assert(VIP.requestAmbush(log))
 if blocked=='query' then v.spatialAvailable=false elseif blocked=='floor' then v.roadMissing=true else v.roadBlocked=true end
 driveTrail();assert(#f.creates==1 and not Ambush.isActive())
 v.spatialAvailable=true;v.roadMissing=false;v.roadBlocked=false
 driveTrail();step(1);assert(#f.creates==4 and v.ambushCar.initCmd)
 VIP.cancel(f.patrol,log)
end
-- An earlier loop can be close in the world but hundreds of metres back along
-- the road. It cannot become a spawn across a median/on another carriageway.
reset();actor=enter();assert(VIP.requestAmbush(log));v.cameraYaw=math.pi;v.car.speed=16
local function move(dx,dy,steps)
 for _=1,steps do
  v.car.pos.x=v.car.pos.x+dx;v.car.pos.y=v.car.pos.y+dy
  f.playerPosition.x=v.car.pos.x;f.playerPosition.y=v.car.pos.y;step(.25)
 end
end
move(4,0,10);move(0,4,25);move(4,0,25);move(0,-4,25);move(-4,0,10)
v.cameraYaw=0;step(.25)
assert(#f.creates==1,'air distance selected an old road loop')
move(4,0,25);step(1);assert(#f.creates==4 and v.ambushCar.initCmd)
VIP.cancel(f.patrol,log)
-- Waiting while looking back does not consume the single ambush reservation.
reset();actor=enter();assert(VIP.requestAmbush(log));v.cameraYaw=math.pi;driveTrail()
assert(#f.creates==1 and not Ambush.isActive())
v.cameraPresent=false;v.cameraYaw=0;step(1);assert(#f.creates==1)
v.cameraPresent=true;v.cameraTransformOK=false;step(1);assert(#f.creates==1)
v.cameraTransformOK=true;v.autoCrewMount=false
local function notices()
 local count=0
 for _,notice in ipairs(f.notices) do if notice.text:find('Possible hostile vehicle',1,true) then count=count+1 end end
 return count
end
step(1);assert(#f.creates==4 and notices()==0,'warning preceded actual attached/seated attackers')
local enemy=v.ambushCar;local a,b=f.actors[1003],f.actors[1004]
v:Mount(a,enemy,'seat_front_left');v:Mount(b,enemy,'seat_front_right');step(.25)
assert(enemy.initCmd and notices()==1 and v.lastAmbushSpawnDistance<=65)
VIP.cancel(f.patrol,log)
-- Last kill/down while STILL SEATED retains car/bodies for 90 gameplay seconds.
for _,state in ipairs({'dead','defeated'}) do
 local witness,enemy,a,b=spawnAmbush();v.car.speed=0;enemy.pos.x=v.car.pos.x-30
 a[state]=true;step(.25);assert(Ambush.isActive() and f.managed[1003])
 b[state]=true;step(.25)
 assert(Ambush.state():find('scene retained',1,true) and f.managed[1002] and f.managed[1003] and f.managed[1004])
 assert(not VIP.requestAmbush(log) and #f.creates==4)
 step(89.75);assert(Ambush.isActive() and f.managed[1003])
 f.paused=true;step(60);assert(Ambush.isActive());f.paused=false
 step(.25);assert(not Ambush.isActive() and not f.managed[1002] and n:GetStage()==2)
 VIP.cancel(f.patrol,log)
end
-- Distance cleanup checks ALL bodies as well as the car, with three-second grace.
actor,enemy,a,b=spawnAmbush();v.car.speed=0;enemy.pos.x=v.car.pos.x-30
for _,unit in ipairs({a,b}) do unit.mounted=nil;unit.pos=point(enemy.pos.x);unit.defeated=true end
step(.25)
-- Player may be far from the car while standing beside a body.
enemy.pos.x=v.car.pos.x-250;step(4);assert(Ambush.isActive())
for _,unit in ipairs({a,b}) do unit.pos=point(enemy.pos.x) end
step(2.75);assert(Ambush.isActive());step(.25);assert(not Ambush.isActive())
VIP.cancel(f.patrol,log)
-- Successful delivery and the VIP's own cleanup must not erase retained bodies.
actor,enemy,a,b=spawnAmbush();v.car.speed=0;v.car.pos.x=1800;f.playerPosition.x=1800;enemy.pos.x=1780
for _,unit in ipairs({a,b}) do unit.mounted=nil;unit.pos=point(1780);unit.dead=true end
step(.25);assert(Ambush.isActive())
step(.25);actor.mounted=nil;actor.pos=point(1800);step(.25)
assert(n:GetStage()==3 and Ambush.isActive() and f.managed[1003])
step(21);assert(VIP.isActive() and Ambush.isActive() and f.managed[1003] and not f.managed[1001])
f.playerPosition.x=2000;step(5)
assert(not VIP.isActive() and not Ambush.isActive() and f.managed[990]=='ambient')
-- Explicit cancel/shift end still tears down immediately, with retry reservation.
actor,enemy,a,b=spawnAmbush();a.dead=true;b.dead=true;step(.25)
f.deleteOK=false;assert(not VIP.cancel(f.patrol,log) and VIP.isActive())
f.deleteOK=true;step(2);assert(not VIP.isActive() and not Ambush.isActive())
