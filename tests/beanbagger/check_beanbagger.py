"""Execute the actual native hit policy and wrapper with engine boundaries mocked."""
from pathlib import Path
import re,sys,tempfile
from lupa.luajit21 import LuaRuntime
HERE=Path(__file__).resolve().parent
ROOT=Path(sys.argv[1]).resolve() if len(sys.argv)>1 else HERE.parents[1]
sys.path.insert(0,str(HERE.parent/'arrests'))
from translate import translate
source=(ROOT/'r6/scripts/NCPDPatrol/NCPDPatrolBeanBaggerSystem.reds').read_text()
def extract(pattern):
 match=re.search(pattern,source);assert match,pattern
 start=source.index('{',match.start());end=start+1;depth=1
 while depth:
  depth+=(source[end]=='{')-(source[end]=='}');end+=1
 return source[match.start():end]
lua=LuaRuntime(unpack_returned_tuples=True)
with tempfile.TemporaryDirectory(prefix='ncpd-beanbagger-') as d:
 p=Path(d)/'fixture.reds'
 p.write_text(extract(r'public class NCPDPatrolBeanBaggerSystem\b').replace('hit.target as NPCPuppet','NativeAsNPC(hit.target)'))
 lua.globals().Policy=lua.execute(translate(p))
 p.write_text('public class WrapperFixture extends IScriptable {\n'+extract(r'public final static func ModifyHitData\(')+'\n}')
 lua.globals().Wrapper=lua.execute(translate(p))
lua.execute((HERE/'scenarios.lua').read_text())
yaml=(ROOT/'r6/tweaks/NCPDBeanBagger/NCPDBeanBagger.yaml').read_text()
code='\n'.join(line for line in yaml.splitlines() if not line.lstrip().startswith('#'))
assert re.findall(r'^(\w+\.\w+):',code,re.M)==['Items.NCPDBeanBagger_M2038']
assert '$base: Items.Preset_Tactician_Default' in code and 'quality: Quality.Uncommon' in code
assert 'value: 0.90' in code and 'statType: BaseStats.DamagePerHit' in code
assert 'OnAttach' not in code and 'GenericMod1' not in code
loc=(ROOT/'r6/scripts/NCPDPatrol/NCPDPatrolLocalization.reds').read_text()
for key in ['NCPD_BeanBagger_WeaponName','NCPD_BeanBagger_Description']:
 assert 'LocKey#'+key in code and 'this.Text("'+key+'",' in loc
print('PASS: actual Bean Bagger hit policy/wrapper: exact item/player/ranged/human scope, native-first order, non-lethal/finisher flags, lethal overrides removed only for this weapon, downed/pending-defeat pellet protection, other attacks/dead/mechanical targets untouched; transient observed-target diagnostics; fixed T2/0.90 item and registered localization (engine hit reactions mocked)')
