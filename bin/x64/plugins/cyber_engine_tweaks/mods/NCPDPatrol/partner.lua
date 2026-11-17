-- NCPD Patrol v0.7a: one owned partner with native defeat/revive and boarding.
-- Uses the same officer record and follower setup tested in v0.3a.
-- Codeware DynamicEntitySystem is used only to create/delete an entity owned by this mod.
-- Native game AIFollowerRole handles following; all riskier operations are guarded.
-- No nearby NPC is ever modified.

local M = {}
local Boarding = require("boarding")
local OfficerAI = require("officer_ai")
local Probe = require("revive_probe")
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
local supportState = 0
local supportFailure = false
local rolePending, roleElapsed, roleAttempts, roleFailed = false, 0, 0, false
local voiceTime, voiceRevision, voiceLines = 0, 0, 0

local function support()
    return Game.GetScriptableSystemsContainer():Get("NCPDPatrolSupportSystem")
end

function M.aidState()
    if roleFailed then return "Revived; follower AI recovery failed (see diagnostics)" end
    if rolePending then return "Revived; waiting for follower target" end
    local labels = { [0]="No registered partner", [1]="Active; death protection enabled",
        [2]="Down; approach to revive", [3]="Reviving; stay within 2.5 m",
        [4]="Waiting for native recovery" }
    return supportFailure and "Revive control failed; see CET log" or (labels[supportState] or "Unknown")
end

function M.diagnostics()
    local ok, info = pcall(function() return support():GetPartnerDiagnostics() end)
    return (ok and tostring(info) or ("Partner AI diagnostics unavailable: " .. tostring(info))) .. " | probe=" .. Probe.state()
end

function M.healthDiagnostics()
    local ok, info = pcall(function() return support():GetPartnerHealthDiagnostics() end)
    return ok and tostring(info) or ("Health diagnostics unavailable: " .. tostring(info))
end

local function observeVoice(delta)
    if delta <= 0 or delta > 0.5 or voiceLines >= 30 then return end
    voiceTime = voiceTime + delta
    if voiceTime < 2 then return end
    voiceTime = 0
    -- Optional diagnostics must never interrupt following, combat or boarding.
    pcall(function()
        local system = support()
        local revision = system:GetPartnerVoiceRevision()
        if revision ~= voiceRevision then
            voiceRevision, voiceLines = revision, voiceLines + 1
            print("[NCPD Patrol] Partner VO request | " .. tostring(system:GetPartnerVoiceDiagnostics()))
        end
    end)
end

local function restoreRole()
    local role = AIFollowerRole.new()
    role.followerRef = Game.CreateEntityReference('#player', {})
    if not support():RestorePartnerFollowerRole(role) then error("Native follower role recovery refused") end
    OfficerAI.friendly(officer)
    roleAttempts = roleAttempts + 1
end

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
    OfficerAI.follower(target)
end

local function sendFollow()
    if not officer or not loaded() or not officer:IsAttached() or Boarding.busy() or supportState ~= 1 then return end
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
    supportState, supportFailure = 0, false
    rolePending, roleElapsed, roleAttempts, roleFailed = false, 0, 0, false
    timeout = 0
    pollTime = 0
    followTime = 0
    stateLabel = "Spawn requested; waiting for actor"
    status("NCPD partner called; waiting for arrival.")
end

function M.dismiss(status)
    Probe.reset()
    voiceTime, voiceRevision, voiceLines = 0, 0, 0
    rolePending, roleElapsed, roleAttempts, roleFailed = false, 0, 0, false
    pcall(function()
        local system = support()
        if system then system:UnregisterPartner() end
    end)
    supportState, supportFailure = 0, false
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
    Probe.reset()
    voiceTime, voiceRevision, voiceLines = 0, 0, 0
    rolePending, roleElapsed, roleAttempts, roleFailed = false, 0, 0, false
    spawnId, officer, spawnWaiting, followCommand = nil, nil, false, nil
    timeout, pollTime, followTime = 0, 0, 0
    stateLabel = "Not spawned"
    Boarding.reset()
    vehicleFailed = false
    supportState, supportFailure = 0, false
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
            local system = support()
            if not system or system:Version() ~= 16 or not system:RegisterPartner(officer) then
                error("Native revive protection could not register our partner")
            end
            supportState = system:GetPartnerState()
            nativeFollower(officer)
            sendFollow()
        end)
        if not attached then
            M.dismiss(nil)
            stateLabel = "Partner setup failed; actor dismissed"
            status("Partner setup failed: " .. tostring(err))
            return
        end
        stateLabel = attached and "Spawned; follower commands sent" or "Spawned; follower setup FAILED"
        status(attached and "NCPD partner spawned; follow role and command sent." or ("Spawned but follower role failed: " .. tostring(err)))
        return
    end
    if officer then
        observeVoice(delta)
        local aidOK, ready = pcall(function()
            local system = support()
            local patrol = Game.GetScriptableSystemsContainer():Get("NCPDPatrolSystem")
            if not system or not patrol then error("Native support system unavailable") end
            if not patrol:IsDispatchMenuOpen() then system:TickPartner(delta) end
            local previous = supportState
            supportState = system:GetPartnerState()
            if supportState ~= 1 then
                Probe.reset()
                rolePending, roleElapsed, roleAttempts, roleFailed = false, 0, 0, false
                if previous == 1 then Boarding.cancel(officer); stopFollow() end
                stateLabel = M.aidState()
                return false
            end
            if previous ~= 1 then
                Boarding.reset()
                voiceTime, voiceRevision, voiceLines = 0, 0, 0
                rolePending, roleElapsed, roleAttempts, roleFailed = true, 0, 0, false
                restoreRole()
                stateLabel = "Revived; restoring follower AI"
            end
            if roleFailed then return false end
            if rolePending then
                if not patrol:IsDispatchMenuOpen() and delta > 0 and delta <= 0.5 then roleElapsed = roleElapsed + delta end
                if roleElapsed < 0.5 then return false end
                if system:IsPartnerFollowerReady() then
                    rolePending = false
                    sendFollow()
                    system:ConfirmPartnerFollowerRestored()
                    Probe.begin(status)
                    followTime = 0
                    stateLabel = "Revived; follower target restored"
                    status("Partner AI restored | " .. M.diagnostics())
                    print("[NCPD Patrol] Partner health after revive | " .. M.healthDiagnostics())
                else
                    if roleElapsed >= 1.5 and roleAttempts < 2 then restoreRole() end
                    if roleElapsed >= 4 then
                        rolePending, roleFailed = false, true
                        stateLabel = "Revived; follower recovery FAILED"
                        status("Partner AI recovery failed | " .. M.diagnostics())
                        patrol:NotifyDispatch("NCPD: Partner revived, but could not resume following.", 6)
                    end
                    return false
                end
            end
            return true
        end)
        if not aidOK then
            if not supportFailure then status("Partner revive control failed: " .. tostring(ready)) end
            supportFailure = true
            return
        end
        if not ready then return end
        supportFailure = false
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
        local paused = true
        pcall(function() paused = Game.GetScriptableSystemsContainer():Get("NCPDPatrolSystem"):IsDispatchMenuOpen() end)
        Probe.update(delta, officer, followCommand, status, function() return support():GetPartnerDiagnostics() end, paused)
        followTime = followTime + delta
        -- Keep the sampled command stable for this one bounded observation.
        if followTime >= 5 and not Probe.isSampling() then
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
