clock=0; notices={}; backupCalls=0; listenerAdds=0; listenerRemoves=0
onDuty=true; wanted=false; paused=false
function IsDefined(x) return x~=nil and x~=0 end
function Equals(a,b) return a==b end
function NotEquals(a,b) return a~=b end
function Cast(x) return x end
function CeilF(x) return math.ceil(x) end
function StringToName(x) return x end
function ArraySize(x) return x.n end
function GetLocalizedTextByKey(key) return key end
function GetPlayer() return player end
EngineTime={ToFloat=function(_,value) return value end}
GameInstance={GetEngineTime=function() return clock end}
TweakDBInterface={GetCName=function(_,id,default)
 assert(id=='Interactions.NCPDPatrolBackup.action'); return default
end}
ListenerAction={
 GetName=function(_,a) return a.name end,
 IsButtonJustPressed=function(_,a) return a.kind=='press' end,
 IsButtonJustReleased=function(_,a) return a.kind=='release' end,
}
Vector4={Distance=function(_,a,b) return math.sqrt((a.x-b.x)^2+(a.y-b.y)^2+(a.z-b.z)^2) end}
player={position={x=0,y=0,z=0},attached=true,dead=false,mounted=false}
function player:GetWorldPosition() return self.position end
function player:IsAttached() return self.attached end
function player:IsDead() return self.dead end
function player:RegisterInputListener(obj,name) assert(obj==Trunk and name=='Choice2'); listenerAdds=listenerAdds+1 end
function player:UnregisterInputListener(obj,name) assert(obj==Trunk and name=='Choice2'); listenerRemoves=listenerRemoves+1 end
local function car(id)
 local v={id=id,attached=true,owned=true,destroyed=false,position={x=0,y=2,z=0},refreshes=0,repairs=0}
 function v:IsAttached() return self.attached end
 function v:IsDestroyed() return self.destroyed end
 function v:IsCrowdVehicle() return false end
 function v:MatchVisualTag(tag) return self.noTrunk==true and tag=='NoTrunk' end
 function v:GetWorldPosition() return self.position end
 v.component={NCPDPatrolRefreshTrunk=function() v.refreshes=v.refreshes+1 end,
 NCPDPatrolRepairVehicle=function() v.repairs=v.repairs+1 end}
 function v:GetVehicleComponent() return self.component end
 return v
end
vehicle=car(1); otherVehicle=car(2)
local patrol={}
function patrol:IsOnDuty() return onDuty end
function patrol:HasWantedLevel() return wanted end
function patrol:IsDispatchMenuOpen() return paused end
function patrol:IsOwnedPoliceVehicle(v) return v and v.owned end
function patrol:NotifyDispatch(text,seconds) notices[#notices+1]={text=text,seconds=seconds} end
function patrol:GetRecordedScannerCount() return Ledger:GetRecordedScannerCount() end
local support={}
function support:CanUseTrunk(v) return onDuty and not wanted and v and v.owned and not v.destroyed and not player.mounted end
function support:RequestBackupAtTrunk(v) assert(v==vehicle); backupCalls=backupCalls+1; return true end
NCPDPatrolSystem={Get=function() return patrol end}
NCPDPatrolSupportSystem={Get=function() return support end}
function Trunk:GetGameInstance() return {} end
local function reset()
 Trunk:FinishSession(); Trunk:OnAttach(); onDuty=true; wanted=false; paused=false
 player.position={x=0,y=0,z=0}; player.mounted=false; player.dead=false; player.attached=true
 vehicle.attached=true; vehicle.owned=true; vehicle.destroyed=false; vehicle.noTrunk=false
 clock=clock+2; notices={}; backupCalls=0; Trunk:Tick(0.01)
end
local function input(kind,name) Trunk:OnAction({name=name or 'Choice2',kind=kind},{}) end
local function advance(seconds,step)
 step=step or 0.25
 for _=1,math.floor(seconds/step+0.00001) do clock=clock+step; Trunk:Tick(step) end
end
local function tap() input('press'); Trunk:BeginGesture(vehicle); clock=clock+0.10; input('release') end
local function hold() input('press'); Trunk:BeginGesture(vehicle); advance(0.5) end

-- Input before native interaction, interaction before input, and release before interaction.
reset(); input('press'); Trunk:BeginGesture(vehicle); assert(backupCalls==0)
clock=clock+0.1; input('release'); assert(backupCalls==1 and not Trunk:IsOpenFor(vehicle))
Trunk:BeginGesture(vehicle); assert(backupCalls==1, 'duplicate release event called backup twice')
reset(); Trunk:BeginGesture(vehicle); input('press'); clock=clock+0.1; input('release'); assert(backupCalls==1)
reset(); input('press'); clock=clock+0.1; input('release'); Trunk:BeginGesture(vehicle); assert(backupCalls==1)
reset(); hold(); assert(Trunk:IsOpenFor(vehicle) and backupCalls==0)
input('release'); Trunk:Select(0,vehicle); assert(Trunk:IsOpenFor(vehicle), 'opening release closed menu')
clock=clock+0.3; input('press'); Trunk:Select(0,vehicle); input('release')
assert(not Trunk:IsOpenFor(vehicle) and backupCalls==0)
reset(); input('press'); clock=clock+0.75; input('release'); Trunk:BeginGesture(vehicle)
assert(Trunk:IsOpenFor(vehicle) and backupCalls==0, 'late native hold callback requested backup')
reset(); input('press','Reload'); advance(1); input('release','Reload'); assert(backupCalls==0)
reset(); input('press'); advance(1); input('release'); assert(backupCalls==0, 'unrelated R press authorized trunk')
reset(); Trunk:BeginGesture(vehicle); advance(0.5); assert(backupCalls==0, 'missing input must fail closed')
assert(notices[#notices].text:find('input not received',1,true))
reset(); input('press'); Trunk:BeginGesture(vehicle); player.position.x=10; advance(0.5); input('release')
assert(backupCalls==0 and not Trunk:IsOpenFor(vehicle))
reset(); input('press'); Trunk:BeginGesture(vehicle); paused=true; advance(0.5); input('release'); paused=false
assert(backupCalls==0 and not Trunk:IsOpenFor(vehicle))
reset(); hold(); player.mounted=true; Trunk:Tick(0.1); assert(not Trunk:IsOpenFor(vehicle))
reset(); player.dead=true; tap(); assert(backupCalls==0)
reset(); vehicle.owned=false; tap(); assert(backupCalls==0)
reset(); vehicle.noTrunk=true; tap(); assert(backupCalls==0)
reset(); vehicle.destroyed=true; tap(); assert(backupCalls==0)

-- Selection is scoped to the authorized open trunk, command queue consumes once.
reset(); Trunk:Select(3,vehicle); assert(Trunk:TakeCommand()==0)
hold(); Trunk:Select(3,otherVehicle); assert(Trunk:TakeCommand()==0)
Trunk:Select(3,vehicle); assert(Trunk:TakeCommand()==3 and Trunk:TakeCommand()==0)
input('release'); clock=clock+0.3; hold(); Trunk:Select(1,vehicle)
assert(Trunk:IsBusy()); input('release'); clock=clock+0.3; hold(); Trunk:Select(1,vehicle); assert(not Trunk:IsBusy())
-- A second queued operation cannot replace the first operation before CET polls it.
input('release'); clock=clock+0.3; hold(); Trunk:Select(4,vehicle)
input('release'); clock=clock+0.3; hold(); Trunk:Select(5,vehicle)
assert(Trunk:TakeCommand()==4 and Trunk:TakeCommand()==0)

-- The same 10-second request survives mounting and never switches to another car.
reset(); local repaired=vehicle.repairs; local otherRepaired=otherVehicle.repairs
assert(Trunk:RequestRepair(vehicle)); advance(5); assert(Trunk:GetRepairSeconds()==5)
assert(not Trunk:RequestRepair(otherVehicle)); assert(Trunk:GetRepairSeconds()==5)
player.mounted=true; advance(4.75); assert(vehicle.repairs==repaired)
paused=true; advance(20); assert(vehicle.repairs==repaired and Trunk:IsRepairPending())
paused=false; advance(0.25); assert(vehicle.repairs==repaired+1 and not Trunk:IsRepairPending())
advance(15); assert(vehicle.repairs==repaired+1 and otherVehicle.repairs==otherRepaired)
reset(); repaired=vehicle.repairs; assert(Trunk:RequestRepair(vehicle)); vehicle.attached=false; advance(10)
assert(vehicle.repairs==repaired and not Trunk:IsRepairPending())
reset(); assert(Trunk:RequestRepair(vehicle)); vehicle.destroyed=true; advance(10); assert(not Trunk:IsRepairPending())
reset(); assert(Trunk:RequestRepair(vehicle)); wanted=true; advance(10)
assert(not Trunk:IsRepairPending() and not Trunk:IsBusy() and Trunk:TakeCommand()==0)
reset(); assert(Trunk:RequestRepair(vehicle)); advance(3); local removes=listenerRemoves
Trunk:OnRestored(1,1); assert(listenerRemoves==removes, 'load called old listener')
assert(not Trunk:IsRepairPending() and not Trunk:IsOpenFor(vehicle))

reset(); hold(); Trunk:Select(3,vehicle); assert(Trunk:RequestRepair(vehicle)); Trunk:SetBusy(true)
onDuty=false; Trunk:Tick(0.1)
assert(not Trunk:IsRepairPending() and not Trunk:IsBusy() and Trunk:TakeCommand()==0 and not Trunk:IsOpenFor(vehicle))

-- Stats read the existing scanner ledger without money/ledger writes.
reset()
for _,case in ipairs({{0,10},{9,10},{10,20},{19,20},{20,40},{39,40},{40,60},{80,100},{100,120},{120,140}}) do
 Ledger.m_paidActivities={n=case[1]}; Trunk:ShowStats()
 local text=notices[#notices].text
 assert(text:find('completions: '..case[1]..' |',1,true))
 assert(text:find('Next milestone: '..case[2]..' |',1,true))
 assert(Ledger.m_paidActivities.n==case[1])
end

-- Every option resolves a separate record and caption, not its inherited label.
DeviceActionPropertyFunctions={SetUpProperty_Bool=function() return {} end}
InteractionChoiceCaption={Clear=function() end,AddTextPart=function() end}
function MenuAction:CreateActionWidgetPackage() end
function MenuAction:CreateInteraction() self.interactionChoice={captionParts={}} end
local records={}
for command=0,6 do
 MenuAction:Initialize(command,false)
 local record=MenuAction:GetTweakDBChoiceRecord()
 assert(not records[record]); records[record]=true
 assert(MenuAction:GetCommand()==command and MenuAction.actionName==record)
 assert(MenuAction.interactionChoice.caption:find('NCPDPatrol-',1,true))
end
MenuAction:Initialize(1,true); assert(MenuAction:GetTweakDBChoiceRecord()=='NCPDPatrolAvailable')

-- Execute the actual repair wrapper: health routine, four tires and visual resets.
local repairedParts={}; local tires={}; local body,glass,health,fx,visual=0,0,0,0,0
AnimationControllerComponent={SetInputFloat=function(_,v,key,value) assert(v==vehicle and value==0); repairedParts[key]=true end}
function Repair:GetVehicle() return vehicle end
function Repair:RepairVehicle() health=health+1 end
function Repair:UpdateDamageEngineEffects() fx=fx+1 end
function Repair:VehicleVisualDestructionSetup() visual=visual+1 end
function vehicle:ToggleBrokenTire(index,state) assert(not state and not tires[index]); tires[index]=true end
function vehicle:DestructionResetGrid() body=body+1 end
function vehicle:DestructionResetGlass() glass=glass+1 end
vehicle.attached=true; vehicle.destroyed=false; Repair:NCPDPatrolRepairVehicle()
assert(health==1 and fx==1 and visual==1 and body==1 and glass==1)
assert(tires[0] and tires[1] and tires[2] and tires[3] and repairedParts.hood_destruction)
vehicle.destroyed=true; Repair:NCPDPatrolRepairVehicle(); assert(health==1)
