-- Observe the actual VIP facade, marker API and engine fixture outcomes. This
-- supplies no selection, navigation, timer, mounting or cleanup decisions.
local VIP = require('vip')
local f,v,n = CyberFixture,VIPFixture,VIPNative
local random=math.random
math.random=function(...)
    local result=random(...)
    Trace('random|'..table.concat({...},',')..'|'..result)
    return result
end
local function position(p) return p and table.concat({p.x,p.y,p.z},',') or '-' end
local function ordered(map,project)
    local keys,rows={},{}
    for key in pairs(map or {}) do keys[#keys+1]=key end
    table.sort(keys,function(a,b) return tostring(a)<tostring(b) end)
    for _,key in ipairs(keys) do rows[#rows+1]=tostring(key)..'='..project(map[key]) end
    return table.concat(rows,';')
end
local cursors={}
local function events(name,items,format)
    local cursor=cursors[name]
    if not cursor or cursor.items~=items or cursor.index>#items then cursor={items=items,index=0};cursors[name]=cursor end
    for index=cursor.index+1,#items do Trace(name..'|'..format(items[index])) end
    cursor.index=#items
end
local function flush()
    events('created',f.creates,function(spec) return tostring(spec.recordID)..'|'..position(spec.position) end)
    events('deleted',f.deletes,tostring)
    events('notice',f.notices,function(item) return table.concat({item.text,tostring(item.seconds),tostring(item.sound),tostring(item.voice)},'|') end)
    events('status',f.logs,tostring)
    events('journal-write',JournalFixture.writes,function(write) return tostring(write.path)..'='..tostring(write.state) end)
    events('reward-notice',notifications or {},tostring)
end
local function snapshot(name,result)
    flush()
    local rows={name,tostring(result),VIP.state(),VIP.isActive(),VIP.hasCleanup(),VIP.diagnostics(),
        n:GetStage(),n:GetToken(),n:GetRemainingSeconds(),n:GetReason(),
        IncidentNative:GetCompletedCount(),IncidentRewardFixture.wallet,IncidentRewardFixture.attempts,
        DispatchRewardFixture.wallet,#f.creates,#f.deletes,v.registrations,#v.unregistrations,
        ordered(v.pins,function(pin) return position(pin.point)..','..tostring(pin.active)..','..tostring(pin.hidden) end),
        ordered(f.managed,tostring),
        ordered(f.actors,function(actor)
            return table.concat({actor.record or '-',position(actor.pos),tostring(actor.dead),tostring(actor.defeated),
                tostring(actor.mounted and actor.mounted.id.hash),#(actor.commands or {})},',')
        end)}
    for i=1,#rows do rows[i]=tostring(rows[i]) end
    Trace(table.concat(rows,'|'))
end
local getMap=Game.GetMappinSystem
Game.GetMappinSystem=function(...)
    local map=getMap(...)
    if not map then Trace('map-unavailable');return nil end
    return {
        GetAllMappins=function() Trace('map-inspect');return map:GetAllMappins() end,
        UnregisterMappin=function(_,id) Trace('map-remove|'..tostring(id.value));return map:UnregisterMappin(id) end,
        SetMappinActive=function(_,id,active) Trace('map-active|'..tostring(id.value)..'|'..tostring(active));return map:SetMappinActive(id,active) end,
        SetMappinPosition=function(_,id,point) Trace('map-move|'..tostring(id.value)..'|'..position(point));return map:SetMappinPosition(id,point) end,
    }
end
local place=f.patrol.PlaceDispatchWaypoint
function f.patrol:PlaceDispatchWaypoint(point)
    Trace('map-place|'..position(point))
    local result=place(self,point)
    Trace('map-placed|'..tostring(result and result.value))
    return result
end
local exports={}
for name,fn in pairs(VIP) do if type(fn)=='function' then exports[#exports+1]=name end end
table.sort(exports);Trace('vip-exports|'..table.concat(exports,','))
for _,name in ipairs({'reset','request','requestAmbush','refreshWaypoint','finish','cancel','update','cycleAmbushCars'}) do
    local original=VIP[name]
    VIP[name]=function(...)
        local result=original(...)
        snapshot(name,result)
        return result
    end
end
