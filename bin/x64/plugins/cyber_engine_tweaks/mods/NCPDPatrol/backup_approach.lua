-- Backup road evidence, adapted from the transport ambush's proven checks.
-- History is local to one current vehicle/world. No actors or dispatch state.
local M={}
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
function M.new()
    local trail,vehicle={},nil
    local clock,sample=0,0
    local approach={}
    function approach.reset() trail={};vehicle=nil;clock,sample=0,0 end
    function approach.record(delta,current)
        clock=clock+delta;sample=sample+delta
        -- Getting out to use the trunk keeps the last driven route available.
        if not current then return end
        if not same(current,vehicle) then trail={};vehicle=current;sample=0 end
        if not current:IsAttached() or sample<.25 or math.abs(current:GetCurrentSpeed())<3 then return end
        sample=0
        local pos,forward=current:GetWorldPosition(),current:GetWorldForward()
        if not finite(pos) or not finite(forward) then trail={};return end
        local previous=trail[#trail]
        local moved=previous and distance(previous.position,pos) or 0
        if previous and moved>120 then trail={};previous=nil end
        if previous and moved<5 then return end
        trail[#trail+1]={position=Vector4.new(pos.x,pos.y,pos.z,1),
            orientation=current:GetWorldOrientation(),forward=Vector4.new(forward.x,forward.y,forward.z,0),time=clock}
        if #trail>120 then table.remove(trail,1) end
    end
    function approach.find(current,support,rejected)
        local spatial=Game.GetSpatialQueriesSystem()
        local origin=current and current:GetWorldPosition()
        local forward=current and current:GetWorldForward()
        if not spatial or not finite(origin) or not finite(forward) then return nil end
        local function ray(a,b)
            return spatial:SyncRaycastByCollisionGroup(a,b,CName.new("Static"),true,false)
        end
        local function floorAt(p)
            local hit,result=ray(Vector4.new(p.x,p.y,p.z+.75,1),Vector4.new(p.x,p.y,p.z-1.5,1))
            if not hit or not result or not finite(result.position) or not finite(result.normal)
                or result.normal.z<.85 or math.abs(result.position.z-p.z)>1.3 then return nil end
            return result
        end
        local function supported(point)
            local centre=floorAt(point.position)
            if not centre then return nil end
            for _,corner in ipairs({{-2,-.85},{-2,.85},{2,-.85},{2,.85}}) do
                local dx=point.forward.x*corner[1]-point.forward.y*corner[2]
                local dy=point.forward.y*corner[1]+point.forward.x*corner[2]
                local p=Vector4.new(point.position.x+dx,point.position.y+dy,point.position.z,1)
                local floor=floorAt(p)
                local expected=centre.position.z-(centre.normal.x*dx+centre.normal.y*dy)/centre.normal.z
                if not floor or math.abs(floor.position.z-expected)>.2 then return nil end
            end
            return centre
        end
        local function corridor(a,b,direction)
            for _,side in ipairs({-.8,0,.8}) do
                local dx,dy=-direction.y*side,direction.x*side
                if ray(Vector4.new(a.x+dx,a.y+dy,a.z+.6,1),Vector4.new(b.x+dx,b.y+dy,b.z+.6,1)) then return false end
            end
            return true
        end
        local function candidate(point,source)
            for _,blocked in ipairs(rejected or {}) do
                if distance(point.position,blocked)<12 then return nil end
            end
            local centre=supported(point)
            if not centre then return nil end
            local ground=centre.position
            -- A supported floor is not enough: require clearance for the body.
            for _,height in ipairs({.6,1.3}) do
                for _,side in ipairs({-.8,0,.8}) do
                    local dx,dy=-point.forward.y*side,point.forward.x*side
                    local a=Vector4.new(ground.x+dx-point.forward.x*2.4,ground.y+dy-point.forward.y*2.4,ground.z+height,1)
                    local b=Vector4.new(ground.x+dx+point.forward.x*2.4,ground.y+dy+point.forward.y*2.4,ground.z+height,1)
                    if ray(a,b) then return nil end
                end
            end
            -- Stage crew on checked road behind the bumper, within the padded
            -- scene bounds. Lateral +/-4 m can put them beyond a bridge railing.
            local crew={}
            for _,side in ipairs({-.8,.8}) do
                local dx=-point.forward.x*5-point.forward.y*side
                local dy=-point.forward.y*5+point.forward.x*side
                local probe=Vector4.new(ground.x+dx,ground.y+dy,ground.z,1)
                local floor=floorAt(probe)
                local expected=ground.z-(centre.normal.x*dx+centre.normal.y*dy)/centre.normal.z
                if not floor or math.abs(floor.position.z-expected)>.35 then return nil end
                local foot=floor.position
                if ray(Vector4.new(foot.x,foot.y,foot.z+.15,1),Vector4.new(foot.x,foot.y,foot.z+1.9,1)) then return nil end
                crew[#crew+1]=Vector4.new(foot.x,foot.y,foot.z+.15,1)
            end
            -- The same padded active-camera test as ambush, without a VIP gate.
            if support:CanSpawnBackupAt(point.position)~=true then return nil end
            return {position=point.position,ground=ground,orientation=point.orientation,forward=point.forward,crew=crew,source=source}
        end
        if same(current,vehicle) then
            local along,previous=0,origin
            for i=#trail,1,-1 do
                local point=trail[i]
                along=along+distance(previous,point.position)
                if along>90 or clock-point.time>60 then break end
                if not corridor(previous,point.position,point.forward) then break end
                previous=point.position
                local metres=distance(origin,point.position)
                if along>=35 and metres>=30 and metres<=85 and clock-point.time>=.5
                    and math.abs(point.position.z-origin.z)<=4 then
                    local found=candidate(point,"recent driven route")
                    if found then return found end
                end
            end
        end
        -- A newly started shift may have no route history. Check a continuous
        -- straight corridor behind the actual vehicle, never pedestrian navmesh.
        -- Static geometry cannot identify a traffic lane; uncertain terrain fails.
        local previous=origin
        for metres=5,70,5 do
            local point=Vector4.new(origin.x-forward.x*metres,origin.y-forward.y*metres,origin.z,1)
            local floor=floorAt(point)
            if not floor or not corridor(previous,point,forward) then return nil end
            previous=point
            if metres==40 or metres==55 or metres==70 then
                local found=candidate({position=point,forward=forward,orientation=current:GetWorldOrientation()},"checked straight approach")
                if found then return found end
            end
        end
    end
    return approach
end
function M.positioned(car,point)
    if not car or not car:IsAttached() or not point then return false end
    local actual,expected=car:GetWorldPosition(),point.ground
    return finite(actual) and math.sqrt((actual.x-expected.x)^2+(actual.y-expected.y)^2)<=1.5
        and actual.z>=expected.z-.25 and actual.z<=expected.z+1.2
end
return M
