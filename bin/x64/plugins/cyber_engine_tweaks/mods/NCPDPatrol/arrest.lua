-- One private, non-persistent workspot anchor per arrested suspect. Ambient
-- NPCs are never spawned/deleted, healed, resurrected or given follower roles.
local M = {}
local CLIP = "lie_ground_0__2h_back_handcuffs_a__01"
local units, observedToken = {}, nil
local pendingPlacement=nil
local poll, lastRevision = 0, -1
local label = "Ready on duty; EUR$250 per arrest"
local unavailableReported = false
local lastLook = nil
local configuredLoop, configuredSource = nil, nil
local GROUND_FAILURE="NCPD_GROUND_UNSUITABLE"
local function groundFailure(reason) return tostring(reason):find(GROUND_FAILURE,1,true)~=nil end
local function publicFailure(reason)
    if groundFailure(reason) then return "Move the suspect to flat, clear ground and try again." end
    return "Unable to secure the suspect. Try again."
end

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

local function finite(point)
    return point and point.x==point.x and point.y==point.y and point.z==point.z
        and math.abs(point.x)<100000 and math.abs(point.y)<100000 and math.abs(point.z)<100000
end
local function pointDistance(a,b)
    local x,y,z=a.x-b.x,a.y-b.y,a.z-b.z
    return math.sqrt(x*x+y*y+z*z)
end
local function lyingPosition(npc)
    local nav,player,spatial=Game.GetAINavigationSystem(),Game.GetPlayer(),Game.GetSpatialQueriesSystem()
    if not nav or not player or not spatial then error("Arrest ground placement unavailable; R pickup can move the suspect") end
    local origin,from,forward=npc:GetWorldPosition(),player:GetWorldPosition(),npc:GetWorldForward()
    if not finite(origin) or not finite(from) or not finite(forward) then error("Invalid arrest placement coordinates") end
    local length=math.sqrt(forward.x*forward.x+forward.y*forward.y)
    local fx,fy=0,1
    if length>.01 then fx,fy=forward.x/length,forward.y/length end
    local surface={missing=0,slope=0,height=0}
    local function ground(point)
        local hit,trace=spatial:SyncRaycastByCollisionGroup(
            Vector4.new(point.x,point.y,point.z+.4,1),Vector4.new(point.x,point.y,point.z-.6,1),
            CName.new("Static"),true,false)
        if not hit or not trace or not finite(trace.position) or not finite(trace.normal) then
            surface.missing=surface.missing+1;return nil
        end
        if trace.normal.z<.95 then surface.slope=surface.slope+1;return nil end
        if math.abs(trace.position.z-point.z)>.35 then surface.height=surface.height+1;return nil end
        return Vector4.new(trace.position.x,trace.position.y,trace.position.z,1)
    end
    local best,bestScore,bestMove=nil,math.huge,nil
    local rejected={nav=0,floor=0,bounds=0,path=0,footprint=0}
    -- Score every supported candidate rather than accepting the current spot
    -- first. A flatter patch wins even when the root is already on navmesh.
    for _,offset in ipairs({{0,0},{.75,0},{-.75,0},{0,.75},{0,-.75},{1,1},{-1,1},{1,-1},{-1,-1},
        {1.6,0},{-1.6,0},{0,1.6},{0,-1.6},{1.3,.7},{-1.3,.7},{1.3,-.7},{-1.3,-.7}}) do
        local probe=Vector4.new(origin.x+offset[1],origin.y+offset[2],origin.z,1)
        -- Search depth may exceed the displacement budget; the resulting floor
        -- must still pass the same 2 m / 0.75 m native placement limits below.
        local result=nav:FindPointInSphereForCharacter(probe,.9,npc)
        if result and result.status==worldNavigationRequestStatus.OK and finite(result.point) then
            local point=ground(result.point)
            local clear=point~=nil
            if not clear then rejected.floor=rejected.floor+1
            elseif pointDistance(point,origin)>1.95 or math.abs(point.z-origin.z)>.7 or pointDistance(point,from)>2.45 then
                clear=false;rejected.bounds=rejected.bounds+1
            elseif not AINavigationSystem.HasPathFromAtoB(player,from,point) then
                clear=false;rejected.path=rejected.path+1
            end
            local footprintStarted=clear
            local low,high=point and point.z or 0,point and point.z or 0
            -- Check the full lying footprint, including both sides, against
            -- real static collision as well as pedestrian navigation. Navmesh
            -- alone can smooth over curbs/stairs and is not the floor surface.
            for _,foot in ipairs({{-.7,-.25},{-.7,.25},{.7,-.25},{.7,.25},{0,-.3},{0,.3}}) do
                if clear then
                    local endPoint=Vector4.new(point.x+fx*foot[1]-fy*foot[2],point.y+fy*foot[1]+fx*foot[2],point.z,1)
                    local support=nav:FindPointInSphereForCharacter(endPoint,.2,npc)
                    clear=support and support.status==worldNavigationRequestStatus.OK and finite(support.point)
                        and pointDistance(endPoint,support.point)<=.25 and math.abs(support.point.z-point.z)<=.2
                        and AINavigationSystem.HasPathFromAtoB(player,point,support.point)
                    if clear then
                        local floor=ground(endPoint)
                        clear=floor~=nil
                        if clear then low,high=math.min(low,floor.z),math.max(high,floor.z);clear=high-low<=.16 end
                    end
                end
            end
            if footprintStarted and not clear then rejected.footprint=rejected.footprint+1 end
            if clear then
                local moved=pointDistance(point,origin)
                local score=(high-low)*10+moved*.04
                if score<bestScore then best,bestScore,bestMove=Vector4.new(point.x,point.y,point.z+.03,1),score,moved end
            end
        else rejected.nav=rejected.nav+1 end
    end
    if best then
        print(string.format("[NCPD Patrol] Arrest placement | supported floor selected | move=%.2f m | target=(%.2f, %.2f, %.2f)",bestMove,best.x,best.y,best.z))
        return best
    end
    error(string.format("%s | no supported nearby patch | nav=%d | collision=%d | bounds=%d | path=%d | footprint=%d | ray misses=%d | slope=%d | floor height=%d | root=(%.2f,%.2f,%.2f)",
        GROUND_FAILURE,rejected.nav,rejected.floor,rejected.bounds,rejected.path,rejected.footprint,surface.missing,surface.slope,surface.height,origin.x,origin.y,origin.z))
end

local function recoverPhysics(system,unit,delta)
    if not unit.needsRecovery then return true end
    if not unit.physicsOwned then
        if not unit.npc:IsRagdollEnabled() then unit.needsRecovery=false;return true end
        if not system:BeginPoseRecovery(unit.npc,unit.token) then error("Ragdoll arrest recovery was refused") end
        unit.physicsOwned=true;unit.recoveryAge=0
        print("[NCPD Patrol] Arrest recovery | ragdoll reset requested; preparing nearby supported ground")
        return false
    end
    unit.recoveryAge=unit.recoveryAge+delta
    if unit.npc:IsRagdollEnabled() then
        if unit.recoveryAge>2 then error("Suspect physics did not release for arrest") end
        return false
    end
    if not unit.placed then
        if unit.recoveryAge<.25 then return false end
        if not system:PlaceRecoveredSuspect(unit.npc,unit.token,unit.position) then error("Nearby arrest placement was refused") end
        unit.placed=true;unit.recoveryAge=0
        return false
    end
    if unit.recoveryAge<.25 then return false end
    -- Teleport is a request and the character root need not equal floor height.
    -- Native workspot sliding performs the final alignment; confirm its actual
    -- position after entry below, before any payment, rather than blocking it.
    unit.needsRecovery=false
    print("[NCPD Patrol] Arrest recovery | ragdoll released; final placement delegated to the workspot")
    return true
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

local function loadedResource(unit, key, stateKey, path, label)
    if not unit[key] then unit[key] = Game.GetResourceDepot():LoadResource(path) end
    local token = unit[key]
    if not token then error(label .. " load returned no token") end
    local loaded, finished, failed = token:IsLoaded(), token:IsFinished(), token:IsFailed()
    local state = "loaded=" .. tostring(loaded) .. " | finished=" .. tostring(finished) .. " | failed=" .. tostring(failed)
    if state ~= unit[stateKey] then
        unit[stateKey] = state
        print("[NCPD Patrol] Arrest resource token | " .. label .. " | " .. state)
    end
    if failed then error(label .. " asynchronous load failed") end
    if not loaded then
        if finished then error(label .. " finished without a loaded resource") end
        return nil
    end
    return token:GetResource()
end

local function entryClass(system, entry)
    return entry and system:AnimationName(entry:GetClassName()) or "missing"
end

local function validateLoop(system, tree)
    local root = tree.rootEntry
    local list = root and read(root, "list")
    local loop = list and list[1]
    local children = loop and read(loop, "list")
    local pause = children and children[1]
    if entryClass(system, root) ~= "workSequence" or not list or #list ~= 1
        or entryClass(system, loop) ~= "workSequence" or not children or #children ~= 1
        or entryClass(system, pause) ~= "workPauseClip" then error("Outdated or invalid private arrest loop topology") end
    if not root.loopInfinitely or not loop.loopInfinitely or tree.initialCanUseExits
        or tree.useTimeLimitForSequences or system:AnimationName(loop.idleAnim) ~= CLIP
        or loop.id.id ~= 2 then error("Private arrest resource is not the expected exit-free lying loop") end
    return loop.id.id
end

local function prepare(system, unit, helper)
    if helper and not unit.component then
        unit.component = helper:FindComponentByType(CName.new("workWorkspotResourceComponent"))
        if not unit.component then error("Arrest helper has no workspot component; install the complete v0.17a package") end
        local name = system:AnimationName(unit.component.name)
        if name ~= "NCPDPatrolArrestLoop" then error("Outdated arrest helper; replace the bundled archive and restart") end
        print("[NCPD Patrol] Arrest setup | helper attached=true | component=" .. name)
    end
    -- Preload both async references before using the component. No reference
    -- helper writes or native source-resource mutations are performed.
    local source = loadedResource(unit, "bankToken", "sourceLoad", system:GetWorkspotResource(), "vanilla bindings")
    local resource = loadedResource(unit, "loopToken", "loopLoad", system:GetLoopResource(), "private loop")
    if not source or not resource then return false end
    local sourceTree, tree = read(source, "workspotTree"), read(resource, "workspotTree")
    if not sourceTree or not read(sourceTree, "rootEntry") or not tree or not read(tree, "rootEntry") then
        if unit.elapsed > 4 then error("Loaded arrest resources have no readable/ready trees") end
        return false
    end
    if not unit.prepared then
        local selected, nodes, sample = inspectTree(system, sourceTree)
        if selected ~= CLIP then error("Vanilla bindings do not expose the intended lying idle") end
        unit.entry = validateLoop(system, tree)
        local bindings = read(sourceTree, "finalAnimsets")
        if not bindings or #bindings == 0 then error("Vanilla workspot animation bindings are unreadable") end
        local currentBindings = read(tree, "finalAnimsets")
        if configuredLoop ~= resource or configuredSource ~= source
            or not currentBindings or #currentBindings ~= #bindings then
            -- Only the mod-owned resource receives these dependency/prop fields.
            -- Its authored root, loop flags, tags, status and exits stay intact.
            tree.finalAnimsets = bindings
            for _, field in ipairs({"workspotRig", "globalProps", "initialActions", "itemsPolicy", "propsPlaySyncAnim", "censorshipFlags", "whitelistVisualTags", "blacklistVisualTags"}) do
                local value = read(sourceTree, field)
                if value ~= nil then tree[field] = value end
            end
            configuredLoop, configuredSource = resource, source
            print("[NCPD Patrol] Arrest loop | private bindings configured | setups=" .. #bindings .. " | entry=2 | infinite=true | natural exits=false")
        end
        currentBindings = read(tree, "finalAnimsets")
        if not currentBindings or #currentBindings ~= #bindings then
            error("Private arrest animation bindings did not survive readback; helper not created")
        end
        unit.bindingCount = #currentBindings
        unit.clip, unit.resource, unit.prepared = CLIP, resource, true
        print("[NCPD Patrol] Arrest resources | private binding readback=" .. unit.bindingCount .. " | prepared before helper creation=true")
        print("[NCPD Patrol] Arrest bank | vanilla nodes=" .. nodes .. " | selected idle=" .. selected)
        print("[NCPD Patrol] Arrest bank names | " .. sample)
    end
    return true
end

local function jump(unit)
    -- The idle belongs to a container, not necessarily a workAnimClip leaf.
    -- Jump to our actual infinite sequence by entry ID; do not advance it.
    workspots():SendJumpCommandEnt(unit.npc, unit.entry, true)
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
    local function releasePhysics()
        if unit.physicsOwned then
            local system=native()
            if not system then return false end
            system:ReleasePosePhysics(unit.npc)
            unit.physicsOwned=false
        end
        return true
    end
    if not unit.id then return releasePhysics() end
    local system = entities()
    if not system or not system:IsReady() then return false end
    if not system:IsManaged(unit.id) then unit.id = nil; return releasePhysics() end
    if system:DeleteEntity(unit.id) and not system:IsManaged(unit.id) then
        unit.id = nil
        return releasePhysics()
    end
    return false
end

local function fail(system, unit, reason)
    if unit.failed then return end
    unit.failed, unit.retiring = true, true
    if not unit.paid then system:FailPose(unit.token, publicFailure(reason)) end
    print("[NCPD Patrol] Arrest | " .. reason)
end

local function create(system, npc, token, quiet, prepared)
    if not prepared or not prepared.prepared or not prepared.bindingCount or prepared.bindingCount < 1 then
        error("Arrest resources must be prepared before helper attachment")
    end
    local dynamic = entities()
    if not dynamic or not dynamic:IsReady() then error("Codeware entity system unavailable") end
    if workspots():IsActorInWorkspot(npc) then error("Suspect is already in another workspot") end
    local depot = Game.GetResourceDepot()
    local template = depot:ResourceExists(system:GetHelperTemplate())
    local bank = depot:ResourceExists(system:GetWorkspotResource())
    local loop = depot:ResourceExists(system:GetLoopResource())
    if not quiet then
        print("[NCPD Patrol] Arrest setup | archive=" .. tostring(depot:ArchiveExists("NCPDPatrol_Arrest.archive"))
            .. " | template=" .. tostring(template) .. " | bank=" .. tostring(bank) .. " | loop=" .. tostring(loop))
    end
    if not template or not bank or not loop then error("Arrest animation resources unavailable; no playback requested") end
    local spec = DynamicEntitySpec.new()
    spec.templatePath = system:GetHelperTemplate()
    local needsRecovery=npc:IsRagdollEnabled()
    local position=needsRecovery and lyingPosition(npc) or npc:GetWorldPosition()
    spec.position, spec.orientation = position, npc:GetWorldOrientation()
    spec.persistState, spec.persistSpawn = false, false
    spec.alwaysSpawned, spec.spawnInView, spec.active = false, true, true
    local id = dynamic:CreateEntity(spec)
    if not id then error("Arrest helper creation refused; check NCPDPatrol_Arrest.archive") end
    local unit = {id=id, npc=npc, token=token, elapsed=prepared.elapsed, started=false, paid=false,
        position=position,needsRecovery=needsRecovery,groundPlacement=needsRecovery,physicsOwned=false}
    for _,key in ipairs({"bankToken","loopToken","sourceLoad","loopLoad","entry","clip","resource","prepared","bindingCount"}) do
        unit[key] = prepared[key]
    end
    return unit
end

local function placementReady(unit)
    if not unit.groundPlacement then return true end
    local actual=unit.npc:GetWorldPosition()
    if not finite(actual) then return false end
    local horizontal=math.sqrt((actual.x-unit.position.x)^2+(actual.y-unit.position.y)^2)
    local vertical=math.abs(actual.z-unit.position.z)
    -- A human capsule/root can be above the floor while the lying animation
    -- is aligned with its device. Require local alignment, not an exact Z match.
    local ready=horizontal<=.65 and actual.z>=unit.position.z-.2 and actual.z<=unit.position.z+1.2
    if unit.placementReady~=ready then
        unit.placementReady=ready
        print(string.format("[NCPD Patrol] Arrest placement | aligned=%s | horizontal=%.2f m | root/floor height=%.2f m",tostring(ready),horizontal,vertical))
    end
    return ready
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
        unit.proof:Tick(delta, paused)
    end
    if unit.paid then
        if distance(player, unit.npc) > 60 or unit.proof:IsFinished() then
            if unit.proof:IsFinished() then print("[NCPD Patrol] Arrest loop | released after playback or actor state ended | active=" .. tostring(unit.proof:NativeActive()) .. " | exiting=" .. tostring(unit.proof:Exiting())) end
            unit.retiring = true
            return cleanup(unit)
        end
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
        if not recoverPhysics(system,unit,delta) then return false end
        unit.proof = NCPDPatrolArrestPlayback.new()
        if not system:ArmPlayback(unit.npc, helper, unit.token, unit.proof) then
            error("Arrest playback could not arm a clean native start")
        end
        unit.started = true
        workspots():PlayInDeviceSimple(helper, unit.npc, false, CName.new("NCPDPatrolArrestLoop"),
            CName.new("None"), CName.new("None"), unit.groundPlacement and .5 or 0,
            unit.groundPlacement and WorkspotSlidingBehaviour.PlayAtResourcePosition
                or WorkspotSlidingBehaviour.DontPlayAtResourcePosition, helper)
        jump(unit)
        print("[NCPD Patrol] Arrest request | private infinite idle | entry=" .. unit.entry .. " | requested clip=" .. unit.clip .. " | observed clip=unavailable | result recipient=private helper")
        return false
    end
    reportActivation(unit)
    if unit.proof:IsFinished() then
        fail(system, unit, "Native arrest playback ended before confirmation; no payment")
        return cleanup(unit)
    end
    if unit.proof:Matches(unit.npc, unit.token) and placementReady(unit) then
        if system:ConfirmActivatedArrest(unit.npc, unit.token, unit.proof) then
            unit.paid = true
            print("[NCPD Patrol] Arrest | Registered via " .. activationSource(unit) .. "; separate EUR$250 payment")
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
    pendingPlacement=nil
    configuredLoop, configuredSource = nil, nil
    label, unavailableReported = "Ready on duty; EUR$250 per arrest", false
    lastLook = nil
end

function M.finish()
    pendingPlacement=nil
    pcall(function()
        local system = native()
        if system and system:Version() == 6 and system:GetStage() ~= 0 then system:CancelArrest("Arrest cancelled: shift ended") end
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
        if not system or system:Version() ~= 6 then error("Install all v0.17a arrest scripts and restart the game") end
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
        if not onDuty or system:GetStage()~=2 then pendingPlacement=nil
        elseif not paused then
            local token = system:GetToken()
            if token ~= observedToken then
                observedToken = token
                pendingPlacement={token=token,npc=system:GetTarget(),age=0,retry=0,attempts=0}
            end
            local pending=pendingPlacement
            if pending then
                pending.age=pending.age+delta;pending.retry=pending.retry-delta
                if pending.retry<=0 then
                    pending.elapsed=pending.age
                    local made, unit = pcall(function()
                        -- A helper's workspot component can initialize on attach.
                        -- Its resource must already contain the native bindings.
                        if not prepare(system, pending, nil) then return nil end
                        if not pending.groundStarted then pending.groundStarted=pending.age end
                        pending.attempts=pending.attempts+1
                        return create(system, pending.npc, token,pending.attempts>1,pending)
                    end)
                    if made and unit then
                        units[#units+1] = unit
                        if pending.attempts>1 then
                            print(string.format("[NCPD Patrol] Arrest ground | ready after %d checks over %.2f s",pending.attempts,pending.age))
                        end
                        pendingPlacement=nil
                    elseif made then
                        if pending.age>8 then
                            system:FailPose(token,"Arrest animation resources did not become ready")
                            print("[NCPD Patrol] Arrest | Resource preparation timed out before helper creation; no payment")
                            pendingPlacement=nil
                        end
                    elseif groundFailure(unit) and pending.age-(pending.groundStarted or pending.age)<1.5 then
                        pending.retry=.35
                    else
                        system:FailPose(token, publicFailure(unit))
                        print(string.format("[NCPD Patrol] Arrest | %s | checks=%d | observed=%.2f s",tostring(unit),pending.attempts,pending.age))
                        pendingPlacement=nil
                    end
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
