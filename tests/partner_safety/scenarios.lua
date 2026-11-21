local f={ready=true,heat=0,calls=0,threats=0,damage=0,nativeReturn=true}
function IsDefined(x) return x~=nil and x~=0 end
function Equals(a,b) return a==b end
function NotEquals(a,b) return a~=b end
function ArrayClear(a) for k in pairs(a) do a[k]=nil end;a.n=0 end
EAIAttitude={AIA_Friendly=0,AIA_Neutral=1,AIA_Hostile=2}
gamedataAffiliation={NCPD=1,Other=2}
EPreventionHeatStage={Heat_0=0}
AttackData={IsRangedOnly=function(_,kind) return kind=='ranged' end}
GameObject={GetAttitudeTowards=function(_,receiver,source)
 return receiver.hostileTo==source and EAIAttitude.AIA_Hostile or EAIAttitude.AIA_Neutral
end}
NCPDPatrolPartnerSafety=Safety
NCPDPatrolSystem={Get=function() if f.noPatrol then return nil end;return Core end}
NCPDPatrolSupportSystem={Get=function() if f.noSupport then return nil end;return Support end}
NCPDPatrolMarkerSession={WorldReady=function() return f.ready end}
GameInstance={GetScriptableSystemsContainer=function()
 return {Get=function() return {GetHeatStage=function() return f.heat end} end}
end}
function Core:GetGameInstance() return {} end
function Core:CancelDispatchVoiceWindow() end
function Core:StopVehicleChatter() end
function Core:ClearDispatchWaypoints() end
function Core:ShowPriorityMessage(text) f.notice=text end
local function actor(kind,police)
 local a={kind=kind,police=police,attached=true,dead=false}
 function a:IsAttached() return self.attached end
 function a:IsDead() return self.dead end
 function a:IsPlayer() return self.kind=='player' end
 function a:GetGame() return {} end
 function a:IsCharacterPolice() return self.police end
 function a:IsPrevention() return self.prevention==true end
 function a:GetRecord() return self.record end
 local wrapper=kind=='vehicle' and VehicleObjectWrapper or NPCPuppetWrapper
 return setmetatable(a,{__index=wrapper})
end
local player=actor('player',false)
local partner=actor('npc',true)
local other=actor('npc',true)
local police=actor('npc',true)
local gang=actor('npc',false)
local civilian=actor('npc',false)
local car=actor('vehicle',false)
car.prevention=true
local emptyPoliceCar=actor('vehicle',false)
emptyPoliceCar.record={Affiliation=function() return {Type=function() return gamedataAffiliation.NCPD end} end}
local civilianCar=actor('vehicle',false)
civilianCar.record={Affiliation=function() return {Type=function() return gamedataAffiliation.Other end} end}
function GetPlayer() return not f.noPlayer and player or nil end
function AsNPC(x) return x and x.kind=='npc' and x or nil end
function AsVehicle(x) return x and x.kind=='vehicle' and x or nil end
function wrappedMethod(hit)
 f.calls=f.calls+1;f.damage=f.damage+1
 if hit.target.kind=='vehicle' and hit.target.prevention and not hit.attackData:GetInstigator().prevention then
  f.threats=f.threats+1
 end
 return f.nativeReturn
end
local function hit(target,source,kind)
 return {target=target,attackData={GetInstigator=function() return source end,GetAttackType=function() return kind or 'ranged' end}}
end
local function reset()
 f.ready=true;f.heat=0;f.calls=0;f.damage=0;f.threats=0;f.nativeReturn=true
 f.noPatrol=false;f.noSupport=false;f.noPlayer=false
 player.attached=true;player.dead=false;partner.attached=true
 Core.m_onDuty=true;Core.m_criminalTermination=false;Core.m_requestedDuty=0
 Support.m_partner=partner
 for _,a in ipairs({car,emptyPoliceCar,police,gang,civilian,civilianCar}) do a.hostileTo=nil;a.attached=true end
end
local function check(target,source,kind,blocked)
 local before=f.calls;local e=hit(target,source,kind)
 assert(Safety:ShouldIgnoreHit(target,e)==blocked)
 local result=target:OnHit(e)
 assert(f.calls==before+(blocked and 0 or 1))
 if blocked then assert(result==false) else assert(result==f.nativeReturn) end
end
reset()
-- Counterfactual native boundary records the threat route for an ordinary NPC.
wrappedMethod(hit(car,partner));assert(f.threats==1 and f.damage==1)
reset()
for _,target in ipairs({car,emptyPoliceCar,police}) do check(target,partner,'ranged',true) end
assert(f.calls==0 and f.threats==0 and f.damage==0)
for _,target in ipairs({gang,civilian,civilianCar}) do check(target,partner,'ranged',false) end
for _,source in ipairs({player,other}) do
 for _,target in ipairs({car,emptyPoliceCar,police,gang}) do check(target,source,'ranged',false) end
end
-- There is no time window or police-wide immunity: V's next hit still runs.
check(car,partner,'ranged',true);check(car,player,'ranged',false)
for _,kind in ipairs({'melee','collision','explosion','hack','direct'}) do check(car,partner,kind,false) end
for _,target in ipairs({car,emptyPoliceCar,police}) do
 for _,source in ipairs({partner,player}) do
  target.hostileTo=source;check(target,partner,'ranged',false);target.hostileTo=nil
 end
end
for _,condition in ipairs({'offDuty','session','partnerDetached','targetDetached','playerDetached','playerDead','noPlayer','noPatrol','noSupport','unregistered','sameRecordNewActor'}) do
 reset()
 if condition=='offDuty' then Core.m_onDuty=false end
 if condition=='session' then f.ready=false end
 if condition=='partnerDetached' then partner.attached=false end
 if condition=='targetDetached' then car.attached=false end
 if condition=='playerDetached' then player.attached=false end
 if condition=='playerDead' then player.dead=true end
 if condition=='noPlayer' then f.noPlayer=true end
 if condition=='noPatrol' then f.noPatrol=true end
 if condition=='noSupport' then f.noSupport=true end
 if condition=='unregistered' then Support.m_partner=nil end
 if condition=='sameRecordNewActor' then Support.m_partner=other end
 check(car,partner,'ranged',false)
end
reset()
assert(not Safety:ShouldIgnoreHit(car,nil))
assert(not Safety:ShouldIgnoreHit(nil,hit(car,partner)))
assert(not Safety:ShouldIgnoreHit(car,{target=car}))
assert(not Safety:ShouldIgnoreHit(car,hit(police,partner)))
assert(not Safety:ShouldIgnoreHit(car,hit(car,nil)))
for _,record in ipairs({false,{Affiliation=function() return nil end}}) do
 emptyPoliceCar.record=record or nil;check(emptyPoliceCar,partner,'ranged',false)
end
f.nativeReturn=false;check(car,player,'ranged',false)
reset();f.heat=1;Core:EnforceDutyRules()
assert(f.heat==1 and not Core:IsOnDuty() and Core:WasTerminatedForCrime())
assert(f.notice:find('criminal activity',1,true))
check(car,partner,'ranged',false)
reset();Support:OnRestored(0,0)
assert(not Support:IsPartner(partner));check(car,partner,'ranged',false)
