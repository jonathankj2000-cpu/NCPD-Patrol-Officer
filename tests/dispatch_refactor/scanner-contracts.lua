-- Scanner transitions and failure boundaries run through the unchanged public
-- facade in BOTH runtimes. Use real native journal/transaction code.
local D = require('dispatch')
local f,v = CyberFixture,VIPFixture
local rewardNotice = f.patrol.NotifyDispatchReward
function f.patrol:NotifyDispatchReward(amount)
    self:NotifyDispatch('DISPATCH BONUS PAID: +'..amount, 8)
end
local function log(text) f.logs[#f.logs+1]=text end
local function marker(hash,x)
    local pin=f:Place(x,0,0,'assault',true,2)
    function pin:GetJournalPathHash() return hash end
    return pin
end
local function setup(...)
    D.reset();v:Reset();notifications={}
    f.scanners={...};D.setAutomatic(false);D.start(f.patrol,log)
end
local function update(seconds)
    for _=1,math.floor(seconds*4+.001) do D.update(.25,f.duty,log,function() return f.patrol end) end
end
local function request() return D.request(f.patrol,log) end

-- The attendance condition owns the supplement. An earned transaction retries
-- off duty without counting another completion or replacing old save fields.
local pin=marker(701,800);setup(pin);assert(request())
f.playerPosition.x=800;update(1)
assert(DispatchJournalNative:GetStage()==2)
DispatchRewardFixture.paymentOK=false;pin.phase=gamedataMappinPhase.CompletedPhase;update(1)
assert(D.completed()==1 and D.failedCount()==0 and DispatchRewardFixture.wallet==0)
assert(DispatchJournalNative:GetPendingDispatchRewards()==1)
f.duty=false;D.finish(f.patrol,log)
DispatchRewardFixture.paymentOK=true;update(3)
assert(DispatchRewardFixture.wallet==500 and DispatchJournalNative:GetPaidDispatches()==1)
update(10);assert(DispatchRewardFixture.wallet==500)

pin=marker(702,800);setup(pin);assert(request())
pin.phase=gamedataMappinPhase.CompletedPhase;update(1)
assert(not D.isActive() and D.completed()==0 and DispatchRewardFixture.wallet==0)
assert(D.lastOutcome()=='CLOSED | Incident resolved before attendance')

pin=marker(703,800);setup(pin);assert(request());assert(D.armTimeoutTest(f.patrol,log))
update(16);assert(not D.isActive() and D.failedCount()==1)
update(5);assert(D.failedCount()==1 and DispatchRewardFixture.wallet==0)

pin=marker(704,800);setup(pin);JournalFixture.ready=false
assert(not request() and not D.isActive() and D.seconds()==30)
JournalFixture.ready=true;assert(request());assert(D.cancel(f.patrol,log))
assert(D.lastOutcome()=='CANCELLED | Assignment cancelled')

-- A thrown setup API failure stops dispatch until shift restart. Normal
-- resource unavailability above does not. Neither path can award payment.
pin=marker(705,800);setup(pin);f.markerOK=false
assert(not request() and not D.isActive())
f.markerOK=true;assert(not request())
assert(D.schedulerStatus(f.patrol):find('dispatch API error',1,true))
D.start(f.patrol,log);assert(request());D.cancel(f.patrol,log)

-- Native stage 6 keeps its original stop behavior without a duplicated failed
-- counter. The extracted scanner's local fault must reset with the shift.
pin=marker(706,800);setup(pin);assert(request())
JournalFixture.entries[DispatchJournalNative:QuestPath()].state=3;update(1)
assert(not D.isActive() and D.lastOutcome():find('JOURNAL ERROR',1,true))
assert(D.failedCount()==0 and not request())
D.start(f.patrol,log);assert(request());D.cancel(f.patrol,log)

-- Candidate deduplication, range tiers and invalid coordinates stay intact.
local near=marker(707,1000)
setup(marker(708,1450),near,near,marker(709,2001),marker(710,0),marker(711,0/0))
assert(request());assert(D.state():find('POI=707',1,true) and D.candidates()==3)
assert(D.cancel(f.patrol,log));assert(request())
assert(D.state():find('POI=708',1,true));D.cancel(f.patrol,log)
assert(not request() and D.seconds()==30)

-- Preserve the existing distinction: normal mixed calls reject combat/menu;
-- the focused scanner test can be requested manually while Busy/in combat.
pin=marker(712,800);setup(pin);D.setBusy(true);f.combat=true
assert(not D.requestMixed(f.patrol,log));assert(request() and D.isBusy())
f.combat=false;f.playerPosition.x=800;update(1)
pin.phase=gamedataMappinPhase.CompletedPhase;update(1)
assert(D.completed()==1 and D.isBusy() and DispatchRewardFixture.wallet==500)
D.finish(f.patrol,log);assert(not D.isBusy())

-- A world reset forgets the previous marker ID rather than unregistering it.
pin=marker(713,800);setup(pin);assert(request())
local removed=#v.unregistrations;local token=DispatchJournalNative:GetToken()
D.reset();assert(#v.unregistrations==removed and not D.isActive())
DispatchJournalNative:OnRestored(1,1);update(.25)
assert(not DispatchJournalNative:CompleteDispatch(token))
D.shutdown(f.patrol)
f.patrol.NotifyDispatchReward = rewardNotice
