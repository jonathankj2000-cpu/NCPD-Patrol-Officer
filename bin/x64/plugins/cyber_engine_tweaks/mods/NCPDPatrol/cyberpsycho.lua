-- Manual encounter prototype. IDs originate only in this module's CreateEntity.
local M = {}
local RECORD = "Character.NCPDPatrol_Cyberpsycho"
local phase, label = "idle", "No cyberpsycho incident"
local id, actor, token, origin, command = nil, nil, nil, nil, nil
local elapsed, poll, resolvedTime, cleanupPoll = 0, 0, 0, 0
local finalReason, errorReported = nil, false

local function native()
    local system = Game.GetScriptableSystemsContainer():Get("NCPDPatrolCyberpsychoSystem")
    if not system or system:Version() ~= 1 then error("Install all v0.13a Cyberpsycho files and restart") end
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
function M.reset()
    -- Save/load forgets the previous world. Never delete its old entity IDs.
    phase,label="idle","No cyberpsycho incident"
    id,actor,token,origin,command=nil,nil,nil,nil,nil
    elapsed,poll,resolvedTime,cleanupPoll=0,0,0,0
    finalReason,errorReported=nil,false
end
function M.diagnostics()
    local ok,result=pcall(function() return native():GetDiagnostics() end)
    return "phase="..phase.." | entity="..tostring(id and id.hash or "none").." | "
        ..(ok and tostring(result) or tostring(result))
end
local function cleanup(status)
    if not id then phase="idle";actor,command=nil,nil;return true end
    local ok,gone=pcall(function()
        local system=Game.GetDynamicEntitySystem()
        if not system then return false end
        if system:IsManaged(id)==false then return true end
        -- A rejected or asynchronous deletion keeps the reservation.
        if system:DeleteEntity(id)~=true then return false end
        return system:IsManaged(id)==false
    end)
    if not ok or not gone then
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
function M.finish(patrol,status,reason)
    if token then
        local ok,err=pcall(function() native():Cancel(token,reason or "Assignment cancelled") end)
        if not ok and status then status("Cyberpsycho journal | "..tostring(err)) end
    end
    if patrol then pcall(function() patrol:ClearDispatchWaypoints() end) end
    phase="cleanup";finalReason=reason or "Test incident cleared";cleanupPoll=0
    return cleanup(status)
end
function M.cancel(patrol,status)
    if not M.isActive() then return false end
    return M.finish(patrol,status,"Cyberpsycho test cancelled/cleared")
end
local function spawnPoint(player)
    local nav=Game.GetAINavigationSystem()
    if not nav then error("Navigation system unavailable") end
    local start,forward=player:GetWorldPosition(),player:GetWorldForward()
    if not finite(start) or not finite(forward) then error("Invalid player position/heading") end
    for _,metres in ipairs({65,85,-65,-85}) do
        local probe=Vector4.new(start.x+forward.x*metres,start.y+forward.y*metres,start.z,1)
        local result=nav:FindPointInSphereForCharacter(probe,4,player)
        if result and result.status==worldNavigationRequestStatus.OK and finite(result.point) then
            local point=result.point
            local range=distance(point,start)
            if math.abs(point.z-start.z)<=2.5 and range>=35 and range<=100
                and AINavigationSystem.HasPathFromAtoB(player,start,point) then
                return Vector4.new(point.x,point.y,point.z+0.2,1)
            end
        end
    end
    error("No reachable nearby spawn point. Try an open outdoor area on foot.")
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
        if Game.GetMountedVehicle(player) then error("Request this encounter on foot in an open outdoor area") end
        local journal=native()
        if not journal:IsReady() then error("Cyberpsycho journal resources missing; install the full package and restart") end
        local system=Game.GetDynamicEntitySystem()
        if not system or not system:IsReady() then error("Codeware DynamicEntitySystem not ready") end
        if not TweakDB:GetRecord(TweakDBID.new(RECORD)) then error("Cyberpsycho record missing; check NCPDPatrol_Cyberpsycho.yaml") end
        local point=spawnPoint(player)
        local spec=DynamicEntitySpec.new()
        spec.recordID=TweakDBID.new(RECORD)
        spec.position=point;spec.orientation=player:GetWorldOrientation()
        spec.persistState=false;spec.persistSpawn=false;spec.alwaysSpawned=false
        spec.spawnInView=true;spec.active=true
        local created=system:CreateEntity(spec)
        if not created or not EntityID.IsDefined(created) then error("Cyberpsycho entity creation was not accepted") end
        id=created;origin=point;phase="spawning"
        elapsed,poll,resolvedTime,cleanupPoll=0,0,0,0
        token,actor,command,finalReason,errorReported=nil,nil,nil,nil,false
        M.sound,M.voice=sound==true,voice==true
        report("Target requested; waiting for the spawned cyberpsycho",status)
    end)
    if not ok then
        if id then M.finish(patrol,status,"Cyberpsycho setup failed") end
        report("Request failed: "..tostring(err),status)
    end
    return ok
end
local function update(delta,onDuty,patrol,status,HUD)
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
    if phase=="spawning" then
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
                token=journal:BeginTarget(actor)
                if not token or token==0 then error(journal:GetReason()) end
                patrol:ClearDispatchWaypoints()
                local marker=patrol:PlaceDispatchWaypoint(origin)
                if not marker or not marker.value or marker.value==0 then error("Scene waypoint creation failed") end
                phase="active"
                patrol:NotifyDispatch("NCPD DISPATCH: Cyberpsycho reported nearby. Neutralize the threat. Backup may be requested.",8,M.sound,M.voice)
                report("Assigned: neutralize cyberpsycho | entity="..tostring(id.hash),status)
            end
        end)
        if not ok then
            report("Setup failed: "..tostring(err),status)
            M.finish(patrol,status,"Cyberpsycho setup failed")
        elseif elapsed>=12 and phase=="spawning" then
            M.finish(patrol,status,"Cyberpsycho spawn/AI attachment timed out")
        end
    elseif phase=="active" then
        local stage=journal:GetStage()
        if journal:GetToken()~=token then
            M.finish(patrol,status,"Cyberpsycho session superseded")
        elseif stage==3 then
            phase="resolved";resolvedTime=0
            patrol:ClearDispatchWaypoints()
            patrol:NotifyDispatch("NCPD DISPATCH: Cyberpsycho neutralized. Incident resolved.",8)
            report("COMPLETED | Cyberpsycho neutralized",status)
        elseif stage~=2 then
            local reason=journal:GetReason()
            patrol:NotifyDispatch("NCPD DISPATCH CLOSED: "..tostring(reason),8)
            M.finish(patrol,status,tostring(reason))
        end
    elseif phase=="resolved" then
        resolvedTime=resolvedTime+delta
        local player=Game.GetPlayer()
        if resolvedTime>=120 or (player and distance(player:GetWorldPosition(),origin)>150) then
            M.finish(patrol,status,"Cyberpsycho scene cleared; ready for another test")
        end
    end
    if phase=="active" then
        local metres=distance(Game.GetPlayer():GetWorldPosition(),journal:GetTargetPosition())
        HUD.set("NCPD DISPATCH\nCyberpsycho response\nNeutralize the cyberpsycho - "..tostring(math.floor(metres+0.5)).." m\nLethal or non-lethal",true)
    elseif phase=="resolved" then
        HUD.set("NCPD DISPATCH\nCyberpsycho neutralized\nLeave the scene or clear the test incident",true)
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
