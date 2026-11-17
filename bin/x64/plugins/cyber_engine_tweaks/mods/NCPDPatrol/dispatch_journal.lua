-- Small CET bridge; timers, native journal states and tracking live in redscript.
local M = {}
local reported = false
local function native()
    local system = Game.GetScriptableSystemsContainer():Get("NCPDPatrolDispatchJournalSystem")
    if not system or system:Version() ~= 1 then error("Install all v0.9a journal files and restart the game") end
    return system
end
function M.reset() reported = false end -- forget only; no loaded-away handles
function M.update(delta, status)
    local ok, err = pcall(function() native():Tick(delta) end)
    if not ok and not reported then
        reported = true
        if status then status("Dispatch journal | " .. tostring(err)) end
    end
end
function M.begin(hash, position)
    local ok, token, reason = pcall(function()
        local system = native()
        local id = system:BeginDispatch(hash, position)
        return id, system:GetReason()
    end)
    if not ok then return nil, tostring(token) end
    if not token or token == 0 then return nil, tostring(reason) end
    return token
end
function M.snapshot(token)
    local ok, stage, remaining, reason = pcall(function()
        local system = native()
        if system:GetToken() ~= token then return -1, 0, "Previous dispatch session is no longer active" end
        return system:GetStage(), system:GetRemainingSeconds(), system:GetReason()
    end)
    if not ok then return 6, 0, tostring(stage) end
    return stage, remaining, reason
end
function M.complete(token)
    local ok, accepted, reason = pcall(function()
        local system = native()
        local result = system:CompleteDispatch(token)
        return result, system:GetReason()
    end)
    if not ok then return false, tostring(accepted) end
    return accepted == true, reason
end
function M.cancel(token, reason)
    local ok, stage, message = pcall(function()
        local system = native()
        system:CancelDispatch(token or 0, reason or "Assignment cancelled")
        return system:GetStage(), system:GetReason()
    end)
    if not ok then return false, tostring(stage) end
    return stage ~= 6, message
end
function M.armTimeout(token)
    local ok, value = pcall(function() return native():ArmTimeoutTest(token) end)
    return ok and value == true
end
function M.diagnostics()
    local ok, result = pcall(function() return native():GetDiagnostics() end)
    return ok and tostring(result) or ("Journal unavailable: " .. tostring(result))
end
return M
