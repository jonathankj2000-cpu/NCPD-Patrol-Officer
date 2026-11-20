-- One non-persistent patrol car and two officers per scene.
-- All entity IDs below originate in this module's own CreateEntity calls.
local Crew = require("officer_ai")
local Ready = require("officer_ready")
local Approach = require("backup_approach")
local Road = Approach.new()
local M = {}
local CAR = "Vehicle.v_standard2_archer_hella_police"
local OFFICER = "Character.cvi_ncpd_police_ranged2_copperhead_ma"
local ids, units, car, drive, anchor, target = {}, {}, nil, nil, nil, nil
local carID = nil
local phase, label = "idle", "Available on duty"
local elapsed, poll, away, retry = 0, 0, 0, 0
local notified, failed = false, false
local releaseNotice, releaseBraked = false, false
local spawnPoint, requestPosition = nil, nil
local attempts, settling, searchPoll = 0, 0, 0
local retryAfterCleanup = false
local rejectedPoints = {}

local function distance(a, b)
    local x, y, z = a.x - b.x, a.y - b.y, a.z - b.z
    return math.sqrt(x*x + y*y + z*z)
end

local function sameVehicle(a, b)
    return a and b and tostring(a:GetEntityID().hash) == tostring(b:GetEntityID().hash)
end

local function report(text, support, status)
    label = text
    if support then support:SetBackupStatus(text) end
    if status then status("Backup | " .. text) end
end

local function notice(patrol, text)
    if patrol then patrol:NotifyDispatch("NCPD: " .. text, 7) end
end

local function stopUnit(unit)
    if unit.actor and unit.command then
        unit.actor:GetAIControllerComponent():StopExecutingCommand(unit.command, false)
    end
    unit.command = nil
end

local function cleanup(support, status)
    if car and drive then pcall(function() car:GetAIComponent():StopExecutingCommand(drive, false) end) end
    drive = nil
    for _, unit in ipairs(units) do
        if unit.readiness then Ready.release(unit.readiness, unit.actor) end
        pcall(stopUnit, unit)
    end
    local remaining = {}
    local hasSystem, system = pcall(function() return Game.GetDynamicEntitySystem() end)
    if not hasSystem then system = nil end
    for index = #ids, 1, -1 do
        local id = ids[index]
        local ok, gone = pcall(function()
            if not system then return false end
            if system:IsManaged(id) == false then return true end
            return system:DeleteEntity(id) == true and system:IsManaged(id) == false
        end)
        -- Even an accepted asynchronous delete retains the reservation until
        -- removal is confirmed. Failed IDs can never become a second patrol.
        if not ok or not gone then remaining[#remaining+1] = id end
    end
    ids = remaining
    if #ids > 0 then
        phase, retry = "cleanup", 0
        report("Cleanup pending; another patrol stays blocked", support, status)
        return false
    end
    units, car = {}, nil
    carID = nil
    spawnPoint, settling = nil, 0
    if retryAfterCleanup and attempts < 3 then
        retryAfterCleanup = false
        phase, elapsed, poll, searchPoll = "searching", 0, 0, 0
        report("Road placement rejected; waiting for another checked approach (attempt " .. attempts .. "/3)", support, status)
        return false
    end
    anchor, target, requestPosition = nil, nil, nil
    phase, away = "idle", 0
    releaseNotice, releaseBraked = false, false
    if support then support:ReleaseBackup() end
    report("Available on duty", support, status)
    return true
end

local function create(system, record, position, orientation)
    if not TweakDB:GetRecord(TweakDBID.new(record)) then error("Backup record unavailable: " .. record) end
    local spec = DynamicEntitySpec.new()
    spec.recordID, spec.position, spec.orientation = TweakDBID.new(record), position, orientation
    spec.persistState, spec.persistSpawn, spec.alwaysSpawned = false, false, false
    spec.spawnInView, spec.active = false, true
    if record:sub(1,10) == "Character." then spec.tags = {"NCPDPatrolOfficer"} end
    local id = system:CreateEntity(spec)
    if not id or not EntityID.IsDefined(id) then error("Backup entity creation failed") end
    ids[#ids+1] = id
    return id
end

function M.state() return label end
function M.isActive() return phase ~= "idle" end

function M.reset()
    -- Called on save/load transitions: old world IDs must never be deleted here.
    ids, units, car, drive, anchor, target = {}, {}, nil, nil, nil, nil
    carID = nil
    phase, label = "idle", "Available on duty"
    elapsed, poll, away, retry, notified, failed = 0, 0, 0, 0, false, false
    releaseNotice, releaseBraked = false, false
    spawnPoint, requestPosition = nil, nil
    attempts, settling, searchPoll, retryAfterCleanup = 0, 0, 0, false
    rejectedPoints = {}
    Road.reset()
end

function M.finish(support, status)
    retryAfterCleanup = false
    if #ids > 0 then return cleanup(support, status) end
    M.reset()
    if support then support:ReleaseBackup() end
    return true
end

local function deploy(support, patrol, status)
    local player = Game.GetPlayer()
    local system = Game.GetDynamicEntitySystem()
    if not player or not system or not system:IsReady() then error("Entity system not ready") end
    if support:SpawnSafetyVersion() ~= 1 then error("Install the complete patrol improvements package and restart") end
    target = support:GetBackupVehicle() or Game.GetMountedVehicle(player) or player
    if target ~= player and math.abs(target:GetCurrentSpeed()) > 1 then error("Stop your vehicle before requesting backup") end
    local position = player:GetWorldPosition()
    anchor = Vector4.new(position.x, position.y, position.z, 1)
    position = target:GetWorldPosition()
    requestPosition = Vector4.new(position.x, position.y, position.z, 1)
    spawnPoint, attempts, settling, searchPoll, retryAfterCleanup = nil, 0, 0, 0, false
    rejectedPoints = {}
    phase, elapsed, poll, away, notified, failed = "searching", 0, 0, 0, false, false
    report("One patrol assigned; looking for a checked off-camera road approach", support, status)
    notice(patrol, "Backup responding. One patrol car assigned.")
end

local function spawnCar(point, support, status)
    local system = Game.GetDynamicEntitySystem()
    if not system or not system:IsReady() then error("Entity system not ready") end
    spawnPoint = point
    attempts, settling = attempts + 1, 0
    local p = point.ground
    carID = create(system, CAR, Vector4.new(p.x, p.y, p.z + 0.15, 1), point.orientation)
    car, units = nil, {}
    phase, elapsed = "spawning", 0
    report("Patrol car requested from " .. point.source .. "; checking actual placement before crew deployment", support, status)
end

local function spawnCrew(system)
    local first = create(system, OFFICER, spawnPoint.crew[1], spawnPoint.orientation)
    units = {{id=first,seat="seat_front_left"}}
    local second = create(system, OFFICER, spawnPoint.crew[2], spawnPoint.orientation)
    units[2] = {id=second,seat="seat_front_right"}
end

local function mount(unit, unmount)
    local data = MountEventData.new()
    data.mountParentEntityId, data.slotName = car:GetEntityID(), CName.new(unit.seat)
    -- Initial seating occurs at the distant spawn point; arrival exits animate.
    data.isInstant, data.ignoreHLS = not unmount, not unmount
    data.allowFailsafeTeleport, data.setEntityVisibleWhenMountFinish = not unmount, true
    local options = NewObject("handle:gameMountEventOptions")
    options.silentUnmount, options.entityID, options.alive = false, car:GetEntityID(), true
    data.mountEventOptions = options
    local command = unmount and AIUnmountCommand.new() or AIMountCommand.new()
    command.mountData = data
    command = command:Copy()
    unit.actor:GetAIControllerComponent():SendCommand(command)
    unit.command = command
end

local function stopDrive()
    if car and drive then car:GetAIComponent():StopExecutingCommand(drive, false) end
    drive = nil
end

local function leaveActualVehicle(unit, mounted)
    local info = Game.GetMountingFacility():GetMountingInfoSingleWithObjects(unit.actor)
    local seat = info and info.slotId and info.slotId.id
    if not seat then error("Released officer's actual seat is unavailable") end
    local data = MountEventData.new()
    data.mountParentEntityId, data.slotName = mounted:GetEntityID(), seat
    data.isInstant, data.ignoreHLS, data.allowFailsafeTeleport = false, false, false
    data.setEntityVisibleWhenMountFinish = true
    local options = NewObject("handle:gameMountEventOptions")
    options.silentUnmount, options.entityID, options.alive = false, mounted:GetEntityID(), true
    data.mountEventOptions = options
    local command = AIUnmountCommand.new()
    command.mountData = data
    command = command:Copy()
    unit.actor:GetAIControllerComponent():SendCommand(command)
    unit.releaseUnmount, unit.releaseWait = command, 0
    unit.releaseAttempts = (unit.releaseAttempts or 0) + 1
end

local function updateReleased(delta, support, patrol, status)
    local system = Game.GetDynamicEntitySystem()
    if not car then car = system:GetEntity(carID) end
    if car and car:IsAttached() and not releaseBraked then
        stopDrive()
        if not sameVehicle(Game.GetMountedVehicle(Game.GetPlayer()), car) then
            car:ForceBrakesUntilStoppedOrFor(8.0)
        end
        releaseBraked = true
    end
    local ready = true
    for _, unit in ipairs(units) do
        if not unit.actor then unit.actor = system:GetEntity(unit.id) end
        local actor = unit.actor
        if actor and actor:IsAttached() then
            if not unit.releaseRole then
                if unit.readiness then Ready.release(unit.readiness, actor) end
                stopUnit(unit)
                Crew.stopFollowing(actor)
                unit.releaseRole = true
            end
            if not actor:IsDead() and not actor:IsDeadNoStatPool()
                and not ScriptedPuppet.IsDefeated(actor) and not ScriptedPuppet.IsUnconscious(actor) then
                local mounted = Game.GetMountedVehicle(actor)
                if mounted then
                    -- A mount already in flight at 10-4 may finish afterwards.
                    -- Release our on-foot hold before requesting its exit.
                    stopUnit(unit)
                    ready = false; unit.releaseHolding = false
                    unit.releaseWait = (unit.releaseWait or 0) + delta
                    -- Never brake or teleport the player's vehicle. Wait for a
                    -- stationary actual parent before requesting an animated exit.
                    if math.abs(mounted:GetCurrentSpeed()) < 0.7 then
                        if unit.releaseUnmount and unit.releaseWait >= 12 and (unit.releaseAttempts or 0) < 3 then
                            actor:GetAIControllerComponent():StopExecutingCommand(unit.releaseUnmount, false)
                            unit.releaseUnmount = nil
                        end
                        if not unit.releaseUnmount then leaveActualVehicle(unit, mounted) end
                    end
                elseif not unit.releaseHolding then
                    unit.releaseUnmount = nil
                    unit.command = Crew.hold(actor)
                    unit.releaseHolding = true
                end
            end
        else ready = false end
    end
    if ready and not releaseNotice then
        releaseNotice = true
        report("10-4: Backup released; remaining on scene until you leave 150 m", support, status)
        notice(patrol, "10-4. Backup released. Unit remaining on scene.")
    end
end

function M.release(support, patrol, status)
    if not support or not patrol or not Game.GetPlayer() or not patrol:IsOnDuty() or patrol:HasWantedLevel() then return false end
    if phase == "cleanup" then
        notice(patrol, "10-4. Previous patrol cleanup is still pending.")
        return false
    end
    if phase == "idle" and #ids == 0 then
        if support:HasBackupUnit() then
            support:ReleaseBackup()
            report("10-4: Pending backup request cancelled before deployment", support, status)
            notice(patrol, "10-4. Pending backup request cancelled.")
            return true
        end
        notice(patrol, "No backup patrol is assigned.")
        return false
    end
    if phase == "released" then
        notice(patrol, "10-4 already requested. Allow seated officers to exit; the patrol remains on scene.")
        return true
    end
    if phase == "searching" and #ids == 0 then
        cleanup(support, status)
        notice(patrol, "10-4. Pending backup approach cancelled.")
        return true
    end
    retryAfterCleanup = false
    phase, elapsed, away, failed, releaseNotice, releaseBraked = "released", 0, 0, false, false, false
    anchor = Game.GetPlayer():GetWorldPosition()
    report("10-4: Standing down; releasing officers from follower duty", support, status)
    local ok, err = pcall(updateReleased, 0, support, patrol, status)
    if not ok then report("10-4 pending: " .. tostring(err), support, status) end
    if not releaseNotice then notice(patrol, "10-4 received. Allow backup officers to exit before driving away.") end
    -- No DeleteEntity or ReleaseBackup here: retain the patrol and reservation
    -- until the existing distance-based cleanup confirms deletion.
    return true
end

local function driveToScene(support, status)
    local command = AIVehicleDriveToPointAutonomousCommand.new()
    -- This is the request location, independent of dispatch and later movement.
    command.targetPosition = Vector3.new(anchor.x, anchor.y, anchor.z)
    command.useKinematic, command.needDriver = false, true
    command.maxSpeed, command.minSpeed = 12, 0
    command.minimumDistanceToTarget = 12
    command.forcedStartSpeed = 0
    command.clearTrafficOnPath, command.driveDownTheRoadIndefinitely = false, false
    car:GetAIComponent():SendCommand(command)
    drive = command
    phase, elapsed = "enroute", 0
    report("Patrol approaching the fixed request location", support, status)
end

local function awayFromUnit(player)
    if not anchor or distance(player:GetWorldPosition(), anchor) < 150 then return false end
    if car and car:IsAttached() and distance(player:GetWorldPosition(), car:GetWorldPosition()) < 150 then return false end
    for _, unit in ipairs(units) do
        if unit.actor and unit.actor:IsAttached() and distance(player:GetWorldPosition(), unit.actor:GetWorldPosition()) < 150 then return false end
    end
    return true
end

local function updateActive(delta, support, patrol, status)
    local player = Game.GetPlayer()
    elapsed = elapsed + delta
    if awayFromUnit(player) then away = away + delta else away = 0 end
    if away >= 3 then
        if cleanup(support, status) then notice(patrol, "Backup released after leaving the scene. A new patrol is available.") end
        return
    end
    if phase == "released" then updateReleased(delta, support, patrol, status); return end
    if phase == "searching" then
        if not target or not target:IsAttached() or distance(target:GetWorldPosition(), requestPosition) > 8 then
            error("The request position moved before a safe approach was found")
        end
        searchPoll = searchPoll + delta
        if searchPoll >= 0.5 then
            searchPoll = 0
            local point = Road.find(target, support, rejectedPoints)
            if point then spawnCar(point, support, status); return end
        end
        if elapsed >= 20 then error("No checked off-camera road approach found within 20 seconds") end
    elseif phase == "spawning" then
        local system = Game.GetDynamicEntitySystem()
        car = system:GetEntity(carID)
        if car and car:IsAttached() then
            if not Approach.positioned(car, spawnPoint) then
                settling = 0
                if elapsed >= 1 then
                    rejectedPoints[#rejectedPoints+1] = spawnPoint.ground
                    retryAfterCleanup = attempts < 3
                    report("Patrol appeared off the requested road position; removing it before another attempt", support, status)
                    cleanup(support, status)
                end
                return
            end
            if #units == 0 then
                -- Recheck the camera: attachment may complete after V turns.
                if support:CanSpawnBackupAt(spawnPoint.position) ~= true then
                    if elapsed >= 12 then error("Patrol crew could not deploy outside the camera view") end
                    return
                end
                if settling == 0 then car:ForceBrakesUntilStoppedOrFor(1.0) end
                settling = settling + delta
                if settling < 0.75 then return end
                spawnCrew(system)
            end
        end
        local ready = car and car:IsAttached() and #units == 2
        for _, unit in ipairs(units) do
            unit.actor = system:GetEntity(unit.id)
            ready = ready and unit.actor and unit.actor:IsAttached()
        end
        if ready then
            for _, unit in ipairs(units) do Crew.friendly(unit.actor); mount(unit, false) end
            phase, elapsed = "seating", 0
        elseif elapsed > 12 then error("Patrol entities did not attach") end
    elseif phase == "seating" then
        local ready = true
        for _, unit in ipairs(units) do ready = ready and sameVehicle(Game.GetMountedVehicle(unit.actor), car) end
        if ready then
            for _, unit in ipairs(units) do unit.command = nil end
            driveToScene(support, status)
        elseif elapsed > 12 then error("Patrol crew could not take their seats") end
    elseif phase == "enroute" then
        if car:IsDestroyed() then
            phase = "lost"
            report("Patrol vehicle lost; leave the scene before another request", support, status)
            notice(patrol, "Backup vehicle lost. No additional unit available at this scene.")
        elseif distance(car:GetWorldPosition(), anchor) <= 28 then
            if drive then car:GetAIComponent():StopExecutingCommand(drive, false); drive = nil end
            car:ForceBrakesUntilStoppedOrFor(8.0)
            phase, elapsed = "stopping", 0
            report("Patrol at request location; braking before exit", support, status)
        elseif elapsed > 65 then error("Patrol could not reach the scene within 65 seconds") end
    elseif phase == "stopping" then
        if car:IsDestroyed() then
            phase = "lost"
            report("Patrol vehicle lost; leave the scene before another request", support, status)
            notice(patrol, "Backup vehicle lost. No additional unit available at this scene.")
        elseif math.abs(car:GetCurrentSpeed()) < 0.7 and elapsed >= 0.5 then
            if distance(car:GetWorldPosition(), anchor) > 45 then error("Patrol stopped too far from the request location") end
            for _, unit in ipairs(units) do mount(unit, true) end
            phase, elapsed = "exiting", 0
            report("Patrol stopped; officers disembarking", support, status)
        elseif elapsed > 10 then error("Patrol did not stop safely for crew exit") end
    elseif phase == "exiting" or phase == "onscene" then
        local ready = true
        for index, unit in ipairs(units) do
            if unit.actor:IsDead() or unit.actor:IsDeadNoStatPool()
                or ScriptedPuppet.IsDefeated(unit.actor) or ScriptedPuppet.IsUnconscious(unit.actor) then
                if unit.readiness then Ready.release(unit.readiness, unit.actor) end
                stopUnit(unit)
                unit.command, unit.onFoot = nil, true
            elseif not Game.GetMountedVehicle(unit.actor) then
                if not unit.onFoot then
                    unit.readiness = {}
                    unit.command = nil
                    Crew.follower(unit.actor)
                    unit.onFoot, unit.followElapsed = true, 5
                end
                local ai = unit.actor:GetAIControllerComponent()
                local boarding = Game.GetMountedVehicle(player) ~= nil
                    or ai:IsCommandExecuting("AIMountCommand", false)
                    or ai:IsCommandExecuting("AIUnmountCommand", false)
                unit.followElapsed = (unit.followElapsed or 5) + delta
                if boarding then
                    -- Let the native follower use seats, without an on-foot
                    -- movement command holding it at the request location.
                    stopUnit(unit)
                elseif unit.followElapsed >= 5 then
                    stopUnit(unit)
                    unit.command = Crew.follow(unit.actor, index == 1 and 3.0 or 4.0)
                    unit.followElapsed = 0
                end
                Ready.update(unit.readiness, delta, unit.actor, patrol, boarding, status)
            else
                if unit.readiness then Ready.release(unit.readiness, unit.actor) end
                stopUnit(unit)
                ready = false
            end
        end
        if ready and not notified then
            notified, phase = true, "onscene"
            report("Backup on scene; one patrol assigned until you leave 150 m", support, status)
            notice(patrol, "Backup on scene. Officers supporting your position.")
        elseif phase == "exiting" and elapsed > 18 then error("Patrol officers could not leave the vehicle") end
    end
end

function M.update(delta, onDuty, support, patrol, status)
    if not support or not patrol or not Game.GetPlayer() then return end
    if onDuty and delta > 0 and delta <= 0.5 and not patrol:IsDispatchMenuOpen() then
        local recorded = pcall(function() Road.record(delta, Game.GetMountedVehicle(Game.GetPlayer())) end)
        if not recorded then Road.reset() end
    end
    if phase == "cleanup" then
        if not onDuty then retryAfterCleanup = false end
        retry = retry + delta
        if retry >= 3 then cleanup(support, nil) end
        return
    end
    if not onDuty then return end
    if patrol:IsDispatchMenuOpen() or delta <= 0 or delta > 0.5 then return end
    if support:TakeBackupRequest() then
        if phase ~= "idle" or #ids > 0 then
            report("A patrol is already assigned", support, status)
        else
            local ok, err = pcall(deploy, support, patrol, status)
            if not ok then
                report("Request failed: " .. tostring(err), support, status)
                notice(patrol, "Backup unavailable. Stop at a clear roadside location and try again.")
                cleanup(support, nil)
            end
        end
    end
    if phase == "idle" then return end
    poll = poll + delta
    if poll < 0.25 then return end
    local step = poll
    poll = 0
    local ok, err = pcall(updateActive, step, support, patrol, status)
    if not ok and phase == "released" then
        if not failed then report("10-4 pending: " .. tostring(err), support, status) end
        failed = true
        return
    end
    if not ok and not failed then
        failed = true
        report("Patrol failed: " .. tostring(err), support, status)
        if phase == "searching" then
            notice(patrol, "No safe backup approach found. Try a clear roadside location and look away from the approach road.")
        else
            notice(patrol, "Backup could not complete its response. Unit standing down.")
        end
        cleanup(support, nil)
    end
end

function M.diagnostics()
    local lines = {"Backup phase=" .. phase}
    for index, unit in ipairs(units) do
        lines[#lines+1] = "Officer " .. index .. " | " .. Ready.diagnostics(unit.readiness or {}, unit.actor)
    end
    return table.concat(lines, "\n[NCPD Patrol] ")
end

return M
