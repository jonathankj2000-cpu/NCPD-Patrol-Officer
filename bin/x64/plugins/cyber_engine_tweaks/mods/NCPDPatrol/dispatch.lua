-- Dispatch selects existing scanner activities; rewards remain in redscript.
local HUD = require("dispatch_hud")
local Journal = require("dispatch_journal")
local Cyberpsycho = require("cyberpsycho")
local VIP = require("vip")
local M = {}
local active, used = nil, {}
local automatic, dutySeen, cleaned = true, false, false
local busy = false
local countdown, poll = 0, 0
local state = "OFF DUTY"
local completed, candidateCount = 0, 0
local failedCalls, lastOutcome = 0, "No dispatch result this shift"
local failed = false
local soundEnabled = true
local voiceEnabled = true
local navigation = "No active dispatch"
local lastBriefing = nil

local function chooseBriefing()
    if lastBriefing == nil then return math.random(0, 5) end
    local nextBriefing = math.random(0, 4)
    if nextBriefing >= lastBriefing then nextBriefing = nextBriefing + 1 end
    return nextBriefing
end

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
    if not active.arrived then
        local _, seconds = Journal.snapshot(active.journalToken)
        objective = objective .. string.format("\nResponse deadline: %02d:%02d", math.floor(seconds / 60), seconds % 60)
    end
    HUD.set("NCPD DISPATCH\n" .. active.label .. "\n" .. objective, not inMenu)
end

function M.init() HUD.init() end
function M.state() return VIP.isActive() and VIP.state() or (Cyberpsycho.isActive() and Cyberpsycho.state() or state) end
function M.vipState() return VIP.state() end
function M.vipDiagnostics() return VIP.diagnostics() end
function M.vipAmbushState() return VIP.ambushState() end
function M.cyberpsychoState() return Cyberpsycho.state() end
function M.cyberpsychoDiagnostics() return Cyberpsycho.diagnostics() end
function M.cyberpsychoVariantState() return Cyberpsycho.variantState() end
function M.cycleCyberpsychoVariant(status) return Cyberpsycho.cycleVariant(status) end
function M.randomCyberpsychoVariants(status) return Cyberpsycho.randomVariants(status) end
function M.hudState() return HUD.state() end
function M.isAutomatic() return automatic end
function M.isBusy() return busy end
function M.setBusy(value) busy = value == true end
function M.isActive() return active ~= nil or Cyberpsycho.isActive() or VIP.isActive() end
function M.completed() return completed end
function M.failedCount() return failedCalls end
function M.lastOutcome() return lastOutcome end
function M.journalDiagnostics() return Journal.diagnostics() end
function M.armTimeoutTest(patrol, status)
    if not active or not Journal.armTimeout(active.journalToken) then
        if status then status("Dispatch | Timeout test needs an active call more than 60 m away, before On scene.") end
        return false
    end
    if patrol then patrol:NotifyDispatch("NCPD TEST: Response deadline shortened to 15 seconds. Remain away from the scene to test expiry.", 6.0) end
    if status then status("Dispatch | TEST: 15-second response deadline armed") end
    return true
end
function M.seconds() return math.max(0, math.ceil(countdown)) end
function M.candidates() return candidateCount end
function M.isSoundEnabled() return soundEnabled end
function M.isVoiceEnabled() return voiceEnabled end
function M.navigationState()
    if VIP.isActive() then return "VIP pickup/delivery marker active. GPS may require opening the map." end
    if Cyberpsycho.isActive() then return "Cyberpsycho scene marker; HUD shows target distance. GPS may require opening the map." end
    return navigation
end
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
    Journal.reset()
    busy = false
    active, used = nil, {}
    navigation = "No active dispatch"
    poll, completed, candidateCount = 0, 0, 0
    failedCalls, lastOutcome = 0, "No dispatch result this shift"
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
    if VIP.isActive() then VIP.finish(patrol, status, "Shift ended; VIP transport closed") end
    if Cyberpsycho.isActive() or Cyberpsycho.hasCleanup() then Cyberpsycho.finish(patrol, status, "Shift ended; cyberpsycho test closed") end
    Journal.update(0, status)
    if active then
        local stage, _, reason = Journal.snapshot(active.journalToken)
        if stage == 4 then failedCalls = failedCalls + 1; lastOutcome = "FAILED | " .. tostring(reason) end
    end
    Journal.cancel(active and active.journalToken or 0, "Shift ended")
    busy = false
    local ok, err = pcall(clear, patrol)
    active, used, dutySeen = nil, {}, false
    countdown, poll, cleaned = 0, 0, ok
    hide()
    report(ok and "OFF DUTY" or ("Waypoint cleanup failed: " .. tostring(err)), status)
end

-- Used after a load: never remove a marker by an ID from the previous world.
function M.reset(keepVIPCleanup)
    if not keepVIPCleanup then VIP.reset() end
    Cyberpsycho.reset()
    Journal.reset()
    busy = false
    active, used, dutySeen, cleaned = nil, {}, false, false
    countdown, poll, completed, candidateCount = 0, 0, 0, 0
    failed, state = false, "OFF DUTY"
    failedCalls, lastOutcome = 0, "No dispatch result this shift"
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
        if M.isActive() then report("A dispatch or target cleanup is already active; complete or cancel it first", status); return false end
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
        local briefing = chooseBriefing()
        local token, journalError = Journal.begin(chosen.hash, chosen.position, briefing)
        if not token then
            countdown = 30
            report("Journal unavailable: " .. tostring(journalError), status)
            return false
        end
        active = chosen
        lastBriefing = briefing
        active.journalToken = token
        patrol:ClearDispatchWaypoints()
        local id = patrol:PlaceDispatchWaypoint(chosen.position)
        if not id or not id.value or id.value == 0 then error("Game did not return a dispatch waypoint ID") end
        used[chosen.key] = true
        active.arrived = false
        active.waypoint = id
        countdown = 0
        navigation = "Dispatch marker active. Open and close the map if you need the GPS line."
        patrol:NotifyDispatch("NCPD DISPATCH: " .. chosen.label .. ". Respond to the marked location. Dispatch completion supplement: €$500.", 8.0, soundEnabled, voiceEnabled)
        drawObjective(patrol:IsDispatchMenuOpen())
        report("Assigned: " .. chosen.label .. " | POI=" .. chosen.key .. " | distance=" .. tostring(math.floor(chosen.distance))
            .. " m | search radius=" .. tostring(radius) .. " m | " .. navigation, status)
        return true
    end)
    if not ok then
        if active then Journal.cancel(active.journalToken, "Dispatch setup failed") end
        pcall(clear, patrol)
        failed = true
        report("Dispatch request failed: " .. tostring(result), status)
        return false
    end
    return result
end

function M.cancel(patrol, status)
    if VIP.isActive() then
        local cleared = VIP.cancel(patrol, status)
        hide()
        if cleared then countdown = math.random(60, 120) end
        return cleared
    end
    if Cyberpsycho.isActive() then
        local cleared = Cyberpsycho.cancel(patrol, status)
        hide()
        if cleared then countdown = math.random(60, 120) end
        return cleared
    end
    if not active then report("No active dispatch to cancel", status); return false end
    local ok, err = pcall(function()
        local cancelled, message = Journal.cancel(active.journalToken, "Assignment cancelled")
        if not cancelled then error(message) end
        clear(patrol)
        countdown = math.random(60, 120)
        patrol:NotifyDispatch("NCPD DISPATCH: Assignment cancelled.", 4.0)
    end)
    if ok then
        lastOutcome = "CANCELLED | Assignment cancelled"
        report("Assignment cancelled; ready for another call", status)
    else
        failed = true
        report("Dispatch cancellation failed: " .. tostring(err), status)
    end
    return ok
end

function M.replace(patrol, status)
    if M.isActive() and not M.cancel(patrol, status) then return false end
    return M.request(patrol, status)
end

function M.requestCyberpsycho(patrol, status)
    if M.isActive() then
        if status then status("Cyberpsycho | Cancel/clear the current dispatch before requesting a test incident") end
        return false
    end
    local accepted = Cyberpsycho.request(patrol, status, soundEnabled, voiceEnabled)
    if accepted then countdown = math.random(60, 120) end
    return accepted
end

function M.requestVIP(patrol, status)
    if M.isActive() then
        if status then status("VIP | Cancel/clear the current dispatch before requesting transport") end
        return false
    end
    local accepted = VIP.request(patrol, status, soundEnabled, voiceEnabled)
    if accepted then countdown = math.random(60, 120) end
    return accepted
end
function M.requestVIPAmbush(status) return VIP.requestAmbush(status) end

function M.update(delta, onDuty, status, getPatrol)
    Journal.update(delta, status)
    local cyberBusy = Cyberpsycho.update(delta, onDuty, getPatrol(), status, HUD)
    local vipBusy = VIP.update(delta, onDuty, getPatrol(), status, HUD)
    poll = poll + delta
    if poll < 1 then return end
    local elapsed = math.min(poll, 2)
    poll = 0
    local patrol = getPatrol()
    if not patrol then hide(); return end
    local ok, err = pcall(function()
        if patrol:Version() ~= 17 then return end
        if not onDuty or not patrol:IsOnDuty() then
            if dutySeen and not Cyberpsycho.isActive() and not Cyberpsycho.hasCleanup() and not VIP.isActive() then M.reset() end
            if not cleaned then clear(patrol); cleaned = true end
            return
        end
        if not dutySeen then M.start(patrol, status) end
        if cyberBusy or vipBusy then return end
        if failed then return end
        local inMenu = patrol:IsDispatchMenuOpen()
        if active then
            local stage, _, reason = Journal.snapshot(active.journalToken)
            if stage == 4 or stage == 5 or stage == 6 or stage == -1 then
                clear(patrol)
                countdown = math.random(60, 120)
                if stage == 4 then
                    failedCalls = failedCalls + 1
                    lastOutcome = "FAILED | " .. tostring(reason)
                    patrol:NotifyDispatch("NCPD DISPATCH FAILED: " .. tostring(reason) .. ". Assignment closed.", 8.0)
                elseif stage == 6 then
                    failed = true
                    lastOutcome = "JOURNAL ERROR | " .. tostring(reason)
                    patrol:NotifyDispatch("NCPD: Dispatch journal error. Check CET diagnostics before requesting another call.", 8.0)
                else
                    lastOutcome = "CANCELLED | " .. tostring(reason)
                end
                report(lastOutcome, status)
                return
            end
            if patrol:GetScannerPhase(active.hash, active.marker) == gamedataMappinPhase.CompletedPhase then
                if stage ~= 2 then
                    Journal.cancel(active.journalToken, "Incident resolved before attendance")
                    clear(patrol)
                    countdown = math.random(60, 120)
                    lastOutcome = "CLOSED | Incident resolved before attendance"
                    report(lastOutcome, status)
                    patrol:NotifyDispatch("NCPD: Incident resolved before your arrival. Assignment withdrawn.", 6.0)
                    return
                end
                local accepted, message = Journal.complete(active.journalToken, active.marker)
                if not accepted then error("Journal completion rejected: " .. tostring(message)) end
                clear(patrol)
                completed = completed + 1
                lastOutcome = "COMPLETED | Incident resolved"
                countdown = math.random(60, 120)
                patrol:NotifyDispatch("NCPD DISPATCH: Incident resolved. Stand by for your next call.", 8.0)
                report("Incident resolved | Dispatches completed: " .. tostring(completed), status)
                return
            end
            if not inMenu and not active.arrived and stage == 2 then
                active.arrived = true
                patrol:NotifyDispatch("NCPD DISPATCH: On scene. Resolve the incident and collect evidence.", 4.0)
                report("On scene: " .. active.label, status)
            end
            drawObjective(inMenu)
        elseif automatic and not busy and not inMenu and not Game.GetPlayer():IsInCombat() then
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
    if VIP.isActive() then VIP.finish(patrol, nil, "Mod shutdown") end
    if Cyberpsycho.isActive() then Cyberpsycho.finish(patrol, nil, "Mod shutdown") end
    Journal.cancel(active and active.journalToken or 0, "Mod shutdown")
    if patrol then pcall(clear, patrol) end
    M.reset(true)
    HUD.shutdown()
end

return M
