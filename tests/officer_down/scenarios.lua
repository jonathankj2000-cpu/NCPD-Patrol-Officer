local Scene=require('officer_down')
local f,n=F,OfficerNative
local hud={set=function(text,visible) f.hud=visible and text or '' end}
local function status(text) f.lastStatus=text end
local function step(seconds,onDuty)
 for _=1,math.floor(seconds*4+.0001) do Scene.update(.25,onDuty==nil and f.duty or onDuty,f.patrol,status,hud) end
end
local function reset() Scene.reset();f:Reset() end
local function request()
 assert(Scene.request(f.patrol,status,true,true),Scene.state())
 assert(n:GetStage()==1 and #f.creates==0 and f.manual==654)
 step(.25);assert(n.m_marker.m_confirmed,'Authored native pin not linked at the exact scene target')
end
local function staged()
 request();f.playerPoint=f:Point(-100,0);step(.5)
 assert(#f.creates==10)
 assert(n.m_npcs.n==7 and n.m_cars.n==3 and n:GetAidState()==2 and n:GetStage()==1)
 for id in pairs(f.objects) do assert(f.god[id],'Actor unprotected before arrival') end
 assert(n.m_injured.down and #f.threats==0)
end
local function active()
 staged();f.playerPoint=f:Point(-40,0);step(.25)
 assert(n:GetStage()==2 and #f.threats==15)
 for id,a in pairs(f.objects) do assert((f.god[id]==true)==(a==n.m_injured),'Staging invulnerability leaked past arrival') end
 return n.m_injured
end
local function neutralize()
 local index=0
 for _,a in pairs(f.objects) do if a.record=='Character.NCPDPatrol_OD_Ganger' then
  index=index+1
  if index==1 then a.dead=true elseif index==2 then a.deadNoPool=true elseif index==3 then a.down=true elseif index==4 then a.unconscious=true else a.arrested=true end
 end end
 assert(index==5 and n:GetRemainingEnemies()==0)
end
local function revive()
 f.playerPoint=n.m_injured.pos
 assert(Scene.revive(status));assert(not Scene.revive(status),'Duplicate callback restarted treatment')
 step(2.75);assert(n:GetAidState()==3)
 step(1.5);assert(n:GetAidState()==1 and n.m_injured.health==100 and not f.god[n.m_injured.id.hash])
end
reset();staged()
assert(not n:ProtectNPC(f:Actor('Character.cvi_ncpd_police_ranged2_copperhead_ma',{hash=999},f:Point())))
local a=n.m_defender;local expected=a.pos;a.pos=f:Point(-30,0);local locks=f.locks;step(.25);assert(f.locks>locks and a.pos.x==expected.x and a.pos.y==expected.y)
f.ready=false;local creates,deletes,locked=#f.creates,#f.deletes,f.locks;step(2);assert(#f.creates==creates and #f.deletes==deletes and f.locks==locked)
f.ready=true;assert(Scene.cancel(f.patrol,status));assert(not Scene.isActive() and not next(f.god))
-- A new world can reuse numeric IDs. Forget those handles before any deletion.
reset();staged();local removes=#f.deletes;f.generation=f.generation+1;step(.25)
assert(not Scene.isActive() and #f.deletes==removes and f.managed[999])
-- Completion requires both outcomes, in either order, with one persistent record.
for _,rescueFirst in ipairs({true,false}) do
 reset();active()
 if rescueFirst then revive();assert(f.wallet==0 and n:GetStage()==2);neutralize()
 else neutralize();step(2);assert(f.wallet==0 and n:GetStage()==2);revive() end
 step(1.25)
 assert(n:GetStage()==3 and f.wallet==2000 and IncidentNative:GetCompletedCount()==1)
 assert(not Scene.isActive() and Scene.hasCleanup() and #f.deletes==0 and f.manual==654 and f.tracked==f.story)
 for i=0,f.pins.n-1 do assert(not f.pins[i].active) end
 assert(not Scene.request(f.patrol,status),'Retained scene overlapped itself')
 step(5);assert(f.wallet==2000 and IncidentNative:GetCompletedCount()==1)
 assert(Scene.cancel(f.patrol,status));assert(not Scene.hasCleanup() and f.managed[999])
 f.playerPoint=f:Point(-350,0);assert(Scene.request(f.patrol,status));assert(Scene.cancel(f.patrol,status))
end
-- The new kind keeps the existing durable payment retry and its own receipt.
reset();active();f.paymentOK=false;neutralize();revive();step(1.25)
assert(n:GetStage()==3 and f.wallet==0 and IncidentNative:GetCompletedCount()==1 and IncidentNative:GetPendingPayments()==1)
f.paymentOK=true
for _=1,44 do IncidentNative:Tick(.25) end
assert(f.wallet==2000 and IncidentNative:GetPendingPayments()==0 and #f.receipts==1)
assert(f.receipts[1]:find('OFFICER DOWN DISPATCH PAID',1,true))
Scene.cancel(f.patrol,status)
-- Range/menu interruptions and actual recovery/health readback, not a timer alone.
reset();active();f.playerPoint=n.m_injured.pos;assert(Scene.revive());step(1)
f.playerPoint=f:Point(0,0);step(.25);assert(n:GetAidState()==2)
f.playerPoint=n.m_injured.pos;assert(Scene.revive());f.menu=true;step(4);assert(n:GetAidState()==3)
f.menu=false;f.blockHealth=true;step(8);assert(n:GetAidState()==2 and f.wallet==0)
f.blockHealth=false;f.blockRecovery=true;assert(Scene.revive());step(8);assert(n:GetAidState()==2 and f.wallet==0)
f.blockRecovery=false;revive();assert(n:GetAidState()==1);Scene.cancel(f.patrol,status)
-- All partial and asynchronous failure paths keep their own cleanup reservation.
for _,failure in ipairs({'noGround','lowerFloor','obstruction','noNav','missingRecord','wrongPlacement','failProtection','actorVisible','partialCreate'}) do
 reset();request();f.playerPoint=f:Point(-100,0)
 if failure=='actorVisible' then f.actorVisible=false elseif failure=='partialCreate' then f.failCreateAt=5 else f[failure]=true end
 f.deleteOK=false;step(16)
 assert(f.wallet==0 and IncidentNative:GetCompletedCount()==0,failure)
 if next(f.objects) then assert(Scene.isActive() and Scene.hasCleanup(),failure..' released live IDs') end
 f.deleteOK=true;step(2);assert(not Scene.isActive() and f.managed[999],failure..' did not clear')
end
reset();active();f.deleteDeferred=true;assert(not Scene.cancel(f.patrol,status) and Scene.isActive())
step(2);assert(Scene.isActive());for id in pairs(f.objects) do f.managed[id]=nil end
step(2);assert(not Scene.isActive() and f.wallet==0)
-- Missing actors are never mistaken for neutralized enemies. No completion on abandon/death.
reset();active();n.m_npcs[2].attached=false;step(6);assert(n:GetStage()==4 and f.wallet==0)
reset();active();n.m_injured.dead=true;step(.25);assert(n:GetStage()==4 and f.wallet==0)
reset();request();n.m_remaining=.1;step(.25);assert(n:GetStage()==4 and f.wallet==0)
reset();staged();f.duty=false;step(1);assert(not Scene.isActive() and not next(f.god) and f.wallet==0)
-- A valid registration/activation alone cannot prove a quest marker.
reset();f.materialize=false
assert(Scene.request(f.patrol,status));step(8);assert(not n.m_marker.m_confirmed and n.m_marker.m_attempts==6 and f.manual==654)
Scene.cancel(f.patrol,status)
reset();f.pinWrongPosition=true;assert(Scene.request(f.patrol,status));step(1);assert(not n.m_marker.m_confirmed);Scene.cancel(f.patrol,status)
-- Rotation changes layout, not the baked marker position; read/reset is passive.
reset();local heading=Scene.heading();assert(Scene.rotate());assert(Scene.heading()==(heading+90)%360)
local L=require('officer_down_layout');local layout=L.build(Scene.heading(),f.player);assert(#layout==10)
assert(not n:LockPosition(f:Actor('ambient',{hash=999},f:Point()),f:Point(),0))
local deletes=#f.deletes;Scene.reset();assert(#f.deletes==deletes and f.managed[999])
-- Actual dispatcher shares the single-assignment reservation and resumes other
-- types while a completed scene retains bodies. Existing weighted choices run unchanged.
local empty={state=function() return 'idle' end,isActive=function() return false end,hasCleanup=function() return false end,
 lifecycle=function() return {reserved=false,foregroundCleanup=false,backgroundCleanup=false} end,
 reset=function() end,update=function() return false end,finish=function() end}
package.loaded.vip=setmetatable({request=function() return true end},{__index=empty})
package.loaded.cyberpsycho=empty
package.loaded.dispatch_scanner=setmetatable({isFailed=function() return false end,candidates=function() return 0 end},{__index=function() return function() end end})
package.loaded.dispatch_journal=setmetatable({},{__index=function() return function() end end})
package.loaded.dispatch_hud={set=hud.set,state=function() return '' end,shutdown=function() end}
package.loaded.dispatch=nil
local D=require('dispatch');D.reset();f:Reset();D.start(f.patrol,status);D.setAutomatic(false)
assert(D.requestOfficerDown(f.patrol,status));assert(D.isActive() and not D.requestVIP(f.patrol,status))
f.playerPoint=f:Point(-100,0)
local function dispatchStep(seconds) for _=1,math.floor(seconds*4+.001) do D.update(.25,f.duty,status,function() return f.patrol end) end end
dispatchStep(.5);f.playerPoint=f:Point(-40,0);dispatchStep(.25)
f.playerPoint=n.m_injured.pos;assert(D.reviveOfficerDown(status));neutralize();dispatchStep(5.5)
assert(n:GetStage()==3 and D.completed()==1 and not D.isActive() and D.lifecycle().backgroundCleanup)
assert(D.requestVIP(f.patrol,status),'Completed scene blocked another dispatch')
assert(D.mixDescription()=='50% Scanner / 30% VIP / 20% Cyberpsycho')
assert(D.clearOfficerDown(f.patrol,status));assert(not Scene.hasCleanup())
