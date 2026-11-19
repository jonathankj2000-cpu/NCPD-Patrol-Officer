local f,v,r,c,n=CyberFixture,VIPFixture,IncidentRewardFixture,CyberNative,VIPNative
local backend=IncidentNative
NCPDPatrolDispatchJournalSystem={Get=function() return DispatchJournalNative end}
function CareerNative:GetGameInstance() return {} end
function f.patrol:GetRecordedScannerCount() return f.recordedScanners or 0 end
local function reset()
 v:Reset();f.recordedScanners=0;notifications={}
end
local function tick(seconds)
 for _=1,math.floor(seconds*4+.0001) do backend:Tick(.25) end
end
local pickup,destination={x=800,y=0,z=0},{x=1800,y=0,z=0}
local function vip()
 local token=n:BeginDispatch(pickup,destination);assert(token>0,n:GetReason())
 local rewardId=n.m_rewardId
 f.playerPosition.x=780;local actor=v:Actor()
 assert(n:BindVIP(token,actor));v:Drive();v:Mount(actor,v.car)
 assert(n:ConfirmBoarded(token,v.car))
 v.car.pos.x=1800;f.playerPosition.x=1800
 assert(n:BeginDropOff(token))
 return token,actor,rewardId
end
local function finishVIP()
 local token,actor,id=vip();actor.mounted=nil;actor.pos.x=1800
 n:Tick(.25);assert(n:GetStage()==3,n:GetReason())
 return token,actor,id
end
local function cyber()
 local token=c:BeginDispatch(pickup);assert(token>0,c:GetReason())
 f.playerPosition.x=700;c:Tick(.25)
 local actor=f:Actor();assert(c:BindTarget(token,actor))
 return actor,c.m_rewardId
end

-- Delivery is the reward trigger, not an assigned marker or mount command.
reset();local token,actor,id=vip()
assert(r.wallet==0 and backend:GetCompletedCount()==0)
n:Tick(.25);assert(n:GetStage()==2 and r.wallet==0)
actor.mounted=nil;actor.pos.x=1500;n:Tick(.25)
assert(r.wallet==0 and backend:GetCompletedCount()==0)
actor.pos.x=1800;n:Tick(.25)
assert(n:GetStage()==3 and r.wallet==2000 and #r.grants==1)
assert(backend:GetCompletedCount()==1 and backend:GetCompletedVIP()==1 and backend:GetCompletedCyberpsychos()==0)
assert(backend:CompleteVIP(id));n:Tick(.25);tick(20)
assert(r.wallet==2000 and #r.grants==1 and DispatchRewardFixture.wallet==0)

-- All supported lethal/non-lethal outcomes use the actual target proof and
-- freeze the earned amount. Later damage cannot pay again or change the bonus.
for _,state in ipairs({'dead','deadNoPool','defeated','unconscious'}) do
 reset();actor,id=cyber();actor[state]=true
 f:Advance(.5);assert(r.wallet==0 and backend:GetCompletedCount()==0)
 f:Advance(.25)
 local amount=(state=='dead' or state=='deadNoPool') and 3000 or 3500
 assert(c:GetStage()==3 and r.wallet==amount and #r.grants==1)
 assert(backend:GetCompletedCount()==1 and backend:GetCompletedCyberpsychos()==1)
 actor.dead=true;f:Advance(2);assert(backend:CompleteCyberpsycho(id,false))
 tick(20);assert(r.wallet==amount and #r.grants==1)
end
reset();actor=cyber();actor.defeated=true;f:Advance(.5);actor.dead=true;f:Advance(.25)
assert(r.wallet==3000,'non-lethal bonus granted after death before confirmation')

-- Failed/cancelled assignments and rejected journal success cannot credit.
for _,reason in ipairs({'dead','cancel','journal','lost'}) do
 reset();token,actor,id=vip()
 if reason=='dead' then actor.dead=true;n:Tick(.25)
 elseif reason=='cancel' then n:Cancel(token,'test')
 elseif reason=='journal' then
  JournalFixture.rejectState=3;actor.mounted=nil;actor.pos.x=1800;n:Tick(.25)
 else actor.attached=false;v:Advance(8) end
 assert(r.wallet==0 and backend:GetCompletedCount()==0 and not backend:CompleteVIP(id),reason)
end
reset();actor,id=cyber();actor.attached=false;f:Advance(8)
assert(c:GetStage()==4 and r.wallet==0 and not backend:CompleteCyberpsycho(id,true))

-- Progress records actual completion even if payment must retry. Loading and
-- ending duty retain earned money, but cannot resurrect an in-flight claim.
reset();f.recordedScanners=4;r.paymentOK=false
token,actor,id=finishVIP()
assert(r.wallet==0 and backend:GetCompletedCount()==1 and backend:GetPendingPayments()==1)
assert(CareerNative:GetRecordedActivities()==5 and CareerNative:GetRankIndex()==1)
assert(f.recordedScanners==4 and DispatchRewardFixture.wallet==0)
local serial=backend.m_serial
backend:OnRestored(1,2500);n:OnRestored(1,2500)
assert(backend.m_serial==serial and backend:GetCompletedCount()==1 and backend:GetPendingPayments()==1)
r.paymentOK=true;f.duty=false;tick(1)
assert(r.wallet==2000 and backend:GetPendingPayments()==0)
assert(backend:CompleteVIP(id));tick(20);assert(r.wallet==2000 and #r.grants==1)

reset();local open=backend:Reserve('vip');assert(open>0)
backend:OnRestored(1,2500)
assert(not backend:CompleteVIP(open) and backend:GetCompletedCount()==0)
local fresh=backend:Reserve('vip');assert(fresh>open)
assert(not backend:CompleteCyberpsycho(fresh,true))
backend:Cancel(fresh,'cyberpsycho');assert(backend:CompleteVIP(fresh))
assert(r.wallet==2000 and not backend:CompleteCyberpsycho(fresh,true))
local cancelled=backend:Reserve('vip');backend:Cancel(cancelled,'vip')
assert(not backend:CompleteVIP(cancelled) and r.wallet==2000)

-- Queued completions can arrive in a different order from reserved IDs.
-- The paid prefix follows completion order and survives a load without scanning
-- or replaying previous grants.
reset();r.paymentOK=false
local one,two=backend:Reserve('vip'),backend:Reserve('cyberpsycho')
assert(backend:CompleteCyberpsycho(two,true) and backend:CompleteVIP(one))
assert(backend:GetPendingPayments()==2 and backend:GetCompletedCount()==2 and r.wallet==0)
backend:OnRestored(1,2500);r.paymentOK=true;tick(2)
assert(r.wallet==5500 and #r.grants==2 and r.grants[1].amount==3500 and r.grants[2].amount==2000)
assert(backend:GetPendingPayments()==0 and backend:GetCompletedVIP()==1 and backend:GetCompletedCyberpsychos()==1)
tick(10);assert(#r.grants==2)

-- An absent transaction system retries the completed record; UI receipt delay
-- is independent of money and pauses in menus, including after ending a shift.
reset();r.available=false;finishVIP()
assert(r.wallet==0 and backend:GetPendingPayments()==1)
r.available=true;tick(.25);assert(r.wallet==2000)
notifications={};f.paused=true;tick(20);assert(#notifications==0)
f.paused=false;tick(7.5);assert(#notifications==0)
tick(.5);assert(#notifications==1 and notifications[1]:find('VIP TRANSPORT PAID',1,true))
local grants=#r.grants;tick(20);assert(#r.grants==grants and #notifications==1)

-- Scanner and generated history are added exactly once. The separate €$500
-- scanner-dispatch record does not add a second career incident.
reset();f.recordedScanners=4;finishVIP()
f.playerPosition.x=0;actor=cyber();actor.unconscious=true;f:Advance(.75)
DispatchJournalNative.m_paidDispatches={n=3};DispatchJournalNative.m_pendingDispatchRewards={n=1}
assert(CareerNative:GetRecordedActivities()==6 and CareerNative:GetRecordedDispatches()==6)
assert(backend:GetCompletedCount()==2 and r.wallet==5500 and f.recordedScanners==4)
backend:OnRestored(1,2500)
assert(CareerNative:GetRecordedActivities()==6 and backend:GetCompletedCount()==2)
