-- Actual CET partner module consumes the authored redscript career selection.
local f=CareerFixture;f:Reset(100)
local player=GetPlayer()
function player:GetWorldPosition() return {x=1,y=2,z=3,w=1} end
function player:GetWorldOrientation() return {} end
local managed={[990]='ambient'};local creates,deletes,actors={},{},{}
local deleteAccepted=true;local missingRecord;local missingCareer=false
local statusConfigured,godAvailable,godAccepted=true,true,true
local godAdds=0
gameGodModeType={Immortal=1,Invulnerable=2};gamedataStatusEffectType={DefeatedWithRecover=1}
local god={AddGodMode=function(_,id,kind,tag)
 assert(kind==gameGodModeType.Immortal and tag=='NCPDPatrolPartner');godAdds=godAdds+1;return godAccepted
end,RemoveGodMode=function() end}
GameInstance.GetGodModeSystem=function() if godAvailable then return god end end
TweakDBInterface={GetStatusEffectRecord=function(_,id)
 assert(id=='BaseStatusEffect.NCPDPatrolPartnerDown')
 if statusConfigured then return {
  StatusEffectType=function() return {Type=function() return gamedataStatusEffectType.DefeatedWithRecover end} end,
  Duration=function() return {GetID=function() return 'BaseStats.InfiniteDuration' end} end} end
end}
local playerAgent={GetAttitudeGroup=function() return 'player' end}
function player:GetAttitudeAgent() return playerAgent end
local function actor(record,id)
 local a={commands=0,defeat=true,record=record,id=id}
 local ai={GetAIRole=function() return nil end,SetAIRole=function(_,role) a.role=role end,OnAttach=function() end,
  SendCommand=function() a.commands=a.commands+1 end,StopExecutingCommand=function() end}
 function a:GetRecordID() return self.record end
 function a:GetEntityID() return self.id end
 function a:IsAttached() return true end
 function a:IsDead() return false end
 function a:SetIsDefeatMechanicActive(value) self.defeat=value end
 function a:GetAIControllerComponent() return ai end
 function a:GetAttitudeAgent() return {SetAttitudeGroup=function() end,SetAttitudeTowards=function() end} end
 return a
end
Core.m_onDuty=true;Support:OnAttach()
local outsider=actor('Character.unrelated',90)
assert(not Support:RegisterPartner(outsider) and godAdds==0)
local ordinary=actor('Character.cvi_ncpd_police_ranged2_copperhead_ma',91)
Core.m_onDuty=false;assert(not Support:RegisterPartner(ordinary));Core.m_onDuty=true
f.wanted=true;assert(not Support:RegisterPartner(ordinary));f.wanted=false
statusConfigured=false;assert(not Support:RegisterPartner(ordinary));statusConfigured=true
godAvailable=false;assert(not Support:RegisterPartner(ordinary));godAvailable=true
godAccepted=false;assert(not Support:RegisterPartner(ordinary) and Support:GetPartnerState()==0);godAccepted=true
assert(Support:RegisterPartner(ordinary) and not ordinary.defeat and Support:GetPartnerState()==1)
local added=godAdds;assert(Support:RegisterPartner(ordinary) and godAdds==added)
assert(not Support:RegisterPartner(actor(ordinary.record,92)));Support:UnregisterPartner()
local entities={IsReady=function() return true end,IsManaged=function(_,id) return managed[id]==true end,
 GetEntity=function(_,id) return actors[id] end,
 CreateEntity=function(_,spec)
  assert(spec.persistState==false and spec.persistSpawn==false and spec.active==true)
  creates[#creates+1]=spec;managed[#creates]=true;actors[#creates]=actor(spec.recordID,#creates);return #creates
 end,
 DeleteEntity=function(_,id)
  assert(managed[id]==true and id~=990);deletes[#deletes+1]=id
  if not deleteAccepted then return false end
  managed[id]=nil;return true
 end}
Game={GetPlayer=GetPlayer,GetDynamicEntitySystem=function() return entities end,
 GetScriptableSystemsContainer=function() return {Get=function(_,name)
  if name=='NCPDPatrolCareerSystem' and not missingCareer then return Career end
  if name=='NCPDPatrolSupportSystem' then return Support end
 end} end}
TweakDB={GetRecord=function(_,id) if id~=missingRecord then return {} end end}
TweakDBID={new=function(record) return record end};DynamicEntitySpec={new=function() return {} end}
AIFollowerRole={new=function() return {} end};AIFollowTargetCommand={new=function() return {} end}
moveMovementType={Run=1};EAIAttitude={AIA_Friendly=1}
Game.CreateEntityReference=function() return {} end
Vector4=Vector4 or {};Vector4.new=function(x,y,z,w) return {x=x,y=y,z=z,w=w} end
local Partner=require('partner');local messages={};local function status(text) messages[#messages+1]=text end
Partner.reset();Partner.spawn(false,status);assert(#creates==0)
local records={'Character.cvi_ncpd_police_ranged2_copperhead_ma','Character.nok_ncpd_enforcer_shotgun2_tactician_ma_rare',
 'Character.ncpd_hwp_gunner2_defender_mb_rare','Character.maxtac_av_netrunner_ma'}
for index,record in ipairs(records) do
 assert(Career:SelectPartner(index-1))
 if index==1 then Partner.spawn(true,status) else assert(Partner.replace(true,status)) end
 assert(#creates==index and creates[index].recordID==record and Partner.activeProfile()==Career:PartnerName(index-1))
 Partner.update(0.5,true,status)
 assert(Support:IsPartner(actors[index]) and not actors[index].defeat and actors[index].commands==1,
  'selected model failed native revive registration/follower initialization: '..record)
 assert(Partner.state()=='Spawned; follower commands sent')
 Partner.spawn(true,status);assert(#creates==index,'duplicate partner admitted')
end
assert(managed[990]=='ambient' and #deletes==3 and managed[4])
assert(Career:SelectPartner(0));missingRecord=records[1]
assert(not Partner.replace(true,status) and #creates==4 and #deletes==3 and managed[4],'missing next model removed active partner')
missingRecord=nil;missingCareer=true
assert(not Partner.replace(true,status) and #deletes==3 and managed[4]);missingCareer=false
deleteAccepted=false;assert(not Partner.replace(true,status) and #creates==4 and managed[4])
deleteAccepted=true;assert(Partner.replace(true,status) and #creates==5 and creates[5].recordID==records[1])
-- Clear/restore test eligibility returns future spawns to the standard profile.
f:SetCount(0);assert(Career:SetTestUnlocks(true) and Career:SelectPartner(3))
assert(Partner.replace(true,status) and creates[6].recordID==records[4])
Career:OnRestored(1,1);Support:OnRestored(1,1);local deleted=#deletes;Partner.reset()
assert(#deletes==deleted and Partner.activeProfile()=='None','load tried to delete stale actor IDs')
managed={[990]='ambient'};Partner.spawn(true,status)
assert(creates[7].recordID==records[1] and Core:GetRecordedScannerCount()==0)
Partner.dismiss(status);assert(Partner.activeProfile()=='None' and managed[990]=='ambient')
