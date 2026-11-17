-- One private, non-persistent workspot anchor per arrested suspect. Ambient
-- NPCs are never spawned/deleted, healed, resurrected or given follower roles.
local M = {}
local CLIP = "lie_ground_0__2h_back_handcuffs_a__01"
local units, observedToken = {}, nil
local poll, lastRevision = 0, -1
local label = "Ready on duty; EUR$250 per arrest"
local unavailableReported = false
local lastLook = nil

local function native()
    return Game.GetScriptableSystemsContainer():Get("NCPDPatrolArrestSystem")
end

local function entities() return Game.GetDynamicEntitySystem() end
local function workspots() return Game.GetWorkspotSystem() end
local function same(a, b) return a and b and a:GetEntityID().hash == b:GetEntityID().hash end
local function attached(npc) return npc and npc:IsAttached() end
local function distance(a, b)
    local p, q = a:GetWorldPosition(), b:GetWorldPosition()
    local x, y, z = p.x-q.x, p.y-q.y, p.z-q.z
    return math.sqrt(x*x+y*y+z*z)
end

local function ownsWorkspot(unit)
    return unit.started and unit.id and attached(unit.npc)
        and same(workspots():GetDeviceUser(unit.id), unit.npc)
end

local function cleanup(unit)
    -- Stop only the playback still associated with our private helper. Another
    -- mod taking the actor into a different workspot must not be interrupted.
    if ownsWorkspot(unit) then workspots():StopInDevice(unit.npc) end
    unit.started = false
    if not unit.id then return true end
    local system = entities()
    if not system or not system:IsReady() then return false end
    if not system:IsManaged(unit.id) then unit.id = nil; return true end
    if system:DeleteEntity(unit.id) then unit.id = nil; return true end
    return false
end

local function fail(system, unit, reason)
    if unit.failed then return end
    unit.failed, unit.retiring = true, true
    if not unit.paid then system:FailPose(unit.token, reason) end
    print("[NCPD Patrol] Arrest | " .. reason)
end

local function create(system, npc, token)
    local dynamic = entities()
    if not dynamic or not dynamic:IsReady() then error("Codeware entity system unavailable") end
    if workspots():IsActorInWorkspot(npc) then error("Suspect is already in another workspot") end
    local spec = DynamicEntitySpec.new()
    spec.templatePath = system:GetHelperTemplate()
    spec.position, spec.orientation = npc:GetWorldPosition(), npc:GetWorldOrientation()
    spec.persistState, spec.persistSpawn = false, false
    spec.alwaysSpawned, spec.spawnInView, spec.active = false, true, true
    local id = dynamic:CreateEntity(spec)
    if not id then error("Arrest helper creation refused; check NCPDPatrol_Arrest.archive") end
    return {id=id, npc=npc, token=token, elapsed=0, stable=0, started=false, paid=false}
end

local function updateUnit(system, unit, delta, onDuty, paused)
    if not onDuty then unit.retiring = true end
    if unit.retiring then return cleanup(unit) end
    local player = Game.GetPlayer()
    if not attached(unit.npc) or unit.npc:IsDead() or not player then
        fail(system, unit, "Suspect unavailable; arrest animation released")
        return cleanup(unit)
    end
    if unit.paid then
        if distance(player, unit.npc) > 60 then unit.retiring = true; return cleanup(unit) end
        return false
    end
    if system:GetStage() ~= 2 or system:GetToken() ~= unit.token or not same(system:GetTarget(), unit.npc) then
        unit.retiring = true
        return cleanup(unit)
    end
    if paused then return false end
    unit.elapsed = unit.elapsed + delta
    if unit.elapsed > 8 then
        fail(system, unit, "Lying arrest animation not confirmed; no arrest payment")
        return cleanup(unit)
    end
    local helper = entities():GetEntity(unit.id)
    if not helper or not helper:IsAttached() then return false end
    if not unit.started then
        -- The helper references an existing vanilla ground/handcuff workspot.
        -- This starts no paired V animation and changes no NPC life/AI state.
        workspots():PlayInDeviceSimple(helper, unit.npc, false, CName.new("NCPDPatrolArrest"),
            CName.new("None"), CName.new("None"), 0,
            WorkspotSlidingBehaviour.DontPlayAtResourcePosition, nil)
        unit.started = true
        print("[NCPD Patrol] Arrest | Lying workspot requested; awaiting actual clip")
        return false
    end
    local instance = workspots():GetWorkspotInstance(unit.npc:GetEntityID())
    local clip = instance and system:AnimationName(instance.animName) or "none"
    if clip ~= unit.lastClip then
        unit.lastClip = clip
        print("[NCPD Patrol] Arrest pose | clip=" .. tostring(clip))
    end
    local matches = clip:sub(1, #CLIP) == CLIP and not clip:find("__to__", 1, true)
    if matches and workspots():IsActorInWorkspot(unit.npc) and ownsWorkspot(unit) then
        unit.stable = unit.stable + delta
        if unit.stable >= 0.5 then
            if system:ConfirmArrestPose(unit.npc, unit.token) then
                unit.paid = true
                print("[NCPD Patrol] Arrest | Registered; separate EUR$250 arrest payment")
            else
                unit.retiring = true
                return cleanup(unit)
            end
        end
    else
        unit.stable = 0
    end
    return false
end

function M.state() return label end

-- A load has already discarded the non-persistent helpers. Never delete old
-- IDs or stop old actor handles in a newly attached world.
function M.reset()
    units, observedToken, poll, lastRevision = {}, nil, 0, -1
    label, unavailableReported = "Ready on duty; EUR$250 per arrest", false
    lastLook = nil
end

function M.finish()
    pcall(function()
        local system = native()
        if system and system:Version() == 1 and system:GetStage() ~= 0 then system:CancelArrest("Arrest cancelled: shift ended") end
    end)
    for index = #units, 1, -1 do
        local unit = units[index]
        unit.retiring = true
        local ok, removed = pcall(cleanup, unit)
        if ok and removed then table.remove(units, index) end
    end
    pcall(function() if attached(lastLook) then lastLook:NCPDPatrolRefreshArrestInteraction() end end)
    lastLook = nil
end

function M.update(delta, onDuty, paused)
    if delta <= 0 or delta > 0.5 then return end
    local ok, err = pcall(function()
        local system = native()
        if not system or system:Version() ~= 1 then error("Install all v0.7a arrest scripts and restart the game") end
        system:Tick(delta, paused)
        -- Helpers whose cleanup failed retain their IDs for a later retry,
        -- including while off duty. No deletion is ever aimed at the suspect.
        for index = #units, 1, -1 do
            local unit = units[index]
            local ran, done = pcall(updateUnit, system, unit, delta, onDuty, paused)
            if not ran then
                fail(system, unit, "Arrest control failed: " .. tostring(done))
                local cleaned, removed = pcall(cleanup, unit)
                if cleaned and removed then table.remove(units, index) end
            elseif done then
                table.remove(units, index)
            end
        end
        if onDuty and not paused and system:GetStage() == 2 then
            local token = system:GetToken()
            if token ~= observedToken then
                observedToken = token
                local made, unit = pcall(create, system, system:GetTarget(), token)
                if made then
                    units[#units+1] = unit
                else
                    system:FailPose(token, tostring(unit))
                    print("[NCPD Patrol] Arrest | " .. tostring(unit))
                end
            end
        end
        poll = poll + delta
        if poll >= 0.25 then
            poll = 0
            if onDuty and not paused then
                -- Refresh a newly looked-at eligible body, including an empty
                -- inventory. Optional targeting errors cannot stop arrests.
                pcall(function()
                    local target = Game.GetTargetingSystem():GetLookAtObject(Game.GetPlayer(), false, false)
                    if target and system:CanStartArrest(target) and distance(Game.GetPlayer(), target) <= 3 then
                        if not same(lastLook, target) then target:NCPDPatrolRefreshArrestInteraction() end
                        lastLook = target
                    else
                        lastLook = nil
                    end
                end)
            end
            local revision = system:GetRevision()
            if revision ~= lastRevision then
                lastRevision = revision
                label = tostring(system:GetStatus())
                print("[NCPD Patrol] Arrest | " .. label .. " | arrests paid in this save=" .. tostring(system:GetPaidArrests()))
            end
        end
    end)
    if not ok and not unavailableReported then
        unavailableReported = true
        label = "Arrest control unavailable; see CET log"
        print("[NCPD Patrol] Arrest | " .. tostring(err))
    end
end

return M
