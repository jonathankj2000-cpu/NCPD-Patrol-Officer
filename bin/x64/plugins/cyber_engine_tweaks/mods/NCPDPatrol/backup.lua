-- One non-persistent patrol car and two officers per scene.
-- All entity IDs below originate in this module's own CreateEntity calls.
local Crew = require("officer_ai")
local M = {}
local CAR = "Vehicle.v_standard2_archer_hella_police"
local OFFICER = "Character.cvi_ncpd_police_ranged2_copperhead_ma"
local ids, units, car, drive, anchor, target = {}, {}, nil, nil, nil, nil
local carID = nil
local phase, label = "idle", "Available on duty"
local elapsed, poll, away, retry = 0, 0, 0, 0
local notified, failed = false, false

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
    for _, unit in ipairs(units) do pcall(stopUnit, unit) end
    local remaining = {}
    local hasSystem, system = pcall(function() return Game.GetDynamicEntitySystem() end)
    if not hasSystem then system = nil end
    for index = #ids, 1, -1 do
        local id = ids[index]
        local ok, result = pcall(function() return system and system:DeleteEntity(id) end)
        -- Retain failed IDs and the reservation; never permit duplicate patrols.
        if not ok or result ~= true then
            local checked, managed = pcall(function() return system and system:IsManaged(id) end)
            if not checked or managed ~= false then remaining[#remaining+1] = id end
        end
    end
    ids = remaining
    if #ids > 0 then
        phase, retry = "cleanup", 0
        report("Cleanup pending; another patrol stays blocked", support, status)
        return false
    end
    units, car, anchor, target = {}, nil, nil, nil
    carID = nil
    phase, away = "idle", 0
    if support then support:ReleaseBackup() end
    report("Available on duty", support, status)
    return true
end

-- Navmesh projection helps avoid voids and upper floors. It does not identify a
-- traffic lane: this first driving test needs a clear roadside location.
local function spawnPoint(origin, heading, player)
    local nav = Game.GetAINavigationSystem()
    if not nav then error("Navigation system unavailable") end
    local forward = heading:GetWorldForward()
    for _, metres in ipairs({38, -38, 50, -50}) do
        local probe = Vector4.new(origin.x - forward.x*metres, origin.y - forward.y*metres, origin.z, 1)
        local result = nav:FindPointInSphereForCharacter(probe, 3, player)
        if result and result.status == worldNavigationRequestStatus.OK then
            local point = result.point
            if math.abs(point.z-origin.z) <= 2 and distance(point, origin) >= 25
                and AINavigationSystem.HasPathFromAtoB(player, point, origin) then
                return Vector4.new(point.x, point.y, point.z + 0.3, 1)
            end
        end
    end
    error("No suitable approach point. Request backup at a clear roadside location.")
end

local function create(system, record, position, orientation)
    if not TweakDB:GetRecord(TweakDBID.new(record)) then error("Backup record unavailable: " .. record) end
    local spec = DynamicEntitySpec.new()
    spec.recordID, spec.position, spec.orientation = TweakDBID.new(record), position, orientation
    spec.persistState, spec.persistSpawn, spec.alwaysSpawned = false, false, false
    spec.spawnInView, spec.active = true, true
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
end

function M.finish(support, status)
    if #ids > 0 then return cleanup(support, status) end
    M.reset()
    if support then support:ReleaseBackup() end
    return true
end

local function deploy(support, patrol, status)
    local player = Game.GetPlayer()
    local system = Game.GetDynamicEntitySystem()
    if not player or not system or not system:IsReady() then error("Entity system not ready") end
    target = support:GetBackupVehicle() or Game.GetMountedVehicle(player) or player
    if target ~= player and math.abs(target:GetCurrentSpeed()) > 1 then error("Stop your vehicle before requesting backup") end
    anchor = player:GetWorldPosition()
    local point = spawnPoint(target:GetWorldPosition(), target, player)
    local orientation = target:GetWorldOrientation()
    carID = create(system, CAR, point, orientation)
    local forward = target:GetWorldForward()
    local first = create(system, OFFICER, Vector4.new(point.x+forward.y*4, point.y-forward.x*4, point.z, 1), orientation)
    local second = create(system, OFFICER, Vector4.new(point.x-forward.y*4, point.y+forward.x*4, point.z, 1), orientation)
    units = {{id=first,seat="seat_front_left"},{id=second,seat="seat_front_right"}}
    -- Store car ID separately without trusting any vehicle from the world.
    car = nil
    phase, elapsed, poll, away, notified, failed = "spawning", 0, 0, 0, false, false
    report("One patrol requested: car and two officers", support, status)
    notice(patrol, "Backup responding. One patrol car assigned.")
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
    if phase == "spawning" then
        local system = Game.GetDynamicEntitySystem()
        car = system:GetEntity(carID)
        local ready = car and car:IsAttached()
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
            if unit.actor:IsDead() then
                unit.command, unit.onFoot = nil, true
            elseif not Game.GetMountedVehicle(unit.actor) then
                if not unit.onFoot then
                    unit.command = nil
                    Crew.follower(unit.actor)
                    local point = Vector4.new(anchor.x + (index == 1 and 3 or -3), anchor.y, anchor.z, 1)
                    unit.command = Crew.moveToScene(unit.actor, point)
                    unit.onFoot, unit.holding = true, false
                end
                if not unit.holding and distance(unit.actor:GetWorldPosition(), anchor) <= 7 then
                    stopUnit(unit); unit.command = Crew.hold(unit.actor); unit.holding = true
                end
            else ready = false end
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
    if phase == "cleanup" then
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
                notice(patrol, "Backup unavailable. Try a clear roadside location.")
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
    if not ok and not failed then
        failed = true
        report("Patrol failed: " .. tostring(err), support, status)
        notice(patrol, "Backup could not complete its response. Unit standing down.")
        cleanup(support, nil)
    end
end

return M
