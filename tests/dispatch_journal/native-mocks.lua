-- Native boundaries only; production journal code is executed by the test.
gameJournalEntryState={Undefined=0,Inactive=1,Active=2,Succeeded=3,Failed=4}
JournalNotifyOption={Undefined=0,DoNotNotify=1,Notify=2}
CeilF=CeilF or function(v) return math.ceil(v) end
JournalFixture={entries={},writes={},tracks={},ready=true,rejectReset=false,ignoreWrites=false,tracked=nil}
local prefix='quests/minor_quest/ncpd_patrol_dispatch'
function JournalFixture:Reset()
 self.entries={};self.writes={};self.tracks={};self.ready=true
 self.rejectReset=false;self.rejectState=nil;self.ignoreWrites=false;self.tracked=nil
 for _,v in ipairs({{prefix,'gameJournalQuest'},{prefix..'/main','gameJournalQuestPhase'},{prefix..'/main/resolve','gameJournalQuestObjective'},{prefix..'/main/resolve/briefing','gameJournalQuestDescription'}}) do
  self.entries[v[1]]={path=v[1],className=v[2],state=1}
 end
end
function JournalFixture:GetEntryByString(path,className)
 if not self.ready then return nil end
 local e=self.entries[path];if e and e.className==className then return e end
end
function JournalFixture:GetEntryState(e) assert(e,'nil state read');return e.state end
function JournalFixture:GetTrackedEntry() return self.tracked end
function JournalFixture:TrackEntry(e) assert(e,'TrackEntry(nil) not verified');self.tracked=e;self.tracks[#self.tracks+1]=e end
function JournalFixture:ChangeEntryState(path,className,state,notify)
 assert(path:sub(1,#prefix)==prefix,'write outside mod-owned journal')
 local e=self:GetEntryByString(path,className);assert(e,'missing/wrong-class entry')
 self.writes[#self.writes+1]={path=path,state=state,notify=notify}
 if self.rejectState==state then return false end
 if self.rejectReset and state==1 and (e.state==3 or e.state==4) then return false end
 if not self.ignoreWrites then e.state=state end
 return true
end
function JournalFixture:State() return self.entries[prefix].state end
function JournalFixture:Objective() return self.entries[prefix..'/main/resolve'].state end
function JournalFixture:Story(id) return {path='quests/side_quest/'..(id or 'story'),className='gameJournalQuestObjective',state=2} end
function JournalFixture:ResetRuntime(controller) self:Reset();controller:OnAttach() end
JournalFixture:Reset()
GameInstance=GameInstance or {}
GameInstance.GetJournalManager=function() return JournalFixture end
function DispatchJournalNative:GetGameInstance() return {} end
DispatchJournalNative:OnAttach()
DispatchJournalBridge=setmetatable({}, {__index=function(_,name) return function(_,...) return DispatchJournalNative[name](DispatchJournalNative,...) end end})
