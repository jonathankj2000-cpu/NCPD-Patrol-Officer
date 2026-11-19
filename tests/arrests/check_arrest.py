from pathlib import Path
import sys
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
print('PASS: ragdoll recovery with flatter static-collision footprint selection, native workspot alignment despite delayed teleport/root height, misplacement/no-surface/steep-ground rejection; unchanged health/defeat and rollback/carry handoff; stable native activation pays once; exact-helper positive/negative/stale results; no-entry/transition/paused/dead/range/wanted/load guards; infinite idle and single entry-ID jump; async resource failures; independent scanner/arrest 1000/250 payments (native APIs mocked)')
