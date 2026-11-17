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

local function read(object, field)
    local ok, value = pcall(function() return object[field] end)
    if ok then return value end
    return nil
end

local function isArrestClip(name)
    return name:sub(1, 11) == "lie_ground_" and not name:find("__to__", 1, true)
        and not name:find("uncuff", 1, true)
        and (name:find("handcuff", 1, true) or name:find("cuffed", 1, true)) ~= nil
end

local function inspectTree(system, tree)
    local stack, seen, names, nodes = {tree.rootEntry}, {}, {}, 0
    while #stack > 0 and nodes < 256 do
        local entry = table.remove(stack)
        if entry and not seen[entry] then
            seen[entry], nodes = true, nodes + 1
            for _, field in ipairs({"animName", "idleAnim"}) do
                local name = read(entry, field)
                if name then
                    local ok, text = pcall(function() return system:AnimationName(name) end)
                    if ok and text ~= "" and text ~= "None" then names[text] = true end
                end
            end
            local list = read(entry, "list")
            if list then for _, child in ipairs(list) do stack[#stack+1] = child end end
        end
    end
    local candidates, sample = {}, {}
    for name in pairs(names) do
        if #sample < 6 then sample[#sample+1] = name end
        if isArrestClip(name) then candidates[#candidates+1] = name end
    end
    table.sort(candidates)
    local selected = names[CLIP] and CLIP or candidates[1]
    return selected, nodes, table.concat(sample, ", "), next(names) ~= nil and #stack == 0
end

local function prepare(system, unit, helper)
    if not unit.component then
        unit.component = helper:FindComponentByType(CName.new("workWorkspotResourceComponent"))
        if not unit.component then error("Arrest helper has no workspot component; reinstall the complete v0.7e archive") end
        local name = system:AnimationName(unit.component.name)
        if name ~= "NCPDPatrolArrestPC" then error("Outdated arrest helper; replace NCPDPatrol_Arrest.archive and restart") end
        print("[NCPD Patrol] Arrest setup | helper attached=true | component=" .. name)
    end
    -- workspotResource is a ResourceAsyncReference. ResourceHelper's reference
    -- methods accept only synchronous ResourceReference properties, so use a
    -- depot token and retain it for the helper's lifetime instead.
    if not unit.bankToken then
        unit.bankToken = Game.GetResourceDepot():LoadResource(system:GetWorkspotResource())
        if not unit.bankToken then error("Arrest resource load returned no token") end
        print("[NCPD Patrol] Arrest setup | async bank load requested")
    end
    local loaded, finished, failed = unit.bankToken:IsLoaded(), unit.bankToken:IsFinished(), unit.bankToken:IsFailed()
    local state = "loaded=" .. tostring(loaded) .. " | finished=" .. tostring(finished) .. " | failed=" .. tostring(failed)
    if state ~= unit.lastLoad then
        unit.lastLoad = state
        print("[NCPD Patrol] Arrest resource token | " .. state)
    end
    if failed then error("Arrest workspot asynchronous load failed") end
    if not loaded then
        if finished then error("Arrest workspot load finished without a loaded resource") end
        return false
    end
    local resource = unit.bankToken:GetResource()
    local tree = resource and read(resource, "workspotTree")
    if not tree or not read(tree, "rootEntry") then
        if unit.elapsed > 4 then error("Arrest resource loaded; workspot tree still not readable/ready") end
        return false
    end
    if not unit.prepared then
        local selected, nodes, sample = inspectTree(system, tree)
        print("[NCPD Patrol] Arrest bank | loaded=true | nodes=" .. nodes .. " | selected=" .. tostring(selected or "unavailable"))
        print("[NCPD Patrol] Arrest bank names | " .. sample)
        if not selected then error("Loaded workspot has no readable lying handcuff candidate") end
        unit.clip, unit.prepared = selected, true
        unit.resource = resource
    end
    return true
end

local function jump(unit)
    workspots():SendJumpToAnimEnt(unit.npc, CName.new(unit.clip), true)
    workspots():SendPlaySignal(unit.npc)
end

local function activationSource(unit)
    return unit.proof:HasResult() and "native play result" or "native activation fallback"
end

local function reportActivation(unit)
    local proof = unit.proof
    local stable = math.floor(math.min(proof:StableTime(), proof:RequiredTime()) * 4) / 4
    local text = "source=" .. activationSource(unit) .. " | result="
        .. (proof:HasResult() and tostring(proof:ResultSucceeded()) or "not received")
        .. " | in workspot=" .. tostring(proof:IsPresent()) .. " | active=" .. tostring(proof:NativeActive())
        .. " | entering=" .. tostring(proof:Entering()) .. " | exiting=" .. tostring(proof:Exiting())
        .. " | stable=" .. string.format("%.2f", stable) .. "/" .. string.format("%.2f", proof:RequiredTime()) .. " s"
    if text ~= unit.lastActivation then
        unit.lastActivation = text
        print("[NCPD Patrol] Arrest activation | " .. text)
    end
end

local function cleanup(unit)
    if unit.proof then unit.proof:Disarm() end
    unit.started = false
    -- Release only our managed helper. No unverified StopInDevice command is
    -- sent to an ambient actor whose current device cannot be inspected.
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
    local depot = Game.GetResourceDepot()
    local template = depot:ResourceExists(system:GetHelperTemplate())
    local bank = depot:ResourceExists(system:GetWorkspotResource())
    print("[NCPD Patrol] Arrest setup | archive=" .. tostring(depot:ArchiveExists("NCPDPatrol_Arrest.archive"))
        .. " | template=" .. tostring(template) .. " | bank=" .. tostring(bank))
    if not template or not bank then error("Arrest animation resources unavailable; no playback requested") end
    local spec = DynamicEntitySpec.new()
    spec.templatePath = system:GetHelperTemplate()
    spec.position, spec.orientation = npc:GetWorldPosition(), npc:GetWorldOrientation()
    spec.persistState, spec.persistSpawn = false, false
    spec.alwaysSpawned, spec.spawnInView, spec.active = false, true, true
    local id = dynamic:CreateEntity(spec)
    if not id then error("Arrest helper creation refused; check NCPDPatrol_Arrest.archive") end
    return {id=id, npc=npc, token=token, elapsed=0, started=false, paid=false}
end

local function keepLying(unit)
    if not unit.proof:IsActive() then return end
    if (unit.playTime or 0) < (unit.nextHold or 1) then return end
    unit.nextHold = unit.playTime + 1
    -- No clip telemetry is available here. Re-select the known lying clip at
    -- most once per second, without advancing the bank with another play signal.
    workspots():SendJumpToAnimEnt(unit.npc, CName.new(unit.clip), true)
    unit.holdRequests = (unit.holdRequests or 0) + 1
    if unit.holdRequests == 1 or unit.holdRequests % 15 == 0 then
        print("[NCPD Patrol] Arrest hold | lying clip reselected | requests=" .. unit.holdRequests .. " | interval=1 s | observed clip=unavailable")
    end
end

local function updateUnit(system, unit, delta, onDuty, paused)
    if not onDuty then unit.retiring = true end
    if unit.retiring then return cleanup(unit) end
    local player = Game.GetPlayer()
    if not attached(unit.npc) or unit.npc:IsDead() or not player then
        fail(system, unit, "Suspect unavailable; arrest helper released")
        return cleanup(unit)
    end
    if unit.started then
        if not paused then unit.playTime = (unit.playTime or 0) + delta end
        unit.proof:Tick(delta, paused)
    end
    if unit.paid then
        if distance(player, unit.npc) > 60 or unit.proof:IsFinished() then
            unit.retiring = true
            return cleanup(unit)
        end
        if not paused then keepLying(unit) end
        return false
    end
    if system:GetStage() ~= 2 or system:GetToken() ~= unit.token or not same(system:GetTarget(), unit.npc) then
        unit.retiring = true
        return cleanup(unit)
    end
    if paused then return false end
    unit.elapsed = unit.elapsed + delta
    if unit.elapsed > 8 then
        fail(system, unit, "Native arrest activation not confirmed; no arrest payment")
        return cleanup(unit)
    end
    local helper = entities():GetEntity(unit.id)
    if not helper or not helper:IsAttached() then return false end
    if not unit.started then
        if not prepare(system, unit, helper) then return false end
        unit.proof = NCPDPatrolArrestPlayback.new()
        if not system:ArmPlayback(unit.npc, helper, unit.token, unit.proof) then
            error("Arrest playback could not arm a clean native start")
        end
        unit.started = true
        workspots():PlayInDeviceSimple(helper, unit.npc, false, CName.new("NCPDPatrolArrestPC"),
            CName.new("None"), CName.new("None"), 0,
            WorkspotSlidingBehaviour.DontPlayAtResourcePosition, helper)
        jump(unit)
        print("[NCPD Patrol] Arrest request | requested clip=" .. unit.clip .. " | observed clip=unavailable | result recipient=private helper")
        return false
    end
    reportActivation(unit)
    if unit.proof:IsFinished() then
        fail(system, unit, "Native arrest playback ended before confirmation; no payment")
        return cleanup(unit)
    end
    if unit.proof:Matches(unit.npc, unit.token) then
        if system:ConfirmActivatedArrest(unit.npc, unit.token, unit.proof) then
            unit.paid = true
            print("[NCPD Patrol] Arrest | Registered via " .. activationSource(unit) .. "; separate EUR$250 payment")
            keepLying(unit)
        else
            unit.retiring = true
            return cleanup(unit)
        end
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
        if system and system:Version() == 4 and system:GetStage() ~= 0 then system:CancelArrest("Arrest cancelled: shift ended") end
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
        if not system or system:Version() ~= 4 then error("Install all v0.7e arrest scripts and restart the game") end
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
