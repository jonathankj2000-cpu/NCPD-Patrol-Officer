VIPFixture={}
local v=VIPFixture;local f=CyberFixture
gamedataMappinVariant.ServicePointDropPointVariant='drop-point'
v.root='quests/minor_quest/ncpd_patrol_vip'
local originalChange=JournalFixture.ChangeEntryState
function JournalFixture:ChangeEntryState(path,kind,state,notify)
 if path:sub(1,#v.root)~=v.root then return originalChange(self,path,kind,state,notify) end
 local entry=self:GetEntryByString(path,kind);assert(entry,'unknown VIP journal path')
 self.writes[#self.writes+1]={path=path,state=state}
 if self.rejectState==state then return false end
 if not self.ignoreWrites then entry.state=state end
 return true
end
AbsF=function(x) return math.abs(x) end;MaxF=function(a,b) return math.max(a,b) end
SqrtF=math.sqrt;TanF=math.tan;Deg2Rad=function(degrees) return degrees*math.pi/180 end
Vector4.new=function(x,y,z,w) return {x=x,y=y,z=z,w=w,X=x,Y=y,Z=z,W=w} end
local function vec(x,y,z) return Vector4.new(x,y,z,0) end
Transform={GetPosition=function(_,t) return t.position end,GetForward=function(_,t) return t.forward end,
 GetRight=function(_,t) return t.right end,GetUp=function(_,t) return t.up end}
local camera={}
function camera:GetActiveCameraWorldTransform(t)
 if not v.cameraTransformOK then return false end
 t.position=v.cameraPosition or vec(v.car.pos.x-6,v.car.pos.y,v.car.pos.z+2)
 local yaw=v.cameraYaw or 0
 t.forward=vec(math.cos(yaw),math.sin(yaw),0)
 t.right=vec(-math.sin(yaw),math.cos(yaw),0);t.up=vec(0,0,1)
 return true
end
function camera:GetActiveCameraFOV() return v.cameraFOV end
function camera:GetAspectRatio() return v.cameraAspect end
GameInstance.GetCameraSystem=function() if v.cameraPresent then return camera end end
ScriptedPuppet.IsDefeated=function(a,b) return (b or a).defeated end
ScriptedPuppet.IsUnconscious=function(a,b) return (b or a).unconscious end
function VIPNative:GetGameInstance() return {} end
local player=Game.GetPlayer()
v.player=player
function player:GetEntityID() return {hash=5} end
function player:GetAttitudeAgent() return {player=true,GetAttitudeGroup=function() return 'player' end} end
local patrol=f.patrol
-- Real mappin identity/lifetime boundary. A nonzero registration ID does not
-- guarantee the pin remains in the registry on subsequent game updates.
local originalPlace=patrol.PlaceDispatchWaypoint
function patrol:PlaceDispatchWaypoint(point)
 local stored=Vector4.new(point.x,point.y,point.z,1)
 local result=originalPlace(self,stored)
 if result.value==0 then return result end
 v.nextMarker=(v.nextMarker or 7000)+1
 local id={value=v.nextMarker}
 local pin={id=id,point=stored,active=true}
 function pin:GetNewMappinID() return self.id end
 function pin:GetWorldPosition() return self.point end
 function pin:IsActive() return self.active end
 function pin:GetVariant() return gamedataMappinVariant.CustomPositionVariant end
 function pin:GetPhase() return gamedataMappinPhase.DefaultPhase end
 v.pins[id.value]=pin;v.registrations=v.registrations+1
 return id
end
function patrol:ClearDispatchWaypoints() f.markers={};v.pins={} end
local oldMappins=Game.GetMappinSystem
Game.GetMappinSystem=function()
 local original=oldMappins()
 if not original then return nil end
 return {
  GetAllMappins=function()
   local pins={}
   for _,pin in ipairs(original:GetAllMappins()) do pins[#pins+1]=pin end
   for _,pin in pairs(v.pins) do if not pin.hidden then pins[#pins+1]=pin end end
   return pins
  end,
  UnregisterMappin=function(_,id)
   v.unregistrations[#v.unregistrations+1]=id.value
   local removed=v.pins[id.value];v.pins[id.value]=nil
   if removed then
    local remaining={}
    for _,point in ipairs(f.markers) do if point~=removed.point then remaining[#remaining+1]=point end end
    f.markers=remaining
   end
  end,
  SetMappinActive=function(_,id,active) assert(v.pins[id.value]);v.pins[id.value].active=active end,
  SetMappinPosition=function(_,id,point)
   assert(v.pins[id.value]);local previous=v.pins[id.value].point;v.pins[id.value].point=point
   for index,stored in ipairs(f.markers) do if stored==previous then f.markers[index]=point end end
  end
 }
end
function patrol:IsOwnedPoliceVehicle(car) return car.owned==true end
function GetMountedVehicle(object) if object then return object.mounted end end
Game.GetMountedVehicle=GetMountedVehicle
local facility={GetMountingInfoSingleWithObjects=function(_,object) return {slotId={id=object.seat}} end}
GameInstance.GetMountingFacility=function() return facility end
Game.GetMountingFacility=function() return facility end
local oldGet=Game.GetScriptableSystemsContainer
Game.GetScriptableSystemsContainer=function() return {Get=function(_,name)
 if name=='NCPDPatrolVIPSystem' then return VIPNative end
 return oldGet():Get(name)
end} end
EAIAttitude.AIA_Friendly=0;moveMovementType={Run=1}
local function constructor(kind)
 return {new=function() return {kind=kind,Copy=function(self) return self end} end}
end
MountEventData=constructor('data');AIMountCommand=constructor('mount');AIUnmountCommand=constructor('unmount')
AIFollowTargetCommand=constructor('follow');AIHoldPositionCommand=constructor('hold');AICommandEvent=constructor('event')
AIVehicleChaseCommand=constructor('chase')
AIFollowerRole={new=function() return {OnRoleCleared=function() end} end}
function NewObject(name) assert(name=='handle:gameMountEventOptions');return {} end
v.entities={}
function v.entities:IsReady() return f.entityReady end
function v.entities:IsManaged(id) return f.managed[id.hash]==true end
function v.entities:CreateEntity(spec)
 assert(spec.persistState==false and spec.persistSpawn==false and spec.alwaysSpawned==false and spec.active)
 assert(spec.spawnInView==(spec.recordID=='Character.NCPDPatrol_VIP'),'native spawn-in-view gate not respected')
 assert(spec.recordID=='Character.NCPDPatrol_VIP' or spec.recordID=='Character.NCPDPatrol_VIPAttacker' or spec.recordID=='Vehicle.NCPDPatrol_VIPAmbush')
 f.creates[#f.creates+1]=spec
 if spec.recordID=='Vehicle.NCPDPatrol_VIPAmbush' then
  v.lastAmbushSpawnDistance=math.sqrt((spec.position.x-v.car.pos.x)^2+(spec.position.y-v.car.pos.y)^2)
 end
 if not f.createOK then return {hash=0} end
 local id={hash=1000+#f.creates};f.managed[id.hash]=true
 local a=spec.recordID:sub(1,7)=='Vehicle' and v:Car(id) or v:Actor(spec.recordID,id)
 a.pos=spec.position
 if spec.recordID=='Vehicle.NCPDPatrol_VIPAmbush' and v.carSpawnOffset then
  a.pos=Vector4.new(a.pos.x+(v.carSpawnOffset.x or 0),a.pos.y+(v.carSpawnOffset.y or 0),a.pos.z+(v.carSpawnOffset.z or 0),1)
 elseif spec.recordID=='Character.NCPDPatrol_VIPAttacker' then
  local ownCar=false
  for _,candidate in ipairs(v.ambushCars) do
   if f.managed[candidate.id.hash] and math.abs(a.pos.x-candidate.pos.x)<.01 and math.abs(a.pos.y-candidate.pos.y)<.01 then ownCar=true end
  end
  assert(ownCar,'crew spawned beyond any checked car footprint')
 end
 f.actors[id.hash]=a;return id
end
function v.entities:GetEntity(id) if f.actorVisible then return f.actors[id.hash] end end
function v.entities:DeleteEntity(id)
 assert(id.hash~=990,'ambient delete')
 f.deletes[#f.deletes+1]=id.hash
 if not f.deleteOK then return false end
 if not f.deleteDeferred then f.managed[id.hash]=nil;f.actors[id.hash]=nil end
 return true
end
Game.GetDynamicEntitySystem=function() return v.entities end
Game.GetSpatialQueriesSystem=function()
 if not v.spatialAvailable then return nil end
 return {SyncRaycastByCollisionGroup=function(_,from,to,group,staticOnly,dynamicOnly)
  assert(group=='Static' and staticOnly and not dynamicOnly)
  if math.abs(from.x-to.x)<.001 and math.abs(from.y-to.y)<.001 and from.z>to.z then
   if v.roadMissing then return false,nil end
   return true,{position=Vector4.new(from.x,from.y,v.roadHeight or 0,1),normal=Vector4.new(0,0,1,0)}
  end
  return v.roadBlocked==true,nil
 end}
end
function v:Actor(record,id)
 local a=f:Actor(record or 'Character.NCPDPatrol_VIP',id or {hash=100})
 a.pos={x=812,y=0,z=0,w=1}
 function a:GetWorldPosition() if self.mounted then return self.mounted:GetWorldPosition() end;return self.pos end
 local ai={}
 function ai:GetAIRole() return a.role end
 function ai:SetAIRole(role) a.role=role end
 function ai:OnAttach() end
 function ai:StopExecutingCommand(command) a.stopped=command end
 function ai:SendCommand(command)
  a.commands[#a.commands+1]=command
  if command.kind=='mount' or command.kind=='unmount' then
   local data=command.mountData
   assert(data.slotName~='seat_trunk')
   if a.record=='Character.NCPDPatrol_VIP' then
    assert(not data.isInstant and not data.ignoreHLS and not data.allowFailsafeTeleport)
    assert(data.slotName~='seat_front_left','VIP overwrote driver')
   elseif command.kind=='mount' and v.autoCrewMount then
    a.mounted=f.actors[data.mountParentEntityId.hash];a.seat=data.slotName
    assert(a.mounted and a.mounted.vehicle,'crew mounted the wrong/nonexistent convoy car')
   elseif command.kind=='unmount' and v.autoCrewUnmount then a.mounted=nil end
  end
 end
 function a:GetAIControllerComponent() return ai end
 function a:GetAttitudeAgent() return {SetAttitudeGroup=function(_,g) a.group=g end,
  SetAttitudeTowards=function(_,target,value) a.attitude=value end} end
 return a
end
function v:Car(id)
 local a={id=id or {hash=88},pos={x=800,y=0,z=0,w=1},attached=true,vehicle=true,owned=true,destroyed=false,speed=0,
  slots={seat_front_left=true,seat_front_right=true,seat_back_right=true,seat_back_left=true},occupied={},commands={}}
 function a:GetEntityID() return self.id end
 function a:GetWorldPosition() return {x=self.pos.x,y=self.pos.y,z=self.pos.z,w=1} end
 function a:GetWorldOrientation() return {} end
 function a:GetWorldForward() return {x=1,y=0,z=0,w=0} end
 function a:GetCurrentSpeed() return self.speed end
 function a:IsAttached() return self.attached end
 function a:IsDestroyed() return self.destroyed end
 function a:SetPoliceStrategyDestination(pos) self.chaseDestination=pos end
 function a:QueueEvent(event) self.commands[#self.commands+1]=event.command end
 function a:ForceBrakesUntilStoppedOrFor(seconds) self.brakes=seconds end
 local ai={SetInitCmd=function(_,command) a.initCmd=command end,StopExecutingCommand=function(_,command) a.stopped=command end}
 function a:GetAIComponent() return ai end
 if id then self.ambushCar=a;self.ambushCars[#self.ambushCars+1]=a end
 return a
end
VehicleComponent={HasSlot=function(car,seat) return car.slots[seat]==true end,
 IsSlotOccupied=function(id,seat)
  local car=v.car
  assert(id.hash==car.id.hash)
  return car.occupied[seat]==true
 end}
function v:Reset()
 self.pins={};self.nextMarker=7000;self.registrations=0;self.unregistrations={}
 f:Reset();self.player.mounted=nil;self.player.seat=nil
 self.ambushCars={};self.car=self:Car();self.ambushCar=nil;self.autoCrewMount=true;self.autoCrewUnmount=false
 self.cameraPresent=true;self.cameraTransformOK=true;self.cameraYaw=0;self.cameraFOV=75;self.cameraAspect=16/9;self.cameraPosition=nil
 self.lastAmbushSpawnDistance=nil
 self.spatialAvailable=true;self.roadMissing=false;self.roadBlocked=false;self.roadHeight=0;self.carSpawnOffset=nil
 f.places={f:Place(800),f:Place(1800)}
 for _,spec in ipairs({{'','gameJournalQuest'},{'/main','gameJournalQuestPhase'},{'/main/pickup','gameJournalQuestObjective'},
  {'/main/pickup/briefing','gameJournalQuestDescription'},{'/main/deliver','gameJournalQuestObjective'},{'/main/deliver/briefing','gameJournalQuestDescription'}}) do
  local path=self.root..spec[1];JournalFixture.entries[path]={path=path,className=spec[2],state=1}
 end
 VIPNative:OnAttach();self.hud=''
end
function v:Mount(actor,car,seat) actor.mounted=car;actor.seat=seat or 'seat_back_right' end
function v:Drive(car) self:Mount(player,car or self.car,'seat_front_left') end
function v:Advance(seconds) for _=1,math.floor(seconds*4+0.0001) do VIPNative:Tick(0.25) end end
function v:State(path) return JournalFixture.entries[self.root..(path or '')].state end
v:Reset()
