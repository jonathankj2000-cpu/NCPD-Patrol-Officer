-- Actual VIP/convoy controllers, including Codeware's asynchronous contract:
-- first DeleteEntity is accepted, then returns false until the despawn event.
local f,v=CyberFixture,VIPFixture
local D,VIP,A=require('dispatch'),require('vip'),require('vip_ambush')
local function log(text) f.logs[#f.logs+1]=text end
local function update(seconds)
 for _=1,math.floor(seconds*4+.001) do D.update(.25,f.duty,log,function() return f.patrol end) end
end
local held,requested={},{}
local function despawn(id)
 if f.actors[id] then f.actors[id].attached=false end
 held[id]=nil;f.managed[id]=nil;f.actors[id]=nil
end
local originalDelete=v.entities.DeleteEntity
function v.entities:DeleteEntity(id)
 if held[id.hash] then
  if requested[id.hash] then return false end
  requested[id.hash]=true;return true
 end
 return originalDelete(self,id)
end
local function reset()
 D.reset();v:Reset();held,requested={},{}
 local pin=f:Place(950,0,0,'assault',true,2)
 function pin:GetJournalPathHash() return 9191 end
 f.scanners={pin};f.places[#f.places+1]=pin
 D.start(f.patrol,log);D.setAutomatic(false)
end
local function request(count)
 v.player.mounted=nil;f.playerPosition.x=0;v.car.pos.x=800;v.car.speed=0
 assert(A.configure(count));assert(D.requestVIP(f.patrol,log))
end
local function deliver(count,neutralize,cancel)
 request(count);f.playerPosition.x=780;update(1)
 local witness=f.actors[1000+#f.creates]
 v:Drive();update(.25);v:Mount(witness,v.car);update(.5)
 assert(D.requestVIPAmbush(log));v.car.speed=16
 local first=#f.creates+1
 for _=1,60 do v.car.pos.x=v.car.pos.x+4;f.playerPosition.x=v.car.pos.x;update(.25) end
 update(1)
 assert(#f.creates-first+1==count*3,table.concat(f.logs,'\n'))
 local ids={}
 for index=first,#f.creates do
  local id=1000+index;held[id]=true;ids[#ids+1]=id
  local actor=f.actors[id];actor.pos.x=1780
  if actor.record=='Character.NCPDPatrol_VIPAttacker' then
   actor.dead=neutralize;actor.mounted=nil
  end
 end
 if cancel then
  assert(not D.cancel(f.patrol,log));update(21);return ids
 end
 v.car.speed=0;v.car.pos.x=1800;f.playerPosition.x=1800;update(.5)
 witness.mounted=nil;witness.pos.x=1800;update(.5)
 assert(VIPNative:GetStage()==3)
 update(21)
 return ids
end

-- A new VIP must not discard older IDs. Three convoy scenes are the bound,
-- even when a scene contains three cars/nine actors rather than one car.
reset()
local all={}
for index,count in ipairs({3,1,2}) do
 local ids=deliver(count,true);all[#all+1]=ids
 assert(not D.isActive() and VIP.hasCleanup() and A.retainedCount()==index)
 for _,scene in ipairs(all) do for _,id in ipairs(scene) do assert(f.managed[id]) end end
end
local creates,token=#f.creates,VIPNative:GetToken()
assert(not D.requestVIP(f.patrol,log) and #f.creates==creates and VIPNative:GetToken()==token)
assert(A.retainedCount()==3 and not D.isActive())
local random=math.random
math.random=function(a,b)
 if a==1 and b==100 then return 60 end
 if a==1 and b==70 then return 1 end
 return random(a,b)
end
assert(D.requestMixed(f.patrol,log),'full VIP scene queue blocked scanner fallback')
math.random=random
assert(DispatchJournalNative:GetStage()==1 and not VIP.isActive())
D.cancel(f.patrol,log)
assert(D.requestCyberpsycho(f.patrol,log),'full VIP scene queue blocked cyberpsycho')
D.cancel(f.patrol,log)
for _,scene in ipairs(all) do
 for _,id in ipairs(scene) do despawn(id) end
end
update(3);assert(not VIP.hasCleanup() and A.retainedCount()==0 and f.managed[990]=='ambient')
assert(IncidentRewardFixture.wallet==6000 and IncidentNative:GetCompletedVIP()==3)

-- Old scene cleanup cannot clear a new VIP's marker, token or journal stage.
reset();local ids=deliver(1,true);update(91)
request(1);local marker,token=f.markers[1],VIPNative:GetToken()
for _,id in ipairs(ids) do despawn(id) end
update(3)
assert(VIPNative:GetStage()==1 and VIPNative:GetToken()==token and f.markers[1]==marker)
assert(not VIP.hasCleanup() and D.isActive());D.cancel(f.patrol,log)

-- A completed delivery no longer has an ambush objective. Pending NPC deletion
-- is background cleanup too, without claiming those NPCs were neutralized.
reset();ids=deliver(1,false);update(125)
assert(not D.isActive() and not VIP.isActive() and A.retainedCount()==1)
for _,id in ipairs(ids) do despawn(id) end
update(3);assert(not VIP.hasCleanup())

-- A cancelled/failed escort with live NPCs retains its foreground guard.
reset();ids=deliver(1,false,true);update(125)
assert(D.isActive() and VIP.isActive() and A.retainedCount()==0)
for _,id in ipairs(ids) do despawn(id) end
update(3);assert(not D.isActive())

-- Shift end retries old bodies off duty; load/reset forgets old-world IDs
-- without issuing deletion against possibly reused IDs in the next world.
reset();ids=deliver(1,true);f.duty=false;D.finish(f.patrol,log);update(5)
assert(VIP.hasCleanup() and not D.isActive())
for _,id in ipairs(ids) do despawn(id) end
update(3);assert(not VIP.hasCleanup())
reset();deliver(1,true);local deletes=#f.deletes
D.reset();assert(not VIP.hasCleanup() and #f.deletes==deletes)
v.entities.DeleteEntity=originalDelete
