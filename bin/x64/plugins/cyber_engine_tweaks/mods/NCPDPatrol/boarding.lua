-- Explicit, animated passenger boarding for this mod's own partner only.
local M = {}
local elapsed, poll = 0, 0.5
local mode = "On foot"
local targetKey, issued, attempts, nextAttempt = nil, nil, 0, 0
local suppress = false
local seats = { "seat_front_right", "seat_back_right", "seat_back_left" }

local function key(vehicle)
    return vehicle and tostring(vehicle:GetEntityID().hash) or nil
end

local function cancel(npc)
    if issued and npc then
        local ai = npc:GetAIControllerComponent()
        if ai then ai:StopExecutingCommand(issued, false) end
    end
    issued = nil
end

function M.reset()
    elapsed, poll = 0, 0.5
    mode, targetKey, issued, attempts, nextAttempt = "On foot", nil, nil, 0, 0
    suppress = false
end

function M.cancel(npc)
    cancel(npc)
    M.reset()
end

function M.state() return mode end
function M.busy() return suppress end

local function send(npc, vehicle, seat, unmount)
    local data = MountEventData.new()
    data.mountParentEntityId = vehicle:GetEntityID()
    data.slotName = type(seat) == "string" and CName.new(seat) or seat
    data.isInstant = false
    data.ignoreHLS = false
    data.allowFailsafeTeleport = false
    data.setEntityVisibleWhenMountFinish = true
    local options = NewObject("handle:gameMountEventOptions")
    options.silentUnmount = false
    options.entityID = vehicle:GetEntityID()
    options.alive = true
    data.mountEventOptions = options
    local command = unmount and AIUnmountCommand.new() or AIMountCommand.new()
    command.mountData = data
    command = command:Copy()
    npc:GetAIControllerComponent():SendCommand(command)
    issued = command
    attempts = attempts + 1
    nextAttempt = elapsed + 20
end

function M.update(delta, npc, status, stopFollow)
    elapsed, poll = elapsed + delta, poll + delta
    if poll < 0.5 then return suppress end
    poll = 0
    local player = Game.GetPlayer()
    if not player or not npc or not npc:IsAttached() then return suppress end
    local playerCar = Game.GetMountedVehicle(player)
    local npcCar = Game.GetMountedVehicle(npc)
    local playerKey, npcKey = key(playerCar), key(npcCar)

    if npcCar then
        suppress = true
        if playerKey == npcKey then
            -- The mount command has completed; never cancel it while seated.
            issued, targetKey, attempts = nil, playerKey, 0
            mode = "Riding with player"
            return true
        end
        if mode ~= "Leaving vehicle" then
            issued, attempts, nextAttempt = nil, 0, 0
            mode = "Leaving vehicle"
        end
        if elapsed >= nextAttempt and attempts < 3 and math.abs(npcCar:GetCurrentSpeed()) < 1.0 then
            local info = Game.GetMountingFacility():GetMountingInfoSingleWithObjects(npc)
            cancel(npc)
            send(npc, npcCar, info.slotId.id, true)
        end
        return true
    end

    if not playerCar then
        cancel(npc)
        targetKey, attempts, nextAttempt = nil, 0, 0
        mode, suppress = "On foot", false
        return false
    end

    suppress = true
    if targetKey ~= playerKey then
        cancel(npc)
        targetKey, attempts, nextAttempt = playerKey, 0, 0
        if stopFollow then stopFollow() end
    end
    if player:IsInCombat() or npc:IsInCombat() then
        cancel(npc)
        attempts, nextAttempt = 0, elapsed + 2
        mode = "Boarding paused during combat"
        return true
    end
    if math.abs(playerCar:GetCurrentSpeed()) >= 1.0 then
        mode = issued and "Approaching vehicle" or "Waiting for vehicle to stop"
        return true
    end
    if issued and elapsed < nextAttempt then
        mode = "Approaching passenger door"
        return true
    end
    if attempts >= 3 then
        mode = "Boarding stalled; exit and re-enter the vehicle to retry"
        return true
    end
    local seat = nil
    for _, candidate in ipairs(seats) do
        local name = CName.new(candidate)
        if VehicleComponent.HasSlot(playerCar, name)
            and not VehicleComponent.IsSlotOccupied(playerCar:GetEntityID(), name) then
            seat = candidate
            break
        end
    end
    if not seat then
        mode = "No free passenger seat"
        return true
    end
    cancel(npc)
    send(npc, playerCar, seat, false)
    mode = "Approaching passenger door"
    if status and attempts == 1 then status("Partner asked to walk to the passenger door and board.") end
    return true
end

return M
