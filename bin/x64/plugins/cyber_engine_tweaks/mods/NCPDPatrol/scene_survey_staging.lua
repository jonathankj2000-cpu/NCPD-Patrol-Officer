-- Opt-in production-style placement, followed by an uncorrected observation.
-- A teleport request never counts as proof; all final reads use the engine.
local Settling=require('scene_survey_settling')
local M={profile='injured-staging-pilot-v1',stageSeconds=4,releaseSeconds=.5,
    pilotSites=Settling.pilotSites}
function M.new(backend)
    local self=Settling.new()
    local observe=self.frame
    self.corrections=0
    function self:frame(actors,delta,transition,partial,release)
        local samples,reason,frame=observe(self,actors,delta,transition,partial)
        frame.phase=partial and 'spawning' or (release and 'placement-release' or (transition and 'staging' or 'observing'))
        frame.placement_corrections=self.corrections
        frame.corrections_enabled=transition==true and not partial and not release
        if not samples then
            if reason=='Actor displaced: injured' then
                reason='Injured placement did not hold after staging; site geometry remains unverified'
                frame.failure=reason
            end
            return nil,reason,frame
        end
        if frame.corrections_enabled then
            local row
            for _,candidate in ipairs(actors) do if candidate.kind=='injured' then row=candidate end end
            local a,b=frame.injured.actual,frame.injured.expected
            -- Exactly the production pre-arrival correction trigger. Preserve
            -- the original target, ground and finite transition safety limits.
            if (a.x-b.x)^2+(a.y-b.y)^2>.25 or math.abs(a.z-b.z)>1 then
                local ground,bad=Settling.support({actual=b,yaw=frame.injured.yaw},true)
                frame.correction_target_ground=ground
                if bad then
                    frame.failure='Injured placement target unsafe: '..bad
                    return nil,frame.failure,frame
                end
                if not backend:LockPosition(row.actor,Vector4.new(b.x,b.y,b.z,1),row.yaw) then
                    frame.failure='Injured placement correction refused'
                    return nil,frame.failure,frame
                end
                self.corrections=self.corrections+1
                frame.correction_requested=true;frame.correction_target={x=b.x,y=b.y,z=b.z}
                frame.placement_corrections=self.corrections
            end
        end
        return samples,nil,frame
    end
    return self
end
return M
