-- Explicit, separate quest prototype. The archived native scene supplies the
-- actual subtitle/choice UI; this module only stages our two tagged entities.
local M={}
local SITE={x=1424.737,y=-2754.759,z=204.665,yaw=-143.376}
local TAG='ncpd_patrol_qgiver_test'
local NPC='Character.NCPDPatrol_QG_Investigator'
local CAR='Vehicle.NCPDPatrol_QG_Hella'
local POSE_COMPONENT='NCPDPatrolVossWaitPose'
local context,rows,retired={},{},{}
local pose=nil
local phase,label='idle','Ready: activate the quest giver test while OFF DUTY.'
local recover,poll,age=true,0,0
local lastFailure=nil
local function distance(a,b) return math.sqrt((a.x-b.x)^2+(a.y-b.y)^2+(a.z-b.z)^2) end
local function point(p) return Vector4.new(p.x,p.y,p.z,1) end
local function say(text,status)
    label=text
    local callback=status or context.status
    if callback then callback('Quest giver test | '..text) end
end
local function owner()
    local box=Game.GetScriptableSystemsContainer()
    local n=box and box:Get('NCPDPatrolQuestGiverTest')
    if not n or n:Version()~=2 then error('Install the complete v0.19e quest giver package and restart the game') end
    return n
end
local function entities()
    local system=Game.GetDynamicEntitySystem()
    if not system or not system:IsReady() then error('Dynamic entity system is not ready') end
    return system
end
local function ready() return context.worldReady and context.worldReady() end
local function sceneInterface()
    local scene=Game.GetSceneSystem()
    local interface=scene and scene:GetScriptInterface()
    if not interface then error('Scene ownership service unavailable; test actors are retained') end
    return interface
end
local function inScene(id) return sceneInterface():IsEntityInScene(id) end
local function playerBlockReason(player)
    if not player or not player:IsAttached() then return 'Load a save before testing the quest giver' end
    -- Scene membership also covers background scenes. Vanilla distinguishes
    -- active dialogue and restricted tiers from Tier 1 full gameplay.
    if sceneInterface():IsEntityInDialogue(player:GetEntityID()) then
        return 'Finish the active conversation before testing the quest giver'
    end
    local tier=PlayerPuppet.GetSceneTier(player)
    if tier>1 then return 'Return to normal gameplay before testing the quest giver (scene tier '..tostring(tier)..')' end
    return nil
end
local function collect()
    local system=entities()
    for _,id in ipairs(system:GetTaggedIDs(CName.new(TAG))) do
        local known=retired[tostring(id.hash)]==true
        for _,r in ipairs(rows) do if r.id==id or tostring(r.id.hash)==tostring(id.hash) then known=true end end
        if not known then rows[#rows+1]={id=id} end
    end
end
local function cleanup()
    collect()
    local system=entities();local remaining={}
    -- Release the invisible device before its puppet, after the native scene
    -- releases ALL private entities. No generic workspot stop is sent to NPCs.
    local anchors,actors={},{}
    for _,row in ipairs(rows) do
        local object=row.object or system:GetEntity(row.id)
        if object and object:IsAttached() and inScene(row.id) then return false end
        local helper=row.helper or system:IsTagged(row.id,CName.new(TAG..'_pose'))
        row.helper=helper
        if object and object:IsAttached() then
            if not system:IsTagged(row.id,CName.new(TAG)) and not (helper and row.accepted) then error('Refusing cleanup of an unowned entity') end
            if helper then
                local component=object:FindComponentByType(CName.new('workWorkspotResourceComponent'))
                if not component or component.name~=CName.new(POSE_COMPONENT) then error('Unexpected tagged pose helper; retained') end
            else
                local record=object:GetRecordID()
                if record~=TweakDBID.new(NPC) and record~=TweakDBID.new(CAR) then error('Unexpected record on a tagged test entity') end
            end
        end
        if helper then anchors[#anchors+1]=row else actors[#actors+1]=row end
    end
    if #anchors>0 then
        for _,row in ipairs(anchors) do
            local object=row.object or system:GetEntity(row.id)
            if not row.accepted then row.accepted=system:DeleteEntity(row.id)==true end
            row.object=object
            if system:IsSpawning(row.id) or (object and object:IsAttached())
                or (not row.accepted and system:IsSpawned(row.id)) then actors[#actors+1]=row
            else retired[tostring(row.id.hash)]=true end
        end
        rows=actors
        pose=nil
        -- Leave one update for the device's detach to release its native user.
        return #rows==0
    end
    pose=nil
    for _,row in ipairs(rows) do
        local object=row.object or system:GetEntity(row.id)
        if object and object:IsAttached() and inScene(row.id) then return false end
        if object and object:IsAttached() then
            local record=tostring(object:GetRecordID())
            -- Tags and private cloned records are both required before a
            -- recovered entity can be deleted. A foreign object stays intact.
            if not system:IsTagged(row.id,CName.new(TAG)) then error('Refusing cleanup of an unowned entity') end
            if record~=NPC and record~=CAR then
                -- CET normally prints a descriptive TweakDBID, so compare the
                -- typed IDs as well instead of relying on that display string.
                local actual=object:GetRecordID()
                if actual~=TweakDBID.new(NPC) and actual~=TweakDBID.new(CAR) then error('Unexpected record on a tagged test entity') end
            end
        end
        if not row.accepted then row.accepted=system:DeleteEntity(row.id)==true end
        row.object=object
        if system:IsSpawning(row.id) or (object and object:IsAttached())
            or (not row.accepted and system:IsSpawned(row.id)) then remaining[#remaining+1]=row
        else retired[tostring(row.id.hash)]=true end
    end
    rows=remaining
    return #rows==0
end
local function ground(spatial,p)
    local hit,data=spatial:SyncRaycastByCollisionGroup(Vector4.new(p.x,p.y,p.z+1.5,1),Vector4.new(p.x,p.y,p.z-1.5,1),CName.new('Static'),true,false)
    if not hit or not data or not data.position or not data.normal or data.normal.z<.85
        or math.abs(data.position.z-SITE.z)>1.5 then error('The requested quest-giver scene has no supported level ground') end
    return Vector4.new(data.position.x,data.position.y,data.position.z,1)
end
local function layout(player)
    local a=math.rad(SITE.yaw);local fx,fy=-math.sin(a),math.cos(a)
    local carYaw=SITE.yaw+90;local b=math.rad(carYaw)
    local cf,cr={x=-math.sin(b),y=math.cos(b)},{x=math.cos(b),y=math.sin(b)}
    local car={x=SITE.x-fx*4,y=SITE.y-fy*4,z=SITE.z}
    local spatial=Game.GetSpatialQueriesSystem();local nav=Game.GetAINavigationSystem()
    if not spatial or not nav then error('Ground/navigation services unavailable') end
    local npcGround=ground(spatial,SITE);local carGround=ground(spatial,car)
    for _,corner in ipairs({{-1,-2.5},{-1,2.5},{1,-2.5},{1,2.5}}) do
        local p={x=car.x+cr.x*corner[1]+cf.x*corner[2],y=car.y+cr.y*corner[1]+cf.y*corner[2],z=SITE.z}
        local g=ground(spatial,p)
        if math.abs(g.z-carGround.z)>.4 then error('Uneven ground behind the investigator; the Hella footprint does not fit') end
    end
    local function ray(a,b) return spatial:SyncRaycastByCollisionGroup(a,b,CName.new('Static'),true,false) end
    if ray(Vector4.new(npcGround.x,npcGround.y,npcGround.z+.15,1),Vector4.new(npcGround.x,npcGround.y,npcGround.z+1.9,1)) then error('Investigator position is obstructed') end
    for _,side in ipairs({-.8,0,.8}) do
        local x,y=car.x+cr.x*side,car.y+cr.y*side
        if ray(Vector4.new(x-cf.x*2.5,y-cf.y*2.5,carGround.z+.8,1),Vector4.new(x+cf.x*2.5,y+cf.y*2.5,carGround.z+.8,1)) then error('Static obstruction behind the investigator') end
    end
    for _,r in ipairs({{npcGround,Vector4.new(.4,.4,.8,0),SITE.yaw},{carGround,Vector4.new(1.05,2.5,.75,0),carYaw}}) do
        if spatial:Overlap(r[2],Vector4.new(r[1].x,r[1].y,r[1].z+.9,1),EulerAngles.new(0,0,r[3]),CName.new('Vehicle')) then error('A vehicle is blocking the test scene') end
    end
    local route=nav:FindPointInSphereForCharacter(npcGround,1.0,player)
    if not route or route.status~=worldNavigationRequestStatus.OK or not route.point
        or distance(route.point,npcGround)>1.0 then error('Investigator position has no nearby navigation support') end
    return {{record=NPC,position=Vector4.new(npcGround.x,npcGround.y,npcGround.z,1),yaw=SITE.yaw,tag=TAG..'_npc',npc=true},
        {record=CAR,position=Vector4.new(carGround.x,carGround.y,carGround.z+.15,1),yaw=carYaw,tag=TAG..'_car'}}
end
local function spawn(player)
    local definitions=layout(player) -- validate both complete footprints first
    for _,row in ipairs(definitions) do
        local spec=DynamicEntitySpec.new()
        spec.recordID=TweakDBID.new(row.record);spec.position=row.position
        spec.orientation=EulerAngles.new(0,0,row.yaw):ToQuat()
        spec.persistState=false;spec.persistSpawn=true;spec.alwaysSpawned=false
        spec.spawnInView=true;spec.active=true;spec.tags={CName.new(TAG),CName.new(row.tag)}
        if row.npc then spec.appearanceName=CName.new('corpo__ncpd_wa_investigator__lvl3_02') end
        row.id=entities():CreateEntity(spec)
        if not row.id or row.id.hash==0 then error('Test actor creation was rejected') end
        rows[#rows+1]=row
    end
    phase,age='spawning',0
    say('Investigator and Hella requested; waiting for both actors to attach.')
end
local function preparePose(n,step)
    local actor=pose.actor
    if not actor or not actor:IsAttached() or actor:IsDead() then error('Investigator unavailable while preparing the waiting pose') end
    if not pose.load then
        local depot=Game.GetResourceDepot()
        if not depot:ResourceExists(n:GetPoseHelperTemplate()) or not depot:ResourceExists(n:GetPoseResource()) then
            error('Voss pose resources unavailable; install the complete package and restart')
        end
        pose.load=depot:LoadResource(n:GetPoseResource())
        if not pose.load then error('Voss pose resource load returned no token') end
    end
    if pose.load:IsFailed() then error('Voss pose resource load failed') end
    if not pose.load:IsLoaded() then return false end
    local resource=pose.load:GetResource()
    if not resource or not resource.workspotTree or not resource.workspotTree.rootEntry then return false end
    if not pose.anchor then
        local spec=DynamicEntitySpec.new()
        spec.templatePath=n:GetPoseHelperTemplate();spec.position=pose.ground
        spec.orientation=EulerAngles.new(0,0,SITE.yaw):ToQuat()
        spec.persistState=false;spec.persistSpawn=false;spec.alwaysSpawned=false
        spec.spawnInView=true;spec.active=true;spec.tags={CName.new(TAG),CName.new(TAG..'_pose')}
        local id=entities():CreateEntity(spec)
        if not id or id.hash==0 then error('Voss pose helper creation was rejected') end
        pose.anchor={id=id,position=pose.ground,helper=true};rows[#rows+1]=pose.anchor
    end
    local helper=entities():GetEntity(pose.anchor.id)
    if not helper or not helper:IsAttached() then return false end
    pose.anchor.object=helper
    local workspots=Game.GetWorkspotSystem()
    if not workspots then error('Workspot system unavailable') end
    if not pose.requested then
        local component=helper:FindComponentByType(CName.new('workWorkspotResourceComponent'))
        if not component or component.name~=CName.new(POSE_COMPONENT) then error('Voss pose helper component unavailable') end
        if workspots:IsActorInWorkspot(actor) then error('Voss is already using another workspot; pose not replaced') end
        pose.requested=true
        workspots:PlayInDeviceSimple(helper,actor,false,CName.new(POSE_COMPONENT),CName.new('None'),CName.new('None'),.25,
            WorkspotSlidingBehaviour.PlayAtResourcePosition)
    end
    local user=workspots:GetDeviceUser(pose.anchor.id)
    local info=workspots:GetExtendedInfo(actor)
    local present=workspots:IsActorInWorkspot(actor)
    -- GetDeviceUser is a device lookup, not a required receipt for an NPC
    -- workspot. This request started our exact actor from no prior workspot;
    -- its native activity can be valid even when the helper has no user map.
    -- A reported different user still prevents confirmation.
    local matching=not user or user:GetEntityID().hash==actor:GetEntityID().hash
    pose.observed='present='..tostring(present)..' | active='..tostring(info and info.isActive)
        ..' | entering='..tostring(info and info.entering)..' | exiting='..tostring(info and info.exiting)
        ..' | device user='..(user and (matching and 'Voss' or 'other') or 'not registered')
    if matching and present and info and info.isActive==true and info.entering==false and info.exiting==false then
        pose.stable=(pose.stable or 0)+step
    else pose.stable=0 end
    return pose.stable>=.5
end
function M.configure(value) context=value or {};recover=true end
function M.state() return label end
function M.active() return phase~='idle' end
function M.blocksDuty() return phase~='idle' and phase~='complete' end
function M.reset() rows={};retired={};pose=nil;phase,poll,age='idle',0,0;recover=true;lastFailure=nil end
function M.start(status)
    local ok,result=pcall(function()
        if not ready() then error('Load a save and wait for the game session') end
        local allowed,reason=false,nil
        if context.canStart then allowed,reason=context.canStart() end
        if not allowed then error(reason or 'Go OFF DUTY and clear existing developer tests') end
        if M.active() then error('Clear the previous quest giver test before starting another') end
        collect()
        local n=owner()
        if #rows>0 or n:GetStage()~=0 then error('Use Clear quest giver test to remove previous test state') end
        if n:IsMenuOpen() then error('Close in-game menus before starting this test') end
        local player=Game.GetPlayer()
        local blocked=playerBlockReason(player)
        if blocked then error(blocked) end
        if not TweakDB:GetRecord(TweakDBID.new(NPC)) or not TweakDB:GetRecord(TweakDBID.new(CAR)) then error('Private investigator/car records are unavailable; install the full package') end
        if not n:Begin() then error('Quest not ready: install the archive and scripts, then restart outside combat/wanted status') end
        recover=false;phase,age,poll='waiting',0,0;lastFailure=nil
        say('Voss invitation requested. Check Messages and follow the meeting marker; approach within 3 m on foot to start the conversation.',status)
        return true
    end)
    if not ok then say(tostring(result),status);return false end
    return result
end
function M.clear(status)
    if not ready() then say('Load a save before clearing this test.',status);return false end
    local ok,err=pcall(function() owner():RequestClear();collect();phase,age,poll='clearing',0,0;recover=false end)
    if not ok then say(tostring(err),status);return false end
    say('Test cancellation requested; waiting for the native scene to release its actors.',status)
    return true
end
local function update(delta)
    if not ready() or delta<=0 or delta>.5 then return end
    if recover then
        local n=owner();collect();recover=false
        if #rows>0 or n:GetStage()~=0 then M.clear() end
    end
    if phase=='idle' then return end
    local n=owner()
    if n:IsMenuOpen() then return end
    poll,age=poll+delta,age+delta
    if poll<.25 then return end
    local step=poll;poll=0;n:Tick(step)
    local stage=n:GetStage()
    if phase=='clearing' then
        -- Never delete a puppet while the native scene still owns it.
        if stage==0 and cleanup() then phase='idle';say('Test cleared. You can activate it again.');return end
        return
    end
    if stage==3 then
        if phase~='complete' then
            if not n:IsSucceeded() then error('Scene ended without a proven journal completion') end
            phase='complete';say('Quest completed after goodbye. Briefing finished. Clear the test before replaying the conversation.')
        end
        return
    end
    if stage==0 then
        if phase~='waiting' or age>10 then error('Native quest did not activate or was interrupted; clear and retry') end
        return
    end
    local player=Game.GetPlayer()
    if not player or not player:IsAttached() then return end
    if phase=='waiting' and distance(player:GetWorldPosition(),SITE)<=120 then spawn(player) end
    if phase=='spawning' then
        local attached=0
        for _,r in ipairs(rows) do
            local object=entities():GetEntity(r.id)
            if object and object:IsAttached() then
                if distance(object:GetWorldPosition(),r.position)>3 then error('The engine placed a test actor outside its intended scene') end
                r.object=object;attached=attached+1
            end
        end
        if attached==2 then
            pose={actor=rows[1].object,ground=rows[1].position}
            phase,age='posing',0;say('Both actors ready; preparing Voss at the grounded waiting anchor.')
        elseif age>30 then error('Timed out waiting for the two test actors') end
    end
    if phase=='posing' then
        local ok,complete=pcall(preparePose,n,step)
        if ok and complete then phase='approaching';say('Voss is waiting in the workspot. Approach within 3 m on foot.')
        elseif not ok or age>8 then
            -- A cosmetic preparation failure must not cancel the SMS quest or
            -- delete its two actors. Retain our helper until explicit cleanup;
            -- never stop/restart an actor whose pose may already be playing.
            pose.warning=ok and ('Waiting pose not confirmed after 8 s | '..tostring(pose.observed or 'no native activity sample')) or tostring(complete)
            lastFailure=pose.warning
            phase='approaching'
            say('Waiting pose could not be confirmed; Voss and the quest are retained. Approach within 3 m on foot to talk. Details: '..pose.warning)
        end
    end
    if phase=='approaching' then
        local npc=rows[1] and rows[1].object
        if not npc or not npc:IsAttached() or npc:IsDead() then error('Investigator unavailable') end
        if context.overlayOpen and context.overlayOpen() then return end
        if not Game.GetMountedVehicle(player) and not playerBlockReason(player) and distance(player:GetWorldPosition(),npc:GetWorldPosition())<=3 then
            if n:RequestTalk(npc) then phase,age='dialogue',0;say('Native conversation requested: Voss briefing with automatic replies from V.') end
        end
    end
end
function M.update(delta)
    local ok,err=pcall(update,delta)
    if not ok then
        if lastFailure~=tostring(err) then say(tostring(err));lastFailure=tostring(err) end
        if phase~='idle' and phase~='clearing' then M.clear() end
    end
end
function M.diagnostics()
    local ok,state=pcall(function() return owner():GetDiagnostics() end)
    local poseState=pose and (pose.warning and 'unconfirmed' or (pose.requested and 'requested' or 'loading')) or 'none'
    return 'phase='..phase..' | owned actors='..#rows..' | pose='..poseState..' | pose proof='..tostring(pose and pose.observed or 'none')..' | '..(ok and state or tostring(state))..' | last failure='..tostring(lastFailure or 'none')..' | '..label
end
function M.shutdown()
    if ready() and M.active() then pcall(function() owner():RequestClear() end) end
end
return M
