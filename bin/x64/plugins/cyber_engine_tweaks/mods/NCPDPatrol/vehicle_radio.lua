-- The ambient NPC police radio event plays on the owned car's entity audio object.
local M = {}
local enabled, failed = true, false
local currentKey, poll = nil, 0
local state = "OFF DUTY"

local function stop(patrol)
    patrol:StopVehicleChatter()
    currentKey = nil
end

function M.state() return state end
function M.isEnabled() return enabled end
function M.reset()
    -- Save loads destroyed the previous world: forget, do not reuse its entity ID.
    currentKey, poll, failed, state = nil, 0, false, "OFF DUTY"
end

function M.finish(patrol)
    if patrol then pcall(stop, patrol) end
    currentKey, state = nil, "OFF DUTY"
end

function M.setEnabled(value, patrol, status)
    enabled = value
    if not value then M.finish(patrol); state = "Chatter muted" end
    if status then status("Vehicle chatter " .. (value and "enabled" or "muted")) end
end

function M.update(delta, onDuty, status, getPatrol)
    poll = poll + delta
    if poll < 0.25 then return end
    poll = 0
    local patrol = getPatrol()
    if not patrol then return end
    local ok, err = pcall(function()
        if patrol:Version() ~= 11 then return end
        if not enabled or not onDuty or not patrol:IsOnDuty() then
            if currentKey then stop(patrol) end
            state = enabled and "OFF DUTY" or "Chatter muted"
            return
        end
        if failed then return end
        if patrol:IsVehicleChatterPausedForVoice() then
            currentKey = nil
            state = "Paused for dispatch voice"
            return
        end
        local vehicle = Game.GetMountedVehicle(Game.GetPlayer())
        if not vehicle or not patrol:IsOwnedPoliceVehicle(vehicle) then
            if currentKey then stop(patrol) end
            state = vehicle and "Current vehicle is not an owned police vehicle" or "On foot: vehicle chatter stopped"
            return
        end
        local key = tostring(vehicle:GetEntityID().hash)
        if currentKey ~= key then
            if currentKey then stop(patrol) end
            if patrol:BeginVehicleChatter(vehicle) then
                currentKey = key
                state = "Chatter requested on vehicle emitter | entity=" .. key
            else
                state = "Vehicle chatter unavailable"
            end
        end
    end)
    if not ok and not failed then
        failed = true
        pcall(stop, patrol)
        state = "Vehicle chatter failed: " .. tostring(err)
        if status then status(state) end
    end
end

return M
