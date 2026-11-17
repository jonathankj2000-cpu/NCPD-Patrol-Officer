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
    function a:NCPDPatrolRefreshArrestInteraction() self.refreshes=self.refreshes+1 end
    return a
end
