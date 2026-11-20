-- Engine boundaries only. No native marker is materialized by default.
-- Journal map-pin state is deliberately NOT a visibility control. Journal UI
-- resolves the first declared map-pin child, as the game source does.
F={}
function IsDefined(x) return x~=nil and x~=false and x~=0 end
function Equals(a,b) return a==b end
function NotEquals(a,b) return a~=b end
function Cast(x) return x end
function ArraySize(a) return a.n end
function ArrayClear(a) for k in pairs(a) do a[k]=nil end;a.n=0 end
function ArrayInsert(a,i,x) for j=a.n,i+1,-1 do a[j]=a[j-1] end;a[i]=x;a.n=a.n+1 end
function Murmur3(s,seed) assert(seed==1592638046);return PathHash(s) end
function ArrayPush(a,x) a[a.n]=x;a.n=a.n+1 end
function ArrayErase(a,i) for j=i,a.n-2 do a[j]=a[j+1] end;a[a.n-1]=nil;a.n=a.n-1 end
function ArrayContains(a,x) for i=0,a.n-1 do if a[i]==x then return true end end;return false end
function AbsF(x) return math.abs(x) end
function MaxF(a,b) return math.max(a,b) end
function CeilF(x) return math.ceil(x) end
function StringToName(x) return x end
function AsQuestMappin(pin) if pin and pin.kind=='quest' then return pin end end
function NewMarkerDiagnostics() return setmetatable({}, {__index=MarkerDiagnostics}) end
function NewFixedData() return {fixed=true} end
function AsFixedData(x) if x and x.fixed then return x end end
Vector4={new=function(x,y,z,w) return {X=x,Y=y,Z=z,W=w,x=x,y=y,z=z,w=w} end}
function Vector4:Distance(a,b) return math.sqrt((a.X-b.X)^2+(a.Y-b.Y)^2+(a.Z-b.Z)^2) end
function NewJournalPath() return {GetHash=function(self) return PathHash(self.realPath) end} end
function NewManagerNode() return {} end
gameJournalEntryState={Undefined=0,Inactive=1,Active=2,Succeeded=3,Failed=4}
JournalNotifyOption={DoNotNotify=0,Notify=1}
gamedataMappinVariant={QuestGiverVariant=7}
gamedataMappinPhase={CompletedPhase=9}
ScriptedPuppet={IsActive=function(_,x) return not x.down end,IsDefeated=function(_,x) return x.down end,IsUnconscious=function(_,x) return false end}
ItemID={FromTDBID=function(_,x) return x end}
local journal,map,patrol,player,container,quests={},{},{},{},{},{}
local rewards={}
local serviceContainer={}
local callbacks={}
function callbacks:UnregisterCallback(event,context,fn)
 local list=F.callbacks[event] or {};local kept={}
 for _,c in ipairs(list) do if c.context~=context or c.fn~=fn then kept[#kept+1]=c end end
 F.callbacks[event]=kept
end
function callbacks:RegisterCallback(event,context,fn,sticky)
 assert(sticky==true);F.callbacks[event]=F.callbacks[event] or {}
 F.callbacks[event][#F.callbacks[event]+1]={context=context,fn=fn,sticky=sticky}
 return {}
end
function F:Emit(event)
 for _,c in ipairs(self.callbacks[event] or {}) do c.context[c.fn](c.context,{}) end
end
function serviceContainer:GetService(name) if name=='NCPDPatrolMarkerSession' then return SessionNative end end

function F:Scope(index)
 for _,e in pairs(self.entries) do if e.kind~='gameJournalQuestMapPin' then e.state=1 end end
 for _,owner in ipairs({ScannerNative,CyberNative,VIPNative}) do owner.m_stage=0 end
 ScannerNative.m_navigationSite=0;CyberNative.m_navigationSite=0;VIPNative.m_pickupSite=0;VIPNative.m_deliverySite=0
 local root,objective,owner
 if index<6 then
  root='quests/minor_quest/ncpd_patrol_dispatch'..(index==0 and '' or '_'..index);objective=root..'/main/resolve'
  owner=ScannerNative;owner.m_briefing=index;owner.m_stage=1
 elseif index<8 then
  root='quests/minor_quest/ncpd_patrol_cyberpsycho';objective=root..'/main/'..(index==6 and 'respond' or 'neutralize')
  owner=CyberNative;owner.m_stage=index==6 and 1 or 2
 else
  root='quests/minor_quest/ncpd_patrol_vip';objective=root..'/main/'..(index==8 and 'pickup' or 'deliver')
  owner=VIPNative;owner.m_stage=index==8 and 1 or 2
 end
 self.entries[root].state=2;self.entries[root..'/main'].state=2;self.entries[objective].state=2
 self.entries[objective..'/briefing'].state=2
 self.scope=index;self.objective=objective;self.owner=owner
end
function F:Reset(scope)
 self.entries={};self.hashes={};self.pins={n=0};self.writes={};self.nodes={};self.deleted={};self.fallbackCreates=0;self.nextID=9000
 self.callbacks={};self.hideSitePins=false;self.entryReads=0;self.materialize=false;self.failDelete=false;self.failHide=false;self.failRegister=false;self.rejectPath=nil
 self.menu=false;self.duty=true;self.wanted=false;self.loaded=true;self.attached=true;self.nativeMissing=false;self.failActivate=false;self.activationWrites=0
 self.manual=700;self.story={path='story',state=2};self.tracked=self.story;self.tracks={};self.lookupKnown=true;self.linked=true;self.changeManual=false
 self.wallet=0;self.reserved=0;self.paidVIP=0;self.paidCyber=0;self.completed=false;self.paymentOK=true
 self.playerPoint=Vector4.new(0,0,0,1);self.mount={};self.driver=true
 for _,d in ipairs(Entries) do
  local e={path=d.path,kind=d.kind,state=1,hash=PathHash(d.path),children=d.children,site=d.site,authoredActive=d.active}
  self.entries[d.path]=e;self.hashes[e.hash]=e
 end
 for _,d in ipairs(Definitions) do self.entries[d.path].objective=d.objective end
 for _,owner in ipairs({ScannerNative,CyberNative,VIPNative}) do owner:OnAttach();owner.m_restorePending=false end
 ScannerNative.m_paidDispatches={n=0};ScannerNative.m_pendingDispatchRewards={n=0}
 SessionNative:OnLoad();SessionNative:OnInitialize();self:Emit('Session/BeforeStart')
 Native:OnAttach();self:Scope(scope or 0);self:Emit('Session/Ready')
 for _=1,40 do Native:Tick(.25) end
 self.writes={};self.nodes={};self.deleted={}
end
function journal:GetEntryByString(path,kind)
 F.entryReads=F.entryReads+1
 if F.hideSitePins and kind=='gameJournalQuestMapPin' and path:sub(-9)=='/location' then return nil end
 local e=F.entries[path];if e and e.kind==kind then return e end
end
function journal:GetEntryState(entry) assert(entry);return entry.state end
function journal:GetEntryHash(entry) return entry.hash end
function journal:GetTrackedEntry() return F.tracked end
function journal:TrackEntry(entry) assert(entry);F.tracked=entry;F.tracks[#F.tracks+1]=entry end
function journal:ChangeEntryState(path,kind,state)
 local e=self:GetEntryByString(path,kind);assert(e and kind~='gameJournalQuestMapPin','map-pin journal state is not an activation API')
 F.writes[#F.writes+1]={path=path,state=state}
 if F.rejectPath==path and state==2 then return false end
 e.state=state
 return true
end
function quests:ExecuteNode(node,input)
 assert(node.id==0 and node.path.fileEntryIndex==1 and node.path.className=='gameJournalQuestMapPin' and node.disablePreviousMappins==false)
 assert(input=='Active' or input=='Inactive')
 F.nodes[#F.nodes+1]={path=node.path.realPath,input=input}
 local e=journal:GetEntryByString(node.path.realPath,'gameJournalQuestMapPin');assert(e)
 if input=='Active' and F.materialize then
  local found=false
  for i=0,F.pins.n-1 do if F.pins[i].hash==e.hash then F.pins[i].active=true;found=true end end
  if not found then F:AddPin(e.hash) end
 end
 if input=='Inactive' and not F.failHide then for i=0,F.pins.n-1 do if F.pins[i].hash==e.hash then F.pins[i].active=false end end end
 if F.changeManual then F.manual=701 end
end
function F:AddPin(hash,point)
 local e=self.hashes[hash];local position=e and e.site and Sites[e.site].position or {x=1,y=2,z=3}
 local pin={kind='quest',hash=hash,id=self.nextID,point=point or Vector4.new(position.x,position.y,position.z,1),active=true}
 self.nextID=self.nextID+1
 function pin:GetNewMappinID() return {value=self.id} end
 function pin:GetWorldPosition() return self.point end
 function pin:GetJournalPathHash() return self.hash end
 function pin:IsQuestMappin() return self.kind=='quest' end
 function pin:IsActive() return self.active end
 function pin:IsVisible() return self.active and not self.hidden end
 function pin:GetScriptData() return self.data end
 self.pins[self.pins.n]=pin;self.pins.n=self.pins.n+1
 return pin
end
function F:OwnedActive()
 local count=0
 for i=0,self.pins.n-1 do local p=self.pins[i]
  if p.active and ((p.kind=='quest' and (ArrayContains(Native.m_ownHashes,p.hash) or (p.hash==Native.m_hash and Native.m_currentPath~=''))) or AsFixedData(p.data)) then count=count+1 end
 end
 return count
end
function map:GetAllMappins() return F.pins end
function map:GetMappin(id)
 for i=0,F.pins.n-1 do if F.pins[i].id==id.value then return F.pins[i] end end
end
function map:GetMappinFromObjective(phase,objective)
 assert(phase and objective)
 if not F.linked then return nil end
 -- FIRST DECLARED map pin, irrespective of its journal-entry state. No fake
 -- search for the 'right' hash: multiple sibling pins would fail this oracle.
 for _,path in ipairs(objective.children) do
  local e=F.entries[path]
  if e.kind=='gameJournalQuestMapPin' then
   for i=0,F.pins.n-1 do local p=F.pins[i];if p.kind=='quest' and p.hash==e.hash then return p end end
   return nil
  end
 end
end
function map:GetQuestMappinPosition(hash)
 local e=F.hashes[hash];assert(e and e.site)
 local p=Sites[e.site].position
 return F.lookupKnown,Vector4.new(p.x,p.y,p.z,1)
end
function map:GetManuallyTrackedMappinID() return {value=F.manual} end
function map:SetMappinActive(id,active)
 local pin=self:GetMappin(id)
 if active then F.activationWrites=F.activationWrites+1 end
 if pin and not F.failHide and not (active and F.failActivate) then pin.active=active end
end
function map:UnregisterMappin(id)
 local pin=self:GetMappin(id);assert(not pin or pin.kind~='quest','Engine-managed quest pins must not be unregistered')
 F.deleted[#F.deleted+1]=id.value
 if F.failDelete then return end
 local pins={n=0};for i=0,F.pins.n-1 do local p=F.pins[i];if p.id~=id.value then pins[pins.n]=p;pins.n=pins.n+1 end end;F.pins=pins
end
function map:RegisterMappin(data,point)
 assert(data.variant==gamedataMappinVariant.QuestGiverVariant and data.active and data.scriptData.fixed)
 F.fallbackCreates=F.fallbackCreates+1
 if F.failRegister then return {value=0} end
 local pin=F:AddPin(0,point);pin.kind='visual';pin.data=data.scriptData
 return pin:GetNewMappinID()
end
function patrol:IsOnDuty() return F.duty end
function patrol:HasWantedLevel() return F.wanted end
function patrol:IsDispatchMenuOpen() return F.menu end
function patrol:PlaceDispatchWaypoint(point) F.legacyPoint=point;return {value=999} end
function patrol:IsOwnedPoliceVehicle(v) return v==F.vehicle end
function patrol:GetScannerPhase() return F.completed and 9 or 1 end
function patrol:NotifyDispatchReward(amount) assert(amount==500) end
function player:IsAttached() return F.attached end
function player:IsDead() return false end
function player:GetWorldPosition() return F.playerPoint end
function GetMountedVehicle(x) return F.mount[x] end
function rewards:Reserve(kind) F.reserved=F.reserved+1;return F.reserved end
function rewards:Cancel() end
function rewards:CompleteVIP(id) F.paidVIP=F.paidVIP+1;return true end
function rewards:CompleteCyberpsycho(id,nonlethal) F.paidCyber=F.paidCyber+1;F.nonlethal=nonlethal;return true end
for _,owner in ipairs({Native,ScannerNative,CyberNative,VIPNative}) do owner.GetGameInstance=function() return {} end end
function container:Get(name)
 if name=='NCPDPatrolFixedMarkerSystem' and not F.nativeMissing then return Native end
 if name=='NCPDPatrolSystem' then return patrol end
 if name=='NCPDPatrolDispatchJournalSystem' then return ScannerNative end
 if name=='NCPDPatrolCyberpsychoSystem' then return CyberNative end
 if name=='NCPDPatrolVIPSystem' then return VIPNative end
end
GameInstance={GetScriptableServiceContainer=function() return serviceContainer end,GetCallbackSystem=function() return callbacks end,GetJournalManager=function() return journal end,GetMappinSystem=function() return map end,GetQuestsSystem=function() return quests end,
 GetTransactionSystem=function() return {GiveItem=function(_,player,item,amount) assert(item=='Items.money');if not F.paymentOK then return false end;F.wallet=F.wallet+amount;return true end} end,
 GetMountingFacility=function() return {GetMountingInfoSingleWithObjects=function() return {slotId={id=F.driver and 'seat_front_left' or 'seat_front_right'}} end} end}
NCPDPatrolSystem={Get=function() return patrol end}
NCPDPatrolIncidentSystem={Get=function() return rewards end}
NCPDPatrolMarkerSession=SessionNative
NCPDPatrolFixedMarkerSystem=Native
NCPDPatrolDispatchJournalSystem={Get=function() return ScannerNative end}
NCPDPatrolCyberpsychoSystem={Get=function() return CyberNative end}
NCPDPatrolVIPSystem={Get=function() return VIPNative end}
function GetPlayer() if F.loaded then return player end end
Game={GetScriptableServiceContainer=function() return serviceContainer end,GetScriptableSystemsContainer=function() return container end,GetMappinSystem=function() return map end,GetPlayer=GetPlayer}
F.patrol=patrol;F.map=map;F.journal=journal;F.player=player
function F:Actor(record,point)
 local x={record=record,point=point,down=false}
 function x:GetRecordID() return self.record end
 function x:GetWorldPosition() return self.point end
 function x:IsAttached() return true end
 function x:IsDead() return false end
 function x:IsDeadNoStatPool() return false end
 return x
end
function F:Car(point)
 local v={point=point}
 function v:IsAttached() return true end
 function v:IsDestroyed() return false end
 function v:GetWorldPosition() return self.point end
 function v:GetCurrentSpeed() return 0 end
 self.vehicle=v;self.mount[self.player]=v;return v
end
F:Reset()
