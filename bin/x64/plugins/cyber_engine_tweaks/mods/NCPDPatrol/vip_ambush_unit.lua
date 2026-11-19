-- One independently owned car/crew in a transport ambush convoy. Road points are recorded from the
-- actual transport vehicle; pedestrian navigation is not used as a road finder.
local function new(options)
options=options or {}
local M = {}
local ids, units, trail = {}, {}, {}
local carID, car, chase = nil, nil, nil
local phase, label = "idle", "No ambush this trip"
local used, requested = false, false
local travelled, sample, clock, elapsed, age, stopped, escaped, retry = 0, 0, 0, 0, 0, 0, 0, 0
local triggerAt = 300
local spawnPoint,trailVehicle=nil,nil
local attempts,retryAfterCleanup,settling=0,false,0
local function finite(p)
    return p and p.x==p.x and p.y==p.y and p.z==p.z
        and math.abs(p.x)<100000 and math.abs(p.y)<100000 and math.abs(p.z)<100000
end
local function distance(a,b)
    return math.sqrt((a.x-b.x)^2+(a.y-b.y)^2+(a.z-b.z)^2)
end
local function same(a,b)
    return a and b and tostring(a:GetEntityID().hash)==tostring(b:GetEntityID().hash)
end
local function report(text,status) label=text;if status then status("VIP ambush | "..text) end end
local function notify(patrol,text)
    if options.notify then options.notify(patrol,text)
    elseif patrol then patrol:NotifyDispatch("NCPD: "..text,8) end
end
function M.state() return label end
function M.isActive() return phase~="idle" end
function M.hasStarted() return used or attempts>0 end
function M.canStart() return phase=="idle" and not used end
function M.stage() return phase end
function M.position()
    if car and car:IsAttached() then
        local actual=car:GetWorldPosition()
        if actual then return actual end
    end
    return spawnPoint and spawnPoint.ground or nil
end
function M.reset()
    -- Only for a world transition. Never delete entity IDs from the old world.
    ids,units,trail={},{},{};carID,car,chase=nil,nil,nil
    phase,label="idle","No ambush this trip";used,requested=false,false
    travelled,sample,clock,elapsed,age,stopped,escaped,retry=0,0,0,0,0,0,0,0
    triggerAt=options.triggerAt or math.random(250,400)
    spawnPoint,trailVehicle=nil,nil;attempts,retryAfterCleanup,settling=0,false,0
end
function M.begin()
    if M.isActive() then return false end
    M.reset();return true
end
function M.request(status)
    if used then report("This trip has already used its one ambush",status);return false end
    requested=true;report("Test armed; waiting for an off-camera road point 35-65 m behind you",status)
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
    spawnPoint=nil
    if retryAfterCleanup and attempts<3 then
        retryAfterCleanup=false;used,requested=false,true;trail={};sample=0
        report("Unsafe road spawn released; waiting for a new checked road point (attempt "..attempts.."/3)",status)
    else
        retryAfterCleanup=false;report("Ambush closed",status)
    end
    return true
end
function M.finish(status,keepResolvedScene)
    retryAfterCleanup=false
    if keepResolvedScene and phase=="resolved" then return false end
    if phase=="idle" and #ids==0 then used,requested=true,false;trail={};return true end
    requested=false;trail={};used=true;phase="cleanup";retry=0
    return cleanup(status)
end
local function create(system,record,point,orientation)
    if not TweakDB:GetRecord(TweakDBID.new(record)) then error("Missing ambush record: "..record) end
    local spec=DynamicEntitySpec.new()
    spec.recordID=TweakDBID.new(record);spec.position=point;spec.orientation=orientation
    spec.persistState,spec.persistSpawn,spec.alwaysSpawned=false,false,false
    spec.spawnInView,spec.active=false,true
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
    local spatial=Game.GetSpatialQueriesSystem()
    if not spatial or not finite(pos) or not finite(forward) then return nil end
    local function ray(from,to)
        return spatial:SyncRaycastByCollisionGroup(from,to,CName.new("Static"),true,false)
    end
    local function floorAt(p)
        local hit,result=ray(Vector4.new(p.x,p.y,p.z+.75,1),Vector4.new(p.x,p.y,p.z-1.5,1))
        if not hit or not result or not finite(result.position) or not finite(result.normal)
            or result.normal.z<.85 or math.abs(result.position.z-p.z)>1.3 then return nil end
        return result
    end
    local function supported(point)
        local centre=floorAt(point.position)
        local direction=point.forward
        if not centre or not finite(direction) then return false end
        for _,corner in ipairs({{-2,-.85},{-2,.85},{2,-.85},{2,.85}}) do
            local dx=direction.x*corner[1]-direction.y*corner[2]
            local dy=direction.y*corner[1]+direction.x*corner[2]
            local p=Vector4.new(point.position.x+dx,point.position.y+dy,point.position.z,1)
            local floor=floorAt(p)
            local expected=centre.position.z-(centre.normal.x*dx+centre.normal.y*dy)/centre.normal.z
            if not floor or math.abs(floor.position.z-expected)>.2 then return false end
        end
        return centre.position
    end
    -- Walk the recent route backwards. A spatially close point from another
    -- carriageway, an earlier loop or a different bridge level is not "behind".
    local along,previous=0,pos
    for i=#trail,1,-1 do
        local point=trail[i]
        local segment=distance(previous,point.position)
        along=along+segment
        if along>65 then break end
        -- Check the swept car corridor along each recorded segment. Fail closed
        -- at barriers instead of projecting onto pedestrian navmesh/another road.
        for _,side in ipairs(segment>.1 and {-.8,0,.8} or {}) do
            local dx,dy=-point.forward.y*side,point.forward.x*side
            local hit=ray(Vector4.new(previous.x+dx,previous.y+dy,previous.z+.6,1),
                Vector4.new(point.position.x+dx,point.position.y+dy,point.position.z+.6,1))
            if hit then return nil end
        end
        previous=point.position
        local metres=distance(point.position,pos)
        local behind=(point.position.x-pos.x)*forward.x+(point.position.y-pos.y)*forward.y
        local heading=point.forward.x*forward.x+point.forward.y*forward.y
        if along>=35 and metres>=35 and metres<=65 and behind < -25 and heading>=.9
            and clock-point.time>=.5 and clock-point.time<=12 and math.abs(point.position.z-pos.z)<=4 then
            local ground=supported(point)
            local ok,hidden=pcall(function()
                local native=Game.GetScriptableSystemsContainer():Get("NCPDPatrolVIPSystem")
                return native and native:Version()==4 and native:CanSpawnAmbushAt(point.position)
            end)
            if ground and ok and hidden==true and (not options.canSpawnAt or options.canSpawnAt(ground)) then
                return {position=point.position,ground=ground,orientation=point.orientation,forward=point.forward,time=point.time}
            end
        end
    end
end
local function record(delta,vehicle)
    clock=clock+delta;sample=sample+delta
    if not same(trailVehicle,vehicle) then trail={};trailVehicle=vehicle;sample=0 end
    if sample<.25 or math.abs(vehicle:GetCurrentSpeed())<3 then return end
    sample=0
    local pos=vehicle:GetWorldPosition()
    local prev=trail[#trail]
    local moved=prev and distance(pos,prev.position) or 0
    if prev and moved>120 then trail={};travelled=0;prev=nil end
    if not finite(pos) then trail={};return end
    if prev and moved<5 then return end
    travelled=travelled+(prev and moved or 0)
    local forward=vehicle:GetWorldForward()
    if not finite(forward) then return end
    trail[#trail+1]={position=Vector4.new(pos.x,pos.y,pos.z,1),orientation=vehicle:GetWorldOrientation(),
        forward=Vector4.new(forward.x,forward.y,forward.z,0),time=clock}
    if #trail>120 then table.remove(trail,1) end
end
local function spawn(point,patrol,status)
    -- Reserve before the first create; partial creation must also be cleaned up.
    used,requested=true,false;phase="spawning";elapsed,age=0,0
    attempts=attempts+1;retryAfterCleanup=false;settling=0;spawnPoint=point
    local system=Game.GetDynamicEntitySystem()
    if not system or not system:IsReady() then error("Ambush entity system not ready") end
    local pos=point.position
    carID=create(system,"Vehicle.NCPDPatrol_VIPAmbush",Vector4.new(pos.x,pos.y,point.ground.z+0.15,1),point.orientation)
    units={}
    report("Attacker car requested at checked road history; verifying actual road level",status)
end
local function positioned()
    if not car or not car:IsAttached() or not spawnPoint then return false end
    local actual,expected=car:GetWorldPosition(),spawnPoint.ground
    return finite(actual) and math.sqrt((actual.x-expected.x)^2+(actual.y-expected.y)^2)<=1.5
        and actual.z>=expected.z-.25 and actual.z<=expected.z+1.2
end
local function rejectPlacement(status)
    local actual=car and car:GetWorldPosition()
    local expected=spawnPoint and spawnPoint.position
    report(string.format("Road placement rejected | actual=%s | requested=%s",
        actual and string.format("%.1f,%.1f,%.1f",actual.x,actual.y,actual.z) or "unavailable",
        expected and string.format("%.1f,%.1f,%.1f",expected.x,expected.y,expected.z) or "unavailable"),status)
    retryAfterCleanup=true;phase="cleanup";retry=0
    cleanup(status)
end
local function alive(actor)
    return actor and actor:IsAttached() and not actor:IsDead() and not actor:IsDeadNoStatPool()
        and not ScriptedPuppet.IsDefeated(actor) and not ScriptedPuppet.IsUnconscious(actor)
end
local function crewNeutralized()
    if #units~=2 then return false end
    for _,unit in ipairs(units) do
        -- Missing/streamed-out actors are not proof of neutralization.
        if not unit.actor or not unit.actor:IsAttached() or alive(unit.actor) then return false end
    end
    return true
end
local function resolve(status)
    stopChase();car:ForceBrakesUntilStoppedOrFor(8)
    phase,elapsed,escaped="resolved",0,0
    report("Attackers neutralized; scene retained for 90 seconds or until you leave 150 m",status)
end
local function updateResolved(delta,status)
    elapsed=elapsed+delta
    local pos=Game.GetPlayer():GetWorldPosition()
    local away=true
    if car and car:IsAttached() and distance(pos,car:GetWorldPosition())<150 then away=false end
    for _,unit in ipairs(units) do
        if unit.actor and unit.actor:IsAttached() and distance(pos,unit.actor:GetWorldPosition())<150 then away=false end
    end
    if away then escaped=escaped+delta else escaped=0 end
    if elapsed>=90 or escaped>=3 then cleanup(status) end
end
local function active(delta,vehicle,patrol,status)
    elapsed=elapsed+delta;age=age+delta
    if phase=="spawning" then
        local system=Game.GetDynamicEntitySystem()
        car=system:GetEntity(carID)
        if car and car:IsAttached() then
            if not positioned() then
                settling=0
                if elapsed>=1 then rejectPlacement(status) end
                return
            end
            if #units==0 then
                if settling==0 then car:ForceBrakesUntilStoppedOrFor(1) end
                settling=settling+delta
                if settling<.75 then return end
                -- Spawn inside the verified car footprint, then mount each
                -- attached actor immediately. Sideways +3/+6 m offsets can put
                -- crew beyond a guardrail or off the edge of a bridge.
                local pos=car:GetWorldPosition()
                for _,seat in ipairs({"seat_front_left","seat_front_right"}) do
                    local id=create(system,"Character.NCPDPatrol_VIPAttacker",Vector4.new(pos.x,pos.y,pos.z+1,1),spawnPoint.orientation)
                    units[#units+1]={id=id,seat=seat}
                end
            end
        end
        local ready=car and car:IsAttached()
        for _,unit in ipairs(units) do
            unit.actor=system:GetEntity(unit.id)
            local attached=unit.actor and unit.actor:IsAttached()
            if attached and not unit.command then mount(unit,false) end
            ready=ready and attached
        end
        if ready and #units==2 then
            phase,elapsed="seating",0
        elseif elapsed>=12 then error("Ambush entities failed to attach") end
        return
    end
    if not car or not car:IsAttached() then error("Ambush vehicle unavailable") end
    if crewNeutralized() then resolve(status);return end
    if phase=="seating" then
        if not positioned() then rejectPlacement(status);return end
        local ready=true
        for _,unit in ipairs(units) do ready=ready and same(Game.GetMountedVehicle(unit.actor),car) end
        if ready then
            if distance(Game.GetPlayer():GetWorldPosition(),car:GetWorldPosition())>130 then rejectPlacement(status);return end
            for _,unit in ipairs(units) do unit.command=nil;hostile(unit.actor,false) end
            -- Native DynamicSpawnSystem uses this command/event/init sequence.
            chase=AIVehicleChaseCommand.new();chase.target=Game.GetPlayer()
            chase.distanceMin,chase.distanceMax,chase.forcedStartSpeed=8,18,10
            chase.ignoreChaseVehiclesLimit,chase.boostDrivingStats=true,true
            local event=AICommandEvent.new();event.command=chase
            car:SetPoliceStrategyDestination(Game.GetPlayer():GetWorldPosition())
            car:QueueEvent(event);car:GetAIComponent():SetInitCmd(chase)
            phase,elapsed="chasing",0;report("Hostile car pursuing the transport",status)
            notify(patrol,"Possible hostile vehicle behind your transport. Keep the witness safe.")
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
    end
end
function M.update(delta,vehicle,transporting,nearDestination,patrol,status)
    if phase=="cleanup" then
        retry=retry+delta
        if retry>=2 then retry=0;cleanup(status) end
        return
    end
    if not patrol or patrol:IsDispatchMenuOpen() or delta<=0 or delta>0.5 then return end
    local ok,err=pcall(function()
        if phase=="resolved" then updateResolved(delta,status);return end
        if not transporting then return end
        if vehicle then record(delta,vehicle) end
        if phase~="idle" then active(delta,vehicle,patrol,status);return end
        if used or nearDestination or not vehicle then return end
        if requested or travelled>=triggerAt then
            local point=roadPoint(vehicle)
            if point then spawn(point,patrol,status)
            elseif label~="Waiting for an off-camera road point 35-65 m behind you" then
                report("Waiting for an off-camera road point 35-65 m behind you",status)
            end
        end
    end)
    if not ok then report("Ambush test stopped: "..tostring(err),status);M.finish(status) end
end
return M
end
return {new=new}
