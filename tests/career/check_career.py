"""Execute the authored career model, page renderer, click handlers and hooks.

Native game/widgets are mocked boundaries; pinned BEF base/registry code runs.
This is not a game emulator.
"""
from pathlib import Path
import re, sys, tempfile
HERE=Path(__file__).resolve().parent
ROOT=Path(sys.argv[1]).resolve() if len(sys.argv)>1 else HERE.parents[1]
sys.path.insert(0,str(HERE.parent/'arrests'))
from translate import translate
from lupa.luajit21 import LuaRuntime
from bef_reference import sources
NATIVE=ROOT/'r6/scripts/NCPDPatrol'
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute((HERE.parent/'arrests/mappin-native-mocks.lua').read_text())
for file,name in [('NCPDPatrolSystem.reds','Core'),('NCPDPatrolDispatchJournalSystem.reds','Dispatch'),('NCPDPatrolArrestSystem.reds','Arrests'),('NCPDPatrolCareerSystem.reds','Career'),('NCPDPatrolSupportSystem.reds','Support')]:
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
 refs=sources()
 base=extract(refs['BrowserExtension.Classes.reds'],r'public class BrowserEventsListener\b')
 base=base.replace('protected let','private let').replace('new inkCanvas()','NativeWidget("inkCanvas")')
 p.write_text(base);lua.globals().FrameworkBase=lua.execute(translate(p))
 methods=[]
 for name in ['Register','Unregister','GetSitesData','GetWebPage','IsAddressBlocked']:
  method=extract(refs['BrowserExtension.System.reds'],r'public (?:final )?func '+name+r'\(')
  method=method.replace('for listener in this.m_listeners {','let referenceIndex: Int32 = 0; while referenceIndex < ArraySize(this.m_listeners) { let listener: ref<BrowserEventsListener> = this.m_listeners[referenceIndex]; referenceIndex += 1;')
  methods.append(method)
 p.write_text('public class FrameworkSystem extends IScriptable {\nprivate let m_listeners: array<ref<IScriptable>>;\nprivate let m_blockedAddress: array<String>;\n'+'\n'.join(methods)+'\n}')
 lua.globals().FrameworkSystem=lua.execute(translate(p))
 state=(NATIVE/'NCPDPatrolCareerBrowserState.reds').read_text()
 # Select the installed-module branch, as redscript's compiler does. Production
 # still gets a separate native compile with the module absent.
 for name in ['CheckRegistry','FrameworkStatus','OpenCareer']:
  pattern=r'@if\(!ModuleExists\("BrowserExtension.System"\)\)\s+(?:private|public) func '+name+r'\('
  fragment=extract(state,pattern);state=state.replace(fragment,'')
 state=re.sub(r'(?m)^[ \t]*@if\(ModuleExists\("BrowserExtension.System"\)\)\s*\n','',state)
 p.write_text(extract(state,r'public class NCPDPatrolCareerBrowserState\b'))
 lua.globals().BrowserState=lua.execute(translate(p))
 listener=extract(source,r'public class NCPDPatrolCareerSiteListener\b')
 # Only constructor/base-runtime boundaries are replaced. Rendering decisions,
 # exact widget text, event guards and reward calls are authored production code.
 listener=listener.replace('super.Init(logic);','NativeBrowserInit(this, logic);').replace('super.Uninit();','NativeBrowserUninit(this);')
 listener=listener.replace('let color: HDRColor;','let color: HDRColor = NativeColor();')
 listener=listener.replace('let transform: Vector2;','let transform: Vector2 = NativeVector();')
 listener=listener.replace('let viewport: Vector2;','let viewport: Vector2 = NativeVector();')
 for kind in ['inkText','inkCanvas','inkRectangle','inkVerticalPanel','inkHorizontalPanel']:
  listener=listener.replace('new '+kind+'()',f'NativeWidget("{kind}")')
 p.write_text(listener);lua.globals().ListenerPrototype=lua.execute(translate(p))
 def viewport_method(owner):
  method=extract(source,r'@addMethod\('+owner+r'\)\s+public func NCPDPatrolCareerViewport\(')
  return method[method.index('public func'):].replace('let empty: Vector2;','let empty: Vector2 = NativeVector();')
 hooks=viewport_method('BrowserGameController')+'\n'+extract(source,r'public func NCPDPatrolEnsureCareerSite\(')+'\n'+extract(source,r'protected cb func OnInitialize\(')+'\n'+extract(source,r'protected cb func OnUninitialize\(')
 hooks=hooks.replace('new NCPDPatrolCareerSiteListener()','NativeListener()')
 p.write_text('public class BrowserHookFixture extends IScriptable {\n'+hooks+'\n}')
 lua.globals().HookPrototype=lua.execute(translate(p))
 p.write_text('public class PageSpawnFixture extends IScriptable {\n'+viewport_method('BrowserController')+'\n'+extract(source,r'public final func SetWebsiteData\(')+'\n}')
 lua.globals().PageSpawnPrototype=lua.execute(translate(p))
lua.execute((HERE/'native-mocks.lua').read_text())
weapon_tweaks=(ROOT/'r6/tweaks/NCPDPatrol_CareerWeapons.yaml').read_text()
weapon_tweaks+='\n'+(ROOT/'r6/tweaks/NCPDBeanBagger/NCPDBeanBagger.yaml').read_text()
weapon_records={}
for match in re.finditer(r'^(Items\.[\w]+):\n  \$base: (Items\.[\w]+)\n  quality: (Quality\.\w+)\s*',weapon_tweaks,re.M):
 weapon_records[match[1]]=(match[2],match[3])
assert weapon_records=={
 'Items.Preset_Lexington_Military_NCPDPatrol_Tier2':('Items.Preset_Lexington_Military','Quality.Uncommon'),
 'Items.Preset_Masamune_Military_NCPDPatrol_Tier3':('Items.Preset_Masamune_Military','Quality.Rare'),
 'Items.Preset_Defender_Military_NCPDPatrol_Tier5':('Items.Preset_Defender_Military','Quality.Legendary'),
 'Items.NCPDBeanBagger_M2038':('Items.Preset_Tactician_Default','Quality.Uncommon')}
lua.globals().TieredRewardRecords=lua.table_from({key:lua.table_from({'base':value[0],'quality':value[1]}) for key,value in weapon_records.items()})
lua.execute((HERE/'scenarios.lua').read_text())
lua.execute((HERE/'portal-scenarios.lua').read_text())
lua.execute((HERE/'shift-scenarios.lua').read_text())
lua.execute((HERE/'weapon-scenarios.lua').read_text())
lua.execute((HERE/'beanbagger-rewards.lua').read_text())
lua.globals().MOD_DIR=str(ROOT/'bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrol')
lua.execute('package.path=MOD_DIR.."/?.lua;"..package.path')
lua.execute((HERE/'partner-scenarios.lua').read_text())
lua.execute((HERE/'cet-ui-scenarios.lua').read_text())
assert source.count('@if(ModuleExists("BrowserExtension.System"))')==11
assert 'this.LoadPageByAddress(' not in source
assert 'this.m_deviceLogicController.LoadPageByAddress(' in source
assert 'GetWebPage(address: String)' in source and 'ClaimNextReward()' in source
assert 'CreateScriptedQuest' not in source
print('PASS: three portal pages fit five viewport sizes; career Start/End Shift queue native desired states with pending feedback, no direct lifecycle changes, duplicate/stale/session/death/wanted guards; rank/reward/partner rendering, callback cleanup, tiered rewards and pinned BEF registration/navigation (native boundaries mocked)')
