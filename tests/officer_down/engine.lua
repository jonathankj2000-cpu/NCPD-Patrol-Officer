-- Engine/native boundaries only. Quest, marker, aid, protection, scene layout,
-- actor lifecycle, payout and dispatcher decisions are production source.
F={root='quests/minor_quest/ncpd_patrol_officer_down'}
function IsDefined(x) return x~=nil and x~=false and x~=0 end
function Equals(a,b) return a==b end
function NotEquals(a,b) return a~=b end
function Cast(x) return x end
function MaxF(a,b) return math.max(a,b) end
function ArraySize(a) return a.n end
function ArrayClear(a) for k in pairs(a) do a[k]=nil end;a.n=0 end
function ArrayPush(a,x) a[a.n]=x;a.n=a.n+1 end
function ArrayContains(a,x) for i=0,a.n-1 do if a[i]==x then return true end end;return false end
function ArrayFindFirst(a,x) for i=0,a.n-1 do if a[i]==x then return i end end;return -1 end
function ArrayErase(a,i) for j=i,a.n-2 do a[j]=a[j+1] end;a[a.n-1]=nil;a.n=a.n-1 end
Vector4={new=function(x,y,z,w) return {x=x,y=y,z=z,w=w,X=x,Y=y,Z=z,W=w,__vector='Vector4'} end}
Vector3={new=function(x,y,z) return {x=x,y=y,z=z,X=x,Y=y,Z=z,__vector='Vector3'} end}
function Vector4:Distance(a,b) return math.sqrt((a.X-b.X)^2+(a.Y-b.Y)^2+(a.Z-b.Z)^2) end
CName={new=function(x) return x end};TweakDBID={new=function(x) return x end}
EulerAngles={ToQuat=function(_,rotation) return rotation end,
 new=function(roll,pitch,yaw) return {Roll=roll,Pitch=pitch,Yaw=yaw,__vector='EulerAngles'} end}
NCPDPatrolOfficerDownSite=SiteNative
NCPDPatrolFixedMarkerCatalog={PathHash=function(_,s) return PathHash(s) end}
function AsQuestMappin(pin) if pin and pin.kind=='quest' then return pin end end
function NewJournalPath() return {} end
function NewManagerNode() return {} end
function NewSceneMarker() return setmetatable({m_id={value=0},m_before={value=0},m_after={value=0}}, {__index=SceneMarker}) end
NCPDPatrolMarkerSession={WorldReady=function() return F.ready end,Get=function() return {GetGeneration=function() return F.generation end} end}
gameJournalEntryState={Inactive=1,Active=2,Succeeded=3,Failed=4};JournalNotifyOption={DoNotNotify=0}
gameGodModeType={Invulnerable=2};gamedataStatPoolType={Health=1};EAIAttitude={AIA_Friendly=0,AIA_Hostile=2}
ScriptedPuppet={IsDefeated=function(_,a) return a.down end,IsUnconscious=function(_,a) return a.unconscious end,IsActive=function(_,a) return not a.dead and not a.down end}
gamedataNPCHighLevelState={Unconscious=7,Dead=3,Combat=2}
VehicleComponent={IsMountedToVehicle=function(_,game,a) return a.mounted~=nil end}
NCPDPatrolArrestSystem={Get=function() return {IsArrested=function(_,a) return a.arrested==true end} end}
TargetTrackingExtension={InjectThreat=function(_,a,b) F.threats[#F.threats+1]={a=a,b=b} end}
local journal,map,quests,god,stats,transaction,player,patrol,entities={},{},{},{},{},{},{},{},{ }
function F:Point(dx,dy,dz) local s=require('officer_down_scene');return Vector4.new(s.x+(dx or 0),s.y+(dy or 0),s.z+(dz or 0),1) end
function F:Actor(record,id,point)
 local a={record=record,id=id,pos=point,attached=true,dead=false,deadNoPool=false,down=false,unconscious=false,health=100,effects={},commands={}}
 function a:GetRecordID() return self.record end
 function a:GetEntityID() return self.id end
 function a:GetWorldPosition() return self.pos end
 function a:IsAttached() return self.attached end
 function a:Dispose()
  assert(self.record=='Vehicle.NCPDPatrol_OD_Police' or self.record=='Vehicle.NCPDPatrol_OD_GangCar','Disposed an unrelated actor')
  F.disposals=F.disposals or {};F.disposals[#F.disposals+1]={id=self.id.hash,record=self.record,actor=self}
  if F.disposeCompletes then
   self.attached=false;F.objects[self.id.hash]=nil
   if not F.disposeLeavesManaged then F.managed[self.id.hash]=nil end
  end
 end
 function a:IsDead() return self.dead end
 function a:IsDeadNoStatPool() return self.deadNoPool end
 function a:GetHighLevelStateFromBlackboard() return self.down and 7 or 2 end
 function a:SetIsDefeatMechanicActive(x) self.defeat=x end
 function a:NCPDPatrolRefreshAidInteraction() F.interactions=F.interactions+1 end
 function a:ForceBrakesUntilStoppedOrFor() self.braked=true end
 a.agent={GetAttitudeGroup=function() return 'player' end,SetAttitudeGroup=function(_,g) a.group=g end,SetAttitudeTowards=function(_,other,value) a.attitude=value end}
 function a:GetAttitudeAgent() return self.agent end
 a.ai={GetAIRole=function() return a.role end,SetAIRole=function(_,r) a.role=r end,OnAttach=function() end,SendCommand=function(_,c) a.commands[#a.commands+1]=c end,StopExecutingCommand=function(_,c) a.stopped=c end}
 function a:GetAIControllerComponent() return self.ai end
 return a
end
local function constructor(kind) return {new=function() return {kind=kind,OnRoleCleared=function() end} end} end
AINoRole=constructor('none');AIHoldPositionCommand=constructor('hold');DynamicEntitySpec={new=function() return {} end}
EntityID={IsDefined=function(id) return id and id.hash~=0 end}
worldNavigationRequestStatus={OK=0}
TweakDB={GetRecord=function(_,record) return not F.missingRecord end}
function entities:IsReady() return F.entitiesReady end
function entities:IsSpawning(id) return F.spawningIDs and F.spawningIDs[id.hash]==true or false end
function entities:CreateEntity(spec)
 F.creates[#F.creates+1]=spec
 if F.failCreateAt==#F.creates then return {hash=0} end
 local id={hash=1000+#F.creates};local a=F:Actor(spec.recordID,id,spec.position)
 if F.wrongPlacement then a.pos=F:Point(0,0,-12) end
 F.managed[id.hash]=true;F.objects[id.hash]=a;return id
end
function entities:IsManaged(id) return F.managed[id.hash]==true end
function entities:GetEntity(id) if F.actorVisible then return F.objects[id.hash] end end
function entities:DeleteEntity(id)
 assert(id.hash~=999,'Ambient/main partner deleted');F.deletes[#F.deletes+1]=id.hash
 if not F.deleteOK then return false end
 if not F.deleteDeferred then F.managed[id.hash]=nil;F.objects[id.hash]=nil end
 return true
end
function player:IsAttached() return F.playerAttached end
function player:IsDead() return false end
function player:IsInCombat() return F.combat end
function player:GetWorldPosition() return F.playerPoint end
function player:GetAttitudeAgent() return {GetAttitudeGroup=function() return 'player' end} end
function patrol:IsOnDuty() return F.duty end
function patrol:HasWantedLevel() return F.wanted end
function patrol:IsDispatchMenuOpen() return F.menu end
function patrol:Version() return 17 end
function patrol:NotifyDispatch(text,seconds) F.notices[#F.notices+1]={text=text,seconds=seconds} end
function patrol:ClearDispatchWaypoints() end
function patrol:TickBonuses() end
NCPDPatrolSystem={Get=function() return patrol end}
function journal:GetEntryByString(path,kind) local e=F.entries[path];if e and e.kind==kind then return e end end
function journal:GetEntryState(e) return e.state end
function journal:GetTrackedEntry() return F.tracked end
function journal:TrackEntry(e) F.tracked=e end
function journal:ChangeEntryState(path,kind,state) local e=self:GetEntryByString(path,kind);if F.failJournal then return false end;e.state=state;return true end
function map:GetAllMappins() return F.pins end
function map:GetManuallyTrackedMappinID() return {value=F.manual} end
function map:GetMappinFromObjective(phase,obj) if F.linked and phase and obj then for i=0,F.pins.n-1 do if F.pins[i].hash==PathHash(obj.path..'/location') then return F.pins[i] end end end end
function map:GetQuestMappinPosition(hash) return F.lookupKnown,F:Point() end
function map:SetMappinActive(id,active) for i=0,F.pins.n-1 do if F.pins[i].id==id.value then F.pins[i].active=active end end end
function map:UnregisterMappin() error('Engine-owned quest marker unregistered') end
function quests:ExecuteNode(node,input)
 assert(node.path.realPath==F.root..'/main/assist/location' and node.id==0 and node.path.fileEntryIndex==1 and node.disablePreviousMappins==false)
 local hash=PathHash(node.path.realPath);local found=false
 for i=0,F.pins.n-1 do local p=F.pins[i];if p.hash==hash then p.active=input=='Active';found=true end end
 if input=='Active' and not found and F.materialize then
  local p={hash=hash,kind='quest',id=765,active=true,pos=F:Point(F.pinWrongPosition and 50 or 0)}
  function p:GetJournalPathHash() return self.hash end
  function p:IsActive() return self.active end
  function p:GetNewMappinID() return {value=self.id} end
  function p:GetWorldPosition() return self.pos end
  ArrayPush(F.pins,p)
 end
end
function god:AddGodMode(id,mode,source) if F.failProtection then return false end;F.god[id.hash]=true;return true end
function god:RemoveGodMode(id,mode,source) F.god[id.hash]=nil;return true end
StatusEffectHelper={ApplyStatusEffect=function(_,a,e) a.effects[e]=true;a.down=true end,RemoveStatusEffect=function(_,a,e) a.effects[e]=nil;if not F.blockRecovery then a.down=false end end,RemoveStatusEffectsWithTag=function() end}
StatusEffectSystem={ObjectHasStatusEffect=function(_,a,e) return a.effects[e]==true end,ObjectHasStatusEffectWithTag=function() return false end}
function stats:GetStatPoolValue(id) return F.objects[id.hash].health end
function stats:RequestSettingStatPoolValue(id,pool,health) if not F.blockHealth then F.objects[id.hash].health=health end end
function transaction:GiveItem(p,item,amount) F.paymentAttempts=F.paymentAttempts+1;if not F.paymentOK then return false end;F.wallet=F.wallet+amount;return true end
ItemID={FromTDBID=function(_,id) return id end}
local teleport={Teleport=function(_,a,p,r) F.locks=F.locks+1;a.pos=p end}
local spatial={SyncRaycastByCollisionGroup=function(_,a,b,group,staticOnly,dynamicOnly)
 assert(a.__vector=='Vector4' and b.__vector=='Vector4','Raycast endpoints must be Vector4')
 assert(group=='Static' and staticOnly==true and dynamicOnly==false,'Ground/clearance must remain static-only')
 if a.x==b.x and a.y==b.y and a.z>b.z then
  F.groundProbes[#F.groundProbes+1]=a
  if F.noGround or (F.noGroundAt and F.noGroundAt(a)) then return false end
  local offset=F.surfaceOffsetAt and F.surfaceOffsetAt(a) or F.surfaceOffset or 0
  local z=require('officer_down_scene').z+(F.lowerFloor and -12 or offset)
  if z>a.z or z<b.z then return false end
  return true,{position=Vector3.new(a.x,a.y,z),normal=Vector3.new(0,0,F.normalZ or 1)}
 end
 return F.obstruction==true
end,
Overlap=function(_,box,center,rotation,group)
 assert(box.__vector=='Vector4' and box.w==0 and center.__vector=='Vector4' and center.w==1)
 assert(rotation.__vector=='EulerAngles' and rotation.Roll==0 and rotation.Pitch==0 and group=='Vehicle')
 assert(box.x>0 and box.y>0 and box.z>0,'Overlap half-extents must be positive')
 F.overlapQueries[#F.overlapQueries+1]={box=box,center=center,rotation=rotation}
 if F.overlapError then error('Unexpected Overlap engine error') end
 return F.vehiclePresent or (F.vehicleAt and F.vehicleAt(center,box,rotation)) or false
end}
local nav={FindPointInSphereForCharacter=function(_,p)
 assert(p.__vector=='Vector4' and p.w==1,"FindPointInSphereForCharacter parameter 1 must be Vector4")
 F.navQueries=F.navQueries+1
 return F.noNav and {status=1} or {status=0,point=p}
end}
local container={Get=function(_,name) if name=='NCPDPatrolOfficerDownSystem' then return OfficerNative elseif name=='NCPDPatrolIncidentSystem' then return IncidentNative end end}
GameInstance={GetJournalManager=function() return journal end,GetMappinSystem=function() return map end,GetQuestsSystem=function() return quests end,GetGodModeSystem=function() return god end,GetStatPoolsSystem=function() return stats end,GetTransactionSystem=function() return transaction end,GetTeleportationFacility=function() return teleport end,GetScriptableSystemsContainer=function() return container end}
Game={GetPlayer=function() return player end,GetScriptableSystemsContainer=function() return container end,GetDynamicEntitySystem=function() return entities end,GetSpatialQueriesSystem=function() return spatial end,GetAINavigationSystem=function() return nav end}
function GetPlayer() return player end
NCPDPatrolIncidentSystem={Get=function() return IncidentNative end}
NCPDPatrolOfficerDownSystem={Get=function() return OfficerNative end}
function GameInstance:GetDynamicEntitySystem() return entities end
for _,owner in ipairs({OfficerNative,IncidentNative}) do owner.GetGameInstance=function() return {} end end
-- Receipt rendering boundary; the production receipt FIFO is still exercised.
SimpleMessageType={Money=1};GetAllBlackboardDefs=function() return {UI_Notifications={},WarningMessage=1} end
SimpleScreenMessage={}
GameInstance.GetBlackboardSystem=function() return {Get=function() return {SetVariant=function(_,k,v) F.receipts[#F.receipts+1]=v.message end} end} end
function ToVariant(x) return x end
function F:Reset()
 self.generation=(self.generation or 0)+1
 self.ready=true;self.playerAttached=true;self.duty=true;self.wanted=false;self.menu=false;self.combat=false
 self.entitiesReady=true;self.actorVisible=true;self.materialize=true;self.lookupKnown=true;self.linked=true;self.pinWrongPosition=false
 self.deleteOK=true;self.deleteDeferred=false;self.failCreateAt=nil;self.wrongPlacement=false;self.failProtection=false;self.missingRecord=false
 self.blockRecovery=false;self.blockHealth=false;self.failJournal=false;self.paymentOK=true
 self.noGround=false;self.lowerFloor=false;self.obstruction=false;self.noNav=false
 self.surfaceOffset=0;self.surfaceOffsetAt=nil;self.normalZ=1;self.navQueries=0
 self.noGroundAt=nil;self.groundProbes={};self.vehiclePresent=false;self.vehicleAt=nil;self.overlapError=false;self.overlapQueries={}
 self.creates={};self.deletes={};self.managed={[999]=true};self.objects={};self.god={};self.notices={};self.threats={};self.locks=0;self.interactions=0;self.wallet=0;self.paymentAttempts=0;self.receipts={}
 self.pins={n=0};self.manual=654;self.story={path='story',state=2};self.tracked=self.story
 self.playerPoint=self:Point(-350,0,0)
 self.entries={}
 for _,r in ipairs({{'','gameJournalQuest'},{'/main','gameJournalQuestPhase'},{'/main/assist','gameJournalQuestObjective'},{'/main/assist/briefing','gameJournalQuestDescription'},{'/main/assist/location','gameJournalQuestMapPin'}}) do
  local path=self.root..r[1];self.entries[path]={path=path,kind=r[2],state=1}
 end
 IncidentNative.m_serial=0;IncidentNative.m_completedIds={n=0};IncidentNative.m_completedKinds={n=0};IncidentNative.m_completedAmounts={n=0};IncidentNative.m_paidIds={n=0};IncidentNative:OnAttach()
 OfficerNative:OnAttach();OfficerNative:Tick(0)
end
F.patrol=patrol;F.player=player;F.entities=entities;F.map=map;F.journal=journal
F:Reset()
