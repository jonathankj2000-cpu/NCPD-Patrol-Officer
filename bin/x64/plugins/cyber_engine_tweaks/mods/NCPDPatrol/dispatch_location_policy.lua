-- Assignment eligibility only. Never remove/unlock world fast-travel markers
-- or renumber the fixed journal bank. Coordinates match its existing site 271.
local M={}
function M.allowed(pin,point,fastTravel)
    if fastTravel then
        local ok,blocked=pcall(function()
            local data=pin:GetPointData()
            return data and data:GetPointRecord()==TweakDBID.new("FastTravelPoints.wat_lch_dataterm_10")
        end)
        if ok and blocked then return false end
    end
    -- Older/custom marker wrappers may not expose point data. Use an exact
    -- three-dimensional 2 m match, preserving street-level locations below it.
    local x,y,z=point.x+1396.31165,point.y-1277.96313,point.z-123.076935
    return x*x+y*y+z*z>4
end
return M
