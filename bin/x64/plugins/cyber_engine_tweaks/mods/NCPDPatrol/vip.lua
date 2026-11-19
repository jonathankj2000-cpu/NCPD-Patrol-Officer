-- Two-stage witness transport. Native checks, rather than a sent mount command,
-- decide when objective two unlocks and when the passenger is delivered.
local Crew = require("officer_ai")
local Ambush = require("vip_ambush")
local M = {}
local RECORD="Character.NCPDPatrol_VIP"
local phase,label="idle","No VIP transport"
local id,actor,token,pickup,destination,car,command=nil,nil,nil,nil,nil,nil,nil
local elapsed,poll,retry,resolvedTime,boardingAge,searchAge=0,0,0,0,0,0
local boardingSeat,finalReason,lastStage=nil,nil,0
local keepResolvedScene=false
local locationInfo="Not selected"
local function native()
    local system=Game.GetScriptableSystemsContainer():Get("NCPDPatrolVIPSystem")
    if not system or system:Version()~=2 then error("Install the complete v0.14b VIP package and restart") end
    return system
end
local function distance(a,b) return math.sqrt((a.x-b.x)^2+(a.y-b.y)^2+(a.z-b.z)^2) end
local function finite(p)
    return p and p.x==p.x and p.y==p.y and p.z==p.z and math.abs(p.x)<100000 and math.abs(p.y)<100000 and math.abs(p.z)<100000
end
local function same(a,b) return a and b and tostring(a:GetEntityID().hash)==tostring(b:GetEntityID().hash) end
local function report(text,status) label=text;if status then status("VIP | "..text) end end
local function notify(patrol,text) if patrol then patrol:NotifyDispatch("NCPD VIP: "..text,8) end end
local function waypoint(patrol,point)
    patrol:ClearDispatchWaypoints()
    local marker=patrol:PlaceDispatchWaypoint(point)
    if not marker or marker.value==0 then error("VIP waypoint creation failed") end
end
function M.state() return label end
function M.ambushState() return Ambush.state() end
function M.isActive() return phase~="idle" or Ambush.isActive() end
function M.reset()
    -- World transitions forget old IDs without touching the previous world.
    phase,label="idle","No VIP transport"
    id,actor,token,pickup,destination,car,command=nil,nil,nil,nil,nil,nil,nil
    elapsed,poll,retry,resolvedTime,boardingAge,searchAge=0,0,0,0,0,0
    boardingSeat,finalReason,lastStage=nil,nil,0
    keepResolvedScene=false
    locationInfo="Not selected"
    Ambush.reset()
end
function M.diagnostics()
    local ok,info=pcall(function() return native():GetDiagnostics() end)
    return "phase="..phase.." | seat="..tostring(boardingSeat).." | entity="..tostring(id and id.hash or "none")
        .." | locations="..locationInfo.." | ambush="..Ambush.state().." | "..tostring(info)
end
local function stopCommand()
    if actor and command then pcall(function() actor:GetAIControllerComponent():StopExecutingCommand(command,false) end) end
    command=nil
end
local function cleanup(status)
    local ambushGone=Ambush.finish(status,keepResolvedScene)
    local gone=id==nil
    if id then
        local ok,result=pcall(function()
            local system=Game.GetDynamicEntitySystem()
            if not system then return false end
            if system:IsManaged(id)==false then return true end
            return system:DeleteEntity(id)==true and system:IsManaged(id)==false
        end)
        gone=ok and result
    end
    if gone then id,actor,command=nil,nil,nil end
    if not gone or not ambushGone then phase="cleanup";return false end
    phase="idle";token,pickup,destination,car=nil,nil,nil,nil
    report(finalReason or "VIP transport cleared",status);return true
end
function M.finish(patrol,status,reason,failed)
    keepResolvedScene=false
    finalReason=reason or "VIP assignment cancelled"
    if token then
        pcall(function()
            if failed then native():Fail(token,finalReason) else native():Cancel(token,finalReason) end
        end)
    end
    if patrol then pcall(function() patrol:ClearDispatchWaypoints() end) end
    stopCommand();phase="cleanup";retry=0
    return cleanup(status)
end
function M.cancel(patrol,status)
    if not M.isActive() then return false end
    local cleared=M.finish(patrol,status,"VIP transport cancelled/cleared")
    notify(patrol,cleared and "Assignment cancelled." or "Assignment cancelled; unit cleanup pending.")
    return cleared
end
local function chooseLocations(player)
    local pins=Game.GetMappinSystem():GetAllMappins()
    local sites,occupied,seen={},{},{}
    local terminals,dropPoints=0,0
    local start=player:GetWorldPosition()
    for _,pin in ipairs(pins) do
        -- Interaction availability is not geographic availability: native
        -- fast travel can be inactive while V is in a car or during a lock.
        local ok,variant,phaseNow,point=pcall(function() return pin:GetVariant(),pin:GetPhase(),pin:GetWorldPosition() end)
        if ok and finite(point) and (point.x~=0 or point.y~=0 or point.z~=0) then
            if variant==gamedataMappinVariant.FastTravelVariant
                or variant==gamedataMappinVariant.ServicePointDropPointVariant then
                local key=string.format("%.1f:%.1f:%.1f",point.x,point.y,point.z)
                if not seen[key] then
                    seen[key]=true
                    local kind=variant==gamedataMappinVariant.FastTravelVariant and "fast travel" or "drop point"
                    if kind=="fast travel" then terminals=terminals+1 else dropPoints=dropPoints+1 end
                    sites[#sites+1]={position=Vector4.new(point.x,point.y,point.z,1),distance=distance(start,point),kind=kind}
                end
            elseif (variant==gamedataMappinVariant.GangWatchVariant or variant==gamedataMappinVariant.OutpostVariant)
                and phaseNow~=gamedataMappinPhase.CompletedPhase then occupied[#occupied+1]=point end
        end
    end
    local safe={}
    for _,site in ipairs(sites) do
        local clear=true
        for _,point in ipairs(occupied) do if distance(site.position,point)<100 then clear=false;break end end
        if clear then safe[#safe+1]=site end
    end
    locationInfo=string.format("fast travel=%d | drop points=%d | clear=%d",terminals,dropPoints,#safe)
    -- Prefer the established local fast-travel routes. If there is no pair,
    -- expand the same search with native drop-point terminal locations. This
    -- reads world markers only; never registers/unlocks a travel point.
    for _,includeDropPoints in ipairs({false,true}) do
        for _,radius in ipairs({1000,1500,2000}) do
            local pairs={}
            for _,site in ipairs(safe) do
                if (includeDropPoints or site.kind=="fast travel") and site.distance>=500 and site.distance<=radius then
                    local drops={}
                    for _,drop in ipairs(safe) do
                        local metres=distance(site.position,drop.position)
                        if (includeDropPoints or drop.kind=="fast travel") and metres>=800 and metres<=2500 then drops[#drops+1]=drop end
                    end
                    if #drops>0 then
                        local drop=drops[math.random(1,#drops)]
                        pairs[#pairs+1]={pickup=site.position,drop=drop.position,kind=site.kind.." -> "..drop.kind}
                    end
                end
            end
            if #pairs>0 then
                local pair=pairs[math.random(1,#pairs)]
                locationInfo=locationInfo.." | selected="..pair.kind.." | radius="..radius.." m"
                return pair
            end
        end
    end
    error("No safe VIP terminal pair 500-2000 m away ("..locationInfo.."). Travel to another area and retry.")
end
local function spawnVIP(player)
    local system=Game.GetDynamicEntitySystem()
    if not system or not system:IsReady() then error("Codeware entity system not ready") end
    if not TweakDB:GetRecord(TweakDBID.new(RECORD)) then error("VIP character record unavailable") end
    local nav=Game.GetAINavigationSystem()
    if not nav then error("Navigation system unavailable") end
    local point=nil
    for _,offset in ipairs({{12,0},{-12,0},{0,12},{0,-12},{24,0},{0,24}}) do
        local probe=Vector4.new(pickup.x+offset[1],pickup.y+offset[2],pickup.z,1)
        local result=nav:FindPointInSphereForCharacter(probe,4,player)
        if result and result.status==worldNavigationRequestStatus.OK and finite(result.point)
            and math.abs(result.point.z-pickup.z)<=2.5 and distance(result.point,pickup)<=45
            and AINavigationSystem.HasPathFromAtoB(player,player:GetWorldPosition(),result.point) then point=result.point;break end
    end
    if not point then return false end
    local spec=DynamicEntitySpec.new()
    spec.recordID=TweakDBID.new(RECORD);spec.position=Vector4.new(point.x,point.y,point.z+0.2,1)
    spec.orientation=player:GetWorldOrientation();spec.persistSpawn,spec.persistState,spec.alwaysSpawned=false,false,false
    spec.spawnInView,spec.active=true,true
    id=system:CreateEntity(spec)
    if not id or not EntityID.IsDefined(id) then id=nil;error("VIP creation rejected") end
    phase,elapsed="spawning",0;return true
end
local function follow()
    stopCommand()
    local cmd=AIFollowTargetCommand.new()
    cmd.target=Game.GetPlayer();cmd.desiredDistance,cmd.tolerance=2.5,0.7
    cmd.movementType=moveMovementType.Run;cmd.matchSpeed=true
    cmd.teleport=false;cmd.stopWhenDestinationReached=false
    cmd.ignoreInCombat,cmd.removeAfterCombat,cmd.alwaysUseStealth=false,false,false
    actor:GetAIControllerComponent():SendCommand(cmd);command=cmd
end
local function freeSeat(vehicle)
    for _,seat in ipairs({"seat_back_right","seat_back_left","seat_front_right"}) do
        if VehicleComponent.HasSlot(vehicle,CName.new(seat)) and not VehicleComponent.IsSlotOccupied(vehicle:GetEntityID(),CName.new(seat)) then return seat end
    end
end
local function mount(vehicle,seat,unmount)
    stopCommand()
    local data=MountEventData.new()
    data.mountParentEntityId,data.slotName=vehicle:GetEntityID(),CName.new(seat)
    data.isInstant,data.ignoreHLS,data.allowFailsafeTeleport=false,false,false
    data.setEntityVisibleWhenMountFinish=true
    local options=NewObject("handle:gameMountEventOptions")
    options.silentUnmount,options.entityID,options.alive=false,vehicle:GetEntityID(),true
    data.mountEventOptions=options
    local cmd=unmount and AIUnmountCommand.new() or AIMountCommand.new()
    cmd.mountData=data;cmd=cmd:Copy()
    actor:GetAIControllerComponent():SendCommand(cmd);command=cmd
    car,boardingSeat,boardingAge=vehicle,seat,0
end
function M.request(patrol,status,sound,voice)
    if M.isActive() then report("Transport/cleanup already active",status);return false end
    local ok,err=pcall(function()
        local player=Game.GetPlayer()
        if not player or not patrol or not patrol:IsOnDuty() then error("Start a shift before requesting VIP transport") end
        if patrol:IsDispatchMenuOpen() or player:IsInCombat() then error("Leave game menus and combat before requesting VIP transport") end
        local backend=native()
        if not backend:IsReady() then error("VIP journal unavailable; install the new archive/.xl and restart") end
        local pair=chooseLocations(player);pickup,destination=pair.pickup,pair.drop
        if status then status("VIP locations | "..locationInfo) end
        token=backend:BeginDispatch(pickup,destination)
        if not token or token==0 then error("VIP journal request rejected: "..tostring(backend:GetReason())) end
        phase,elapsed,poll,lastStage="responding",0,0,1;finalReason=nil;searchAge=0;keepResolvedScene=false
        if not Ambush.begin() then error("Previous ambush cleanup still active") end
        waypoint(patrol,pickup)
        patrol:NotifyDispatch("NCPD DISPATCH: Protected witness transport. Collect the VIP at the marked location. Use an owned police car with a free passenger seat.",10,sound,voice)
        report("Assigned: collect protected witness; destination follows after boarding",status)
    end)
    if not ok then
        M.finish(patrol,status,"VIP setup failed: "..tostring(err),true)
        return false
    end
    return true
end
function M.requestAmbush(status)
    if phase~="transport" then report("Ambush test requires objective 2 with the witness aboard",status);return false end
    return Ambush.request(status)
end
local function physical(delta,backend,patrol,status)
    local player=Game.GetPlayer()
    elapsed=elapsed+delta
    if phase=="responding" then
        if backend:CanSpawn(token) then
            searchAge=searchAge+delta
            if not spawnVIP(player) and searchAge>=8 then error("No reachable VIP position at pickup") end
        end
    elseif phase=="spawning" then
        local system=Game.GetDynamicEntitySystem()
        actor=system:GetEntity(id)
        if actor and actor:IsAttached() then
            if system:IsManaged(id)~=true or not backend:BindVIP(token,actor) then error("Own VIP binding rejected") end
            Crew.follower(actor);follow();phase,elapsed="pickup",0
            notify(patrol,"Witness located. Stop nearby as driver; keep a passenger seat free.")
            report("Witness ready for pickup",status)
        elseif elapsed>=12 then error("VIP did not attach") end
    elseif phase=="pickup" or phase=="boarding" or phase=="transport" then
        local mounted=Game.GetMountedVehicle(actor)
        local vehicle=Game.GetMountedVehicle(player)
        if mounted then
            -- Do not stop the completed mount command while the VIP is seated.
            command=nil
            if backend:GetStage()==1 then
                if not backend:ConfirmBoarded(token,mounted) then return end
            end
            car=mounted
            if backend:CanDropOff(token) and backend:BeginDropOff(token) then
                local info=Game.GetMountingFacility():GetMountingInfoSingleWithObjects(actor)
                local seat=info and info.slotId and info.slotId.id
                if not seat then error("Actual VIP seat unavailable for drop-off") end
                mount(car,seat,true);phase,elapsed="unloading",0
                report("At safe location; witness exiting",status)
            end
            return
        end
        if phase=="boarding" then
            boardingAge=boardingAge+delta
            if not same(vehicle,car) or math.abs(car:GetCurrentSpeed())>2 or boardingAge>=25 then
                follow();phase=backend:GetStage()==2 and "transport" or "pickup";boardingAge=0
            end
            return
        end
        if vehicle and (backend:GetStage()==1 or same(vehicle,car)) and backend:CanUseVehicle(vehicle) and math.abs(vehicle:GetCurrentSpeed())<1
            and distance(actor:GetWorldPosition(),vehicle:GetWorldPosition())<=35 then
            local seat=freeSeat(vehicle)
            if seat then
                -- Rear seats first; never steal the driver's or partner's seat.
                mount(vehicle,seat,false);phase="boarding"
                report("Witness walking to free passenger door: "..seat,status)
            end
        end
    elseif phase=="unloading" then
        if elapsed>=20 then error("Witness could not leave the vehicle at the safe location") end
    end
end
function M.update(delta,onDuty,patrol,status,HUD)
    if phase=="cleanup" then
        Ambush.update(delta,nil,false,true,patrol,status)
        retry=retry+delta
        if retry>=2 then retry=0;cleanup(status) end
        return true
    end
    if phase=="idle" then
        -- Reconcile a saved active journal even though transient actors were
        -- deliberately forgotten on load.
        if Game.GetPlayer() then pcall(function() native():Tick(delta) end) end
        return Ambush.isActive()
    end
    local ok,err=pcall(function()
        if not patrol or not Game.GetPlayer() then return end
        local backend=native();backend:Tick(delta)
        if not onDuty or not patrol:IsOnDuty() then M.finish(patrol,status,"Shift ended");HUD.set("",false);return end
        local stage=backend:GetStage()
        if token~=backend:GetToken() then M.finish(patrol,status,"VIP world/session changed");return end
        if stage>=3 then
            if phase~="resolved" then
                finalReason=backend:GetReason();patrol:ClearDispatchWaypoints();HUD.set("",false)
                report((stage==3 and "COMPLETED | " or "CLOSED | ")..finalReason,status)
                keepResolvedScene=stage==3
                notify(patrol,finalReason);Ambush.finish(status,keepResolvedScene)
                if stage~=3 then phase="cleanup";cleanup(status);return end
                command=nil
                if actor and actor:IsAttached() then command=Crew.hold(actor) end
                phase,resolvedTime="resolved",0
            end
            Ambush.update(delta,nil,false,true,patrol,status)
            if not patrol:IsDispatchMenuOpen() and delta>0 and delta<=0.5 then resolvedTime=resolvedTime+delta end
            if resolvedTime>=20 or (actor and distance(Game.GetPlayer():GetWorldPosition(),actor:GetWorldPosition())>80) then cleanup(status) end
            return
        end
        if patrol:IsDispatchMenuOpen() then HUD.set("",false);return end
        if delta<=0 or delta>0.5 then return end
        if stage==2 and lastStage~=2 then
            phase="transport";waypoint(patrol,destination)
            notify(patrol,"Witness aboard. Delivery destination assigned. Keep moving and protect your passenger.")
            report("Objective 2 active after confirmed boarding",status)
        end
        lastStage=stage
        local vehicle=Game.GetMountedVehicle(Game.GetPlayer())
        local validTransport=stage==2 and actor and same(Game.GetMountedVehicle(actor),car) and same(vehicle,car) and backend:CanUseVehicle(car)
        local near=destination and distance(Game.GetPlayer():GetWorldPosition(),destination)<180
        Ambush.update(delta,validTransport and car or nil,stage==2,near,patrol,status)
        local point=stage==2 and destination or pickup
        local seconds=backend:GetRemainingSeconds()
        HUD.set("NCPD VIP TRANSPORT\n"..(stage==2 and "Deliver the witness" or "Collect the protected witness")
            .." - "..tostring(math.floor(distance(Game.GetPlayer():GetWorldPosition(),point))).." m\n"..backend:GetReason()
            ..string.format("\nTime remaining: %02d:%02d",math.floor(seconds/60),seconds%60),true)
        poll=poll+delta
        if poll>=0.25 then local step=poll;poll=0;physical(step,backend,patrol,status) end
    end)
    if not ok then
        M.finish(patrol,status,"VIP test failed: "..tostring(err),true)
        if patrol then notify(patrol,"Assignment closed. Check CET diagnostics.") end
        HUD.set("",false)
    end
    return M.isActive()
end
return M
