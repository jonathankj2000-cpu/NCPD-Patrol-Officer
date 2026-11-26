local Navigation = require("marker_navigation") -- r5 marker hook
-- Manual encounter prototype. IDs originate only in this module's CreateEntity.
local M = {}
local Variants = require("cyberpsycho_variants")
local LocationPolicy = require("dispatch_location_policy")
local selected, testVariant, previousVariant = nil, nil, nil
local phase, label = "idle", "No cyberpsycho incident"
local id, actor, token, origin, command = nil, nil, nil, nil, nil
local elapsed, poll, cleanupPoll = 0, 0, 0
local finalReason, errorReported = nil, false
local prepareElapsed, searchRadius, assignedDistance = 0, 0, 0
local retired = {}

local function native()
    local system = Game.GetScriptableSystemsContainer():Get("NCPDPatrolCyberpsychoSystem")
    if not system or system:Version() ~= 4 then error("Install the complete v0.17a package and restart") end
    return system
end
local function distance(a,b)
    local x,y,z=a.x-b.x,a.y-b.y,a.z-b.z
    return math.sqrt(x*x+y*y+z*z)
end
local function finite(v)
    return v and v.x==v.x and v.y==v.y and v.z==v.z
        and math.abs(v.x)<100000 and math.abs(v.y)<100000 and math.abs(v.z)<100000
end
local function report(text,status)
    label=text
    if status then status("Cyberpsycho | "..text) end
end
function M.state() return label end
function M.isActive() return phase~="idle" end
function M.hasCleanup() return phase=="cleanup" or #retired>0 end
-- Read-only lifecycle view; retained bodies never own a dispatch reservation.
function M.lifecycle()
    return {phase=phase, assignment=phase~="idle" and phase~="cleanup", reserved=M.isActive(),
        foregroundCleanup=phase=="cleanup", backgroundCleanup=#retired>0}
end
function M.variantState() return Variants.label(testVariant) end
function M.cycleVariant(status)
    testVariant=(testVariant or 0)%Variants.count()+1
    if status then status("Cyberpsycho | Next dispatch: "..M.variantState()) end
end
function M.randomVariants(status)
    testVariant=nil
    if status then status("Cyberpsycho | Random variants enabled") end
end
function M.reset()
    -- Save/load forgets the previous world. Never delete its old entity IDs.
    phase,label="idle","No cyberpsycho incident"
    id,actor,token,origin,command=nil,nil,nil,nil,nil
    elapsed,poll,cleanupPoll=0,0,0
    finalReason,errorReported=nil,false
    prepareElapsed,searchRadius,assignedDistance=0,0,0
    selected,testVariant,previousVariant=nil,nil,nil
    retired={}
end
function M.diagnostics()
    local ok,result=pcall(function() return native():GetDiagnostics() end)
    return "phase="..phase.." | assigned distance="..tostring(math.floor(assignedDistance)).." m | search radius="..tostring(searchRadius)
        .." m | retained scenes="..tostring(#retired).." | entity="..tostring(id and id.hash or "none").." | variant="..tostring(selected and selected.label or "none").." | "
        ..(ok and tostring(result) or tostring(result))
end
local function deleteOwned(entityID)
    local ok,gone=pcall(function()
        local system=Game.GetDynamicEntitySystem()
        if not system or not system:IsReady() then return false end
        if system:IsManaged(entityID)==false then return true end
        if system:DeleteEntity(entityID)~=true then return false end
        return system:IsManaged(entityID)==false
    end)
    return ok and gone
end
local function updateRetired(delta,onDuty,patrol)
    if delta<=0 or delta>0.5 or (onDuty and patrol and patrol:IsDispatchMenuOpen()) then return end
    local player=Game.GetPlayer()
    for i=#retired,1,-1 do
        local scene=retired[i]
        scene.age=scene.age+delta
        if not onDuty or scene.age>=120 or (player and distance(player:GetWorldPosition(),scene.origin)>150) then
            scene.retry=scene.retry+delta
            if scene.retry>=1 then
                scene.retry=0
                -- Retained bodies own no dispatch, journal token or waypoint.
                -- Their cleanup cannot cancel a subsequent assignment.
                if deleteOwned(scene.id) then table.remove(retired,i) end
            end
        end
    end
end
local function cleanup(status)
    if not id then
        phase="idle";actor,command,token,origin=nil,nil,nil,nil
        report(finalReason or "Cyberpsycho dispatch cleared",status)
        return true
    end
    if not deleteOwned(id) then
        phase="cleanup"
        if not errorReported then
            errorReported=true
            report("Target cleanup pending; another incident stays blocked",status)
        end
        return false
    end
    id,actor,token,origin,command=nil,nil,nil,nil,nil
    phase="idle";errorReported=false
    report(finalReason or "Test incident cleared",status)
    return true
end
function M.finish(patrol,status,reason,failed)
    if token then
        local ok,err=pcall(function()
            if failed then native():Fail(token,reason or "Incident setup failed")
            else native():Cancel(token,reason or "Assignment cancelled") end
        end)
        if not ok and status then status("Cyberpsycho journal | "..tostring(err)) end
    end
    if patrol then pcall(function() patrol:ClearDispatchWaypoints() end) end
    Navigation.clear("cyberpsycho") -- r5 marker hook
    phase="cleanup";finalReason=reason or "Test incident cleared";cleanupPoll=0
    return cleanup(status)
end
function M.cancel(patrol,status)
    if not M.isActive() then return false end
    return M.finish(patrol,status,"Cyberpsycho test cancelled/cleared")
end
local function chooseDestination(player)
    local system=Game.GetMappinSystem()
    if not system then error("Map locations unavailable") end
    local pins=system:GetAllMappins()
    local occupied,sites,seen={},{},{}
    local start=player:GetWorldPosition()
    -- Native fast-travel markers supply existing world positions, not guessed
    -- distant navmesh queries. NCART uses a different variant and is excluded.
    for _,pin in ipairs(pins) do
        local ok,variant,phase,point=pcall(function()
            return pin:GetVariant(),pin:GetPhase(),pin:GetWorldPosition()
        end)
        if ok and finite(point) and (point.x~=0 or point.y~=0 or point.z~=0) then
            if variant==gamedataMappinVariant.FastTravelVariant then
                local metres=distance(point,start)
                -- Interaction availability changes while mounted. It does not
                -- invalidate a known fast-travel location as a scene anchor.
                if metres>=500 and metres<=2000 and LocationPolicy.allowed(pin,point,true) then
                    local key=string.format("%.1f:%.1f:%.1f",point.x,point.y,point.z)
                    if not seen[key] then
                        seen[key]=true
                        sites[#sites+1]={position=Vector4.new(point.x,point.y,point.z,1),distance=metres}
                    end
                end
            elseif (variant==gamedataMappinVariant.GangWatchVariant or variant==gamedataMappinVariant.OutpostVariant)
                and phase~=gamedataMappinPhase.CompletedPhase then occupied[#occupied+1]=point end
        end
    end
    for _,radius in ipairs({1000,1500,2000}) do
        local candidates={}
        for _,site in ipairs(sites) do
            if site.distance<=radius then
                local clear=true
                for _,point in ipairs(occupied) do if distance(site.position,point)<100 then clear=false;break end end
                if clear then candidates[#candidates+1]=site end
            end
        end
        if #candidates>0 then return candidates[math.random(1,#candidates)],radius end
    end
    error("No suitable dispatch location 500-2000 m away. Travel to another area and try again.")
end
local function spawnPoint(player,scene)
    local nav=Game.GetAINavigationSystem()
    if not nav then error("Navigation system unavailable") end
    local start=player:GetWorldPosition()
    if not finite(start) or not finite(scene) then error("Invalid incident position") end
    for _,offset in ipairs({{32,0},{-32,0},{0,32},{0,-32},{28,28},{-28,-28},{28,-28},{-28,28}}) do
        local probe=Vector4.new(scene.x+offset[1],scene.y+offset[2],scene.z,1)
        local result=nav:FindPointInSphereForCharacter(probe,4,player)
        if result and result.status==worldNavigationRequestStatus.OK and finite(result.point) then
            local point=result.point
            if math.abs(point.z-scene.z)<=2.5 and distance(point,scene)<=50 and distance(point,start)>=25
                and AINavigationSystem.HasPathFromAtoB(player,start,point) then
                return Vector4.new(point.x,point.y,point.z+0.2,1)
            end
        end
    end
    error("No reachable spawn point in the assigned incident area")
end
local function spawnEntity(player,scene)
    local system=Game.GetDynamicEntitySystem()
    if not system or not system:IsReady() then error("Codeware DynamicEntitySystem not ready") end
    if not selected or not TweakDB:GetRecord(TweakDBID.new(selected.record)) then error("Selected cyberpsycho record unavailable") end
    local point=spawnPoint(player,scene)
    local spec=DynamicEntitySpec.new()
    spec.recordID=TweakDBID.new(selected.record)
    spec.position=point;spec.orientation=player:GetWorldOrientation()
    spec.persistState=false;spec.persistSpawn=false;spec.alwaysSpawned=false
    spec.spawnInView=true;spec.active=true
    local created=system:CreateEntity(spec)
    if not created or not EntityID.IsDefined(created) then error("Cyberpsycho entity creation was not accepted") end
    return created
end
local function hostile(target)
    local player=Game.GetPlayer()
    local ai,agent,playerAgent=target:GetAIControllerComponent(),target:GetAttitudeAgent(),player:GetAttitudeAgent()
    if not ai or not agent or not playerAgent then return false end
    -- Mirrors native DynamicSpawnSystem's own attitude/threat setup.
    agent:SetAttitudeGroup(CName.new("hostile"))
    agent:SetAttitudeTowards(playerAgent,EAIAttitude.AIA_Hostile)
    local threat=AIInjectCombatThreatCommand.new()
    threat.targetPuppetRef=Game.CreateEntityReference('#player',{})
    threat.duration=-1
    threat.isPersistent=true
    threat.dontForceHostileAttitude=false
    ai:SendCommand(threat)
    command=threat
    return true
end
function M.request(patrol,status,sound,voice)
    if M.isActive() then report("An incident or target cleanup is already active",status);return false end
    local ok,err=pcall(function()
        local player=Game.GetPlayer()
        if not player or not player:IsAttached() or player:IsDead() then error("Load a save first") end
        if not patrol or not patrol:IsOnDuty() or patrol:HasWantedLevel() then error("An active, non-wanted shift is required") end
        if patrol:IsDispatchMenuOpen() or player:IsInCombat() then error("Leave game menus and combat before testing") end
        if #retired>=3 then error("Three previous scenes are awaiting cleanup. Leave the previous areas or wait for cleanup.") end
        local journal=native()
        if not journal:IsReady() then error("Cyberpsycho journal resources missing; install the full package and restart") end
        local system=Game.GetDynamicEntitySystem()
        if not system or not system:IsReady() then error("Codeware DynamicEntitySystem not ready") end
        selected=Variants.choose(testVariant,previousVariant)
        local site,radius=chooseDestination(player)
        local request=journal:BeginVariant(site.position,TweakDBID.new(selected.record))
        if not request or request==0 then error(journal:GetReason()) end
        token=request;origin=site.position;phase="responding"
        previousVariant=selected.record
        id,actor,command,finalReason,errorReported=nil,nil,nil,nil,false
        prepareElapsed,searchRadius,assignedDistance=0,radius,site.distance
        elapsed,poll,cleanupPoll=0,0,0
        M.sound,M.voice=sound==true,voice==true
        patrol:ClearDispatchWaypoints()
        Navigation.clear("cyberpsycho") -- r5 marker hook
        local marker=Navigation.place(patrol,origin,"cyberpsycho")
        if not marker or not marker.value or marker.value==0 then error("Scene waypoint creation failed") end
        patrol:NotifyDispatch("NCPD DISPATCH: Cyberpsycho reported. Respond to the marked area within 3 minutes. Backup may be requested.",8,M.sound,M.voice)
        report("Assigned: cyberpsycho response | variant="..selected.label.." | distance="..tostring(math.floor(site.distance)).." m | search radius="..tostring(radius).." m",status)
    end)
    if not ok then
        if token then M.finish(patrol,status,"Cyberpsycho dispatch setup failed",true) end
        report("Request failed: "..tostring(err),status)
    end
    return ok
end
local function update(delta,onDuty,patrol,status,HUD)
    updateRetired(delta,onDuty,patrol)
    -- Reconcile saved active journal entries even while no Lua incident exists.
    local checked,journal=pcall(native)
    if checked then
        local ticked,err=pcall(function() journal:Tick(delta) end)
        if not ticked and M.isActive() and phase~="cleanup" then
            report("Native encounter control failed: "..tostring(err),status)
            M.finish(patrol,status,"Cyberpsycho native control failed")
        end
    elseif M.isActive() and phase~="cleanup" then
        report("Native encounter module unavailable",status)
        M.finish(patrol,status,"Cyberpsycho native module unavailable")
    end
    if not M.isActive() then return false end
    if phase=="cleanup" then
        if delta>0 and delta<=0.5 then cleanupPoll=cleanupPoll+delta end
        if cleanupPoll>=1 then cleanupPoll=0;cleanup(status) end
        HUD.set("",false)
        return M.isActive()
    end
    if not onDuty or not patrol or not patrol:IsOnDuty() then
        M.finish(patrol,status,"Shift ended; cyberpsycho test closed")
        HUD.set("",false);return M.isActive()
    end
    local inMenu=patrol:IsDispatchMenuOpen()
    if inMenu then HUD.set("",false);return true end
    if delta<=0 or delta>0.5 then return true end
    elapsed=elapsed+delta;poll=poll+delta
    local nativeStage=journal:GetStage()
    if journal:GetToken()~=token
        or (nativeStage~=1 and nativeStage~=2 and not (nativeStage==3 and phase=="active")) then
        local reason=journal:GetToken()~=token and "Cyberpsycho session superseded" or journal:GetReason()
        patrol:NotifyDispatch("NCPD DISPATCH CLOSED: "..tostring(reason),8)
        M.finish(patrol,status,tostring(reason))
        HUD.set("",false);return M.isActive()
    end
    if phase=="responding" then
        if journal:CanSpawn(token) then
            phase="preparing";elapsed,poll=0,0
            report("On scene; locating cyberpsycho",status)
        end
    elseif phase=="preparing" then
        if poll>=0.5 and journal:CanSpawn(token) then
            poll=0;prepareElapsed=prepareElapsed+0.5
            local ok,created=pcall(spawnEntity,Game.GetPlayer(),origin)
            if ok then
                id=created;phase="spawning";elapsed,poll=0,0
                report("On scene; target spawn requested",status)
            elseif prepareElapsed>=8 then
                report("Scene setup failed: "..tostring(created),status)
                M.finish(patrol,status,"No suitable cyberpsycho spawn point at the assigned scene",true)
            end
        end
    elseif phase=="spawning" then
        if poll<0.25 then return true end
        poll=0
        local ok,err=pcall(function()
            local entity=Game.FindEntityByID(id)
            if entity and entity:IsAttached() then
                if Game.GetDynamicEntitySystem():IsManaged(id)~=true or not journal:IsTargetRecord(entity) then
                    error("Created target identity/record did not match")
                end
                if not journal:IsTargetReady(entity) then return end
                if not hostile(entity) then return end
                actor=entity
                if not journal:BindTarget(token,actor) then error(journal:GetReason()) end
                phase="active"
                patrol:NotifyDispatch("NCPD DISPATCH: On scene. Neutralize the cyberpsycho. Lethal or non-lethal takedowns accepted.",4)
                report("Assigned: neutralize cyberpsycho | entity="..tostring(id.hash),status)
            end
        end)
        if not ok then
            report("Setup failed: "..tostring(err),status)
            M.finish(patrol,status,"Cyberpsycho scene setup failed",true)
        elseif elapsed>=12 and phase=="spawning" then
            M.finish(patrol,status,"Cyberpsycho spawn/AI attachment timed out",true)
        end
    elseif phase=="active" then
        local stage=journal:GetStage()
        if journal:GetToken()~=token then
            M.finish(patrol,status,"Cyberpsycho session superseded")
        elseif stage==3 then
            patrol:ClearDispatchWaypoints()
            Navigation.clear("cyberpsycho") -- r5 marker hook
            patrol:NotifyDispatch("NCPD DISPATCH: Cyberpsycho neutralized. Incident resolved.",8)
            report("COMPLETED | Cyberpsycho neutralized",status)
            if id then retired[#retired+1]={id=id,origin=origin,age=0,retry=1} end
            id,actor,token,origin,command=nil,nil,nil,nil,nil
            phase="idle"
        elseif stage~=2 then
            local reason=journal:GetReason()
            patrol:NotifyDispatch("NCPD DISPATCH CLOSED: "..tostring(reason),8)
            M.finish(patrol,status,tostring(reason))
        end
    end
    if phase=="responding" then
        local metres=distance(Game.GetPlayer():GetWorldPosition(),origin)
        local seconds=journal:GetRemainingSeconds()
        HUD.set("NCPD DISPATCH\nCyberpsycho response\nRespond to the incident - "..tostring(math.floor(metres+0.5)).." m"
            ..string.format("\nResponse deadline: %02d:%02d",math.floor(seconds/60),seconds%60),true)
    elseif phase=="preparing" or phase=="spawning" then
        HUD.set("NCPD DISPATCH\nCyberpsycho response\nOn scene - locate the threat",true)
    elseif phase=="active" then
        local metres=distance(Game.GetPlayer():GetWorldPosition(),journal:GetTargetPosition())
        HUD.set("NCPD DISPATCH\nCyberpsycho response\nNeutralize the cyberpsycho - "..tostring(math.floor(metres+0.5)).." m\nLethal or non-lethal",true)
    else HUD.set("",false) end
    return M.isActive()
end
function M.update(delta,onDuty,patrol,status,HUD)
    local ok,result=pcall(update,delta,onDuty,patrol,status,HUD)
    if ok then return result end
    if M.isActive() and phase~="cleanup" then
        report("Encounter control failed: "..tostring(result),status)
        M.finish(patrol,status,"Cyberpsycho encounter control failed")
    end
    if HUD then pcall(function() HUD.set("",false) end) end
    return M.isActive()
end
return M
