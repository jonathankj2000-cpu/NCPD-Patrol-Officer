"""Execute readiness plus actual partner/backup integration at native boundaries."""
from pathlib import Path
import sys
from lupa.luajit21 import LuaRuntime
HERE=Path(__file__).resolve().parent
ROOT=Path(sys.argv[1]).resolve() if len(sys.argv)>1 else HERE.parents[1]
lua=LuaRuntime(unpack_returned_tuples=True)
lua.globals().MOD_DIR=str(ROOT/'bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrol')
lua.execute('package.path=MOD_DIR.."/?.lua;"..package.path')
lua.execute((HERE/'scenarios.lua').read_text())
print('PASS: own partner/backup draw/holster mirrors V outside combat; native alert/combat priority, pending holster cancellation, menus, mount/down/revive, bounded retries, isolated API failure and lifecycle; movement/combat commands preserved (engine APIs mocked)')
