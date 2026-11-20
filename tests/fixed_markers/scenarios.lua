local function tick(n) for _=1,n do Native:Tick(.25) end end
local function point(index) local p=Sites[index].position;return Vector4.new(p.x,p.y,p.z,1) end
local function request(site) local token=Native:Request(site,point(site));assert(token>0);tick(1);return token end
local function stop(token) Native:Stop(token or 0);tick(2);assert(not Native:HasWork()) end
local function path(base,site) return base..'_bank_'..site..'/location' end
-- Native node calls are not success by themselves. Default no-pin behavior.
F:Reset();local token=request(42);assert(not Native.m_confirmed)
tick(24);assert(Native.m_fallback and not Native.m_confirmed and F.fallbackCreates==1)
assert(ScannerNative.m_navigationSite==0 and F.entries[F.objective].state==2)
assert(Native.m_runtimePoint.X==0 and Native.m_questPoint.X==0 and Native.m_nativeID.value==0)
assert(F.manual==700 and F.story.path=='story');stop(token);assert(F.pins.n==0)
-- FIRST declared pin resolves the selected site, including non-first site42.
F:Reset();F.materialize=true;token=request(42)
assert(Native.m_confirmed and Native.m_pinCount==1 and Native.m_linked and F.fallbackCreates==0)
assert(Native.m_activeBankPins==1 and Native.m_otherBankPins==0 and Native.m_targetActive)
assert(ScannerNative.m_navigationSite==42 and F.entries[F.objective].state==1)
assert(F.entries[path(F.objective,42)].state==1,'map-pin journal state must stay inactive')
local firstHash=Native.m_hash
F.lookupKnown=false;tick(1);assert(not Native.m_confirmed)
F.lookupKnown=true;tick(1);assert(Native.m_confirmed)
F.linked=false;tick(1);assert(not Native.m_confirmed and Native.m_linkHash==0)
F.linked=true;tick(1);assert(Native.m_confirmed)
F.pins[0].active=false;tick(1);assert(not Native.m_confirmed)
F.pins[0].active=true;F.pins[0].point=Vector4.new(0,0,0,1);tick(1);assert(not Native.m_confirmed)
F.pins[0].point=point(42);tick(1);assert(Native.m_confirmed)
F:AddPin(firstHash);tick(1);assert(not Native.m_confirmed);stop(token)
-- Unexpected bank pins are detected and pruned, including a legacy r5 hash.
F:Reset(8);F.materialize=true;token=request(204)
local foreign=F:AddPin(123);foreign.data={otherMod=true};foreign.kind='visual'
local flood=F:AddPin(F.entries[path(F.objective,205)].hash)
local legacy=F:AddPin(PathHash(F.objective..'/bank_204'))
tick(1);assert(not Native.m_confirmed and Native.m_otherBankPins==2)
tick(4);assert(Native.m_confirmed and F.pins.n==2 and Native.m_pruned==2)
assert(F.pins[1]==foreign and F.manual==700)
F.failHide=true;F.failDelete=true;Native:Stop(token);tick(2);assert(Native:HasWork())
F.failHide=false;tick(2);assert(Native:HasWork())
F.failDelete=false;tick(2);assert(not Native:HasWork() and F.pins.n==1 and F.pins[0]==foreign)
-- Replacement waits for old registry removal; stale tokens cannot cancel it.
F:Reset();F.materialize=true;local old=request(42);F.failDelete=true
local nextToken=Native:Request(43,point(43));assert(nextToken~=old);tick(2)
assert(not Native.m_confirmed and F.entries[path(F.objective,43)].state==1)
Native:Stop(old);assert(Native:IsActive(nextToken))
F.failDelete=false;tick(2);assert(Native.m_confirmed and Native.m_site==43 and F.pins.n==1)
stop(nextToken)
-- Selection rejection rolls back the owner path and common objective, then
-- provides independent fallback. No paused mission, fake success or payment.
F:Reset();F.materialize=true;F.rejectPath=F.objective..'_bank_42'
token=request(42);tick(2);assert(Native.m_fallback and ScannerNative.m_navigationSite==0)
assert(F.entries[F.objective].state==2 and F.pins.n==1 and F.wallet==0);stop(token)
-- Off-catalog sites and lost fallback rendering have bounded retries.
F:Reset(8);token=Native:Request(0,Vector4.new(100,200,10,1));tick(2)
assert(Native.m_fallback and not Native.m_confirmed and F.fallbackCreates==1)
F.pins={n=0};tick(4);assert(F.fallbackCreates==1);tick(20);assert(F.fallbackCreates==2);stop(token)
F:Reset();F.failRegister=true;token=Native:Request(0,point(1));tick(20)
assert(F.fallbackCreates==1);tick(1);assert(F.fallbackCreates==2);stop(token)
-- Menus pause confirmation timeout; ending the quest/duty removes markers.
F:Reset();token=request(1);F.menu=true;tick(40);assert(not Native.m_fallback)
F.menu=false;F.duty=false;tick(2);assert(not Native:HasWork())
F:Reset();F.materialize=true;token=request(1);F.entries[ScannerNative:ObjectivePath()].state=3;tick(2)
assert(not Native:HasWork() and F.pins.n==0)
-- Loading forgets IDs/tokens and rediscovers only private hashes. Legacy pins
-- recreated later are also removed while idle. A foreign pin survives.
F:Reset();F.materialize=true;old=request(1);Native.m_nativeID={value=999999}
foreign=F:AddPin(123);foreign.kind='visual';foreign.data={otherMod=true}
Native:OnRestored(0,0);tick(2);assert(F.pins.n==1 and F.pins[0]==foreign and not Native:HasWork())
assert(not Native:IsActive(old));for _,id in ipairs(F.deleted) do assert(id~=999999) end
F:AddPin(PathHash(F.objective..'/bank_2'));tick(4);assert(F.pins.n==1)
-- Manual activation changes invalidate proof; later player story/waypoint
-- choices are respected through site switches and terminal cleanup.
F:Reset();F.materialize=true;F.changeManual=true;token=request(1)
assert(not Native.m_confirmed and F.manual==701);stop(token)
F:Reset();F.materialize=true;F.tracked=F.entries[F.objective];token=request(1)
assert(F.tracked==F.entries[ScannerNative:ObjectivePath()])
F.manual=800;F.tracked=F.story;nextToken=Native:Request(2,point(2));tick(2)
assert(Native.m_confirmed and F.manual==800 and F.tracked==F.story);stop(nextToken)
-- ACTUAL original owners: all six scanner briefings retain attendance,
-- success, exactly-once supplement and a reusable session after site selection.
for briefing=0,5 do
 F:Reset(briefing);ScannerNative.m_stage=0;F.materialize=true
 F.playerPoint=Vector4.new(point(42).X-700,point(42).Y,point(42).Z,1)
 local journalToken=ScannerNative:BeginDispatch(100+briefing,point(42),briefing);assert(journalToken>0)
 token=request(42);assert(Native.m_confirmed)
 local selected=ScannerNative:ObjectivePath();assert(F.tracked==F.entries[selected])
 F.playerPoint=point(42);ScannerNative:Tick(.25);assert(ScannerNative:GetStage()==2)
 F.completed=true;assert(ScannerNative:CompleteDispatch(journalToken))
 assert(F.entries[selected].state==3 and F.wallet==500 and ScannerNative:GetPaidDispatches()==1)
 assert(not ScannerNative:CompleteDispatch(journalToken));tick(2);assert(not Native:HasWork() and F.pins.n==0)
 assert(F.tracked==F.story)
 F.completed=false;F.playerPoint=Vector4.new(point(43).X-700,point(43).Y,point(43).Z,1)
 assert(ScannerNative:BeginDispatch(200+briefing,point(43),briefing)>0)
 token=request(43);assert(Native.m_confirmed);ScannerNative:CancelDispatch(0,'test');tick(2);assert(not Native:HasWork())
end
-- Actual timeout terminates the site objective, not the inactive common one.
F:Reset();ScannerNative.m_stage=0;F.materialize=true
F.playerPoint=Vector4.new(point(42).X-700,point(42).Y,point(42).Z,1)
local jt=ScannerNative:BeginDispatch(500,point(42));assert(jt>0);token=request(42)
ScannerNative.m_remaining=.1;ScannerNative:Tick(.25);tick(2)
assert(ScannerNative:GetStage()==4 and F.wallet==0 and not Native:HasWork())
-- Actual CP arrival/binding switches respond -> neutralize at the same site.
F:Reset(6);CyberNative.m_stage=0;F.materialize=true
F.playerPoint=Vector4.new(point(204).X-700,point(204).Y,point(204).Z,1)
jt=CyberNative:BeginDispatch(point(204));assert(jt>0);token=request(204)
local response=CyberNative:ResponsePath();local before=Native.m_hash
F.playerPoint=point(204);CyberNative:Tick(.25)
local target=F:Actor('Character.NCPDPatrol_Cyberpsycho',point(204));assert(CyberNative:BindTarget(jt,target))
tick(2);assert(Native.m_confirmed and Native.m_scope==7 and Native.m_hash~=before)
assert(F.entries[response].state==3 and F.pins.n==1)
target.down=true;for _=1,4 do CyberNative:Tick(.25) end;tick(2)
assert(CyberNative:GetStage()==3 and F.paidCyber==1 and F.nonlethal and not Native:HasWork() and F.pins.n==0)
-- Actual VIP pickup, bind, driver/boarding, delivery and terminal reward.
F:Reset(8);VIPNative.m_stage=0;F.materialize=true
local pickup=point(204);local destination=point(205)
F.playerPoint=Vector4.new(pickup.X-700,pickup.Y,pickup.Z,1)
jt=VIPNative:BeginDispatch(pickup,destination);assert(jt>0);old=request(204)
local pickupPath=VIPNative:ResponsePath();before=Native.m_hash
F.playerPoint=pickup;target=F:Actor('Character.NCPDPatrol_VIP',pickup);assert(VIPNative:BindVIP(jt,target))
local car=F:Car(pickup);F.mount[target]=car;assert(VIPNative:ConfirmBoarded(jt,car))
-- Delivery uses its independently selected immutable terminal location.
nextToken=Native:Request(205,destination);tick(2)
assert(Native.m_confirmed and Native.m_scope==9 and Native.m_hash~=before and F.pins.n==1)
assert(F.entries[pickupPath].state==3 and VIPNative.m_pickupSite==204 and VIPNative.m_deliverySite==205)
Native:Stop(old);assert(Native:IsActive(nextToken))
car.point=destination;F.playerPoint=destination;target.point=destination
assert(VIPNative:BeginDropOff(jt));F.mount[target]=nil;VIPNative:Tick(.25);tick(2)
assert(VIPNative:GetStage()==3 and F.paidVIP==1 and not Native:HasWork() and F.pins.n==0 and F.tracked==F.story)
-- Lua adapter owner tokens and legacy-unavailable-bank compatibility boundary.
local Navigation=require('marker_navigation')
F:Reset();Navigation.reset();F.materialize=true
local scanner=Navigation.place(F.patrol,point(42),'scanner');Navigation.update(.25)
assert(scanner.fixedMarker and Native.m_confirmed)
Navigation.clear('cyberpsycho');assert(Native:IsActive(scanner.value))
F:Scope(8);local vip=Navigation.place(F.patrol,point(204),'vip');Navigation.update(.25)
Navigation.clear('scanner');Navigation.release(scanner);assert(Native:IsActive(vip.value))
assert(Navigation.describe(vip,'old')=='Native quest marker confirmed')
Navigation.release(vip);Navigation.update(.25);assert(not Native:HasWork())
F:Scope(0);local unmapped=Navigation.place(F.patrol,Vector4.new(9999,9999,50,1),'scanner');Navigation.update(.25)
assert(Native.m_site==0 and Native.m_fallback and not Native.m_confirmed)
Navigation.clear('scanner');Navigation.update(.25)
F.nativeMissing=true;local legacy=Navigation.place(F.patrol,point(1),'scanner')
assert(not Navigation.isBank(legacy) and legacy.value==999 and F.legacyPoint)
