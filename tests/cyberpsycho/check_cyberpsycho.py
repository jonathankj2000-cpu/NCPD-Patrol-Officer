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
catalog_spec=importlib.util.spec_from_file_location('catalog_builder',ROOT/'tools/build_cyberpsycho_catalog.py')
catalog=importlib.util.module_from_spec(catalog_spec);catalog_spec.loader.exec_module(catalog)
files,clause=catalog.outputs()
for name,text in files.items():assert (ROOT/name).read_text()==text,name
assert clause in (ROOT/'r6/scripts/NCPDPatrol/NCPDPatrolCyberpsychoSystem.reds').read_text()
rows=json.loads((ROOT/'assets/cyberpsycho/variants.json').read_text())['variants']
assert len(rows)==17 and len({row['base'] for row in rows})==17
assert len([row for row in rows if row['exo']])==2
assert all(row['source_path'] and len(row['source_blob'])==40 for row in rows)
print('PASS: 17 verified private cyberpsycho variants; exact selected native identity, all lethal/non-lethal outcomes, random no-repeat/availability, manual CET selection; distant dispatch/arrival/deadline/cancel/load/cleanup and scanner exclusion; no payment/progress writes (native boundaries mocked)')
