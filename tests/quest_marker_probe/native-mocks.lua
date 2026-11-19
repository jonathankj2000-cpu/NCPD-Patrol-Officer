-- Engine boundaries only. The actual authored native controller runs above
-- these fixtures. ExecuteNode intentionally produces NO pin by default.
F={}
local root='quests/minor_quest/ncpd_patrol_marker_probe'
gameJournalEntryState={Inactive=1,Active=2,Succeeded=3,Failed=4}
JournalNotifyOption={DoNotNotify=1}
function IsDefined(x) return x~=nil and x~=false and x~=0 end
function Equals(a,b) return a==b end
function NotEquals(a,b) return a~=b end
function Cast(a) return a end
function ArraySize(a) return a.n end
function AsQuestMappin(p) if p and p.kind=='QuestMappin' then return p end end
function NewJournalPath() return {GetHash=function() return 12345 end} end
function NewMarkerNode() return {} end
Vector4={}
function Vector4:Distance(a,b) return math.sqrt((a.X-b.X)^2+(a.Y-b.Y)^2+(a.Z-b.Z)^2) end
function Vector4.new(x,y,z,w) return {X=x,Y=y,Z=z,W=w,x=x,y=y,z=z,w=w} end
local journal,map,quests,player,patrol={},{},{},{},{}
function F:Reset()
 self.entries={};self.tracked={state=2,path='story-before'};self.previous=self.tracked
 for _,spec in ipairs({{'','gameJournalQuest'},{'/main','gameJournalQuestPhase'},
     {'/main/inspect','gameJournalQuestObjective'},{'/main/inspect/location','gameJournalQuestMapPin'}}) do
     self.entries[root..spec[1]]={path=root..spec[1],kind=spec[2],state=1,hash=7654}
 end
 self.ready=true;self.pins={n=0};self.manual=700;self.requests={};self.removed={}
 self.menu=false;self.duty=false;self.wanted=false;self.combat=false;self.loaded=true
 self.failDelete=false;self.rejectWrite=false;self.linked=true;self.materialize=false
 self.changeManual=false;self.pos=Vector4.new(150,0,0,1);self.writes={}
 Native:OnAttach()
 for _,name in ipairs({'m_beforeCreate','m_afterCreate','m_beforeRemove','m_afterRemove','m_lastMarker'}) do Native[name]={value=0} end
 Native:Tick(.1)
end
function journal:GetEntryByString(path,kind)
 local e=F.entries[path];if F.ready and e and e.kind==kind then return e end
end
function journal:GetEntryState(e) assert(e);return e.state end
function journal:GetEntryHash(e) assert(e);return e.hash end
function journal:GetTrackedEntry() return F.tracked end
function journal:TrackEntry(e) assert(e);F.tracked=e end
function journal:ChangeEntryState(path,kind,state,notify)
 assert(path:sub(1,#root)==root and notify==1,'writes outside private journal')
 F.writes[#F.writes+1]={path=path,state=state}
 if F.rejectWrite then return false end
 self:GetEntryByString(path,kind).state=state;return true
end
function map:GetManuallyTrackedMappinID() return {value=F.manual} end
function map:GetAllMappins() return F.pins end
function map:GetMappinFromObjective(phase,objective)
 assert(phase.path==root..'/main' and objective.path==root..'/main/inspect')
 if F.linked then return F.pins[0] end
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
 function pin:GetJournalPathHash() return self.hash end
 function pin:IsQuestMappin() return true end
 function pin:GetWorldPosition() return self.pos end
 function pin:GetNewMappinID() return {value=self.id} end
 self.pins[self.pins.n]=pin;self.pins.n=self.pins.n+1;return pin
end
function quests:ExecuteNode(node,input)
 assert(node.path.realPath==root..'/main/inspect/location' and node.path.fileEntryIndex==-1)
 assert(node.path.className=='gameJournalQuestMapPin' and node.disablePreviousMappins==false)
 F.requests[#F.requests+1]=input or 'default'
 if input~='Disable' and F.materialize then F:AddPin() end
 if input~='Disable' and F.changeManual then F.manual=701 end
end
function player:IsAttached() return F.loaded end
function player:IsDead() return false end
function player:IsInCombat() return F.combat end
function player:GetWorldPosition() return Vector4.new(0,0,0,1) end
function player:GetWorldForward() return {x=1,y=0,z=0} end
function player:GetWorldOrientation() return {} end
function patrol:IsOnDuty() return F.duty end
function patrol:HasWantedLevel() return F.wanted end
function patrol:IsDispatchMenuOpen() return F.menu end
GameInstance={GetJournalManager=function() return journal end,GetMappinSystem=function() return map end,
    GetQuestsSystem=function() return quests end}
function GetPlayer() if F.loaded then return player end end
NCPDPatrolSystem={Get=function() return patrol end}
function Native:GetGameInstance() return {} end
function F:Anchor(pos) return {GetWorldPosition=function() return pos or F.pos end,IsAttached=function() return true end} end
-- Codeware/entity/native bridge for the actual Lua controller, tested below.
local entities={}
function entities:IsReady() return F.ready end
function entities:CreateEntity(spec)
 assert(spec.persistSpawn==false and spec.persistState==false and spec.alwaysSpawned==true)
 assert(spec.templatePath==Native:GetAnchorTemplate() and spec.tags[1]=='NCPDPatrol_QuestMarkerProbeAnchor')
 F.spec=spec;F.managed=true;F.created=(F.created or 0)+1;F.entityID={hash=101};return F.entityID
end
function entities:IsManaged(id) assert(id==F.entityID);return F.managed end
function entities:IsTagged(id,tag) assert(id==F.entityID);return tag=='NCPDPatrol_QuestMarkerProbeAnchor' and not F.badTag end
function entities:GetEntity(id) assert(id==F.entityID);if not F.detach then return F:Anchor(F.spec.position) end end
function entities:DeleteEntity(id) assert(id==F.entityID);F.deleted=(F.deleted or 0)+1;if not F.deferAnchor then F.managed=false end end
local container={Get=function(_,name)
 if name=='NCPDPatrolSystem' then return patrol end
 if name=='NCPDPatrolQuestMarkerProbeSystem' and not F.noNative then return Native end
end}
Game={GetPlayer=GetPlayer,GetScriptableSystemsContainer=function() return container end,
 GetDynamicEntitySystem=function() return entities end,GetResourceDepot=function() return {ResourceExists=function() return true end} end}
DynamicEntitySpec={new=function() return {} end}
EntityID={IsDefined=function(id) return id.hash~=0 end}
CName={new=function(s) return s end}
F:Reset()
