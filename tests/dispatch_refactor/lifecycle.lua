-- Run after every real coordinator command, including rejected/cancelled calls,
-- no-attachment cleanup, delayed despawn and concurrent background scenes.
local D, VIP, Cyber = require('dispatch'), require('vip'), require('cyberpsycho')
local commands = {'start','finish','reset','request','requestMixed','requestVIP','requestCyberpsycho',
    'cancel','replace','update','shutdown'}
local function check()
    local before={D.seconds(),#CyberFixture.creates,#CyberFixture.deletes,VIPNative:GetToken(),CyberNative:GetToken()}
    local random=math.random
    math.random=function() error('A lifecycle read consumed a random draw') end
    local state=D.lifecycle()
    -- Mutating a snapshot cannot mutate module-owned state.
    state.vip.phase='caller mutation';state.vip.reserved=not state.vip.reserved
    state=D.lifecycle()
    math.random=random
    assert(state.reserved==D.isActive(),'facade reservation disagrees with lifecycle')
    assert(state.vip.reserved==VIP.isActive() and state.cyberpsycho.reserved==Cyber.isActive())
    for _,entry in ipairs({state.vip,state.cyberpsycho}) do
        assert(entry.reserved==(entry.assignment or entry.foregroundCleanup))
        assert(not (entry.assignment and entry.foregroundCleanup))
    end
    assert(state.foregroundCleanup==(state.vip.foregroundCleanup or state.cyberpsycho.foregroundCleanup))
    assert(state.backgroundCleanup==(state.vip.backgroundCleanup or state.cyberpsycho.backgroundCleanup))
    assert(D.seconds()==before[1] and #CyberFixture.creates==before[2] and #CyberFixture.deletes==before[3])
    assert(VIPNative:GetToken()==before[4] and CyberNative:GetToken()==before[5])
end
for _,name in ipairs(commands) do
    local original=D[name]
    D[name]=function(...)
        local result=original(...)
        check()
        return result
    end
end
