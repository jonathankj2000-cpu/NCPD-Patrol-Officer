-- Opt-in native quest-marker experiment. Owns only a meshless private anchor;
-- native code owns its private journal/mappin. No normal dispatch is replaced.
local M={}
local TAG='NCPDPatrol_QuestMarkerProbeAnchor'
local phase,label='idle','Quest marker test ready (off duty only)'
local id,target=nil,nil
local elapsed,retry,revision=0,0,-1
local function native()
    local system=Game.GetScriptableSystemsContainer():Get('NCPDPatrolQuestMarkerProbeSystem')
    if not system or system:Version()~=2 then error('Install the complete r4b quest-marker test package and restart') end
    return system
end
local function report(text,status) label=text;if status then status('Quest marker test | '..text) end end
local function deleteAnchor()
    if not id then return true end
    local system=Game.GetDynamicEntitySystem()
    if not system or not system:IsReady() then return false end
    if system:IsManaged(id)==false then id=nil;return true end
    if system:IsTagged(id,TAG)~=true then return false end
    system:DeleteEntity(id)
    if system:IsManaged(id)==false then id=nil;return true end
    return false
end
function M.state() return label end
function M.reset()
    -- Loading a world forgets old IDs without touching a reused handle.
    phase,label='idle','Quest marker test ready (off duty only)'
    id,target=nil,nil;elapsed,retry,revision=0,0,-1
end
function M.finish(status,reason)
    if phase=='idle' and not id then
        local ok,pending=pcall(function() local b=native();return b:HasRequest() or b:HasPendingCleanup() end)
        if not ok or not pending then return true end
    end
    local ok,err=pcall(function() native():Stop(reason or 'Quest marker experiment removed') end)
    phase='cleanup';retry=0
    local gone,deleted=pcall(deleteAnchor)
    local pending=false
    pcall(function() pending=native():HasPendingCleanup() end)
    if gone and deleted and not pending then phase='idle';target=nil end
    if status then report(ok and (reason or 'Removing private quest marker and anchor') or tostring(err),status) end
    return phase=='idle'
end
function M.start(status)
    if phase~='idle' or id then report('A test/anchor cleanup is already active',status);return false end
    local ok,err=pcall(function()
        local player=Game.GetPlayer();if not player then error('Load a save first') end
        local patrol=Game.GetScriptableSystemsContainer():Get('NCPDPatrolSystem')
        if not patrol or patrol:IsOnDuty() or patrol:HasWantedLevel() or patrol:IsDispatchMenuOpen() or player:IsInCombat() then error('Run this isolated test OFF DUTY, outside combat/menus/wanted status') end
        local backend=native();if not backend:IsReady() then error('Probe journal unavailable; install NCPDPatrol_QuestMarkerProbe.archive/.xl and restart') end
        local entities=Game.GetDynamicEntitySystem();if not entities or not entities:IsReady() then error('Codeware entity system unavailable') end
        if not Game.GetResourceDepot():ResourceExists(backend:GetAnchorTemplate()) then error('Private marker anchor resource unavailable') end
        -- A snapshot, not a moving-player reference. It never updates afterward.
        local p,forward=player:GetWorldPosition(),player:GetWorldForward()
        local length=math.sqrt(forward.x*forward.x+forward.y*forward.y)
        local x,y=1,0;if length>.001 then x,y=forward.x/length,forward.y/length end
        target=Vector4.new(p.x+x*150,p.y+y*150,p.z,1)
        local spec=DynamicEntitySpec.new();spec.templatePath=backend:GetAnchorTemplate()
        spec.position=target;spec.orientation=player:GetWorldOrientation()
        spec.persistState,spec.persistSpawn=false,false
        spec.alwaysSpawned,spec.spawnInView,spec.active=true,true,true
        spec.tags={CName.new(TAG)}
        id=entities:CreateEntity(spec)
        if not id or not EntityID.IsDefined(id) then id=nil;error('Private anchor creation rejected') end
        phase,elapsed='spawning',0;revision=-1
        report('Private stationary target requested 150 m ahead of the starting position; waiting for attachment',status)
    end)
    if not ok then
        if id then M.finish(nil,'Probe setup failed') end
        report(tostring(err),status);return false
    end
    return true
end
function M.diagnostics()
    local ok,text=pcall(function() return native():GetDiagnostics() end)
    return 'phase='..phase..' | anchor='..tostring(id and id.hash or 'none')..' | input=Active | '..(ok and text or tostring(text))
end
function M.update(delta,onDuty,status)
    if not Game.GetPlayer() then return end
    local ok,err=pcall(function()
        local backend=native()
        backend:Tick(delta)
        if phase=='idle' then return end
        if phase=='cleanup' then
            retry=retry+delta
            if retry>=1 then
                retry=0
                if deleteAnchor() and not backend:HasPendingCleanup() then phase='idle';target=nil;report('Private test cleanup confirmed; ready for another test',status) end
            end
            return
        end
        if onDuty then M.finish(status,'Probe removed as a normal shift started');return end
        local patrol=Game.GetScriptableSystemsContainer():Get('NCPDPatrolSystem')
        if patrol and patrol:IsDispatchMenuOpen() then return end
        if delta<=0 or delta>.5 then return end
        elapsed=elapsed+delta
        if phase=='spawning' then
            local entities=Game.GetDynamicEntitySystem()
            local anchor=entities:GetEntity(id)
            if anchor and anchor:IsAttached() then
                if not entities:IsTagged(id,TAG) or not backend:Begin(anchor,target) then error('Native probe rejected attached anchor; '..backend:GetDiagnostics()) end
                phase='active'
            elseif elapsed>=15 then error('Private anchor did not attach within 15 seconds') end
        elseif not backend:HasRequest() then M.finish(status,'Native probe closed; cleaning anchor') end
        local value=backend:GetRevision()
        if value~=revision then revision=value;report(backend:GetDiagnostics(),status) end
    end)
    if not ok and phase~='idle' then M.finish(nil,'Probe failed');report(tostring(err),status) end
end
return M
