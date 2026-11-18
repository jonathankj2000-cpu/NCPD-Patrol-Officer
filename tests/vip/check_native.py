"""Optional local source/API check; requires the established game contracts/compiler.

Extends offline native-cache stubs using source-derived additions. Does not ship
these declarations or claim an actual Cyberpunk game-cache compilation.
"""
from pathlib import Path
import re,subprocess,sys,tempfile
ROOT=Path(__file__).resolve().parents[2]
WORK=ROOT.parent
base=WORK/'v09a-check'
compiler=WORK/'redscript/target/debug/ncpd-check'
originals=[WORK/'v11a-check/game-api.reds']+[base/n for n in ['support-api.reds','playback-api.reds','trunk-api.reds','journal-api.reds']]+[ROOT/'tests/career/contracts'/n for n in ['natives.reds','rewards.reds']]
source='\n'.join(p.read_text() for p in originals)
subprocess.run([sys.executable, str(ROOT/'tests/compile_compatibility/check_legacy_api.py')],check=True)
source=re.sub(r'public enum gamedataNPCHighLevelState \{[^}]+\}', 'public enum gamedataNPCHighLevelState { Alerted = 0, Combat = 2, Dead = 3, Relaxed = 5, Unconscious = 7 }', source)
additions='\n'.join(p.read_text() for p in [ROOT/'tests/career/contracts/vip-vehicle.reds', ROOT/'tests/officer_readiness/equipment-api.reds', ROOT/'tests/trunk_menu/popup-api.reds'])
for target,method in re.findall(r'@addMethod\((\w+)\)\n([^\n]+)',additions):
 pattern=r'(public native (?:class|struct) '+target+r'[^\{]*\{)'
 source,count=re.subn(pattern,lambda m:m[0]+'\n '+method,source,count=1)
 assert count,target
additions=re.sub(r'@addMethod\(\w+\)\n[^\n]+\n?','',additions)
source+='\n'+additions
scripts=[base/'localization-api.reds', ROOT/'tests/trunk_menu/codeware-popup-api.reds']+sorted((ROOT/'r6/scripts/NCPDPatrol').glob('*.reds'))
with tempfile.TemporaryDirectory(prefix='ncpd-native-') as d:
 path=Path(d)/'contracts.reds';path.write_text(source)
 for browser in [True,False]:
  optional=([ROOT/'tests/career/contracts'/n for n in ['browser-data.reds','browser-extension.reds','browser-controller.reds']]+[WORK/'v010b-framework/BrowserExtension.Classes.reds']) if browser else []
  subprocess.run([str(compiler),str(path),'--',*map(str,optional+scripts)],check=True)
  print('PASS: offline source/API compile with BEF='+str(browser)+' (not the actual game cache)')
