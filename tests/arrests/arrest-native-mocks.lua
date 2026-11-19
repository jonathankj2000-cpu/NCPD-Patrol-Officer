-- Native boundaries only; eligibility, progression and payments run the
-- authored redscript class through the existing test-only syntax adapter.
gamedataNPCType={Human='human',Android='android',Drone='drone'}
EntityID={ToDebugStringDecimal=function(self,id) return tostring(id.hash) end}
NCPDPatrolArrestSystem={Get=function() return ArrestNative end}
local originalContainer=GameInstance.GetScriptableSystemsContainer
GameInstance.GetScriptableSystemsContainer=function(...)
    local original=originalContainer(...)
    return {Get=function(self,name)
        if name=='NCPDPatrolArrestSystem' then return ArrestNative end
        return original:Get(name)
    end}
end
arrestPayments={}; arrestPaymentOK=true
GameInstance.GetTransactionSystem=function()
    if not transactionPresent then return nil end
    return {GiveItem=function(self,player,item,amount)
        assert(item=='Items.money' and (amount==250 or amount==1000))
        if not arrestPaymentOK then return false end
        arrestPayments[#arrestPayments+1]=amount
        wallet=wallet+amount
        return true
    end}
end
function arrestSuspect(id,x)
    local a=supportActor(id,'Character.gang_member',x or 1,0,0)
    a.health=2; a.effects['BaseStatusEffect.Defeated']=true
    function a:IsDeadNoStatPool() return self.persistentDead==true end
    function a:GetNPCType() return self.npcType or 'human' end
    function a:IsCharacterCivilian() return self.civilian==true end
    function a:IsCharacterPolice() return self.police==true end
    function a:IsPlayerCompanion() return self.companion==true end
    function a:IsQuest() return self.quest==true end
    function a:IsBoss() return self.boss==true end
    function a:IsEnemy() return self.friendly~=true end
    function a:GetWorldOrientation() return {i=0,j=0,k=0,r=1} end
    function a:GetWorldForward() return {x=0,y=1,z=0,w=0} end
    function a:IsRagdolling() return self.ragdoll==true end
    function a:IsRagdollEnabled() return self.ragdoll==true or self.animatedRagdoll==true end
    function a:QueueEvent(event) self.physicsEvents=self.physicsEvents or {};self.physicsEvents[#self.physicsEvents+1]=event end
    function a:SetDisableRagdoll(value)
        self.physicsDisabled=value
        if value and not self.stuckRagdoll then self.ragdoll=false;self.animatedRagdoll=false end
    end
    function a:CanEnableRagdollComponent() return not self.nativeRagdollBlocked and not ArrestNative:OwnsPosePhysics(self) end
    setmetatable(a.position,{__index=function(t,k) return rawget(t,string.lower(k)) end})
    function a:NCPDPatrolRefreshArrestInteraction() self.refreshes=self.refreshes+1 end
    return a
end
function CreateDisableRagdollEvent(source) return {kind='disable',source=source} end
function CreateForceRagdollNoPowerPoseEvent(source) return {kind='restore',source=source} end
Quaternion={ToEulerAngles=function(_,value) return value end}
AbsF=math.abs
GameInstance.GetTeleportationFacility=function()
    return {Teleport=function(_,actor,point)
        actor.teleports=(actor.teleports or 0)+1
        if not actor.rejectTeleport then
            actor.position=setmetatable({x=point.x,y=point.y,z=point.z},{__index=function(t,k)return rawget(t,string.lower(k))end})
        end
    end}
end
GameInstance.GetMountingFacility=function()
    return {IsMountedToAnything=function(_,id)
        local actor=supportActors[id.hash]
        return actor and (actor.carried==true or actor.vehicle~=nil) or false
    end}
end
