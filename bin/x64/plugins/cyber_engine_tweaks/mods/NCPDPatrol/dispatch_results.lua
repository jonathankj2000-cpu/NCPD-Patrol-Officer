-- Read native generated results and keep shift-local dispatch statistics.
-- The native incident/scanner/arrest ledgers remain the sole payment owners.
local M = {}
local completed, failedCalls = 0, 0
local lastOutcome = "No dispatch result this shift"
local incidentBaseline, lastRewardRevision = 0, -1
local seenGenerated = {}

local function incidentSystem()
    local container = Game.GetScriptableSystemsContainer()
    return container and container:Get("NCPDPatrolIncidentSystem") or nil
end

local function generatedCount()
    local ok, count = pcall(function()
        local system = incidentSystem()
        return system and system:Version() == 1 and system:GetCompletedCount() or 0
    end)
    return ok and count or 0
end

function M.completed() return completed + math.max(0, generatedCount() - incidentBaseline) end
function M.failedCount() return failedCalls end
function M.lastOutcome() return lastOutcome end
function M.scannerCompleted()
    completed = completed + 1
    lastOutcome = "COMPLETED | Incident resolved"
    return completed
end
function M.record(outcome, failed)
    lastOutcome = outcome
    if failed then failedCalls = failedCalls + 1 end
end

-- Terminal stage meanings are native contracts: 3 success, 4 failure,
-- 5 cancellation, 6 journal error. Tokens are scoped to their native system.
function M.observeGenerated(recordOnly, onClosed)
    for _, name in ipairs({"NCPDPatrolVIPSystem", "NCPDPatrolCyberpsychoSystem", "NCPDPatrolOfficerDownSystem"}) do
        pcall(function()
            local backend = Game.GetScriptableSystemsContainer():Get(name)
            local expected = name == "NCPDPatrolOfficerDownSystem" and 1 or 4
            if not backend or backend:Version() ~= expected then return end
            local stage = backend:GetStage()
            if stage < 3 or stage > 6 then return end
            local key = name .. ":" .. tostring(backend:GetToken())
            if seenGenerated[key] then return end
            seenGenerated[key] = true
            if recordOnly then return end
            onClosed()
            if stage == 3 then M.record("COMPLETED | " .. tostring(backend:GetReason()))
            elseif stage == 5 then M.record("CANCELLED | " .. tostring(backend:GetReason()))
            else M.record((stage == 6 and "JOURNAL ERROR | " or "FAILED | ") .. tostring(backend:GetReason()), true) end
        end)
    end
end

function M.reset()
    completed, failedCalls = 0, 0
    lastOutcome = "No dispatch result this shift"
    incidentBaseline, lastRewardRevision = generatedCount(), -1
    seenGenerated = {}
    M.observeGenerated(true)
end

function M.updateRewards(delta, status)
    local ok, err = pcall(function()
        local system = incidentSystem()
        if not system or system:Version() ~= 1 then return end
        system:Tick(delta)
        local revision = system:GetRevision()
        if revision ~= lastRewardRevision then
            lastRewardRevision = revision
            if status then status("Incident rewards | " .. system:GetDiagnostics()) end
        end
    end)
    if not ok and status then status("Incident reward control | " .. tostring(err)) end
end

function M.rewardDiagnostics()
    local ok, text = pcall(function() return incidentSystem():GetDiagnostics() end)
    return ok and text or "Install the complete v0.17a incident module and restart"
end

return M
