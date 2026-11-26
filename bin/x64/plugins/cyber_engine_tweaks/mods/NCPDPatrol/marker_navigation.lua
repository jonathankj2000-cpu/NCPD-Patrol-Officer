-- Finite-location journal pins. Logical handles are never passed to engine APIs.
local catalog=require('marker_catalog')
local M={}
local owner,token,revision=nil,nil,-1
local function native()
    if not M.worldReady() then return nil end
    local container=Game.GetScriptableSystemsContainer()
    local system=container and container:Get('NCPDPatrolFixedMarkerSystem')
    if system and system:Version()~=4 then error('Install the complete r5c fixed marker package and restart') end
    return system
end
function M.worldReady()
    if not Game then return false end
    -- Historical comparison fixtures have no Codeware service API. A complete
    -- game install has it, and missing/unready service fails closed there.
    if not Game.GetScriptableServiceContainer then return true end
    local ok,ready=pcall(function()
        local container=Game.GetScriptableServiceContainer()
        local service=container and container:GetService('NCPDPatrolMarkerSession')
        return service and service:IsReady() or false
    end)
    return ok and ready or false
end
function M.isBank(handle) return type(handle)=='table' and handle.fixedMarker==true end
local function match(point,scanner)
    local best,metres=0,4 -- squared two-metre tolerance
    for _,site in ipairs(catalog) do
        if site[2]==scanner then
            local d=(point.x-site[3])^2+(point.y-site[4])^2+(point.z-site[5])^2
            if d<metres then best,metres=site[1],d end
        end
    end
    return best
end
function M.place(patrol,point,who)
    if not M.worldReady() then error("Game session is not ready for a dispatch marker") end
    local backend=native()
    -- Compatibility boundary for older installs/test fixtures. Complete r5
    -- always has the native bank; it never uses CustomPositionVariant.
    if not backend then return patrol:PlaceDispatchWaypoint(point) end
    local scope=backend:GetScope()
    local site=match(point,scope>=0 and scope<6)
    local nextToken=backend:Request(site,point)
    if not nextToken or nextToken<=0 then error('Fixed quest marker request rejected: '..backend:GetDiagnostics()) end
    owner,token=who,nextToken
    return {value=nextToken,fixedMarker=true}
end
function M.release(handle)
    if not M.isBank(handle) then return false end
    local backend=native()
    if backend then backend:Stop(handle.value) end
    if token==handle.value then owner,token=nil,nil end
    return true
end
function M.clear(who)
    if owner~=who or not token then return end
    local backend=native()
    if backend then backend:Stop(token) end
    owner,token=nil,nil
end
function M.describe(handle,previous)
    if not M.isBank(handle) then return previous end
    local ok,text=pcall(function()
        local backend=native()
        if not backend then return 'Fixed marker backend unavailable' end
        if not backend:IsActive(handle.value) then return 'Fixed marker no longer active' end
        return backend:GetStatus()
    end)
    return ok and text or tostring(text)
end
function M.diagnostics()
    local ok,text=pcall(function()
        local backend=native()
        return backend and backend:GetDiagnostics() or 'Fixed marker backend unavailable; install complete r5c package'
    end)
    return ok and text or tostring(text)
end
function M.lastNative()
    local ok,text=pcall(function()
        local backend=native()
        return backend and backend:GetLastNativeProbe() or 'Fixed marker backend unavailable'
    end)
    return ok and text or tostring(text)
end
function M.reset() owner,token,revision=nil,nil,-1 end
function M.finish()
    local backend=native()
    if backend then backend:Stop(0) end
    owner,token=nil,nil
end
function M.update(delta,status)
    if not M.worldReady() then M.reset();return end
    local ok,err=pcall(function()
        local backend=native()
        if not backend then return end
        backend:Tick(delta)
        local current=backend:GetRevision()
        if current~=revision then
            revision=current
            if status and backend:HasWork() then status('Fixed markers | '..backend:GetDiagnostics()) end
        end
    end)
    if not ok and revision~=-2 then
        revision=-2
        if status then status('Fixed marker update failed: '..tostring(err)) end
    end
end
return M
