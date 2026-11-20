local Navigation = require("marker_navigation") -- r5 marker hook
-- One VIP transport's marker registry state. No journal, actor or reward APIs.
-- clear removes the owned current-world marker; reset only forgets old handles.
local M = {}
function M.new()
    local waypointID,waypointPoint=nil,nil
    local waypointPoll,waypointMissing,waypointCooldown,waypointRepairs=0,0,0,0
    local waypointKind,waypointStatus="Pickup","No active VIP waypoint"
    local function distance(a,b) return math.sqrt((a.x-b.x)^2+(a.y-b.y)^2+(a.z-b.z)^2) end
    local function releaseWaypointID()
        if Navigation.isBank(waypointID) then Navigation.release(waypointID);waypointID=nil;return end -- r5 marker hook
        if waypointID then
            local system=Game.GetMappinSystem()
            if not system then error("Mappin system unavailable for VIP marker removal") end
            system:UnregisterMappin(waypointID)
        end
        waypointID=nil
    end
    local function clearWaypoint()
        local ok,err=pcall(releaseWaypointID)
        waypointPoint=nil
        waypointStatus=ok and "No active VIP waypoint" or ("VIP marker removal pending: "..tostring(err))
    end
    local function waypoint(patrol,point,kind)
        releaseWaypointID()
        waypointPoint=Vector4.new(point.x,point.y,point.z,1)
        local marker=Navigation.place(patrol,point,"vip")
        if not marker or marker.value==nil or marker.value==0 then error("VIP waypoint creation failed") end
        waypointID,waypointKind=marker,kind
        waypointPoll,waypointMissing,waypointCooldown=0,0,0
        waypointStatus=kind.." marker registered; awaiting registry verification"
    end
    local function checkWaypoint(delta,patrol,status)
        if not waypointPoint then return end
        if Navigation.isBank(waypointID) then waypointStatus=Navigation.describe(waypointID,waypointStatus);return end -- r5 marker hook
        waypointPoll=waypointPoll+delta
        waypointCooldown=math.max(0,waypointCooldown-delta)
        if waypointPoll<1 then return end
        local step=waypointPoll;waypointPoll=0
        local checked,system,found=pcall(function()
            local map=Game.GetMappinSystem()
            if not map then error("Mappin system unavailable") end
            for _,pin in ipairs(map:GetAllMappins()) do
                local ok,id=pcall(function() return pin:GetNewMappinID() end)
                if ok and id and waypointID and tostring(id.value)==tostring(waypointID.value) then return map,pin end
            end
            return map,nil
        end)
        if not checked then waypointStatus="VIP marker inspection pending: "..tostring(system);return end
        if found then
            waypointMissing=0
            local ok,err=pcall(function()
                local active=found:IsActive()
                local aligned=distance(found:GetWorldPosition(),waypointPoint)<=1
                if not aligned then system:SetMappinPosition(waypointID,waypointPoint) end
                if not active then system:SetMappinActive(waypointID,true) end
                waypointStatus=waypointKind..(active and aligned and " marker present" or " marker activation/position requested")
            end)
            if not ok then waypointStatus="VIP marker update pending: "..tostring(err) end
            return
        end
        waypointMissing=waypointMissing+step
        waypointStatus=waypointKind.." marker missing; automatic recovery pending"
        if waypointMissing<2 or waypointCooldown>0 then return end
        waypointCooldown=5
        local ok,err=pcall(function()
            -- Only this assignment's cached ID is removed. Retired scenes and
            -- other dispatch types cannot lose their marker to a VIP repair.
            releaseWaypointID()
            local marker=Navigation.place(patrol,waypointPoint,"vip")
            if not marker or marker.value==nil or marker.value==0 then error("VIP marker re-registration rejected") end
            waypointID=marker;waypointRepairs=waypointRepairs+1;waypointMissing=0
            waypointStatus=waypointKind.." marker re-registered; awaiting registry verification"
        end)
        if not ok then waypointStatus="VIP marker recovery pending: "..tostring(err) end
        if status then status("VIP navigation | "..waypointStatus.." | repairs="..waypointRepairs) end
    end
    local marker = {place=waypoint, clear=clearWaypoint, update=checkWaypoint}
    function marker.beginAssignment(patrol,point,kind)
        waypointRepairs=0
        waypoint(patrol,point,kind)
    end
    function marker.rebuild(patrol,point,kind)
        waypoint(patrol,point,kind)
        waypointRepairs=waypointRepairs+1
    end
    function marker.reset()
        -- World transitions never unregister an ID from a previous world.
        waypointID,waypointPoint=nil,nil
        waypointPoll,waypointMissing,waypointCooldown,waypointRepairs=0,0,0,0
        waypointKind,waypointStatus="Pickup","No active VIP waypoint"
    end
    function marker.status() return waypointStatus end
    function marker.diagnostics()
        return "waypoint="..waypointStatus.." | waypoint ID="..tostring(waypointID and waypointID.value or "none")
            .." | waypoint repairs="..waypointRepairs.." | waypoint position="..(waypointPoint and string.format("%.1f,%.1f,%.1f",waypointPoint.x,waypointPoint.y,waypointPoint.z) or "none")
    end
    return marker
end
return M
