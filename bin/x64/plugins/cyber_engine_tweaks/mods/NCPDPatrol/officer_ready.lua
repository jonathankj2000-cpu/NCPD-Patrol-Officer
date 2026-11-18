-- Per-officer readiness. A queued command is never treated as an equipped gun.
-- After one second without an actual slot change, use the game's equipment
-- routines on our tagged officer's existing inventory. Native combat wins.
local M = {}
local function bridge()
    local system=Game.GetScriptableSystemsContainer():Get("NCPDPatrolOfficerEquipment")
    if not system or system:Version()~=1 then error("Install all v0.15c files and restart the game") end
    return system
end
local function stopOurs(state,actor)
    if state.command and actor then
        pcall(function() actor:GetAIControllerComponent():StopExecutingCommand(state.command,false) end)
    end
    state.command=nil;state.pending=false
end
function M.release(state,actor)
    stopOurs(state,actor)
    state.wanted=nil;state.stable=0;state.retry=0;state.attempts=0
end
function M.diagnostics(state,actor)
    local ok,value=pcall(function()
        local command="none"
        if actor and state.command then
            command=tostring(actor:GetAIControllerComponent():GetCommandState(state.command))
        end
        return bridge():GetDiagnostics(actor).." | command="..command
            .." | attempts="..tostring(state.attempts or 0).." | fallbacks="..tostring(state.fallbacks or 0)
            .." | last fallback="..tostring(state.lastFallback or "none").." | result="..tostring(state.result or "none")
    end)
    return ok and value or ("Equipment diagnostics unavailable: "..tostring(value))
end
function M.update(state,delta,actor,patrol,blocked,status)
    if state.failed or not patrol or patrol:IsDispatchMenuOpen() or delta<=0 or delta>0.5 then return end
    local ok,err=pcall(function()
        local system=bridge()
        if not actor or not actor:IsAttached() then return end
        local mode=system:Mode(actor)
        if blocked or mode==0 then
            M.release(state,actor);state.settle=2;return
        end
        state.settle=math.max(0,(state.settle or 0)-delta)
        local wanted=system:WantsReady()
        if state.wanted~=wanted then
            stopOurs(state,actor)
            state.wanted=wanted;state.stable=0;state.retry=0;state.attempts=0;state.warned=false
        end
        state.stable=(state.stable or 0)+delta
        state.retry=math.max(0,(state.retry or 0)-delta)
        if not wanted and mode~=2 then
            -- Alerted officers may draw with V, but never holster for V.
            stopOurs(state,actor);state.settle=2;return
        end
        if system:IsReady(actor)==wanted then state.pending=false;state.result="held slots match";return end
        if not wanted and (state.stable<1 or state.settle>0) then return end
        if state.pending then
            state.age=state.age+delta
            if state.age<1 then return end
            stopOurs(state,actor)
            state.fallbacks=(state.fallbacks or 0)+1
            state.lastFallback=system:Apply(actor,wanted)
            state.result="native fallback="..tostring(state.lastFallback)
            -- Apply rechecks ownership, actual V state, combat and mounting.
            if system:IsReady(actor)==wanted then state.result="native fallback: held slots match";return end
        end
        if state.retry>0 then return end
        if state.attempts>=3 then
            if not state.warned then
                state.warned=true
                if status then status("Officer readiness not confirmed | "..M.diagnostics(state,actor)) end
            end
            return
        end
        stopOurs(state,actor)
        local command=AISwitchToPrimaryWeaponCommand.new()
        command.unEquip=not wanted
        actor:GetAIControllerComponent():SendCommand(command)
        state.command=command;state.retry=3;state.attempts=state.attempts+1
        state.pending=true;state.age=0;state.result="request sent; awaiting actual held weapon"
    end)
    if not ok then
        stopOurs(state,actor)
        state.failed=true;state.error=tostring(err)
        if status then status("Officer readiness unavailable for this actor: "..state.error) end
    end
end
return M
