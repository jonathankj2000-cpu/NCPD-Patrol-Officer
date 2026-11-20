local function tick(n) for _=1,n do Native:Tick(.25) end end
local function point(index) local p=Sites[index].position;return Vector4.new(p.x,p.y,p.z,1) end
local function request(site) local token=Native:Request(site,point(site));assert(token>0);tick(1);return token end
local function stop(token) Native:Stop(token or 0);tick(2);assert(not Native:HasWork()) end
-- Native journal activation is not success by itself. Default no-pin behavior.
F:Reset();local token=request(1);assert(not Native.m_confirmed)
tick(24);assert(Native.m_fallback and not Native.m_confirmed and F.fallbackCreates==1)
assert(F.manual==700 and F.story.path=='story');stop(token);assert(F.pins.n==0)
-- Exact target, hash, ID, objective and both position reads establish proof.
F:Reset();F.materialize=true;token=request(1)
assert(Native.m_confirmed and Native.m_pinCount==1 and Native.m_linked and F.fallbackCreates==0)
local firstHash=Native.m_hash;assert(F.entries[F.objective..'/bank_1'].state==2)
F.lookupKnown=false;tick(1);assert(not Native.m_confirmed)
F.lookupKnown=true;tick(1);assert(Native.m_confirmed)
F.linked=false;tick(1);assert(not Native.m_confirmed)
F.linked=true;tick(1);assert(Native.m_confirmed)
F.pins[0].point=Vector4.new(0,0,0,1);tick(1);assert(not Native.m_confirmed)
F.pins[0].point=point(1);tick(1);assert(Native.m_confirmed)
F:AddPin(firstHash);tick(1);assert(not Native.m_confirmed);stop(token)
-- Native pin retained after Inactive is removed, without touching foreign data.
F:Reset();F.materialize=true;token=request(1)
local foreign=F:AddPin(F.entries[F.objective..'/bank_2'].hash);foreign.data={otherMod=true};foreign.kind='visual'
F.failHide=true;Native:Stop(token);tick(2);assert(Native:HasWork() and F.pins.n==2)
F.failHide=false;F.failDelete=true;tick(2);assert(Native:HasWork() and F.pins.n==2)
F.failDelete=false;tick(2);assert(not Native:HasWork() and F.pins.n==1 and F.pins[0]==foreign)
-- Replacement accepts a fresh token while old cleanup retries, then activates
-- only the new site. Stale releases cannot cancel the replacement.
F:Reset();F.materialize=true;local old=request(1);F.failDelete=true
local nextToken=Native:Request(2,point(2));assert(nextToken~=old);tick(2)
assert(not Native.m_confirmed and F.entries[F.objective..'/bank_2'].state==1)
Native:Stop(old);assert(Native:IsActive(nextToken))
F.failDelete=false;tick(2);assert(Native.m_confirmed and Native.m_site==2 and F.pins.n==1)
stop(nextToken)
-- CP arrival switches to another fixed journal child at the SAME position.
F:Reset(6);F.materialize=true;token=request(133);local before=Native.m_hash
F:Scope(7);tick(2);assert(Native.m_confirmed and Native.m_scope==7 and Native.m_hash~=before)
assert(F.pins.n==1 and F.entries['quests/minor_quest/ncpd_patrol_cyberpsycho/main/respond/bank_133'].state==1)
assert(Native.m_target.X==point(133).X);stop(token)
-- VIP pickup -> delivery uses separate pre-authored pins, no relocation calls.
F:Reset(8);F.materialize=true;old=request(133);before=Native.m_hash
F:Scope(9);nextToken=Native:Request(134,point(134));tick(2)
assert(Native.m_confirmed and Native.m_scope==9 and Native.m_hash~=before and Native.m_target.X==point(134).X)
Native:Stop(old);assert(Native:IsActive(nextToken));stop(nextToken)
-- Missing catalog sites still get an independent visible marker. No native
-- confirmation or fake journal association is inferred from that renderer.
F:Reset(8);token=Native:Request(0,Vector4.new(100,200,10,1));tick(2)
assert(Native.m_fallback and not Native.m_confirmed and F.fallbackCreates==1)
F.pins={n=0};tick(4);assert(F.fallbackCreates==1);tick(20);assert(F.fallbackCreates==2)
stop(token)
F:Reset();F.failRegister=true;token=Native:Request(0,point(1));tick(20)
assert(F.fallbackCreates==1);tick(1);assert(F.fallbackCreates==2);stop(token)
-- Menus pause timeout. Ending the quest or duty still removes its markers.
F:Reset();token=request(1);F.menu=true;tick(40);assert(not Native.m_fallback)
F.menu=false;F.duty=false;tick(2);assert(not Native:HasWork())
F:Reset();F.materialize=true;token=request(1);F.entries[F.objective].state=3;tick(2)
assert(not Native:HasWork() and F.pins.n==0)
-- Loading forgets IDs/tokens and rediscovers only our private journal leaves.
F:Reset();F.materialize=true;old=request(1);Native.m_nativeID={value=999999}
Native:OnRestored(0,0);tick(2);assert(F.pins.n==0 and not Native:HasWork())
assert(not Native:IsActive(old));for _,id in ipairs(F.deleted) do assert(id~=999999) end
-- Manual ID changes caused during activation prevent native success. Newer
-- player waypoint/story choices between operations are never overwritten.
F:Reset();F.materialize=true;F.changeManual=true;token=request(1)
assert(not Native.m_confirmed and F.manual==701);stop(token)
F:Reset();F.materialize=true;token=request(1);F.manual=800;F.story={path='newer-story'}
tick(4);assert(Native.m_confirmed and F.manual==800);stop(token);assert(F.story.path=='newer-story')
-- Actual Lua adapter: match immutable site coords, scoped owner release and
-- separate logical tokens (never engine IDs); legacy unavailable-bank boundary.
local Navigation=require('marker_navigation')
F:Reset();Navigation.reset();F.materialize=true
local scanner=Navigation.place(F.patrol,point(1),'scanner');Navigation.update(.25)
assert(scanner.fixedMarker and Native.m_confirmed)
Navigation.clear('cyberpsycho');assert(Native:IsActive(scanner.value))
F:Scope(8);local vip=Navigation.place(F.patrol,point(133),'vip');Navigation.update(.25)
Navigation.clear('scanner');Navigation.release(scanner);assert(Native:IsActive(vip.value))
assert(Navigation.describe(vip,'old')=='Native quest marker confirmed')
Navigation.release(vip);Navigation.update(.25);assert(not Native:HasWork())
F:Scope(0);local unmapped=Navigation.place(F.patrol,Vector4.new(9999,9999,50,1),'scanner');Navigation.update(.25)
assert(Native.m_site==0 and Native.m_fallback and not Native.m_confirmed)
Navigation.clear('scanner');Navigation.update(.25)
F.nativeMissing=true;local legacy=Navigation.place(F.patrol,point(1),'scanner')
assert(not Navigation.isBank(legacy) and legacy.value==999 and F.legacyPoint)
