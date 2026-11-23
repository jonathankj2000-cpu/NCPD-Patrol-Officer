"""Scope the v0.20b receipt/return fix for earlier gameplay comparisons."""
import re

OLD_COMPLETION="""    if stage==3 then
        if phase~='complete' then
            if not n:IsSucceeded() then error('Scene ended without a proven journal completion') end
            phase='complete';say('Quest completed after goodbye. Briefing finished. Clear the test before replaying the conversation.')
            if context.onBriefingComplete then context.onBriefingComplete() end -- retained Voss continuation hook
        end
        if retaining() then maintainRetained(n,step) end -- retained Voss return hook
        return
    end
"""

def without_handoff_native(source):
    source=re.sub(r'^([ \t]*)// handoff (receipt|completion|journal proof) begin\n.*?^\1// handoff \2 end\n','',source,flags=re.M|re.S)
    source=re.sub(r'^.* // handoff receipt hook\n','',source,flags=re.M)
    return source.replace('public func Version() -> Int32 { return 5; }','public func Version() -> Int32 { return 4; }')

def without_handoff_lua(source):
    source=re.sub(r'^    -- handoff completion begin\n.*?^    -- handoff completion end\n',lambda _:OLD_COMPLETION,source,flags=re.M|re.S)
    source=source.replace('local handoffAge,handoffAccepted=0,false\n','')
    source=re.sub(r'^local function continueBriefing\(step\)\n.*?^end\n','',source,flags=re.M|re.S)
    source=re.sub(r'^.* -- handoff receipt hook\n','',source,flags=re.M)
    source=source.replace(';handoffAge,handoffAccepted=0,false','')
    source=source.replace('retaining() and n:HasBriefingReceipt() then','retaining() and n:GetStage()==3 then')
    source=source.replace('return owner():HasBriefingReceipt() end','return owner():IsSucceeded() end')
    return source.replace("n:Version()~=5 then error('Install the complete v0.20b quest giver package and restart the game')",
        "n:Version()~=4 then error('Install the complete v0.20a quest giver package and restart the game')")
