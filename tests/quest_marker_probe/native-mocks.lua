-- Engine boundaries only. The separate runner executes the authored phase.
F={}
local root='quests/street_stories/ncpd_patrol_marker_reference'
local legacy='quests/minor_quest/ncpd_patrol_marker_probe'
local oldPrefix='ncpd_patrol_marker_probe_r4c_'
local prefix='ncpd_patrol_marker_reference_r4d_'
gameJournalEntryState={Inactive=1,Active=2,Succeeded=3,Failed=4}
JournalNotifyOption={DoNotNotify=1}
function IsDefined(x) return x~=nil and x~=false and x~=0 end
function Equals(a,b) return a==b end
function NotEquals(a,b) return a~=b end
function Cast(a) return a end
function ArraySize(a) return a.n end
gamedataMappinVariant={QuestGiverVariant=8}
function NewReferenceData() return {kind='ReferenceData'} end
function AsReferenceData(x) if x and x.kind=='ReferenceData' then return x end end
function AsQuestMappin(p) if p and p.kind=='QuestMappin' then return p end end
Vector4={}
function Vector4:Distance(a,b) return math.sqrt((a.X-b.X)^2+(a.Y-b.Y)^2+(a.Z-b.Z)^2) end
function Vector4.new(x,y,z,w) return {X=x,Y=y,Z=z,W=w,x=x,y=y,z=z,w=w} end
local journal,map,quests,player,patrol={},{},{},{},{}
function F:Reset(boot)
 self.entries={};self.tracked={state=2,path='story-before'};self.previous=self.tracked
 for _,spec in ipairs({{'','gameJournalQuest'},{'/main','gameJournalQuestPhase'},
     {'/main/inspect','gameJournalQuestObjective'},{'/main/inspect/location','gameJournalQuestMapPin'}}) do
     self.entries[root..spec[1]]={path=root..spec[1],kind=spec[2],state=1,hash=7654}
 end
 self.entries[legacy]={path=legacy,kind='gameJournalQuest',state=1,hash=8888}
 self.entries[legacy..'/main/inspect/location']={path=legacy..'/main/inspect/location',kind='gameJournalQuestMapPin',state=1,hash=8888}
 self.legacyStalled=false
 self.ready=true;self.pins={n=0};self.manual=700;self.requests={};self.removed={}
 self.menu=false;self.duty=false;self.wanted=false;self.combat=false;self.loaded=true
 self.failCreate=false;self.failDelete=false;self.linked=true;self.materialize=false;self.changeManual=false
 self.pos=Vector4.new(PhasePosition.X,PhasePosition.Y,PhasePosition.Z,1);self.writes={}
 self.facts={};self.pc=0;self.incoming=nil;self.graphStalled=false;self.phasePresent=true
 self.retainNativePin=true;self.noNative=false;self.factWrites={}
 Native:OnAttach();Native.m_target=Vector4.new(0,0,0,0)
 for _,name in ipairs({'m_beforeCreate','m_afterCreate','m_beforeRemove','m_afterRemove','m_lastMarker','m_visualID'}) do Native[name]={value=0} end
 if boot~=false then self:StepGraph() end
 Native:Tick(.1);self.requests={};self.writes={};self.factWrites={}
end
function journal:GetEntryByString(path,kind)
 local e=F.entries[path];if F.ready and e and e.kind==kind then return e end
end
function journal:GetEntryState(e) assert(e);return e.state end
function journal:GetEntryHash(e) assert(e);return e.hash end
function journal:GetTrackedEntry() return F.tracked end
function journal:TrackEntry(e) assert(e);F.tracked=e end
function journal:ChangeEntryState(path,kind,state)
 assert(path:sub(1,#root)==root,'write outside private journal')
 local e=self:GetEntryByString(path,kind);assert(e,'missing/wrong-class journal entry')
 F.writes[#F.writes+1]={path=path,state=state};e.state=state
end
function map:GetManuallyTrackedMappinID() return {value=F.manual} end
function map:GetAllMappins() return F.pins end
function map:GetMappin(id)
 for i=0,F.pins.n-1 do if F.pins[i].id==id.value then return F.pins[i] end end
end
function map:RegisterMappin(data,spot)
 F.lastData=data
 if F.failCreate then return {value=0} end
 local pin=F:AddPin();pin.kind='StaticMappin';pin.pos=spot;pin.data=data.scriptData;pin.variant=data.variant
 return pin:GetNewMappinID()
end
function map:SetMappinPosition(id,spot)
 local pin=self:GetMappin(id);assert(pin);pin.pos=spot
end
function map:GetMappinFromObjective(phase,objective)
 assert(phase.path==root..'/main' and objective.path==root..'/main/inspect')
 if F.linked then
  for i=0,F.pins.n-1 do if F.pins[i].kind=='QuestMappin' and F.pins[i].hash==7654 then return F.pins[i] end end
 end
end
function map:UnregisterMappin(id)
 F.removed[#F.removed+1]=id.value
 if F.failDelete then return end
 local p={n=0};for i=0,F.pins.n-1 do
  if F.pins[i].id~=id.value then p[p.n]=F.pins[i];p.n=p.n+1 end
 end;F.pins=p
end
function F:AddPin(hash,pos)
 local pin={kind='QuestMappin',hash=hash or 7654,pos=pos or self.pos,id=900+self.pins.n}
 function pin:GetScriptData() return self.data end
 function pin:GetVariant() return self.variant end
 function pin:GetJournalPathHash() return self.hash end
 function pin:IsQuestMappin() return true end
 function pin:GetWorldPosition() return self.pos end
 function pin:GetNewMappinID() return {value=self.id} end
 self.pins[self.pins.n]=pin;self.pins.n=self.pins.n+1;return pin
end
function quests:GetFactStr(name) assert(name:sub(1,#prefix)==prefix or name:sub(1,#oldPrefix)==oldPrefix);return F.facts[name] or 0 end
function quests:SetFactStr(name,value)
 assert(name:sub(1,#prefix)==prefix or (name==oldPrefix..'request' and value==0),'write outside private phase facts')
 F.facts[name]=value;F.factWrites[#F.factWrites+1]={name=name,value=value}
end
function F:StepGraph()
 if not self.legacyStalled and self.facts[oldPrefix..'request']==0 then self.entries[legacy].state=1;self.facts[oldPrefix..'stage']=0 end
 if self.graphStalled or not self.phasePresent or not self.ready then return end
 for _=1,64 do
  local node=GraphModel[tostring(self.pc)];assert(node,'phase node missing')
  if node.kind=='questPauseConditionNodeDefinition' then
   local value=quests:GetFactStr(node.fact)
   local passed=(node.comparison=='Greater' and value>node.value) or (node.comparison=='Equal' and value==node.value)
   if not passed then return end
  elseif node.kind=='questFactsDBManagerNodeDefinition' then
   assert(node.exact);quests:SetFactStr(node.fact,node.value)
  elseif node.kind=='questJournalNodeDefinition' then
   assert(self.incoming=='Active' or self.incoming=='Inactive')
   journal:ChangeEntryState(node.path,node.class,self.incoming=='Active' and 2 or 1)
   if node.class=='gameJournalQuestMapPin' then
   self.requests[#self.requests+1]=self.incoming
   -- A node executing is explicitly not proof that the native engine created
   -- a QuestMappin. Default no-pin behavior preserves that failure boundary.
   if self.incoming=='Active' then
    if self.materialize then self:AddPin() end
    if self.changeManual then self.manual=701 end
   elseif not self.retainNativePin then
    local keep={n=0};for i=0,self.pins.n-1 do local pin=self.pins[i]
     if pin.kind~='QuestMappin' or pin.hash~=7654 then keep[keep.n]=pin;keep.n=keep.n+1 end
    end;self.pins=keep
   end
   end
  elseif node.kind=='questOutputNodeDefinition' then self.pc=nil;return
  else assert(node.kind=='questInputNodeDefinition') end
  local edge=node.out;assert(edge,'missing output edge');self.pc=edge.node;self.incoming=edge.input
 end
 error('phase failed to reach a waiting boundary')
end
function player:IsAttached() return F.loaded end
function player:IsDead() return false end
function player:IsInCombat() return F.combat end
function player:GetWorldPosition() return Vector4.new(0,0,0,1) end
function patrol:IsOnDuty() return F.duty end
function patrol:HasWantedLevel() return F.wanted end
function patrol:IsDispatchMenuOpen() return F.menu end
GameInstance={GetJournalManager=function() return journal end,GetMappinSystem=function() return map end,
    GetQuestsSystem=function() return quests end}
function GetPlayer() if F.loaded then return player end end
NCPDPatrolSystem={Get=function() return patrol end}
function Native:GetGameInstance() return {} end
local container={Get=function(_,name)
 if name=='NCPDPatrolSystem' then return patrol end
 if name=='NCPDPatrolQuestMarkerProbeSystem' and not F.noNative then return Native end
end}
Game={GetPlayer=GetPlayer,GetScriptableSystemsContainer=function() return container end}
F:Reset()
