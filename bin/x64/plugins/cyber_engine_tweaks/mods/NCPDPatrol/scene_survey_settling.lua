-- Opt-in three-site measurement protocol, not a global tolerance change.
local Actors=require('officer_down_actors')
local M={profile='injured-settling-pilot-v1',settleSeconds=4,observeSeconds=3,maximumDrift=.15,
    pilotSites={kryss_04=true,kryss_11=true,kryss_15=true}}
local function finite(p) return p and p.x==p.x and p.y==p.y and p.z==p.z and math.abs(p.x)<100000 and math.abs(p.y)<100000 and math.abs(p.z)<100000 end
local function distance(a,b) return math.sqrt((a.x-b.x)^2+(a.y-b.y)^2+(a.z-b.z)^2) end
local function support(sample,final)
    local spatial=Game.GetSpatialQueriesSystem()
    local p=sample.actual
    local hit,trace=spatial:SyncRaycastByCollisionGroup(Vector4.new(p.x,p.y,p.z+1.5,1),Vector4.new(p.x,p.y,p.z-1.5,1),CName.new('Static'),true,false)
    local state={hit=hit==true}
    if not hit or not trace or not finite(trace.position) or not finite(trace.normal) then
        return state,final and 'Injured ground support not confirmed' or nil
    end
    local ground=trace.position
    state.position={x=ground.x,y=ground.y,z=ground.z};state.normal_z=trace.normal.z;state.root_height=p.z-ground.z
    if state.root_height<-.2 then return state,'Injured root below supported ground' end
    if not final then return state end
    if trace.normal.z<.85 or state.root_height>.75 then return state,'Injured final ground support outside bounds' end
    local yaw=math.rad(sample.yaw);local fx,fy=-math.sin(yaw),math.cos(yaw);local rx,ry=math.cos(yaw),math.sin(yaw)
    -- Local body-height proxy rays, not a claim of full skeleton collision proof.
    for _,side in ipairs({-.3,0,.3}) do
        local x,y=p.x+rx*side,p.y+ry*side
        if spatial:SyncRaycastByCollisionGroup(Vector4.new(x-fx*.6,y-fy*.6,ground.z+.45,1),Vector4.new(x+fx*.6,y+fy*.6,ground.z+.45,1),CName.new('Static'),true,false) then
            state.static_clear=false;return state,'Injured final local Static clearance blocked'
        end
    end
    state.static_clear=true
    state.vehicle_clear=not spatial:Overlap(Vector4.new(.35,.6,.2,0),Vector4.new(p.x,p.y,ground.z+.45,1),EulerAngles.new(0,0,sample.yaw),CName.new('Vehicle'))
    if not state.vehicle_clear then return state,'Injured final local Vehicle clearance blocked' end
    return state
end
M.support=support -- shared conservative support/clearance for the staging pilot
function M.new()
    local self={age=0,boundAt=nil,peak=0,anchors=nil,stable=0,maxDrift=0,previous=nil}
    function self:noteBound(actors,elapsed)
        self.age=self.age+(elapsed or 0)
        if self.boundAt then return end
        for _,row in ipairs(actors) do if row.kind=='injured' and row.bound then self.boundAt=self.age end end
    end
    function self:frame(actors,delta,settling,partial)
        self.age=self.age+delta
        local row
        for _,candidate in ipairs(actors) do if candidate.kind=='injured' then row=candidate end end
        local sample,reason,actor
        if row then sample,reason,actor=Actors.measure(row) end
        local frame={phase=partial and 'spawning' or (settling and 'settling' or 'observing'),elapsed_active=self.age,
            since_down_request=self.boundAt and self.age-self.boundAt or nil,settling=settling==true,
            final_distance_limit=1.5,temporary_horizontal_limit=3,temporary_vertical_limit=1.5}
        if not sample then frame.failure=reason or 'Injured actor missing';return nil,frame.failure,frame end
        frame.injured=sample
        local p,q=sample.actual,sample.expected;local dx,dy,dz=p.x-q.x,p.y-q.y,p.z-q.z;local angle=math.rad(sample.yaw)
        frame.delta_world={x=dx,y=dy,z=dz};frame.delta_local={forward=-math.sin(angle)*dx+math.cos(angle)*dy,right=math.cos(angle)*dx+math.sin(angle)*dy,z=dz}
        frame.step_distance=self.previous and distance(p,self.previous) or 0
        self.previous={x=p.x,y=p.y,z=p.z};self.peak=math.max(self.peak,sample.displacement);frame.peak_displacement=self.peak
        frame.alive=not actor:IsDead()
        local stateOK,state=pcall(function() return tostring(actor:GetHighLevelStateFromBlackboard()) end)
        if stateOK then frame.high_level_state=state end
        if not frame.alive then frame.failure='Injured actor dead';return nil,frame.failure,frame end
        local samples,bad,badSample=Actors.observe(partial and {row} or actors,settling and {injuredTransition=true} or nil)
        local groundFailure
        if dx*dx+dy*dy<=9 and math.abs(dz)<=1.5 then
            frame.ground,groundFailure=support(sample,not settling)
        else frame.ground={skipped='Outside temporary measurement envelope'} end
        if not samples then frame.failure=bad;frame.failed_actor=badSample;return nil,bad,frame end
        if groundFailure then frame.failure=groundFailure;return nil,groundFailure,frame end
        if not settling then
            if not self.anchors then
                self.anchors={}
                for i,value in ipairs(samples) do self.anchors[i]={x=value.actual.x,y=value.actual.y,z=value.actual.z} end
            end
            for i,value in ipairs(samples) do
                local drift=distance(value.actual,self.anchors[i]);self.maxDrift=math.max(self.maxDrift,drift)
                if drift>M.maximumDrift then
                    frame.failure='Actor not stable after settling: '..value.kind;frame.anchor_drift=drift;frame.failed_actor=value
                    return nil,frame.failure,frame
                end
            end
            self.stable=self.stable+delta
        end
        frame.stable_seconds=self.stable;frame.maximum_anchor_drift=self.maxDrift
        return samples,nil,frame
    end
    return self
end
return M
