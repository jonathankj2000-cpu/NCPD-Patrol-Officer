-- The archived phase owns the marker. This controller spawns no entities.
local M={}
local phase,label='idle','Andrea reference marker test ready (off duty only)'
local revision=-1
local function native()
    local system=Game.GetScriptableSystemsContainer():Get('NCPDPatrolQuestMarkerProbeSystem')
    if not system or system:Version()~=5 then error('Install the complete r4d quest-phase marker package and restart') end
    return system
end
local function report(text,status) label=text;if status then status('Quest marker test | '..text) end end
function M.state() return label end
function M.reset() phase,label='idle','Andrea reference marker test ready (off duty only)';revision=-1 end
function M.diagnostics()
    local ok,text=pcall(function() return native():GetDiagnostics() end)
    return 'phase='..phase..' | Andrea reference / fixed Coyote position | '..(ok and text or tostring(text))
end
function M.finish(status,reason)
    local ok,err=pcall(function()
        local backend=native()
        if phase=='idle' and not backend:HasRequest() and not backend:HasPendingCleanup() then return end
        backend:Stop(reason or 'Closing archived marker test')
        phase=backend:HasPendingCleanup() and 'cleanup' or 'idle'
    end)
    if status then report(ok and (reason or 'Marker phase closing; waiting for confirmed cleanup') or tostring(err),status) end
    return ok and phase=='idle'
end
local function start(status,visual)
    if phase~='idle' then report('The current test or its cleanup is still active',status);return false end
    local ok,err=pcall(function()
        local backend=native()
        if not visual and not backend:IsReady() then error('Archived marker phase not ready. Install the complete archive/.xl and restart. '..backend:GetDiagnostics()) end
        if not (visual and backend:BeginVisual() or (not visual and backend:Begin())) then error(backend:GetDiagnostics()) end
        phase='active';revision=-1
        report(visual and 'Visual control at El Coyote Cojo. Journal/GPS not verified.' or 'Reference quest requested at El Coyote Cojo. Inspect the map after five seconds.',status)
    end)
    if not ok then report(tostring(err),status);return false end
    return true
end
function M.start(status) return start(status,false) end
function M.startVisual(status) return start(status,true) end
function M.update(delta,onDuty,status)
    if not Game.GetPlayer() then return end
    local ok,err=pcall(function()
        local backend=native();backend:Tick(delta)
        if phase=='idle' then return end
        if onDuty and backend:HasRequest() then M.finish(status,'Closing test as a normal shift starts') end
        if not backend:HasRequest() then
            phase=backend:HasPendingCleanup() and 'cleanup' or 'idle'
        end
        local value=backend:GetRevision()
        if value~=revision then revision=value;report(backend:GetDiagnostics(),status) end
    end)
    if not ok and phase~='idle' then M.finish(nil,'Test failed');report(tostring(err),status) end
end
return M
