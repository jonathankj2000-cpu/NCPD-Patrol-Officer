local Module=require('arrest')
local player=supportActor(1001,'player',0,0,0)
supportPlayer=player; wantedHeat=0; pins=list(); Patrol:ResetSession(); Patrol:BeginShift(); ArrestNative:OnRestored(1,1)
local helpers,managed,bound,active,clips={},{},{},{},{}
local nextID=5000
local deleted,played,stopped={},{},{}
local failDeletes=0
local jumpCalls,playSignals={},{}
local listeners,paths,lastDelivered={},{},{}
local callbacksEnabled=true
local autoClipOnJump=false
local bankReady=true
local missingComponent=false
local resourceAvailable=true
local treeAvailable=true
local bankTokens={}
local bankLoads=0
local referenceCalls=0
local loadFailure=false
local rejectToken=false
local dynamic={IsReady=function() return true end}
function dynamic:CreateEntity(spec)
    assert(spec.recordID==nil and spec.templatePath=='base\\ncpd_patrol\\arrest_workspot.ent')
    assert(not spec.persistState and not spec.persistSpawn and not spec.alwaysSpawned and spec.spawnInView and spec.active)
    nextID=nextID+1;local id={hash=nextID}
    local component={name='NCPDPatrolArrestPC',workspotResource='async reference'}
    helpers[id.hash]={GetEntityID=function() return id end,IsAttached=function() return true end,
        FindComponentByType=function(_,kind) assert(kind=='workWorkspotResourceComponent'); if not missingComponent then return component end end}
    managed[id.hash]=true
    return id
end
function dynamic:GetEntity(id) return helpers[id.hash] end
function dynamic:IsManaged(id) return managed[id.hash]==true end
function dynamic:DeleteEntity(id)
    assert(id.hash>=5001,'attempted to delete an ambient suspect')
    if failDeletes>0 then failDeletes=failDeletes-1;return false end
    deleted[#deleted+1]=id.hash;managed[id.hash]=nil;helpers[id.hash]=nil;bound[id.hash]=nil
    return true
end
local ws={}
function ws:IsActorInWorkspot(npc) return active[npc.id.hash]==true end
-- Reproduce the reported running animation with both legacy lookups empty.
function ws:GetDeviceUser(id) return nil end
function ws:PlayInDeviceSimple(helper,npc,free,actorComp,deviceComp,sync,slideTime,behaviour,callback)
    assert(not free and actorComp=='NCPDPatrolArrestPC' and slideTime==0 and behaviour==0)
    played[#played+1]={helper=helper,npc=npc};bound[helper:GetEntityID().hash]=npc;active[npc.id.hash]=true
    paths[npc.id.hash]='base\\workspots\\common\\ground\\generic__lie_ground_lean_front_handcuffs_a__aggressive__01.workspot'
end
function ws:GetWorkspotInstance(id) return nil end
function ws:SendDebugCommandFunctionalTests(mode,npc,proof)
    assert(mode==8192)
    listeners[npc.id.hash]=proof
    if callbacksEnabled and active[npc.id.hash] then
        proof:OnInstanceCreated();proof:OnWorkspotSetup(paths[npc.id.hash]);proof:OnWorkspotStarted()
        if clips[npc.id.hash] then proof:OnAnimationChanged(clips[npc.id.hash],{}) end
    end
end
function ws:SendJumpToAnimEnt(npc,clip,instant)
    assert(instant==true)
    jumpCalls[#jumpCalls+1]={npc=npc,clip=clip}
    if autoClipOnJump then
        clips[npc.id.hash]=clip
        if callbacksEnabled and listeners[npc.id.hash] then
            listeners[npc.id.hash]:OnAnimationChanged(clip,{})
            lastDelivered[npc.id.hash]=clip
        end
    end
end
function ws:SendPlaySignal(npc) playSignals[#playSignals+1]=npc end
function ws:GetExtendedInfo(npc)
    return {isActive=active[npc.id.hash] and clips[npc.id.hash]~=nil,entering=active[npc.id.hash] and clips[npc.id.hash]==nil,exiting=false}
end
ResourceHelper={
    -- Codeware 1.21.4 rejects ResourceAsyncReference properties in all three
    -- methods. v0.7b incorrectly treated this field as ResourceReference.
    IsReferenceLoaded=function(component,field)
        assert(field=='workspotResource'); referenceCalls=referenceCalls+1;return false
    end,
    LoadReferenceResource=function(component,field,path,wait)
        assert(field=='workspotResource' and wait==false)
        referenceCalls=referenceCalls+1;return false
    end,
    GetReferenceResource=function(component,field)
        referenceCalls=referenceCalls+1;return nil
    end
}
local depot={ArchiveExists=function() return true end,ResourceExists=function(_,ref) return resourceAvailable end}
function depot:LoadResource(ref)
    assert(ref=='base\\workspots\\common\\ground\\generic__lie_ground_lean_front_handcuffs_a__aggressive__01.workspot')
    bankLoads=bankLoads+1
    if rejectToken then return nil end
    local token={loaded=bankReady,failed=loadFailure,finished=bankReady or loadFailure}
    function token:IsLoaded() return self.loaded end
    function token:IsFailed() return self.failed end
    function token:IsFinished() return self.finished end
    function token:GetResource()
        assert(self.loaded,'read a resource before its asynchronous load completed')
        if not treeAvailable then return {workspotTree=nil} end
        return {workspotTree={rootEntry={idleAnim='lie_ground_0__2h_back_handcuffs_a__01',list={
            {animName='lie_ground_0__2h_back_handcuffs_a__01__shuffle__01'},
            {animName='lie_ground_0__2h_back_handcuffs_a__01__to__stand__01'}
        }}}}
    end
    bankTokens[#bankTokens+1]=token
    return token
end
function ws:StopInDevice(npc)
    stopped[#stopped+1]=npc;active[npc.id.hash]=nil
    if listeners[npc.id.hash] then listeners[npc.id.hash]:OnWorkspotFinished() end
    for id,actor in pairs(bound) do if actor==npc then bound[id]=nil end end
end
CName={new=function(v) return v end};DynamicEntitySpec={new=function() return {} end}
WorkspotSlidingBehaviour={DontPlayAtResourcePosition=0}
workWorkspotDebugMode={FunctionalTests=8192}
local looked
Game={GetPlayer=function() return player end,GetDynamicEntitySystem=function() return dynamic end,
    GetWorkspotSystem=function() return ws end,
    GetResourceDepot=function() return depot end,
    GetScriptableSystemsContainer=function() return {Get=function() return ArrestNative end} end,
    GetTargetingSystem=function() return {GetLookAtObject=function() return looked end} end}
local function step(count,paused)
    for _=1,count do
        if callbacksEnabled then
            for id,proof in pairs(listeners) do
                if active[id] and clips[id] and clips[id]~=lastDelivered[id] then
                    proof:OnAnimationChanged(clips[id],{});lastDelivered[id]=clips[id]
                end
            end
        end
        Module.update(0.25,Patrol:IsOnDuty(),paused==true)
    end
end
local function secure(npc)
    assert(ArrestNative:StartArrest(npc));step(8);assert(ArrestNative:GetStage()==2);step(2)
end
local CLIP='lie_ground_0__2h_back_handcuffs_a__01'
Module.reset()
local a=arrestSuspect(1002);local bank=wallet
looked=a;local refreshes=a.refreshes;step(2)
assert(a.refreshes==refreshes+1,'newly focused body was not refreshed once')
step(5);assert(a.refreshes==refreshes+1,'focused body refresh spammed')
secure(a)
assert(#played==1 and #jumpCalls>=1 and #playSignals>=1 and wallet==bank,'missing explicit clip request or payment from void request')
clips[a.id.hash]=CLIP..'__to__stand__2h_on_sides__01';step(4)
assert(wallet==bank,'exit/transition animation counted as arrest')
clips[a.id.hash]=CLIP;step(1)
assert(wallet==bank,'single-frame clip sample counted as stable arrest')
step(1);assert(wallet==bank+250 and ArrestNative:IsArrested(a))
step(20);assert(wallet==bank+250,'stable animation paid repeatedly')
assert(a.effects['BaseStatusEffect.Defeated'] and a.health==2,'animation controller changed life state/health')

-- Menu time cannot advance securing or the pose confirmation interval.
local b=arrestSuspect(1003);bank=wallet
assert(ArrestNative:StartArrest(b));step(30,true)
assert(ArrestNative:GetStage()==1 and #played==1)
step(8);step(2);clips[b.id.hash]=CLIP
step(30,true);assert(wallet==bank)
step(2);assert(wallet==bank+250)

-- Wrong animation, missing instance and another device never get a reward.
local c=arrestSuspect(1004);bank=wallet
secure(c);clips[c.id.hash]='kneel__wrong_pose';step(36)
assert(wallet==bank and not ArrestNative:IsArrested(c) and ArrestNative:GetStage()==0)
local d=arrestSuspect(1005);secure(d)
local helperID=nextID;bound[helperID]=nil;clips[d.id.hash]=CLIP
listeners[d.id.hash]:OnWorkspotSetup('base\\foreign.workspot')
local stopCount=#stopped;step(36)
assert(wallet==bank and #stopped==stopCount,'foreign workspot was paid or stopped')

-- A body that dies after the request cannot cash the observed clip.
local e=arrestSuspect(1006);secure(e);e.dead=true;clips[e.id.hash]=CLIP;step(4)
assert(wallet==bank and not ArrestNative:IsArrested(e))

-- Leave the scene: remove only our helpers, never any ambient NPC. Failed
-- deletion retains the owned ID and is retried rather than silently forgotten.
player.position.x=80;failDeletes=1;step(1);step(3)
assert(next(managed)==nil and #deleted==5)
for _,id in ipairs(deleted) do assert(id>=5001) end
player.position.x=0
local f=arrestSuspect(1007);secure(f);clips[f.id.hash]=CLIP;step(2)
bank=wallet;local paid=ArrestNative:GetPaidArrests()
Patrol:FinishShift();Module.finish();step(2)
assert(next(managed)==nil and wallet==bank and ArrestNative:GetPaidArrests()==paid)

-- Load resets cannot address helpers or actor handles from an old world.
Patrol:BeginShift();local g=arrestSuspect(1008);secure(g)
local oldDeleted,oldStopped=#deleted,#stopped
helpers,managed,bound,active,clips={},{},{},{},{}
listeners,paths,lastDelivered={},{},{}
ArrestNative:OnRestored(1,1);Module.reset();step(4)
assert(#deleted==oldDeleted and #stopped==oldStopped and wallet==bank)
assert(ArrestNative:GetPaidArrests()==paid and ArrestNative:IsArrested(f))
-- The reported T-pose/no-instance case is modelled by Play alone not
-- delivering a clip. Explicit clip selection/start supplies it in this case.
autoClipOnJump=true
local h=arrestSuspect(1009);bank=wallet
secure(h);step(2)
assert(ArrestNative:IsArrested(h) and wallet==bank+250,'explicit clip/play sequence did not complete')
-- Native callbacks, not the empty instance/device lookups, keep the paid body
-- in the lying pose. A transition is redirected once and cannot pay again.
local paidBank=wallet;local jumpBefore=#jumpCalls
clips[h.id.hash]=CLIP..'__to__stand__2h_on_sides__01';step(1)
assert(#jumpCalls==jumpBefore+1 and clips[h.id.hash]==CLIP,'standing transition was not redirected')
step(48)
assert(active[h.id.hash] and wallet==paidBank,'paid arrest was released or paid again after three seconds')
local heldProof=listeners[h.id.hash]
heldProof:OnWorkspotSetup('base\\foreign.workspot')
local stopsBefore=#stopped;step(2)
assert(#stopped==stopsBefore and wallet==paidBank,'superseded paid playback was stopped or paid again')
local j=arrestSuspect(1010);bankReady=false;bank=wallet
local beforeLoads=bankLoads
assert(ArrestNative:StartArrest(j));step(8);step(2)
local calls=#played;local token=bankTokens[#bankTokens]
assert(not token.loaded and bankLoads==beforeLoads+1)
step(4);assert(#played==calls and wallet==bank,'unloaded resource entered the animation graph')
assert(bankLoads==beforeLoads+1,'asynchronous load was restarted on each poll')
token.loaded=true;token.finished=true;bankReady=true;step(4)
assert(ArrestNative:IsArrested(j) and wallet==bank+250)
-- Unconfirmed playback is released after three seconds rather than holding
-- the reported T-pose for the original eight-second window.
autoClipOnJump=false
local waiting=arrestSuspect(1014);bank=wallet
secure(waiting);local wasStopped=#stopped
step(10);assert(ArrestNative:GetStage()==2)
step(1);assert(ArrestNative:GetStage()==0 and #stopped==wasStopped+1 and wallet==bank)
-- No unit floods repeated jump commands while waiting for evidence.
local counts={}
for _,request in ipairs(jumpCalls) do
 local id=request.npc.id.hash;counts[id]=(counts[id] or 0)+1
 assert(counts[id]<=(id==h.id.hash and 3 or 2),'clip selection was retried without a bound')
end
-- Missing resources/components/tree fail before transfer; no T-pose request.
for case=1,3 do
    local suspect=arrestSuspect(1010+case)
    resourceAvailable=case~=1;missingComponent=case==2;treeAvailable=case~=3
    local before=#played;bank=wallet
    assert(ArrestNative:StartArrest(suspect));step(30)
    assert(wallet==bank and #played==before and not ArrestNative:IsArrested(suspect),'invalid preflight played or paid')
    resourceAvailable,missingComponent,treeAvailable=true,false,true
end
-- A failed or refused async load cannot transfer the body or pay an arrest.
for case=1,3 do
    local suspect=arrestSuspect(1020+case)
    local before=#played;bank=wallet
    bankReady=false;loadFailure=case==1;rejectToken=case==2
    assert(ArrestNative:StartArrest(suspect));step(10)
    if case==3 then
        local token=bankTokens[#bankTokens];token.finished=true
    end
    step(8)
    assert(ArrestNative:GetStage()==0 and #played==before and wallet==bank,'failed async load played or paid')
    bankReady,loadFailure,rejectToken=true,false,false
end
assert(referenceCalls==0,'ResourceHelper was used on an asynchronous component property')
-- Native active playback without callbacks is still insufficient evidence.
callbacksEnabled=false;autoClipOnJump=true
local silent=arrestSuspect(1030);bank=wallet
secure(silent);step(20)
assert(wallet==bank and not ArrestNative:IsArrested(silent),'active playback without callbacks paid')
callbacksEnabled=true
-- Missing clips and stale proof identities cannot reach the native transaction.
local missing=arrestSuspect(1031);bank=wallet;autoClipOnJump=false
secure(missing);local proof=listeners[missing.id.hash]
proof:OnAnimationChanged(CLIP,{})
assert(not ArrestNative:ConfirmObservedArrest(missing,ArrestNative:GetToken()+1,proof))
assert(not ArrestNative:ConfirmObservedArrest(arrestSuspect(1032),ArrestNative:GetToken(),proof))
proof:OnAnimationMissing(CLIP,{})
assert(not ArrestNative:ConfirmObservedArrest(missing,ArrestNative:GetToken(),proof))
step(20);assert(wallet==bank and not ArrestNative:IsArrested(missing))
-- A paid hold whose transition requests are ignored stops after three seconds,
-- even if native transition callbacks keep arriving. It cannot flood commands.
autoClipOnJump=true
local stubborn=arrestSuspect(1033);secure(stubborn);step(2)
assert(ArrestNative:IsArrested(stubborn))
bank=wallet;autoClipOnJump=false
local beforeJumps=#jumpCalls;local stubbornProof=listeners[stubborn.id.hash]
for _=1,16 do
    clips[stubborn.id.hash]=CLIP..'__to__stand__2h_on_sides__01'
    stubbornProof:OnAnimationChanged(clips[stubborn.id.hash],{})
    step(1)
end
assert(#jumpCalls-beforeJumps<=3 and not active[stubborn.id.hash] and wallet==bank,'failed hold spammed, stayed active or paid again')
Patrol:FinishShift();Module.finish();supportPlayer=nil
