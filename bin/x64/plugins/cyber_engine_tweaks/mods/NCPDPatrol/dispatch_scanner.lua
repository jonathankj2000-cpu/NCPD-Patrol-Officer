local Navigation = require("marker_navigation") -- r5 marker hook
-- Scanner assignment ownership: candidate history, journal token, marker and HUD.
-- Global request guards remain in dispatch.lua. Native code owns all payments.
local HUD = require("dispatch_hud")
local Journal = require("dispatch_journal")
local Schedule = require("dispatch_scheduler")
local Results = require("dispatch_results")
local M = {}
local active, used = nil, {}
local candidateCount = 0
local navigation = "No active dispatch"
local lastBriefing = nil
local faulted = false
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

local function hide()
    HUD.set("", false)
end

local function clear(patrol)
    -- The native tag identifies our markers even if a save regenerated their IDs.
    patrol:ClearDispatchWaypoints()
    Navigation.clear("scanner") -- r5 marker hook
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

function M.isActive() return active ~= nil end
function M.isFailed() return faulted end
function M.token() return active and active.journalToken or 0 end
function M.candidates() return candidateCount end
function M.navigationState() return Navigation.describe(active and active.waypoint, navigation) end
function M.clear(patrol) clear(patrol) end
-- Shift end clears assignment/history; the last diagnostic counts remain until
-- the next shift. Briefing variation intentionally survives resets, as before.
function M.resetHistory() active, used = nil, {} end
function M.reset()
    active, used, candidateCount = nil, {}, 0
    navigation, faulted = "No active dispatch", false
end
function M.armTimeout() return active and Journal.armTimeout(active.journalToken) end
function M.recordShiftEnd()
    if active then
        local stage, _, reason = Journal.snapshot(active.journalToken)
        if stage == 4 then Results.record("FAILED | " .. tostring(reason), true) end
    end
end
function M.request(patrol, status, soundEnabled, voiceEnabled, report)
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
        Schedule.retry()
        report("No available scanner within 1 km, 1.5 km or 2 km; retrying in 30 seconds", status)
        return false
    end
    local chosen = pool[math.random(1, #pool)]
    chosen.label = chosen.marker:GetVariant() == gamedataMappinVariant.OutpostVariant
        and "Suspected organized crime" or "Assault in progress"
    local briefing = chooseBriefing()
    local token, journalError = Journal.begin(chosen.hash, chosen.position, briefing)
    if not token then
        Schedule.retry()
        report("Journal unavailable: " .. tostring(journalError), status)
        return false
    end
    active = chosen
    Schedule.scannerSelected()
    lastBriefing = briefing
    active.journalToken = token
    patrol:ClearDispatchWaypoints()
    Navigation.clear("scanner") -- r5 marker hook
    local id = Navigation.place(patrol, chosen.position, "scanner")
    if not id or not id.value or id.value == 0 then error("Game did not return a dispatch waypoint ID") end
    used[chosen.key] = true
    active.arrived = false
    active.waypoint = id
    Schedule.scannerAssigned()
    navigation = "Dispatch marker active. Open and close the map if you need the GPS line."
    patrol:NotifyDispatch("NCPD DISPATCH: " .. chosen.label .. ". Respond to the marked location. Dispatch completion supplement: €$500.", 8.0, soundEnabled, voiceEnabled)
    drawObjective(patrol:IsDispatchMenuOpen())
    report("Assigned: " .. chosen.label .. " | POI=" .. chosen.key .. " | distance=" .. tostring(math.floor(chosen.distance))
        .. " m | search radius=" .. tostring(radius) .. " m | " .. navigation, status)
    return true
end

function M.cancel(patrol)
    local cancelled, message = Journal.cancel(active.journalToken, "Assignment cancelled")
    if not cancelled then error(message) end
    clear(patrol)
    Schedule.standby()
    patrol:NotifyDispatch("NCPD DISPATCH: Assignment cancelled.", 4.0)
end

function M.update(patrol, inMenu, status, report)
    local stage, _, reason = Journal.snapshot(active.journalToken)
    if stage == 4 or stage == 5 or stage == 6 or stage == -1 then
        clear(patrol)
        Schedule.standby()
        if stage == 4 then
            Results.record("FAILED | " .. tostring(reason), true)
            patrol:NotifyDispatch("NCPD DISPATCH FAILED: " .. tostring(reason) .. ". Assignment closed.", 8.0)
        elseif stage == 6 then
            faulted = true
            Results.record("JOURNAL ERROR | " .. tostring(reason))
            patrol:NotifyDispatch("NCPD: Dispatch journal error. Check CET diagnostics before requesting another call.", 8.0)
        else
            Results.record("CANCELLED | " .. tostring(reason))
        end
        report(Results.lastOutcome(), status)
        return
    end
    if patrol:GetScannerPhase(active.hash, active.marker) == gamedataMappinPhase.CompletedPhase then
        if stage ~= 2 then
            Journal.cancel(active.journalToken, "Incident resolved before attendance")
            clear(patrol)
            Schedule.standby()
            Results.record("CLOSED | Incident resolved before attendance")
            report(Results.lastOutcome(), status)
            patrol:NotifyDispatch("NCPD: Incident resolved before your arrival. Assignment withdrawn.", 6.0)
            return
        end
        local accepted, message = Journal.complete(active.journalToken, active.marker)
        if not accepted then error("Journal completion rejected: " .. tostring(message)) end
        clear(patrol)
        local completed = Results.scannerCompleted()
        Schedule.standby()
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
end

return M
