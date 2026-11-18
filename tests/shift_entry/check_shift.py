"""Run the actual CET entrypoint and trunk bridge for shift start/end.

Native Version() boundary values come from the shipped redscript interfaces,
so a stale Lua gate is exercised against the independently installed contract.
"""
from pathlib import Path
import re,sys
from lupa.luajit21 import LuaRuntime
HERE=Path(__file__).resolve().parent
ROOT=Path(sys.argv[1]).resolve() if len(sys.argv)>1 else HERE.parents[1]
lua=LuaRuntime(unpack_returned_tuples=True)
lua.globals().MOD_DIR=str(ROOT/'bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrol')
versions={}
for name in ['NCPDPatrolSystem','NCPDPatrolSupportSystem','NCPDPatrolTrunkSystem']:
 text=(ROOT/'r6/scripts/NCPDPatrol'/f'{name}.reds').read_text()
 match=re.search(r'public func Version\(\) -> Int32 \{ return (\d+); \}',text);assert match,name
 versions[name]=int(match[1])
lua.globals().NativeVersions=lua.table_from(versions)
lua.execute('package.path=MOD_DIR.."/?.lua;"..package.path')
lua.execute((HERE/'scenarios.lua').read_text())
print('PASS: actual init.lua + trunk.lua start/end via CET, native fast travel request and hotkey; current installed interfaces, old/missing trunk refusal, no partial start, retry and duplicate-start guards (engine boundaries mocked)')
