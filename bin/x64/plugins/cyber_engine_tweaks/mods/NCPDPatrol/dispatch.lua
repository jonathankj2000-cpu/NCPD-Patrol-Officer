-- Weighted scanner/VIP/cyberpsycho dispatch. Native code owns earned rewards.
local HUD = require("dispatch_hud")
local Journal = require("dispatch_journal")
local Cyberpsycho = require("cyberpsycho")
local VIP = require("vip")
local OfficerDown = require("officer_down")
local Scanner = require("dispatch_scanner")
local Schedule = require("dispatch_scheduler")
local Results = require("dispatch_results")
local M = {}
local dutySeen, cleaned = false, false
local poll = 0
local state = "OFF DUTY"
local failed = false
local soundEnabled, voiceEnabled = true, true

local function stopped() return failed or Scanner.isFailed() end
local function report(message, status)
    state = message
    if status then status("Dispatch | " .. message) end
end

local function hide()
    HUD.set("", false)
end

function M.init() HUD.init() end
function M.state() return OfficerDown.isActive() and OfficerDown.state() or (VIP.isActive() and VIP.state() or (Cyberpsycho.isActive() and Cyberpsycho.state() or state)) end
function M.vipState() return VIP.state() end
function M.vipDiagnostics() return VIP.diagnostics() end
function M.refreshVIPWaypoint(patrol,status) return VIP.refreshWaypoint(patrol,status) end
function M.vipAmbushState() return VIP.ambushState() end
function M.vipAmbushCars() return VIP.ambushSetting() end
function M.cycleVIPAmbushCars(status) return VIP.cycleAmbushCars(status) end
function M.cyberpsychoState() return Cyberpsycho.state() end
function M.cyberpsychoDiagnostics() return Cyberpsycho.diagnostics() end
function M.cyberpsychoVariantState() return Cyberpsycho.variantState() end
function M.cycleCyberpsychoVariant(status) return Cyberpsycho.cycleVariant(status) end
function M.randomCyberpsychoVariants(status) return Cyberpsycho.randomVariants(status) end
function M.hudState() return HUD.state() end
function M.isAutomatic() return Schedule.isAutomatic() end
function M.isBusy() return Schedule.isBusy() end
function M.setBusy(value) Schedule.setBusy(value) end
-- Existing callers use this as the global reservation guard, including live
-- actor cleanup. Background scenes do not reserve the next assignment.
function M.isActive() return Scanner.isActive() or Cyberpsycho.isActive() or VIP.isActive() or OfficerDown.isActive() end
function M.lifecycle()
    local vip, cyber = VIP.lifecycle(), Cyberpsycho.lifecycle()
    return {
        scanner = Scanner.isActive(), vip = vip, cyberpsycho = cyber,
        reserved = Scanner.isActive() or vip.reserved or cyber.reserved or OfficerDown.isActive(),
        foregroundCleanup = vip.foregroundCleanup or cyber.foregroundCleanup or OfficerDown.lifecycle().foregroundCleanup,
        backgroundCleanup = vip.backgroundCleanup or cyber.backgroundCleanup or OfficerDown.lifecycle().backgroundCleanup,
        standby = Schedule.isCooling(),
    }
end
function M.completed() return Results.completed() end
function M.mixDescription() return Schedule.mixDescription(OfficerDown.supportsCatalog()) end
function M.rewardDiagnostics() return Results.rewardDiagnostics() end
function M.failedCount() return Results.failedCount() end
function M.lastOutcome() return Results.lastOutcome() end
function M.journalDiagnostics() return Journal.diagnostics() end
function M.armTimeoutTest(patrol, status)
    if not Scanner.armTimeout() then
        if status then status("Dispatch | Timeout test needs an active call more than 60 m away, before On scene.") end
        return false
    end
    if patrol then patrol:NotifyDispatch("NCPD TEST: Response deadline shortened to 15 seconds. Remain away from the scene to test expiry.", 6.0) end
    if status then status("Dispatch | TEST: 15-second response deadline armed") end
    return true
end
function M.seconds() return Schedule.seconds() end
function M.schedulerStatus(patrol)
    local ok,text=pcall(function()
        if not patrol or not Game.GetPlayer() then return "Load a save" end
        if not patrol:IsOnDuty() then return "OFF DUTY" end
        if stopped() then return "Stopped after a dispatch API error; check CET log" end
        if not Schedule.isAutomatic() then return "Automatic calls paused" end
        if Schedule.isBusy() then return "BUSY; automatic calls paused" end
        if patrol:IsDispatchMenuOpen() then return "Game menu open; standby timer paused" end
        if Game.GetPlayer():IsInCombat() then return "In combat; standby timer paused" end
        if M.isActive() then
            if Schedule.isCooling() then
                return not Schedule.isDue() and ("Next call in about "..M.seconds().." s; scene cleanup continues")
                    or "Standby elapsed; waiting for confirmed actor cleanup"
            end
            return "Assignment active; standby starts when it closes"
        end
        return "Next automatic call in about "..M.seconds().." s"..(VIP.hasCleanup() and "; previous ambush cleanup continues in background" or "")
    end)
    return ok and text or ("Scheduler status unavailable: "..tostring(text))
end
function M.schedulerDiagnostics(patrol)
    local lifecycle = M.lifecycle()
    return M.schedulerStatus(patrol).." | seconds="..M.seconds().." | generated standby="..tostring(Schedule.isCooling())
        .." | reserved="..tostring(lifecycle.reserved).." | foreground cleanup="..tostring(lifecycle.foregroundCleanup)
        .." | background cleanup="..tostring(lifecycle.backgroundCleanup)
        .." | VIP: "..VIP.diagnostics().." | Cyberpsycho: "..Cyberpsycho.diagnostics()
        ..(OfficerDown.supportsCatalog() and (" | Officer Down: "..OfficerDown.diagnostics()) or "")
end
function M.candidates() return Scanner.candidates() end
function M.isSoundEnabled() return soundEnabled end
function M.isVoiceEnabled() return voiceEnabled end
function M.navigationState()
    if OfficerDown.isActive() then return "Officer Down fixed quest marker; manual waypoint retained." end
    if VIP.isActive() then return "VIP pickup/delivery marker active. GPS may require opening the map." end
    if Cyberpsycho.isActive() then return "Cyberpsycho scene marker; HUD shows target distance. GPS may require opening the map." end
    return Scanner.navigationState()
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
    Schedule.prepareShift()
    Scanner.reset()
    poll = 0
    Results.reset()
    failed, dutySeen = false, true
    cleaned = false
    local ok, err = pcall(Scanner.clear, patrol)
    if not ok then
        failed = true
        report("Waypoint cleanup failed: " .. tostring(err), status)
        return
    end
    cleaned = true
    Schedule.start()
    report("Standing by for calls", status)
end

function M.finish(patrol, status)
    if OfficerDown.isActive() or OfficerDown.hasCleanup() then OfficerDown.finish(patrol, status, "Shift ended; Officer Down closed") end
    if VIP.isActive() or VIP.hasCleanup() then VIP.finish(patrol, status, "Shift ended; VIP transport closed", false, true) end
    if Cyberpsycho.isActive() or Cyberpsycho.hasCleanup() then Cyberpsycho.finish(patrol, status, "Shift ended; cyberpsycho test closed") end
    Journal.update(0, status)
    Scanner.recordShiftEnd()
    Journal.cancel(Scanner.token(), "Shift ended")
    local ok, err = pcall(Scanner.clear, patrol)
    Scanner.resetHistory()
    dutySeen = false
    Schedule.finish()
    poll, cleaned = 0, ok
    hide()
    report(ok and "OFF DUTY" or ("Waypoint cleanup failed: " .. tostring(err)), status)
end

-- Used after a load: never remove a marker by an ID from the previous world.
function M.reset(keepVIPCleanup)
    if not keepVIPCleanup then OfficerDown.reset() end
    if not keepVIPCleanup then VIP.reset() end
    Cyberpsycho.reset()
    Journal.reset()
    Scanner.reset()
    dutySeen, cleaned, poll = false, false, 0
    Schedule.reset()
    failed, state = false, "OFF DUTY"
    Results.reset()
    hide()
end

function M.setAutomatic(value, status) Schedule.setAutomatic(value, status) end

function M.request(patrol, status)
    if not patrol or not Game.GetPlayer() then
        report("Load a save before requesting a dispatch", status)
        return false
    end
    local ok, result = pcall(function()
        if patrol:Version() ~= 17 then error("Install all v0.7b Lua/redscript files and restart the game") end
        if not patrol:IsOnDuty() then report("Start a shift before requesting a dispatch", status); return false end
        if stopped() then report("Dispatch stopped after an API error; end and restart the shift to retry", status); return false end
        if M.isActive() then report("A dispatch or target cleanup is already active; complete or cancel it first", status); return false end
        return Scanner.request(patrol, status, soundEnabled, voiceEnabled, report)
    end)
    if not ok then
        if Scanner.isActive() then Journal.cancel(Scanner.token(), "Dispatch setup failed") end
        pcall(Scanner.clear, patrol)
        failed = true
        report("Dispatch request failed: " .. tostring(result), status)
        return false
    end
    return result
end

function M.cancel(patrol, status)
    if OfficerDown.isActive() then
        local cleared = OfficerDown.cancel(patrol, status)
        hide()
        if cleared then Schedule.standby() end
        return cleared
    end
    if VIP.isActive() then
        local cleared = VIP.cancel(patrol, status)
        hide()
        if cleared then Schedule.standby() end
        return cleared
    end
    if Cyberpsycho.isActive() then
        local cleared = Cyberpsycho.cancel(patrol, status)
        hide()
        if cleared then Schedule.standby() end
        return cleared
    end
    if not Scanner.isActive() then report("No active dispatch to cancel", status); return false end
    local ok, err = pcall(function()
        Scanner.cancel(patrol)
    end)
    if ok then
        Results.record("CANCELLED | Assignment cancelled")
        report("Assignment cancelled; ready for another call", status)
    else
        failed = true
        report("Dispatch cancellation failed: " .. tostring(err), status)
    end
    return ok
end

function M.replace(patrol, status)
    if M.isActive() and not M.cancel(patrol, status) then return false end
    return M.requestMixed(patrol, status)
end

function M.requestCyberpsycho(patrol, status)
    if M.isActive() then
        if status then status("Cyberpsycho | Cancel/clear the current dispatch before requesting a test incident") end
        return false
    end
    local accepted = Cyberpsycho.request(patrol, status, soundEnabled, voiceEnabled)
    if accepted then Schedule.generatedAssigned() end
    return accepted
end

function M.requestVIP(patrol, status)
    if M.isActive() then
        if status then status("VIP | Cancel/clear the current dispatch before requesting transport") end
        return false
    end
    local accepted = VIP.request(patrol, status, soundEnabled, voiceEnabled)
    if accepted then Schedule.generatedAssigned() end
    return accepted
end
function M.requestVIPAmbush(status) return VIP.requestAmbush(status) end

-- This first scene is manual-only; weighted automatic choices are unchanged.
function M.requestOfficerDown(patrol, status)
    if M.isActive() then
        if status then status("Officer Down | Cancel/clear the current dispatch before requesting the test") end
        return false
    end
    local accepted = OfficerDown.request(patrol, status, soundEnabled, voiceEnabled)
    if accepted then Schedule.generatedAssigned() end
    return accepted
end
function M.requestOfficerDownNearby(patrol,status,source)
    if M.isActive() then
        if status then status("Officer Down | Complete/cancel the current assignment and its cleanup first") end
        return false
    end
    local accepted=OfficerDown.requestNearby(patrol,status,soundEnabled,voiceEnabled,source or 'manual')
    if accepted then Schedule.generatedAssigned() end
    return accepted
end
function M.officerDownLogState() return OfficerDown.logState() end
-- v018i catalogue metadata begin
function M.officerDownCatalogueInfo()
    local catalog = require("officer_down_sites")
    local enabled = 0
    for _, site in ipairs(catalog.sites) do
        if site.enabled then enabled = enabled + 1 end
    end
    return tostring(enabled) .. " enabled locations | " .. catalog.coverage
end
-- v018i catalogue metadata end
function M.exportOfficerDownLog(status) return OfficerDown.exportLog(status) end
function M.officerDownState() return OfficerDown.state() end
function M.officerDownDiagnostics() return OfficerDown.diagnostics() end
function M.rotateOfficerDown(status) return OfficerDown.rotate(status) end
function M.reviveOfficerDown(status) return OfficerDown.revive(status) end
function M.clearOfficerDown(patrol,status) return OfficerDown.cancel(patrol,status) end

local function generatedAvailable(name)
    local ok, ready = pcall(function()
        local system = Game.GetScriptableSystemsContainer():Get(name)
        local container = Game.GetScriptableSystemsContainer()
        local rewards = container and container:Get("NCPDPatrolIncidentSystem") or nil
        local entities = Game.GetDynamicEntitySystem()
        return system and system:Version() == 4 and system:IsReady()
            and rewards and rewards:Version() == 1 and entities and entities:IsReady()
    end)
    return ok and ready == true
end

-- Draw without replacement, preserving original weights among remaining types.
-- A failed request with owned actors/cleanup blocks every subsequent attempt.
function M.requestMixed(patrol,status,source)
    local player=Game.GetPlayer()
    if not patrol or not player or not patrol:IsOnDuty() or patrol:HasWantedLevel() then
        report("An active, non-wanted shift is required",status);return false
    end
    if stopped() or M.isActive() then report("Finish the active call or its cleanup first",status);return false end
    if patrol:IsDispatchMenuOpen() or player:IsInCombat() then report("Leave menus and combat before requesting a call",status);return false end
    local withOfficer=OfficerDown.supportsCatalog()
    local choices = Schedule.choices(withOfficer)
    for _=1,#choices do
        local choice = Schedule.draw(choices)
        local accepted=false
        if choice.name=="Scanner" then accepted=M.request(patrol,status)
        elseif choice.name=="VIP" and generatedAvailable("NCPDPatrolVIPSystem") then accepted=M.requestVIP(patrol,status)
        elseif choice.name=="Cyberpsycho" and generatedAvailable("NCPDPatrolCyberpsychoSystem") then accepted=M.requestCyberpsycho(patrol,status)
        elseif choice.name=="Officer Down" then accepted=M.requestOfficerDownNearby(patrol,status,source or 'mixed') end
        if accepted then
            if status then status("Dispatch mix | Assigned "..choice.name.." | "..M.mixDescription()) end
            return true
        end
        if M.isActive() or stopped() then return false end
        if status then status("Dispatch mix | "..choice.name.." unavailable; trying another type") end
    end
    Schedule.retry()
    report(withOfficer and "No suitable scanner, VIP, cyberpsycho or Officer Down call; retrying in 30 seconds"
        or "No suitable scanner, VIP or cyberpsycho call; retrying in 30 seconds",status)
    return false
end

function M.update(delta, onDuty, status, getPatrol)
    Results.updateRewards(delta,status)
    Journal.update(delta, status)
    local cyberBusy = Cyberpsycho.update(delta, onDuty, getPatrol(), status, HUD)
    local vipBusy = VIP.update(delta, onDuty, getPatrol(), status, HUD)
    local officerBusy = OfficerDown.update(delta, onDuty, getPatrol(), status, HUD)
    Results.observeGenerated(false,function() Schedule.generatedClosed(status) end)
    poll = poll + delta
    if poll < 1 then return end
    local elapsed = math.min(poll, 2)
    poll = 0
    local patrol = getPatrol()
    if not patrol then hide(); return end
    local ok, err = pcall(function()
        if patrol:Version() ~= 17 then return end
        if not onDuty or not patrol:IsOnDuty() then
            if dutySeen and not Cyberpsycho.isActive() and not Cyberpsycho.hasCleanup() and not VIP.isActive() and not VIP.hasCleanup() and not OfficerDown.isActive() and not OfficerDown.hasCleanup() then M.reset() end
            if not cleaned then Scanner.clear(patrol); cleaned = true end
            return
        end
        if not dutySeen then M.start(patrol, status) end
        if stopped() then return end
        local inMenu = patrol:IsDispatchMenuOpen()
        if cyberBusy or vipBusy or officerBusy then
            -- A completed generated call can retain bodies while they are
            -- cleaned. Do not add that retention time before the normal wait.
            -- Actual actor cleanup still owns the assignment reservation.
            if Schedule.isCooling() and Schedule.canAdvance(inMenu) and not Game.GetPlayer():IsInCombat() then
                Schedule.advance(elapsed, true)
            end
            return
        end
        if Scanner.isActive() then
            Scanner.update(patrol, inMenu, status, report)
        elseif Schedule.canAdvance(inMenu) and not Game.GetPlayer():IsInCombat() then
            Schedule.advance(elapsed, false)
            if Schedule.isDue() then M.requestMixed(patrol, status,'automatic') end
        end
    end)
    if not ok then
        if not stopped() then report("Dispatch control failed: " .. tostring(err), status) end
        failed = true
        hide()
    end
end

function M.shutdown(patrol)
    if OfficerDown.isActive() or OfficerDown.hasCleanup() then OfficerDown.finish(patrol, nil, "Mod shutdown") end
    if VIP.isActive() or VIP.hasCleanup() then VIP.finish(patrol, nil, "Mod shutdown", false, true) end
    if Cyberpsycho.isActive() then Cyberpsycho.finish(patrol, nil, "Mod shutdown") end
    Journal.cancel(Scanner.token(), "Mod shutdown")
    if patrol then pcall(Scanner.clear, patrol) end
    M.reset(true)
    HUD.shutdown()
end

return M
