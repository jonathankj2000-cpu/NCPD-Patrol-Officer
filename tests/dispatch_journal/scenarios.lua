function IsDefined(v) return v~=nil and v~=0 end
function Equals(a,b) return a==b end
function NotEquals(a,b) return a~=b end
function ToString(v) return tostring(v) end
Vector4={Distance=function(_,a,b) return math.sqrt((a.x-b.x)^2+(a.y-b.y)^2+(a.z-b.z)^2) end}
local player={pos={x=10,y=10,z=0,w=1},attached=true,dead=false,combat=false}
function player:GetWorldPosition() return self.pos end
function player:IsAttached() return self.attached end
function player:IsDead() return self.dead end
function player:IsInCombat() return self.combat end
function GetPlayer() return player end
local patrol={duty=true,wanted=false,paused=false,notices={},markers={},nextMarker=0,paid={},bonus=0}
function patrol:IsOnDuty() return self.duty end
function patrol:HasWantedLevel() return self.wanted end
function patrol:IsDispatchMenuOpen() return self.paused end
function patrol:Version() return 17 end
function patrol:NotifyDispatch(text) self.notices[#self.notices+1]=text end
function patrol:ClearDispatchWaypoints() self.markers={} end
function patrol:PlaceDispatchWaypoint(pos) self.nextMarker=self.nextMarker+1;self.markers[self.nextMarker]=pos;return {value=self.nextMarker} end
function patrol:GetScannerPhase(hash,marker) return marker and marker.phase or (self.savedPhase or 'complete') end
function patrol:NotifyDispatchReward(amount) self:NotifyDispatch('DISPATCH BONUS PAID: +'..amount) end
function patrol:GetDispatchCandidates() return self.candidates or {} end
function patrol:TickBonuses()
 for _,p in ipairs(self.candidates or {}) do
  if p.phase=='complete' and not self.paid[p.hash] then self.paid[p.hash]=true;self.bonus=self.bonus+1000 end
 end
end
NCPDPatrolSystem={Get=function() return patrol end}
Game={GetPlayer=function() return player end,GetScriptableSystemsContainer=function()
 return {Get=function(_,name) if name=='NCPDPatrolDispatchJournalSystem' then return DispatchJournalBridge end end}
end}
gamedataMappinVariant={OutpostVariant='organized'};gamedataMappinPhase={CompletedPhase='complete'}
local c=DispatchJournalNative
math.randomseed(901)
local target={x=800,y=10,z=0,w=1}
local function reset()
 JournalFixture:ResetRuntime(c);patrol.duty=true;patrol.wanted=false;patrol.paused=false
 DispatchRewardFixture:Reset();patrol.savedPhase=nil;patrol.notices={}
 player.pos={x=10,y=10,z=0,w=1};player.dead=false;player.attached=true
end
local function advance(seconds) for _=1,math.floor(seconds*4+0.00001) do c:Tick(0.25) end end
local hashSequence=100
local function begin(briefing) hashSequence=hashSequence+1;local t=c:BeginDispatch(hashSequence,target,briefing or 0);assert(t>0,c:GetReason());return t end
local function active() assert(JournalFixture:State()==2 and JournalFixture:Objective()==2) end

reset();local story=JournalFixture:Story();JournalFixture.tracked=story
local token=begin();active();assert(c:GetRemainingSeconds()==180)
advance(179.75);assert(c:GetStage()==1 and c:GetRemainingSeconds()==1)
advance(0.25);assert(c:GetStage()==4 and JournalFixture:State()==4 and JournalFixture:Objective()==4)
assert(JournalFixture.tracked==story and story.state==2)
assert(not c:CompleteDispatch(token))
local writes=#JournalFixture.writes;advance(20);assert(#JournalFixture.writes==writes)
local nextToken=begin();assert(nextToken~=token);active();assert(not c:CompleteDispatch(token))
player.pos=target;c:Tick(0.25);assert(c:GetStage()==2 and c:GetRemainingSeconds()==0)
advance(300);assert(c:GetStage()==2)
assert(c:CompleteDispatch(nextToken));assert(JournalFixture:State()==3 and JournalFixture:Objective()==3)
assert(not c:CompleteDispatch(nextToken))
player.pos={x=10,y=10,z=0,w=1};nextToken=begin();active()
c:CancelDispatch(nextToken,'manual');assert(c:GetStage()==5 and JournalFixture:State()==1)
nextToken=begin();active();c:CancelDispatch(nextToken-1,'stale');active()

reset();token=begin();patrol.paused=true;advance(300);assert(c:GetRemainingSeconds()==180)
patrol.paused=false;c:Tick(20);c:Tick(-1);assert(c:GetRemainingSeconds()==180)
assert(c:ArmTimeoutTest(token));advance(14.75)
player.pos={x=target.x-60,y=target.y,z=0,w=1};c:Tick(0.25)
assert(c:GetStage()==2,'arrival boundary lost to expiry');assert(not c:ArmTimeoutTest(token))

reset();JournalFixture.ready=false;assert(c:BeginDispatch(101,target)==0)
assert(c:GetReason():find('ArchiveXL',1,true) and #JournalFixture.writes==0)
reset();JournalFixture.rejectState=2;assert(c:BeginDispatch(101,target)==0);assert(JournalFixture:State()==1)
reset();token=begin();player.pos=target;c:Tick(0.25);assert(c:CompleteDispatch(token))
JournalFixture.rejectReset=true;assert(c:BeginDispatch(102,target)==0)
assert(c:GetReason():find('reset rejected',1,true) and JournalFixture:State()==3)
reset();JournalFixture.ignoreWrites=true;token=begin();advance(1);assert(c:GetStage()==6)

reset();story=JournalFixture:Story('before');JournalFixture.tracked=story;token=begin()
local changed=JournalFixture:Story('changed');JournalFixture.tracked=changed
c:CancelDispatch(token,'manual');assert(JournalFixture.tracked==changed)
reset();JournalFixture.tracked=story;token=begin();c:CancelDispatch(token,'manual');assert(JournalFixture.tracked==story)

reset();token=begin();writes=#JournalFixture.writes;c:OnRestored(1,1)
assert(#JournalFixture.writes==writes);patrol.duty=false;c:Tick(0.25)
assert(JournalFixture:State()==1 and c:GetStage()==0 and not c:CompleteDispatch(token))
reset();token=begin();player.pos=target;c:Tick(0.25);assert(c:CompleteDispatch(token))
c:OnRestored(1,1);c:Tick(0.25);assert(JournalFixture:State()==3)
reset();token=begin();patrol.wanted=true;c:Tick(0.25);assert(JournalFixture:State()==4)
reset();token=begin();patrol.duty=false;c:Tick(0.25);assert(c:GetStage()==5 and JournalFixture:State()==1)
reset();token=begin();player.dead=true;c:Tick(0.25);assert(c:GetStage()==5)
reset();assert(c:BeginDispatch(0,target)==0)

-- Each briefing has exactly one active objective and uses the same state flow.
-- Completed entries may remain in history, but there is never a second active call.
reset()
for round=1,2 do
 for variant=0,5 do
  token=begin(variant);active()
  for other=0,5 do if other~=variant then assert(JournalFixture:State(other)~=2 and JournalFixture:Objective(other)~=2) end end
  player.pos=target;c:Tick(0.25);assert(c:CompleteDispatch(token))
  assert(c:GetPaidDispatches()==(round-1)*6+variant+1 and c:GetPendingDispatchRewards()==0)
  assert(not c:CompleteDispatch(token),'duplicate completion paid twice')
 end
end
assert(DispatchRewardFixture.wallet==6000 and DispatchRewardFixture.attempts==12)
local paidHash=c.m_hash;c:OnRestored(1,1);c:Tick(0.25)
assert(c:GetPaidDispatches()==12 and DispatchRewardFixture.wallet==6000)
assert(c:BeginDispatch(paidHash,target,4)==0,'save/load lost the paid incident ledger')
assert(c:BeginDispatch(999,target,-1)==0 and c:BeginDispatch(999,target,6)==0)

-- Only a completed matching scanner can earn the supplement; terminal journal
-- rejection, timeout, wanted, cancellation and pre-arrival completion earn none.
reset();token=begin(3);player.pos=target;c:Tick(0.25);patrol.savedPhase='active'
assert(not c:CompleteDispatch(token) and c:GetStage()==2 and DispatchRewardFixture.wallet==0)
local wrong={GetJournalPathHash=function() return c.m_hash+1 end,phase='complete'}
assert(not c:CompleteDispatch(token,wrong) and DispatchRewardFixture.wallet==0)
patrol.savedPhase='complete';JournalFixture.rejectState=3
assert(not c:CompleteDispatch(token) and c:GetStage()==6 and c:GetPendingDispatchRewards()==0 and DispatchRewardFixture.wallet==0)
reset();token=begin();c:CancelDispatch(token,'manual');assert(not c:CompleteDispatch(token) and DispatchRewardFixture.wallet==0)
reset();token=begin();patrol.wanted=true;c:Tick(0.25);assert(not c:CompleteDispatch(token) and DispatchRewardFixture.wallet==0)

-- A rejected transaction stays in the persistent earned-reward queue. The
-- journal can finish and another call can start; retries cannot duplicate money.
reset();DispatchRewardFixture.paymentOK=false;token=begin(5);player.pos=target;c:Tick(0.25)
assert(c:CompleteDispatch(token) and c:GetStage()==3 and JournalFixture:State()==3)
assert(c:GetPendingDispatchRewards()==1 and c:GetPaidDispatches()==0 and DispatchRewardFixture.wallet==0)
assert(c:TakeDispatchReceipt()=='' and #patrol.notices==0)
paidHash=c.m_hash;assert(c:BeginDispatch(paidHash,target,2)==0)
c:OnRestored(1,1);patrol.duty=false;patrol.paused=true;DispatchRewardFixture.paymentOK=true
advance(2);assert(DispatchRewardFixture.wallet==0 and c:GetPendingDispatchRewards()==1)
patrol.paused=false;player.attached=false;advance(2);assert(DispatchRewardFixture.wallet==0)
player.attached=true;DispatchRewardFixture.available=false;advance(2);assert(DispatchRewardFixture.wallet==0)
DispatchRewardFixture.available=true;advance(1)
assert(DispatchRewardFixture.wallet==500 and c:GetPendingDispatchRewards()==0 and c:GetPaidDispatches()==1)
assert(c:TakeDispatchReceipt():find('DISPATCH BONUS PAID: +EUR$500',1,true) and c:TakeDispatchReceipt()=='')
assert(#patrol.notices==1);advance(10);assert(DispatchRewardFixture.wallet==500 and #patrol.notices==1)
patrol.duty=true;assert(c:BeginDispatch(paidHash,target,0)==0)

-- Upgrade/load cleanup covers every briefing, including the original v0.9a path.
reset()
for variant=0,5 do
 local t=begin(variant);local p=c:QuestPath();JournalFixture.entries[p].state=2
 c:OnRestored(1,1);c:Tick(0.25)
 assert(JournalFixture:State(variant)==1 and not c:CompleteDispatch(t))
end

local hud={}
package.loaded.dispatch_hud={init=function() end,set=function(text,visible) hud.text=text;hud.visible=visible end,state=function() return 'fixture' end,shutdown=function() end}
local Dispatch=require('dispatch')
local function marker(hash,x)
 local m={hash=hash,phase='active',pos={x=x,y=10,z=0,w=1}}
 function m:GetJournalPathHash() return self.hash end
 function m:GetWorldPosition() return self.pos end
 function m:GetVariant() return 'assault' end
 return m
end
local function ticks(seconds) for _=1,math.floor(seconds*4) do Dispatch.update(0.25,true,nil,function() return patrol end) end end
local function setup(...)
 reset();patrol.candidates={...};patrol.bonus=0;patrol.paid={};Dispatch.reset();Dispatch.start(patrol)
end
local m=marker(1001,800);setup(m)
assert(Dispatch.request(patrol));assert(Dispatch.isActive() and hud.text:find('03:00',1,true));active()
assert(Dispatch.armTimeoutTest(patrol));ticks(16)
assert(not Dispatch.isActive() and Dispatch.failedCount()==1 and JournalFixture:State()==4)
assert(m.phase=='active' and patrol.bonus==0 and next(patrol.markers)==nil and DispatchRewardFixture.wallet==0)
m.phase='complete';patrol:TickBonuses();assert(patrol.bonus==1000)

m=marker(1002,800);setup(m);assert(Dispatch.request(patrol))
Dispatch.setBusy(true);patrol.paused=true;ticks(200);assert(Dispatch.isActive() and c:GetRemainingSeconds()==180)
patrol.paused=false;player.pos=m.pos;ticks(1);assert(c:GetStage()==2 and Dispatch.isActive())
assert(not Dispatch.armTimeoutTest(patrol));m.phase='complete';patrol:TickBonuses();ticks(1)
assert(Dispatch.completed()==1 and Dispatch.failedCount()==0 and JournalFixture:State()==3 and patrol.bonus==1000)
assert(DispatchRewardFixture.wallet==500 and c:GetPaidDispatches()==1)
ticks(20);assert(patrol.bonus==1000 and Dispatch.completed()==1 and DispatchRewardFixture.wallet==500)

m=marker(1003,800);setup(m);assert(Dispatch.request(patrol));m.phase='complete';ticks(1)
assert(not Dispatch.isActive() and Dispatch.completed()==0 and Dispatch.failedCount()==0 and JournalFixture:State()==1)
assert(DispatchRewardFixture.wallet==0)

m=marker(1004,800);setup(m);JournalFixture.ready=false;assert(not Dispatch.request(patrol))
assert(not Dispatch.isActive() and next(patrol.markers)==nil)
JournalFixture.ready=true;assert(Dispatch.request(patrol));assert(Dispatch.cancel(patrol));assert(JournalFixture:State()==1)
local other=marker(1005,900);patrol.candidates={m,other};assert(Dispatch.replace(patrol));assert(Dispatch.isActive())
local oldToken=c:GetToken();Dispatch.reset();c:OnRestored(1,1);ticks(0.25)
assert(not Dispatch.isActive() and not c:CompleteDispatch(oldToken))

-- Actual Lua selection avoids consecutive repeats and all six authored paths
-- are reachable across cancellation/replacement without awarding any money.
setup();local seen={};local previous=nil
for i=1,40 do
 local incident=marker(2000+i,800);patrol.candidates={incident}
 assert(Dispatch.request(patrol));local variant=c.m_briefing
 assert(variant>=0 and variant<=5 and variant~=previous)
 seen[variant]=true;previous=variant;assert(Dispatch.cancel(patrol))
end
for variant=0,5 do assert(seen[variant],'briefing not selectable') end
assert(DispatchRewardFixture.wallet==0 and c:GetPaidDispatches()==0)

-- A successful native transfer is printed once by the actual CET bridge.
m=marker(3001,800);setup(m);local logs={};local function log(text) logs[#logs+1]=text end
assert(Dispatch.request(patrol,log));player.pos=m.pos;ticks(1);m.phase='complete';ticks(1)
Dispatch.update(0.25,true,log,function() return patrol end)
Dispatch.update(0.25,true,log,function() return patrol end)
local receipts=0;for _,v in ipairs(logs) do if v:find('DISPATCH BONUS PAID: +EUR$500',1,true) then receipts=receipts+1 end end
assert(receipts==1 and DispatchRewardFixture.wallet==500)
