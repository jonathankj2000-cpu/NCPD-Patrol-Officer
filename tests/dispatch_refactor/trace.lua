-- Observe the public facade and real native/actor fixtures after each command.
-- This does not define scheduling/results: v0.17d is the comparison oracle.
local D = require('dispatch')
local f, v = CyberFixture, VIPFixture
local random = math.random
math.random = function(...)
    local result = random(...)
    Trace('random|'..table.concat({...}, ',')..'|'..result)
    return result
end
local function ordered(map, project)
    local keys, rows = {}, {}
    for key in pairs(map or {}) do keys[#keys+1] = key end
    table.sort(keys, function(a,b) return tostring(a) < tostring(b) end)
    for _, key in ipairs(keys) do rows[#rows+1] = tostring(key)..'='..project(map[key]) end
    return table.concat(rows, ';')
end
local function position(p)
    return p and table.concat({p.x,p.y,p.z}, ',') or '-'
end
local function array(a, project)
    local rows = {}
    for _, item in ipairs(a or {}) do rows[#rows+1] = project(item) end
    return table.concat(rows, ';')
end
local function scalar(value) return tostring(value) end
local function snapshot(name, result)
    local rows = {name, tostring(result), D.state(), D.isActive(), D.isAutomatic(), D.isBusy(),
        D.seconds(), D.completed(), D.failedCount(), D.lastOutcome(), D.candidates(),
        D.navigationState(), D.isSoundEnabled(), D.isVoiceEnabled(), D.schedulerStatus(f.patrol),
        f.hud.text, f.hud.visible, DispatchJournalNative:GetStage(), DispatchJournalNative:GetToken(),
        DispatchJournalNative:GetRemainingSeconds(), DispatchJournalNative:GetPaidDispatches(),
        DispatchJournalNative:GetPendingDispatchRewards(), VIPNative:GetStage(), VIPNative:GetToken(),
        VIPNative:GetRemainingSeconds(), CyberNative:GetStage(), CyberNative:GetToken(),
        CyberNative:GetRemainingSeconds(), IncidentNative:GetCompletedCount(), IncidentRewardFixture.wallet,
        IncidentRewardFixture.attempts, DispatchRewardFixture.wallet, #f.creates, #f.deletes,
        #JournalFixture.writes, #f.notices, #v.unregistrations, v.registrations,
        ordered(f.managed, scalar), ordered(v.pins, function(pin) return position(pin.point)..','..tostring(pin.active) end),
        ordered(f.actors, function(actor)
            return table.concat({actor.record or '-',position(actor.pos),tostring(actor.dead),tostring(actor.defeated),
                tostring(actor.mounted and actor.mounted.id.hash),#(actor.commands or {})}, ',')
        end),
        array(f.markers, position),
        array(f.notices, function(notice)
            return table.concat({notice.text,tostring(notice.seconds),tostring(notice.sound),tostring(notice.voice)}, ',')
        end),
        array(JournalFixture.writes, function(write) return tostring(write.path)..'='..tostring(write.state) end),
    }
    for i=1,#rows do rows[i]=tostring(rows[i]) end
    Trace(table.concat(rows, '|'))
end
local commands = {'start','finish','reset','setAutomatic','setBusy','setSoundEnabled','setVoiceEnabled',
    'request','requestMixed','requestVIP','requestCyberpsycho','requestVIPAmbush','cancel','replace',
    'armTimeoutTest','refreshVIPWaypoint','update','shutdown'}
for _, name in ipairs(commands) do
    local original = D[name]
    D[name] = function(...)
        local result = original(...)
        snapshot(name, result)
        return result
    end
end
-- Useful when updating the facade: each pre-refactor public entry must survive.
local exports = {}
-- Explicit additive prototype API is checked by the Officer Down integration
-- suite; this historical observer still verifies every original public entry.
local sceneAPI={requestOfficerDown=true,officerDownState=true,officerDownDiagnostics=true,rotateOfficerDown=true,reviveOfficerDown=true,clearOfficerDown=true,
 requestOfficerDownNearby=true,officerDownLogState=true,exportOfficerDownLog=true,officerDownCatalogueInfo=true}
for name, fn in pairs(D) do if type(fn)=='function' and name~='lifecycle' and not sceneAPI[name] then exports[#exports+1]=name end end
table.sort(exports)
Trace('exports|'..table.concat(exports, ','))
