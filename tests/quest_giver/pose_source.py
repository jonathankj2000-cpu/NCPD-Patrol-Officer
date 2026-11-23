"""Remove only the reviewed v0.19h1 idle-only request for baseline comparisons."""
import re

def without_retained_native(source):
    source=source.replace('public func Version() -> Int32 { return 4; }','public func Version() -> Int32 { return 3; }')
    return source.replace('(this.GetStage() != 1 && this.GetStage() != 3)','this.GetStage() != 1')

def without_retained_lua(source):
    source=re.sub(r'^-- retained Voss helpers begin\n.*?^-- retained Voss helpers end\n','',source,flags=re.M|re.S)
    source=source.replace("        if retaining() and n:GetStage()==3 then phase='complete' -- retained Voss recovery hook\n        elseif #rows>0 or n:GetStage()~=0 then M.clear() end",
                          "        if #rows>0 or n:GetStage()~=0 then M.clear() end")
    source=re.sub(r'^.* -- retained Voss (?:clear|continuation|return|error) hook\n','',source,flags=re.M)
    source=source.replace('if ready() and M.active() and not retaining() then','if ready() and M.active() then')
    return source.replace("n:Version()~=4 then error('Install the complete v0.20a quest giver package and restart the game')",
                          "n:Version()~=3 then error('Install the complete v0.19h1 quest giver package and restart the game')")

def without_idle_only_pose(source):
    source=without_retained_native(source)
    source=re.sub(r'^    // idle-only pose begin\n.*?^    // idle-only pose end\n','',source,flags=re.M|re.S)
    return source.replace('public func Version() -> Int32 { return 3; }','public func Version() -> Int32 { return 2; }')

def without_idle_only_lua(source):
    source=without_retained_lua(source)
    source=re.sub(r'^        -- idle-only pose begin\n.*?^        -- idle-only pose end\n','',source,flags=re.M|re.S)
    return source.replace("n:Version()~=3 then error('Install the complete v0.19h1 quest giver package and restart the game')",
                          "n:Version()~=2 then error('Install the complete v0.19e quest giver package and restart the game')")
