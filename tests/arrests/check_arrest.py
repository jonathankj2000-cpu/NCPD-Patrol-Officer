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
print('PASS: authored arrest eligibility/time/identity/payment/receipt guards, duplicate and stale callbacks, shifts/loads, failure cancellation, no healing or AI mutation; actual scanner and arrest ledgers pay 1000 and 250 independently; actual CET controller: resource/component/tree readiness, explicit clip/play, bounded retry and three-second release, no payment for void/incorrect/transition/foreign clips, stable owned clip pays once, menus/death/cleanup/load guards (native APIs mocked)')
