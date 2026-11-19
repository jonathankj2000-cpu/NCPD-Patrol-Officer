-- The extracted owners must isolate diagnostics/IDs and distinguish deleting a
-- current marker from forgetting an old-world handle. Real helper code runs.
local Waypoint,Locations=require('vip_waypoint'),require('vip_locations')
local f,v=CyberFixture,VIPFixture
local game,random=Game,math.random
Game=nil;math.random=function() error('read/reset consumed RNG') end
local emptyMarker,emptyLocations=Waypoint.new(),Locations.new()
emptyMarker.reset();emptyLocations.reset()
assert(emptyMarker.status()=='No active VIP waypoint')
assert(emptyLocations.diagnostics()=='Not selected')
assert(emptyMarker.diagnostics():find('waypoint ID=none',1,true))
Game,math.random=game,random
v:Reset()
local a,b=Waypoint.new(),Waypoint.new()
local function point(x) return Vector4.new(x,0,0,1) end
local function markerAt(x)
    for id,pin in pairs(v.pins) do if pin.point.x==x then return id,pin end end
    error('marker missing at '..x)
end
a.beginAssignment(f.patrol,point(800),'Pickup')
b.beginAssignment(f.patrol,point(1800),'Pickup')
local aID=markerAt(800);local bID=markerAt(1800)
a.rebuild(f.patrol,point(900),'Pickup')
assert(not v.pins[aID] and v.pins[bID])
assert(a.diagnostics():find('waypoint repairs=1',1,true))
assert(b.diagnostics():find('waypoint repairs=0',1,true))
a.place(f.patrol,point(2000),'Delivery')
assert(a.diagnostics():find('waypoint repairs=1',1,true),'stage transition reset repair diagnostics')
aID=markerAt(2000)
local getMap=Game.GetMappinSystem
Game.GetMappinSystem=function()
    local map=getMap()
    map.UnregisterMappin=function() error('fixture unregister failure') end
    return map
end
a.clear()
assert(v.pins[aID] and a.status():find('VIP marker removal pending',1,true))
local registrations=v.registrations
a.update(10,f.patrol,nil)
assert(v.registrations==registrations,'cleared target was silently restored after failed removal')
Game.GetMappinSystem=getMap
a.beginAssignment(f.patrol,point(1000),'Pickup')
assert(not v.pins[aID] and v.pins[bID])
assert(a.diagnostics():find('waypoint repairs=0',1,true))
-- Placement failure cannot acquire the sibling's marker; its owner still
-- explicitly clears the failed assignment, as vip.lua does.
f.markerOK=false
assert(not pcall(a.beginAssignment,f.patrol,point(1100),'Pickup'))
a.clear();f.markerOK=true
assert(v.pins[bID])
-- IDs can be reused by the next world. Reset/clear of the old owner must not
-- unregister the new owner's marker with the same numeric value.
v:Reset()
local c,d=Waypoint.new(),Waypoint.new()
c.beginAssignment(f.patrol,point(9000),'Pickup')
d.beginAssignment(f.patrol,point(10000),'Pickup')
local reused=markerAt(10000);assert(reused==bID)
local removes=#v.unregistrations
b.reset();b.clear();b.update(3,f.patrol,nil)
assert(v.pins[reused] and #v.unregistrations==removes)
c.clear();assert(v.pins[reused])
-- Location diagnostics belong to the choosing instance, including failure and
-- reset. Reading/resetting helpers may not affect actors or marker lifetime.
local first,second=Locations.new(),Locations.new()
f.places={f:Place(800),f:Place(1800)}
local pair=first.choose(Game.GetPlayer());assert(pair.pickup.x==800)
local before=first.diagnostics()
f.places={f:Place(3000),f:Place(4300)}
local other=second.choose(Game.GetPlayer());assert(other.pickup.x==3000)
assert(first.diagnostics()==before)
local secondInfo=second.diagnostics();registrations=v.registrations;removes=#v.unregistrations
math.random=function() error('read/reset consumed RNG') end
first.reset();assert(first.diagnostics()=='Not selected' and second.diagnostics()==secondInfo)
a.diagnostics();b.diagnostics();c.diagnostics();d.diagnostics()
math.random=random
f.places={};assert(not pcall(first.choose,Game.GetPlayer()))
assert(second.diagnostics()==secondInfo)
assert(v.registrations==registrations and #v.unregistrations==removes)
assert(#f.creates==0 and #f.deletes==0,'helper accessed actor ownership')
