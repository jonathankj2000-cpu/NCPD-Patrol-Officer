-- Native trunk/input/repair state stays in redscript; existing CET controllers
-- perform partner and dispatch operations. A command is consumed exactly once.
local Dispatch = require("dispatch")
local Partner = require("partner")
local Backup = require("backup")
local M = {}
local reported = false

local function native()
    local system = Game.GetScriptableSystemsContainer():Get("NCPDPatrolTrunkSystem")
    if not system or system:Version() ~= 4 then error("Install all v0.15c files and restart the game") end
    return system
end

function M.reset()
    -- Never call a native method using a loaded-away world's references.
    reported = false
    Dispatch.setBusy(false)
end

function M.finish()
    pcall(function() native():FinishSession() end)
    M.reset()
end

function M.setBusy(value, status)
    local ok, err = pcall(function()
        local system = native()
        system:SetBusy(value)
        Dispatch.setBusy(system:IsBusy())
    end)
    if not ok and status then status("Patrol menu: " .. tostring(err)) end
end

function M.showStats(status)
    local ok, err = pcall(function() native():ShowStats() end)
    if not ok and status then status("Cop Stats unavailable: " .. tostring(err)) end
end

function M.repairSeconds()
    local ok, value = pcall(function() return native():GetRepairSeconds() end)
    return ok and value or 0
end

function M.update(delta, onDuty, patrol, status)
    local ok, err = pcall(function()
        local system = native()
        system:Tick(delta)
        Dispatch.setBusy(system:IsBusy())
        if not onDuty or not patrol or not patrol:IsOnDuty() then return end
        local command = system:TakeCommand()
        if command == 3 then
            local accepted = Partner.replace(onDuty, status)
            system:ReportCommand(accepted and "NCPD: New partner requested. Waiting for arrival."
                or "NCPD: Partner replacement failed. No extra partner spawned; see CET log.")
        elseif command == 4 then
            local hadAssignment = Dispatch.isActive()
            if not Dispatch.cancel(patrol, status) then
                system:ReportCommand(hadAssignment and "NCPD: Dispatch cancellation failed; see CET log."
                    or "NCPD: No active dispatch to cancel.")
            end
        elseif command == 5 then
            if not Dispatch.replace(patrol, status) then
                system:ReportCommand("NCPD: No new dispatch assigned. " .. Dispatch.state())
            end
        elseif command == 7 then
            local support = Game.GetScriptableSystemsContainer():Get("NCPDPatrolSupportSystem")
            Backup.release(support, patrol, status)
        end
    end)
    if not ok and not reported then
        reported = true
        if status then status("Patrol menu unavailable: " .. tostring(err)) end
    end
end

return M
