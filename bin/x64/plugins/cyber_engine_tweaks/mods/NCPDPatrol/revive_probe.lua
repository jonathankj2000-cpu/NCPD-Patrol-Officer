-- Read-only observations of this mod's partner after revive. Never sends AI
-- commands, moves/heals entities or changes native flags. A command state is
-- evidence about the request, not an acknowledgement of actual movement.
local M = {}
local mode, reason = "idle", "Not armed"
local elapsed, poll, greatest = 0, 0, 0
local origin, observedCommand = nil, nil

local function point(object)
    local p = object:GetWorldPosition()
    return {x=p.x, y=p.y, z=p.z}
end

local function gap(a, b)
    local x, y, z = a.x-b.x, a.y-b.y, a.z-b.z
    return math.sqrt(x*x+y*y+z*z)
end

local function commandInfo(command)
    if not command then return "command=none" end
    local ok, value = pcall(function()
        return "command=" .. tostring(command.id) .. " | command state=" .. tostring(command.state)
    end)
    return ok and value or "command state=unavailable"
end

local function emit(stage, command, distance, status, diagnostics)
    local text = "Revive probe | " .. stage .. " | " .. commandInfo(command)
        .. string.format(" | observed=%.2f s | max horizontal displacement=%.2f m | player distance=%.2f m", elapsed, greatest, distance)
    if diagnostics then
        local ok, value = pcall(diagnostics)
        if ok then text = text .. " | " .. tostring(value) end
    end
    if status then status(text) end
end

function M.reset()
    mode, reason = "idle", "Not armed"
    elapsed, poll, greatest, origin, observedCommand = 0, 0, 0, nil, nil
end

function M.begin(status)
    M.reset()
    mode, reason = "waiting", "Waiting for an on-foot follow distance of at least 5 m"
    if status then status("Revive probe | armed after revive; command state and physical displacement will be observed automatically") end
end

function M.isSampling() return mode == "sampling" end
function M.state() return mode .. ": " .. reason end

local function observe(delta, npc, command, status, diagnostics, paused)
    if mode ~= "waiting" and mode ~= "sampling" then return end
    if delta <= 0 or delta > 0.5 then return end
    if paused then
        mode, reason, elapsed, poll, origin = "waiting", "Paused in menu", 0, 0, nil
        return
    end
    local player = Game.GetPlayer()
    if not player or not npc or not npc:IsAttached() then M.reset(); return end
    if Game.GetMountedVehicle(player) or Game.GetMountedVehicle(npc) or player:IsInCombat() or npc:IsInCombat() then
        mode, reason, elapsed, poll, origin = "waiting", "Waiting for both actors on foot and outside combat", 0, 0, nil
        return
    end
    local position, playerPosition = point(npc), point(player)
    local distance = gap(position, playerPosition)
    if mode == "waiting" then
        reason = "Waiting for an on-foot follow distance of at least 5 m"
        if distance < 5 or not command then return end
        mode, reason, origin, observedCommand = "sampling", "Observing existing follow command", position, command
        elapsed, poll, greatest = 0, 0, 0
        emit("sample started", command, distance, status, diagnostics)
        return
    end
    if command ~= observedCommand then
        mode, reason, elapsed, poll, origin = "waiting", "Follow command changed; restarting observation", 0, 0, nil
        return
    end
    local x, y = position.x-origin.x, position.y-origin.y
    greatest = math.max(greatest, math.sqrt(x*x+y*y))
    elapsed, poll = elapsed + delta, poll + delta
    if distance < 2.5 and greatest < 0.5 then
        mode, reason, elapsed, poll, origin = "waiting", "Player returned close; no sustained follow demand", 0, 0, nil
        return
    end
    if elapsed >= 3 or (distance < 2.5 and greatest >= 0.5) then
        mode = "done"
        reason = greatest >= 0.5 and "Horizontal displacement observed" or "No horizontal displacement observed"
        emit(reason, observedCommand, distance, status, diagnostics)
    elseif poll >= 1 then
        poll = 0
        emit("sample", observedCommand, distance, status, diagnostics)
    end
end

function M.update(delta, npc, command, status, diagnostics, paused)
    local ok, err = pcall(observe, delta, npc, command, status, diagnostics, paused)
    if not ok then
        mode, reason = "unavailable", tostring(err)
        if status then status("Revive probe | observation unavailable: " .. reason) end
    end
end

return M
