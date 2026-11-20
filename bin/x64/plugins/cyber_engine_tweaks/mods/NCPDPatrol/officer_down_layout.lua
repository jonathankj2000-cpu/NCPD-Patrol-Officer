-- Fixed relative scene layout. Validate all support/clearance before creating
-- any entity; no road level or navmesh fallback to another floor.
local Scene=require('officer_down_scene')
local M={}
local function finite(p) return p and p.x==p.x and p.y==p.y and p.z==p.z and math.abs(p.x)<100000 and math.abs(p.y)<100000 and math.abs(p.z)<100000 end
local REJECTION='Scene placement: '
local function reject(reason) error(REJECTION..reason,0) end
function M.build(heading,player)
    local spatial,nav=Game.GetSpatialQueriesSystem(),Game.GetAINavigationSystem()
    if not spatial or not nav then error('Scene ground/navigation services unavailable') end
    local a=math.rad(heading);local fx,fy=-math.sin(a),math.cos(a);local rx,ry=math.cos(a),math.sin(a)
    local function point(x,y,z) return Vector4.new(Scene.x+fx*x+rx*y,Scene.y+fy*x+ry*y,z or Scene.z,1) end
    local function ray(a,b) return spatial:SyncRaycastByCollisionGroup(a,b,CName.new('Static'),true,false) end
    local function occupied(ground,car,yaw)
        -- Match the game's SpatialQueriesHelper: dimensions are half-extents;
        -- Vehicle is a separate overlap query, never evidence of missing ground.
        local box=car and Vector4.new(1.05,2.5,.75,0) or Vector4.new(.4,.4,.8,0)
        local center=Vector4.new(ground.x,ground.y,ground.z+(car and .9 or .95),1)
        return spatial:Overlap(box,center,EulerAngles.new(0,0,yaw),CName.new('Vehicle'))
    end
    local function floor(p)
        -- Search the full accepted +/-1.3 m height band, with a small margin.
        -- A ray beginning at +0.7 m cannot hit valid uphill ground above it.
        local hit,result=ray(Vector4.new(p.x,p.y,p.z+1.5,1),Vector4.new(p.x,p.y,p.z-1.5,1))
        if not hit then return nil,'no Static surface hit in the +/-1.5 m probe' end
        if not result or not finite(result.position) or not finite(result.normal) then return nil,'invalid Static hit position/normal' end
        if result.normal.z<.85 then return nil,string.format('surface normal Z=%.3f; minimum=0.850',result.normal.z) end
        if math.abs(result.position.z-Scene.z)>1.3 then
            return nil,string.format('surface Z=%.3f; scene Z=%.3f; height delta=%.3f m; maximum=1.300 m',result.position.z,Scene.z,result.position.z-Scene.z)
        end
        -- SpatialQueryResult.position is Vector3. Native character navigation
        -- requires Vector4; convert once at this boundary instead of forwarding
        -- the raycast struct to a differently typed engine API.
        return Vector4.new(result.position.x,result.position.y,result.position.z,1)
    end
    local definitions={
        {'police','Vehicle.NCPDPatrol_OD_Police',-9,0,90},
        {'gangcar','Vehicle.NCPDPatrol_OD_GangCar',8,-5.5,90},
        {'gangcar','Vehicle.NCPDPatrol_OD_GangCar',8,5.5,90},
        {'injured','Character.NCPDPatrol_OD_Injured',-12.5,-1.5,0},
        {'defender','Character.NCPDPatrol_OD_Defender',-12.5,2.5,0},
        {'enemy','Character.NCPDPatrol_OD_Ganger',11.5,-8,180},
        {'enemy','Character.NCPDPatrol_OD_Ganger',11.5,-4,180},
        {'enemy','Character.NCPDPatrol_OD_Ganger',12,0,180},
        {'enemy','Character.NCPDPatrol_OD_Ganger',11.5,4,180},
        {'enemy','Character.NCPDPatrol_OD_Ganger',11.5,8,180},
    }
    local layout={}
    for _,row in ipairs(definitions) do
        local p=point(row[3],row[4]);local ground,reason=floor(p)
        if not ground then reject(string.format('Unsupported scene ground at %s | heading=%.0f | probe=%.3f,%.3f,%.3f | %s',row[1],heading,p.x,p.y,p.z,reason)) end
        local car=row[1]=='police' or row[1]=='gangcar'
        if car then
            for _,corner in ipairs({{-1,-2.4},{-1,2.4},{1,-2.4},{1,2.4}}) do
                local probe=point(row[3]+corner[1],row[4]+corner[2])
                local q,cornerReason=floor(probe)
                if not q then reject(string.format('Unsupported vehicle footprint at %s | heading=%.0f | probe=%.3f,%.3f,%.3f | %s',row[1],heading,probe.x,probe.y,probe.z,cornerReason)) end
                if math.abs(q.z-ground.z)>.4 then reject(string.format('Uneven vehicle footprint at %s | corner height delta=%.3f m; maximum=0.400 m',row[1],q.z-ground.z)) end
            end
            for _,side in ipairs({-.8,0,.8}) do
                local from=point(row[3]+side,row[4]-2.5,ground.z+.8)
                local to=point(row[3]+side,row[4]+2.5,ground.z+.8)
                if ray(from,to) then reject('Static obstruction in scene vehicle footprint') end
            end
            p=Vector4.new(ground.x,ground.y,ground.z+.15,1)
        else
            if ray(Vector4.new(ground.x,ground.y,ground.z+.15,1),Vector4.new(ground.x,ground.y,ground.z+1.9,1)) then reject('Blocked officer/gang spawn') end
            local result=nav:FindPointInSphereForCharacter(ground,1.2,player)
            if not result or result.status~=worldNavigationRequestStatus.OK or not finite(result.point)
                or math.abs(result.point.z-ground.z)>1 or (result.point.x-ground.x)^2+(result.point.y-ground.y)^2>2.25 then reject('Scene actor has no nearby supported navmesh') end
            ground=Vector4.new(result.point.x,result.point.y,result.point.z,1)
            p=Vector4.new(result.point.x,result.point.y,result.point.z+.1,1)
        end
        local yaw=(heading+row[5])%360
        if occupied(ground,car,yaw) then reject(string.format('Vehicle occupies %s spawn | heading=%.0f | position=%.3f,%.3f,%.3f',row[1],heading,ground.x,ground.y,ground.z)) end
        layout[#layout+1]={kind=row[1],record=row[2],position=p,yaw=yaw,car=car}
    end
    return layout
end
function M.choose(heading,player)
    local failures={}
    for step=0,3 do
        local candidate=(heading+90*step)%360
        local ok,result=pcall(M.build,candidate,player)
        if ok then return result,candidate,table.concat(failures,' || '),step+1 end
        -- A bad API argument or missing service must remain a real error; only
        -- a known geometric/occupancy rejection permits another rotation.
        if type(result)~='string' or result:sub(1,#REJECTION)~=REJECTION then error(result,0) end
        failures[#failures+1]=string.format('%d deg: %s',candidate,result:sub(#REJECTION+1))
    end
    return nil,nil,table.concat(failures,' || '),4
end
return M
