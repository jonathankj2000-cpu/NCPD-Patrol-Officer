local Module=require('arrest')
local player=supportActor(1001,'player',0,0,0)
supportPlayer=player; wantedHeat=0; pins=list(); Patrol:ResetSession(); Patrol:BeginShift(); ArrestNative:OnRestored(1,1)
local helpers,managed,bound,active,clips={},{},{},{},{}
local nextID=5000
local deleted,played,stopped={},{},{}
local failDeletes=0
local dynamic={IsReady=function() return true end}
function dynamic:CreateEntity(spec)
    assert(spec.recordID==nil and spec.templatePath=='base\\ncpd_patrol\\arrest_workspot.ent')
    assert(not spec.persistState and not spec.persistSpawn and not spec.alwaysSpawned and spec.spawnInView and spec.active)
    nextID=nextID+1;local id={hash=nextID}
    helpers[id.hash]={GetEntityID=function() return id end,IsAttached=function() return true end};managed[id.hash]=true
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
function ws:GetDeviceUser(id) return bound[id.hash] end
function ws:PlayInDeviceSimple(helper,npc,free,actorComp,deviceComp,sync,slideTime,behaviour,callback)
    assert(not free and actorComp=='NCPDPatrolArrest' and slideTime==0 and behaviour==0)
    played[#played+1]={helper=helper,npc=npc};bound[helper:GetEntityID().hash]=npc;active[npc.id.hash]=true
end
function ws:GetWorkspotInstance(id)
    if active[id.hash] then return {animName=clips[id.hash] or 'none'} end
end
function ws:StopInDevice(npc)
    stopped[#stopped+1]=npc;active[npc.id.hash]=nil
    for id,actor in pairs(bound) do if actor==npc then bound[id]=nil end end
end
CName={new=function(v) return v end};DynamicEntitySpec={new=function() return {} end}
WorkspotSlidingBehaviour={DontPlayAtResourcePosition=0}
local looked
Game={GetPlayer=function() return player end,GetDynamicEntitySystem=function() return dynamic end,
    GetWorkspotSystem=function() return ws end,
    GetScriptableSystemsContainer=function() return {Get=function() return ArrestNative end} end,
    GetTargetingSystem=function() return {GetLookAtObject=function() return looked end} end}
local function step(count,paused)
    for _=1,count do Module.update(0.25,Patrol:IsOnDuty(),paused==true) end
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
assert(#played==1 and wallet==bank,'void animation request granted money')
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
ArrestNative:OnRestored(1,1);Module.reset();step(4)
assert(#deleted==oldDeleted and #stopped==oldStopped and wallet==bank)
assert(ArrestNative:GetPaidArrests()==paid and ArrestNative:IsArrested(f))
Patrol:FinishShift();Module.finish();supportPlayer=nil
