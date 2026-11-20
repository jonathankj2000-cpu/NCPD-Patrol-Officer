"""Generate the shared fixed scene and compile/round-trip its own quest archive."""
from pathlib import Path
import argparse,copy,hashlib,json,shutil,subprocess,tempfile
ROOT=Path(__file__).resolve().parents[1]
DIR=ROOT/'assets/officer_down'
MOD='bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrol/'

def outputs():
 s=json.loads((DIR/'scene.json').read_text());p=s['position']
 scene='-- Generated from assets/officer_down/scene.json. Native marker shares this exact point.\nreturn {x=%.9f,y=%.9f,z=%.9f,prepare=%d,prepareNear=%d,prepareInterval=%d,prepareGrace=%d,arrival=%d,retainSeconds=%d,retainDistance=%d}\n'%(p['x'],p['y'],p['z'],s['prepare_radius_metres'],s['prepare_retry_near_radius_metres'],s['prepare_retry_interval_seconds'],s['prepare_retry_grace_seconds'],s['arrival_radius_metres'],s['retain_seconds'],s['retain_distance_metres'])
 native='// Generated from assets/officer_down/scene.json; marker resource uses the same point.\npublic class NCPDPatrolOfficerDownSite extends IScriptable {\n    public static func Position() -> Vector4 {\n        let point: Vector4;\n        point.X = %.9f; point.Y = %.9f; point.Z = %.9f; point.W = 1.0;\n        return point;\n    }\n}\n'%(p['x'],p['y'],p['z'])
 return {MOD+'officer_down_scene.lua':scene,'r6/scripts/NCPDPatrol/NCPDPatrolOfficerDownSite.reds':native}

def validate(journal,texts):
 def walk(x):
  if isinstance(x,dict):
   yield x
   for v in x.values():yield from walk(v)
  elif isinstance(x,list):
   for v in x:yield from walk(v)
 rows=list(walk(journal));handles=[x['HandleId'] for x in rows if 'HandleId' in x];assert len(handles)==len(set(handles))
 quests=[x for x in rows if x.get('$type')=='gameJournalQuest'];assert len(quests)==1 and quests[0]['id']=='ncpd_patrol_officer_down'
 objectives=[x for x in rows if x.get('$type')=='gameJournalQuestObjective'];assert len(objectives)==1 and objectives[0]['id']=='assist'
 pins=[x for x in rows if x.get('$type')=='gameJournalQuestMapPin'];assert len(pins)==1 and pins[0]['mappinData']['active']==0
 anchor=json.loads((ROOT/'assets/quest_marker_probe/reference-contract.json').read_text());point=json.loads((DIR/'scene.json').read_text())['position']
 assert pins[0]['reference']['reference']['$value']==anchor['node_reference']
 for k,v in point.items():assert abs(pins[0]['offset'][k.upper()]-(v-anchor['position'][k.upper()]+anchor['offset'][k.upper()]))<.001
 strings=texts['Data']['RootChunk']['root']['Data']['entries'];assert len(strings)==5
 assert {r['secondaryKey'] for r in strings}=={'NCPDPatrol_OfficerDown_'+k for k in ['Title','Objective','Description','Revive','Reviving']}

def main():
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--wk-cli',type=Path);parser.add_argument('--check',action='store_true');a=parser.parse_args()
 for name,body in outputs().items():
  if a.check:assert (ROOT/name).read_text()==body,name
  else:(ROOT/name).write_text(body)
 validate(json.loads((DIR/'officer_down.journal.json').read_text()),json.loads((DIR/'officer_down_onscreens.json.json').read_text()))
 if not a.wk_cli:return
 def run(*args):subprocess.run([str(a.wk_cli.resolve()),*map(str,args)],check=True)
 with tempfile.TemporaryDirectory(prefix='ncpd-officer-down-') as temp:
  t=Path(temp);packed=t/'NCPDPatrol_OfficerDown';depot=packed/'base/ncpd_patrol/officer_down';depot.mkdir(parents=True)
  roundtrip=t/'roundtrip';roundtrip.mkdir();out=t/'out';out.mkdir()
  files=['officer_down.journal.json','officer_down_onscreens.json.json']
  for name in files:run('convert','deserialize',DIR/name,'--outpath',depot)
  expected={name:(depot/name).read_bytes() for name in ['officer_down.journal','officer_down_onscreens.json']}
  for name in expected:assert expected[name][:4]==b'CR2W';run('convert','serialize',depot/name,'--outpath',roundtrip)
  validate(json.loads((roundtrip/files[0]).read_text(encoding='utf-8-sig')),json.loads((roundtrip/files[1]).read_text(encoding='utf-8-sig')))
  run('pack',packed,'--outpath',out)
  archive=out/'NCPDPatrol_OfficerDown.archive';extracted=t/'extracted';extracted.mkdir();run('extract',archive,'--outpath',extracted)
  assert {p.name:p.read_bytes() for p in extracted.rglob('*') if p.is_file()}==expected
  target=ROOT/'archive/pc/mod'/archive.name
  # A runtime-only scene setting does not change journal/localization bytes.
  # WolvenKit can alter archive timestamps on repack; retain the installed
  # archive only after extracting and proving its full resource set identical.
  retain=False
  if target.exists():
   existing=t/'existing';existing.mkdir();run('extract',target,'--outpath',existing)
   retain={p.name:p.read_bytes() for p in existing.rglob('*') if p.is_file()}==expected
  if not retain:shutil.copy2(archive,target)
  inputs=['assets/officer_down/scene.json',*[f'assets/officer_down/{f}' for f in files],'assets/quest_marker_probe/reference-contract.json']
  (DIR/'compiled.json').write_text(json.dumps({'archive_path':target.relative_to(ROOT).as_posix(),'archive_sha256':hashlib.sha256(target.read_bytes()).hexdigest(),'authored_inputs':{p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in inputs},'roundtrip_validated':True,'extracted_resource_bytes_compared':True,'fixed_pins':1,'position_source':'User TEST_KRYSS_01; same authored offset from the proven Coyote anchor','game_validation':False},indent=2)+'\n')
 print('PASS: Officer Down scene data and fixed quest marker compiled, round-tripped and extracted byte-identically')
if __name__=='__main__':main()
