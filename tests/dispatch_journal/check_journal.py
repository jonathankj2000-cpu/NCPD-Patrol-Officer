"""Execute authored journal controller and actual CET dispatch modules."""
from pathlib import Path
import sys, json, importlib.util
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
assert 'TrackEntry(null)' not in src
assert 'm_paidActivities' not in src and 'm_paidSuspects' not in src
spec=importlib.util.spec_from_file_location('build_dispatch_assets',ROOT/'tools/build_dispatch_assets.py')
builder=importlib.util.module_from_spec(spec);spec.loader.exec_module(builder)
builder.validate(json.loads((ROOT/'assets/dispatch/dispatch.journal.json').read_text()),json.loads((ROOT/'assets/dispatch/dispatch_onscreens.json.json').read_text()))
print('PASS: actual journal/dispatch logic: six briefings, deadline/arrival, success/fail/cancel, tracking/load/reuse, exactly-once EUR$500 supplements and durable failed-payment retries; separate scanner/arrest ledgers (native APIs mocked)')
