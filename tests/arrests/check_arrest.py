from pathlib import Path
import sys
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
sys.path.insert(0,str(HERE))
from lupa.luajit21 import LuaRuntime
from translate import translate
lua=LuaRuntime(unpack_returned_tuples=True)
logs=[]
lua.globals().print=lambda *args: logs.append(' '.join(str(v) for v in args))
lua.execute(Path(HERE/'mappin-native-mocks.lua').read_text())
lua.globals().Patrol=lua.execute(translate(ROOT/'r6/scripts/NCPDPatrol/NCPDPatrolSystem.reds'))
lua.execute('function Patrol:GetGameInstance() return {} end')
lua.execute(Path(HERE/'support-native-mocks.lua').read_text())
lua.execute(Path(HERE/'arrest-native-mocks.lua').read_text())
lua.globals().ArrestNative=lua.execute(translate(ROOT/'r6/scripts/NCPDPatrol/NCPDPatrolArrestSystem.reds'))
lua.execute('function ArrestNative:GetGameInstance() return {} end')
lua.execute(Path(HERE/'arrest-native-scenarios.lua').read_text())
lua.globals().MOD_DIR=str(Path(ROOT/'bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrol').resolve())
lua.execute('package.path=MOD_DIR.."/?.lua;"..package.path')
lua.execute(Path(HERE/'arrest-cet-scenarios.lua').read_text())
assert any('No matching arrest clip after entry' in line for line in logs)
assert any('Arrest bank | loaded=true' in line for line in logs)
assert any('workspot=true | instance=false' in line for line in logs)
assert any('Arrest resource token | loaded=false | finished=false | failed=false' in line for line in logs)
assert any('Arrest resource token | loaded=true' in line for line in logs)
assert any('Arrest workspot asynchronous load failed' in line for line in logs)
print('PASS: independent 1000/250 scanner/arrest payments; eligibility/time/identity/receipt guards; actual CET controller: async property rejects ResourceHelper, pending token waits without replay/reload, loaded token starts explicit clip/play, failed/refused/finished-unloaded tokens never play or pay; bounded retry and three-second release; clip/ownership, menus, interactions, death/cleanup/load guards (native APIs mocked)')
