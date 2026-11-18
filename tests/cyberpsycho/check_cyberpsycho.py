"""Execute the authored target/journal controller and actual CET encounter/dispatcher."""
from pathlib import Path
import importlib.util,json,sys
HERE=Path(__file__).resolve().parent
ROOT=Path(sys.argv[1]).resolve() if len(sys.argv)>1 else HERE.parents[1]
sys.path.insert(0,str(HERE.parent/'arrests'))
from translate import translate
from lupa.luajit21 import LuaRuntime
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute((HERE.parent/'arrests/mappin-native-mocks.lua').read_text())
for file,name in [('NCPDPatrolCyberpsychoSystem.reds','CyberNative'),('NCPDPatrolDispatchJournalSystem.reds','DispatchJournalNative')]:
 lua.globals()[name]=lua.execute(translate(ROOT/'r6/scripts/NCPDPatrol'/file))
lua.execute((HERE.parent/'dispatch_journal/native-mocks.lua').read_text())
lua.execute((HERE/'native-mocks.lua').read_text())
lua.globals().MOD_DIR=str(ROOT/'bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrol')
lua.execute('package.path=MOD_DIR.."/?.lua;"..package.path')
lua.execute((HERE/'scenarios.lua').read_text())
spec=importlib.util.spec_from_file_location('cyberpsycho_assets',ROOT/'tools/build_cyberpsycho_assets.py')
builder=importlib.util.module_from_spec(spec);spec.loader.exec_module(builder)
builder.validate(json.loads((ROOT/'assets/cyberpsycho/cyberpsycho.journal.json').read_text()),json.loads((ROOT/'assets/cyberpsycho/cyberpsycho_onscreens.json.json').read_text()))
tweaks=(ROOT/'r6/tweaks/NCPDPatrol_Cyberpsycho.yaml').read_text()
assert '$base: Character.ma_wat_lch_06_cyberpsycho' in tweaks
assert tweaks.count('Character.NCPDPatrol_Cyberpsycho:')==1
assert 'lootDrop: LootTables.Empty' in tweaks and 'quest: NPCQuestAffiliation.General' in tweaks
assert 'SetFact' not in (ROOT/'r6/scripts/NCPDPatrol/NCPDPatrolCyberpsychoSystem.reds').read_text()
print('PASS: exact created cyberpsycho target, lethal/non-lethal confirmation, disappearance never succeeds, journal/tracking/load and cancellation guards; real CET spawn/hostility/nav/cleanup and scanner exclusion; no scanner/career/payments written (native boundaries mocked)')
