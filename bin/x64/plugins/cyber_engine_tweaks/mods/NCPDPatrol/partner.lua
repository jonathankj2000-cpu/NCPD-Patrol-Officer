-- NCPD Patrol v0.4a: One NCPD partner with explicit vehicle boarding.
-- Uses the same officer record and follower setup tested in v0.3a.
-- Codeware DynamicEntitySystem is used only to create/delete an entity owned by this mod.
-- Native game AIFollowerRole handles following; all riskier operations are guarded.
-- Every state change initiated by player input; no nearby NPC is ever modified.

local M = {}
local Boarding = require("boarding")
local PARTNER_RECORD = "Character.cvi_ncpd_police_ranged2_copperhead_ma"
local spawnId = nil
local officer = nil
local spawnWaiting = false
local timeout = 0
local pollTime = 0
local followTime = 0
local stateLabel = "Not spawned"
local followCommand = nil
local vehicleFailed = false

local function loaded()
    return Game and Game.GetPlayer and Game.GetPlayer() ~= nil
end

local function getSystem()
    if not Game or not Game.GetDynamicEntitySystem then return nil end
    return Game.GetDynamicEntitySystem()
end

function M.state() return stateLabel end
function M.vehicleState() return vehicleFailed and "Vehicle control failed; see diagnostics" or Boarding.state() end

local function stopFollow()
    if followCommand and officer then
        local ai = officer:GetAIControllerComponent()
        if ai then ai:StopExecutingCommand(followCommand, false) end
    end
    followCommand = nil
end

local function nativeFollower(target)
    local ai = target:GetAIControllerComponent()
    if not ai then error("Spawned NPC has no AI controller") end
    if not target:IsAttached() then error("Spawned NPC not attached yet") end
    local existing = ai:GetAIRole()
    if existing then existing:OnRoleCleared(target) end
    local role = AIFollowerRole.new()
    role.followerRef = Game.CreateEntityReference('#player', {})
    ai:SetAIRole(role)
    ai:OnAttach()
    local player = Game.GetPlayer()
    local agent = target:GetAttitudeAgent()
    local playerAgent = player:GetAttitudeAgent()
    if agent and playerAgent then
        agent:SetAttitudeGroup(playerAgent:GetAttitudeGroup())
        agent:SetAttitudeTowards(playerAgent, EAIAttitude.AIA_Friendly)
    end
    target.isPlayerCompanionCachedTimeStamp = 0
end

local function sendFollow()
    if not officer or not loaded() or not officer:IsAttached() or Boarding.busy() then return end
    local ai = officer:GetAIControllerComponent()
    if not ai then return end
    local cmd = AIFollowTargetCommand.new()
    cmd.target = Game.GetPlayer()
    cmd.lookAtTarget = Game.GetPlayer()
    cmd.desiredDistance = 1.8
    cmd.tolerance = 0.7
    cmd.movementType = moveMovementType.Run
    cmd.matchSpeed = true
    cmd.teleport = false
    cmd.stopWhenDestinationReached = false
    cmd.ignoreInCombat = false
    cmd.removeAfterCombat = false
    cmd.alwaysUseStealth = false
    ai:SendCommand(cmd)
    followCommand = cmd
end

function M.spawn(onDuty, status)
    if not onDuty then status("Go On Duty before spawning a partner."); return end
    if not loaded() then status("Load a save first."); return end
    if spawnId or spawnWaiting then status("A partner is already active or pending. Dismiss it first."); return end
    local ok, result = pcall(function()
        local system = getSystem()
        if not system then error("Codeware DynamicEntitySystem not found. Check Codeware installation.") end
        if not system:IsReady() then error("Codeware entity system not ready") end
        local recordID = TweakDBID.new(PARTNER_RECORD)
        if not TweakDB:GetRecord(recordID) then error("NCPD partner character record missing: " .. PARTNER_RECORD) end
        local player = Game.GetPlayer()
        local pos = player:GetWorldPosition()
        local spec = DynamicEntitySpec.new()
        spec.recordID = recordID
        spec.position = Vector4.new(pos.x + 1.8, pos.y + 1.8, pos.z, pos.w)
        spec.orientation = player:GetWorldOrientation()
        spec.persistState = false
        spec.persistSpawn = false
        spec.alwaysSpawned = false
        spec.spawnInView = true
        spec.active = true
        return system:CreateEntity(spec)
    end)
    if not ok or result == nil then
        stateLabel = "Spawn call failed"
        status("Partner spawn failed: " .. tostring(result))
        return
    end
    spawnId = result
    spawnWaiting = true
    Boarding.reset()
    followCommand = nil
    vehicleFailed = false
    timeout = 0
    pollTime = 0
    followTime = 0
    stateLabel = "Spawn requested; waiting for actor"
    status("NCPD partner called; waiting for arrival.")
end

function M.dismiss(status)
    if not spawnId then
        officer = nil
        spawnWaiting = false
        Boarding.reset()
        followCommand = nil
        stateLabel = "Not spawned"
        if status then status("No spawned partner to dismiss.") end
        return
    end
    local id = spawnId
    pcall(function() Boarding.cancel(officer); stopFollow() end)
    -- Clear local references first; on failure do not retry indefinitely.
    spawnId = nil
    officer = nil
    spawnWaiting = false
    Boarding.reset()
    followCommand = nil
    vehicleFailed = false
    local ok, err = pcall(function()
        local system = getSystem()
        if not system then error("DynamicEntitySystem unavailable") end
        -- Only delete entity with the ID returned by our own CreateEntity call.
        return system:DeleteEntity(id)
    end)
    stateLabel = (ok and "Dismissed" or "Cleanup failed; reload test save")
    if status then
        status(ok and "Dismissed our spawned partner." or ("Partner cleanup failed: " .. tostring(err) .. ". Reload the test save."))
    end
end

-- A loaded save has already removed non-persistent actors from the old world.
-- Forget stale IDs without issuing a deletion into the newly loaded world.
function M.reset()
    spawnId, officer, spawnWaiting, followCommand = nil, nil, false, nil
    timeout, pollTime, followTime = 0, 0, 0
    stateLabel = "Not spawned"
    Boarding.reset()
    vehicleFailed = false
end

function M.update(delta, onDuty, status)
    if not onDuty or not spawnId or not loaded() then return end
    if spawnWaiting then
        timeout = timeout + delta
        pollTime = pollTime + delta
        if timeout > 10 then
            stateLabel = "Spawn timeout; dismiss and retry"
            spawnWaiting = false
            status("No spawned officer found within 10 seconds. Use Dismiss, then review CET logs.")
            return
        end
        if pollTime < 0.5 then return end
        pollTime = 0
        local ok, obj = pcall(function()
            local s = getSystem()
            return s and s:GetEntity(spawnId)
        end)
        if not ok or not obj then return end
        officer = obj
        spawnWaiting = false
        local attached, err = pcall(function()
            nativeFollower(officer)
            sendFollow()
        end)
        stateLabel = attached and "Spawned; follower commands sent" or "Spawned; follower setup FAILED"
        status(attached and "NCPD partner spawned; follow role and command sent." or ("Spawned but follower role failed: " .. tostring(err)))
        return
    end
    if officer then
        local wasBusy = Boarding.busy()
        if not vehicleFailed then
            local boarded, err = pcall(Boarding.update, delta, officer, status, stopFollow)
            if not boarded then
                vehicleFailed = true
                status("Partner vehicle control failed: " .. tostring(err))
                -- Keep following and dismissal available if vehicle API access fails.
                pcall(function() Boarding.cancel(officer) end)
                Boarding.reset()
            end
        end
        if wasBusy and not Boarding.busy() then followTime = 5 end
        followTime = followTime + delta
        if followTime >= 5 then
            followTime = 0
            local ok, err = pcall(sendFollow)
            if not ok then
                stateLabel = "Follow update failed; dismiss and retry"
                status("Follow command failed: " .. tostring(err))
                officer = nil -- Stop sending commands; DeleteEntity remains available.
            end
        end
    end
end

return M
