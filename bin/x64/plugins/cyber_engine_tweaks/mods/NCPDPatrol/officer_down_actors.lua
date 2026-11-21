-- Shared production/survey actor boundary. Caller owns this exact ID array;
-- rejected/async deletion keeps it reserved. Never discovers ambient actors.
local Crew=require('officer_ai')
local M={}
local function distance(a,b) return math.sqrt((a.x-b.x)^2+(a.y-b.y)^2+(a.z-b.z)^2) end
function M.create(layout,backend,actors,onCreated)
    if #actors>0 then error('Previous scene actor IDs still reserved') end
    local system=Game.GetDynamicEntitySystem()
    if not system or not system:IsReady() then error('Codeware entity system unavailable') end
    for _,row in ipairs(layout) do
        if not TweakDB:GetRecord(TweakDBID.new(row.record)) then error('Missing private scene record: '..row.record) end
    end
    for _,row in ipairs(layout) do
        local spec=DynamicEntitySpec.new()
        spec.recordID=TweakDBID.new(row.record);spec.position=row.position;spec.orientation=backend:Orientation(row.yaw)
        spec.persistState,spec.persistSpawn,spec.alwaysSpawned=false,false,false;spec.spawnInView,spec.active=true,true
        local id=system:CreateEntity(spec)
        if not id or not EntityID.IsDefined(id) then error('Scene actor creation rejected: '..row.kind) end
        row.id=id;actors[#actors+1]=row
        if onCreated then onCreated(row) end
    end
end
function M.prepare(actors,backend)
    local system=Game.GetDynamicEntitySystem()
    local ready=true
    for _,row in ipairs(actors) do
        if not row.bound then
            local actor=system:GetEntity(row.id)
            if not actor or not actor:IsAttached() then ready=false else
                if system:IsManaged(row.id)~=true or actor:GetRecordID()~=TweakDBID.new(row.record) then error('Scene actor identity mismatch') end
                if distance(actor:GetWorldPosition(),row.position)>1.5 then error('Scene actor attached at an unexpected road level/position') end
                if row.car then
                    if not backend:ProtectVehicle(actor) then ready=false else row.bound=true;actor:ForceBrakesUntilStoppedOrFor(2) end
                else
                    if not actor:GetAIControllerComponent() or not actor:GetAttitudeAgent() then ready=false else
                        Crew.stopFollowing(actor)
                        if not backend:ProtectNPC(actor) then ready=false else
                            row.command=AIHoldPositionCommand.new()
                            row.command.duration=-1;row.command.ignoreInCombat=true;row.command.removeAfterCombat=false;row.command.alwaysUseStealth=false
                            actor:GetAIControllerComponent():SendCommand(row.command)
                            row.bound=true
                        end
                    end
                end
                if row.bound then row.actor=actor end
            end
        end
    end
    return ready
end
function M.lock(actors,backend,options)
    for _,row in ipairs(actors) do
        if row.actor and row.actor:IsAttached() then
            local p=row.actor:GetWorldPosition()
            if not (options and options.freeInjured and row.kind=='injured')
                and ((p.x-row.position.x)^2+(p.y-row.position.y)^2>.25 or math.abs(p.z-row.position.z)>1) then
                if not backend:LockPosition(row.actor,row.position,row.yaw) then error('Pre-arrival position lock rejected') end
            end
            if row.car then row.actor:ForceBrakesUntilStoppedOrFor(1) end
        end
    end
end
function M.measure(row,system)
    system=system or Game.GetDynamicEntitySystem()
    if not system or not system:IsReady() then return nil,'Entity system not ready' end
    local actor=system:GetEntity(row.id)
    if not row.bound or not actor or not actor:IsAttached() then return nil,'Actor missing/detached: '..row.kind end
    if not system:IsManaged(row.id) or actor:GetRecordID()~=TweakDBID.new(row.record) then return nil,'Actor identity changed: '..row.kind end
    local p=actor:GetWorldPosition()
    if not p or p.x~=p.x or p.y~=p.y or p.z~=p.z or math.abs(p.x)>=100000 or math.abs(p.y)>=100000 or math.abs(p.z)>=100000 then return nil,'Actor displaced: '..row.kind end
    return {kind=row.kind,record=row.record,yaw=row.yaw,
        expected={x=row.position.x,y=row.position.y,z=row.position.z},actual={x=p.x,y=p.y,z=p.z},displacement=distance(p,row.position)},nil,actor
end
function M.observe(actors,options)
    local system=Game.GetDynamicEntitySystem()
    if not system or not system:IsReady() then return nil,'Entity system not ready' end
    local samples={}
    for _,row in ipairs(actors) do
        local sample,reason,actor=M.measure(row,system)
        if not sample then return nil,reason end
        if options and options.injuredTransition and row.kind=='injured' then
            local p,q=sample.actual,sample.expected
            if (p.x-q.x)^2+(p.y-q.y)^2>9 or math.abs(p.z-q.z)>1.5 then return nil,'Injured transition outside hard envelope',sample end
        elseif sample.displacement>1.5 then return nil,'Actor displaced: '..row.kind,sample end
        if row.car then actor:ForceBrakesUntilStoppedOrFor(1) end
        samples[#samples+1]=sample
    end
    return samples
end
function M.remove(actors)
    local system=Game.GetDynamicEntitySystem()
    if not system or not system:IsReady() then return actors end
    local remaining={}
    for _,row in ipairs(actors) do
        local ok,gone=pcall(function()
            if system:IsManaged(row.id)==false then return true end
            return system:DeleteEntity(row.id)==true and system:IsManaged(row.id)==false
        end)
        if not ok or not gone then remaining[#remaining+1]=row end
    end
    return remaining
end
return M
