-- VIP endpoints are baked against the native quest-marker catalogue. Live
-- mappins only supply scanner exclusions; discovery/unlock state is irrelevant.
local Catalog = require("marker_catalog")
local Routes = require("vip_route_catalog")
local LocationPolicy = require("dispatch_location_policy")
local M = {}
local function distance(a,b) return math.sqrt((a.x-b.x)^2+(a.y-b.y)^2+(a.z-b.z)^2) end
local function finite(p)
    return p and p.x==p.x and p.y==p.y and p.z==p.z and math.abs(p.x)<100000 and math.abs(p.y)<100000 and math.abs(p.z)<100000
end
function M.new()
    local locationInfo="Not selected"
    local recent={}
    local sites,ordered,routes={},{},{}
    assert(Routes.schema==1,"Install the complete VIP route catalogue and restart")
    local rows={}
    for _,row in ipairs(Catalog) do rows[row[1]]=row end
    for _,id in ipairs(Routes.sites) do
        local row=rows[id]
        assert(row and row[2]==false and not sites[id],"Invalid VIP terminal site: "..tostring(id))
        local point={x=row[3],y=row[4],z=row[5]}
        assert(finite(point) and LocationPolicy.allowed(nil,point,false),"Excluded VIP terminal site: "..id)
        sites[id]={position=point,id=id};ordered[#ordered+1]=sites[id]
    end
    for _,pair in ipairs(Routes.routes) do
        local pickup,drop=sites[pair[1]],sites[pair[2]]
        assert(pickup and drop and pickup~=drop,"Invalid baked VIP route")
        local metres=distance(pickup.position,drop.position)
        assert(metres>=500 and metres<=5000,"Invalid baked VIP trip length")
        routes[#routes+1]={pickup=pickup,drop=drop,trip=metres,id="vip_"..pair[1].."_"..pair[2]}
    end
    local function chooseLocations(player)
        local start=player:GetWorldPosition()
        assert(finite(start),"Player position unavailable for VIP route selection")
        local map=Game.GetMappinSystem()
        if not map then error("Mappin system unavailable for VIP scanner exclusions") end
        local occupied={}
        for _,pin in ipairs(map:GetAllMappins()) do
            local ok,variant,phaseNow,point=pcall(function() return pin:GetVariant(),pin:GetPhase(),pin:GetWorldPosition() end)
            if ok and finite(point) and (variant==gamedataMappinVariant.GangWatchVariant or variant==gamedataMappinVariant.OutpostVariant)
                and phaseNow~=gamedataMappinPhase.CompletedPhase then occupied[#occupied+1]=point end
        end
        local clear,metres={},{}
        local blocked,nearby,localRange,extended,nearest=0,0,0,0,math.huge
        for _,site in ipairs(ordered) do
            local safe=true
            for _,point in ipairs(occupied) do if distance(site.position,point)<100 then safe=false;break end end
            clear[site.id]=safe;metres[site.id]=distance(start,site.position)
            if safe then
                local d=metres[site.id];nearest=math.min(nearest,d)
                if d<250 then nearby=nearby+1 elseif d<=2000 then localRange=localRange+1 elseif d<=5000 then extended=extended+1 end
            else blocked=blocked+1 end
        end
        locationInfo=string.format("baked endpoints=%d | routes=%d | clear=%d | blocked by scanner=%d | clear <250 m=%d | clear 250-2000 m=%d | clear 2000-5000 m=%d | nearest clear=%s",
            #ordered,#routes,#ordered-blocked,blocked,nearby,localRange,extended,nearest<math.huge and string.format("%.0f m",nearest) or "none")
        local used={}
        for _,id in ipairs(recent) do used[id]=true end
        local last=recent[#recent]
        -- Keep the established response/trip bounds. Prefer fresh local routes
        -- before expanding; a small eligible pool may reuse a route to stay live.
        for _,limits in ipairs({{500,1000,800,2500},{500,1500,800,2500},{500,2000,800,2500},
            {250,2000,500,3500},{250,3500,500,5000},{250,5000,500,5000}}) do
            local all,fresh,different={},{},{}
            for _,route in ipairs(routes) do
                local d=metres[route.pickup.id]
                if clear[route.pickup.id] and clear[route.drop.id] and d>=limits[1] and d<=limits[2]
                    and route.trip>=limits[3] and route.trip<=limits[4] then
                    all[#all+1]=route
                    if not used[route.id] then fresh[#fresh+1]=route end
                    if route.id~=last then different[#different+1]=route end
                end
            end
            local choices=#fresh>0 and fresh or (#different>0 and different or all)
            if #choices>0 then
                local route=choices[math.random(1,#choices)]
                -- Remember selections, including failed setup attempts, so a
                -- bad endpoint is not retried indefinitely. No career ledger.
                recent[#recent+1]=route.id
                if #recent>Routes.recentSelections then table.remove(recent,1) end
                local d=metres[route.pickup.id]
                locationInfo=locationInfo.." | route="..route.id.." | pickup site="..route.pickup.id.." | delivery site="..route.drop.id
                    .." | radius="..limits[2].." m | pickup="..math.floor(d+.5).." m | trip="..math.floor(route.trip+.5).." m"
                -- Copies keep callers from modifying the canonical catalogue.
                local p,q=route.pickup.position,route.drop.position
                return {pickup=Vector4.new(p.x,p.y,p.z,1),drop=Vector4.new(q.x,q.y,q.z,1),
                    pickupSite=route.pickup.id,deliverySite=route.drop.id,routeID=route.id,
                    kind="baked route",distance=d}
            end
        end
        error("No eligible baked VIP route (pickup 250-5000 m; trip 500-5000 m). "..locationInfo)
    end
    local locations={choose=chooseLocations}
    function locations.reset() locationInfo="Not selected";recent={} end
    function locations.diagnostics() return locationInfo end
    return locations
end
return M
