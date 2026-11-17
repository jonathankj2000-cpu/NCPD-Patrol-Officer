-- Native boundaries only; production journal code is executed by the test.
gameJournalEntryState={Undefined=0,Inactive=1,Active=2,Succeeded=3,Failed=4}
JournalNotifyOption={Undefined=0,DoNotNotify=1,Notify=2}
CeilF=CeilF or function(v) return math.ceil(v) end
JournalFixture={entries={},writes={},tracks={},ready=true,rejectReset=false,ignoreWrites=false,tracked=nil}
local prefix='quests/minor_quest/ncpd_patrol_dispatch'
local function path(variant) return prefix..((variant or 0)==0 and '' or '_'..variant) end
ArraySize=ArraySize or function(a) return a.n end
ArrayPush=ArrayPush or function(a,v) a[a.n]=v;a.n=a.n+1 end
ArrayClear=ArrayClear or function(a) for i=0,a.n-1 do a[i]=nil end;a.n=0 end
ArrayErase=ArrayErase or function(a,i) for j=i,a.n-2 do a[j]=a[j+1] end;a[a.n-1]=nil;a.n=a.n-1 end
ArrayContains=ArrayContains or function(a,v) for i=0,a.n-1 do if a[i]==v then return true end end;return false end
StringToName=StringToName or function(v) return v end
function JournalFixture:Reset()
 self.entries={};self.writes={};self.tracks={};self.ready=true
 self.rejectReset=false;self.rejectState=nil;self.ignoreWrites=false;self.tracked=nil
 for variant=0,5 do
  local p=path(variant)
  for _,v in ipairs({{p,'gameJournalQuest'},{p..'/main','gameJournalQuestPhase'},{p..'/main/resolve','gameJournalQuestObjective'},{p..'/main/resolve/briefing','gameJournalQuestDescription'}}) do
   self.entries[v[1]]={path=v[1],className=v[2],state=1}
  end
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
function JournalFixture:State(variant) return self.entries[path(variant or DispatchJournalNative.m_briefing)].state end
function JournalFixture:Objective(variant) return self.entries[path(variant or DispatchJournalNative.m_briefing)..'/main/resolve'].state end
function JournalFixture:Story(id) return {path='quests/side_quest/'..(id or 'story'),className='gameJournalQuestObjective',state=2} end
function JournalFixture:ResetRuntime(controller)
 self:Reset();controller.m_paidDispatches={n=0};controller.m_pendingDispatchRewards={n=0};controller:OnAttach()
end
JournalFixture:Reset()
GameInstance=GameInstance or {}
GameInstance.GetJournalManager=function() return JournalFixture end
DispatchRewardFixture={wallet=0,attempts=0,paymentOK=true,available=true}
function DispatchRewardFixture:Reset() self.wallet=0;self.attempts=0;self.paymentOK=true;self.available=true end
local transaction={GiveItem=function(_,player,item,amount)
 assert(player and item=='Items.money' and amount==500)
 DispatchRewardFixture.attempts=DispatchRewardFixture.attempts+1
 if not DispatchRewardFixture.paymentOK then return false end
 DispatchRewardFixture.wallet=DispatchRewardFixture.wallet+amount;return true
end}
GameInstance.GetTransactionSystem=function() if DispatchRewardFixture.available then return transaction end end
ItemID=ItemID or {FromTDBID=function(_,id) return id end}
function DispatchJournalNative:GetGameInstance() return {} end
DispatchJournalNative:OnAttach()
DispatchJournalBridge=setmetatable({}, {__index=function(_,name) return function(_,...) return DispatchJournalNative[name](DispatchJournalNative,...) end end})
