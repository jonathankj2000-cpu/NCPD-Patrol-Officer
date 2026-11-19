-- Money/native-container boundaries. Real reserve/complete/retry/count logic
-- runs from NCPDPatrolIncidentSystem.reds in every generated incident scenario.
IncidentRewardFixture={wallet=0,attempts=0,available=true,paymentOK=true,grants={}}
local f=IncidentRewardFixture
NCPDPatrolIncidentSystem={Get=function() return IncidentNative end}
function IncidentNative:GetGameInstance() return {} end
function f:Reset()
 self.wallet=0;self.attempts=0;self.available=true;self.paymentOK=true;self.grants={}
 IncidentNative.m_serial=0
 IncidentNative.m_completedIds={n=0};IncidentNative.m_completedKinds={n=0}
 IncidentNative.m_completedAmounts={n=0};IncidentNative.m_paidIds={n=0}
 IncidentNative:OnAttach()
end
local oldTransaction=GameInstance.GetTransactionSystem
GameInstance.GetTransactionSystem=function(...)
 if not f.available then return nil end
 local original=oldTransaction(...)
 return {GiveItem=function(_,player,item,amount)
  if item=='Items.money' and (amount==2000 or amount==3000 or amount==3500) then
   f.attempts=f.attempts+1
   if not f.paymentOK then return false end
   f.wallet=f.wallet+amount;f.grants[#f.grants+1]={amount=amount,player=player};return true
  end
  return original and original:GiveItem(player,item,amount) or false
 end}
end
local oldContainer=Game.GetScriptableSystemsContainer
Game.GetScriptableSystemsContainer=function(...)
 local original=oldContainer(...)
 return {Get=function(_,name)
  if name=='NCPDPatrolIncidentSystem' then return IncidentNative end
  return original and original:Get(name)
 end}
end
local reset=CyberFixture.Reset
function CyberFixture:Reset(...)
 reset(self,...);f:Reset()
end
f:Reset()
