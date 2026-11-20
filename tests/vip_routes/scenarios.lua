local f=RouteTest
local Locations=require('vip_locations')
local game,vector=Game,Vector4
Game,Vector4=nil,nil
local passive=Locations.new();passive.reset();assert(passive.diagnostics()=='Not selected')
Game,Vector4=game,vector
local Catalog,Routes=require('marker_catalog'),require('vip_route_catalog')
local Navigation=require('marker_navigation')
local byID,pairs={},{ }
for _,row in ipairs(Catalog) do byID[row[1]]=row end
for _,route in ipairs(Routes.routes) do
    assert(route[1]~=271 and route[2]~=271,'H10 Atrium in VIP routes')
    pairs['vip_'..route[1]..'_'..route[2]]=true
end
local function aligned(point,id)
    local row=byID[id]
    assert(row and row[2]==false and point.x==row[3] and point.y==row[4] and point.z==row[5], 'Endpoint position drifted from its native marker')
end
-- No discovered fast travel/drop points. The former reported off-catalog
-- pickup is ignored; both actual route endpoints resolve to nonzero bank IDs.
local locations=Locations.new()
f.point=Vector4.new(-976.574707,-1155.406494,11.359848,1)
for _=1,40 do
    local pair=locations.choose(f.player)
    assert(pairs[pair.routeID]);aligned(pair.pickup,pair.pickupSite);aligned(pair.drop,pair.deliverySite)
    assert(pair.distance>=250 and pair.distance<=5000)
    f.scope=8;Navigation.place({},pair.pickup,'vip')
    assert(f.requests[#f.requests].site==pair.pickupSite)
    f.scope=9;Navigation.place({},pair.drop,'vip')
    assert(f.requests[#f.requests].site==pair.deliverySite)
end
-- Many player positions, no live terminal pool or discovery dependency.
local successes=0
for x=-3000,1500,500 do for y=-3000,2500,500 do
    f.point=Vector4.new(x,y,10,1)
    local ok,pair=pcall(locations.choose,f.player)
    if ok then
        successes=successes+1;assert(pairs[pair.routeID])
        aligned(pair.pickup,pair.pickupSite);aligned(pair.drop,pair.deliverySite)
    end
end end
assert(successes>100)
-- Every baked endpoint is resolvable by the unchanged 2 m navigation matcher.
for _,id in ipairs(Routes.sites) do
    local r=byID[id];f.scope=8;Navigation.place({},Vector4.new(r[3],r[4],r[5],1),'vip')
    assert(f.requests[#f.requests].site==id)
end
local random=math.random
math.random=function(a) return a end
f.point=Vector4.new(0,0,10,1);locations.reset()
local seen={}
for _=1,13 do local pair=locations.choose(f.player);assert(not seen[pair.routeID],'Recent route repeated too soon');seen[pair.routeID]=true end
local reads=f.reads
math.random=function() error('read/reset consumed RNG') end
local other=Locations.new();local before=locations.diagnostics()
other.reset();assert(other.diagnostics()=='Not selected' and locations.diagnostics()==before and f.reads==reads)
locations.diagnostics();locations.reset();assert(locations.diagnostics()=='Not selected')
math.random=random
-- Caller mutations cannot move the canonical endpoint or later selections.
local pair=locations.choose(f.player);local id=pair.pickupSite;pair.pickup.x=99999
aligned(Vector4.new(byID[id][3],byID[id][4],byID[id][5],1),id)

-- Small canonical fixture isolates scanner radius, stage-independent endpoints,
-- fallback tiers, repetition exhaustion and instance-owned history.
package.loaded.marker_catalog={{133,false,800,0,0},{134,false,1800,0,0},{135,false,2800,0,0}}
package.loaded.vip_route_catalog={schema=1,recentSelections=12,sites={133,134,135},routes={{133,134},{133,135}}}
package.loaded.vip_locations=nil
local Small=require('vip_locations')
f.point=Vector4.new(0,0,0,1);math.random=function(a) return a end
f.pins={f:Pin(1910,0,0,'assault','active')}
local first,second=Small.new(),Small.new()
pair=first.choose(f.player);assert(pair.pickupSite==133 and pair.deliverySite==134,'Scanner exclusion exceeded the 100 m contract')
local secondBefore=second.diagnostics();assert(secondBefore=='Not selected')
pair=first.choose(f.player);assert(pair.deliverySite==135,'Recent route did not change')
assert(second.diagnostics()==secondBefore)
pair=second.choose(f.player);assert(pair.deliverySite==134,'History leaked between owners')
f.pins={f:Pin(1800,0,0,'assault','active')}
first.reset();pair=first.choose(f.player);assert(pair.deliverySite==135,'Blocked delivery selected')
f.pins={f:Pin(800,0,0,'outpost','active')}
assert(not pcall(first.choose,f.player),'Blocked pickup selected')
f.pins={f:Pin(800,0,0,'outpost','complete'),f:Pin(0/0,0,0,'assault','active')}
first.reset();pair=first.choose(f.player);assert(pair.deliverySite==134)
f.pins={}
for _=1,30 do assert(first.choose(f.player),'Small pool deadlocked after history filled') end
f.point=Vector4.new(90000,0,0,1);assert(not pcall(first.choose,f.player),'Distance caps bypassed')
f.point=Vector4.new(0/0,0,0,1);assert(not pcall(first.choose,f.player),'NaN player position accepted')
f.point=Vector4.new(0,0,0,1)
local map=Game.GetMappinSystem;Game.GetMappinSystem=function() return nil end
assert(not pcall(first.choose,f.player),'Missing scanner system failed open');Game.GetMappinSystem=map
math.random=random
return successes
