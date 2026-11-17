"""Execute authored native controllers/entry actions and actual CET modules."""
from pathlib import Path
import re, sys, tempfile, xml.etree.ElementTree as ET
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

def extract(source,pattern):
 m=re.search(pattern,source); assert m,pattern
 body=source.index('{',m.start()); end=body+1; depth=1
 while depth:
  depth+=(source[end]=='{')-(source[end]=='}'); end+=1
 return source[m.start():end]

menu=(NATIVE/'NCPDPatrolTrunkInteractions.reds').read_text()
support=(NATIVE/'NCPDPatrolSupportInteractions.reds').read_text()
with tempfile.TemporaryDirectory(prefix='ncpd-trunk-tests-') as d:
 p=Path(d)/'fixture.reds'
 for name,source,global_name in [('NCPDPatrolTrunkMenuAction',menu,'MenuAction'),('NCPDPatrolOpenTrunkMenuAction',menu,'OpenAction'),('NCPDPatrolBackupAction',support,'BackupAction')]:
  p.write_text(extract(source,r'public class '+name+r'\b'))
  lua.globals()[global_name]=lua.execute(translate(p))
 methods=[]
 for name,source in [('OnNCPDPatrolBackupAction',support),('OnNCPDPatrolOpenTrunkMenuAction',menu),('OnNCPDPatrolTrunkMenuAction',menu),('NCPDPatrolAddBackupAction',support),('NCPDPatrolAddTrunkMenuOpener',menu),('NCPDPatrolAddTrunkMenu',menu),('GetTrunkActions',support),('GetPlayerTrunkActions',support)]:
  methods.append(extract(source,r'(?:public|private)\s+(?:final\s+)?func '+name+r'\('))
 ps='public class PSFixture extends IScriptable {\n'+'\n'.join(methods)+'\n}'
 # Only model native cast and constructors; branch/loop/action routing is authored.
 for name,constructor,cast in [('NCPDPatrolBackupAction','NewBackupAction','AsBackupAction'),('NCPDPatrolOpenTrunkMenuAction','NewOpenAction','AsOpenAction'),('NCPDPatrolTrunkMenuAction','NewMenuAction','AsMenuAction')]:
  ps=ps.replace('Deref(actions)[i] as '+name,cast+'(Deref(actions)[i])')
  ps=ps.replace('new '+name+'()',constructor+'()')
 ps=re.sub(r'}\s+else\s+{','} else {',ps)
 p.write_text(ps);lua.globals().TrunkPS=lua.execute(translate(p))
 src=(NATIVE/'NCPDPatrolTrunkVehicle.reds').read_text()
 p.write_text('public class RepairFixture extends IScriptable {\n'+extract(src,r'public func NCPDPatrolRepairVehicle\(')+'\n}')
 lua.globals().Repair=lua.execute(translate(p))

yaml=(ROOT/'r6/tweaks/NCPDPatrol_Interactions.yaml').read_text()
keys=re.findall(r'^Interactions\.([^:]+):',yaml,re.M)
assert len(keys)==len(set(keys)), 'duplicate YAML records'
def record_action(name):
 m=re.search(r'^Interactions\.'+name+r':\n((?:[ \t].*\n|\n|#.*\n)*)',yaml,re.M)
 assert m,name
 action=re.search(r'^  action: (\w+)$',m[1],re.M);assert action,name
 return action[1]
backup_action=record_action('NCPDPatrolBackup');hold_action=record_action('NCPDPatrolOpenTrunkMenu')
assert backup_action=='Choice2' and hold_action=='Choice2_Hold'
context=ET.parse(HERE/'native-choice-context.xml').getroot()
accepted={node.attrib['action']:{e.attrib['name'] for e in node} for node in context.findall('acceptedEvents')}
assert accepted[backup_action]=={'BUTTON_RELEASED'}
assert accepted[hold_action]=={'BUTTON_HOLD_COMPLETE'}
assert float(context.find('hold').attrib['timeout'])==0.3
lua.globals().AcceptedBackupEvent=next(iter(accepted[backup_action]))
lua.globals().AcceptedHoldEvent=next(iter(accepted[hold_action]))

lua.execute((HERE/'native-scenarios.lua').read_text())
lua.globals().DispatchJournalNative=lua.execute(translate(NATIVE/'NCPDPatrolDispatchJournalSystem.reds'))
lua.execute((HERE.parent/'dispatch_journal/native-mocks.lua').read_text())
lua.execute((HERE/'cet-scenarios.lua').read_text())
loc=(NATIVE/'NCPDPatrolLocalization.reds').read_text()
for key in ['Available','Busy','Repair','NewPartner','CancelDispatch','NewDispatch','CopStats','CloseMenu']:
 assert 'Interactions.NCPDPatrol'+key+':' in yaml
 assert 'NCPDPatrol-'+key in loc
assert 'NCPDPatrol-PatrolMenu' in loc
assert 'trunk.RequestBackupAtTrunk(this.GetOwnerEntity())' in support
assert 'trunk.OpenMenu(this.GetOwnerEntity())' in menu
assert support.count('this.NCPDPatrolAddTrunkMenu(actions)')==2
assert support.count('this.NCPDPatrolAddTrunkMenuOpener(actions)')==2
native=(NATIVE/'NCPDPatrolTrunkSystem.reds').read_text()
assert all(token not in native for token in ['RegisterInputListener','BeginGesture','m_keyDown','Trunk input not received','TweakDBInterface.GetCName'])
print('PASS: release-only backup and native hold entry callbacks, actual trunk PS wrappers/choice records, stash/menu restoration, guards and existing repair/stats/dispatch/partner logic (native boundaries mocked)')
