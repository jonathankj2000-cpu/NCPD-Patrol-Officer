"""Run the authored native quest and actual CET VIP/ambush/dispatcher modules.

Only engine APIs, animation completion and vehicle physics are mocked. This
cannot verify live traffic pathfinding, animation or seat behaviour in game.
"""
from pathlib import Path
import hashlib,importlib.util,json,sys
HERE=Path(__file__).resolve().parent
ROOT=Path(sys.argv[1]).resolve() if len(sys.argv)>1 else HERE.parents[1]
sys.path.insert(0,str(HERE.parent/'arrests'))
from translate import translate
from lupa.luajit21 import LuaRuntime
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute((HERE.parent/'arrests/mappin-native-mocks.lua').read_text())
for file,name in [('NCPDPatrolIncidentSystem.reds','IncidentNative'),('NCPDPatrolCyberpsychoSystem.reds','CyberNative'),('NCPDPatrolDispatchJournalSystem.reds','DispatchJournalNative'),('NCPDPatrolVIPSystem.reds','VIPNative')]:
 lua.globals()[name]=lua.execute(translate(ROOT/'r6/scripts/NCPDPatrol'/file))
lua.execute((HERE.parent/'dispatch_journal/native-mocks.lua').read_text())
lua.execute((HERE.parent/'cyberpsycho/native-mocks.lua').read_text())
lua.globals().MOD_DIR=str(ROOT/'bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrol')
lua.execute('package.path=MOD_DIR.."/?.lua;"..package.path')
lua.execute((HERE/'native-mocks.lua').read_text())
lua.execute((HERE.parent/'incidents/engine-mocks.lua').read_text())
lua.execute((HERE/'scenarios.lua').read_text())
lua.execute((HERE/'fleet-scenarios.lua').read_text())
lua.execute((HERE/'waypoint-scenarios.lua').read_text())
spec=importlib.util.spec_from_file_location('vip_assets',ROOT/'tools/build_vip_assets.py')
builder=importlib.util.module_from_spec(spec);spec.loader.exec_module(builder)
builder.validate(json.loads((ROOT/'assets/vip/vip.journal.json').read_text()),json.loads((ROOT/'assets/vip/vip_onscreens.json.json').read_text()))
compiled=json.loads((ROOT/'assets/vip/compiled.json').read_text())
assert hashlib.sha256((ROOT/compiled['archive_path']).read_bytes()).hexdigest()==compiled['archive_sha256']
for path,sha in compiled['authored_inputs'].items():assert hashlib.sha256((ROOT/path).read_bytes()).hexdigest()==sha
assert compiled['roundtrip_validated'] and compiled['extracted_resource_bytes_compared']
assert 'within five minutes' not in (ROOT/'assets/vip/vip_onscreens.json.json').read_text()
source=(ROOT/'r6/scripts/NCPDPatrol/NCPDPatrolVIPSystem.reds').read_text()
assert all(v not in source for v in ['SetFact','GiveItem','RecordIncident'])
print('PASS: two-stage VIP journal; local/expanded routes and adaptive deadlines; actual boarding/driver/seat/living drop-off earns separate EUR$2000/career record; pickup/delivery waypoint recovery, scoped identity, delayed/failed registration and bounded retries; 1/2/3 and random convoys, reservations, independent crew/aftermath, warning and cleanup; bridge/corridor/camera checks; scanner/arrest rewards unchanged (engine boundaries mocked)')
