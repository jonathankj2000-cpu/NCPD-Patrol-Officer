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
F.failActivate=true;F.pins[0].active=false;tick(1);assert(not Native.m_confirmed)
F.failActivate=false
F.pins[0].active=true;F.pins[0].point=Vector4.new(0,0,0,1);tick(1);assert(not Native.m_confirmed)
F.pins[0].point=point(42);tick(1);assert(Native.m_confirmed)
F:AddPin(firstHash);tick(1);assert(not Native.m_confirmed);stop(token)
-- Unexpected bank pins are detected and pruned, including a legacy r5 hash.
F:Reset(8);F.materialize=true;token=request(204)
local foreign=F:AddPin(123);foreign.data={otherMod=true};foreign.kind='visual'
local flood=F:AddPin(F.entries[path(F.objective,205)].hash)
local legacy=F:AddPin(PathHash(F.objective..'/bank_204'))
tick(1);assert(not Native.m_confirmed and Native.m_otherBankPins==2)
tick(4);assert(Native.m_confirmed and F.pins.n==4 and Native.m_pruned==2 and F:OwnedActive()==1)
assert(F.pins[1]==foreign and F.manual==700)
F.failHide=true;F.failDelete=true;Native:Stop(token);tick(2);assert(Native:HasWork())
F.failHide=false;tick(2);assert(not Native:HasWork() and F:OwnedActive()==0)
F.failDelete=false;assert(F.pins.n==4 and F.pins[1]==foreign and #F.deleted==0)
-- Replacement waits for old registry removal; stale tokens cannot cancel it.
F:Reset();F.materialize=true;local old=request(42);F.failHide=true
local nextToken=Native:Request(43,point(43));assert(nextToken~=old);tick(2)
assert(not Native.m_confirmed and F.entries[path(F.objective,43)].state==1)
Native:Stop(old);assert(Native:IsActive(nextToken))
F.failHide=false;tick(2);assert(Native.m_confirmed and Native.m_site==43 and F:OwnedActive()==1)
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
assert(not Native:HasWork() and F:OwnedActive()==0)
-- Loading forgets IDs/tokens and rediscovers only private hashes. Legacy pins
-- recreated later are also removed while idle. A foreign pin survives.
F:Reset();F.materialize=true;old=request(1);Native.m_nativeID={value=999999}
foreign=F:AddPin(123);foreign.kind='visual';foreign.data={otherMod=true}
Native:OnRestored(0,0);tick(40);assert(F.pins.n==2 and F.pins[1]==foreign and F:OwnedActive()==0 and not Native:HasWork())
assert(not Native:IsActive(old));for _,id in ipairs(F.deleted) do assert(id~=999999) end
F:AddPin(PathHash(F.objective..'/bank_2'));tick(4);assert(F:OwnedActive()==0 and F.pins.n==3)
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
 assert(not ScannerNative:CompleteDispatch(journalToken));tick(2);assert(not Native:HasWork() and F:OwnedActive()==0)
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
assert(F.entries[response].state==3 and F:OwnedActive()==1)
target.down=true;for _=1,4 do CyberNative:Tick(.25) end;tick(2)
assert(CyberNative:GetStage()==3 and F.paidCyber==1 and F.nonlethal and not Native:HasWork() and F:OwnedActive()==0)
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
assert(Native.m_confirmed and Native.m_scope==9 and Native.m_hash~=before and F:OwnedActive()==1)
assert(F.entries[pickupPath].state==3 and VIPNative.m_pickupSite==204 and VIPNative.m_deliverySite==205)
Native:Stop(old);assert(Native:IsActive(nextToken))
car.point=destination;F.playerPoint=destination;target.point=destination
assert(VIPNative:BeginDropOff(jt));F.mount[target]=nil;VIPNative:Tick(.25);tick(2)
assert(VIPNative:GetStage()==3 and F.paidVIP==1 and not Native:HasWork() and F:OwnedActive()==0 and F.tracked==F.story)
-- Engine cache variant: all site definitions may already have an inactive
-- native instance. Registration is not visibility. Loading, switching, reuse
-- and terminal cleanup must never unregister any of these engine-owned IDs.
F:Reset()
for _,d in ipairs(Definitions) do F:AddPin(F.entries[d.path].hash).active=false end
Native:OnRestored(0,0);tick(40)
assert(F.pins.n==1556 and #F.deleted==0 and F:OwnedActive()==0)
F.materialize=true;token=request(42);local stableID=Native.m_nativeID.value
assert(Native.m_confirmed and Native.m_registeredBankPins==1556 and Native.m_activeBankPins==1)
stop(token);assert(F.pins.n==1556 and F:OwnedActive()==0 and #F.deleted==0)
token=request(42);assert(Native.m_confirmed and Native.m_nativeID.value==stableID)
stop(token);assert(F.pins.n==1556 and #F.deleted==0)
-- Manager no-op with one exact cached instance: one guarded native re-enable.
F:Reset();local cached=F:AddPin(F.entries[path(F.objective,42)].hash);cached.active=false
token=request(42);assert(Native.m_confirmed and Native.m_cachedActivations==1 and F.activationWrites==1)
tick(40);assert(Native.m_cachedActivations==1 and F.pins.n==1);stop(token)
-- No repair may activate a wrong-position cached native pin or duplicates.
F:Reset();cached=F:AddPin(F.entries[path(F.objective,42)].hash,Vector4.new(0,0,0,1));cached.active=false
token=request(42);tick(24)
assert(Native.m_fallback and Native.m_cachedActivations==0 and not cached.active)
assert(Native:GetLastNativeProbe():find('registered matches=1',1,true))
assert(Native:GetLastNativeProbe():find('resolve_bank_42',1,true))
assert(Native.m_fallbackRegistered and Native.m_fallbackActive and Native.m_fallbackPositionOK)
stop(token)
-- A physically valid native marker is retained beyond five seconds when a
-- journal lookup or objective association is missing. It is NOT confirmed.
for _,mode in ipairs({'lookupKnown','linked'}) do
 F:Reset();F.materialize=true;F[mode]=false;token=request(70);local id=Native.m_nativeID.value
 tick(100);assert(Native.m_retained and not Native.m_confirmed and not Native.m_fallback and F.fallbackCreates==0)
 assert(F:OwnedActive()==1 and Native.m_nativeID.value==id and #F.deleted==0)
 assert(Native:GetLastNativeProbe():find('full journal proof missing',1,true))
 F[mode]=true;tick(1);assert(Native.m_confirmed);stop(token)
end
-- Snapshot survives fallback/cleanup. Registration failure is reported as
-- pending, never as a visible successful fallback. Retry remains bounded.
F:Reset();F.failRegister=true;token=request(42);tick(24)
assert(Native.m_fallback and not Native.m_fallbackRegistered and not Native.m_fallbackActive)
assert(Native:GetStatus()=='Fallback registration pending')
local snapshot=Native:GetLastNativeProbe();assert(snapshot:find('five active seconds',1,true))
assert(snapshot:find('resolve_bank_42',1,true));assert(Native.m_runtimePoint.X==0)
stop(token);assert(Native:GetLastNativeProbe()==snapshot)
-- An inactive tagged fallback is re-enabled without another registration.
F:Reset();token=Native:Request(0,point(42));tick(2);assert(F.fallbackCreates==1)
F.pins[0].active=false;tick(24);assert(F.fallbackCreates==1 and Native.m_fallbackActive);stop(token)
-- Refused deletion of OUR script-created fallback still blocks replacement.
F:Reset();token=Native:Request(0,point(42));tick(2);F.failDelete=true
Native:Stop(token);tick(2);assert(Native:HasWork())
F.failDelete=false;tick(2);assert(not Native:HasWork() and F.pins.n==0)
-- Load/unload can leave a non-null but DETACHED player and old registries.
-- No node/journal/marker mutation is permitted, including pending restore.
F:Reset();F.materialize=true;token=request(42)
F.attached=false;Native:OnRestored(0,0)
local writes,nodes,deletes,activations=#F.writes,#F.nodes,#F.deleted,F.activationWrites
local activeCount=F:OwnedActive();tick(40)
assert(#F.writes==writes and #F.nodes==nodes and #F.deleted==deletes and F.activationWrites==activations)
assert(Native.m_restorePending and F:OwnedActive()==activeCount)
F.attached=true;tick(40);assert(not Native.m_restorePending and F:OwnedActive()==0)
-- Reproduce the reported r5b state: /location entries are unavailable during
-- restore, then appear before assignment. The selected pin is valid and its
-- catalogue membership must not depend on those earlier journal reads.
for _,scope in ipairs({0,1,2,3,4,5,6,8}) do
 F:Reset(scope);F.hideSitePins=true;Native:OnRestored(0,0);tick(40)
 assert(ArraySize(Native.m_ownHashes)==3112)
 F.hideSitePins=false;F.materialize=true
 local site=scope<6 and 40 or 204
 token=request(site);tick(40)
 assert(Native.m_confirmed and Native.m_pinCount==1 and Native.m_activeBankPins==1)
 assert(Native.m_registeredBankPins==1 and not Native.m_fallback and F.fallbackCreates==0)
 stop(token)
end
-- Restored catalogue damage gets one repair; direct ownership still retains
-- the selected private pin if catalogue checking is deliberately sabotaged.
F:Reset(3);F.materialize=true;token=request(40)
ArrayClear(Native.m_ownHashes);ArrayClear(Native.m_ownPaths);tick(1)
assert(Native.m_confirmed and ArraySize(Native.m_ownHashes)==3112)
Native.m_catalogRepairTried=true;ArrayClear(Native.m_ownHashes);ArrayClear(Native.m_ownPaths)
tick(40);assert(Native.m_retained and not Native.m_confirmed and not Native.m_fallback and F:OwnedActive()==1)
stop(token)
-- A runtime hash alias from the exact private entry may retain that selected
-- pin, but is not full catalogue proof. Foreign identities are not adopted.
F:Reset(3);F.materialize=true
local selected=F.entries[path(F.objective,40)];selected.hash=123456789;F.hashes[selected.hash]=selected
token=request(40);tick(40)
assert(Native.m_retained and not Native.m_confirmed and not Native.m_fallback and Native.m_activeBankPins==1)
assert(Native.m_registeredMatches==1 and F:OwnedActive()==1);stop(token)
-- Session/Ready is stronger than attachment. BeforeEnd closes the gate while
-- player and managers still exist; no cleanup/world lookup runs until ready.
F:Reset();F.materialize=true;token=request(42)
F:Emit('Session/BeforeEnd');local rw,rn,rd=#F.writes,#F.nodes,#F.deleted
local cursor=Native.m_restoreCursor;tick(40)
assert(not SessionNative:IsReady() and F.attached)
assert(#F.writes==rw and #F.nodes==rn and #F.deleted==rd and Native.m_restoreCursor==cursor)
F:Emit('Session/BeforeStart');Native:OnRestored(0,0);tick(20)
assert(Native.m_restoreCursor==0 and Native.m_restorePending)
F:Emit('Session/Ready');local reads=F.entryReads;tick(1)
assert(Native.m_restoreCursor==48 and F.entryReads-reads<=240)
tick(40);assert(not Native.m_restorePending and F:OwnedActive()==0)
-- Duplicate Ready notifications must not invalidate a current assignment.
F:Reset();F.materialize=true;token=request(42);local generation=SessionNative:GetGeneration()
F:Emit('Session/Ready');tick(2);assert(SessionNative:GetGeneration()==generation and Native:IsActive(token) and Native.m_confirmed)
stop(token)
-- Session callback registration is idempotent and sticky across world changes.
SessionNative:OnInitialize()
for _,name in ipairs({'Session/BeforeStart','Session/BeforeEnd','Session/End','Session/Ready'}) do assert(#F.callbacks[name]==1) end
F:Emit('Session/Ready')
-- Async fallback registration status must follow new observations instead of
-- remaining 'pending' once the instance is available and active.
F:Reset();F.failRegister=true;token=Native:Request(0,point(42));tick(2)
assert(Native:GetStatus()=='Fallback registration pending')
local late=F:AddPin(0,point(42));late.kind='visual';late.data=NewFixedData();Native.m_fallbackID=late:GetNewMappinID()
tick(1);assert(Native:GetStatus()=='Independent quest-style fallback' and Native.m_fallbackRegistered)
stop(token)
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

-- Adapter readiness checks use only the service container during loading.
F:Reset();Navigation.reset();F:Emit('Session/BeforeEnd')
local prior=Game.GetScriptableSystemsContainer
Game.GetScriptableSystemsContainer=function() error('World container queried while session unavailable') end
assert(not Navigation.worldReady());Navigation.update(.25);Navigation.finish();Navigation.diagnostics();Navigation.lastNative()
assert(not pcall(Navigation.place,F.patrol,point(40),'scanner'))
Game.GetScriptableSystemsContainer=prior
F:Emit('Session/BeforeStart');F:Emit('Session/Ready');tick(40)
