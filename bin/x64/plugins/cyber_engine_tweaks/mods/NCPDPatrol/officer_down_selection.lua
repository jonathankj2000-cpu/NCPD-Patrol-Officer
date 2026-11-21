-- Pure catalogue selection. Temporary gameplay failures never blacklist a site.
local Catalog=require('officer_down_sites')
local M={}
local recent,blocked,clock={},{},0
function M.reset() recent,blocked,clock={},{},0 end
function M.advance(delta) if delta>0 and delta<=.5 then clock=clock+delta end end
function M.remember(id)
    for i=#recent,1,-1 do if recent[i]==id then table.remove(recent,i) end end
    recent[#recent+1]=id;if #recent>3 then table.remove(recent,1) end
end
function M.block(id) if id then blocked[id]=clock+120 end end
function M.choose(origin)
    if not origin or origin.x~=origin.x or origin.y~=origin.y or origin.z~=origin.z then return nil,0,0,'Invalid player position' end
    for _,radius in ipairs({1000,2000,5000}) do
        local pool,fresh={},{}
        for _,site in ipairs(Catalog.sites) do
            local d=math.sqrt((site.x-origin.x)^2+(site.y-origin.y)^2+(site.z-origin.z)^2)
            if site.enabled and d>=500 and d<=radius and (blocked[site.id] or 0)<=clock then
                local row={site=site,distance=d};pool[#pool+1]=row
                local used=false;for _,id in ipairs(recent) do if id==site.id then used=true end end
                if not used then fresh[#fresh+1]=row end
            end
        end
        if #pool>0 then
            local choices=#fresh>0 and fresh or pool
            local row=choices[math.random(1,#choices)]
            return row.site,row.distance,radius,'Nearest search band; '..#pool..' eligible sites'
        end
    end
    return nil,0,5000,'No surveyed Officer Down site 500-5000 m away, or sites temporarily cooling down'
end
return M
