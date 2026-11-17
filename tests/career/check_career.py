"""Execute the authored career model, page renderer, click handlers and hooks.

Native game/widgets and BEF are mocked boundaries. This is not a game emulator.
"""
from pathlib import Path
import re, sys, tempfile
HERE=Path(__file__).resolve().parent
ROOT=Path(sys.argv[1]).resolve() if len(sys.argv)>1 else HERE.parents[1]
sys.path.insert(0,str(HERE.parent/'arrests'))
from translate import translate
from lupa.luajit21 import LuaRuntime
NATIVE=ROOT/'r6/scripts/NCPDPatrol'
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute((HERE.parent/'arrests/mappin-native-mocks.lua').read_text())
for file,name in [('NCPDPatrolSystem.reds','Core'),('NCPDPatrolDispatchJournalSystem.reds','Dispatch'),('NCPDPatrolArrestSystem.reds','Arrests'),('NCPDPatrolCareerSystem.reds','Career')]:
 lua.globals()[name]=lua.execute(translate(NATIVE/file))

def extract(source,pattern):
 match=re.search(pattern,source);assert match,pattern
 start=source.index('{',match.start());end=start+1;depth=1
 while depth:
  depth+=(source[end]=='{')-(source[end]=='}');end+=1
 return source[match.start():end]

source=(NATIVE/'NCPDPatrolCareerBrowser.reds').read_text()
with tempfile.TemporaryDirectory(prefix='ncpd-career-page-') as scratch:
 p=Path(scratch)/'Listener.reds'
 listener=extract(source,r'public class NCPDPatrolCareerSiteListener\b')
 # Only constructor/base-runtime boundaries are replaced. Rendering decisions,
 # exact widget text, event guards and reward calls are authored production code.
 listener=listener.replace('super.Init(logic);','NativeBrowserInit(this, logic);').replace('super.Uninit();','NativeBrowserUninit(this);')
 listener=listener.replace('let color: HDRColor;','let color: HDRColor = NativeColor();')
 for kind in ['inkText','inkCanvas','inkRectangle','inkVerticalPanel','inkHorizontalPanel']:
  listener=listener.replace('new '+kind+'()',f'NativeWidget("{kind}")')
 p.write_text(listener);lua.globals().ListenerPrototype=lua.execute(translate(p))
 hooks=extract(source,r'protected cb func OnInitialize\(')+'\n'+extract(source,r'protected cb func OnUninitialize\(')
 hooks=hooks.replace('new NCPDPatrolCareerSiteListener()','NativeListener()')
 p.write_text('public class BrowserHookFixture extends IScriptable {\n'+hooks+'\n}')
 lua.globals().HookPrototype=lua.execute(translate(p))
lua.execute((HERE/'native-mocks.lua').read_text())
lua.execute((HERE/'scenarios.lua').read_text())
assert source.count('@if(ModuleExists("BrowserExtension.System"))')==7
assert 'GetWebPage(address: String)' in source and 'ClaimNextReward()' in source
assert 'CreateScriptedQuest' not in source
print('PASS: authored career model/browser: ranks/progress/milestones, existing scanner ledger, independent stats and once-only service payments; native UI render text, real claim/refresh callbacks, registration/cleanup and stale-world guards (native/BEF boundaries mocked)')
