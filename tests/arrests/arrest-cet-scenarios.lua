-- Native boundaries deliberately expose no clip telemetry or functional-test callbacks.
local Module=require('arrest')
local player=supportActor(1001,'player',0,0,0)
supportPlayer=player;wantedHeat=0;pins=list();Patrol:ResetSession();Patrol:BeginShift();ArrestNative:OnRestored(1,1)
local helpers,managed,bound,inWS,flags={},{},{},{},{}
local nextID,clock=5000,0
local deleted,played,jumps,signals,results={},{},{},{},{}
local failDeletes=0
local resultMode,entryMode='none','active'
local bankReady,resourceAvailable,treeAvailable,missingComponent=true,true,true,false
local loopAvailable,loopReady=true,true
local loadFailure,rejectToken=false,false
local tokens,loopTokens,loadCount={},{},0
local dynamic={IsReady=function() return true end}
function dynamic:CreateEntity(spec)
 assert(spec.recordID==nil and spec.templatePath=='base\\ncpd_patrol\\arrest_workspot.ent')
 assert(not spec.persistState and not spec.persistSpawn and not spec.alwaysSpawned and spec.spawnInView and spec.active)
 nextID=nextID+1
 local helper=supportActor(nextID,'private helper',spec.position.x,spec.position.y,spec.position.z)
 helper.orientation=spec.orientation
 function helper:FindComponentByType(kind)
  assert(kind=='workWorkspotResourceComponent')
  if not missingComponent then return {name='NCPDPatrolArrestLoop'} end
 end
 function helper:OnPlayInDeviceCallbackEvent(event) return ResultReceiver.OnPlayInDeviceCallbackEvent(self,event) end
 helpers[nextID]=helper;managed[nextID]=true
 return helper:GetEntityID()
end
function dynamic:GetEntity(id) return helpers[id.hash] end
function dynamic:IsManaged(id) return managed[id.hash]==true end
function dynamic:DeleteEntity(id)
 assert(id.hash>=5001,'ambient suspect deletion attempted')
 if failDeletes>0 then failDeletes=failDeletes-1;return false end
 if helpers[id.hash] then helpers[id.hash].attached=false end
 local actor=bound[id.hash]
 if actor then inWS[actor.id.hash]=false;flags[actor.id.hash]={isActive=false,entering=false,exiting=false} end
 deleted[#deleted+1]=id.hash;managed[id.hash]=nil;helpers[id.hash]=nil;bound[id.hash]=nil
 return true
end
local ws={}
function ws:IsActorInWorkspot(npc) return inWS[npc.id.hash]==true end
function ws:GetExtendedInfo(npc) return flags[npc.id.hash] or {isActive=false,entering=false,exiting=false} end
function ws:GetDeviceUser(id) error('legacy device lookup must not be required') end
function ws:GetWorkspotInstance(id) error('legacy instance lookup must not be required') end
function ws:SendDebugCommandFunctionalTests(...) error('functional-test callback registration must not be required') end
function ws:StopInDevice(...) error('unverified ambient actor stop attempted') end
function ws:PlayInDeviceSimple(helper,npc,free,actorComp,deviceComp,sync,slideTime,behaviour,recipient)
 assert(not npc:IsRagdollEnabled(),'workspot requested while physical ragdoll still owns the suspect')
 assert(not free and actorComp=='NCPDPatrolArrestLoop' and recipient==helper)
 if npc.physicsDisabled then
  assert(slideTime==.5 and behaviour==1,'recovered ragdoll did not use native ground-anchor sliding')
  if not npc.rejectWorkspotPlacement then
   npc.position=Vector4.new(helper.position.x,helper.position.y,helper.position.z+(npc.workspotRootHeight or 0),1)
  end
 else assert(slideTime==0 and behaviour==0,'working animated-down path changed') end
 played[#played+1]={helper=helper,npc=npc,time=clock};bound[helper.id.hash]=npc
 inWS[npc.id.hash]=entryMode~='none'
 flags[npc.id.hash]={isActive=entryMode=='active' or entryMode=='exiting',entering=entryMode=='entering',exiting=entryMode=='exiting'}
 if resultMode~='none' then results[#results+1]={helper=helper,success=resultMode=='success'} end
end
function ws:SendJumpToAnimEnt(...) error('idle names must not be used as leaf animation jumps') end
function ws:SendJumpCommandEnt(npc,entry,instant)
 assert(instant==true and entry==2)
 jumps[#jumps+1]={npc=npc,time=clock,entry=entry}
end
function ws:SendPlaySignal(...) error('do not advance the infinite loop with a play signal') end
local SourceTree={rootEntry={idleAnim='lie_ground_0__2h_back_handcuffs_a__01',list={
 {animName='lie_ground_0__2h_back_handcuffs_a__01__shuffle__01'},
 {animName='lie_ground_0__2h_back_handcuffs_a__01__to__stand__01'}
}},finalAnimsets={
 {rig='native male rig',animations={hash='source-male-hash'},loadingHandles={'native male animations'}},
 {rig='native female rig',animations={hash='source-female-hash'},loadingHandles={'native female animations'}}},
 initialCanUseExits=true,statusEffectID='native status must not be copied',tags={'native tag'},
 customTransitionAnims={'native standing transition'},globalProps={'native cuffs'},initialActions={'native item action'},
 itemsPolicy=7,propsPlaySyncAnim=false,workspotRig='native rig'}
local PrivateResource={workspotTree=PrivateLoopTree}
local depot={ArchiveExists=function() return true end,ResourceExists=function(_,path)
 return resourceAvailable and (path~='base\\ncpd_patrol\\arrest_lying_loop.workspot' or loopAvailable)
end}
function depot:LoadResource(path)
 local isLoop=path=='base\\ncpd_patrol\\arrest_lying_loop.workspot'
 assert(isLoop or path=='base\\workspots\\common\\ground\\generic__lie_ground_lean_front_handcuffs_a__aggressive__01.workspot')
 loadCount=loadCount+1;if rejectToken then return nil end
 local ready=(isLoop and loopReady) or (not isLoop and bankReady)
 local token={loaded=ready,finished=ready or (not isLoop and loadFailure),failed=not isLoop and loadFailure}
 function token:IsLoaded() return self.loaded end
 function token:IsFinished() return self.finished end
 function token:IsFailed() return self.failed end
 function token:GetResource()
  assert(self.loaded,'read before asynchronous load completed')
  if isLoop then return PrivateResource end
  if not treeAvailable then return {} end
  return {workspotTree=SourceTree}
 end
 if isLoop then loopTokens[#loopTokens+1]=token else tokens[#tokens+1]=token end;return token
end
ResourceHelper=setmetatable({},{__index=function() error('ResourceHelper cannot load the async component field') end})
CName={new=function(v)return v end};DynamicEntitySpec={new=function()return {} end};WorkspotSlidingBehaviour={DontPlayAtResourcePosition=0,PlayAtResourcePosition=1}
local looked
local navOK,pathOK,navZ,centerBlocked=true,true,0,false
local floorMode='flat'
Vector4.new=function(x,y,z,w)
 return setmetatable({x=x,y=y,z=z,w=w},{__index=function(t,k)return rawget(t,string.lower(k))end})
end
worldNavigationRequestStatus={OK=1}
AINavigationSystem={HasPathFromAtoB=function()return pathOK end}
Game={GetPlayer=function()return player end,GetDynamicEntitySystem=function()return dynamic end,
 GetWorkspotSystem=function()return ws end,GetResourceDepot=function()return depot end,
 GetAINavigationSystem=function()return {FindPointInSphereForCharacter=function(_,point,radius,npc)
  local denied=centerBlocked and radius==.6 and point.x==npc.position.x and point.y==npc.position.y
  return {status=navOK and not denied and 1 or 0,point=Vector4.new(point.x,point.y,point.z+navZ,1)}
 end}end,
 GetSpatialQueriesSystem=function() return {SyncRaycastByCollisionGroup=function(_,from,to,group,staticOnly,dynamicOnly)
  assert(group=='Static' and staticOnly and not dynamicOnly)
  if floorMode=='missing' then return false,nil end
  local height,normal=0,1
  if floorMode=='curb' and from.x<1.35 then height=from.y>0 and .1 or 0 end
  if floorMode=='steep' then normal=.5 end
  return true,{position=Vector4.new(from.x,from.y,height,1),normal=Vector4.new(0,0,normal,0)}
 end} end,
 GetScriptableSystemsContainer=function()return {Get=function()return ArrestNative end}end,
 GetTargetingSystem=function()return {GetLookAtObject=function()return looked end}end}
GameInstance.GetWorkspotSystem=function()return ws end
local function step(count,paused)
 for _=1,count do
  clock=clock+0.25
  local pending=results;results={}
  for _,event in ipairs(pending) do event.helper:OnPlayInDeviceCallbackEvent({wasPlayInDeviceSuccessful=event.success}) end
  Module.update(0.25,Patrol:IsOnDuty(),paused==true)
 end
end
local function secure(npc)
 assert(ArrestNative:StartArrest(npc));step(8);assert(ArrestNative:GetStage()==2);step(1)
 return helpers[nextID],ArrestNative.m_playback
end
local function releasePaid()
 player.position.x=80;step(4);player.position.x=0
 assert(next(managed)==nil)
end
Module.reset()
-- Reported state: native active, no callback/clip data. Registration now credits
-- a clean start and 1.5 s continuous activation, not an observed animation name.
local a=arrestSuspect(1002);local bank=wallet;local count=ArrestNative:GetPaidArrests()
looked=a;local refresh=a.refreshes;step(2);step(5);assert(a.refreshes==refresh+1)
local helper,proof=secure(a)
assert(#played==1 and not proof:HasResult() and wallet==bank)
step(5);assert(wallet==bank and #jumps==1,'fallback registered or restarted playback before 1.5 s stable activation')
step(1);assert(wallet==bank+250 and ArrestNative:IsArrested(a) and ArrestNative:GetPaidArrests()==count+1)
local paidBank=wallet;step(80)
assert(wallet==paidBank and managed[helper.id.hash],'paid helper timed out or repeated payment')
assert(a.health==2 and a.effects['BaseStatusEffect.Defeated'],'arrest mutated health/life status')
local previous
local requests=0
for _,request in ipairs(jumps) do
 if request.npc==a then
  if previous then assert(request.time-previous>=1,'lying selection exceeded one per second') end
  previous=request.time;requests=requests+1
 end
end
assert(requests==1 and #signals==0,'native infinite loop was repeatedly jumped or advanced')
assert(PrivateLoopTree.rootEntry.list[1].loopInfinitely and not PrivateLoopTree.initialCanUseExits)
assert(#PrivateLoopTree.finalAnimsets==2 and PrivateLoopTree.finalAnimsets[1].animations.hash=='source-male-hash')
assert(SourceTree.initialCanUseExits and SourceTree.statusEffectID=='native status must not be copied' and SourceTree.customTransitionAnims[1]=='native standing transition')
assert(PrivateLoopTree.statusEffectID==0 and PrivateLoopTree.tags[1]=='NCPDPatrolArrestLoop' and #PrivateLoopTree.customTransitionAnims==0,'source behavior leaked into private loop')
assert(receiptMessages[#receiptMessages].message=='NCPD ARREST REGISTERED | +EUR$250')
-- A production success belongs to one private recipient; it still requires
-- native activation. Duplicate and late result events cannot award money.
resultMode='success'
local b=arrestSuspect(1003);bank=wallet
local bh,bp=secure(b);step(2);assert(wallet==bank)
step(1);assert(wallet==bank+250 and bp:HasResult() and bp:ResultSucceeded())
assert(not bh:OnPlayInDeviceCallbackEvent({wasPlayInDeviceSuccessful=false}))
step(8);assert(wallet==bank+250)
-- Rejected native requests veto the same active flags that permit fallback.
resultMode='failure'
local c=arrestSuspect(1004);bank=wallet
secure(c);step(4);assert(wallet==bank and not ArrestNative:IsArrested(c) and ArrestNative:GetStage()==0)
-- Wrong recipient, wrong actor/token, and an unregistered proof cannot confirm.
resultMode='none'
local d=arrestSuspect(1005);bank=wallet
local dh,dp=secure(d);local token=ArrestNative:GetToken()
assert(not helper:OnPlayInDeviceCallbackEvent({wasPlayInDeviceSuccessful=false}))
assert(not dp:HasResult())
step(3);assert(wallet==bank)
assert(not ArrestNative:ConfirmActivatedArrest(d,token+1,dp))
assert(not ArrestNative:ConfirmActivatedArrest(arrestSuspect(1006),token,dp))
assert(not ArrestNative:ConfirmActivatedArrest(d,token,NCPDPatrolArrestPlayback.new()))
assert(dh:OnPlayInDeviceCallbackEvent({wasPlayInDeviceSuccessful=true}))
step(1);assert(wallet==bank+250)
-- Helper deletion retries retain IDs; no actor StopInDevice call is used.
failDeletes=1;releasePaid();assert(wallet==bank+250)
-- A void request or a positive result with no settled native entry cannot pay.
for _,mode in ipairs({'none','entering','inactive','exiting'}) do
 resultMode='success';entryMode=mode
 local npc=arrestSuspect(1010+#played);bank=wallet;local before=#jumps
 secure(npc);step(40)
 assert(wallet==bank and not ArrestNative:IsArrested(npc) and ArrestNative:GetStage()==0,'unsettled native playback registered')
 assert(#jumps<=before+1,'hold attempted without active native playback')
end
resultMode='none';entryMode='active'
-- Menu time pauses both securing and activation; hitch-sized deltas are ignored.
local e=arrestSuspect(1101);bank=wallet
assert(ArrestNative:StartArrest(e));local before=#played;step(40,true)
assert(ArrestNative:GetStage()==1 and #played==before)
step(8);step(1);step(40,true);assert(wallet==bank)
Module.update(10,true,false);assert(wallet==bank)
step(5);assert(wallet==bank);step(1);assert(wallet==bank+250)
releasePaid()
-- Out-of-range, death and wanted terminate pending activation without payment.
for case=1,3 do
 local npc=arrestSuspect(1110+case);bank=wallet
 secure(npc);step(1)
 if case==1 then player.position.x=20 elseif case==2 then npc.dead=true else wantedHeat=1 end
 step(2);player.position.x=0;wantedHeat=0
 assert(wallet==bank and not ArrestNative:IsArrested(npc) and ArrestNative:GetStage()==0)
end
-- An actor already using a workspot cannot arm our playback. A race while the
-- resource is loading is also caught immediately before the play request.
local foreign=arrestSuspect(1120);inWS[foreign.id.hash]=true;flags[foreign.id.hash]={isActive=true,entering=false,exiting=false}
bank=wallet;before=#played
assert(ArrestNative:StartArrest(foreign));step(12)
assert(wallet==bank and #played==before)
inWS[foreign.id.hash]=false
bankReady=false
local race=arrestSuspect(1121);bank=wallet;before=#played
secure(race);local pending=tokens[#tokens];local loads=loadCount
step(4);assert(loadCount==loads and #played==before)
inWS[race.id.hash]=true;flags[race.id.hash]={isActive=true,entering=false,exiting=false}
pending.loaded=true;pending.finished=true;bankReady=true;step(4)
assert(wallet==bank and #played==before and inWS[race.id.hash],'foreign native playback was replaced')
inWS[race.id.hash]=false
-- A delayed resource token waits without playback and then completes normally.
bankReady=false
local delayed=arrestSuspect(1122);bank=wallet;before=#played
secure(delayed);pending=tokens[#tokens];loads=loadCount;step(4)
assert(#played==before and loadCount==loads and wallet==bank)
pending.loaded=true;pending.finished=true;bankReady=true;step(8)
assert(wallet==bank+250 and ArrestNative:IsArrested(delayed))
releasePaid()
-- Missing assets/components/tree and failed/refused/empty-finished tokens cannot
-- enter a workspot or generate a payout.
for case=1,6 do
 resourceAvailable=case~=1;missingComponent=case==2;treeAvailable=case~=3
 bankReady=case<4;loadFailure=case==4;rejectToken=case==5
 local npc=arrestSuspect(1130+case);bank=wallet;before=#played
 assert(ArrestNative:StartArrest(npc));step(10)
 if case==6 then tokens[#tokens].finished=true end
 step(30)
 assert(wallet==bank and #played==before and ArrestNative:GetStage()==0,'invalid resource played or paid')
 resourceAvailable,missingComponent,treeAvailable,bankReady,loadFailure,rejectToken=true,false,true,true,false,false
end
-- A paid body's revival or entry into an exit releases the helper, preserving
-- the reward. The keeper cannot restore life state or re-enter a finished spot.
for case=1,2 do
 local npc=arrestSuspect(1140+case);local h=secure(npc);step(6)
 assert(ArrestNative:IsArrested(npc));bank=wallet;local jumpCount=#jumps
 if case==1 then npc.effects={} else flags[npc.id.hash].exiting=true end
 step(12)
 assert(wallet==bank and #jumps==jumpCount and not managed[h.id.hash])
end
-- A world reset never deletes or addresses old-world actors/helpers. Saved paid
-- identities survive, and a result for an old helper cannot reject a new one.
local old=arrestSuspect(1150);local oldHelper=secure(old)
local deletedBefore=#deleted;bank=wallet;count=ArrestNative:GetPaidArrests()
helpers,managed,bound,inWS,flags,results={},{},{},{},{},{}
ArrestNative:OnRestored(1,1);Module.reset();step(4)
assert(#deleted==deletedBefore and wallet==bank and ArrestNative:GetPaidArrests()==count and ArrestNative:IsArrested(a))
local fresh=arrestSuspect(1151);local freshHelper=secure(fresh)
assert(not oldHelper:OnPlayInDeviceCallbackEvent({wasPlayInDeviceSuccessful=false}))
step(6);assert(wallet==bank+250 and ArrestNative:IsArrested(fresh))
releasePaid()
-- The private loop is an independent required asset. Missing or pending loop
-- data cannot fall back to the vanilla tree with its standing transitions.
Module.reset();loopAvailable=false
local noLoop=arrestSuspect(1160);bank=wallet;before=#played
assert(ArrestNative:StartArrest(noLoop));step(12)
assert(wallet==bank and #played==before);loopAvailable=true
Module.reset();loopReady=false
local slowLoop=arrestSuspect(1161);bank=wallet;before=#played
secure(slowLoop);local loopToken=loopTokens[#loopTokens];local loadsBefore=loadCount
step(4);assert(wallet==bank and #played==before and loadCount==loadsBefore)
loopToken.loaded=true;loopToken.finished=true;loopReady=true;step(8)
assert(wallet==bank+250 and ArrestNative:IsArrested(slowLoop));releasePaid()
-- Guard malformed loop topology and unreadable source bindings before playback.
for case=1,2 do
 Module.reset();bank=wallet;before=#played
 local originalBindings=SourceTree.finalAnimsets
 if case==1 then PrivateLoopTree.initialCanUseExits=true else SourceTree.finalAnimsets={} end
 local npc=arrestSuspect(1161+case);secure(npc);step(20)
 assert(wallet==bank and #played==before and not ArrestNative:IsArrested(npc))
 PrivateLoopTree.initialCanUseExits=false;SourceTree.finalAnimsets=originalBindings
end
-- A physical living ragdoll must release physics and reach supported nearby
-- ground before a workspot request can occur. Health/defeat are never rewritten.
Module.reset();local rag=arrestSuspect(1170);rag.ragdoll=true
bank=wallet;before=#played;centerBlocked=true
local health=rag.health;local defeats=rag.effects;local healBefore=#healCalls;local godBefore=#godCalls
assert(ArrestNative:StartArrest(rag));step(8)
assert(rag:IsRagdolling() and #played==before and wallet==bank)
step(1);assert(rag.physicsDisabled and ArrestNative:OwnsPosePhysics(rag) and #played==before)
local recoveryToken=ArrestNative:GetToken()
for _,point in ipairs({Vector4.new(4,0,0,1),Vector4.new(1,0,1,1),Vector4.new(0/0,0,0,1)}) do
 assert(not ArrestNative:PlaceRecoveredSuspect(rag,recoveryToken,point) and not rag.teleports)
end
assert(not ArrestNative:PlaceRecoveredSuspect(rag,recoveryToken-1,Vector4.new(1,0,0,1)))
step(1);assert(rag.teleports==1 and rag.position.x==1.75 and #played==before)
step(1);assert(#played==before+1 and wallet==bank and not rag:IsRagdolling())
step(6);assert(wallet==bank+250 and ArrestNative:IsArrested(rag) and rag.physicsDisabled)
assert(rag.health==health and rag.effects==defeats and #healCalls==healBefore and #godCalls==godBefore)
releasePaid();assert(not rag.physicsDisabled and not ArrestNative:OwnsPosePhysics(rag))
assert(rag.physicsEvents[#rag.physicsEvents].kind=='restore');centerBlocked=false
-- Animated ragdoll physics uses a separate native flag; it must release too.
Module.reset();local animatedPhysics=arrestSuspect(1180);animatedPhysics.animatedRagdoll=true
bank=wallet;assert(ArrestNative:StartArrest(animatedPhysics));step(20)
assert(wallet==bank+250 and ArrestNative:IsArrested(animatedPhysics) and not animatedPhysics:IsRagdollEnabled())
assert(animatedPhysics.physicsDisabled and animatedPhysics.health==2);releasePaid()
-- A navigable current spot may straddle a curb. Evaluate the complete set and
-- prefer the nearby flatter real collision footprint, not the first nav hit.
Module.reset();local uneven=arrestSuspect(1181);uneven.ragdoll=true;floorMode='curb'
bank=wallet;assert(ArrestNative:StartArrest(uneven));step(22)
assert(wallet==bank+250 and ArrestNative:IsArrested(uneven) and uneven.position.x==1.75)
releasePaid();floorMode='flat'
-- Capsule/root height need not equal the floor. A delayed/rejected teleport
-- must not prevent the native workspot from completing bounded placement.
Module.reset();local rooted=arrestSuspect(1182);rooted.ragdoll=true;rooted.rejectTeleport=true;rooted.workspotRootHeight=.8
centerBlocked=true;bank=wallet;assert(ArrestNative:StartArrest(rooted));step(22)
assert(rooted.teleports==1 and rooted.position.x==1.75 and wallet==bank+250 and ArrestNative:IsArrested(rooted))
releasePaid();centerBlocked=false
-- Native playback alone cannot pay when the recovered actor is still outside
-- the chosen footprint. Retain the physics lease only until helper cleanup.
Module.reset();local misplaced=arrestSuspect(1183);misplaced.ragdoll=true
misplaced.rejectTeleport=true;misplaced.rejectWorkspotPlacement=true;centerBlocked=true
bank=wallet;assert(ArrestNative:StartArrest(misplaced));step(45)
assert(wallet==bank and not ArrestNative:IsArrested(misplaced) and not ArrestNative:OwnsPosePhysics(misplaced))
centerBlocked=false
-- Missing collision or a steep surface is not safe, even with a good navmesh.
for _,mode in ipairs({'missing','steep'}) do
 Module.reset();floorMode=mode;local npc=arrestSuspect(1184);npc.ragdoll=true;bank=wallet;before=#played
 assert(ArrestNative:StartArrest(npc));step(20)
 assert(wallet==bank and #played==before and not npc.physicsDisabled and not npc.teleports)
end
floorMode='flat'
-- Unsupported, unreachable or vertically remote points cannot trigger physics,
-- teleportation, playback or payment. Setup failure releases the reservation.
for failure=1,3 do
 Module.reset();local npc=arrestSuspect(1170+failure);npc.ragdoll=true
 navOK=failure~=1;pathOK=failure~=2;navZ=failure==3 and 2 or 0
 bank=wallet;before=#played
 assert(ArrestNative:StartArrest(npc));step(16)
 assert(wallet==bank and #played==before and not npc.physicsDisabled and not npc.teleports and ArrestNative:GetStage()==0)
 assert(npc:IsRagdolling() and npc.health==2)
end
navOK,pathOK,navZ=true,true,0
Module.reset();local stuck=arrestSuspect(1175);stuck.ragdoll=true;stuck.stuckRagdoll=true
bank=wallet;before=#played;assert(ArrestNative:StartArrest(stuck));step(28)
assert(wallet==bank and #played==before and not stuck.physicsDisabled and not ArrestNative:OwnsPosePhysics(stuck))
-- Death during recovery cannot turn physics preparation into a paid arrest.
Module.reset();local dying=arrestSuspect(1176);dying.ragdoll=true
bank=wallet;before=#played;assert(ArrestNative:StartArrest(dying));step(9);dying.dead=true;step(8)
assert(wallet==bank and #played==before and not dying.physicsDisabled and not dying.teleports)
-- A pickup after payment owns the disabled body physics until vanilla unmount.
Module.reset();local carried=arrestSuspect(1177);carried.ragdoll=true
assert(ArrestNative:StartArrest(carried));step(20);assert(ArrestNative:IsArrested(carried))
carried.carried=true;flags[carried.id.hash].exiting=true;bank=wallet;step(4)
assert(wallet==bank and carried.physicsDisabled and not ArrestNative:OwnsPosePhysics(carried))
assert(carried.physicsEvents[#carried.physicsEvents].kind=='disable')
carried.carried=false;carried:SetDisableRagdoll(false)
-- Duty end releases private helpers without undoing already-paid identities.
bank=wallet;count=ArrestNative:GetPaidArrests()
Patrol:FinishShift();Module.finish();step(4)
assert(next(managed)==nil and wallet==bank and ArrestNative:GetPaidArrests()==count)
supportPlayer=nil
