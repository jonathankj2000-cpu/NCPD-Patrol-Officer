-- One convoy per VIP transport. Each car owns its actors, commands and cleanup.
-- World resets forget old handles; ordinary cleanup retains every refused ID.
local Unit=require("vip_ambush_unit")
local M={}
local workers={}
local retired={}
local mode=0 -- 0 random 1-3, otherwise an exact 1/2/3-car test preference.
local begun,ended,requested,warned,lostNotified=false,false,false,false,false
local spawnWindow,sawEscape=0,false

local function started()
    for _,worker in ipairs(workers) do if worker.hasStarted() then return true end end
    return false
end
function M.isActive()
    for _,worker in ipairs(workers) do if worker.isActive() then return true end end
    return false
end
function M.hasCleanup() return #retired>0 end
function M.retainedCount() return #retired end
function M.canBegin() return not M.isActive() and #retired<3 end
function M.setting() return mode==0 and "Random (1-3)" or tostring(mode).." car"..(mode==1 and "" or "s") end
function M.state()
    local labels={}
    for i,worker in ipairs(workers) do labels[#labels+1]="Car "..i..": "..worker.state() end
    for i,scene in ipairs(retired) do
        for j,worker in ipairs(scene) do labels[#labels+1]="Previous scene "..i..", car "..j..": "..worker.state() end
    end
    if #labels==0 then return "No ambush this trip" end
    return "Current cars="..#workers.." | background scenes="..#retired.."/3 | "..table.concat(labels," | ")
end
local function resetCurrent()
    workers={};begun,ended,requested,warned,lostNotified=false,false,false,false,false
    spawnWindow,sawEscape=0,false
end
function M.reset()
    -- Only a world transition may forget IDs from retained scenes.
    resetCurrent();retired={}
end
local function canSpawnAt(point,own)
    local scenes={workers}
    for _,scene in ipairs(retired) do scenes[#scenes+1]=scene end
    for _,scene in ipairs(scenes) do
        for _,other in ipairs(scene) do
            if other~=own then
                local position=other.position()
                if position then
                    if position.x~=position.x or position.y~=position.y or position.z~=position.z then return false end
                    local x,y,z=position.x-point.x,position.y-point.y,position.z-point.z
                    if x*x+y*y+z*z<144 then return false end
                end
            end
        end
    end
    return true
end
local function notice(patrol,text)
    if text:find("Possible hostile vehicle",1,true) then
        if not warned then
            warned=true
            if patrol then patrol:NotifyDispatch("NCPD: Possible hostile vehicle"..(#workers>1 and "s" or "").." behind your transport. Keep the witness safe.",8) end
        end
    elseif text:find("Hostile vehicle lost",1,true) then
        sawEscape=true
    end
end
local function buildWorkers()
    workers={}
    local count=mode==0 and math.random(1,3) or mode
    local trigger=math.random(250,400)
    for _=1,count do
        local worker
        worker=Unit.new({triggerAt=trigger,notify=notice,canSpawnAt=function(point) return canSpawnAt(point,worker) end})
        worker.begin();workers[#workers+1]=worker
    end
end
function M.begin()
    if not M.canBegin() then return false end
    resetCurrent();begun=true;buildWorkers();return true
end
function M.configure(value,status)
    if type(value)~="number" or value~=value or value%1~=0 or value<0 or value>3 then return false end
    mode=value
    local deferred=started() or M.isActive() or ended
    if begun and not deferred then
        buildWorkers()
        if requested then for _,worker in ipairs(workers) do worker.request() end end
    end
    if status then status("VIP ambush cars: "..M.setting()..(deferred and " (next transport)" or "")) end
    return true
end
function M.cycle(status) return M.configure((mode+1)%4,status) end
function M.request(status)
    if not begun or ended or started() then
        if status then status("VIP ambush | This trip has already used its ambush") end
        return false
    end
    requested=true
    for _,worker in ipairs(workers) do worker.request() end
    if status then status("VIP ambush | "..#workers.." car(s) armed; waiting for separate checked road positions") end
    return true
end
function M.clearRetired(status)
    for i=#retired,1,-1 do
        local gone=true
        for _,worker in ipairs(retired[i]) do if not worker.finish(status) then gone=false end end
        if gone then table.remove(retired,i) end
    end
end
function M.finish(status,keepResolvedScene)
    ended=true;requested=false
    if keepResolvedScene and #retired<3 then
        local scene,remaining={},{}
        for _,worker in ipairs(workers) do
            if worker.canRetire() then scene[#scene+1]=worker else remaining[#remaining+1]=worker end
        end
        if #scene>0 then
            retired[#retired+1]=scene;workers=remaining
            if status then status("VIP ambush | Neutralized scene moved to background cleanup; dispatch reservation released") end
        end
    end
    local complete=true
    for _,worker in ipairs(workers) do
        if not worker.finish(status,keepResolvedScene) then complete=false end
    end
    return complete
end
function M.update(delta,vehicle,transporting,nearDestination,patrol,status)
    -- These workers own no VIP token, marker or assignment slot. Refused
    -- deletion keeps their IDs in this bounded queue, never the dispatcher.
    for i=#retired,1,-1 do
        local gone=true
        for _,worker in ipairs(retired[i]) do
            worker.update(delta,nil,false,true,patrol,status)
            if worker.isActive() then gone=false end
        end
        if gone then table.remove(retired,i) end
    end
    local ticks=delta>0 and delta<=.5 and patrol and not patrol:IsDispatchMenuOpen()
    if ticks and transporting and not ended and started() then
        spawnWindow=spawnWindow+delta
        if spawnWindow>=20 then
            -- Do not add a late car long after the original attack. Existing
            -- cars/cleanup keep their own reservation and continue normally.
            for _,worker in ipairs(workers) do
                local phase=worker.stage()
                if worker.canStart() or phase=="spawning" or phase=="seating" then worker.finish() end
            end
        end
    end
    for i,worker in ipairs(workers) do
        local log=status and function(text) status(#workers>1 and ("Convoy car "..i.." | "..text) or text) end or nil
        worker.update(delta,vehicle,transporting and not ended,nearDestination,patrol,log)
    end
    if ticks and sawEscape and not lostNotified and not ended then
        local threat,pending=false,false
        for _,worker in ipairs(workers) do
            local phase=worker.stage()
            if phase~="idle" and phase~="resolved" and phase~="cleanup" then threat=true end
            if not worker.hasStarted() then pending=true end
        end
        if not threat and not pending then
            lostNotified=true
            patrol:NotifyDispatch("NCPD: Hostile vehicle"..(#workers>1 and "s" or "").." lost. Continue to the safe location.",8)
        end
    end
end
return M
