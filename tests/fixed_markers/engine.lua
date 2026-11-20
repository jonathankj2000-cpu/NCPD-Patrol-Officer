-- Only engine boundaries. Native creation is deliberately OFF by default.
F={}
function IsDefined(x) return x~=nil and x~=false and x~=0 end
function Equals(a,b) return a==b end
function NotEquals(a,b) return a~=b end
function Cast(x) return x end
function ArraySize(a) return a.n end
function ArrayClear(a) for k in pairs(a) do a[k]=nil end;a.n=0 end
function ArrayPush(a,x) a[a.n]=x;a.n=a.n+1 end
function ArrayContains(a,x) for i=0,a.n-1 do if a[i]==x then return true end end;return false end
function AbsF(x) return math.abs(x) end
function MaxF(a,b) return math.max(a,b) end
function AsQuestMappin(pin) if pin and pin.kind=='quest' then return pin end end
function NewFixedData() return {fixed=true} end
function AsFixedData(x) if x and x.fixed then return x end end
Vector4={new=function(x,y,z,w) return {X=x,Y=y,Z=z,W=w,x=x,y=y,z=z,w=w} end}
function Vector4:Distance(a,b) return math.sqrt((a.X-b.X)^2+(a.Y-b.Y)^2+(a.Z-b.Z)^2) end
gameJournalEntryState={Undefined=0,Inactive=1,Active=2,Succeeded=3,Failed=4}
JournalNotifyOption={DoNotNotify=0}
gamedataMappinVariant={QuestGiverVariant=7}
local journal,map,patrol,player,container={},{},{},{},{}
function F:Scope(index)
 for _,e in pairs(self.entries) do if e.kind~='gameJournalQuestMapPin' then e.state=1 end end
 local root,objective
 if index<6 then
  root='quests/minor_quest/ncpd_patrol_dispatch'..(index==0 and '' or '_'..index);objective=root..'/main/resolve'
 elseif index<8 then root='quests/minor_quest/ncpd_patrol_cyberpsycho';objective=root..'/main/'..(index==6 and 'respond' or 'neutralize')
 else root='quests/minor_quest/ncpd_patrol_vip';objective=root..'/main/'..(index==8 and 'pickup' or 'deliver') end
 self.entries[root].state=2;self.entries[root..'/main'].state=2;self.entries[objective].state=2
 self.scope=index;self.objective=objective
end
function F:Reset(scope)
 self.entries={};self.hashes={};self.pins={n=0};self.writes={};self.deleted={};self.fallbackCreates=0
 self.materialize=false;self.failDelete=false;self.failHide=false;self.failRegister=false
 self.menu=false;self.duty=true;self.wanted=false;self.loaded=true;self.nativeMissing=false
 self.manual=700;self.story={path='story'};self.lookupKnown=true;self.linked=true;self.changeManual=false
 local nextHash=1000
 local function add(path,kind)
  if not F.entries[path] then
   nextHash=nextHash+1;local e={path=path,kind=kind,state=1,hash=nextHash};F.entries[path]=e;F.hashes[nextHash]=e
  end
 end
 for _,d in ipairs(Definitions) do
  add(d.root,'gameJournalQuest');add(d.root..'/main','gameJournalQuestPhase');add(d.objective,'gameJournalQuestObjective');add(d.path,'gameJournalQuestMapPin')
  self.entries[d.path].site=d.site;self.entries[d.path].objective=d.objective
 end
 Native:OnAttach()
 for _,name in ipairs({'m_target','m_runtimePoint','m_questPoint'}) do Native[name]=Vector4.new(0,0,0,1) end
 for _,name in ipairs({'m_nativeID','m_fallbackID','m_manualBefore','m_manualAfter'}) do Native[name]={value=0} end
 self:Scope(scope or 0);Native:Tick(.25);self.writes={};self.deleted={}
end
function journal:GetEntryByString(path,kind)
 local e=F.entries[path];if e and e.kind==kind then return e end
end
function journal:GetEntryState(entry) assert(entry);return entry.state end
function journal:GetEntryHash(entry) return entry.hash end
function journal:ChangeEntryState(path,kind,state)
 local e=self:GetEntryByString(path,kind);assert(e and kind=='gameJournalQuestMapPin','write outside fixed map-pin children')
 F.writes[#F.writes+1]={path=path,state=state}
 if state==1 and F.failHide then return false end
 e.state=state
 if state==2 and F.materialize then F:AddPin(e.hash) end
 if F.changeManual then F.manual=701 end
 return true
end
function F:AddPin(hash,point)
 local e=self.hashes[hash];local position=Sites[e.site].position
 local pin={kind='quest',hash=hash,id=9000+self.pins.n,point=point or Vector4.new(position.x,position.y,position.z,1),objective=e.objective}
 function pin:GetNewMappinID() return {value=self.id} end
 function pin:GetWorldPosition() return self.point end
 function pin:GetJournalPathHash() return self.hash end
 function pin:IsQuestMappin() return self.kind=='quest' end
 function pin:GetScriptData() return self.data end
 self.pins[self.pins.n]=pin;self.pins.n=self.pins.n+1
 return pin
end
function map:GetAllMappins() return F.pins end
function map:GetMappin(id)
 for i=0,F.pins.n-1 do if F.pins[i].id==id.value then return F.pins[i] end end
end
function map:GetMappinFromObjective(phase,objective)
 assert(phase and objective)
 if F.linked then for i=0,F.pins.n-1 do local p=F.pins[i];if p.kind=='quest' and p.objective==objective.path then return p end end end
end
function map:GetQuestMappinPosition(hash)
 local e=F.hashes[hash];assert(e and e.site)
 local p=Sites[e.site].position
 return F.lookupKnown,Vector4.new(p.x,p.y,p.z,1)
end
function map:GetManuallyTrackedMappinID() return {value=F.manual} end
function map:UnregisterMappin(id)
 F.deleted[#F.deleted+1]=id.value
 if F.failDelete then return end
 local pins={n=0};for i=0,F.pins.n-1 do local p=F.pins[i];if p.id~=id.value then pins[pins.n]=p;pins.n=pins.n+1 end end;F.pins=pins
end
function map:RegisterMappin(data,point)
 assert(data.variant==gamedataMappinVariant.QuestGiverVariant and data.active and data.scriptData.fixed)
 F.fallbackCreates=F.fallbackCreates+1
 if F.failRegister then return {value=0} end
 local first=F.entries[F.objective..'/bank_'..(F.scope<6 and 1 or 133)]
 local pin=F:AddPin(first.hash,point);pin.kind='visual';pin.data=data.scriptData
 return pin:GetNewMappinID()
end
function patrol:IsOnDuty() return F.duty end
function patrol:HasWantedLevel() return F.wanted end
function patrol:IsDispatchMenuOpen() return F.menu end
function patrol:PlaceDispatchWaypoint(point) F.legacyPoint=point;return {value=999} end
function player:IsAttached() return F.loaded end
function player:IsDead() return false end
function Native:GetGameInstance() return {} end
function container:Get(name)
 if name=='NCPDPatrolFixedMarkerSystem' and not F.nativeMissing then return Native end
 if name=='NCPDPatrolSystem' then return patrol end
end
GameInstance={GetJournalManager=function() return journal end,GetMappinSystem=function() return map end}
NCPDPatrolSystem={Get=function() return patrol end}
function GetPlayer() if F.loaded then return player end end
Game={GetScriptableSystemsContainer=function() return container end,GetMappinSystem=function() return map end,GetPlayer=GetPlayer}
F.patrol=patrol;F.map=map
F:Reset()
