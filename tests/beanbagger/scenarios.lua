local id='Items.NCPDBeanBagger_M2038'
function IsDefined(v) return v~=nil and v~=0 end
function Equals(a,b) return a==b end
function NotEquals(a,b) return a~=b end
gamedataNPCType={Human='human',Android='android',Drone='drone'}
hitFlag={Kill='Kill',ForceDismember='ForceDismember',Nonlethal='Nonlethal',DealNoDamage='DealNoDamage',DoNotTriggerFinisher='DoNotTriggerFinisher'}
ItemID={GetTDBID=function(_,value) return value end}
AttackData={IsRangedOnly=function(_,kind) return kind=='ranged' end}
ScriptedPuppet={IsDefeated=function(_,target) return target.defeated end,IsUnconscious=function(_,target) return target.unconscious end}
NCPDPatrolBeanBaggerSystem=Policy
function NativeAsNPC(v) if v and v.kind=='npc' then return v end end
local systemLookups=0
GameInstance={GetScriptableSystemsContainer=function()
 return {Get=function(_,name) assert(name=='NCPDPatrolBeanBaggerSystem');systemLookups=systemLookups+1;return Policy end}
end}
local function target()
 local t={kind='npc',type='human',dead=false,noPoolDead=false,defeated=false,unconscious=false,pending=false,attached=true}
 function t:GetGame() return {} end
 function t:GetNPCType() return self.type end
 function t:IsDead() return self.dead end
 function t:IsDeadNoStatPool() return self.noPoolDead end
 function t:IsAboutToBeDefeated() return self.pending end
 function t:IsAttached() return self.attached end
 function t:IsDefeatMechanicActive() return not self.disabledDefeat end
 return t
end
local originals=0
function wrappedMethod(hit)
 originals=originals+1
 if hit.perkKill then hit.attackData.flags.Kill=true;hit.attackData.flags.ForceDismember=true end
 hit.originalSeen=true
end
local function hit(record,isPlayer,kind,victim)
 local h={target=victim or target()}
 h.attackData={flags={CriticalHit=true},weapon={GetItemID=function() return record or id end},instigator={IsPlayer=function() return isPlayer~=false end}}
 function h.attackData:GetWeapon() return self.weapon end
 function h.attackData:GetInstigator() return self.instigator end
 function h.attackData:GetAttackType() return kind or 'ranged' end
 function h.attackData:AddFlag(flag,reason) assert(h.originalSeen,'policy ran before native modifier');self.flags[flag]=reason end
 function h.attackData:RemoveFlag(flag) assert(h.originalSeen);self.flags[flag]=nil end
 h.attackComputed={damage=90,MultAttackValue=function(self,value) self.damage=self.damage*value end}
 return h
end
Policy:OnAttach()
local h=hit();h.perkKill=true;Wrapper:ModifyHitData(h)
assert(originals==1 and h.originalSeen and h.attackData.flags.Nonlethal and h.attackData.flags.DoNotTriggerFinisher)
assert(not h.attackData.flags.Kill and not h.attackData.flags.ForceDismember and h.attackData.flags.CriticalHit)
assert(h.attackComputed.damage==90 and Policy.m_hits==1 and systemLookups==1)
-- Real target state, not merely a request flag, is reported for inspection.
h.target.defeated=true
assert(Policy:GetDiagnostics():find('dead=false | defeated=true',1,true))
-- Repeated fire and later pellets cannot finish a living downed target.
for _,state in ipairs({'defeated','unconscious','pending'}) do
 local t=target();t[state]=true;h=hit(id,true,'ranged',t);Wrapper:ModifyHitData(h)
 assert(h.attackComputed.damage==0 and h.attackData.flags.DealNoDamage and h.attackData.flags.Nonlethal)
 assert(not t.dead and t[state],'policy rewrote target life/state')
end
assert(Policy.m_protectedHits==3)
-- Switching guns, NPC use, weapon bashes, explosions/DoT and other weapon
-- damage remain vanilla even if the Bean Bagger is also in the inventory.
for _,case in ipairs({{'Items.Preset_Tactician_Default',true,'ranged'},{id,false,'ranged'},{id,true,'quickMelee'},{id,true,'explosion'},{id,true,'dot'}}) do
 h=hit(case[1],case[2],case[3]);h.perkKill=true;local count=Policy.m_hits;local lookups=systemLookups
 Wrapper:ModifyHitData(h)
 assert(h.attackData.flags.Kill and h.attackData.flags.ForceDismember and not h.attackData.flags.Nonlethal)
 assert(h.attackComputed.damage==90 and Policy.m_hits==count and systemLookups==lookups)
end
-- Missing data/weapon, non-puppet or mechanical targets and already dead bodies
-- do not gain non-lethal flags or have their original damage/life state changed.
for _,state in ipairs({'dead','noPoolDead'}) do
 local t=target();t[state]=true;h=hit(id,true,'ranged',t);Wrapper:ModifyHitData(h)
 assert(not h.attackData.flags.Nonlethal and h.attackComputed.damage==90 and t[state])
end
for _,kind in ipairs({'android','drone'}) do
 local t=target();t.type=kind;h=hit(id,true,'ranged',t);Wrapper:ModifyHitData(h)
 assert(not h.attackData.flags.Nonlethal and h.attackComputed.damage==90)
end
h=hit();h.target.kind='vehicle';Wrapper:ModifyHitData(h);assert(not h.attackData.flags.Nonlethal)
h=hit();h.attackData.weapon=nil;Wrapper:ModifyHitData(h);assert(not h.attackData.flags.Nonlethal)
assert(not Policy:IsBeanBaggerHit(nil) and not Policy:IsBeanBaggerHit({}))
Policy:Apply(nil);Policy:Apply({});Policy:OnRestored(1,1)
assert(Policy.m_hits==0 and Policy.m_protectedHits==0 and Policy.m_target==nil)
assert(Policy:GetDiagnostics():find('last target unavailable',1,true))
