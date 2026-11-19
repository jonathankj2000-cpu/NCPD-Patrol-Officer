local f,v=CyberFixture,VIPFixture
local D=require('dispatch')
local VIP,Cyber=require('vip'),require('cyberpsycho')
local random=math.random
local function log(text) f.logs[#f.logs+1]=text end
local function scanner()
 local pin=f:Place(950,0,0,'assault',true,2)
 pin.phase=2
 function pin:GetJournalPathHash() return 4242 end
 return pin
end
local function reset()
 D.reset();v:Reset();f.recordedScanners=0;notifications={}
 f.scanners={scanner()};f.places[#f.places+1]=f.scanners[1]
 D.setAutomatic(true);D.start(f.patrol,log)
end
local function selected()
 if VIP.isActive() then return 'VIP' end
 if Cyber.isActive() then return 'Cyberpsycho' end
 if D.isActive() then return 'Scanner' end
 return 'none'
end
local function rolls(values,fn)
 local index=1
 math.random=function(a,b)
  local expected=values[index]
  if expected and a==1 and b==expected[1] then index=index+1;return expected[2] end
  return random(a,b)
 end
 local ok,result=pcall(fn)
 math.random=random
 assert(ok,result)
 assert(index==#values+1,'weighted draw was not reached or used the wrong remaining weight')
 return result
end
local function update(seconds)
 for _=1,math.floor(seconds*4+.0001) do D.update(.25,f.duty,log,function() return f.patrol end) end
end

-- Every possible first draw executes the real chosen request/native journal.
-- No synthetic random sampler or stubbed request result defines these counts.
local counts={Scanner=0,VIP=0,Cyberpsycho=0}
for roll=1,100 do
 reset()
 assert(rolls({{100,roll}},function() return D.requestMixed(f.patrol,log) end),table.concat(f.logs,'\n'))
 local kind=selected();counts[kind]=counts[kind]+1
 assert(IncidentNative:GetCompletedCount()==0 and IncidentRewardFixture.wallet==0 and #f.creates==0)
 assert(D.cancel(f.patrol,log))
end
assert(counts.Scanner==50 and counts.VIP==30 and counts.Cyberpsycho==20)

-- A single terminal cannot produce a VIP route, but is a valid cyberpsycho
-- scene. Fallback reweights Scanner 50 / Cyberpsycho 20, rather than stopping.
reset();f.places={f:Place(800)}
assert(rolls({{100,60},{70,70}},function() return D.requestMixed(f.patrol,log) end))
assert(selected()=='Cyberpsycho' and VIPNative:GetStage()==0 and CyberNative:GetStage()==1)
assert(IncidentNative.m_openIds.n==1 and IncidentNative.m_openKinds[0]=='cyberpsycho')
D.cancel(f.patrol,log)

-- The inverse fallback keeps the expanded VIP geometry: no cyberpsycho scene
-- is within 2 km, while a valid protected-witness route exists farther out.
reset();f.places={f:Place(3000),f:Place(4200)}
assert(rolls({{100,90},{80,80}},function() return D.requestMixed(f.patrol,log) end))
assert(selected()=='VIP' and VIPNative:GetRemainingSeconds()==400 and CyberNative:GetStage()==0)
D.cancel(f.patrol,log)

-- A depleted scanner pool is ordinary unavailability, and does not poison
-- the dispatcher with its API-error flag or block another available type.
reset();f.scanners={}
assert(rolls({{100,25},{50,50}},function() return D.requestMixed(f.patrol,log) end))
assert(selected()=='Cyberpsycho');D.cancel(f.patrol,log)

-- Automatic dispatch must resume within its 120-second maximum after actual
-- VIP completion, including retained ambush bodies. Cleanup and standby time
-- run together; scene retention must not add another 90 seconds first.
local function delivered(retainScene)
 reset();D.setAutomatic(true)
 assert(require('vip_ambush').configure(1))
 assert(D.requestVIP(f.patrol,log));f.playerPosition.x=780;update(1)
 local witness=f.actors[1001];v:Drive();update(.25)
 v:Mount(witness,v.car);update(.5)
 if retainScene then
  assert(D.requestVIPAmbush(log));v.car.speed=16
  for _=1,40 do v.car.pos.x=v.car.pos.x+4;f.playerPosition.x=v.car.pos.x;update(.25) end
  update(1)
  assert(v.ambushCar and #f.creates==4)
  v.ambushCar.pos.x=1780
  for _,key in ipairs({1003,1004}) do
   f.actors[key].dead=true;f.actors[key].mounted=nil;f.actors[key].pos.x=1780
  end
 end
 v.car.speed=0;v.car.pos.x=1800;f.playerPosition.x=1800;update(.5)
 witness.mounted=nil;witness.pos.x=1800;update(.5)
 assert(VIPNative:GetStage()==3 and IncidentRewardFixture.wallet==2000)
 return witness
end
math.random=function(a,b)
 if a==60 and b==120 then return 120 end
 if a==1 and b==100 then return 1 end
 return random(a,b)
end
for _,retained in ipairs({false,true}) do
 delivered(retained)
 if retained then assert(D.vipAmbushState():find('retention remaining=',1,true)) end
 update(30)
 assert(D.seconds()<=91,'VIP cleanup adds to the automatic standby interval')
 update(91)
 assert(selected()=='Scanner','automatic calls did not resume after VIP delivery')
 assert(IncidentRewardFixture.wallet==2000 and D.completed()==1)
 local marker=f.markers[1];update(3)
 assert(f.markers[1]==marker and DispatchJournalNative:GetStage()==1,'old VIP cleanup altered the next call')
 D.cancel(f.patrol,log)
end

-- Match the reported failure: VIP gone, journal completed, old neutralized
-- ambush actors cannot be deleted. Those bodies must not reserve dispatch.
delivered(true)
local deleteEntity=v.entities.DeleteEntity
function v.entities:DeleteEntity(id)
 if id.hash>=1002 and id.hash<=1004 then return false end
 return deleteEntity(self,id)
end
update(121)
assert(not f.managed[1001] and VIPNative:GetStage()==3)
assert(selected()=='Scanner','completed VIP remains globally blocked by neutralized ambush cleanup')
assert(f.managed[1002] and f.managed[1003] and f.managed[1004],'refused scene IDs were forgotten')
assert(VIP.hasCleanup() and D.vipAmbushState():find('actor cleanup pending=',1,true))
D.cancel(f.patrol,log);D.setAutomatic(false);update(181)
assert(not D.isActive() and VIP.hasCleanup() and IncidentRewardFixture.wallet==2000)
v.entities.DeleteEntity=deleteEntity;update(3)
assert(not VIP.hasCleanup() and not f.managed[1002] and f.managed[990]=='ambient')

-- The new concurrent countdown retains Busy/menu/combat pauses. Each gate is
-- visible without having to infer it from a scanner journal with stage zero.
for _,gate in ipairs({'busy','menu','combat'}) do
 delivered(true);update(10);local seconds=D.seconds()
 if gate=='busy' then D.setBusy(true) elseif gate=='menu' then f.paused=true else f.combat=true end
 update(100)
 assert(D.seconds()==seconds,gate..' did not pause standby')
 assert(selected()==(gate=='menu' and 'VIP' or 'none'),'unexpected call while '..gate)
 local status=D.schedulerStatus(f.patrol)
 assert(status:find(gate=='busy' and 'BUSY' or gate=='menu' and 'menu' or 'combat',1,true),status)
 D.setBusy(false);f.paused=false;f.combat=false
 update(121);assert(selected()=='Scanner',gate..' did not resume after VIP completion')
 D.cancel(f.patrol,log)
end

-- An actually refused deletion remains a reservation even after the standby
-- interval expires. Once deletion succeeds, request the next call immediately
-- without another 60-120 second wait or a second completion/payment.
delivered(true);f.deleteOK=false
update(125)
assert(D.seconds()==0 and selected()=='VIP' and #f.creates==4)
assert(D.schedulerStatus(f.patrol):find('waiting for confirmed actor cleanup',1,true))
assert(D.vipAmbushState():find('actor cleanup pending=',1,true))
f.deleteOK=true;update(3)
assert(selected()=='Scanner' and #f.creates==4 and IncidentRewardFixture.wallet==2000 and D.completed()==1)
D.cancel(f.patrol,log)
math.random=random

-- The live dispatcher services the earned-reward queue and reports generated
-- outcomes/counts, including when the player ends duty after completing a call.
reset();D.setAutomatic(false);assert(D.requestVIP(f.patrol,log))
f.playerPosition.x=780;update(1)
local witness=f.actors[1001];v:Drive();update(.25)
v:Mount(witness,v.car);update(.5)
assert(VIPNative:GetStage()==2)
v.car.pos.x=1800;f.playerPosition.x=1800;update(.5)
witness.mounted=nil;witness.pos.x=1800;update(.5)
assert(VIPNative:GetStage()==3 and D.completed()==1 and IncidentRewardFixture.wallet==2000)
assert(D.lastOutcome():find('COMPLETED',1,true))
f.duty=false;D.finish(f.patrol,log);update(9)
local receipt=false
for _,message in ipairs(notifications) do if message:find('VIP TRANSPORT PAID',1,true) then receipt=true end end
assert(receipt and IncidentRewardFixture.wallet==2000)

reset();D.setAutomatic(false);assert(D.requestCyberpsycho(f.patrol,log))
update(181)
assert(D.failedCount()==1 and D.lastOutcome():find('FAILED',1,true))
update(10);assert(D.failedCount()==1,'generated failure counted twice')

-- All types can fail safely. Try each at most once and retry after 30 seconds.
reset();f.scanners={};f.places={}
assert(not rolls({{100,25},{50,1},{20,1}},function() return D.requestMixed(f.patrol,log) end))
assert(not D.isActive() and D.seconds()==30 and IncidentNative.m_openIds.n==0)
assert(IncidentNative:GetCompletedCount()==0 and IncidentRewardFixture.wallet==0)
local skipped=0
for _,line in ipairs(f.logs) do if line:find('unavailable; trying another type',1,true) then skipped=skipped+1 end end
assert(skipped==3)

-- Missing generated resources skip those types without entering cleanup or
-- hiding a usable scanner assignment. The scanner-only manual test still works.
reset();f.entityReady=false
assert(rolls({{100,60},{70,1}},function() return D.requestMixed(f.patrol,log) end))
assert(selected()=='Scanner');D.cancel(f.patrol,log)

-- Normal replacement uses the same mix as automatic dispatch, while the
-- separate explicit scanner request remains available for focused CET testing.
reset();assert(D.request(f.patrol,log) and selected()=='Scanner')
assert(rolls({{100,60}},function() return D.replace(f.patrol,log) end))
assert(selected()=='VIP' and DispatchJournalNative:GetStage()==5)
D.cancel(f.patrol,log)

-- Busy, menus and combat pause automatic selection. Once available again,
-- expiry really invokes the mixed selector rather than the old scanner path.
for _,gate in ipairs({'busy','menu','combat'}) do
 reset();local seconds=D.seconds()
 if gate=='busy' then D.setBusy(true) elseif gate=='menu' then f.paused=true else f.combat=true end
 update(80);assert(not D.isActive() and D.seconds()==seconds,gate)
 D.setBusy(false);f.paused=false;f.combat=false
 rolls({{100,60}},function() update(65) end)
 assert(selected()=='VIP' and VIPNative:GetStage()==1,gate)
 D.cancel(f.patrol,log)
end

-- A real attached actor whose deletion is rejected keeps the global slot.
-- Neither mixed requests nor replacement may draw/create a second assignment.
reset();assert(D.requestVIP(f.patrol,log));f.playerPosition.x=780;update(1)
assert(f.actors[1001] and f.managed[1001])
f.deleteOK=false;assert(not D.cancel(f.patrol,log) and D.isActive())
local draws=0
math.random=function(...) draws=draws+1;return random(...) end
assert(not D.requestMixed(f.patrol,log) and not D.replace(f.patrol,log))
math.random=random;assert(draws==0 and #f.creates==1)
f.deleteOK=true;update(2)
assert(not D.isActive() and not f.managed[1001] and f.managed[990]=='ambient')
assert(rolls({{100,90}},function() return D.requestMixed(f.patrol,log) end))
assert(selected()=='Cyberpsycho');D.cancel(f.patrol,log)
