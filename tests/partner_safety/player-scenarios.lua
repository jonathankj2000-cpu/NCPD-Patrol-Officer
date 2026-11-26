-- Continuation of scenarios.lua: actual authored policy/owner/wrappers execute
-- against recording damage/prevention/targeting/time boundaries.
local baseReset,baseWrapped=reset,wrappedMethod
reset=function()
 baseReset();Core:ResetPoliceFireGuard();f.combat=true;f.time=100;f.warnings=0
 player.pos={x=0,y=0,z=0};gang.pos={x=10,y=0,z=0};gang.hostileTo=player
 gang.dead=false;gang.deadNoPool=false;gang.down=false;gang.unconscious=false
 f.lookedAt=gang;f.tracked=nil
 f.targeting={GetLookAtObject=function() return f.lookedAt end,GetTrackedTargetObject=function() return f.tracked end}
end
function Core:ShowPriorityMessage(text)
 f.notice=text;if text:find('Check your fire',1,true) then f.warnings=f.warnings+1 end
end
function wrappedMethod(e)
 local result=baseWrapped(e)
 if e.attackData:GetInstigator()==player and Safety:IsPolice(e.target) then f.heat=f.heat+1 end
 return result
end
local weapon={};local serial=0
local function discharge(target,options)
 options=options or {};serial=serial+1
 local attack={serial=serial};local stamp=f.time
 local e=hit(target,options.source or player,options.kind)
 e.attackData.GetAttackDefinition=function() if not options.noAttack then return attack end end
 e.attackData.GetWeapon=function() if not options.noWeapon then return weapon end end
 e.attackData.GetAttackTime=function() return options.stamp or stamp end
 return e
end
local function deliver(e,ignored)
 local before=f.calls;local result=e.target:OnHit(e)
 assert(f.calls==before+(ignored and 0 or 1))
 if ignored then assert(result==false) else assert(result==f.nativeReturn) end
end
-- A hostile aim context allows one genuinely stray hit on either kind of
-- police receiver; damage/threat/prevention callbacks are not reached.
emptyPoliceCar.record={Affiliation=function() return {Type=function() return gamedataAffiliation.NCPD end} end}
reset();assert(not PreviousSafety:ShouldIgnoreHit(car,discharge(car)))
local currentPolicy=NCPDPatrolPartnerSafety;NCPDPatrolPartnerSafety=PreviousSafety
deliver(discharge(car),false);Core:EnforceDutyRules()
assert(f.heat==1 and not Core:IsOnDuty() and Core:WasTerminatedForCrime(),'Old stray-fire gap was not reproduced')
NCPDPatrolPartnerSafety=currentPolicy
for _,target in ipairs({police,car,emptyPoliceCar}) do
 reset();deliver(discharge(target),true)
 assert(f.calls==0 and f.damage==0 and f.heat==0 and f.warnings==1 and Core:IsOnDuty())
 assert(Core.m_excusedPoliceShots==1)
end
-- Observe the real incoming-hit wrapper before the original. A current,
-- living non-police shooter supplies context when the crosshair hits nothing.
reset();f.lookedAt=nil
local incoming=hit(player,gang)
assert(GameObjectWrapper.OnHit(player,incoming)==f.nativeReturn)
assert(Core.m_recentHostileShooter==gang and f.calls==1)
f.time=105.5;deliver(discharge(car),true);assert(f.warnings==1 and f.heat==0)
reset();f.lookedAt=nil
GameObjectWrapper.OnHit(player,hit(player,gang));f.time=106.1
deliver(discharge(car),false);assert(f.heat==1 and f.warnings==0)
-- Exact attack identity/time/weapon groups shotgun pellets for <=0.5 seconds,
-- even if the cursor moves after firing. A different shot is never that group.
reset();local e=discharge(car);deliver(e,true)
f.time=100.2;f.lookedAt=police
deliver({target=police,attackData=e.attackData},true)
assert(Core.m_excusedPoliceShots==1 and f.warnings==1 and f.heat==0)
f.time=100.3;f.lookedAt=gang;deliver(discharge(car),false)
assert(f.heat==1);Core:EnforceDutyRules()
assert(not Core:IsOnDuty() and Core:WasTerminatedForCrime() and f.heat==1)
reset();e=discharge(car);deliver(e,true);f.time=100.6;deliver(e,false)
reset();e=discharge(car);deliver(e,true);f.time=110;deliver(discharge(police),true)
assert(f.warnings==2 and Core.m_excusedPoliceShots==2)
-- Direct police aim/tracking must not consume an allowance or prevent heat,
-- including deliberate aim immediately after taking an enemy's shot.
for _,target in ipairs({police,car,emptyPoliceCar}) do
 for _,slot in ipairs({'lookedAt','tracked'}) do
  reset();GameObjectWrapper.OnHit(player,hit(player,gang));f[slot]=target
  deliver(discharge(car),false)
  assert(f.warnings==0 and f.heat==1);Core:EnforceDutyRules();assert(not Core:IsOnDuty())
 end
end
-- Missing/invalid context fails closed. Duty alone cannot license gunfire.
for _,condition in ipairs({'noCombat','noContext','friendly','deadEnemy','downEnemy','unconsciousEnemy','farEnemy','policeEnemy','targetHostile','wanted','offDuty','world','deadPlayer','noTargeting','futureShot','oldShot','noWeapon','noAttack','explosion','melee'}) do
 reset();local options={}
 if condition=='noCombat' then f.combat=false end
 if condition=='noContext' then f.lookedAt=nil end
 if condition=='friendly' then gang.hostileTo=nil end
 if condition=='deadEnemy' then gang.dead=true end
 if condition=='downEnemy' then gang.down=true end
 if condition=='unconsciousEnemy' then gang.unconscious=true end
 if condition=='farEnemy' then gang.pos={x=151,y=0,z=0} end
 if condition=='policeEnemy' then f.lookedAt=police;police.hostileTo=player end
 if condition=='targetHostile' then car.hostileTo=player end
 if condition=='wanted' then f.heat=1 end
 if condition=='offDuty' then Core.m_onDuty=false end
 if condition=='world' then f.ready=false end
 if condition=='deadPlayer' then player.dead=true end
 if condition=='noTargeting' then f.targeting=nil end
 if condition=='futureShot' then options.stamp=f.time+2 end
 if condition=='oldShot' then options.stamp=f.time-4 end
 if condition=='noWeapon' then options.noWeapon=true end
 if condition=='noAttack' then options.noAttack=true end
 if condition=='explosion' then options.kind='explosion' end
 if condition=='melee' then options.kind='melee' end
 deliver(discharge(car,options),false);assert(f.warnings==0,condition)
end
-- Civilian/enemy damage, unrelated instigators and malformed events retain
-- their original path. An unrelated hit never spends the stray-shot budget.
reset();deliver(discharge(civilian),false);deliver(discharge(gang),false)
assert(not Core.m_excusedPoliceShot and f.heat==0)
deliver(discharge(car,{source=other}),false);assert(not Core.m_excusedPoliceShot)
assert(not Safety:ShouldIgnoreHit(car,{target=police,attackData=discharge(police).attackData}))
-- The incoming observer never suppresses hits and does not invent a threat
-- from friendly/non-police, missing/old-world or non-ranged sources.
for _,condition in ipairs({'friendly','police','explosion','offDuty','world'}) do
 reset();local source,kind=gang,'ranged'
 if condition=='friendly' then gang.hostileTo=nil end
 if condition=='police' then source=police;police.hostileTo=player end
 if condition=='explosion' then kind='explosion' end
 if condition=='offDuty' then Core.m_onDuty=false end
 if condition=='world' then f.ready=false end
 local before=f.calls;GameObjectWrapper.OnHit(player,hit(player,source,kind))
 assert(f.calls==before+1 and not IsDefined(Core.m_recentHostileShooter))
end
reset();deliver(discharge(car),true);Core:ResetSession()
assert(not Core.m_excusedPoliceShot and not IsDefined(Core.m_recentHostileShooter) and Core.m_excusedPoliceShots==0)
assert(not Core:IsOnDuty());Core.m_onDuty=true;deliver(discharge(car),true)
assert(f.warnings==2,'New world/shift did not reset the transient allowance')
