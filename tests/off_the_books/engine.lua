-- Recording boundaries for actual Lua, native quest/events and shared marker.
local f=F;local root='quests/minor_quest/ncpd_patrol_off_the_books'
EAIAttitude.AIA_Neutral=1
function f.player:GetGame() return {} end
local playerAgent=f.player:GetAttitudeAgent()
function f.player:GetAttitudeAgent() return playerAgent end
f.oblog={};f.obseedCount=0;f.obholds={};f.obcancels={};f.obthreats={};f.obInventory={};f.obPlayerItems={}
f.obOriginalAdded=0;f.obOriginalHits=0;f.obPinWrites={};f.obReadEntries={}
f.obitem='Items.NCPDPatrol_VossEvidence01'
f.obpath='onscreens/emails/quests/ncpd_patrol_off_the_books/onscreens/evidence01'
local roles={
 ['Character.NCPDPatrol_VossContractor01']='target',
 ['Character.NCPDPatrol_VossGuard01']='guard1',
 ['Character.NCPDPatrol_VossGuard02']='guard2'}
local records={['Character.CorpoManArasaka']=true,['Character.arasaka_cyborg_franged3_shingen_ma_elite']=true}
for record in pairs(roles) do records[record]=true end
NCPDPatrolOffBooksSystem=Books
Books.GetGameInstance=function() return {} end
NCPDPatrolSystem={Get=function() return f.patrol end}
local box=Game.GetScriptableSystemsContainer();local previousGet=box.Get
function box:Get(name)
 if name=='NCPDPatrolOffBooksSystem' then return Books end
 return previousGet(self,name)
end
local qs=GameInstance:GetQuestsSystem({})
function qs:SetFactStr(name,value)
 assert(name:find('ncpd_patrol_qgiver_test_',1,true)==1 or name:find('ncpd_patrol_otb_',1,true)==1,'Foreign fact changed')
 f.qfacts[name]=value
end
TweakDBInterface={
 GetCharacterRecord=function(_,id) return records[id] and f.obMissingRecord~=id and {id=id} or nil end,
 GetItemRecord=function(_,id)
  if f.obMissingRecord==id then return nil end
  if id==f.obitem or id=='Items.generic_arasaka_family_backstory_shard' then return {id=id} end
 end}
ItemActionsHelper={GetReadAction=function(_,id)
 if f.obBadReadAction then return nil end
 assert(id==f.obitem);return {GetID=function() return 'ItemAction.NCPDPatrol_VossEvidenceRead01' end}
end}
ReadAction={GetJournalEntryFromAction=function(_,id) assert(id=='ItemAction.NCPDPatrol_VossEvidenceRead01');return f.obBadReadPath and 'onscreens/foreign' or f.obpath end}
ItemID.IsValid=function(_,id) return type(id)=='string' and id~='' end
ItemID.GetTDBID=function(_,id) return id end
local tx=GameInstance:GetTransactionSystem({});local oldGive=tx.GiveItem
function tx:GiveItem(object,item,amount)
 if item~=f.obitem then return oldGive(self,object,item,amount) end
 assert(object~=f.player and object:GetRecordID()=='Character.NCPDPatrol_VossContractor01' and amount==1,'Automatic player/foreign grant')
 if f.obGiveFailed then return false end
 local key=object:GetEntityID().hash;f.obInventory[key]=f.obInventory[key] or {}
 f.obInventory[key][item]=(f.obInventory[key][item] or 0)+amount;f.obseedCount=f.obseedCount+1;return true
end
function tx:GetItemQuantity(object,item)
 if object==f.player then return f.obPlayerItems[item] or 0 end
 local items=f.obInventory[object:GetEntityID().hash] or {};return items[item] or 0
end
AIComponent={SendCommand=function(_,npc,cmd)
 assert(roles[npc:GetRecordID()] and cmd.duration==-1 and cmd.ignoreInCombat and cmd.removeAfterCombat)
 f.obholds[#f.obholds+1]={npc=npc,cmd=cmd};npc.obhold=cmd
end,CancelCommand=function(_,npc,cmd) assert(npc.obhold==cmd);npc.obhold=nil;f.obcancels[#f.obcancels+1]=npc end}
function NewOTBHold() return {kind='otb-hold'} end
local oldInject=TargetTrackingExtension.InjectThreat
function TargetTrackingExtension:InjectThreat(npc,attacker)
 if roles[npc:GetRecordID()] then f.obthreats[#f.obthreats+1]={npc=npc,attacker=attacker} else return oldInject(self,npc,attacker) end
end
local entities=f.entities;local qgCreate=entities.CreateEntity;local actorFactory=f.Actor
function f:Actor(record,id,position)
 local actor=actorFactory(self,record,id,position)
 if roles[record] then
  function actor:GetGame() return {} end
  function actor:GetHighLevelStateFromBlackboard() return self.combat and 2 or 5 end
  actor.agent.owner=actor;actor.obAttitudes={}
  function actor.agent:SetAttitudeTowards(other,value) actor.obAttitudes[other]=value end
 end
 return actor
end
function entities:CreateEntity(spec)
 if not roles[spec.recordID] then return qgCreate(self,spec) end
 assert(spec.persistState and spec.persistSpawn and not spec.alwaysSpawned and spec.active and spec.spawnInView)
 local id=f.qBaseCreateEntity(self,spec)
 if id.hash~=0 then
  f.qtags[id.hash]=spec.tags;f.qids[id.hash]=id
  if f.obAttachPending then f.objects[id.hash].attached=false;f.spawningIDs=f.spawningIDs or {};f.spawningIDs[id.hash]=true end
 end
 return id
end
function entities:GetTaggedID(tag)
 local ids=self:GetTaggedIDs(tag);return ids[1] or {hash=0}
end
function entities:EnableEntity(id)
 assert(self:IsManaged(id),'Unowned handle enabled');f.obEnables=(f.obEnables or 0)+1
 local actor=f.objects[id.hash];if actor and not f.obKeepUnloaded then actor.attached=true end
 return true
end
GameInstance.GetDynamicEntitySystem=function() return entities end
local originalSpatial=Game.GetSpatialQueriesSystem()
local spatial={}
function spatial:SyncRaycastByCollisionGroup(a,b,group,staticOnly,dynamicOnly)
 if math.abs(a.x+649)<20 and math.abs(a.y-930)<20 then
  assert(a.__vector=='Vector4' and b.__vector=='Vector4' and group=='Static')
  if a.z>b.z then
   if f.obNoGround then return false end
   return true,{position=Vector3.new(a.x,a.y,9.4+(f.obGroundOffset or 0)),normal=Vector3.new(0,0,f.obSlope or 1)}
  end
  return f.obObstruction==true
 end
 return originalSpatial:SyncRaycastByCollisionGroup(a,b,group,staticOnly,dynamicOnly)
end
function spatial:Overlap(...) return originalSpatial:Overlap(...) end
Game.GetSpatialQueriesSystem=function() return spatial end
for path,row in pairs(OTBEntries) do f.entries[path]=row end
local execute=qs.ExecuteNode
function qs:ExecuteNode(node,input)
 if node.path and OTBPins[node.path.realPath] then
  local def=OTBPins[node.path.realPath]
  assert(node.id==0 and node.path.fileEntryIndex==1 and not node.disablePreviousMappins)
  f.obPinWrites[#f.obPinWrites+1]={path=node.path.realPath,input=input}
  local pin=f.obReadEntries[node.path.realPath]
  if not pin then
   pin={hash=def.hash,id=210000+def.index,kind='quest',active=false,pos=Vector4.new(def.x,def.y,def.z,1)}
   function pin:GetJournalPathHash() return self.hash end
   function pin:IsActive() return self.active end
   function pin:GetNewMappinID() return {value=self.id} end
   function pin:GetWorldPosition() return self.pos end
   f.obReadEntries[node.path.realPath]=pin;ArrayPush(f.pins,pin)
  end
  pin.active=input=='Active'
  return
 end
 return execute(self,node,input)
end
local getPosition=f.map.GetQuestMappinPosition
function f.map:GetQuestMappinPosition(hash)
 for _,def in pairs(OTBPins) do if def.hash==hash then return true,Vector3.new(def.x,def.y,def.z) end end
 return getPosition(self,hash)
end
function OriginalOTBHit(self,evt)
 f.obOriginalHits=f.obOriginalHits+1
 if f.obPoliceResponse and evt and evt.attackData and evt.attackData:GetInstigator()==f.player then f.wanted=true end
 return true
end
function OriginalOTBAdded(self,evt)
 f.obOriginalAdded=f.obOriginalAdded+1
 if evt and evt.itemID==f.obitem then
  -- Native Gen_Readable behavior, independent of the quest implementation.
  f.obPlayerItems[evt.itemID]=0;f.entries[f.obpath].state=2
 end
 return true
end
function f.obLoot()
 local npc=assert(f.objects[entities:GetTaggedID('ncpd_patrol_off_the_books_target').hash])
 local items=assert(f.obInventory[npc:GetEntityID().hash]);assert(items[f.obitem]==1)
 items[f.obitem]=0;f.obPlayerItems[f.obitem]=1
 assert(ItemObserver.OnItemAddedToInventory(f.player,{itemID=f.obitem,currentQuantity=1}))
end
function f.obHit(npc,attacker)
 return HitObserver.OnHit(npc,{target=npc,attackData={GetInstigator=function() return attacker end}})
end
function f.obRole(role)
 local id=entities:GetTaggedID('ncpd_patrol_off_the_books_'..role);return f.objects[id.hash]
end
function f.obStatus(text) f.oblog[#f.oblog+1]=text end
f.books=require('off_the_books')
f.books.configure({status=f.obStatus,worldReady=function() return f.ready end,onDuty=function() return f.duty end,voss=function() return f.qmod.actor() end})
function f.obConfigureRetention()
 f.qmod.configure({status=f.qstatus,worldReady=function() return f.ready end,overlayOpen=function() return f.qoverlay end,
  canStart=function() return not f.duty and not f.qsurvey and not f.qdispatch end,
  keepAfterBriefing=function() return f.books.keepVoss() or f.qmod.briefingComplete() end,
  onBriefingComplete=function() f.books.begin(f.obStatus) end,onClear=function() f.books.clear(f.obStatus) end})
end
