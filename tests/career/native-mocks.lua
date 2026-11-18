-- Boundary fixtures only; decisions execute the authored redscript classes.
CareerFixture={count=0,wanted=false,ready=true,notices={},registration={},loads={},hostCalls=0}
local player={attached=true,dead=false,combat=false}
function player:IsAttached() return self.attached end
function player:IsDead() return self.dead end
function player:IsInCombat() return self.combat end
function player:GetGame() return {} end
function GetPlayer() if CareerFixture.ready then return player end end
function Core:GetGameInstance() return {} end
function Dispatch:GetGameInstance() return {} end
function Arrests:GetGameInstance() return {} end
function Career:GetGameInstance() return {} end
function Support:GetGameInstance() return {} end
function BrowserState:GetGameInstance() return {} end
NCPDPatrolCareerBrowserState={Get=function() return BrowserState end}
function Core:NotifyCareerReward(amount,threshold) CareerFixture.notices[#CareerFixture.notices+1]={amount=amount,threshold=threshold} end
function Core:NotifyDispatch(text,duration) CareerFixture.notices[#CareerFixture.notices+1]={text=text,duration=duration} end
NCPDPatrolSystem={Get=function() return Core end}
NCPDPatrolDispatchJournalSystem={Get=function() return Dispatch end}
NCPDPatrolArrestSystem={Get=function() return Arrests end}
NCPDPatrolCareerSystem={Get=function() return Career end}
EPreventionHeatStage={Heat_0=0}
GameInstance.GetScriptableSystemsContainer=function()
 return {Get=function(_,name)
  if name=='PreventionSystem' then return {GetHeatStage=function() return CareerFixture.wanted and 1 or 0 end} end
 end}
end
function IsDefined(v) return v~=nil and v~=0 end
function StrBeginsWith(s,prefix) return s:sub(1,#prefix)==prefix end
function ArrayRemove(a,v) for i=0,a.n-1 do if a[i]==v then ArrayErase(a,i);return end end end
BrowserExtensionSystem={GetInstance=function() return FrameworkSystem end}
function FrameworkSystem:IsEnabled() return CareerFixture.befEnabled~=false end
function FrameworkSystem:ShouldBypassBrowserExtension() return CareerFixture.befBypass==true end

function CareerFixture:SetCount(n) Core.m_paidActivities={n=n} end
function CareerFixture:Reset(n)
 self:SetCount(n or 0);self.wanted=false;self.ready=true;self.notices={}
 player.attached=true;player.dead=false;player.combat=false
 wallet=0;paymentOK=true;transactionPresent=true
 Core.m_onDuty=false
 Career.m_claimedMilestones={n=0};Career.m_issuedRewards={n=0};Career.m_selectedPartner=0;Career:OnAttach()
 self.inventory={};self.itemCalls={};self.vehicleCalls={};self.unlockedVehicles={};self.failItems={}
 self.vehiclePresent=true;self.enableAccepted=true;self.unlockConfirmed=true
 Dispatch.m_paidDispatches={n=3};Dispatch.m_pendingDispatchRewards={n=1}
 Arrests.m_paidSuspects={n=7}
 FrameworkSystem.m_listeners={n=0};FrameworkSystem.m_blockedAddress={n=0}
 BrowserState:OnAttach();self.befEnabled=true;self.befBypass=false
end
local rewardTransaction={GiveItem=function(_,target,record,amount)
 assert(target==player and amount==1 and record~='Items.money')
 CareerFixture.itemCalls[#CareerFixture.itemCalls+1]=record
 if not paymentOK or CareerFixture.failItems[record] then return false end
 CareerFixture.inventory[record]=(CareerFixture.inventory[record] or 0)+amount
 return true
end}
GameInstance.GetTransactionSystem=function() if transactionPresent then return rewardTransaction end end
local rewardGarage={EnablePlayerVehicle=function(_,record,enable,despawn)
 assert(enable==true and despawn==false and record:find('Vehicle.',1,true)==1)
 CareerFixture.vehicleCalls[#CareerFixture.vehicleCalls+1]=record
 if not CareerFixture.enableAccepted then return false end
 if CareerFixture.unlockConfirmed then CareerFixture.unlockedVehicles[record]=true end
 return true
end,IsVehiclePlayerUnlocked=function(_,record) return CareerFixture.unlockedVehicles[record]==true end}
GameInstance.GetVehicleSystem=function() if CareerFixture.vehiclePresent then return rewardGarage end end
function NativeColor() return {Red=0,Green=0,Blue=0,Alpha=0} end
inkEAnchor={Fill='fill',Centered='center'}
textHorizontalAlignment={Center='center'}
function NativeWidget(kind)
 local w={kind=kind,children={},callbacks={}}
 function w:SetName(v) self.name=v end
 function w:SetFontFamily(v) self.font=v end
 function w:SetFontStyle(v) self.style=v end
 function w:SetFontSize(v) self.fontSize=v end
 function w:SetSize(x,y) self.width=x;self.height=y end
 function w:SetTintColor(v) self.color=v end
 function w:SetText(v) self.text=v end
 function w:SetInteractive(v) self.interactive=v end
 function w:SetFitToContent(v) self.fit=v end
 function w:SetAnchor(v) self.anchor=v end
 function w:SetAnchorPoint(x,y) self.anchorX=x;self.anchorY=y end
 function w:SetHorizontalAlignment(v) self.horizontal=v end
 function w:SetMargin(l,t,r,b) self.margin={l,t,r,b} end
 function w:Reparent(parent) parent.children[#parent.children+1]=self;self.parent=parent end
 function w:RegisterToCallback(event,listener,method) self.callbacks[event]={listener=listener,method=method} end
 function w:UnregisterFromCallback(event,listener,method)
  local cb=self.callbacks[event]
  if cb and cb.listener==listener and cb.method==method then self.callbacks[event]=nil end
 end
 return w
end
function NativeBrowserInit(listener,host)
 listener.m_siteData={};listener.host=host
 FrameworkBase.Init(listener,host)
 CareerFixture.registration[listener]=true
end
function NativeBrowserUninit(listener)
 FrameworkBase.Uninit(listener)
 CareerFixture.registration[listener]=nil
end
setmetatable(ListenerPrototype,{__index=FrameworkBase})
function NativeListener() return setmetatable({}, {__index=ListenerPrototype}) end
function wrappedMethod() CareerFixture.hostCalls=CareerFixture.hostCalls+1;return true end
function CareerFixture:Host()
 local device={attached=true,GetGame=function() return {} end,IsAttached=function(self) return self.attached end}
 local host={device=device,GetPlayerControlledObject=function() return player end,GetOwnerEntity=function() return device end}
 function host:GetCustomSites() return FrameworkSystem:GetSitesData(self.device) end
 function host:LoadPageByAddress(address)
  CareerFixture.loads[#CareerFixture.loads+1]=address
  self.page=FrameworkSystem:GetWebPage(address,self.device)
 end
 return setmetatable(host, {__index=HookPrototype})
end
function CareerFixture:Text(root)
 local text={};local function walk(w)
  if w.text then text[#text+1]=w.text end
  for _,child in ipairs(w.children) do walk(child) end
 end
 walk(root);return table.concat(text,'\n')
end
function CareerFixture:PageContentHeight(root)
 local function height(w)
  local h=w.height or 0
  if w.fit then
   h=0
   for _,child in ipairs(w.children) do
    if w.kind=='inkHorizontalPanel' then h=math.max(h,height(child)) else h=h+height(child) end
   end
  end
  return h+(w.margin and (w.margin[2]+w.margin[4]) or 0)
 end
 local body=root.children[2];local total=0
 for _,child in ipairs(body.children) do total=total+height(child) end
 return total
end
function CareerFixture:Click(widget,action)
 local cb=widget.callbacks.OnRelease
 if not cb then return false end
 local event={IsAction=function(_,name) return name==(action or 'click') end}
 return cb.listener[cb.method](cb.listener,event)
end
