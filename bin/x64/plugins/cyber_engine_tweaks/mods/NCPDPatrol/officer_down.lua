-- One manual fixed-site rescue scene. Only IDs from our own CreateEntity calls
-- are removed. Journal/aid/protection/completion belong to the native owner.
local Site=require('officer_down_scene')
local Layout=require('officer_down_layout')
local Crew=require('officer_ai')
local M={}
local phase,label='idle','Officer Down test ready'
local heading,token,actors,elapsed,poll,retention=0,nil,{},0,0,0
local finalReason,terminalSeen,recovered=nil,false,false
local generation=nil
local placementElapsed,placementPoll,placementPasses,placementReason=0,0,0,nil
local selectedHeading=nil
local function native()
    local box=Game.GetScriptableSystemsContainer()
    local n=box and box:Get('NCPDPatrolOfficerDownSystem')
    if not n or n:Version()~=1 then error('Install the complete v0.18a Officer Down package and restart') end
    return n
end
local function origin() return Vector4.new(Site.x,Site.y,Site.z,1) end
local function distance(a,b) return math.sqrt((a.x-b.x)^2+(a.y-b.y)^2+(a.z-b.z)^2) end
local function report(text,status) label=text;if status then status('Officer Down | '..text) end end
local function deleteActors()
    local system=Game.GetDynamicEntitySystem()
    if not system or not system:IsReady() then return #actors==0 end
    local remaining={}
    for _,row in ipairs(actors) do
        local ok,gone=pcall(function()
            if system:IsManaged(row.id)==false then return true end
            return system:DeleteEntity(row.id)==true and system:IsManaged(row.id)==false
        end)
        if not ok or not gone then remaining[#remaining+1]=row end
    end
    actors=remaining
    return #actors==0
end
function M.state() return label end
function M.isActive() return phase~='idle' and phase~='aftermath' end
function M.hasCleanup() return phase=='cleanup' or phase=='aftermath' end
function M.lifecycle() return {phase=phase,assignment=M.isActive() and phase~='cleanup',reserved=M.isActive(),foregroundCleanup=phase=='cleanup',backgroundCleanup=phase=='aftermath'} end
function M.heading() return heading end
function M.rotate(status)
    if phase~='idle' then report('Clear the current Officer Down scene before changing rotation',status);return false end
    heading=(heading+90)%360;report('Next scene heading: '..heading..' degrees',status);return true
end
function M.reset()
    phase,label='idle','Officer Down test ready';token,actors=nil,{}
    elapsed,poll,retention=0,0,0;finalReason,terminalSeen,recovered=nil,false,false
    placementElapsed,placementPoll,placementPasses,placementReason=0,0,0,nil
    selectedHeading=nil
    generation=nil
end
function M.diagnostics()
    local ok,text=pcall(function() return native():GetDiagnostics() end)
    return 'phase='..phase..' | site=test_kryss_01 | heading='..tostring(selectedHeading or heading)..' | preferred heading='..heading..' | owned actors='..#actors
        ..' | placement passes='..placementPasses..' | nearby wait='..string.format('%.1f',placementElapsed)..'/'..Site.prepareGrace..' s'
        ..' | placement='..tostring(placementReason or 'not attempted')..' | '..tostring(ok and text or text)
end
function M.revive(status)
    local ok,result=pcall(function() return native():StartRevive() end)
    if status then status('Officer Down | '..(ok and result and 'Revive started; remain within 2.5 m for 3 seconds' or 'Approach the injured officer on scene to revive')) end
    return ok and result==true
end
function M.finish(patrol,status,reason,failed)
    local checked,ready,current=pcall(function() local n=native();return n:IsSessionReady(),n:GetSessionGeneration() end)
    if checked and (not ready or (generation and current~=generation)) then M.reset();return true end
    if not checked and #actors>0 then phase='cleanup';report('Native scene module unavailable; cleanup pending',status);return false end
    if token then pcall(function() if failed then native():Fail(token,reason or 'Scene failed') else native():Cancel(token,reason or 'Assignment cancelled') end end) end
    finalReason=reason or 'Officer Down scene cleared';phase='cleanup';poll=0
    if deleteActors() then phase='idle';token=nil;report(finalReason,status);return true end
    report(finalReason..'; actor cleanup pending',status);return false
end
function M.cancel(patrol,status) if phase=='idle' then return false end;return M.finish(patrol,status,'Officer Down cancelled/cleared') end
function M.request(patrol,status,sound,voice)
    if phase~='idle' then report('Previous Officer Down scene still present; clear it or leave the area',status);return false end
    local ok,err=pcall(function()
        local p=Game.GetPlayer()
        if not p or not p:IsAttached() or p:IsDead() or not patrol or not patrol:IsOnDuty() or patrol:HasWantedLevel() then error('An active, non-wanted shift is required') end
        if patrol:IsDispatchMenuOpen() or p:IsInCombat() then error('Leave game menus and combat before testing') end
        local d=distance(p:GetWorldPosition(),origin())
        if d<100 or d>5000 then error('Request this fixed-site test from 100-5000 m away') end
        local backend=native();backend:Tick(0)
        if not backend:IsReady() then error('Officer Down journal/archive unavailable') end
        local entities=Game.GetDynamicEntitySystem()
        if not entities or not entities:IsReady() then error('Codeware entity system unavailable') end
        token=backend:BeginDispatch()
        if not token or token<=0 then token=nil;error('Officer Down quest request rejected') end
        generation=backend:GetSessionGeneration()
        phase,elapsed,poll='responding',0,0;terminalSeen,recovered=false,false
        placementElapsed,placementPoll,placementPasses,placementReason=0,Site.prepareInterval,0,nil
        selectedHeading=nil
        patrol:NotifyDispatch('NCPD DISPATCH: Officer down. Patrol pinned behind a police vehicle. Respond, neutralize the suspects and revive the injured officer. Backup available.',10,sound,voice)
        report('Assigned: TEST_KRYSS_01 | heading='..heading..' degrees | distance='..math.floor(d)..' m',status)
    end)
    if not ok then
        if token or #actors>0 then M.finish(patrol,status,'Scene setup failed: '..tostring(err),true) else report('Request failed: '..tostring(err),status) end
    end
    return ok
end
local function createScene(backend,status)
    local layout,selected,reason,tries=Layout.choose(heading,Game.GetPlayer())
    placementPasses=placementPasses+1
    placementReason=reason
    if not layout then return false end
    local entities=Game.GetDynamicEntitySystem()
    for _,row in ipairs(layout) do
        if not TweakDB:GetRecord(TweakDBID.new(row.record)) then error('Missing private scene record: '..row.record) end
    end
    selectedHeading=selected
    placementReason='Selected '..selected..' degrees after '..tries..' rotation checks'
    report(placementReason,status)
    for _,row in ipairs(layout) do
        local spec=DynamicEntitySpec.new()
        spec.recordID=TweakDBID.new(row.record);spec.position=row.position;spec.orientation=backend:Orientation(row.yaw)
        spec.persistState,spec.persistSpawn,spec.alwaysSpawned=false,false,false;spec.spawnInView,spec.active=true,true
        local id=entities:CreateEntity(spec)
        if not id or not EntityID.IsDefined(id) then error('Scene actor creation rejected: '..row.kind) end
        row.id=id;actors[#actors+1]=row
    end
    phase,elapsed='spawning',0
    return true
end
local function prepare(backend)
    local entities=Game.GetDynamicEntitySystem()
    local ready=true
    for _,row in ipairs(actors) do
        if not row.bound then
            local actor=entities:GetEntity(row.id)
            if not actor or not actor:IsAttached() then ready=false else
                if entities:IsManaged(row.id)~=true or actor:GetRecordID()~=TweakDBID.new(row.record) then error('Scene actor identity mismatch') end
                local p=actor:GetWorldPosition()
                if distance(p,row.position)>1.5 then error('Scene actor attached at an unexpected road level/position') end
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
local function lock(backend)
    for _,row in ipairs(actors) do
        if row.actor and row.actor:IsAttached() then
            local p=row.actor:GetWorldPosition()
            if (p.x-row.position.x)^2+(p.y-row.position.y)^2>.25 or math.abs(p.z-row.position.z)>1 then
                if not backend:LockPosition(row.actor,row.position,row.yaw) then error('Pre-arrival position lock rejected') end
            end
            if row.car then row.actor:ForceBrakesUntilStoppedOrFor(1) end
        end
    end
end
local function release(backend)
    for _,row in ipairs(actors) do
        if row.command then row.actor:GetAIControllerComponent():StopExecutingCommand(row.command,false);row.command=nil end
        if row.kind=='defender' or row.kind=='injured' then Crew.friendly(row.actor) end
    end
    if not backend:Activate(token) then error('Scene activation rejected') end
    phase,elapsed='active',0
end
local function update(delta,onDuty,patrol,status,HUD)
    if phase=='idle' then
        -- Only restore the new journal when its native module exists.
        pcall(function() native():Tick(delta) end);return false
    end
    local player=Game.GetPlayer()
    if not player or not player:IsAttached() then return M.isActive() end
    local backend=native()
    if not backend:IsSessionReady() then return M.isActive() end
    if generation and backend:GetSessionGeneration()~=generation then M.reset();return false end
    if phase=='aftermath' then
        if delta>0 and delta<=.5 and (not patrol or not patrol:IsDispatchMenuOpen()) then retention=retention+delta;poll=poll+delta end
        if (not onDuty or retention>=Site.retainSeconds or distance(player:GetWorldPosition(),origin())>Site.retainDistance) and poll>=1 then
            poll=0;if deleteActors() then phase='idle';token=nil end
        end
        return false
    end
    if phase=='cleanup' then
        if delta>0 and delta<=.5 then poll=poll+delta end
        if poll>=1 then poll=0;if deleteActors() then phase='idle';token=nil;report(finalReason or 'Scene cleared',status) end end
        return M.isActive()
    end
    backend:Tick(delta)
    if not onDuty or not patrol or not patrol:IsOnDuty() then M.finish(patrol,status,'Shift ended',false);return M.isActive() end
    if backend:GetToken()~=token then M.finish(patrol,status,'Officer Down session superseded');return M.isActive() end
    local stage=backend:GetStage()
    if stage>=3 then
        if not terminalSeen then
            terminalSeen=true
            patrol:NotifyDispatch('NCPD OFFICER DOWN: '..backend:GetReason(),10)
            report((stage==3 and 'COMPLETED | ' or 'CLOSED | ')..backend:GetReason(),status)
        end
        HUD.set('',false)
        if stage==3 then phase,retention,poll='aftermath',0,0;return false end
        M.finish(patrol,status,backend:GetReason());return M.isActive()
    end
    if patrol:IsDispatchMenuOpen() then HUD.set('',false);return true end
    if delta<=0 or delta>.5 then return true end
    elapsed,poll=elapsed+delta,poll+delta
    local d=distance(player:GetWorldPosition(),origin())
    if phase=='responding' and d<=Site.prepare then
        placementPoll=placementPoll+delta
        if d<=Site.prepareNear then placementElapsed=placementElapsed+delta end
        if placementPoll>=Site.prepareInterval or placementElapsed>=Site.prepareGrace then
            placementPoll=0
            if not createScene(backend,status) then
                if placementElapsed>=Site.prepareGrace then
                    error('All four scene rotations rejected after '..placementPasses..' placement passes | '..tostring(placementReason))
                end
                if placementPasses==1 then report('Waiting for supported, unoccupied scene layout; automatic rotations/retry pending',status) end
            end
        end
    end
    if poll>=.25 then
        poll=0
        if phase=='spawning' then
            if prepare(backend) then phase,elapsed='staged',0;report('Scene protected and held; awaiting arrival',status)
            elseif elapsed>=15 then error('Scene attachment/protection timed out') end
        end
        if phase=='staged' then
            lock(backend)
            if d<=Site.arrival then release(backend);patrol:NotifyDispatch('NCPD: On scene. Secure the area and revive the injured officer.',5);report('On scene: five suspects and one injured officer',status) end
        end
    end
    if phase=='active' and not recovered and backend:GetAidState()==1 then
        recovered=true;patrol:NotifyDispatch('NCPD: Officer revived. Finish securing the scene.',7)
        for _,row in ipairs(actors) do if row.kind=='injured' then Crew.friendly(row.actor) end end
    end
    local seconds=backend:GetRemainingSeconds()
    HUD.set('NCPD OFFICER DOWN\n'..(stage==1 and 'Respond to the patrol' or 'Secure the scene and revive the officer')
        ..' - '..math.floor(d)..' m\nSuspects remaining: '..backend:GetRemainingEnemies()
        ..' | Officer: '..(backend:GetAidState()==1 and 'REVIVED' or 'NEEDS AID')
        ..string.format('\nTime remaining: %02d:%02d',math.floor(seconds/60),seconds%60),true)
    return true
end
function M.update(delta,onDuty,patrol,status,HUD)
    local ok,result=pcall(update,delta,onDuty,patrol,status,HUD)
    if ok then return result end
    if phase~='idle' and phase~='cleanup' then
        M.finish(patrol,status,'Officer Down failed: '..tostring(result),true)
        if patrol then patrol:NotifyDispatch('NCPD: Officer Down scene could not be prepared. Check scene diagnostics; automatic placement could not finish.',8) end
    end
    if HUD then pcall(function() HUD.set('',false) end) end
    return M.isActive()
end
return M
