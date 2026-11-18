-- Per-officer, transient weapon readiness. Call only for our own partner/crew.
-- Uses native equipment commands, never movement commands or combat-state writes.
local M = {}
local function weaponDrawn(actor)
    local weapon=ScriptedPuppet.GetActiveWeapon(actor)
    return weapon~=nil and not WeaponObject.IsFists(weapon:GetItemID())
end
local function stopOurs(state,actor,holsterOnly)
    if state.command and (not holsterOnly or state.command.unEquip) then
        pcall(function() actor:GetAIControllerComponent():StopExecutingCommand(state.command,false) end)
        state.command=nil
    end
end
function M.release(state,actor)
    if actor then stopOurs(state,actor,false) end
    state.command=nil;state.wanted=nil;state.stable=0;state.retry=0;state.attempts=0
end
function M.update(state,delta,actor,patrol,blocked,status)
    if state.failed then return end
    if not patrol or patrol:IsDispatchMenuOpen() or delta<=0 or delta>0.5 then return end
    local ok,err=pcall(function()
        local player=Game.GetPlayer()
        if not player or not actor or not actor:IsAttached() then return end
        if blocked or actor:IsDead() or actor:IsDeadNoStatPool()
            or ScriptedPuppet.IsDefeated(actor) or ScriptedPuppet.IsUnconscious(actor)
            or Game.GetMountedVehicle(actor) or Game.GetMountedVehicle(player) then
            M.release(state,actor);return
        end
        local high=actor:GetHighLevelStateFromBlackboard()
        if high~=gamedataNPCHighLevelState.Relaxed or player:IsInCombat() then
            -- An alerted/combat officer keeps native weapon decisions even if
            -- V holsters. Release OUR equipment request so native combat can
            -- also switch weapons freely; never stop a native combat order.
            stopOurs(state,actor,false)
            state.wanted=nil;state.stable=0;state.retry=0;state.attempts=0
            state.settle=2;return
        end
        state.settle=math.max(0,(state.settle or 0)-delta)
        local wanted=weaponDrawn(player)
        if state.wanted~=wanted then
            stopOurs(state,actor,false)
            state.wanted=wanted;state.stable=0;state.retry=0;state.attempts=0
        end
        state.stable=(state.stable or 0)+delta
        state.retry=math.max(0,(state.retry or 0)-delta)
        if weaponDrawn(actor)==wanted then return end
        -- Drawing is prompt; holstering waits for a stable, calm state.
        if not wanted and (state.stable<1 or state.settle>0) then return end
        if state.retry>0 or state.attempts>=3 then return end
        stopOurs(state,actor,false)
        local command=AISwitchToPrimaryWeaponCommand.new()
        command.unEquip=not wanted
        actor:GetAIControllerComponent():SendCommand(command)
        state.command=command;state.retry=3;state.attempts=state.attempts+1
    end)
    if not ok then
        state.failed=true;state.error=tostring(err)
        if status then status("Officer readiness unavailable for this actor: "..state.error) end
    end
end
return M
