-- Shared setup for this mod's own officers; never call it on ambient NPCs.
local M = {}

function M.friendly(target)
    local player = Game.GetPlayer()
    local agent, playerAgent = target:GetAttitudeAgent(), player:GetAttitudeAgent()
    if agent and playerAgent then
        agent:SetAttitudeGroup(playerAgent:GetAttitudeGroup())
        agent:SetAttitudeTowards(playerAgent, EAIAttitude.AIA_Friendly)
    end
end

function M.follower(target)
    local ai = target:GetAIControllerComponent()
    if not ai or not target:IsAttached() then error("Officer AI is not attached") end
    local existing = ai:GetAIRole()
    if existing then existing:OnRoleCleared(target) end
    local role = AIFollowerRole.new()
    role.followerRef = Game.CreateEntityReference('#player', {})
    ai:SetAIRole(role)
    ai:OnAttach()
    M.friendly(target)
    target.isPlayerCompanionCachedTimeStamp = 0
end

function M.stopFollowing(target)
    local ai = target:GetAIControllerComponent()
    if not ai or not target:IsAttached() then error("Officer AI is not attached") end
    local existing = ai:GetAIRole()
    if existing then existing:OnRoleCleared(target) end
    ai:SetAIRole(AINoRole.new())
    ai:OnAttach()
    target.isPlayerCompanionCachedTimeStamp = 0
end

function M.moveToScene(target, position)
    local command = AIMoveToCommand.new()
    local point = WorldPosition.new()
    WorldPosition.SetVector4(point, position)
    local spec = AIPositionSpec.new()
    AIPositionSpec.SetWorldPosition(spec, point)
    command.movementTarget = spec
    command.movementType = moveMovementType.Run
    command.ignoreNavigation = false
    command.useStart, command.useStop = true, true
    command.desiredDistanceFromTarget = 2.5
    command.finishWhenDestinationReached = false
    command.ignoreInCombat, command.removeAfterCombat = false, false
    command.alwaysUseStealth = false
    target:GetAIControllerComponent():SendCommand(command)
    return command
end

function M.follow(target, desiredDistance)
    local player = Game.GetPlayer()
    local command = AIFollowTargetCommand.new()
    command.target, command.lookAtTarget = player, player
    command.desiredDistance, command.tolerance = desiredDistance, 1.0
    command.movementType, command.matchSpeed = moveMovementType.Run, true
    command.teleport, command.stopWhenDestinationReached = false, false
    command.ignoreInCombat, command.removeAfterCombat = false, false
    command.alwaysUseStealth = false
    target:GetAIControllerComponent():SendCommand(command)
    return command
end

function M.hold(target)
    local command = AIHoldPositionCommand.new()
    command.duration = -1
    command.ignoreInCombat, command.removeAfterCombat = false, false
    command.alwaysUseStealth = false
    target:GetAIControllerComponent():SendCommand(command)
    return command
end

return M
