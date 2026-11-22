-- Engine boundaries for actual quest-giver Lua/native source. Graph and scene
-- execution below are driven from the authored resources by the test harness.
local f=F
f.duty=false;f.qfacts={};f.qtags={};f.qids={};f.qsceneOwned=false
f.qsceneTier=1
PlayerPuppet={GetSceneTier=function(player) assert(player==f.player);return f.qsceneTier end}
f.qroot='quests/minor_quest/ncpd_patrol_quest_giver_test'
f.qpoint=Vector4.new(1424.737,-2754.759,204.665,1)
f.qlog={};f.qtagStale=false;f.qpending={}
f.qposeLinks={};f.qposeCalls={};f.qposeLoads=0
f.qposeIdleCalls={};f.qposeWalks=0
gameEntityReferenceType={EntityRef=0,Tag=1,SlotID=2,SceneActorContextName=3}
questUseWorkspotNodeFunctions={UseWorkspot=0,JumpWorkspot=1,StopWorkspot=2,IdleOnlyMode=3}
questUseWorkspotNodeDefinition=function() return {kind='quest-workspot'} end
questUseWorkspotParamsV1=function() return {['function']=0} end
QNative.GetGameInstance=function() return {} end
NCPDPatrolQuestGiverTest=QNative
local qs=GameInstance:GetQuestsSystem({})
function qs:GetFactStr(key) return f.qfacts[key] or 0 end
function qs:SetFactStr(key,value)
 assert(key:find('ncpd_patrol_qgiver_test_',1,true)==1,'Unrelated quest fact written')
 f.qfacts[key]=value
end
local executeNode=qs.ExecuteNode
function qs:ExecuteNode(node,input)
 if node.kind~='quest-workspot' then return executeNode(self,node,input) end
 if f.qposeIdleExecuteThrows then error('Native idle-mode request rejected') end
 local p,ref=node.paramsV1,node.entityReference
 assert(input=='In' and node.id==0 and p['function']==3 and p.enableIdleMode==true)
 assert(not p.changeWorkspot and not p.teleport and not p.jumpToEntry and not p.isPlayer)
 assert(ref.type==1 and ref.names.n==1 and ref.names[0]=='ncpd_patrol_qgiver_test_npc')
 local actor
 for _,user in pairs(f.qposeLinks) do
  assert(not actor and user~=f.player and user:GetRecordID()=='Character.NCPDPatrol_QG_Investigator')
  actor=user
 end
 assert(actor and actor:IsAttached(),'Idle mode requested before the owned workspot was active')
 actor.qposeIdleOnly=true
 f.qposeIdleCalls[#f.qposeIdleCalls+1]={node=node,input=input,actor=actor}
end
local box=Game.GetScriptableSystemsContainer();local oldGet=box.Get
function box:Get(name)
 if name=='NCPDPatrolQuestGiverTest' then return QNative end
 if name=='NCPDPatrolSystem' then return f.patrol end
 return oldGet(self,name)
end
GetAllBlackboardDefs=function() return {UI_System={IsInMenu='menu'},UI_Notifications={},WarningMessage=1} end
GameInstance.GetBlackboardSystem=function() return {Get=function() return {GetBool=function() return f.menu end} end} end
function f.player:GetEntityID() return {hash=111} end
Game.GetMountedVehicle=function() return f.mounted and {} or nil end
Game.GetSceneSystem=function() return {GetScriptInterface=function() return {IsEntityInScene=function(_,id)
 return (id.hash==111 and f.qforeignScene) or (f.qsceneOwned and (id.hash==111 or f.qtags[id.hash]~=nil)) or false
end,IsEntityInDialogue=function(_,id)
 return (id.hash==111 and f.qforeignDialogue) or (f.qsceneOwned and (id.hash==111 or f.qtags[id.hash]~=nil)) or false
end} end} end
EulerAngles.new=function(roll,pitch,yaw)
 return {Roll=roll,Pitch=pitch,Yaw=yaw,__vector='EulerAngles',ToQuat=function(self) return self end}
end
local e=f.entities;local create,delete=e.CreateEntity,e.DeleteEntity
function e:CreateEntity(spec)
 local helper=spec.templatePath==QNative:GetPoseHelperTemplate()
 assert(helper or spec.recordID=='Character.NCPDPatrol_QG_Investigator' or spec.recordID=='Vehicle.NCPDPatrol_QG_Hella')
 assert(spec.persistSpawn==not helper and not spec.persistState and spec.active and not spec.alwaysSpawned)
 local id=create(self,spec)
 if id.hash~=0 then
  f.qtags[id.hash]=spec.tags;f.qids[id.hash]=id
  local object=f.objects[id.hash]
  if helper then
   object.poseHelper=true
   function object:FindComponentByType(kind)
    assert(kind=='workWorkspotResourceComponent')
    if f.qposeNoComponent then return nil end
    return {name=f.qposeWrongComponent and 'ForeignComponent' or 'NCPDPatrolVossWaitPose'}
   end
  end
 end
 return id
end
function e:GetTaggedIDs(tag)
 local rows={}
 for hash,id in pairs(f.qids) do
  if (f.managed[hash] or f.qtagStale) and self:IsTagged(id,tag) then rows[#rows+1]=id end
 end
 return rows
end
function e:IsTagged(id,tag)
 for _,value in ipairs(f.qtags[id.hash] or {}) do if value==tag then return true end end
 return false
end
function e:IsSpawned(id) return f.objects[id.hash]~=nil and f.objects[id.hash].attached end
function e:DeleteEntity(id)
 assert(not f.qsceneOwned,'Actor deleted while still owned by the native scene')
 for _,user in pairs(f.qposeLinks) do assert(user:GetEntityID().hash~=id.hash,'NPC deleted before its pose device detached') end
 local a=f.objects[id.hash];local accepted=delete(self,id)
 if accepted and a then
  if f.deleteDeferred then f.qpending[id.hash]=a else a.attached=false;f.qposeLinks[id.hash]=nil end
 end
 return accepted
end
function f.qCompleteDeletes()
 for hash,a in pairs(f.qpending) do a.attached=false;f.objects[hash]=nil;f.managed[hash]=nil;f.qposeLinks[hash]=nil end
 f.qpending={}
end
WorkspotSlidingBehaviour={PlayAtResourcePosition='ground_anchor'}
local workspots={}
function workspots:IsActorInWorkspot(actor)
 if f.qforeignPose then return true end
 for _,user in pairs(f.qposeLinks) do if user==actor then return true end end
 return false
end
function workspots:GetDeviceUser(id)
 if f.qposeNoDeviceUser then return nil end
 if f.qposeOtherDeviceUser then return f.player end
 return f.qposeLinks[id.hash]
end
function workspots:GetExtendedInfo(actor)
 if f.qposeNoInfo then return nil end
 return setmetatable({isActive=self:IsActorInWorkspot(actor),entering=f.qposeEntering==true,exiting=f.qposeExiting==true},
  {__index=function(_,key) error('Unknown native ExtendedWorkspotInfo property: '..tostring(key)) end})
end
function workspots:PlayInDeviceSimple(helper,actor,camera,actorComp,deviceComp,sync,slide,behaviour,recipient)
 assert(helper.poseHelper and actor:GetRecordID()=='Character.NCPDPatrol_QG_Investigator' and actor~=f.player)
 assert(not camera and actorComp=='NCPDPatrolVossWaitPose' and deviceComp=='None' and sync=='None')
 assert(behaviour=='ground_anchor' and slide==.25 and recipient==nil)
 assert(not f.qsceneOwned,'Waiting pose was delayed until dialogue start')
 f.qposeCalls[#f.qposeCalls+1]={helper=helper,actor=actor,position=helper:GetWorldPosition()}
 if not f.qposePlayFailed then f.qposeLinks[helper:GetEntityID().hash]=actor;actor.pos=helper:GetWorldPosition() end
end
Game.GetWorkspotSystem=function() return workspots end
GameInstance.GetWorkspotSystem=function(_,game)
 if f.qposeNoNativeSystem then return nil end
 return workspots
end
function f.qAdvanceWorkspot(seconds)
 -- A deliberately simple branch-selection boundary, not an animation or
 -- root-motion emulator. Tests opt in to an ambient walking branch.
 if not f.qposeModelWalkAfter then return end
 for _,actor in pairs(f.qposeLinks) do
  actor.qposeAge=(actor.qposeAge or 0)+seconds
  if actor.qposeAge>=f.qposeModelWalkAfter and not actor.qposeIdleOnly and not actor.qposeWalked then
   actor.qposeWalked=true;f.qposeWalks=f.qposeWalks+1
   local p=actor:GetWorldPosition();actor.pos=Vector4.new(p.x+1,p.y,p.z,1)
  end
 end
end
Game.GetResourceDepot=function() return {
 ResourceExists=function(_,path) return f.qposeResourcesMissing~=true end,
 LoadResource=function(_,path)
  assert(path==QNative:GetPoseResource());f.qposeLoads=f.qposeLoads+1
  return {IsFailed=function() return f.qposeLoadFailed==true end,IsLoaded=function() return not f.qposeLoadPending and not f.qposeLoadFailed end,
   GetResource=function() return {workspotTree={rootEntry={}}} end}
 end,
} end
function f.qPoseActive()
 for _,actor in pairs(f.qposeLinks) do if actor:IsAttached() then return true end end
 return false
end
local spatial={}
function spatial:SyncRaycastByCollisionGroup(a,b,group,staticOnly,dynamicOnly)
 assert(a.__vector=='Vector4' and b.__vector=='Vector4' and group=='Static' and staticOnly and not dynamicOnly)
 if a.x==b.x and a.y==b.y and a.z>b.z then
  f.groundProbes[#f.groundProbes+1]=a
  if f.noGround then return false end
  return true,{position=Vector3.new(a.x,a.y,f.qpoint.z+(f.lowerFloor and -12 or f.surfaceOffset)),normal=Vector3.new(0,0,f.normalZ)}
 end
 return f.obstruction
end
function spatial:Overlap(box,center,rotation,group)
 assert(box.__vector=='Vector4' and box.w==0 and center.w==1 and rotation.__vector=='EulerAngles' and group=='Vehicle')
 return f.vehiclePresent
end
Game.GetSpatialQueriesSystem=function() return spatial end
local path=f.qroot..'/main/talk/location';local hash=PathHash(path)
for _,row in ipairs({{'','gameJournalQuest'},{'/main','gameJournalQuestPhase'},{'/main/talk','gameJournalQuestObjective'},{'/main/talk/location','gameJournalQuestMapPin'}}) do
 f.entries[f.qroot..row[1]]={path=f.qroot..row[1],kind=row[2],state=1}
end
f.qpin={hash=hash,kind='quest',id=90909,active=false,pos=f.qpoint}
function f.qpin:GetJournalPathHash() return self.hash end
function f.qpin:IsActive() return self.active end
function f.qpin:GetNewMappinID() return {value=self.id} end
function f.qpin:GetWorldPosition() return self.pos end
ArrayPush(f.pins,f.qpin)
local execute=qs.ExecuteNode
function qs:ExecuteNode(node,input)
 if node.path and node.path.realPath==path then
  assert(node.id==0 and node.path.fileEntryIndex==1 and node.disablePreviousMappins==false)
  f.qpin.active=input=='Active'
 else execute(self,node,input) end
end
local getPosition=f.map.GetQuestMappinPosition
function f.map:GetQuestMappinPosition(key)
 if key==hash then return true,Vector3.new(f.qpoint.x,f.qpoint.y,f.qpoint.z) end
 return getPosition(self,key)
end
function f.qstatus(text) f.qlog[#f.qlog+1]=text end
function f.qconfigure()
 local mod=require('quest_giver_test')
 mod.configure({status=f.qstatus,worldReady=function() return f.ready end,overlayOpen=function() return f.qoverlay end,canStart=function()
  return not f.duty and not f.qsurvey and not f.qdispatch,'Existing duty/survey/dispatch is reserved'
 end})
 return mod
end
f.qmod=f.qconfigure()
