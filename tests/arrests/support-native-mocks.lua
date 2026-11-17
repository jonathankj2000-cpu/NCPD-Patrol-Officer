-- Only native boundaries are simulated; the authored support class executes.
gameGodModeType={Immortal='immortal',Invulnerable='invulnerable'}
gamedataStatPoolType={Health='health'}
godModes,godCalls,reviveEvents,fullDefeats,healCalls={},{},{},{},{}
supportPlayer=nil
NCPDPatrolSystem={Get=function() return Patrol end}
NCPDPatrolSupportSystem={Get=function() return Support end}
local oldContainer=GameInstance.GetScriptableSystemsContainer
GameInstance.GetScriptableSystemsContainer=function(...)
    local original=oldContainer(...)
    return {Get=function(self,name)
        if name=='NCPDPatrolSupportSystem' then return Support end
        return original:Get(name)
    end}
end
local god={}
function god:AddGodMode(id,mode,source)
    godModes[id.hash]=godModes[id.hash] or {}
    godModes[id.hash][source]=mode
    godCalls[#godCalls+1]={op='add',id=id.hash,mode=mode,source=source}
    return true
end
function god:RemoveGodMode(id,mode,source)
    if godModes[id.hash] then godModes[id.hash][source]=nil end
    godCalls[#godCalls+1]={op='remove',id=id.hash,mode=mode,source=source}
    return true
end
GameInstance.GetGodModeSystem=function() return god end
GameInstance.GetStatPoolsSystem=function() return {
    GetStatPoolValue=function(self,id,pool,perc) return (supportActors[id.hash] or {}).health or 100 end,
    RequestSettingStatPoolValue=function(self,id,pool,value,instigator,perc)
        assert(perc==true and pool=='health')
        local a=supportActors[id.hash]
        healCalls[#healCalls+1]={actor=a,value=value,downEffect=a.effects['BaseStatusEffect.NCPDPatrolPartnerDown']==true}
        if (a.healRejectCount or 0)>0 then a.healRejectCount=a.healRejectCount-1; return end
        if not a.healRejectAlways then a.health=value end
    end
} end
local originalGetPlayer=GetPlayer
function GetPlayer(...) return supportPlayer or originalGetPlayer(...) end
Vector4=Vector4 or {}
function Vector4.Distance(self,a,b)
    return math.sqrt((a.x-b.x)^2+(a.y-b.y)^2+(a.z-b.z)^2)
end
local mounted=VehicleComponent and VehicleComponent.IsMountedToVehicle
VehicleComponent=VehicleComponent or {}
function VehicleComponent:IsMountedToVehicle(game,obj) return obj.vehicle~=nil end
ScriptedPuppet={
    IsDefeated=function(self,obj) return obj.effects and (obj.effects['BaseStatusEffect.Defeated'] or obj.effects['BaseStatusEffect.NCPDPatrolPartnerDown']) or false end,
    IsUnconscious=function(self,obj) return obj.effects and obj.effects['BaseStatusEffect.Unconscious'] or false end,
    IsActive=function(self,obj) return not obj.dead and not self:IsDefeated(obj) and not self:IsUnconscious(obj) end,
    SendResurrectEvent=function(self,obj) reviveEvents[#reviveEvents+1]=obj end
}
StatusEffectHelper={}
function StatusEffectHelper:ApplyStatusEffect(obj,id)
    obj.effects=obj.effects or {}; obj.effects[id]=true
end
function StatusEffectHelper:RemoveStatusEffect(obj,id)
    obj.effects=obj.effects or {}
    if obj.holdEffectRemoval then return end
    local wasApplied=obj.effects[id]
    obj.effects[id]=nil
    if id=='BaseStatusEffect.NCPDPatrolPartnerDown' and wasApplied then
        -- Model the documented remove callback, not a mod-authored AI repair.
        obj.senseType='npc'
        if not obj.freezeHigh then obj.highLevel='relaxed' end
    end
end
supportActors={}
function supportActor(id,record,x,y,z)
    local a={id={hash=id},health=100,record=record,position={x=x,y=y,z=z},effects={},refreshes=0,attached=true}
    function a:GetEntityID() return self.id end
    function a:GetRecordID() return self.record end
    function a:GetWorldPosition() return self.position end
    function a:IsAttached() return self.attached end
    function a:IsDead() return self.dead==true end
    function a:SetIsDefeatMechanicActive(value) self.defeatMechanic=value end
    function a:NCPDPatrolRefreshAidInteraction() self.refreshes=self.refreshes+1 end
    supportActors[id]=a
    return a
end

gamedataNPCHighLevelState={Relaxed='relaxed',Combat='combat',Unconscious='unconscious',Dead='dead'}
EAIRole={None='none',Follower='follower'}
StatusEffectSystem={
    ObjectHasStatusEffectOfType=function(self,obj,t) assert(t=='wounded'); return obj.wounded==true end,
    ObjectHasStatusEffectWithTag=function(self,obj,tag) return tag=='FollowerDefeated' and obj.followerDefeated==true end,
    ObjectHasStatusEffect=function(self,obj,id) return obj.effects and obj.effects[id]==true end
}
gamedataStatusEffectType={Defeated='defeated',DefeatedWithRecover='recoverable',Wounded='wounded'}
function NameToString(name) return name end
downRecordPresent,downRecordType,downDuration=true,'recoverable','BaseStats.InfiniteDuration'
TweakDBInterface={GetStatusEffectRecord=function(self,id)
    assert(id=='BaseStatusEffect.NCPDPatrolPartnerDown')
    if not downRecordPresent then return nil end
    return {StatusEffectType=function() return {Type=function() return downRecordType end} end,
        Duration=function() return {GetID=function() return downDuration end} end}
end}
NPCPuppet={ChangeHighLevelState=function(self,obj,state)
    obj.highRequests=(obj.highRequests or 0)+1
    if not obj.freezeHigh then obj.highLevel=state end
end}
roleChanges={}
AIHumanComponent={SetCurrentRole=function(self,obj,role)
    roleChanges[#roleChanges+1]={actor=obj,role=role}
    local ai=obj:GetAIControllerComponent()
    if ai.SetAIRole then ai:SetAIRole(role) end
    ai.nativeFollowerReady=not obj.failRoleBind
    obj.senseType='follower'
end}
function addSupportAIBoundaries(a)
    a.highLevel='relaxed'; a.downSignal=false; a.senses=true; a.bump=true
    local ai={IsPlayerCompanion=function(self) return self.nativeFollowerReady==true end}
    if not a.GetAIControllerComponent then a.GetAIControllerComponent=function() return ai end end
    function a:GetHighLevelStateFromBlackboard() return self.highLevel end
    function a:GetSignalHandlerComponent()
        return {
            HasSignalWithTag=function(_,tag) return tag=='downed' and a.downSignal==true end,
            IsHighestPriority=function(_,tag) return a.downSignal and not a.priorityBlocker,1 end,
            RemoveSignal=function(_,id)
                assert(id==1); a.signalRemovals=(a.signalRemovals or 0)+1
                if a.failRemoveSignal then return false end
                a.downSignal=false; return true
            end
        }
    end
    function a:GetSensesComponent() return {ToggleComponent=function(_,v) a.senses=v end} end
    function a:GetBumpComponent() return {Toggle=function(_,v) a.bump=v end} end
    function a:GetGame() return {} end
end
local originalActor=supportActor
function supportActor(...)
    local a=originalActor(...); addSupportAIBoundaries(a); return a
end
local originalApply=StatusEffectHelper.ApplyStatusEffect
function StatusEffectHelper:ApplyStatusEffect(obj,id)
    originalApply(self,obj,id)
    if id=='BaseStatusEffect.Defeated' then
        fullDefeats[#fullDefeats+1]=obj
        obj.highLevel='unconscious'; obj.downSignal=true; obj.senses=false; obj.bump=false
    elseif id=='BaseStatusEffect.NCPDPatrolPartnerDown' then
        obj.highLevel='unconscious'
    end
end
function StatusEffectHelper:RemoveStatusEffectsWithTag(obj,tag)
    assert(tag=='FollowerDefeated'); obj.followerDefeated=false
end
