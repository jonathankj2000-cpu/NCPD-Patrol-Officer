"""Execute readiness plus actual partner/backup integration at native boundaries."""
from pathlib import Path
import sys,tempfile
from lupa.luajit21 import LuaRuntime
HERE=Path(__file__).resolve().parent
ROOT=Path(sys.argv[1]).resolve() if len(sys.argv)>1 else HERE.parents[1]
lua=LuaRuntime(unpack_returned_tuples=True)
lua.globals().MOD_DIR=str(ROOT/'bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrol')
lua.execute('package.path=MOD_DIR.."/?.lua;"..package.path')
sys.path.insert(0,str(HERE.parent/'arrests'))
from translate import translate
source=(ROOT/'r6/scripts/NCPDPatrol/NCPDPatrolOfficerEquipment.reds').read_text()
# Adapt only the native out-parameter ABI; all guards, item filtering, slot
# verification and control flow below execute the actual production script.
source=source.replace('let context: ScriptExecutionContext;', 'let context: ScriptExecutionContext = NativeContext();')
source=source.replace('let item: NPCItemToEquip;', 'let item: NPCItemToEquip = NativeEquipItem();')
source=source.replace('AIActionTransactionSystem.GetItemsBodySlot(actor, item.itemID, bodySlot);', 'bodySlot = NativeBodySlot(actor, item.itemID);')
with tempfile.TemporaryDirectory(prefix='ncpd-equipment-') as d:
 path=Path(d)/'equipment.reds';path.write_text(source)
 lua.globals().EquipmentNative=lua.execute(translate(path))
lua.execute((HERE/'scenarios.lua').read_text())
print('PASS: actual equipment controller + partner/backup integration: accepted-but-stalled command fallback, held-slot confirmation, owned inventory filtering, combat/alert/mount/down guards, bounded failures; active backup follows instead of holding, native boarding priority; 10-4 stand-down and distance/async cleanup (engine boundaries mocked)')
