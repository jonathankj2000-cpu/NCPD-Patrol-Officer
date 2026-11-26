-- Explicit off-duty test tour. One owned scene at a time; never starts a quest.
local DefaultCatalog=require('scene_survey_sites')
local Layout=require('officer_down_layout')
local Actors=require('officer_down_actors')
local DefaultStore=require('scene_survey_store')
local Settling=require('scene_survey_settling')
local Staging=require('scene_survey_staging')
local Functional=require('scene_survey_functional')
local function createRunner(Catalog,Store,discovery)
local M={}
local context,storage={},Store.new()
local phase,label='idle','Survey not started. '..Catalog.coverage
local backend,generation,origin,run,site,variant
local queue,index,actors,draining={},0,{},{}
local angles,angleIndex,pass,failures={},1,1,{}
local clock,poll,stable,observedMax=0,0,0,0
local heading,samples,pending,afterCleanup,stopReason,lastError
local done,passed=0,0
local moved=false
local anchor=nil
local discoveryStage=nil
local loggedStop=nil
local discoveryScope=nil
local profile=Functional.profile
local pilotState=nil
local function point(p) return Vector4.new(p.x,p.y,p.z,1) end
local function copy(p) return {x=p.x,y=p.y,z=p.z} end
local function distance(a,b) return math.sqrt((a.x-b.x)^2+(a.y-b.y)^2+(a.z-b.z)^2) end
local function native()
    local box=Game.GetScriptableSystemsContainer()
    local owner=box and box:Get('NCPDPatrolSceneSurveySystem')
    if not owner or owner:Version()~=1 then error('Install the complete v0.18b scene survey package and restart the game') end
    return owner
end
local function say(text,status)
    label=text
    local callback=status or context.status
    if callback then callback('Scene survey | '..text) end
end
local function enter(nextPhase) phase=nextPhase;clock,poll,stable=0,0,0 end
local function evidence(row)
    row.run=run;row.catalog_revision=Catalog.revision;row.layout_revision=Layout.revision;row.validation_profile=profile
    if discovery and anchor then row.source_anchor=anchor.id end
    storage:append(row)
end
local function trialEvent(kind,reason)
    evidence({kind=kind,site=site and site.id,variant=variant,heading=heading,phase=phase,reason=reason})
end
local function siteResult(status,reason)
    return {kind='site_result',site=site.id,label=site.label,position=copy(site),variant=variant,
        status=status,heading=heading,reason=reason,failures=failures,samples=samples,
        observed_seconds=stable,max_displacement=observedMax,cleanup_confirmed=true,
        injured_transition_peak_displacement=pilotState and pilotState.peak or nil,
        pilot_settling_seconds=pilotState and Settling.settleSeconds or nil,
        maximum_observation_drift=pilotState and pilotState.maxDrift or nil,
        placement_corrections=profile==Staging.profile and pilotState and pilotState.corrections or nil,
        placement_release_seconds=profile==Staging.profile and Staging.releaseSeconds or nil,
        functional_validation=profile==Functional.profile and pilotState and pilotState.proof or nil}
end
local function captureDrain()
    for _,row in ipairs(actors) do
        if not row.drainCaptured then
            local object=row.actor
            if not object then
                local system=Game.GetDynamicEntitySystem()
                if system and system:IsReady() then object=system:GetEntity(row.id) end
            end
            if object then draining[#draining+1]=object;row.drainCaptured=true end
        end
    end
end
local function detached()
    for _,object in ipairs(draining) do
        local ok,attached=pcall(function() return object:IsAttached() end)
        if ok and attached then return false end
    end
    return true
end
local function cleanup(action)
    if discovery and (action=='return' or action=='finish-here') and loggedStop~=stopReason then
        loggedStop=stopReason
        pcall(function() evidence({kind='stop_requested',reason=stopReason or 'Return requested',site=site and site.id,
            variant=variant,phase=phase,pair_index=index,completed_pairs=done,queued_pairs=#queue}) end)
    end
    afterCleanup=action
    captureDrain()
    enter('cleanup')
end
local function rejectTrial(reason)
    failures[#failures+1]={heading=heading,pass=pass,phase=phase,reason=tostring(reason)}
    trialEvent('trial_failed',tostring(reason))
    say(site.label..' | '..variant..' | heading='..string.format('%.3f',heading)..' | '..tostring(reason))
    pending=nil
    cleanup('next-angle')
end
local function resultAndNext(row)
    row.cleanup_confirmed=true;evidence(row)
    done=done+1;if row.status=='validated' then passed=passed+1 end
    say(site.label..' | '..row.status..' | '..tostring(row.reason)..' | completed='..done..'/'..#queue)
    pending=nil
    enter('between-sites')
end
local function advanceAngle()
    if discovery then
        site=anchor;samples=nil;observedMax=0;pilotState=nil
        if not discoveryStage or not backend:SetOrigin(point(discoveryStage))
            or not backend:MovePlayer(point(discoveryStage),discoveryStage.heading) then error('Discovery staging return refused') end
        enter('discovery-stage-landing');return
    end
    angleIndex=angleIndex+1
    if angleIndex>#angles then
        if pass<2 then pass=pass+1;angleIndex=1
        else resultAndNext(siteResult('unverified','No complete stable placement after two passes; see per-heading failures'));return end
    end
    heading=angles[angleIndex];samples=nil;observedMax=0;pilotState=nil
    enter('preflight')
end
local function finishRun(returned)
    local saved,saveError=pcall(function()
        evidence({kind='run_finished',reason=stopReason or 'Tour complete',returned_to_origin=returned~=false,completed=done,validated=passed,queued=#queue})
    end)
    if not backend:Finish() then error('Survey protection release refused') end
    enter('idle');backend=nil;actors,draining={},{}
    if discovery then
        local ok,reason=pcall(function() return storage:export(profile) end)
        if not ok then saveError=reason;saved=false end
    end
    say((stopReason or 'Tour complete')..' | validated='..passed..'/'..done..(returned==false and ' | stopped without a return teleport' or ' | returned to starting position')
        ..(saved and (' | evidence='..Store.logFile) or (' | evidence write failed: '..tostring(saveError))))
end
function M.configure(value) context=value or {} end
function M.active() return phase~='idle' end
function M.blocksDuty()
    if M.active() then return true end
    local ok,active=pcall(function() return native():IsActive() end)
    return ok and active==true
end
function M.summary()
    local total=tostring(#Catalog.sites)
    return label..'\nPhase: '..phase..' | '..Catalog.coverage
        ..' | functional compact='..storage:count('compact',Functional.profile)..'/'..total..' | functional standard='..storage:count('standard',Functional.profile)..'/'..total
        ..' | proven compact='..storage:count('compact')..'/'..total..' | proven standard='..storage:count('standard')..'/'..total
        ..(discovery and (' | terminal/layout pairs completed='..done..'/'..#queue..' | current pair='..index) or '')
        ..(discovery and '' or (' | settling pilot='..storage:count('compact',Settling.profile)..'/3'
        ..' | placement pilot='..storage:count('compact',Staging.profile)..'/3'))
end
function M.diagnostics()
    return M.summary()..' | site='..tostring(site and site.id)..' | variant='..tostring(variant)..' | heading='..tostring(heading)
        ..' | owned IDs='..#actors..' | retained handles='..#draining..' | seconds='..string.format('%.2f',clock)..' | stop='..tostring(stopReason)
        ..(discovery and (' | '..discovery:progress()) or '')
end
function M.loadResults(status)
    local ok,reason=pcall(function() storage:load();return 'Saved evidence loaded; incompatible/truncated lines='..storage.ignored end)
    say(ok and reason or tostring(reason),status);return ok
end
function M.export(status)
    local ok,name=pcall(function() return storage:export(profile) end)
    say(ok and ('Report exported to '..name..' inside the NCPDPatrol CET folder') or tostring(name),status)
    return ok
end
function M.start(requestedVariant,onlyUnverified,status,pilot)
    if M.active() then say('A survey is already running; stop/return before starting another',status);return false end
    local ok,reason=pcall(function()
        if requestedVariant~='compact' and requestedVariant~='standard' and not (discovery and requestedVariant=='both') then error('Unknown survey layout') end
        if context.canStart then local allowed,why=context.canStart();if not allowed then error(why or 'Existing patrol actors/dispatch still active') end end
        local owner=native()
        if discovery then
            if owner:DiscoveryVersion()~=1 or owner:FunctionalVersion()~=1 then error('Install the complete v0.18g Scene Discovery package and fully restart') end
        end
        if pilot=='staging' then
            local compatible,version=pcall(function() return owner:PlacementVersion() end)
            if not compatible or version~=1 then error('Install the complete v0.18b2 Injured Placement Pilot package and fully restart the game') end
        end
        if pilot=='functional' then
            local compatible,version=pcall(function() return owner:FunctionalVersion() end)
            if not compatible or version~=1 then error('Install the complete v0.18b3 Functional Scene Survey package and fully restart the game') end
        end
        if owner:IsActive() then error('Previous CET session left a survey reserved; use Recover survey cleanup and return') end
        if not owner:CanRun() or owner:IsMenuOpen() then error('Load a manual test save, go OFF DUTY, leave combat/menus and exit your vehicle') end
        storage:load();queue={}
        profile=(discovery or pilot=='functional') and Functional.profile or (pilot=='staging' and Staging.profile or (pilot and Settling.profile or 'legacy-immediate-v1'));pilotState=nil
        if discovery then queue=discovery:queue(requestedVariant,onlyUnverified,discoveryScope) end
        for _,candidate in ipairs(discovery and {} or Catalog.sites) do
            if pilot==true or pilot=='staging' then
                if Settling.pilotSites[candidate.id] then queue[#queue+1]=candidate end
            elseif not onlyUnverified or storage:needsTest(candidate,requestedVariant,profile) then queue[#queue+1]=candidate end
        end
        if #queue==0 then say('All '..#Catalog.sites..' sites already have a successful latest test for '..requestedVariant,status);return false end
        variant=requestedVariant;index=1;done,passed=0,0;actors,draining={},{}
        stopReason,lastError,pending=nil,nil,nil;moved=false
        anchor,discoveryStage,loggedStop=nil,nil,nil
        run=((os and os.date) and os.date('!%Y%m%dT%H%M%S') or 'run')..'-'..(#storage.events+1)
        evidence({kind='run_started',variant=variant,queued=#queue,coverage=Catalog.coverage})
        local began
        if discovery then began=owner:BeginDiscovery()
        elseif profile==Staging.profile then began=owner:BeginPlacement() else began=owner:Begin() end
        if not began then error('Native survey protection/reservation refused') end
        backend=owner;generation=owner:GetRunGeneration()
        local p=owner:GetReturnPosition();origin=copy(p);origin.heading=owner:GetReturnYaw()
        enter('travel')
        say('Started '..variant..' | '..#queue..(discovery and ' terminal/layout pairs' or ' sites')..' | automatic movement; close CET and leave the game running',status)
        return true
    end)
    if not ok then say('Start failed: '..tostring(reason),status);return false end
    return reason==true
end
function M.startDataset(scope,onlyUnverified,status)
    discoveryScope=scope
    return M.start('both',onlyUnverified,status,'functional')
end
function M.startPilot(status) return M.start('compact',false,status,true) end
function M.startPlacementPilot(status) return M.start('compact',false,status,'staging') end
function M.startFunctional(requestedVariant,onlyUnverified,status) return M.start(requestedVariant,onlyUnverified,status,'functional') end
function M.cancel(status)
    if not M.active() then say('No active survey; use recovery if a previous CET session was interrupted',status);return false end
    stopReason='Survey cancelled'
    if pending then pending.status='cancelled';pending.reason=stopReason end
    cleanup('return')
    say('Cancellation requested; owned actors must be gone before returning',status);return true
end
function M.recover(status)
    if M.active() then return M.cancel(status) end
    local ok,reason=pcall(function()
        local owner=native()
        if not owner:IsActive() then error('No native survey reservation to recover') end
        if not owner:IsSessionReady() or owner:GetRunGeneration()~=owner:GetSessionGeneration() then error('Load the same survey session before recovery') end
        storage:load();backend=owner;generation=owner:GetRunGeneration()
        origin=copy(owner:GetReturnPosition());origin.heading=owner:GetReturnYaw()
        actors,draining={},{}
        for i=0,owner:GetCreatedCount()-1 do
            local id=owner:GetCreatedID(i)
            if not EntityID.IsDefined(id) then error('Invalid native recovery ID; no ambient actor lookup attempted') end
            actors[#actors+1]={id=id}
        end
        run='recovery';stopReason='Interrupted CET survey recovered';pending=nil;done,passed=0,0;queue={}
        pcall(function() evidence({kind='recovery_started',owned_ids=#actors}) end)
        cleanup('return');say('Recovering only native-recorded survey IDs, then returning to the saved start',status)
        return true
    end)
    if not ok then say('Recovery failed: '..tostring(reason),status);return false end
    return reason==true
end
function M.reset()
    -- World/session changes forget handles. Never delete/teleport reused IDs.
    if M.active() then pcall(function() evidence({kind='run_interrupted',reason='World/session changed; old IDs forgotten'}) end) end
    phase,label='idle','Survey interrupted/reset; saved evidence retained. '..Catalog.coverage
    backend,generation,origin,site=nil,nil,nil,nil;actors,draining={},{};pending=nil
end
local function update(delta)
    if not M.active() then return false end
    if context.worldReady and not context.worldReady() then return true end
    local current=native()
    if current:GetSessionGeneration()~=generation then M.reset();return false end
    backend=current
    if not backend:IsSessionReady() or backend:IsMenuOpen() then return true end
    if delta<=0 or delta>.5 then return true end
    clock,poll=clock+delta,poll+delta
    local player=Game.GetPlayer()
    if player:IsDead() and afterCleanup~='finish-here' then
        stopReason='Player died; survey stopped without a return teleport';pending=nil;cleanup('finish-here');return true
    end
    if not stopReason and not backend:CanRun() then
        stopReason='Survey interrupted by duty, combat, wanted status, vehicle entry or player state'
        if discovery then
            local facts={}
            local function check(name,probe)
                local ok,value=pcall(probe);facts[#facts+1]=name..'='..(ok and tostring(value) or 'unavailable')
            end
            check('combat',function() return player:IsInCombat() end)
            check('dead',function() return player:IsDead() end)
            check('wanted',function() return Game.GetScriptableSystemsContainer():Get('NCPDPatrolSystem'):HasWantedLevel() end)
            check('on duty',function() return Game.GetScriptableSystemsContainer():Get('NCPDPatrolSystem'):IsOnDuty() end)
            check('mounted',function() return Game.GetMountedVehicle(player)~=nil end)
            stopReason=stopReason..' | '..table.concat(facts,' | ')
        end
        pending=nil;cleanup('return');return true
    end
    if phase=='travel' then
        if #actors>0 or #draining>0 then error('Previous actor ownership not cleared before travel') end
        site=queue[index];failures={};angleIndex,pass=1,1;samples=nil;observedMax=0;pilotState=nil
        if discovery then
            anchor=site;variant=site.variant;discoveryStage=nil
            discovery:begin(anchor,variant)
        end
        local preferred=storage:preferred(site,variant,profile)
        angles={}
        if preferred then angles[1]=preferred end
        for step=0,3 do
            local angle=(site.heading+90*step)%360;local duplicate=false
            for _,old in ipairs(angles) do if math.abs(old-angle)<.0001 then duplicate=true end end
            if not duplicate then angles[#angles+1]=angle end
        end
        heading=angles[1]
        if not backend:SetOrigin(point(site)) or not backend:MovePlayer(point(site),site.heading) then error('Survey transfer refused') end
        moved=true;trialEvent('site_arrival','Transfer requested; awaiting actual ground/navmesh')
        enter(discovery and 'discovery-staging' or 'landing')
        say('Moving to '..site.label..' | '..(discovery and 'terminal/layout pair ' or '')..index..'/'..#queue)
    elseif phase=='discovery-staging' then
        if poll>=.25 then
            poll=0
            -- Existing protected hold while local collision streams. The
            -- terminal itself may lack navmesh; that cannot reject its offsets.
            if distance(player:GetWorldPosition(),anchor)>1 or clock<5 then
                if not backend:MovePlayer(point(anchor),anchor.heading) then error('Discovery streaming hold refused') end
            end
            if clock>=5 then
                local candidate,stagePass=discovery:nextStaging()
                if not candidate then
                    site=anchor;resultAndNext(siteResult('unverified','No supported staging point at or around terminal after three passes; see staging rejections'));return true
                end
                local landing,reason=Layout.landing(candidate,player)
                local supported=landing and discovery:grounded(candidate,landing)
                if supported then
                    supported.heading=anchor.heading;discoveryStage=supported
                    if not backend:SetOrigin(point(supported)) or not backend:MovePlayer(landing,supported.heading) then error('Discovery supported staging transfer refused') end
                    evidence({kind='staging_passed',site=candidate.id,variant=variant,position=copy(supported),pass=stagePass,
                        reason='Supported nearby staging point; terminal exact-position navmesh is not a scene requirement'})
                    enter('discovery-stage-landing')
                else
                    evidence({kind='staging_rejected',site=candidate.id,variant=variant,position=copy(candidate),pass=stagePass,
                        reason=reason or 'Staging grounding changed road level/position'})
                end
            end
        end
    elseif phase=='discovery-stage-landing' then
        if poll>=.25 then
            local elapsed=poll;poll=0
            local landing,reason=Layout.landing(discoveryStage,player)
            if distance(player:GetWorldPosition(),discoveryStage)>1 then
                if not backend:MovePlayer(point(discoveryStage),discoveryStage.heading) then error('Discovery staging hold refused') end
            end
            if landing and clock>=1 then stable=stable+elapsed else stable=0 end
            if stable>=1 then
                if not backend:MovePlayer(landing,discoveryStage.heading) then error('Discovery stable staging transfer refused') end
                enter('searching-offsets');poll=1
            elseif clock>=10 then
                site=anchor;resultAndNext(siteResult('unverified','Nearby staging did not remain safe: '..tostring(reason)))
            end
        end
    elseif phase=='landing' then
        -- Short re-positioning prevents falling while local collision streams.
        -- No actor is created until the central landing and full layout pass.
        if poll>=.25 then
            local elapsed=poll;poll=0
            local landing,reason=Layout.landing(site,player)
            if distance(player:GetWorldPosition(),site)>1 or (not landing and clock<5) then
                if not backend:MovePlayer(point(site),site.heading) then error('Landing hold refused') end
            end
            if landing and clock>=5 then stable=stable+elapsed else stable=0 end
            if stable>=2 then
                if not backend:MovePlayer(landing,site.heading) then error('Supported landing placement refused') end
                enter(discovery and 'searching-offsets' or 'preflight');poll=1
            elseif clock>=30 then
                failures[#failures+1]={phase='landing',reason=reason or 'Central landing did not settle'}
                resultAndNext(siteResult('unverified','Landing not confirmed: '..tostring(reason)))
            end
        end
    elseif phase=='searching-offsets' then
        if distance(player:GetWorldPosition(),discoveryStage)>3 then stopReason='V moved away from the supported staging point during terminal search';cleanup('return');return true end
        if poll>=discovery.interval then
            poll=0
            local candidate,yaw,trialPass=discovery:next()
            if not candidate then
                site=anchor;resultAndNext(siteResult('unverified','No complete functional scene after bounded offset/rotation search'));return true
            end
            heading,pass=yaw,trialPass
            local landing,reason=Layout.landing(candidate,player)
            local chosen=landing and discovery:grounded(candidate,landing)
            if landing and not chosen then reason='Offset grounding moved to a different road level/position' end
            local layout,ok
            if chosen then
                reason=discovery:duplicate(chosen,variant)
                if not reason then
                    ok,layout=pcall(Layout.build,heading,player,{site=chosen,variant=variant})
                    if not ok then
                        if not Layout.isRejection(layout) then error(layout,0) end
                        reason=layout
                    end
                end
            end
            if chosen and ok then
                site=chosen
                if not backend:SetOrigin(point(site)) or not backend:MovePlayer(landing,heading) then error('Discovery candidate transfer refused') end
                trialEvent('geometry_passed','All ten positions clear before spawning; confirming selected landing')
                enter('candidate-landing')
                say(site.label..' | '..variant..' | geometry passed; confirming actual shifted center')
            else
                failures[#failures+1]={site=candidate.id,position=copy(candidate),heading=heading,pass=pass,phase=phase,reason=tostring(reason)}
                evidence({kind='geometry_rejected',site=candidate.id,variant=variant,heading=heading,position=copy(candidate),reason=tostring(reason)})
                if #failures%16==0 then say(anchor.label..' | '..variant..' | '..discovery:progress()) end
            end
        end
    elseif phase=='candidate-landing' then
        if poll>=.25 then
            local elapsed=poll;poll=0
            local landing,reason=Layout.landing(site,player)
            if distance(player:GetWorldPosition(),site)>1 then
                if not backend:MovePlayer(point(site),heading) then error('Discovery landing hold refused') end
            end
            if landing and clock>=1 then stable=stable+elapsed else stable=0 end
            if stable>=.5 then
                if not backend:MovePlayer(landing,heading) then error('Discovery supported landing refused') end
                enter('preflight');poll=1
            elseif clock>=10 then rejectTrial('Selected offset landing did not remain clear: '..tostring(reason)) end
        end
    elseif phase=='preflight' then
        if poll>=1 then
            poll=0
            if not discovery then heading=angles[angleIndex] end
            local ok,layout=pcall(Layout.build,heading,player,{site=site,variant=variant})
            if not ok then
                if not Layout.isRejection(layout) then error(layout,0) end
                failures[#failures+1]={heading=heading,pass=pass,phase='preflight',reason=layout}
                trialEvent('preflight_rejected',layout)
                say(site.label..' | heading='..string.format('%.3f',heading)..' | '..layout)
                advanceAngle()
            else
                trialEvent('trial_started','All ten positions validated; creating actual scene')
                pilotState=profile==Functional.profile and Functional.new(backend,site)
                    or (profile==Staging.profile and Staging.new(backend) or (profile==Settling.profile and Settling.new() or nil))
                Actors.create(layout,backend,actors,function(row)
                    if not backend:TrackCreatedID(row.id) then error('Native survey ID tracking refused') end
                end)
                enter('spawning')
            end
        end
    elseif phase=='spawning' then
        if poll>=.25 then
            local elapsed=poll;poll=0
            local ok,ready=pcall(Actors.prepare,actors,backend)
            if pilotState then pilotState:noteBound(actors,elapsed) end
            local partialFailure=false
            if ok and pilotState and pilotState.boundAt then
                local measured,reason,frame=pilotState:frame(actors,0,true,true)
                frame.kind='injured_motion_sample';frame.site=site.id;frame.variant=variant;frame.heading=heading;frame.pass=pass;evidence(frame)
                if not measured then partialFailure=true;rejectTrial(reason) end
            end
            if not ok then
                if tostring(ready):find('unexpected road level/position',1,true) then rejectTrial(ready) else error(ready,0) end
            elseif partialFailure then -- rejected trial is already reserved for cleanup
            elseif ready then enter(profile==Functional.profile and 'functional-settling'
                or (profile==Staging.profile and 'staging' or (pilotState and 'settling' or 'observing')));samples=nil;observedMax=0
            elseif clock>=15 then rejectTrial('Actor attachment/protection timed out') end
        end
    elseif phase=='settling' or phase=='staging' or phase=='placement-release' or phase=='functional-settling' then
        if poll>=.25 then
            local elapsed=poll;poll=0
            local observed,reason,frame=pilotState:frame(actors,elapsed,true,false,phase=='placement-release')
            frame.kind='injured_motion_sample';frame.site=site.id;frame.variant=variant;frame.heading=heading;frame.pass=pass;evidence(frame)
            if not observed then rejectTrial(reason)
            elseif distance(player:GetWorldPosition(),site)>3 then stopReason='V moved away during the placement test';pending=nil;cleanup('return')
            elseif phase=='functional-settling' and clock>=Functional.settleSeconds then
                trialEvent('functional_checks_started','Checking actual ground, clear space, down-state and a reachable aid position; injured spawn displacement is informational')
                enter('functional-observing');samples=nil;observedMax=0
            elseif phase=='staging' and clock>=Staging.stageSeconds then
                if not backend:StopInjuredPlacement() then error('Native injured placement release refused') end
                trialEvent('placement_corrections_stopped','Production-style injured correction stopped; waiting 0.5 active seconds without correction before final validation')
                enter('placement-release')
            elseif phase=='placement-release' and clock>=Staging.releaseSeconds then
                trialEvent('placement_released','No further actor correction; original 1.5 m bound and three seconds of stable supported placement now required')
                enter('observing');samples=nil;observedMax=0
            elseif phase=='settling' and clock>=Settling.settleSeconds then
                trialEvent('settling_complete','Four active seconds elapsed; original 1.5 m final limit and stable/support/clearance checks now apply')
                enter('observing');samples=nil;observedMax=0
            end
        end
    elseif phase=='observing' or phase=='functional-observing' then
        if poll>=.25 then
            local elapsed=poll;poll=0
            local observed,reason
            if pilotState then
                local frame
                observed,reason,frame=pilotState:frame(actors,elapsed,false)
                frame.kind='injured_motion_sample';frame.site=site.id;frame.variant=variant;frame.heading=heading;frame.pass=pass;evidence(frame)
            else observed,reason=Actors.observe(actors) end
            if not observed then rejectTrial(reason)
            elseif distance(player:GetWorldPosition(),site)>3 then
                stopReason='V moved away during the placement test';pending=nil;cleanup('return')
            else
                samples=observed
                if profile==Functional.profile then stable=pilotState.stable else stable=stable+elapsed end
                for _,row in ipairs(samples) do observedMax=math.max(observedMax,row.displacement) end
                if stable>=3 then
                    pending=siteResult('validated',profile==Functional.profile
                        and 'Injured officer supported, clear and reachable within aid range for three seconds; all ten actors confirmed'
                        or 'All ten actors attached and stable for at least three seconds')
                    cleanup('site-result')
                elseif profile==Functional.profile and clock>=Functional.timeoutSeconds then
                    rejectTrial(pilotState.reason or 'No continuously usable aid position for three seconds')
                end
            end
        end
    elseif phase=='cleanup' or phase=='cleanup-blocked' then
        if poll>=.5 then
            poll=0;captureDrain();actors=Actors.remove(actors)
            if #actors==0 and detached() then
                if not backend:EndActors() then error('Native survey actor protection cleanup refused') end
                draining={}
                if afterCleanup=='finish-here' then finishRun(false)
                elseif afterCleanup=='return' then
                    if pending then pending.status='cancelled';pending.reason=stopReason or 'Cancelled';evidence(pending);pending=nil end
                    enter('returning');moved=false
                elseif afterCleanup=='site-result' then resultAndNext(pending)
                else enter('between-trials') end
            elseif clock>=20 and phase~='cleanup-blocked' then
                phase='cleanup-blocked';trialEvent('cleanup_pending','Owned IDs/attached handles remain; no next teleport allowed')
                say('Cleanup pending at '..tostring(site and site.label)..'; survey stays reserved until every owned actor is gone')
            end
        end
    elseif phase=='between-trials' then
        if clock>=1 then advanceAngle() end
    elseif phase=='between-sites' then
        if clock>=3 then
            index=index+1
            if index>#queue then enter('returning');moved=false else enter('travel') end
        end
    elseif phase=='returning' or phase=='return-blocked' then
        if not moved then
            if #actors>0 or #draining>0 then error('Cannot return with pending survey actors') end
            if not backend:EndActors() or not backend:MovePlayer(point(origin),origin.heading) then error('Return transfer refused') end
            moved=true;clock,poll,stable=0,0,0
            if discovery then
                pcall(function() evidence({kind='return_started',reason=stopReason or 'Tour complete',completed_pairs=done,queued_pairs=#queue,pair_index=index}) end)
            end
            say('Returning to the original position; awaiting supported landing'..(discovery and (' | reason: '..(stopReason or 'Tour complete')) or ''))
        elseif poll>=.25 then
            local elapsed=poll;poll=0
            local landing=Layout.landing(origin,player)
            local close=distance(player:GetWorldPosition(),origin)<1.5
            if not close and clock<5 then backend:MovePlayer(point(origin),origin.heading) end
            if close and landing and clock>=2 then stable=stable+elapsed else stable=0 end
            if stable>=1 then finishRun()
            elseif clock>=30 and phase~='return-blocked' then
                phase='return-blocked';say('Return landing not confirmed; survey protection retained. Load the test save or retry recovery after the area settles.')
            end
        end
    end
    return M.active()
end
function M.update(delta)
    local ok,result=pcall(update,delta)
    if ok then return result end
    local reason=tostring(result)
    if reason~=lastError then
        say('Error: '..reason);lastError=reason
        pcall(function() evidence({kind='run_error',site=site and site.id,variant=variant,heading=heading,phase=phase,reason=reason}) end)
    end
    if M.active() then
        stopReason='Survey aborted: '..reason;pending=nil
        -- Keep ownership on failures; cleanup must complete before any return.
        if phase=='returning' or phase=='return-blocked' then phase='return-blocked'
        elseif phase~='cleanup' and phase~='cleanup-blocked' then cleanup('return') else afterCleanup='return' end
    end
    return M.active()
end
function M.shutdown()
    if not M.active() then return end
    pcall(function() evidence({kind='run_interrupted',reason='CET shutdown; use recovery if the game remains open'}) end)
    -- No unconfirmed cross-map teleport during shutdown. Native-recorded IDs
    -- and original position remain available for explicit CET-reload recovery.
    pcall(function()
        if backend and backend:IsSessionReady() and backend:GetSessionGeneration()==generation then
            captureDrain();actors=Actors.remove(actors)
            if #actors==0 and detached() then backend:EndActors() end
        end
    end)
end
return M
end

local normal=createRunner(DefaultCatalog,DefaultStore)
local discovered=nil
local context={}
local facade={}
for name,fn in pairs(normal) do facade[name]=fn end
local function discoveryRunner()
    if not discovered then
        local helper=require('scene_discovery').new()
        discovered=createRunner(helper.catalog,{new=function() return helper.store end,logFile=helper.logFile,exportFile=helper.exportFile},helper)
        discovered.configure(context)
    end
    return discovered
end
local function running()
    if discovered and discovered.active() then return discovered end
    return normal
end
function facade.configure(value) context=value or {};normal.configure(context);if discovered then discovered.configure(context) end end
function facade.active() return normal.active() or (discovered and discovered.active()) or false end
function facade.update(delta) return running().update(delta) end
function facade.summary() return running().summary() end
function facade.diagnostics() return running().diagnostics() end
function facade.cancel(status) return running().cancel(status) end
function facade.reset() normal.reset();if discovered then discovered.reset() end end
function facade.shutdown() normal.shutdown();if discovered then discovered.shutdown() end end
function facade.recover(status)
    if discovered and discovered.active() then return discovered.cancel(status) end
    local ok,isDiscovery=pcall(function() local box=Game.GetScriptableSystemsContainer();return box:Get('NCPDPatrolSceneSurveySystem'):IsDiscovery() end)
    if ok and isDiscovery then return discoveryRunner().recover(status) end
    return normal.recover(status)
end
function facade.startDiscovery(scope,onlyUnverified,status) return discoveryRunner().startDataset(scope,onlyUnverified,status) end
function facade.discoverySummary() return discoveryRunner().summary() end
function facade.exportDiscovery(status) return discoveryRunner().export(status) end
function facade.loadDiscovery(status) return discoveryRunner().loadResults(status) end
return facade
