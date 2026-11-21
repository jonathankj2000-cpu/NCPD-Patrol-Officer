-- Judge the injured officer by usable space/access, never spawn accuracy.
-- No actor teleports, target rebasing, or fixed-position stability anchors.
local Actors=require('officer_down_actors')
local M={profile='injured-functional-v1',settleSeconds=4,observeSeconds=3,timeoutSeconds=12,sceneRadius=25,aidRange=2.5}
local function finite(p) return p and p.x==p.x and p.y==p.y and p.z==p.z and math.abs(p.x)<100000 and math.abs(p.y)<100000 and math.abs(p.z)<100000 end
local function copy(p) return {x=p.x,y=p.y,z=p.z} end
local function point(p,z) return Vector4.new(p.x,p.y,z or p.z,1) end
local function distance(a,b) return math.sqrt((a.x-b.x)^2+(a.y-b.y)^2+(a.z-b.z)^2) end
local function ray(spatial,a,b) return spatial:SyncRaycastByCollisionGroup(a,b,CName.new('Static'),true,false) end
local function floor(spatial,p)
    local hit,result=ray(spatial,point(p,p.z+.5),point(p,p.z-1.5))
    if not hit or not result or not finite(result.position) or not finite(result.normal) then return nil,'No supported ground at injured officer' end
    return {position=copy(result.position),normal_z=result.normal.z,root_height=p.z-result.position.z}
end
local function body(spatial,sample)
    local ground,reason=floor(spatial,sample.actual)
    if not ground then return nil,reason end
    if ground.root_height<-.25 then return ground,'Injured officer below ground',true end
    if ground.normal_z<.7 or ground.root_height>1 then return ground,'Injured officer not supported by usable ground' end
    local p,z=sample.actual,ground.position.z
    for _,angle in ipairs({0,90}) do
        local r=math.rad(angle);local dx,dy=math.cos(r)*.5,math.sin(r)*.5
        if ray(spatial,Vector4.new(p.x-dx,p.y-dy,z+.45,1),Vector4.new(p.x+dx,p.y+dy,z+.45,1)) then
            ground.static_clear=false;return ground,'Injured officer overlaps local Static geometry'
        end
    end
    ground.static_clear=true
    ground.vehicle_clear=not spatial:Overlap(Vector4.new(.35,.6,.2,0),Vector4.new(p.x,p.y,z+.45,1),EulerAngles.new(0,0,sample.yaw),CName.new('Vehicle'))
    if not ground.vehicle_clear then return ground,'Injured officer overlaps a vehicle' end
    return ground
end
local function approach(spatial,nav,backend,actor,p,ground,probe,fixed,navigationOwner)
    local result=nav:FindPointInSphereForCharacter(point(probe),.5,navigationOwner or Game.GetPlayer())
    if not result or result.status~=worldNavigationRequestStatus.OK or not finite(result.point)
        or distance(result.point,probe)>.75 or distance(result.point,p)>M.aidRange then return nil,'No aid position within interaction range' end
    local q=copy(fixed and probe or result.point)
    local support,reason=floor(spatial,q)
    if not support or math.abs(support.position.z-q.z)>.5 or support.normal_z<.7 then return nil,reason or 'Aid position has no usable ground' end
    q.z=support.position.z
    if distance(q,p)>M.aidRange then return nil,'Aid position outside interaction range' end
    if ray(spatial,point(q,q.z+.15),point(q,q.z+1.9)) then return nil,'Aid standing position blocked by Static geometry' end
    if spatial:Overlap(Vector4.new(.4,.4,.8,0),point(q,q.z+.95),EulerAngles.new(0,0,0),CName.new('Vehicle')) then return nil,'Aid standing position occupied by a vehicle' end
    if ray(spatial,point(q,q.z+.65),point(p,ground.position.z+.65)) then return nil,'Wall blocks access to injured officer' end
    for _,t in ipairs({.25,.5,.75}) do
        local x,y,z=q.x+(p.x-q.x)*t,q.y+(p.y-q.y)*t,q.z+(ground.position.z-q.z)*t
        if spatial:Overlap(Vector4.new(.2,.2,.3,0),Vector4.new(x,y,z+.65,1),EulerAngles.new(0,0,0),CName.new('Vehicle')) then return nil,'Vehicle blocks access to injured officer' end
    end
    if not backend:HasInjuredAidPath(actor,point(q)) then return nil,'No complete walking route to injured officer' end
    return q
end
-- Live catalogue incidents already have a surveyed layout. A standing actor's
-- root/cover animation is not a new survey failure; check actual usable space.
-- Survey callers do not opt in and retain their original 1.5 m placement rule.
local function liveActor(spatial,sample,site,actor)
    if actor:IsDead() then return 'Scene actor dead: '..sample.kind end
    if distance(sample.actual,site)>M.sceneRadius or math.abs(sample.actual.z-sample.expected.z)>1.5 then return 'Scene actor outside supported incident area: '..sample.kind end
    local ground,reason=floor(spatial,sample.actual)
    if not ground or ground.root_height<-.25 or ground.root_height>1 or ground.normal_z<.7 then return 'Scene actor has no usable ground: '..sample.kind end
    local p,z=sample.actual,ground.position.z
    if ray(spatial,point(p,z+.15),point(p,z+1.7)) then return 'Scene actor overlaps Static geometry: '..sample.kind end
    if spatial:Overlap(Vector4.new(.3,.3,.65,0),point(p,z+.9),EulerAngles.new(0,0,sample.yaw),CName.new('Vehicle')) then return 'Scene actor overlaps a vehicle: '..sample.kind end
end
function M.new(backend,site,options)
    local self={age=0,boundAt=nil,peak=0,stable=0,previous=nil,aidPosition=nil,proof=nil,reason=nil}
    function self:noteBound(actors,elapsed)
        self.age=self.age+(elapsed or 0)
        if self.boundAt then return end
        for _,row in ipairs(actors) do if row.kind=='injured' and row.bound then self.boundAt=self.age end end
    end
    function self:frame(actors,delta,transition,partial)
        self.age=self.age+delta
        local spatial,nav=Game.GetSpatialQueriesSystem(),Game.GetAINavigationSystem()
        if not spatial or not nav then error('Functional survey ground/navigation services unavailable') end
        local navigationOwner=options and options.liveScene and backend:GetInjuredAidNavigationOwner() or nil
        if options and options.liveScene and not navigationOwner then error('Live incident navigation owner not ready') end
        local samples,row,actor={}
        local frame={phase=partial and 'spawning' or (transition and 'functional-settling' or 'functional-observing'),elapsed_active=self.age,
            since_down_request=self.boundAt and self.age-self.boundAt or nil,scene_radius=M.sceneRadius,aid_range=M.aidRange,corrections_enabled=false}
        local function failed(reason) frame.failure=reason;return nil,reason,frame end
        for _,candidate in ipairs(actors) do
            if not partial or candidate.kind=='injured' then
                local sample,bad,object=Actors.measure(candidate)
                if not sample then return failed(bad) end
                if candidate.kind=='injured' then
                    row,actor=candidate,object;frame.injured=sample
                    if object:IsDead() then return failed('Injured officer dead') end
                    frame.scene_distance=distance(sample.actual,site)
                    if frame.scene_distance>M.sceneRadius then return failed('Injured officer outside incident area') end
                elseif options and options.liveScene and not candidate.car then
                    local reason=liveActor(spatial,sample,site,object)
                    if reason then return failed(reason) end
                elseif sample.displacement>1.5 then return failed('Actor displaced: '..candidate.kind) end
                if candidate.car then object:ForceBrakesUntilStoppedOrFor(1) end
                samples[#samples+1]=sample
            end
        end
        if not row then return failed('Injured officer missing') end
        local p=frame.injured.actual
        frame.alive=true;self.peak=math.max(self.peak,frame.injured.displacement);frame.peak_displacement=self.peak
        frame.step_distance=self.previous and distance(p,self.previous) or 0;self.previous=copy(p)
        local ground,reason,unsafe
        if transition then
            ground,reason=floor(spatial,p)
            if ground and ground.root_height<-.25 then unsafe=true;reason='Injured officer below ground' else reason=nil end
        else ground,reason,unsafe=body(spatial,frame.injured) end
        frame.ground=ground
        if unsafe then return failed(reason) end
        if transition then return samples,nil,frame end
        frame.aid_state_ready=backend:IsInjuredAidReady(actor)==true
        frame.body_ready=not reason and frame.aid_state_ready
        if not reason and not frame.aid_state_ready then reason='Injured officer is not ready for aid' end
        local aid,old=self.aidPosition,self.aidPosition
        local continued=false
        if not reason then
            if aid then aid,reason=approach(spatial,nav,backend,actor,p,ground,aid,true,navigationOwner);continued=aid~=nil end
            if not aid then
                self.stable=0;reason=nil
                for i=0,7 do
                    local angle=i*math.pi/4
                    local probe={x=p.x+math.cos(angle)*1.5,y=p.y+math.sin(angle)*1.5,z=ground.position.z}
                    aid,reason=approach(spatial,nav,backend,actor,p,ground,probe,nil,navigationOwner)
                    if aid then break end
                end
            end
        else aid=nil end
        self.aidPosition=aid
        if aid then
            self.stable=continued and self.stable+delta or 0;self.reason=nil
            self.proof={ground_supported=true,static_clear=true,vehicle_clear=true,aid_state_ready=true,path_confirmed=true,
                actual_position=copy(p),assistance_position=copy(aid),aid_distance=distance(p,aid),scene_distance=frame.scene_distance,
                scene_radius=M.sceneRadius,ready_seconds=self.stable,revive_executed=false}
        else
            self.stable=0;self.proof=nil;self.reason=reason or 'No usable aid position'
        end
        frame.functionally_ready=aid~=nil;frame.functional_reason=self.reason;frame.assistance_position=aid and copy(aid) or nil
        frame.stable_seconds=self.stable;frame.aid_position_changed=aid~=nil and (old==nil or distance(old,aid)>.01)
        return samples,nil,frame
    end
    return self
end
return M
