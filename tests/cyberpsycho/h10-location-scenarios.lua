local f,c=CyberFixture,CyberNative
local Cyber=require('cyberpsycho')
local function status(text) f:Status(text) end
local function fresh() f:Reset();Cyber.reset() end
local function request() assert(Cyber.request(f.patrol,status,true,false),Cyber.state()) end
-- H10's indoor atrium is not a generated incident location. Preserve the
-- street-level point below it; names/localization and marker bank IDs are unused.
local LocationPolicy=require('dispatch_location_policy')
local atrium={x=-1396.31165,y=1277.96313,z=123.076935}
local atriumPin=f:Place(atrium.x,atrium.y,atrium.z)
assert(not LocationPolicy.allowed(atriumPin,atrium,true))
assert(LocationPolicy.allowed(atriumPin,{x=atrium.x,y=atrium.y,z=20},true))
local identified=f:Place(800)
function identified:GetPointData() return {GetPointRecord=function() return 'FastTravelPoints.wat_lch_dataterm_10' end} end
assert(not LocationPolicy.allowed(identified,{x=800,y=0,z=0},true))
fresh();f.places={atriumPin}
assert(not Cyber.request(f.patrol,status) and #f.creates==0 and not Cyber.isActive())
fresh();f.places={identified}
assert(not Cyber.request(f.patrol,status) and #f.creates==0)
fresh();f.places={atriumPin,f:Place(800)};request()
assert(c:GetTargetPosition().x==800);Cyber.cancel(f.patrol,status)
fresh();f.places={f:Place(atrium.x,atrium.y,20)};request()
assert(c:GetTargetPosition().z==20);Cyber.cancel(f.patrol,status)
