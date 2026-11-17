"""Execute authored journal controller and actual CET dispatch modules."""
from pathlib import Path
import sys
HERE=Path(__file__).resolve().parent
ROOT=Path(sys.argv[1]).resolve() if len(sys.argv)>1 else HERE.parents[1]
sys.path.insert(0,str(HERE.parent/'arrests'))
from lupa.luajit21 import LuaRuntime
from translate import translate
lua=LuaRuntime(unpack_returned_tuples=True)
logs=[];lua.globals().print=lambda *args:logs.append(' '.join(str(v) for v in args))
lua.globals().DispatchJournalNative=lua.execute(translate(ROOT/'r6/scripts/NCPDPatrol/NCPDPatrolDispatchJournalSystem.reds'))
lua.execute((HERE/'native-mocks.lua').read_text())
lua.globals().MOD_DIR=str(ROOT/'bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrol')
lua.execute('package.path=MOD_DIR.."/?.lua;"..package.path')
lua.execute((HERE/'scenarios.lua').read_text())
src=(ROOT/'r6/scripts/NCPDPatrol/NCPDPatrolDispatchJournalSystem.reds').read_text()
assert 'CreateScriptedQuestFromTemplate' not in src
assert 'GetTransactionSystem' not in src and 'GiveItem' not in src and 'TrackEntry(null)' not in src
print('PASS: journal controller and dispatcher: arrival/deadline boundary, pause, success/fail/cancel, reuse/rejection, assets, tracking, stale tokens, load cleanup and separate scanner rewards (native APIs mocked)')
