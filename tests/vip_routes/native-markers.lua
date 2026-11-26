-- Exhaust the actual baked pairs through real translated native owners and the
-- production Lua matcher. The engine materializes pins only as a test boundary.
local Navigation=require('marker_navigation')
local routes=require('vip_route_catalog').routes
local function point(id) local p=Sites[id].position;return Vector4.new(p.x,p.y,p.z,1) end
local function tick(n) for _=1,n do Native:Tick(.25) end end
for _,route in ipairs(routes) do
    F:Reset(8);VIPNative.m_stage=0;F.materialize=true;Navigation.reset()
    local pickup,drop=point(route[1]),point(route[2])
    F.playerPoint=Vector4.new(pickup.X-700,pickup.Y,pickup.Z,1)
    local token=VIPNative:BeginDispatch(pickup,drop);assert(token>0)
    local before=F.manual
    local old=Navigation.place(F.patrol,pickup,'vip');tick(2)
    assert(Native.m_confirmed and Native.m_scope==8 and Native.m_site==route[1])
    assert(VIPNative.m_pickupSite==route[1] and F:OwnedActive()==1 and F.fallbackCreates==0)
    F.playerPoint=pickup
    local actor=F:Actor('Character.NCPDPatrol_VIP',pickup)
    assert(VIPNative:BindVIP(token,actor))
    local car=F:Car(pickup);F.mount[actor]=car;assert(VIPNative:ConfirmBoarded(token,car))
    local next=Navigation.place(F.patrol,drop,'vip');tick(2)
    assert(Native.m_confirmed and Native.m_scope==9 and Native.m_site==route[2])
    assert(VIPNative.m_deliverySite==route[2] and F:OwnedActive()==1 and F.fallbackCreates==0)
    Navigation.release(old);assert(Native:IsActive(next.value),'Old pickup handle removed delivery marker')
    car.point=drop;F.playerPoint=drop;actor.point=drop
    assert(VIPNative:BeginDropOff(token));F.mount[actor]=nil;VIPNative:Tick(.25);tick(2)
    assert(VIPNative:GetStage()==3 and F.paidVIP==1 and not Native:HasWork() and F:OwnedActive()==0)
    assert(F.manual==before and #F.deleted==0,'Baked route changed manual waypoint or unregistered native pin')
end
assert(#routes==360)
print('VIP baked/native integration: all 360 pairs activate the exact pickup and delivery site, complete once, remove only owned visibility and preserve the manual waypoint; no off-catalog fallback')
