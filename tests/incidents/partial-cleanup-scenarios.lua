-- Completed escort with one pending vehicle ID per car, as in the game log.
-- Exercise real dispatch/escort/convoy code; only attachment/deletion is mocked.
local f,v=CyberFixture,VIPFixture
local D,VIP,A=require('dispatch'),require('vip'),require('vip_ambush')
local function log(text) f.logs[#f.logs+1]=text end
local function update(seconds)
 for _=1,math.floor(seconds*4+.001) do D.update(.25,f.duty,log,function() return f.patrol end) end
end
local create,delete=v.entities.CreateEntity,v.entities.DeleteEntity
local held,requested,cars,crew={},{},{},{}
local attach,holdCrew=true,false
function v.entities:CreateEntity(spec)
 local id=create(self,spec)
 if spec.recordID=='Vehicle.NCPDPatrol_VIPAmbush' and id.hash~=0 then
  cars[#cars+1]=id.hash;held[id.hash]=true
  f.actors[id.hash].attached=attach
 elseif spec.recordID=='Character.NCPDPatrol_VIPAttacker' and id.hash~=0 then
  crew[#crew+1]=id.hash
  if holdCrew then held[id.hash]=true end
 end
 return id
end
function v.entities:DeleteEntity(id)
 if held[id.hash] then
  if requested[id.hash] then return false end
  requested[id.hash]=true;return true
 end
 return delete(self,id)
end
local function begin(visible,keepCrew,cancel)
 D.reset();v:Reset();held,requested,cars,crew={},{},{},{}
 attach,holdCrew=visible,keepCrew
 local pin=f:Place(950,0,0,'assault',true,2)
 function pin:GetJournalPathHash() return 9876 end
 f.scanners={pin};f.places[#f.places+1]=pin
 D.start(f.patrol,log);D.setAutomatic(false);assert(A.configure(3))
 assert(D.requestVIP(f.patrol,log));f.playerPosition.x=780;update(1)
 local witness=f.actors[1001];v:Drive();update(.25)
 v:Mount(witness,v.car);update(.5)
 assert(D.requestVIPAmbush(log));v.car.speed=16
 for _=1,60 do v.car.pos.x=v.car.pos.x+4;f.playerPosition.x=v.car.pos.x;update(.25) end
 update(15)
 assert(#cars==3 and #crew==(visible and 6 or 0),table.concat(f.logs,'\n'))
 if cancel then
  assert(not D.cancel(f.patrol,log));update(21);return
 end
 v.car.speed=0;v.car.pos.x=1800;f.playerPosition.x=1800;update(.5)
 witness.mounted=nil;witness.pos.x=1800;update(.5)
 assert(VIPNative:GetStage()==3 and IncidentRewardFixture.wallet==2000)
 update(21)
end

for _,visible in ipairs({false,true}) do
 local random=math.random
 math.random=function(a,b)
  if a==1 and b==100 then return 1 end
  if a==60 and b==120 then return 120 end
  return random(a,b)
 end
 begin(visible,false)
 assert(not VIP.isActive(),'three pending car IDs still reserve completed VIP dispatch')
 assert(A.retainedCount()==1 and VIP.hasCleanup(),'one convoy was split or IDs were lost')
 for _,id in ipairs(cars) do assert(f.managed[id] and requested[id]) end
 for _,id in ipairs(crew) do assert(not f.managed[id]) end
 if not visible then assert(A.state():find('ever attached=false',1,true)) end
 assert(A.state():find('vehicles=1',1,true) and A.state():find('NPCs=0',1,true))
 D.setAutomatic(true);update(121)
 assert(DispatchJournalNative:GetStage()==1 and D.isActive() and not VIP.isActive())
 local marker=f.markers[1];D.setAutomatic(false)
 f.playerPosition.x=950;v.car.pos.x=950;update(181)
 assert(DispatchJournalNative:GetStage()==2,'next scanner did not remain on scene')
 assert(f.markers[1]==marker and IncidentRewardFixture.wallet==2000 and D.completed()==1)
 D.cancel(f.patrol,log)
 assert(D.requestVIP(f.patrol,log),'passive cars blocked a subsequent VIP')
 local token=VIPNative:GetToken();marker=f.markers[1]
 for _,id in ipairs(cars) do held[id]=nil;f.managed[id]=nil;f.actors[id]=nil end
 update(3)
 assert(VIPNative:GetToken()==token and VIPNative:GetStage()==1 and f.markers[1]==marker)
 assert(not VIP.hasCleanup());D.cancel(f.patrol,log)
 math.random=random
end

-- Successful delivery permits known pending NPC cleanup in the bounded queue,
-- even when the game has not detached them. Every ID is retained and retried.
begin(true,true);update(121)
assert(not VIP.isActive() and A.retainedCount()==1 and A.state():find('NPCs=2',1,true))
for _,id in ipairs(cars) do assert(f.managed[id]);held[id]=nil;f.managed[id]=nil;f.actors[id]=nil end
for _,id in ipairs(crew) do assert(f.managed[id]);held[id]=nil;f.managed[id]=nil;f.actors[id]=nil end
update(3);assert(not VIP.hasCleanup())

-- During cancellation, a remaining live/streamed-out NPC is not an empty
-- vehicle. Late car eligibility still joins the same scene, not another slot.
begin(true,true,true);update(121)
assert(VIP.isActive() and A.retainedCount()==0)
local last=crew[1]
for _,id in ipairs(crew) do if id~=last then held[id]=nil;f.managed[id]=nil;f.actors[id]=nil end end
f.actors[last].attached=false;update(3)
assert(VIP.isActive() and A.retainedCount()==1,'unknown NPC absence was treated as cleanup')
assert(A.state():find('NPCs=1',1,true))
held[last]=nil;f.managed[last]=nil;f.actors[last]=nil;update(3)
assert(not VIP.isActive() and A.retainedCount()==1,'late passive car did not join its existing scene')
for _,id in ipairs(cars) do held[id]=nil;f.managed[id]=nil;f.actors[id]=nil end
update(3);assert(not VIP.hasCleanup() and f.managed[990]=='ambient')
v.entities.CreateEntity,v.entities.DeleteEntity=create,delete
