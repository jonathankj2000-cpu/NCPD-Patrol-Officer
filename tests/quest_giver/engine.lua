-- Engine boundaries for actual quest-giver Lua/native source. Graph and scene
-- execution below are driven from the authored resources by the test harness.
local f=F
f.duty=false;f.qfacts={};f.qtags={};f.qids={};f.qsceneOwned=false
f.qroot='quests/minor_quest/ncpd_patrol_quest_giver_test'
f.qpoint=Vector4.new(1424.737,-2754.759,204.665,1)
f.qlog={};f.qtagStale=false;f.qpending={}
QNative.GetGameInstance=function() return {} end
NCPDPatrolQuestGiverTest=QNative
local qs=GameInstance:GetQuestsSystem({})
function qs:GetFactStr(key) return f.qfacts[key] or 0 end
function qs:SetFactStr(key,value)
 assert(key:find('ncpd_patrol_qgiver_test_',1,true)==1,'Unrelated quest fact written')
 f.qfacts[key]=value
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
end} end} end
EulerAngles.new=function(roll,pitch,yaw)
 return {Roll=roll,Pitch=pitch,Yaw=yaw,__vector='EulerAngles',ToQuat=function(self) return self end}
end
local e=f.entities;local create,delete=e.CreateEntity,e.DeleteEntity
function e:CreateEntity(spec)
 assert(spec.recordID=='Character.NCPDPatrol_QG_Investigator' or spec.recordID=='Vehicle.NCPDPatrol_QG_Hella')
 assert(spec.persistSpawn and not spec.persistState and spec.active and not spec.alwaysSpawned)
 local id=create(self,spec)
 if id.hash~=0 then f.qtags[id.hash]=spec.tags;f.qids[id.hash]=id end
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
 local a=f.objects[id.hash];local accepted=delete(self,id)
 if accepted and a then
  if f.deleteDeferred then f.qpending[id.hash]=a else a.attached=false end
 end
 return accepted
end
function f.qCompleteDeletes()
 for hash,a in pairs(f.qpending) do a.attached=false;f.objects[hash]=nil;f.managed[hash]=nil end
 f.qpending={}
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
