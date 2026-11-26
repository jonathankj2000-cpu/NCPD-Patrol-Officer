-- Actual placement coordinator/selector with only engine queries mocked.
local scene=require('officer_down')
local site=require('officer_down_scene')
local f,n=F,OfficerNative
local hud={set=function() end}
local function status(text) f.lastStatus=text end
local function step(seconds)
 for _=1,math.floor(seconds*4+.001) do scene.update(.25,f.duty,f.patrol,status,hud) end
end
local function reset()
 scene.reset();f:Reset()
 while scene.heading()~=0 do assert(scene.rotate()) end
end
local function request(distance)
 assert(scene.request(f.patrol,status))
 f.playerPoint=f:Point(-distance,0)
end
local function policeHeading(p)
 local dx,dy=p.x-site.x,p.y-site.y
 if math.abs(dx)<.001 and math.abs(dy+6)<.001 then return 0 end
 if math.abs(dx-6)<.001 and math.abs(dy)<.001 then return 90 end
 if math.abs(dx)<.001 and math.abs(dy-6)<.001 then return 180 end
 if math.abs(dx+6)<.001 and math.abs(dy)<.001 then return 270 end
end
local function tried()
 local result={}
 for _,p in ipairs(f.groundProbes) do
  local angle=policeHeading(p);if angle then result[#result+1]=tostring(angle) end
 end
 return table.concat(result,',')
end
local function selected(angle)
 assert(#f.creates==10 and n:GetStage()==1)
 assert(scene.diagnostics():find('heading='..angle..' | preferred heading=',1,true),scene.diagnostics())
 for _,row in ipairs(f.creates) do assert(row.position.__vector=='Vector4') end
 assert(scene.cancel(f.patrol,status) and not scene.isActive() and f.managed[999])
end

-- No supported police position at zero degrees; continue without failing quest.
reset();f.noGroundAt=function(p) return policeHeading(p)==0 end
request(240);step(.25)
assert(tried()=='0,90',tried());selected(90)
assert(scene.heading()==0,'An automatic selection changed the preferred next heading')

-- Distinguish a traffic car from missing Static ground and select another layout.
reset();f.noGroundAt=function(p) return policeHeading(p)==0 end
f.vehicleAt=function(p) return policeHeading(p)==90 end
request(240);step(.25)
assert(tried()=='0,90,180',tried())
assert(#f.overlapQueries==11,'Expected one occupied orientation plus ten clear spawn boxes')
local cars,npcs=0,0
for _,q in ipairs(f.overlapQueries) do
 if q.box.x==1.05 then cars=cars+1;assert(q.box.y==2.5 and q.box.z==.75)
 else npcs=npcs+1;assert(q.box.x==.4 and q.box.y==.4 and q.box.z==.8) end
end
assert(cars==4 and npcs==7);selected(180)

-- Even an obstruction at the very last NPC rejects the complete layout before
-- any entity exists; clearing that position permits exactly one later scene.
reset();f.noGroundAt=function(p) local h=policeHeading(p);return h~=nil and h~=0 end
f.vehicleAt=function(p) return math.abs(p.x-site.x-7)<.001 and math.abs(p.y-site.y-9.5)<.001 end
request(170);step(.25);assert(#f.creates==0 and #f.overlapQueries==10 and n:GetStage()==1)
assert(scene.diagnostics():find('Vehicle occupies enemy spawn',1,true))
f.vehicleAt=nil;step(1);selected(0)

reset();f.noGroundAt=function(p) local h=policeHeading(p);return h~=nil and h~=270 end
request(240);step(.25);assert(tried()=='0,90,180,270',tried());selected(270)

-- A manually chosen preferred heading remains available, with four unique tries.
reset();assert(scene.rotate())
f.noGroundAt=function(p) local h=policeHeading(p);return h~=nil and h~=0 end
request(240);step(.25);assert(tried()=='90,180,270,0',tried());selected(0)

-- Earliest valid preparation is 250 m. Nothing is created/query-spammed outside.
reset();request(260);step(2);assert(#f.groundProbes==0 and #f.creates==0)
f.playerPoint=f:Point(-240,0);step(.25);selected(0)

-- Missing distant collision data can settle on approach; far failures do not
-- consume the nearby eight-second grace period or create partial scenes.
reset();f.noGround=true;request(240);step(12)
assert(n:GetStage()==1 and #f.creates==0 and #f.groundProbes<=52)
assert(scene.diagnostics():find('nearby wait=0.0/8 s',1,true))
f.noGround=false;f.playerPoint=f:Point(-170,0);step(1);selected(0)

-- Occupied traffic may move. Menus and an unready session pause the grace clock
-- and all placement work; only one accepted scene can create the ten actors.
reset();f.vehiclePresent=true;request(170);step(3)
assert(n:GetStage()==1 and #f.creates==0)
local queries=#f.overlapQueries;local before=scene.diagnostics():match('nearby wait=([^|]+)')
f.menu=true;step(10);assert(#f.overlapQueries==queries and scene.diagnostics():match('nearby wait=([^|]+)')==before)
f.menu=false;f.ready=false;step(3);assert(#f.overlapQueries==queries)
f.ready=true;f.vehiclePresent=false;step(1);selected(0)

-- Persistent blockage terminates after a bounded nearby wait with all four
-- reasons preserved, and never touches ambient vehicles or pays a reward.
reset();f.vehiclePresent=true;request(170);step(8)
assert(n:GetStage()==4 and not scene.isActive() and #f.creates==0 and f.wallet==0)
assert(#f.overlapQueries<=36 and f.lastStatus:find('All four scene rotations rejected',1,true),f.lastStatus)
for _,angle in ipairs({0,90,180,270}) do assert(f.lastStatus:find(angle..' deg: Vehicle occupies police spawn',1,true),f.lastStatus) end
assert(f.managed[999] and #f.deletes==0)

-- Unexpected engine/API errors are not swallowed as unsuitable rotations.
reset();f.overlapError=true;request(170);step(.25)
assert(n:GetStage()==4 and #f.overlapQueries==1 and #f.creates==0)
assert(f.lastStatus:find('Unexpected Overlap engine error',1,true))

-- No retry/reorientation after the first actor creation, even on partial failure.
reset();f.failCreateAt=5;f.deleteOK=false;request(170);step(.25)
assert(scene.isActive() and scene.hasCleanup() and #f.creates==5)
queries=#f.overlapQueries;step(4);assert(#f.overlapQueries==queries and #f.creates==5)
f.deleteOK=true;step(2);assert(not scene.isActive() and f.managed[999])

reset();f.vehiclePresent=true;request(170);step(1)
assert(scene.cancel(f.patrol,status) and #f.creates==0 and not scene.isActive())
reset()
