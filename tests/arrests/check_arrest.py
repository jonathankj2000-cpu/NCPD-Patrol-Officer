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
lua.globals().PlaybackPrototype=lua.execute(translate(ROOT/'r6/scripts/NCPDPatrol/NCPDPatrolArrestPlayback.reds'))
lua.execute('NCPDPatrolArrestPlayback={new=function() return setmetatable({}, {__index=PlaybackPrototype}) end}')
lua.globals().ArrestNative=lua.execute(translate(ROOT/'r6/scripts/NCPDPatrol/NCPDPatrolArrestSystem.reds'))
lua.execute('function ArrestNative:GetGameInstance() return {} end')
lua.execute(Path(HERE/'arrest-native-scenarios.lua').read_text())
import tempfile
with tempfile.TemporaryDirectory(prefix='ncpd-result-wrapper-') as scratch:
    event=Path(ROOT/'r6/scripts/NCPDPatrol/NCPDPatrolArrestEvents.reds').read_text()
    event=event[event.index('protected cb func'):].replace('protected cb func','public func')
    wrapper=Path(scratch)/'ResultWrapper.reds'
    wrapper.write_text('public class ResultWrapper extends IScriptable {\n'+event+'\n}')
    lua.globals().ResultReceiver=lua.execute(translate(wrapper))
lua.globals().MOD_DIR=str(Path(ROOT/'bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrol').resolve())
lua.execute('package.path=MOD_DIR.."/?.lua;"..package.path')
lua.execute(Path(HERE/'arrest-cet-scenarios.lua').read_text())
assert any('source=native activation fallback' in line for line in logs)
assert any('source=native play result' in line for line in logs)
assert any('Registered via native activation fallback' in line for line in logs)
assert any('observed clip=unavailable' in line for line in logs)
assert any('Arrest hold | lying clip reselected' in line for line in logs)
print('PASS: actual activation proof/controller/result handler: absent debug callbacks and nil legacy lookups; stable clean native entry pays once; exact-helper positive/negative/stale results; no-entry/transition/paused/dead/range/wanted/load guards; one-second hold budget; async resource failures; independent scanner/arrest 1000/250 payments (native APIs mocked)')
