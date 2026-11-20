-- Geographic selection and diagnostics for VIP transport only. This policy is
-- deliberately separate from cyberpsycho placement and witness navigation.
local M = {}
local LocationPolicy = require("dispatch_location_policy")
function M.new()
    local locationInfo="Not selected"
    local function distance(a,b) return math.sqrt((a.x-b.x)^2+(a.y-b.y)^2+(a.z-b.z)^2) end
    local function finite(p)
        return p and p.x==p.x and p.y==p.y and p.z==p.z and math.abs(p.x)<100000 and math.abs(p.y)<100000 and math.abs(p.z)<100000
    end
    local function chooseLocations(player)
        local pins=Game.GetMappinSystem():GetAllMappins()
        local sites,occupied,seen={},{},{}
        local terminals,dropPoints=0,0
        local start=player:GetWorldPosition()
        for _,pin in ipairs(pins) do
            -- Interaction availability is not geographic availability: native
            -- fast travel can be inactive while V is in a car or during a lock.
            local ok,variant,phaseNow,point=pcall(function() return pin:GetVariant(),pin:GetPhase(),pin:GetWorldPosition() end)
            if ok and finite(point) and (point.x~=0 or point.y~=0 or point.z~=0) then
                if (variant==gamedataMappinVariant.FastTravelVariant
                    or variant==gamedataMappinVariant.ServicePointDropPointVariant)
                    and LocationPolicy.allowed(pin,point,variant==gamedataMappinVariant.FastTravelVariant) then
                    local key=string.format("%.1f:%.1f:%.1f",point.x,point.y,point.z)
                    if not seen[key] then
                        seen[key]=true
                        local kind=variant==gamedataMappinVariant.FastTravelVariant and "fast travel" or "drop point"
                        if kind=="fast travel" then terminals=terminals+1 else dropPoints=dropPoints+1 end
                        sites[#sites+1]={position=Vector4.new(point.x,point.y,point.z,1),distance=distance(start,point),kind=kind}
                    end
                elseif (variant==gamedataMappinVariant.GangWatchVariant or variant==gamedataMappinVariant.OutpostVariant)
                    and phaseNow~=gamedataMappinPhase.CompletedPhase then occupied[#occupied+1]=point end
            end
        end
        local safe={}
        for _,site in ipairs(sites) do
            local clear=true
            for _,point in ipairs(occupied) do if distance(site.position,point)<100 then clear=false;break end end
            if clear then safe[#safe+1]=site end
        end
        local nearby,localRange,extended,nearest=0,0,0,math.huge
        for _,site in ipairs(safe) do
            nearest=math.min(nearest,site.distance)
            if site.distance<250 then nearby=nearby+1
            elseif site.distance<=2000 then localRange=localRange+1
            elseif site.distance<=5000 then extended=extended+1 end
        end
        locationInfo=string.format("fast travel=%d | drop points=%d | clear=%d | blocked by scanner=%d | clear <250 m=%d | clear 250-2000 m=%d | clear 2000-5000 m=%d | nearest clear=%s",
            terminals,dropPoints,#safe,#sites-#safe,nearby,localRange,extended,nearest<math.huge and string.format("%.0f m",nearest) or "none")
        -- Prefer short routes, then relax proximity/trip length before expanding
        -- the pickup radius. Native validation and response time use the same caps.
        -- This reads markers only; no travel node is unlocked or registered.
        for _,limits in ipairs({{500,1000,800,2500},{500,1500,800,2500},{500,2000,800,2500},
            {250,2000,500,3500},{250,3500,500,5000},{250,5000,500,5000}}) do
            for _,includeDropPoints in ipairs({false,true}) do
                local pairs={}
                for _,site in ipairs(safe) do
                    if (includeDropPoints or site.kind=="fast travel") and site.distance>=limits[1] and site.distance<=limits[2] then
                        local drops={}
                        for _,drop in ipairs(safe) do
                            local metres=distance(site.position,drop.position)
                            if (includeDropPoints or drop.kind=="fast travel") and metres>=limits[3] and metres<=limits[4] then drops[#drops+1]=drop end
                        end
                        if #drops>0 then
                            local drop=drops[math.random(1,#drops)]
                            pairs[#pairs+1]={pickup=site.position,drop=drop.position,kind=site.kind.." -> "..drop.kind}
                        end
                    end
                end
                if #pairs>0 then
                    local pair=pairs[math.random(1,#pairs)]
                    pair.distance=distance(start,pair.pickup)
                    locationInfo=locationInfo.." | selected="..pair.kind.." | radius="..limits[2].." m | pickup="..math.floor(pair.distance+.5).." m | trip="..math.floor(distance(pair.pickup,pair.drop)+.5).." m"
                    return pair
                end
            end
        end
        error("No safe VIP terminal pair after expanded search (pickup 250-5000 m; trip 500-5000 m). "..locationInfo)
    end
    local locations = {choose=chooseLocations}
    function locations.reset() locationInfo="Not selected" end
    function locations.diagnostics() return locationInfo end
    return locations
end
return M
