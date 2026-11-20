from pathlib import Path
import sys,os,subprocess
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
sys.path.insert(0,str(HERE))
from lupa.luajit21 import LuaRuntime
from translate import translate
lua=LuaRuntime(unpack_returned_tuples=True)
logs=[]
lua.globals().print=lambda *args: logs.append(' '.join(str(v) for v in args))
lua.execute(Path(HERE/'mappin-native-mocks.lua').read_text())
lua.globals().Patrol=lua.execute(translate(ROOT/'r6/scripts/NCPDPatrol/NCPDPatrolSystem.reds'))
lua.execute('function Patrol:GetGameInstance() return {} end')
lua.execute(Path(HERE/'support-native-mocks.lua').read_text())
lua.execute(Path(HERE/'arrest-native-mocks.lua').read_text())
lua.globals().PlaybackPrototype=lua.execute(translate(ROOT/'r6/scripts/NCPDPatrol/NCPDPatrolArrestPlayback.reds'))
lua.execute('NCPDPatrolArrestPlayback={new=function() return setmetatable({}, {__index=PlaybackPrototype}) end}')
lua.globals().ArrestNative=lua.execute(translate(ROOT/'r6/scripts/NCPDPatrol/NCPDPatrolArrestSystem.reds'))
lua.execute('function ArrestNative:GetGameInstance() return {} end')
lua.execute(Path(HERE/'arrest-native-scenarios.lua').read_text())
import tempfile
with tempfile.TemporaryDirectory(prefix='ncpd-result-wrapper-') as scratch:
    event=Path(ROOT/'r6/scripts/NCPDPatrol/NCPDPatrolArrestEvents.reds').read_text()
    event=event[event.index('protected cb func'):].replace('protected cb func','public func')
    wrapper=Path(scratch)/'ResultWrapper.reds'
    wrapper.write_text('public class ResultWrapper extends IScriptable {\n'+event+'\n}')
    lua.globals().ResultReceiver=lua.execute(translate(wrapper))
lua.globals().MOD_DIR=str(Path(ROOT/'bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrol').resolve())
lua.execute('package.path=MOD_DIR.."/?.lua;"..package.path')
override=os.environ.get('NCPD_ARREST_MODULE_TEST')
if override:
    lua.globals().ARREST_MODULE_TEST=override
    lua.execute('package.preload.arrest=function() return dofile(ARREST_MODULE_TEST) end')
import json
asset=json.loads(Path(ROOT/'assets/arrest/arrest_lying_loop.workspot.json').read_text())
handles={}
def collect(value):
    if isinstance(value,dict):
        if 'HandleId' in value and 'Data' in value: handles[value['HandleId']]=value['Data']
        for child in value.values(): collect(child)
    elif isinstance(value,list):
        for child in value: collect(child)
collect(asset)
def resolve(value): return value['Data'] if 'Data' in value else handles[value['HandleRefId']]
def native_entry(value):
    node=resolve(value)
    out={'className':node['$type'],'id':{'id':node['id']['id']}}
    if 'list' in node: out['list']=[native_entry(child) for child in node['list']]
    if 'idleAnim' in node: out['idleAnim']=node['idleAnim']['$value']
    if 'loopInfinitely' in node: out['loopInfinitely']=bool(node['loopInfinitely'])
    return out
asset_tree=resolve(asset['Data']['RootChunk']['workspotTree'])
private_tree={'rootEntry':native_entry(asset_tree['rootEntry']),
    'initialCanUseExits':bool(asset_tree['initialCanUseExits']),
    'useTimeLimitForSequences':bool(asset_tree['useTimeLimitForSequences']),
    'finalAnimsets':[], 'customTransitionAnims':[], 'statusEffectID':0,
    'tags':['NCPDPatrolArrestLoop']}
def to_lua(value):
    if isinstance(value,dict):return lua.table_from({key:to_lua(child) for key,child in value.items()})
    if isinstance(value,list):return lua.table_from([to_lua(child) for child in value])
    return value
lua.globals().PrivateLoopTree=to_lua(private_tree)
lua.execute("local function methods(entry) function entry:GetClassName() return self.className end; for _,child in ipairs(entry.list or {}) do methods(child) end end; methods(PrivateLoopTree.rootEntry)")
lua.execute(Path(HERE/'arrest-cet-scenarios.lua').read_text())
assert any('source=native activation fallback' in line for line in logs)
assert any('source=native play result' in line for line in logs)
assert any('Registered via native activation fallback' in line for line in logs)
assert any('observed clip=unavailable' in line for line in logs)
assert any('Arrest loop | private bindings configured' in line for line in logs)
assert any('Arrest ground | ready after' in line for line in logs)
assert any('NCPD_GROUND_UNSUITABLE' in line and 'ray misses=' in line and 'nav=' in line for line in logs)
assert any('prepared before helper creation=true' in line for line in logs)
if not override:
    with tempfile.TemporaryDirectory(prefix='ncpd-arrest-order-control-') as scratch:
        baseline=Path(scratch)/'arrest.lua'
        baseline.write_bytes(subprocess.check_output(['git','show','07cd4ba3b674b496c12cf69cd58f160d662354b7:bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrol/arrest.lua'],cwd=ROOT))
        control=subprocess.run([sys.executable,str(Path(__file__).resolve())],cwd=ROOT,
            env={**os.environ,'NCPD_ARREST_MODULE_TEST':str(baseline)},capture_output=True,text=True)
        assert control.returncode!=0 and 'Arrest helper attached before private animation bindings were ready' in control.stderr,(control.stdout,control.stderr)
    print('Arrest initialization control: actual v0.17e fails pre-attachment binding invariant; this is not a rendered-animation test')
print('PASS: arrest bindings prepared/read back before helper attachment, fresh/empty resource cache and actual v0.17e negative control; bounded fresh ground retries after carry/drop, native alignment and unsafe-ground rejection; unchanged health/defeat, rollback/carry handoff; stable activation/exactly-once payment; stale/failed results, death/range/wanted/load guards; infinite loop and async failures; separate scanner/arrest 1000/250 payments (native APIs mocked; game rendering unverified)')
