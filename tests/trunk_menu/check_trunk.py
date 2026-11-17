"""Execute authored native control logic and actual CET modules; mock native APIs."""
from pathlib import Path
import re, sys, tempfile
HERE=Path(__file__).resolve().parent
ROOT=Path(sys.argv[1]).resolve() if len(sys.argv)>1 else HERE.parents[1]
sys.path.insert(0,str(HERE.parent/'arrests'))
from lupa.luajit21 import LuaRuntime
from translate import translate
NATIVE=ROOT/'r6/scripts/NCPDPatrol'
MOD=ROOT/'bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrol'
lua=LuaRuntime(unpack_returned_tuples=True)
logs=[]
lua.globals().print=lambda *args: logs.append(' '.join(str(a) for a in args))
lua.globals().MOD_DIR=str(MOD)
lua.execute('package.path=MOD_DIR.."/?.lua;"..package.path')
lua.globals().Trunk=lua.execute(translate(NATIVE/'NCPDPatrolTrunkSystem.reds'))
lua.globals().Ledger=lua.execute(translate(NATIVE/'NCPDPatrolSystem.reds'))
# Isolate the native menu action class from the PS/component extensions.
src=(NATIVE/'NCPDPatrolTrunkInteractions.reds').read_text().split('@addMethod')[0]
# Public fields of the native base class are initialized by the constructor in game.
with tempfile.TemporaryDirectory(prefix='ncpd-trunk-tests-') as d:
 p=Path(d)/'action.reds'; p.write_text(src)
 lua.globals().MenuAction=lua.execute(translate(p))
 # Execute the actual vehicle repair wrapper, with only native routines mocked.
 src=(NATIVE/'NCPDPatrolTrunkVehicle.reds').read_text()
 match=re.search(r'public func NCPDPatrolRepairVehicle\(',src)
 p.write_text('public class RepairFixture extends IScriptable {\n'+src[match.start():]+'\n}')
 lua.globals().Repair=lua.execute(translate(p))
lua.execute((HERE/'native-scenarios.lua').read_text())
lua.execute((HERE/'cet-scenarios.lua').read_text())
# Distinct records and localization prevent inherited "Select destination" captions.
yaml=(ROOT/'r6/tweaks/NCPDPatrol_Interactions.yaml').read_text()
keys=re.findall(r'^Interactions\.([^:]+):',yaml,re.M)
assert len(keys)==len(set(keys)), 'duplicate YAML records'
loc=(NATIVE/'NCPDPatrolLocalization.reds').read_text()
for key in ['Available','Busy','Repair','NewPartner','CancelDispatch','NewDispatch','CopStats','CloseMenu']:
 assert 'Interactions.NCPDPatrol'+key+':' in yaml
 assert 'NCPDPatrol-'+key in loc
# The request is reached solely via the authorized native trunk event.
support=(NATIVE/'NCPDPatrolSupportInteractions.reds').read_text()
assert 'trunk.BeginGesture(this.GetOwnerEntity())' in support
assert 'support.RequestBackupAtTrunk(this.GetOwnerEntity())' not in support
assert support.count('this.NCPDPatrolAddTrunkMenu(actions)')==2
print('PASS: native tap/hold event orders, single-action guards, native menu records, busy/dispatch controls, exact-vehicle timed repair, partner replacement failures, read-only stats and load/duty cleanup; actual CET modules in LuaJIT (native boundaries mocked)')
