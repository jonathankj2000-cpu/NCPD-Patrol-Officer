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
lua.globals().SupportNative=lua.execute(translate(ROOT/'r6/scripts/NCPDPatrol/NCPDPatrolSupportSystem.reds'))
lua.execute((HERE/'backup-approach-scenarios.lua').read_text())
# The backup context uses the exact existing ambush frustum formula; no VIP
# quest/stage dependency is imported into the backup request.
support_source=(ROOT/'r6/scripts/NCPDPatrol/NCPDPatrolSupportSystem.reds').read_text()
vip_source=(ROOT/'r6/scripts/NCPDPatrol/NCPDPatrolVIPSystem.reds').read_text()
def camera_formula(text,name):
 fragment=text.split('public func '+name+'(',1)[1]
 return fragment[fragment.index('        camera ='):fragment.index('\n    }')]
assert camera_formula(support_source,'CanSpawnBackupAt')==camera_formula(vip_source,'CanSpawnAmbushAt')
print('PASS: actual equipment/partner/backup integration and road selector: preserved readiness/follow/boarding/10-4; recent-route identity/expiry, stationary corridor, bridge/edge/slope/barrier/camera rejection, actual native frustum parity, car-before-crew settling, finite wait, three separated placement attempts, async/refused/partial cleanup, reservation/end-shift/world reset (engine boundaries mocked)')
