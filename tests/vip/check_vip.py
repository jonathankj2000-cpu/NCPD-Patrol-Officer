"""Run the authored native quest and actual CET VIP/ambush/dispatcher modules.

Only engine APIs, animation completion and vehicle physics are mocked. This
cannot verify live traffic pathfinding, animation or seat behaviour in game.
"""
from pathlib import Path
import importlib.util,json,sys
HERE=Path(__file__).resolve().parent
ROOT=Path(sys.argv[1]).resolve() if len(sys.argv)>1 else HERE.parents[1]
sys.path.insert(0,str(HERE.parent/'arrests'))
from translate import translate
from lupa.luajit21 import LuaRuntime
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute((HERE.parent/'arrests/mappin-native-mocks.lua').read_text())
for file,name in [('NCPDPatrolCyberpsychoSystem.reds','CyberNative'),('NCPDPatrolDispatchJournalSystem.reds','DispatchJournalNative'),('NCPDPatrolVIPSystem.reds','VIPNative')]:
 lua.globals()[name]=lua.execute(translate(ROOT/'r6/scripts/NCPDPatrol'/file))
lua.execute((HERE.parent/'dispatch_journal/native-mocks.lua').read_text())
lua.execute((HERE.parent/'cyberpsycho/native-mocks.lua').read_text())
lua.globals().MOD_DIR=str(ROOT/'bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrol')
lua.execute('package.path=MOD_DIR.."/?.lua;"..package.path')
lua.execute((HERE/'native-mocks.lua').read_text())
lua.execute((HERE/'scenarios.lua').read_text())
spec=importlib.util.spec_from_file_location('vip_assets',ROOT/'tools/build_vip_assets.py')
builder=importlib.util.module_from_spec(spec);spec.loader.exec_module(builder)
builder.validate(json.loads((ROOT/'assets/vip/vip.journal.json').read_text()),json.loads((ROOT/'assets/vip/vip_onscreens.json.json').read_text()))
source=(ROOT/'r6/scripts/NCPDPatrol/NCPDPatrolVIPSystem.reds').read_text()
assert all(v not in source for v in ['SetFact','GiveItem','RecordIncident'])
print('PASS: two-stage VIP journal; actual boarding/driver/owned vehicle/seat checks; actual living drop-off; failure/cancel/load/deferred cleanup; 35-65 m off-camera ambush, FOV/aspect/scene bounds and delayed warning; single reservation, seating/chase/brake/exit/escape; 90-second/all-body-distance aftermath and delivery retention; scanner/cyberpsycho exclusion (engine boundaries mocked)')
