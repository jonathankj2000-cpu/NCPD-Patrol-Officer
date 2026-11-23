"""Load actual scoped hooks and pinned game methods over recording services.

This does not emulate REDengine scene scheduling, native interaction descriptors,
inventory event routing, serialization or the rendered loot UI.
"""
from pathlib import Path
from tempfile import TemporaryDirectory
import hashlib,json,re,sys
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
sys.path.insert(0,str(HERE.parent/'arrests'))
from translate import translate

def compile_source(lua,source):
    source=re.sub(r'\bprotected\s+(?!(?:cb)\b)', 'public ',source)
    with TemporaryDirectory(prefix='ncpd-encounter-') as temp:
        path=Path(temp)/'source.reds';path.write_text(source)
        code=translate(path)
    code=code.replace('new SetLootInteractionAccessibilityEvent()', 'NewLootAccessEvent()')
    code=code.replace('new AnimFeature_SceneSystem()', 'NewReferenceAnimFeature()')
    code=code.replace('new AnimFeature_SceneGameplayOverrides()', 'NewReferenceAnimFeature()')
    code=code.replace('new InteractionSetEnableEvent()', 'NewReferenceInteractionEvent()')
    code=code.replace('new NotifyShardRead()', 'NewReferenceShardRead()')
    code=code.replace('new PreventionForceDeescalateRequest()', 'NewReferenceDeescalation()')
    code=code.replace('local lastValue = nil', 'local lastValue = 0')
    code=code.replace('super:OnEnter(stateContext, scriptInterface)', 'ReferenceSuperOnEnter(self,stateContext,scriptInterface)')
    code=code.replace('super:CompleteAction(gameInstance)', 'ReferenceItemActionComplete(self,gameInstance)')
    return lua.execute(code)

def prepare(lua):
    g=lua.globals()
    reference=json.loads((HERE/'game_reference.json').read_text())
    grouped={}
    for key,row in reference['methods'].items():
        assert hashlib.sha256(row['source'].encode()).hexdigest()==row['source_sha256'],key
        owner=key.split('.')[0];grouped.setdefault(owner,[]).append(row['source'])
    tables={}
    for owner,sources in grouped.items():
        # Preserve native Cast<Bool> semantics at this boundary (Lua 0 is true).
        source='\n'.join(sources).replace('Cast<Bool>(', 'ReferenceBool(')
        tables[owner]=compile_source(lua,'public class Reference extends IScriptable {\n'+source+'\n}')
    g.GameReference=lua.table_from(tables)
    source=(ROOT/'r6/scripts/NCPDPatrol/NCPDPatrolOffBooksLoot.reds').read_text()
    source=re.sub(r'@addMethod\(ScriptedPuppet\)\n','',source)
    g.NativeEvidenceLoot=compile_source(lua,'public class NativeLoot extends IScriptable {\n'+source+'\n}')
    wrappers=(ROOT/'r6/scripts/NCPDPatrol/NCPDPatrolOffBooksCombat.reds').read_text()
    for owner,body in re.findall(r'@wrapMethod\((\w+)\)\n(.*?)(?=\n@wrapMethod|\Z)',wrappers,re.S):
        body=body.replace('wrappedMethod(stateContext, scriptInterface)',f'Original{owner}(this, stateContext, scriptInterface)')
        g['Scoped'+owner]=compile_source(lua,'public class Hook extends IScriptable {\n'+body+'\n}')
