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
function Core:NotifyCareerReward(amount,threshold) CareerFixture.notices[#CareerFixture.notices+1]={amount=amount,threshold=threshold} end
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

function CareerFixture:SetCount(n) Core.m_paidActivities={n=n} end
function CareerFixture:Reset(n)
 self:SetCount(n or 0);self.wanted=false;self.ready=true;self.notices={}
 player.attached=true;player.dead=false;player.combat=false
 wallet=0;paymentOK=true;transactionPresent=true
 Core.m_onDuty=false
 Career.m_claimedMilestones={n=0};Career:OnAttach()
 Dispatch.m_paidDispatches={n=3};Dispatch.m_pendingDispatchRewards={n=1}
 Arrests.m_paidSuspects={n=7}
end
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
 listener.m_siteData={};listener.host=host;CareerFixture.registration[listener]=true
end
function NativeBrowserUninit(listener) CareerFixture.registration[listener]=nil end
function ListenerPrototype:LoadPageByAddress(address)
 CareerFixture.loads[#CareerFixture.loads+1]=address
 self.host.page=self:GetWebPage(address)
end
function NativeListener() return setmetatable({}, {__index=ListenerPrototype}) end
function wrappedMethod() CareerFixture.hostCalls=CareerFixture.hostCalls+1;return true end
function CareerFixture:Host()
 return setmetatable({GetPlayerControlledObject=function() return player end}, {__index=HookPrototype})
end
function CareerFixture:Text(root)
 local text={};local function walk(w)
  if w.text then text[#text+1]=w.text end
  for _,child in ipairs(w.children) do walk(child) end
 end
 walk(root);return table.concat(text,'\n')
end
function CareerFixture:Click(widget,action)
 local cb=widget.callbacks.OnRelease
 if not cb then return false end
 local event={IsAction=function(_,name) return name==(action or 'click') end}
 return cb.listener[cb.method](cb.listener,event)
end
