-- Actual popup rendering and callbacks, using Codeware/ink only as boundaries.
local function key(p,number,action,modifier)
 local evt={GetKey=function() return number end,GetAction=function() return action end,
 IsControlDown=function() return modifier=='ctrl' end,IsAltDown=function() return modifier=='alt' end,
 IsShiftDown=function() return modifier=='shift' end}
 p:OnNumericKey(evt)
end
local function tap(p,k)
 key(p,k,EInputAction.IACT_Press);key(p,k,EInputAction.IACT_Release)
end
ResetTrunkFixture();local p=HoldTrunkMenu();assert(p and p:UseCursor())
assert(p.m_buttons.n==8 and p.container.width==1080 and p.container.height==330)
local rows={}
for i=0,p.m_buttons.n-1 do
 local card=p.m_buttons[i];rows[card.y]=(rows[card.y] or 0)+1
 assert(card.x>=0 and card.y>=0 and card.x+card.width<=p.container.width and card.y+card.height<=p.container.height)
end
assert(rows[70]==4 and rows[178]==4 and not p.m_buttons[6]:IsInteractive())
assert(p:NumberCommand(EInputKey.IK_8)==-1 and p:NumberCommand(EInputKey.IK_F)==-1)
for i=1,7 do assert(p:NumberCommand(EInputKey['IK_'..i])==i and p:NumberCommand(EInputKey['IK_NumPad'..i])==i) end
assert(p:NumberCommand(EInputKey.IK_9)==0)
-- A key held before opening, F/R, repeats, modified keys and covered popups
-- cannot select. A genuine press/release selects exactly one command.
key(p,EInputKey.IK_1,EInputAction.IACT_Release);assert(not Trunk:IsBusy())
tap(p,EInputKey.IK_F);tap(p,EInputKey.IK_R);assert(Trunk:IsOpenFor(vehicle))
for _,modifier in ipairs({'ctrl','alt','shift'}) do
 key(p,EInputKey.IK_1,1,modifier);key(p,EInputKey.IK_1,2,modifier);assert(not Trunk:IsBusy())
end
p.covered=true;tap(p,EInputKey.IK_1);assert(not Trunk:IsBusy());p.covered=false
tap(p,EInputKey.IK_1);assert(Trunk:IsBusy() and not Trunk:IsOpenFor(vehicle) and p.m_closing and not p.listening)
key(p,EInputKey.IK_7,1);key(p,EInputKey.IK_7,2);assert(Trunk:TakeCommand()==0,'Busy also released backup')
-- Full selection map: close is 9, no backup required for Busy/new dispatch.
for _,pair in ipairs({{3,3},{4,4},{5,5},{7,7},{9,0}}) do
 ResetTrunkFixture();SetBackupAssigned(true);p=HoldTrunkMenu();tap(p,EInputKey['IK_'..pair[1]])
 assert(Trunk:TakeCommand()==pair[2] and Trunk:TakeCommand()==0 and not Trunk:IsOpenFor(vehicle))
end
ResetTrunkFixture();p=HoldTrunkMenu();tap(p,EInputKey.IK_7);assert(Trunk:TakeCommand()==0)
ResetTrunkFixture();p=HoldTrunkMenu();tap(p,EInputKey.IK_2);assert(Trunk:IsRepairPending())
ResetTrunkFixture();p=HoldTrunkMenu();local before=#notices;tap(p,EInputKey.IK_6);assert(#notices==before+1)
-- Mouse selection shares the same exact-once native dispatch path.
ResetTrunkFixture();p=HoldTrunkMenu()
assert(p:OnOptionClicked({IsAction=function(_,v) return v=='click' end,GetCurrentTarget=function() return p.m_buttons[4] end}))
assert(Trunk:TakeCommand()==5 and Trunk:TakeCommand()==0)
-- Stale callbacks cannot select a later menu, and escape restores stash.
ResetTrunkFixture();local old=HoldTrunkMenu();old:Close();p=HoldTrunkMenu()
tap(old,EInputKey.IK_1);assert(Trunk:IsOpenFor(vehicle) and not Trunk:IsBusy())
p:Close();assert(not Trunk:IsOpenFor(vehicle) and not p.listening)
SetPopupManagerReady(false);assert(not Trunk:OpenMenu(vehicle));SetPopupManagerReady(true)
-- Closing or losing eligibility before asynchronous attach never calls into a
-- missing game controller. A rejected/busy native popup queue cannot trap stash.
ResetTrunkFixture();DeferPopupAttach(true);p=HoldTrunkMenu();assert(p and not p:IsPresented())
p:Close();assert(p.m_closing and not Trunk:IsOpenFor(vehicle))
p:CreateContainer();p:OnAttach();assert(not p.listening and not Trunk:IsOpenFor(vehicle))
p=HoldTrunkMenu();for _=1,8 do Trunk:Tick(.25) end
assert(not Trunk:IsOpenFor(vehicle) and p.m_closing)
DeferPopupAttach(false)
ResetTrunkFixture();local adds,removes=PopupListenerCounts();assert(adds==removes,'popup leaked input callbacks')
