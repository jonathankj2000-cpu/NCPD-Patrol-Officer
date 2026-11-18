-- One owned attacker car/crew per transport. Road points are recorded from the
-- actual transport vehicle; pedestrian navigation is not used as a road finder.
local M = {}
local ids, units, trail = {}, {}, {}
local carID, car, chase = nil, nil, nil
local phase, label = "idle", "No ambush this trip"
local used, requested = false, false
local travelled, sample, clock, elapsed, age, stopped, escaped, retry = 0, 0, 0, 0, 0, 0, 0, 0
local triggerAt = 300
local function distance(a,b)
    return math.sqrt((a.x-b.x)^2+(a.y-b.y)^2+(a.z-b.z)^2)
end
local function same(a,b)
    return a and b and tostring(a:GetEntityID().hash)==tostring(b:GetEntityID().hash)
end
local function report(text,status) label=text;if status then status("VIP ambush | "..text) end end
local function notify(patrol,text) if patrol then patrol:NotifyDispatch("NCPD: "..text,8) end end
function M.state() return label end
function M.isActive() return phase~="idle" end
function M.reset()
    -- Only for a world transition. Never delete entity IDs from the old world.
    ids,units,trail={},{},{};carID,car,chase=nil,nil,nil
    phase,label="idle","No ambush this trip";used,requested=false,false
    travelled,sample,clock,elapsed,age,stopped,escaped,retry=0,0,0,0,0,0,0,0
    triggerAt=math.random(250,400)
end
function M.begin()
    if M.isActive() then return false end
    M.reset();return true
end
function M.request(status)
    if used then report("This trip has already used its one ambush",status);return false end
    requested=true;report("Test armed; drive until there is a safe recorded point 120-220 m behind you",status)
    return true
end
local function stopChase()
    if car and chase then pcall(function() car:GetAIComponent():StopExecutingCommand(chase,false) end) end
    chase=nil
end
local function cleanup(status)
    stopChase()
    local remaining={}
    local ok,system=pcall(function() return Game.GetDynamicEntitySystem() end)
    if not ok then system=nil end
    for i=#ids,1,-1 do
        local id=ids[i]
        local checked,gone=pcall(function()
            if not system then return false end
            if system:IsManaged(id)==false then return true end
            return system:DeleteEntity(id)==true and system:IsManaged(id)==false
        end)
        if not checked or not gone then remaining[#remaining+1]=id end
    end
    ids=remaining
    if #ids>0 then phase="cleanup";return false end
    units={};carID,car=nil,nil;phase="idle"
    report("Ambush closed",status);return true
end
function M.finish(status)
    if phase=="idle" and #ids==0 then used,requested=true,false;trail={};return true end
    requested=false;trail={};used=true;phase="cleanup";retry=0
    return cleanup(status)
end
local function create(system,record,point,orientation)
    if not TweakDB:GetRecord(TweakDBID.new(record)) then error("Missing ambush record: "..record) end
    local spec=DynamicEntitySpec.new()
    spec.recordID=TweakDBID.new(record);spec.position=point;spec.orientation=orientation
    spec.persistState,spec.persistSpawn,spec.alwaysSpawned=false,false,false
    spec.spawnInView,spec.active=true,true
    local id=system:CreateEntity(spec)
    if not id or not EntityID.IsDefined(id) then error("Ambush entity creation rejected") end
    ids[#ids+1]=id;return id
end
local function mount(unit,unmount)
    local data=MountEventData.new()
    data.mountParentEntityId,data.slotName=car:GetEntityID(),CName.new(unit.seat)
    data.isInstant,data.ignoreHLS,data.allowFailsafeTeleport=not unmount,not unmount,not unmount
    data.setEntityVisibleWhenMountFinish=true
    local options=NewObject("handle:gameMountEventOptions")
    options.silentUnmount,options.entityID,options.alive=false,car:GetEntityID(),true
    data.mountEventOptions=options
    local command=unmount and AIUnmountCommand.new() or AIMountCommand.new()
    command.mountData=data;command=command:Copy()
    unit.actor:GetAIControllerComponent():SendCommand(command);unit.command=command
end
local function hostile(actor,attack)
    local agent=actor:GetAttitudeAgent()
    agent:SetAttitudeGroup(CName.new("hostile"))
    agent:SetAttitudeTowards(Game.GetPlayer():GetAttitudeAgent(),EAIAttitude.AIA_Hostile)
    if attack then
        local command=AIInjectCombatThreatCommand.new()
        command.targetPuppetRef=Game.CreateEntityReference('#player',{})
        command.duration=-1;command.isPersistent=true;command.dontForceHostileAttitude=false
        actor:GetAIControllerComponent():SendCommand(command)
    end
end
local function roadPoint(vehicle)
    local pos,forward=vehicle:GetWorldPosition(),vehicle:GetWorldForward()
    for i=#trail,1,-1 do
        local point=trail[i]
        local metres=distance(point.position,pos)
        local behind=(point.position.x-pos.x)*forward.x+(point.position.y-pos.y)*forward.y
        if metres>=120 and metres<=220 and behind < -60 and clock-point.time>=4 and clock-point.time<=45
            and math.abs(point.position.z-pos.z)<=15 then return point end
    end
end
local function record(delta,vehicle)
    clock=clock+delta;sample=sample+delta
    if sample<1 or math.abs(vehicle:GetCurrentSpeed())<3 then return end
    sample=0
    local pos=vehicle:GetWorldPosition()
    local prev=trail[#trail]
    local moved=prev and distance(pos,prev.position) or 0
    if prev and moved>120 then trail={};travelled=0;prev=nil end
    if prev and moved<8 then return end
    travelled=travelled+(prev and moved or 0)
    trail[#trail+1]={position=Vector4.new(pos.x,pos.y,pos.z,1),orientation=vehicle:GetWorldOrientation(),time=clock}
    if #trail>60 then table.remove(trail,1) end
end
local function spawn(point,patrol,status)
    -- Reserve before the first create; partial creation must also be cleaned up.
    used,requested=true,false;phase="spawning";elapsed,age=0,0
    local system=Game.GetDynamicEntitySystem()
    if not system or not system:IsReady() then error("Ambush entity system not ready") end
    local pos=point.position
    carID=create(system,"Vehicle.NCPDPatrol_VIPAmbush",Vector4.new(pos.x,pos.y,pos.z+0.15,1),point.orientation)
    units={}
    for i,seat in ipairs({"seat_front_left","seat_front_right"}) do
        local id=create(system,"Character.NCPDPatrol_VIPAttacker",Vector4.new(pos.x+i*3,pos.y+3,pos.z+0.2,1),point.orientation)
        units[#units+1]={id=id,seat=seat}
    end
    report("Attacker car created at a recorded road position",status)
    notify(patrol,"Possible hostile vehicle behind your transport. Keep the witness safe.")
end
local function alive(actor)
    return actor and actor:IsAttached() and not actor:IsDead() and not actor:IsDeadNoStatPool()
        and not ScriptedPuppet.IsDefeated(actor) and not ScriptedPuppet.IsUnconscious(actor)
end
local function active(delta,vehicle,patrol,status)
    elapsed=elapsed+delta;age=age+delta
    if phase=="spawning" then
        local system=Game.GetDynamicEntitySystem()
        car=system:GetEntity(carID)
        local ready=car and car:IsAttached()
        for _,unit in ipairs(units) do unit.actor=system:GetEntity(unit.id);ready=ready and unit.actor and unit.actor:IsAttached() end
        if ready then
            for _,unit in ipairs(units) do mount(unit,false) end
            phase,elapsed="seating",0
        elseif elapsed>=12 then error("Ambush entities failed to attach") end
        return
    end
    if not car or not car:IsAttached() then error("Ambush vehicle unavailable") end
    if phase=="seating" then
        local ready=true
        for _,unit in ipairs(units) do ready=ready and same(Game.GetMountedVehicle(unit.actor),car) end
        if ready then
            for _,unit in ipairs(units) do unit.command=nil;hostile(unit.actor,false) end
            -- Native DynamicSpawnSystem uses this command/event/init sequence.
            chase=AIVehicleChaseCommand.new();chase.target=Game.GetPlayer()
            chase.distanceMin,chase.distanceMax,chase.forcedStartSpeed=8,18,10
            chase.ignoreChaseVehiclesLimit,chase.boostDrivingStats=true,true
            local event=AICommandEvent.new();event.command=chase
            car:SetPoliceStrategyDestination(Game.GetPlayer():GetWorldPosition())
            car:QueueEvent(event);car:GetAIComponent():SetInitCmd(chase)
            phase,elapsed="chasing",0;report("Hostile car pursuing the transport",status)
        elseif elapsed>=12 then error("Ambush crew failed to board") end
        return
    end
    local metres=distance(Game.GetPlayer():GetWorldPosition(),car:GetWorldPosition())
    if metres>350 then escaped=escaped+delta else escaped=0 end
    if escaped>=10 then notify(patrol,"Hostile vehicle lost. Continue to the safe location.");cleanup(status);return end
    if age>=150 then report("Pursuit test time limit reached",status);cleanup(status);return end
    if phase=="chasing" then
        if car:IsDestroyed() or not alive(units[1].actor) then
            stopChase();phase,elapsed="braking",0;car:ForceBrakesUntilStoppedOrFor(8)
        else
            if vehicle and math.abs(vehicle:GetCurrentSpeed())<1 and metres<=45 then stopped=stopped+delta else stopped=0 end
            if stopped>=3 then
                stopChase();car:ForceBrakesUntilStoppedOrFor(8);phase,elapsed="braking",0
                report("Transport stopped for 3 seconds; attackers braking before exit",status)
            end
        end
    elseif phase=="braking" then
        if math.abs(car:GetCurrentSpeed())<0.7 and elapsed>=0.5 then
            for _,unit in ipairs(units) do if alive(unit.actor) and Game.GetMountedVehicle(unit.actor) then mount(unit,true) end end
            phase,elapsed="exiting",0
        elseif elapsed>=10 then error("Attacker car did not stop safely") end
    elseif phase=="exiting" then
        local ready=true
        for _,unit in ipairs(units) do
            if alive(unit.actor) and Game.GetMountedVehicle(unit.actor) then ready=false end
        end
        if ready then
            for _,unit in ipairs(units) do if alive(unit.actor) then unit.command=nil;hostile(unit.actor,true) end end
            phase,elapsed="combat",0;report("Attackers on foot; escape or return fire",status)
        elseif elapsed>=15 then error("Attackers could not exit") end
    elseif phase=="combat" then
        local survivors=false
        for _,unit in ipairs(units) do survivors=survivors or alive(unit.actor) end
        if not survivors then report("Attackers neutralized",status);cleanup(status) end
    end
end
function M.update(delta,vehicle,transporting,nearDestination,patrol,status)
    if phase=="cleanup" then
        retry=retry+delta
        if retry>=2 then retry=0;cleanup(status) end
        return
    end
    if not transporting then return end
    if not patrol or patrol:IsDispatchMenuOpen() or delta<=0 or delta>0.5 then return end
    local ok,err=pcall(function()
        if vehicle then record(delta,vehicle) end
        if phase~="idle" then active(delta,vehicle,patrol,status);return end
        if used or nearDestination or not vehicle then return end
        if requested or travelled>=triggerAt then
            local point=roadPoint(vehicle)
            if point then spawn(point,patrol,status) end
        end
    end)
    if not ok then report("Ambush test stopped: "..tostring(err),status);M.finish(status) end
end
return M
