-- One manual fixed-site rescue scene. Only IDs from our own CreateEntity calls
-- are removed. Journal/aid/protection/completion belong to the native owner.
local Site=require('officer_down_scene')
local Layout=require('officer_down_layout')
local Crew=require('officer_ai')
local Actors=require('officer_down_actors')
local Catalog=require('officer_down_sites')
local Selection=require('officer_down_selection')
local Log=require('officer_down_log')
local Functional=require('scene_survey_functional')
local M={}
local phase,label='idle','Officer Down test ready'
local heading,token,actors,elapsed,poll,retention=0,nil,{},0,0,0
local finalReason,terminalSeen,recovered=nil,false,false
local generation=nil
local placementElapsed,placementPoll,placementPasses,placementReason=0,0,0,nil
local selectedHeading=nil
local selectedSite,catalogMode,logRun=nil,false,nil
local draining,sceneAge,access,readyLogged,cleanupAge={},0,nil,false,0
local cleanupWarned,aftermathCleanupStarted=false,false
local markerLogged=false
local function native()
    local box=Game.GetScriptableSystemsContainer()
    local n=box and box:Get('NCPDPatrolOfficerDownSystem')
    if not n or n:Version()~=1 then error('Install the complete v0.18a Officer Down package and restart') end
    return n
end
local function origin() local s=selectedSite or Site;return Vector4.new(s.x,s.y,s.z,1) end
local function distance(a,b) return math.sqrt((a.x-b.x)^2+(a.y-b.y)^2+(a.z-b.z)^2) end
local function report(text,status) label=text;if status then status('Officer Down | '..text) end end
local function log(kind,details,status) if catalogMode then Log.event(logRun,selectedSite,kind,details,status) end end
local function playerPosition()
    local ok,p=pcall(function() local v=Game.GetPlayer():GetWorldPosition();return {x=v.x,y=v.y,z=v.z} end)
    return ok and p or nil
end
local function nativeDiagnostics()
    local ok,value=pcall(function() return native():GetDiagnostics() end)
    return ok and value or tostring(value)
end
local function snapshot()
    local result={}
    for _,row in ipairs(actors) do
        local value={kind=row.kind,bound=row.bound==true}
        pcall(function()
            local idOK,id=pcall(function() return tostring(row.id.hash) end)
            value.id=idOK and id or tostring(row.id)
            if row.position then value.expected={x=row.position.x,y=row.position.y,z=row.position.z} end
            local actor=row.actor or Game.GetDynamicEntitySystem():GetEntity(row.id)
            if actor and actor:IsAttached() then
                local p=actor:GetWorldPosition();value.actual={x=p.x,y=p.y,z=p.z}
                if not row.car then value.dead=actor:IsDead() end
            end
        end)
        result[#result+1]=value
    end
    return result
end
local function deleteActors()
    if catalogMode then
        for _,row in ipairs(actors) do
            if not row.drainCaptured then
                local object=row.actor or Game.GetDynamicEntitySystem():GetEntity(row.id)
                if object then
                    if not native():CacheCreatedObject(object) then error('Native Officer Down cleanup handle tracking refused') end
                    draining[#draining+1]=object;row.drainCaptured=true
                end
            end
        end
    end
    actors=Actors.remove(actors)
    if #actors>0 then return false end
    for _,object in ipairs(draining) do
        local ok,attached=pcall(function() return object:IsAttached() end)
        if ok and attached then return false end
    end
    if catalogMode then
        if not native():ClearCreatedIDs() then return false end
        log('cleanup_confirmed',{retained_handles=#draining})
        draining={}
    end
    return true
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
    if phase~='idle' and not terminalSeen then log('interrupted',{phase=phase,reason='World/session changed; old IDs forgotten'}) end
    phase,label='idle','Officer Down test ready';token,actors=nil,{}
    elapsed,poll,retention=0,0,0;finalReason,terminalSeen,recovered=nil,false,false
    placementElapsed,placementPoll,placementPasses,placementReason=0,0,0,nil
    selectedHeading=nil
    generation=nil
    selectedSite,catalogMode,logRun=nil,false,nil;draining,sceneAge,access,readyLogged,cleanupAge={},0,nil,false,0
    cleanupWarned,aftermathCleanupStarted,markerLogged=false,false,false
    Selection.reset()
end
function M.diagnostics()
    local ok,text=pcall(function() return native():GetDiagnostics() end)
    return 'phase='..phase..' | site='..tostring(selectedSite and selectedSite.id or 'test_kryss_01')..' | heading='..tostring(selectedHeading or heading)..' | preferred heading='..tostring(selectedSite and selectedSite.heading or heading)..' | owned actors='..#actors
        ..' | placement passes='..placementPasses..' | nearby wait='..string.format('%.1f',placementElapsed)..'/'..Site.prepareGrace..' s'
        ..' | selected site='..tostring(selectedSite and selectedSite.id or 'test_kryss_01')..' | catalogue='..tostring(catalogMode)
        ..' | retained handles='..#draining..' | access ready seconds='..tostring(access and access.stable or 0)
        ..' | placement='..tostring(placementReason or 'not attempted')..' | '..tostring(ok and text or text)
end
function M.supportsCatalog()
    local ok,ready=pcall(function() local n=native();return n:CatalogVersion()==1 and n:IsCatalogReady() end)
    return ok and ready==true
end
function M.logState() return Log.state() end
function M.exportLog(status) return Log.export(status) end
function M.revive(status)
    local ok,result=pcall(function() return native():StartRevive() end)
    if ok and result then log('revive_started',{token=token},status) end
    if status then status('Officer Down | '..(ok and result and 'Revive started; remain within 2.5 m for 3 seconds' or 'Approach the injured officer on scene to revive')) end
    return ok and result==true
end
function M.finish(patrol,status,reason,failed)
    local checked,ready,current=pcall(function() local n=native();return n:IsSessionReady(),n:GetSessionGeneration() end)
    if checked and (not ready or (generation and current~=generation)) then M.reset();return true end
    if not checked and #actors>0 then phase='cleanup';report('Native scene module unavailable; cleanup pending',status);return false end
    if token then pcall(function() if failed then native():Fail(token,reason or 'Scene failed') else native():Cancel(token,reason or 'Assignment cancelled') end end) end
    if not terminalSeen then
        log(failed and 'failed' or 'cancelled',{reason=reason or 'Scene closed',phase=phase,actors=snapshot(),player_position=playerPosition(),native=nativeDiagnostics()},status)
        terminalSeen=true
        if failed and selectedSite then Selection.block(selectedSite.id) end
    end
    log('cleanup_requested',{reason=reason,actors=#actors,phase=phase},status)
    finalReason=reason or 'Officer Down scene cleared';phase='cleanup';poll=0;cleanupAge=0;cleanupWarned=false
    if deleteActors() then phase='idle';token=nil;report(finalReason,status);return true end
    report(finalReason..'; actor cleanup pending',status);return false
end
function M.cancel(patrol,status) if phase=='idle' then return false end;return M.finish(patrol,status,'Officer Down cancelled/cleared') end
function M.request(patrol,status,sound,voice)
    if phase~='idle' then report('Previous Officer Down scene still present; clear it or leave the area',status);return false end
    selectedSite,catalogMode,logRun=nil,false,nil;draining={}
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
function M.requestNearby(patrol,status,sound,voice,source)
    if phase~='idle' then return false end
    local ok,reason=pcall(function()
        local player=Game.GetPlayer()
        if not player or not player:IsAttached() or player:IsDead() or not patrol or not patrol:IsOnDuty() or patrol:HasWantedLevel()
            or patrol:IsDispatchMenuOpen() or player:IsInCombat() then error('An available, non-wanted shift outside menus/combat is required') end
        local backend=native();backend:Tick(0)
        local compatible,ready=pcall(function() return backend:CatalogVersion()==1 and backend:IsCatalogReady() end)
        if not compatible or not ready then error('Install the complete v0.18c Officer Down dispatch package and restart') end
        local system=Game.GetDynamicEntitySystem();if not system or not system:IsReady() then error('Codeware entity system unavailable') end
        local site,d,radius,why=Selection.choose(player:GetWorldPosition())
        if not site then report(why,status);return false end
        local accepted=backend:BeginCatalogDispatch(site.index)
        if not accepted or accepted<=0 then report('Officer Down quest/cleanup reservation unavailable',status);return false end
        selectedSite,catalogMode,token=site,true,accepted;logRun=Log.newRun()
        generation=backend:GetSessionGeneration();phase,elapsed,poll='responding',0,0
        terminalSeen,recovered=false,false;actors,draining={},{}
        placementElapsed,placementPoll,placementPasses,placementReason=0,Site.prepareInterval,0,nil
        selectedHeading,sceneAge,access,readyLogged,cleanupAge=nil,0,nil,false,0;cleanupWarned,aftermathCleanupStarted,markerLogged=false,false,false
        Selection.remember(site.id)
        log('assigned',{source=source or 'manual',token=token,generation=generation,heading=site.heading,
            position={x=site.x,y=site.y,z=site.z},distance=d,search_radius=radius,selection=why,player_position=playerPosition()},status)
        patrol:NotifyDispatch('NCPD DISPATCH: Officer down. Patrol under fire. Secure the scene and revive the injured officer. Backup available.',10,sound,voice)
        report('Assigned: '..site.label..' | distance='..math.floor(d)..' m | search radius='..radius..' m',status)
        return true
    end)
    if not ok then
        if token or #actors>0 then M.finish(patrol,status,'Officer Down setup failed: '..tostring(reason),true)
        else report('Request failed: '..tostring(reason),status) end
        return false
    end
    return reason==true
end
local function createScene(backend,status)
    local layout,selected,reason,tries=Layout.choose(selectedSite and selectedSite.heading or heading,Game.GetPlayer(),{variant='compact',site=selectedSite or Site})
    placementPasses=placementPasses+1
    placementReason=reason
    log('placement_checked',{pass=placementPasses,reason=reason,selected_heading=selected,rotations_checked=tries},status)
    if not layout then return false end
    Actors.create(layout,backend,actors,catalogMode and function(row)
        if not backend:TrackCreatedID(token,row.id) then error('Native Officer Down actor ID tracking refused') end
    end or nil)
    selectedHeading=selected
    placementReason='Selected '..selected..' degrees after '..tries..' rotation checks | layout=compact'
    report(placementReason,status)
    phase,elapsed='spawning',0
    log('spawn_created',{heading=selectedHeading,actors=snapshot()},status)
    return true
end
local function prepare(backend) return Actors.prepare(actors,backend) end
local function lock(backend) return Actors.lock(actors,backend,catalogMode and {freeInjured=true} or nil) end
local function release(backend)
    for _,row in ipairs(actors) do
        if row.command then row.actor:GetAIControllerComponent():StopExecutingCommand(row.command,false);row.command=nil end
        if row.kind=='defender' or row.kind=='injured' then Crew.friendly(row.actor) end
    end
    if not backend:Activate(token) then error('Scene activation rejected') end
    phase,elapsed='active',0
    log('arrived',{heading=selectedHeading,actors=snapshot(),functional=access and access.proof,player_position=playerPosition()})
end
local function recoverPending(backend,status)
    local count=backend:GetCreatedCount()
    if backend:GetCreatedGeneration()~=backend:GetSessionGeneration() then return false end
    if count==0 then
        if backend:GetCatalogIndex()>0 and (backend:GetStage()==1 or backend:GetStage()==2) then
            backend:Cancel(backend:GetToken(),'Interrupted CET dispatch before scene creation')
        end
        return false
    end
    local index=backend:GetCatalogIndex();selectedSite=nil
    for _,site in ipairs(Catalog.sites) do if site.index==index then selectedSite=site end end
    catalogMode=true;logRun=Log.newRun();token=backend:GetToken();generation=backend:GetSessionGeneration()
    actors,draining={},{}
    for i=0,count-1 do
        local id=backend:GetCreatedID(i)
        if not EntityID.IsDefined(id) then error('Invalid native Officer Down recovery ID') end
        actors[#actors+1]={id=id,actor=backend:GetCreatedObject(i)}
    end
    backend:Cancel(token,'Interrupted CET session; pending Officer Down actors recovered')
    terminalSeen=true;phase,poll,cleanupAge='cleanup',1,0;cleanupWarned=false
    finalReason='Interrupted Officer Down cleanup recovered'
    log('recovered_cleanup',{token=token,actors=count,generation=generation},status)
    report(finalReason,status)
    return true
end
local function update(delta,onDuty,patrol,status,HUD)
    if phase=='idle' then
        -- Only restore the new journal when its native module exists.
        local ok,restored=pcall(function()
            local n=native();n:Tick(delta)
            if n:IsSessionReady() and patrol and not patrol:IsDispatchMenuOpen() and onDuty then Selection.advance(delta) end
            return recoverPending(n,status)
        end)
        return ok and restored==true
    end
    local player=Game.GetPlayer()
    if not player or not player:IsAttached() then return M.isActive() end
    local backend=native()
    if not backend:IsSessionReady() then return M.isActive() end
    if generation and backend:GetSessionGeneration()~=generation then M.reset();return false end
    if onDuty and (not patrol or not patrol:IsDispatchMenuOpen()) then Selection.advance(delta) end
    if phase=='aftermath' then
        if delta>0 and delta<=.5 and (not patrol or not patrol:IsDispatchMenuOpen()) then retention=retention+delta;poll=poll+delta end
        if (not onDuty or retention>=Site.retainSeconds or distance(player:GetWorldPosition(),origin())>Site.retainDistance) and poll>=1 then
            poll=0
            if not aftermathCleanupStarted then aftermathCleanupStarted=true;log('cleanup_requested',{reason='Aftermath retention ended',actors=#actors},status) end
            if deleteActors() then phase='idle';token=nil;access=nil end
        end
        return false
    end
    if phase=='cleanup' then
        if delta>0 and delta<=.5 then poll=poll+delta;cleanupAge=cleanupAge+delta end
        if poll>=1 then poll=0;if deleteActors() then phase='idle';token=nil;report(finalReason or 'Scene cleared',status) end end
        if phase=='cleanup' and cleanupAge>=15 and not cleanupWarned then
            cleanupWarned=true;log('cleanup_pending',{seconds=cleanupAge,managed_rows=#actors,retained_handles=#draining},status)
        end
        return M.isActive()
    end
    backend:Tick(delta)
    if not onDuty or not patrol or not patrol:IsOnDuty() then M.finish(patrol,status,'Shift ended',false);return M.isActive() end
    if backend:GetToken()~=token then M.finish(patrol,status,'Officer Down session superseded');return M.isActive() end
    local stage=backend:GetStage()
    if stage>=3 then
        if not terminalSeen then
            log(stage==3 and 'completed' or (stage==5 and 'cancelled' or 'failed'),
                {reason=backend:GetReason(),stage=stage,aid=backend:GetAidState(),enemies_remaining=backend:GetRemainingEnemies(),actors=snapshot(),player_position=playerPosition()},status)
            if stage~=3 and stage~=5 and selectedSite then Selection.block(selectedSite.id) end
            terminalSeen=true
            patrol:NotifyDispatch('NCPD OFFICER DOWN: '..backend:GetReason(),10)
            report((stage==3 and 'COMPLETED | ' or 'CLOSED | ')..backend:GetReason(),status)
        end
        HUD.set('',false)
        if stage==3 then phase,retention,poll='aftermath',0,0;aftermathCleanupStarted=false;return false end
        M.finish(patrol,status,backend:GetReason());return M.isActive()
    end
    if patrol:IsDispatchMenuOpen() then HUD.set('',false);return true end
    if delta<=0 or delta>.5 then return true end
    elapsed,poll=elapsed+delta,poll+delta
    if catalogMode and not markerLogged and elapsed>=1 then
        markerLogged=true;log('marker_observed',{native=nativeDiagnostics(),player_position=playerPosition()},status)
    end
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
        local sampled=poll;poll=0
        if phase=='spawning' then
            if prepare(backend) then
                phase,elapsed='staged',0;sceneAge=0;access=catalogMode and Functional.new(backend,selectedSite) or nil
                sampled=0
                if access then access:noteBound(actors,0) end
                report('Scene protected and held; awaiting arrival',status)
                log('actors_bound',{actors=snapshot()},status)
            elseif elapsed>=15 then error('Scene attachment/protection timed out') end
        end
        if phase=='staged' then
            lock(backend)
            local usable=true
            if catalogMode then
                -- Use active elapsed time, including real frame/poll jitter.
                -- The injured actor is never locked back to its spawn point.
                sceneAge=sceneAge+sampled
                local measured,reason=access:frame(actors,sampled,sceneAge<=Functional.settleSeconds)
                if not measured then error(reason) end
                usable=access.stable>=Functional.observeSeconds
                if usable and not readyLogged then readyLogged=true;log('ready',{functional=access.proof,actors=snapshot()},status) end
                if not usable and sceneAge>=Functional.settleSeconds+Functional.timeoutSeconds then error(access.reason or 'No safe, reachable injured aid position') end
            end
            if usable and d<=Site.arrival then release(backend);patrol:NotifyDispatch('NCPD: On scene. Secure the area and revive the injured officer.',5);report('On scene: five suspects and one injured officer',status) end
        end
    end
    if phase=='active' and not recovered and backend:GetAidState()==1 then
        recovered=true;patrol:NotifyDispatch('NCPD: Officer revived. Finish securing the scene.',7)
        log('revived',{actors=snapshot()},status)
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
