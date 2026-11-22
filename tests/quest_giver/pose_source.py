"""Remove only the reviewed v0.19h1 idle-only request for baseline comparisons."""
import re

def without_idle_only_pose(source):
    source=re.sub(r'^    // idle-only pose begin\n.*?^    // idle-only pose end\n','',source,flags=re.M|re.S)
    return source.replace('public func Version() -> Int32 { return 3; }','public func Version() -> Int32 { return 2; }')

def without_idle_only_lua(source):
    source=re.sub(r'^        -- idle-only pose begin\n.*?^        -- idle-only pose end\n','',source,flags=re.M|re.S)
    return source.replace("n:Version()~=3 then error('Install the complete v0.19h1 quest giver package and restart the game')",
                          "n:Version()~=2 then error('Install the complete v0.19e quest giver package and restart the game')")
