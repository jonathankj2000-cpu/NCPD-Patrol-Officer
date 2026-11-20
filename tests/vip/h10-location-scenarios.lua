local f,v=CyberFixture,VIPFixture
local VIP=require('vip')
local function log(text) f:Status(text) end
local function reset() VIP.reset();v:Reset() end
-- Filtering the shared site pool must exclude H10 from BOTH ends of a trip.
reset()
local atrium=f:Place(-1396.31165,1277.96313,123.076935)
f.places={f:Place(800),atrium}
assert(not VIP.request(f.patrol,log,true,true) and #f.creates==0 and not VIP.isActive())
local locations=require('vip_locations').new()
f.places={f:Place(800),f:Place(1800),atrium}
for _=1,12 do
 local pair=locations.choose(Game.GetPlayer())
 assert(pair.pickup.x~=-1396.31165 and pair.drop.x~=-1396.31165)
end
-- An outdoor point below the same XY remains eligible.
f.places={f:Place(800),f:Place(-1396.31165,1277.96313,20)}
local pair=locations.choose(Game.GetPlayer())
assert(pair.pickup.z==20 or pair.drop.z==20)
