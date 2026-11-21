-- Engine boundaries only. Actual Lua survey/store/shared actor code and the
-- translated production REDscript survey owner run against this fixture.
SF={time=0,maxLive=0,moves=0,logs={},allActors={},groundDelay=0,groundRemaining=0,
 actorTeleports=0,blocked={},noGround={},noNav={},holdDetached=false,detaching={},
 failFile=false,canStart=true,otherReason='other owner active',facing=37.25}
AbsF=math.abs
local s,f=SF,F
local catalog=require('scene_survey_sites')
f.duty=false
SurveyNative.GetGameInstance=function() return {} end
SurveyNative:OnAttach()
local container=Game.GetScriptableSystemsContainer();local originalGet=container.Get
container.Get=function(self,name) if name=='NCPDPatrolSceneSurveySystem' then return SurveyNative end;return originalGet(self,name) end
local player=Game.GetPlayer()
function player:IsDead() return s.playerDead==true end
s.original={x=f.playerPoint.x,y=f.playerPoint.y,z=f.playerPoint.z,heading=s.facing}
local playerID={hash=501}
function player:GetEntityID() return playerID end
function player:GetWorldOrientation() return {Yaw=s.facing} end
Quaternion={ToEulerAngles=function(_,value) return value end}
local locations={s.original}
for _,p in ipairs(catalog.sites) do locations[#locations+1]=p end
local function location(p)
 local best,score=nil,math.huge
 for _,q in ipairs(locations) do local d=(q.x-p.x)^2+(q.y-p.y)^2;if d<score then best,score=q,d end end
 return best
end
function s.live()
 local count=0
 for _,a in ipairs(s.allActors) do if a.attached then count=count+1 end end
 return count
end
local tele=GameInstance:GetTeleportationFacility({})
tele.Teleport=function(_,object,p,angle)
 assert(p.__vector=='Vector4' and angle.Roll==0 and angle.Pitch==0)
 if object==player then
  assert(s.live()==0,'Player moved before physical scene cleanup completed')
  assert(SurveyNative:GetCreatedCount()==0,'Player moved with native IDs still reserved')
  s.moves=s.moves+1;s.facing=angle.Yaw
  f.playerPoint=Vector4.new(p.x,p.y,p.z,1)
  if s.afterMove then s.afterMove(location(p)) end
 else
  s.actorTeleports=s.actorTeleports+1
  s.actorTeleportLog=s.actorTeleportLog or {}
  s.actorTeleportLog[#s.actorTeleportLog+1]={record=object.record,target={x=p.x,y=p.y,z=p.z},time=s.time}
  if not s.ignoreActorTeleports then object.pos=p end
 end
end
local create=f.entities.CreateEntity
f.entities.CreateEntity=function(self,spec)
 assert(spec.persistState==false and spec.persistSpawn==false and spec.alwaysSpawned==false and spec.active and spec.spawnInView)
 local id=create(self,spec)
 if id.hash~=0 then
  local a=f.objects[id.hash];s.allActors[#s.allActors+1]=a
  s.maxLive=math.max(s.maxLive,s.live());assert(s.live()<=10,'Two survey scenes overlapped')
  if s.onCreate then s.onCreate(a) end
 end
 return id
end
local delete=f.entities.DeleteEntity
f.entities.DeleteEntity=function(self,id)
 local actor=f.objects[id.hash];local result=delete(self,id)
 if actor and not self:IsManaged(id) then
  if s.holdDetached then s.detaching[#s.detaching+1]=actor else actor.attached=false end
 end
 return result
end
function s.releaseDetached() for _,a in ipairs(s.detaching) do a.attached=false end;s.detaching={} end
-- Preserve other mods' god-mode sources while the survey removes its own.
s.godSources={[501]={OtherMod=true}}
f.god[501]=true
local god=GameInstance:GetGodModeSystem({})
god.AddGodMode=function(_,id,mode,source)
 if f.failProtection then return false end
 local sources=s.godSources[id.hash] or {};s.godSources[id.hash]=sources;sources[source]=true;f.god[id.hash]=true;return true
end
god.RemoveGodMode=function(_,id,mode,source)
 local sources=s.godSources[id.hash] or {};sources[source]=nil;f.god[id.hash]=next(sources)~=nil and true or nil;return true
end
local spatial={}
function spatial:SyncRaycastByCollisionGroup(a,b,group,staticOnly,dynamicOnly)
 assert(a.__vector=='Vector4' and b.__vector=='Vector4' and group=='Static' and staticOnly==true and dynamicOnly==false)
 if a.x==b.x and a.y==b.y and a.z>b.z then
  local q=location(a)
  if s.groundRemaining>0 or s.noGround[q.id] then return false end
  local z=q.z+(s.heightOffset or 0)
  if z>a.z or z<b.z then return false end
  return true,{position=Vector3.new(a.x,a.y,z),normal=Vector3.new(0,0,s.normal or 1)}
 end
 if s.aidWallBlocked and (a.x-b.x)^2+(a.y-b.y)^2>1.2^2 then return true end
 return s.obstruction==true
end
function spatial:Overlap(box,center,angle,group)
 assert(box.__vector=='Vector4' and center.__vector=='Vector4' and angle.__vector=='EulerAngles' and group=='Vehicle')
 local q=location(center)
 if box.x==.35 and s.injuredVehicleBlocked then return true end
 if box.x==.4 and s.aidStandingBlocked then return true end
 if box.x==.2 and s.aidCorridorBlocked then return true end
 if s.overlapError or (s.carOverlapError and box.x==1.05) then error('Injected native Overlap API error') end
 if box.x==1.05 and s.blockHeading and s.blockHeading[q.id] and math.abs(((angle.Yaw-90)%360)-s.blockHeading[q.id])<.001 then return true end
 if box.x==1.05 and s.blocked[q.id] then return true end
 return s.centerBlocked~=nil and s.centerBlocked==q.id and math.abs(center.x-q.x)<.01 and math.abs(center.y-q.y)<.01
end
Game.GetSpatialQueriesSystem=function() return spatial end
local navigation={FindPointInSphereForCharacter=function(_,p,radius,owner)
 assert(p.__vector=='Vector4' and p.w==1 and owner==player and (radius==.5 or radius==1.2 or radius==1.5))
 if s.noNav[location(p).id] then return {status=1} end
 return {status=0,point=Vector4.new(p.x,p.y,p.z,1)}
end}
function navigation:CalculatePathForCharacter(a,b,tolerance,owner)
 assert(a.__vector=='Vector4' and b.__vector=='Vector4' and tolerance==.5 and owner==player)
 s.pathQueries=(s.pathQueries or 0)+1
 if s.pathError then error('Injected navigation API failure') end
 if s.noAidPath then return {path={n=0}} end
 local last=s.partialAidPath and Vector4.new(b.x+3,b.y,b.z,1) or b
 local first=s.partialAidStart and Vector4.new(a.x+3,a.y,a.z,1) or a
 return {path={n=2,[0]=first,[1]=last}}
end
Game.GetAINavigationSystem=function() return navigation end
GameInstance.GetAINavigationSystem=function() return navigation end
local open=io.open
io.open=function(name,mode)
 assert(name=='scene_survey_results.jsonl' or name=='scene_survey_report.json'
  or name=='officer_down_dispatch.jsonl' or name=='officer_down_dispatch_report.json','Unexpected evidence file path: '..tostring(name))
 if s.failFile and mode~='r' then return nil,'injected disk failure' end
 return open(name,mode)
end
local survey=require('scene_survey')
function s.configure()
 survey.configure({worldReady=function() return f.ready end,
  canStart=function() return s.canStart,s.otherReason end,
  status=function(line) s.logs[#s.logs+1]=line end})
end
function s.use(value) survey=value;s.configure() end
s.configure()
function s.step(seconds)
 for _=1,math.floor(seconds*4+.001) do
  s.time=s.time+.25;s.groundRemaining=math.max(0,s.groundRemaining-.25)
  if s.onTick then s.onTick() end
  survey.update(.25)
 end
end
function s.untilIdle(limit)
 for _=1,limit*4 do s.step(.25);if not survey.active() then return end end
 error('Survey did not finish: '..survey.diagnostics())
end
function s.untilPhase(name,limit)
 for _=1,limit*4 do
  if survey.diagnostics():find('Phase: '..name..' |',1,true) then return end
  s.step(.25)
 end
 error('Expected phase '..name..': '..survey.diagnostics())
end
function s.assertNoGameplay(allowInjuredPlacement)
 assert(f.wallet==0 and IncidentNative:GetCompletedCount()==0 and OfficerNative:GetStage()==0)
 assert(f.pins.n==0 and f.manual==654 and f.tracked==f.story and #f.threats==0)
 assert(f.managed[999])
 if not allowInjuredPlacement then assert(s.actorTeleports==0) end
 for _,move in ipairs(s.actorTeleportLog or {}) do assert(move.record=='Character.NCPDPatrol_OD_Injured') end
end
SurveyFixture=s
