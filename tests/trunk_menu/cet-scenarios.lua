-- Actual dispatch module; only HUD and game/native boundaries are mocked.
local hud={}
package.loaded.dispatch_hud={init=function() end,set=function(text,visible) hud.text=text; hud.visible=visible end,state=function() return 'fixture' end,shutdown=function() end}
local Dispatch=require('dispatch')
local candidates={}; local placements,clears,bonusTicks=0,0,0
local pausedUI=false; local fighting=false; local nativeDuty=true; local failClear=false
local gamePlayer={pos={x=10,y=10,z=0,w=1},GetWorldPosition=function(self) return self.pos end,
 IsAttached=function() return true end,IsDead=function() return false end,
 GetWorldOrientation=function() return {} end,IsInCombat=function() return fighting end}
local function candidate(id,x)
 return {id=id,phase='active',GetJournalPathHash=function(self) return self.id end,
 GetWorldPosition=function() return {x=x,y=10,z=0,w=1} end,
 GetVariant=function() return 'assault' end}
end
local dispatchPatrol={}
function dispatchPatrol:Version() return 17 end
function dispatchPatrol:HasWantedLevel() return false end
function dispatchPatrol:IsOnDuty() return nativeDuty end
function dispatchPatrol:IsDispatchMenuOpen() return pausedUI end
function dispatchPatrol:ClearDispatchWaypoints() if failClear then error('cleanup rejected') end; clears=clears+1 end
function dispatchPatrol:TickBonuses() bonusTicks=bonusTicks+1 end
function dispatchPatrol:GetDispatchCandidates() return candidates end
function dispatchPatrol:PlaceDispatchWaypoint() placements=placements+1; return {value=placements} end
function dispatchPatrol:NotifyDispatch(text) notices[#notices+1]={text=text} end
function dispatchPatrol:GetScannerPhase(hash,marker) return marker.phase end
gamedataMappinVariant={OutpostVariant='organized'}
gamedataMappinPhase={CompletedPhase='complete'}
Game={GetPlayer=function() return gamePlayer end,GetScriptableSystemsContainer=function()
 return {Get=function(_,name) if name=='NCPDPatrolDispatchJournalSystem' then return DispatchJournalBridge end end}
end}
GetPlayer=function() return gamePlayer end
NCPDPatrolSystem.Get=function() return dispatchPatrol end
local function tick(seconds) for _=1,seconds do Dispatch.update(1,true,nil,function() return dispatchPatrol end) end end
Dispatch.start(dispatchPatrol); Dispatch.setAutomatic(true); Dispatch.setBusy(true)
candidates={candidate(1,500),candidate(2,600),candidate(3,700)}
local time=Dispatch.seconds(); tick(120)
assert(not Dispatch.isActive() and Dispatch.seconds()==time and placements==0, 'BUSY admitted an automatic call')
assert(Dispatch.request(dispatchPatrol)); assert(Dispatch.isActive() and Dispatch.isBusy(), 'manual call blocked while BUSY')
tick(2); assert(Dispatch.isActive(), 'BUSY cancelled active call')
local assignedId=tonumber(Dispatch.state():match('POI=(%d+)'))
for _,v in ipairs(candidates) do if v.id==assignedId then gamePlayer.pos=v:GetWorldPosition();v.phase='complete' end end
tick(1); assert(not Dispatch.isActive() and Dispatch.completed()==1, 'BUSY stopped completion monitoring')
Dispatch.setBusy(false); tick(125); assert(Dispatch.isActive())
local placed=placements; assert(Dispatch.replace(dispatchPatrol)); assert(placements==placed+1 and Dispatch.isActive())
failClear=true; placed=placements; assert(not Dispatch.replace(dispatchPatrol)); assert(placements==placed, 'replacement spawned after failed waypoint cleanup')
failClear=false; Dispatch.start(dispatchPatrol); Dispatch.setBusy(true); assert(not Dispatch.cancel(dispatchPatrol))
assert(Dispatch.replace(dispatchPatrol)); assert(Dispatch.isActive())
Dispatch.finish(dispatchPatrol); assert(not Dispatch.isBusy() and not Dispatch.isActive())

-- Actual partner module: a failed deletion cannot clear its ID or spawn another.
local Partner=require('partner')
local managed={}; local createCount,deleteCount,unregisters=0,0,0
local deleteAccepted,entityReady=true,true
local nativeSupport={UnregisterPartner=function() unregisters=unregisters+1 end}
local system={IsReady=function() return entityReady end,
 IsManaged=function(_,id) return managed[id]==true end,
 CreateEntity=function(_,spec) assert(spec.persistState==false and spec.persistSpawn==false); createCount=createCount+1; managed[createCount]=true; return createCount end,
 DeleteEntity=function(_,id) assert(managed[id]); deleteCount=deleteCount+1; if not deleteAccepted then return false end; managed[id]=nil; return true end}
Game.GetDynamicEntitySystem=function() return system end
Game.GetScriptableSystemsContainer=function() return {Get=function(_,name)
 if name=='NCPDPatrolDispatchJournalSystem' then return DispatchJournalBridge end
 if name=='NCPDPatrolSupportSystem' then return nativeSupport end
end} end
TweakDB={GetRecord=function() return {} end}
TweakDBID={new=function(id) return id end}
DynamicEntitySpec={new=function() return {} end}
Vector4.new=function(x,y,z,w) return {x=x,y=y,z=z,w=w} end
local messages={}; local function status(text) messages[#messages+1]=text end
Partner.reset(); Partner.spawn(true,status); assert(createCount==1)
deleteAccepted=false
assert(not Partner.replace(true,status)); assert(createCount==1 and managed[1] and unregisters==0)
assert(not Partner.replace(true,status)); assert(createCount==1 and managed[1])
deleteAccepted=true; assert(Partner.replace(true,status))
assert(createCount==2 and not managed[1] and managed[2] and unregisters==1)
entityReady=false; assert(not Partner.replace(true,status)); assert(createCount==2 and managed[2])
entityReady=true; assert(not Partner.replace(false,status)); assert(managed[2])
-- A missing actor is not allowed to strand the replacement command forever.
managed[2]=nil; assert(Partner.replace(true,status)); assert(createCount==3 and managed[3])

-- Actual CET bridge consumes queued actions once and synchronizes BUSY before polling.
local queue=0; local reports={}; local takeCount=0; local tickCount=0
local nativeTrunk={Version=function() return 2 end,Tick=function() tickCount=tickCount+1 end,
 IsBusy=function() return true end,TakeCommand=function() takeCount=takeCount+1; local c=queue; queue=0; return c end,
 ReportCommand=function(_,text) reports[#reports+1]=text end,FinishSession=function() end}
Game.GetScriptableSystemsContainer=function() return {Get=function(_,name)
 if name=='NCPDPatrolDispatchJournalSystem' then return DispatchJournalBridge end
 if name=='NCPDPatrolTrunkSystem' then return nativeTrunk end
 if name=='NCPDPatrolSupportSystem' then return nativeSupport end
end} end
local TrunkCET=require('trunk')
Dispatch.start(dispatchPatrol)
queue=5; TrunkCET.update(0.1,true,dispatchPatrol,status); assert(Dispatch.isBusy() and Dispatch.isActive())
placed=placements; TrunkCET.update(0.1,true,dispatchPatrol,status); assert(placements==placed)
queue=4; TrunkCET.update(0.1,true,dispatchPatrol,status); assert(not Dispatch.isActive())
queue=4; TrunkCET.update(0.1,true,dispatchPatrol,status); assert(reports[#reports]:find('No active dispatch',1,true))
queue=3; local created=createCount; TrunkCET.update(0.1,true,dispatchPatrol,status)
assert(createCount==created+1 and reports[#reports]:find('New partner requested',1,true))
TrunkCET.update(0.1,true,dispatchPatrol,status); assert(createCount==created+1)
queue=5; local taken=takeCount; TrunkCET.update(0.1,false,dispatchPatrol,status); assert(takeCount==taken)
TrunkCET.reset(); assert(not Dispatch.isBusy())
