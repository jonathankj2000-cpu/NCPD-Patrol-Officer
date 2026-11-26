-- Production road selector, native camera test and complete backup controller.
-- The physics/camera/entity hardware is the boundary; no lane graph is emulated.
local b=BackupTestBoundary
local f,player,support,patrol,entities=b.f,b.player,b.support,b.patrol,b.entities
local vec,actor=b.vec,b.actor
local Approach=require('backup_approach')
local Backup=require('backup')
local world={}
GameInstance=GameInstance or {}
NCPDPatrolMarkerSession={WorldReady=function() return not world.unready end}
function SupportNative:GetGameInstance() return {} end
support.SpawnSafetyVersion=function() return SupportNative:SpawnSafetyVersion() end
support.CanSpawnBackupAt=function(_,p)
 return SupportNative:CanSpawnBackupAt({X=p.x,Y=p.y,Z=p.z,W=1})
end
support.GetBackupVehicle=function() return world.requestVehicle end
Transform={GetPosition=function(_,t) return t.position end,GetForward=function(_,t) return t.forward end,
 GetRight=function(_,t) return t.right end,GetUp=function(_,t) return t.up end}
function TanF(v) return math.tan(v) end
function Deg2Rad(v) return v*math.pi/180 end
function SqrtF(v) return math.sqrt(v) end
function MaxF(a,c) return math.max(a,c) end
function AbsF(v) return math.abs(v) end
local function nativeVec(x,y,z) return {X=x,Y=y,Z=z} end
local camera={}
function camera:GetActiveCameraWorldTransform(t)
 if world.badTransform then return false end
 local yaw=world.yaw or 0
 t.position=nativeVec(player.pos.x-6,player.pos.y,player.pos.z+2)
 t.forward=nativeVec(math.cos(yaw),math.sin(yaw),0)
 t.right=nativeVec(-math.sin(yaw),math.cos(yaw),0);t.up=nativeVec(0,0,1)
 return true
end
function camera:GetActiveCameraFOV() return world.fov or 75 end
function camera:GetAspectRatio() return world.aspect or 16/9 end
GameInstance.GetCameraSystem=function() return not world.noCamera and camera or nil end
local spatial={}
function spatial:SyncRaycastByCollisionGroup(a,c,group,statics,dynamics)
 assert(group=='Static' and statics and not dynamics)
 world.rays=(world.rays or 0)+1
 if a.x==c.x and a.y==c.y and a.z>c.z then
  if world.noFloor or (world.hole and math.abs(a.y)>.5 and a.x<-30) then return false,nil end
  local z=world.height or 0
  if world.uneven and math.abs(a.y)>.7 and a.x<-30 then z=.6 end
  if z>a.z or z<c.z then return false,nil end
  return true,{position=vec(a.x,a.y,z),normal=vec(0,0,world.steep and .5 or 1)}
 end
 if world.barrier and math.min(a.x,c.x)<=-20 and math.max(a.x,c.x)>=-20 then return true,{} end
 if world.crewBlocked and a.x==c.x and a.y==c.y and a.z<c.z then return true,{} end
 return world.bodyBlocked==true,nil
end
Game.GetSpatialQueriesSystem=function() return not world.noSpatial and spatial or nil end
local create=entities.CreateEntity
function entities:CreateEntity(spec)
 if spec.recordID:sub(1,10)=='Character.' then
  world.officerCreates=(world.officerCreates or 0)+1
  if world.failSecondOfficer and world.officerCreates==2 then return nil end
 end
 local id=create(self,spec)
 if spec.recordID:sub(1,8)=='Vehicle.' and world.badPlacement then
  f.actors[id.hash].pos=vec(spec.position.x,spec.position.y,spec.position.z-20)
 end
 return id
end
local function reset()
 Backup.finish(support);Backup.reset()
 world={};f.wanted=false;f.offDuty=false;f.paused=false;f.backupRequest=false;f.reserved=false
 f.deferDelete=false;f.refuseDelete=false;f.actors={};f.managed={}
 player.pos=vec(0,0,0);player.mounted=nil;player.dead=false
end
local function car(id)
 local c=actor({hash=id or 7000},'Vehicle.ownedPolice')
 c.speed=0;c.forward=vec(1,0,0);c.orientation={savedHeading=true}
 function c:GetCurrentSpeed() return self.speed end
 function c:GetWorldForward() return self.forward end
 function c:GetWorldOrientation() return self.orientation end
 return c
end
local function step(count)
 for _=1,count or 1 do Backup.update(.25,true,support,patrol,function() end) end
end
local function request()
 f.backupRequest=true;step(2)
end

-- Execute the actual native camera formula in the new backup context.
reset()
for _,fov in ipairs({50,75,110}) do
 for _,aspect in ipairs({4/3,16/9,21/9}) do
  world.fov=fov;world.aspect=aspect;world.yaw=0
  assert(support:CanSpawnBackupAt(vec(-40,0,0)))
  assert(not support:CanSpawnBackupAt(vec(40,0,0)))
  world.yaw=math.pi;assert(not support:CanSpawnBackupAt(vec(-40,0,0)))
 end
end
world.yaw=0;world.fov=75;world.aspect=16/9
for _,flag in ipairs({'noCamera','badTransform','unready'}) do
 world[flag]=true;assert(not support:CanSpawnBackupAt(vec(-40,0,0)));world[flag]=false
end
for _,fov in ipairs({0,180,0/0}) do world.fov=fov;assert(not support:CanSpawnBackupAt(vec(-40,0,0))) end
world.fov=75;f.wanted=true;assert(not support:CanSpawnBackupAt(vec(-40,0,0)));f.wanted=false
f.offDuty=true;assert(not support:CanSpawnBackupAt(vec(-40,0,0)));f.offDuty=false
player.attached=false;assert(not support:CanSpawnBackupAt(vec(-40,0,0)));player.attached=true
player.dead=true;assert(not support:CanSpawnBackupAt(vec(-40,0,0)));player.dead=false

-- No driven history: a continuous supported, unobstructed straight corridor.
reset();local road=Approach.new();local c=car()
local p=road.find(c,support)
assert(p and p.source=='checked straight approach' and p.position.x==-40)
assert(p.orientation==c.orientation)
assert(#p.crew==2 and p.crew[1].x==-45 and p.crew[1].y==-.8 and p.crew[2].y==.8)
assert(road.find(c,support,{vec(-40,0,0)}).position.x==-55,'rejected point immediately reused')
for _,flag in ipairs({'noSpatial','noFloor','hole','uneven','steep','barrier','bodyBlocked','crewBlocked'}) do
 world[flag]=true;assert(not road.find(c,support),flag);world[flag]=false
end
world.height=-20;assert(not road.find(c,support),'lower road/bridge accepted');world.height=nil
world.yaw=math.pi;assert(not road.find(c,support),'visible approach accepted');world.yaw=0

-- Actual recently driven positions/orientations survive walking to the trunk.
road.reset();c.speed=10
for x=-80,-5,5 do c.pos=vec(x,0,0);road.record(.25,c) end
c.pos=vec(0,0,0);c.speed=0
road.record(5,nil)
p=road.find(c,support)
assert(p and p.source=='recent driven route' and p.orientation==c.orientation)
assert(p.position.x<=-35 and p.position.x>=-85)
road.record(61,nil);assert(road.find(c,support).source=='checked straight approach','expired history reused')
local other=car(8000);other.speed=10;road.record(.25,other)
assert(road.find(other,support).source=='checked straight approach','different car inherited route')
road.record(.25,other)
other.pos=vec(300,0,0);road.record(.25,other)
local afterTeleport=road.find(other,support)
assert(not afterTeleport or afterTeleport.source=='checked straight approach','teleport inherited old route')
road.reset();assert(road.find(c,support).source=='checked straight approach')
-- Post-attachment validation catches relocation that a good requested point cannot.
c.pos=vec(-40,0,.3);p={ground=vec(-40,0,0)};assert(Approach.positioned(c,p))
c.pos=vec(-40,0,-20);assert(not Approach.positioned(c,p))
c.pos=vec(-30,0,.3);assert(not Approach.positioned(c,p))
c.pos=vec(0/0,0,0);assert(not Approach.positioned(c,p))

-- The actual controller records V's route before the trunk request, then uses
-- that exact vehicle's history after V has stepped out.
reset();c=car();c.speed=10;world.requestVehicle=c;player.mounted=c
for x=-80,-5,5 do c.pos=vec(x,0,0);step(1) end
c.pos=vec(0,0,0);c.speed=0;player.mounted=nil
local historyStart=#f.created;request()
assert(#f.created==historyStart+1 and Backup.state():find('recent driven route',1,true))
assert(f.created[#f.created].orientation==c.orientation)
Backup.finish(support)

-- Native visibility delays creation; no second patrol during the wait.
reset();local before=#f.created;world.yaw=math.pi
request();step(12)
assert(#f.created==before and f.reserved and Backup.isActive())
f.backupRequest=true;step(1);assert(#f.created==before)
world.yaw=0;step(2)
assert(#f.created==before+1 and f.created[before+1].recordID:sub(1,8)=='Vehicle.')
assert(f.created[before+1].spawnInView==false)
-- A correctly attached car must settle before either officer is created.
step(1);assert(#f.created==before+1)
step(1);assert(#f.created==before+3)
assert(f.created[before+2].spawnInView==false and f.created[before+3].spawnInView==false)
step(24);assert(Backup.state():find('on scene',1,true))
Backup.finish(support);assert(not Backup.isActive() and not f.reserved)

-- Turning towards the pending car prevents visible crew pop-in.
reset();before=#f.created;request();assert(#f.created==before+1)
world.yaw=math.pi;step(52)
assert(#f.created==before+1 and not Backup.isActive() and not f.reserved)

-- A finite camera/geometry wait ends without actors or a stuck reservation.
reset();before=#f.created;world.noFloor=true;request();step(82)
assert(#f.created==before and not Backup.isActive() and not f.reserved)
reset();before=#f.created;world.yaw=math.pi;request()
assert(Backup.release(support,patrol) and #f.created==before and not f.reserved and not Backup.isActive())

-- Wrong-level attachment never creates crew. A refused/async delete prevents
-- replacement; only confirmed cleanup permits the next bounded attempt.
reset();before=#f.created;world.badPlacement=true;f.deferDelete=true;request();step(20)
assert(#f.created==before+1 and f.reserved and Backup.isActive())
world.badPlacement=false;f.deferDelete=false;step(48)
assert(#f.created==before+4 and Backup.state():find('on scene',1,true))
Backup.finish(support)
reset();before=#f.created;world.badPlacement=true;request();step(120)
assert(#f.created==before+3 and not f.reserved and not Backup.isActive(),'placement retries were not bounded to three cars')
assert(math.abs(f.created[before+1].position.x-f.created[before+2].position.x)>=12)
assert(math.abs(f.created[before+2].position.x-f.created[before+3].position.x)>=12)

-- Partial crew creation retains both known IDs until deletion is confirmed.
reset();before=#f.created;world.failSecondOfficer=true;f.refuseDelete=true
request();step(12)
assert(#f.created==before+2 and f.reserved and Backup.isActive())
step(40);assert(#f.created==before+2 and f.reserved)
f.refuseDelete=false;step(16);assert(not Backup.isActive() and not f.reserved)

-- End-shift cannot let a deferred replacement resume after deletion.
reset();before=#f.created;world.badPlacement=true;f.deferDelete=true;request();step(8)
Backup.finish(support);f.deferDelete=false
for _=1,16 do Backup.update(.25,false,support,patrol) end
assert(#f.created==before+1 and not Backup.isActive() and not f.reserved)
-- A world reset forgets handles; it never deletes through an old-world ID.
reset();request();local deletes=f.deletes or 0
Backup.reset();assert((f.deletes or 0)==deletes and not Backup.isActive())
