-- Dispatch selects existing scanner activities; rewards remain in redscript.
local HUD = require("dispatch_hud")
local M = {}
local active, used = nil, {}
local automatic, dutySeen, cleaned = true, false, false
local countdown, poll = 0, 0
local state = "OFF DUTY"
local completed, candidateCount = 0, 0
local failed = false
local soundEnabled = true
local voiceEnabled = true
local navigation = "No active dispatch"

local function distance(a, b)
    local x, y, z = a.x - b.x, a.y - b.y, a.z - b.z
    return math.sqrt(x * x + y * y + z * z)
end

local function report(message, status)
    state = message
    if status then status("Dispatch | " .. message) end
end

local function hide()
    HUD.set("", false)
end

local function clear(patrol)
    -- The native tag identifies our markers even if a save regenerated their IDs.
    patrol:ClearDispatchWaypoints()
    active = nil
    navigation = "No active dispatch"
    hide()
end

local function drawObjective(inMenu)
    if not active then hide(); return end
    local player = Game.GetPlayer()
    local metres = distance(player:GetWorldPosition(), active.position)
    local objective = active.arrived and "Resolve the incident and collect evidence"
        or ("Respond to the incident - " .. tostring(math.floor(metres + 0.5)) .. " m")
    HUD.set("NCPD DISPATCH\n" .. active.label .. "\n" .. objective, not inMenu)
end

function M.init() HUD.init() end
function M.state() return state end
function M.hudState() return HUD.state() end
function M.isAutomatic() return automatic end
function M.isActive() return active ~= nil end
function M.completed() return completed end
function M.seconds() return math.max(0, math.ceil(countdown)) end
function M.candidates() return candidateCount end
function M.isSoundEnabled() return soundEnabled end
function M.isVoiceEnabled() return voiceEnabled end
function M.navigationState() return navigation end
function M.setVoiceEnabled(value, status)
    voiceEnabled = value
    if status then status("Dispatch | Call voice " .. (value and "enabled" or "muted")) end
end

function M.setSoundEnabled(value, status)
    soundEnabled = value
    if status then status("Dispatch | Alert sound " .. (value and "enabled" or "muted")) end
end

function M.testAudio(patrol, radio, status)
    local ok, result = pcall(function()
        if not patrol or not Game.GetPlayer() then error("Load a save first") end
        if patrol:Version() ~= 17 then error("Install all v0.7b files and restart the game") end
        if radio then return patrol:PreviewPoliceRadio() end
        return patrol:PlayDispatchAlert()
    end)
    if status then
        if ok and result then
            status(radio and "Dispatch voice test requested: nc_heat_1_start. The same line accompanies new dispatch notices."
                or "Dispatch alert requested. Check that the short signal is audible.")
        else
            status("Audio preview unavailable: " .. tostring(result))
        end
    end
    return ok and result == true
end

function M.start(patrol, status)
    active, used = nil, {}
    navigation = "No active dispatch"
    poll, completed, candidateCount = 0, 0, 0
    failed, dutySeen = false, true
    cleaned = false
    local ok, err = pcall(clear, patrol)
    if not ok then
        failed = true
        report("Waypoint cleanup failed: " .. tostring(err), status)
        return
    end
    cleaned = true
    countdown = math.random(30, 60)
    report("Standing by for calls", status)
end

function M.finish(patrol, status)
    local ok, err = pcall(clear, patrol)
    active, used, dutySeen = nil, {}, false
    countdown, poll, cleaned = 0, 0, ok
    hide()
    report(ok and "OFF DUTY" or ("Waypoint cleanup failed: " .. tostring(err)), status)
end

-- Used after a load: never remove a marker by an ID from the previous world.
function M.reset()
    active, used, dutySeen, cleaned = nil, {}, false, false
    countdown, poll, completed, candidateCount = 0, 0, 0, 0
    failed, state = false, "OFF DUTY"
    navigation = "No active dispatch"
    hide()
end

function M.setAutomatic(value, status)
    automatic = value
    if countdown <= 0 then countdown = math.random(30, 60) end
    if status then status("Dispatch | Automatic calls " .. (automatic and "enabled" or "paused")) end
end

function M.request(patrol, status)
    if not patrol or not Game.GetPlayer() then
        report("Load a save before requesting a dispatch", status)
        return false
    end
    local ok, result = pcall(function()
        if patrol:Version() ~= 17 then error("Install all v0.7b Lua/redscript files and restart the game") end
        if not patrol:IsOnDuty() then report("Start a shift before requesting a dispatch", status); return false end
        if failed then report("Dispatch stopped after an API error; end and restart the shift to retry", status); return false end
        if active then report("A dispatch is already assigned; complete or cancel it first", status); return false end
        -- Observe a baseline before selecting so this target is eligible for its bonus.
        patrol:TickBonuses()
        if not patrol:IsOnDuty() then report("Shift inactive; check duty status", status); return false end
        local tiers, all, seen = {{}, {}, {}}, {}, {}
        local radii = {1000, 1500, 2000}
        local position = Game.GetPlayer():GetWorldPosition()
        for _, marker in ipairs(patrol:GetDispatchCandidates()) do
            local hash = marker:GetJournalPathHash()
            local key = tostring(hash)
            if not used[key] and not seen[key] then
                seen[key] = true
                local target = marker:GetWorldPosition()
                -- Reject missing/non-finite positions rather than routing to the origin.
                if target and target.x == target.x and target.y == target.y and target.z == target.z
                    and math.abs(target.x) < 100000 and math.abs(target.y) < 100000 and math.abs(target.z) < 100000
                    and (target.x ~= 0 or target.y ~= 0 or target.z ~= 0) then
                    local item = {marker = marker, hash = hash, key = key, position = target, distance = distance(position, target)}
                    all[#all + 1] = item
                    for i, radius in ipairs(radii) do
                        if item.distance <= radius then tiers[i][#tiers[i] + 1] = item end
                    end
                end
            end
        end
        candidateCount = #all
        local pool, radius = nil, nil
        for i, range in ipairs(radii) do
            if #tiers[i] > 0 then pool, radius = tiers[i], range; break end
        end
        if not pool then
            countdown = 30
            report("No available scanner within 1 km, 1.5 km or 2 km; retrying in 30 seconds", status)
            return false
        end
        local chosen = pool[math.random(1, #pool)]
        chosen.label = chosen.marker:GetVariant() == gamedataMappinVariant.OutpostVariant
            and "Suspected organized crime" or "Assault in progress"
        patrol:ClearDispatchWaypoints()
        local id = patrol:PlaceDispatchWaypoint(chosen.position)
        if not id or not id.value or id.value == 0 then error("Game did not return a dispatch waypoint ID") end
        active = chosen
        used[chosen.key] = true
        active.arrived = false
        active.waypoint = id
        countdown = 0
        navigation = "Dispatch marker active. Open and close the map if you need the GPS line."
        patrol:NotifyDispatch("NCPD DISPATCH: " .. chosen.label .. ". Respond to the marked location.", 8.0, soundEnabled, voiceEnabled)
        drawObjective(patrol:IsDispatchMenuOpen())
        report("Assigned: " .. chosen.label .. " | POI=" .. chosen.key .. " | distance=" .. tostring(math.floor(chosen.distance))
            .. " m | search radius=" .. tostring(radius) .. " m | " .. navigation, status)
        return true
    end)
    if not ok then
        pcall(clear, patrol)
        failed = true
        report("Dispatch request failed: " .. tostring(result), status)
        return false
    end
    return result
end

function M.cancel(patrol, status)
    if not active then report("No active dispatch to cancel", status); return end
    local ok, err = pcall(function()
        clear(patrol)
        countdown = math.random(60, 120)
        patrol:NotifyDispatch("NCPD DISPATCH: Assignment cancelled.", 4.0)
    end)
    if ok then
        report("Assignment cancelled; ready for another call", status)
    else
        failed = true
        report("Dispatch cancellation failed: " .. tostring(err), status)
    end
end

function M.update(delta, onDuty, status, getPatrol)
    poll = poll + delta
    if poll < 1 then return end
    local elapsed = math.min(poll, 2)
    poll = 0
    local patrol = getPatrol()
    if not patrol then hide(); return end
    local ok, err = pcall(function()
        if patrol:Version() ~= 17 then return end
        if not onDuty or not patrol:IsOnDuty() then
            if dutySeen then M.reset() end
            if not cleaned then clear(patrol); cleaned = true end
            return
        end
        if not dutySeen then M.start(patrol, status) end
        if failed then return end
        local inMenu = patrol:IsDispatchMenuOpen()
        if active then
            if patrol:GetScannerPhase(active.hash, active.marker) == gamedataMappinPhase.CompletedPhase then
                clear(patrol)
                completed = completed + 1
                countdown = math.random(60, 120)
                patrol:NotifyDispatch("NCPD DISPATCH: Incident resolved. Stand by for your next call.", 8.0)
                report("Incident resolved | Dispatches completed: " .. tostring(completed), status)
                return
            end
            if not inMenu and not active.arrived
                and distance(Game.GetPlayer():GetWorldPosition(), active.position) <= 60 then
                active.arrived = true
                patrol:NotifyDispatch("NCPD DISPATCH: On scene. Resolve the incident and collect evidence.", 4.0)
                report("On scene: " .. active.label, status)
            end
            drawObjective(inMenu)
        elseif automatic and not inMenu and not Game.GetPlayer():IsInCombat() then
            countdown = countdown - elapsed
            if countdown <= 0 then M.request(patrol, status) end
        end
    end)
    if not ok then
        if not failed then report("Dispatch control failed: " .. tostring(err), status) end
        failed = true
        hide()
    end
end

function M.shutdown(patrol)
    if patrol then pcall(clear, patrol) end
    M.reset()
    HUD.shutdown()
end

return M
