"""Import verified survey sites and bake independent, initially inactive quest pins.

New sites need a normal asset/package build; no journal marker is moved at runtime.
Existing indices/quest paths remain stable when another site is appended.
"""
from pathlib import Path
import argparse,copy,hashlib,json,shutil,subprocess,tempfile
ROOT=Path(__file__).resolve().parents[1]
DIR=ROOT/'assets/officer_down_sites'
MOD=ROOT/'bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrol'
PROFILE='injured-functional-v1'
LEGACY='quests/minor_quest/ncpd_patrol_officer_down'
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def walk(x):
 if isinstance(x,dict):
  yield x
  for v in x.values():yield from walk(v)
 elif isinstance(x,list):
  for v in x:yield from walk(v)
def import_report(path):
 source=json.loads((ROOT/'assets/scene_survey/sites.json').read_text())
 report=json.loads(path.read_text());known={s['id']:s for s in source['sites']}
 assert report['layout_revision']=='od-layout-v2' and report['primary_validation_profile']==PROFILE
 old=json.loads((DIR/'catalog.json').read_text()) if (DIR/'catalog.json').exists() else {'schema':1,'sites':[]}
 indexed={s['id']:s for s in old['sites']};next_index=max((s['index'] for s in old['sites']),default=0)+1
 accepted=[]
 for row in report['sites']:
  if row['variant']!='compact':continue
  result=row.get('injured_functional_latest',{})
  if result.get('status')!='validated':continue
  site=known[row['site']];proof=result['functional_validation']
  assert result['position']==site['position'] and result['validation_profile']==PROFILE
  assert result['cleanup_confirmed'] and result['observed_seconds']>=3 and len(result['samples'])==10
  assert all(proof[k] for k in ['ground_supported','static_clear','vehicle_clear','aid_state_ready','path_confirmed'])
  assert proof['ready_seconds']>=3 and 0<=proof['aid_distance']<=2.5 and 0<=proof['scene_distance']<=25
  existing=indexed.get(site['id']);index=existing['index'] if existing else next_index
  if not existing:next_index+=1
  root=LEGACY if site['id']=='test_kryss_01' else 'quests/minor_quest/ncpd_patrol_officer_down_'+site['id']
  entry={'index':index,'id':site['id'],'label':site['label'],'position':site['position'],'heading':result['heading'],
   'enabled':existing.get('enabled',True) if existing else True,'quest_root':root,
   'validation_profile':PROFILE,'survey_catalog_revision':report['catalog_revision'],'survey_layout_revision':report['layout_revision'],
   'survey_timestamp':result.get('timestamp'),'source_report_sha256':sha(path)}
  indexed[site['id']]=entry;accepted.append(site['id'])
 assert accepted,'No current validated compact functional results to import'
 data={'schema':1,'coverage':source['coverage'],'sites':sorted(indexed.values(),key=lambda s:s['index'])}
 DIR.mkdir(parents=True,exist_ok=True);(DIR/'catalog.json').write_text(json.dumps(data,indent=2)+'\n')
 print('Imported verified compact sites: '+', '.join(accepted))
def outputs():
 data=json.loads((DIR/'catalog.json').read_text());sites=data['sites']
 assert data['schema']==1 and sites and [s['index'] for s in sites]==list(range(1,len(sites)+1))
 assert len({s['id'] for s in sites})==len(sites) and len({s['quest_root'] for s in sites})==len(sites)
 rev=sha(DIR/'catalog.json')
 lua=['-- Generated from assets/officer_down_sites/catalog.json; surveyed sites, rechecked at runtime.',
  'return {schema=1,revision='+json.dumps(rev)+',coverage='+json.dumps(', '.join(data['coverage'])+' only')+',sites={']
 native=['// Generated from assets/officer_down_sites/catalog.json. Stable indices and authored pins.',
  'public class NCPDPatrolOfficerDownCatalog extends IScriptable {',
  '    public static func Count() -> Int32 { return %d; }'%len(sites)]
 for s in sites:
  p=s['position'];assert s['validation_profile']==PROFILE and 0<=s['heading']<360
  lua.append(' {index=%d,id=%s,label=%s,x=%.9f,y=%.9f,z=%.9f,heading=%.9f,enabled=%s},'%(s['index'],json.dumps(s['id']),json.dumps(s['label']),p['x'],p['y'],p['z'],s['heading'],'true' if s['enabled'] else 'false'))
 lua.append('}}\n')
 native+=['    public static func Root(index: Int32) -> String {']
 for s in sites:native.append('        if index == %d { return "%s"; };'%(s['index'],s['quest_root']))
 native+=['        return "";','    }','    public static func Enabled(index: Int32) -> Bool {']
 for s in sites:native.append('        if index == %d { return %s; };'%(s['index'],'true' if s['enabled'] else 'false'))
 native+=['        return false;','    }','    public static func Position(index: Int32) -> Vector4 {','        let point: Vector4;','        point.W = 1.0;']
 for s in sites:
  p=s['position'];native.append('        if index == %d { point.X = %.9f; point.Y = %.9f; point.Z = %.9f; return point; };'%(s['index'],p['x'],p['y'],p['z']))
 native+=['        return point;','    }','}\n']
 doc=json.loads((ROOT/'assets/officer_down/officer_down.journal.json').read_text())
 folder=doc['Data']['RootChunk']['entry']['Data']['entries'][0]['Data'];template=folder['entries'][0];folder['entries']=[]
 anchor=json.loads((ROOT/'assets/quest_marker_probe/reference-contract.json').read_text());handle=2
 for s in sites:
  if s['quest_root']==LEGACY:continue # reuse the already proven original journal
  quest=copy.deepcopy(template);quest['Data']['id']=s['quest_root'].rsplit('/',1)[1]
  for row in walk(quest):
   if 'HandleId' in row:row['HandleId']=str(handle);handle+=1
   if row.get('$type')=='gameJournalQuestMapPin':
    row['mappinData']['active']=0
    row['reference']['reference']['$value']=anchor['node_reference']
    row['offset']={'$type':'Vector3',**{k.upper():v-anchor['position'][k.upper()]+anchor['offset'][k.upper()] for k,v in s['position'].items()}}
  folder['entries'].append(quest)
 validate(doc,data)
 xl='journal:\n  - base\\ncpd_patrol\\officer_down_sites\\officer_down_sites.journal\n'
 return {MOD/'officer_down_sites.lua':'\n'.join(lua),ROOT/'r6/scripts/NCPDPatrol/NCPDPatrolOfficerDownCatalog.reds':'\n'.join(native),
  DIR/'officer_down_sites.journal.json':json.dumps(doc,separators=(',',':'))+'\n',ROOT/'archive/pc/mod/NCPDPatrol_OfficerDownSites.archive.xl':xl}
def validate(doc,data=None):
 data=data or json.loads((DIR/'catalog.json').read_text());expected={s['quest_root'].rsplit('/',1)[1]:s for s in data['sites'] if s['quest_root']!=LEGACY}
 rows=list(walk(doc));handles=[r['HandleId'] for r in rows if 'HandleId' in r];assert len(handles)==len(set(handles))
 quests=[r for r in rows if r.get('$type')=='gameJournalQuest'];assert {r['id'] for r in quests}==set(expected)
 anchor=json.loads((ROOT/'assets/quest_marker_probe/reference-contract.json').read_text())
 for q in quests:
  pins=[r for r in walk(q) if r.get('$type')=='gameJournalQuestMapPin'];assert len(pins)==1
  pin=pins[0];assert pin['id']=='location' and pin['mappinData']['active']==0 and pin['enableGPS']
  assert pin['reference']['reference']['$value']==anchor['node_reference']
  for k,v in expected[q['id']]['position'].items():assert abs(pin['offset'][k.upper()]-(v-anchor['position'][k.upper()]+anchor['offset'][k.upper()]))<.001
 return len(quests)
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--import-report',type=Path);p.add_argument('--check',action='store_true');p.add_argument('--wk-cli',type=Path);a=p.parse_args()
 if a.import_report:import_report(a.import_report)
 generated=outputs()
 for path,body in generated.items():
  if a.check:assert path.read_text()==body,path
  else:path.parent.mkdir(parents=True,exist_ok=True);path.write_text(body)
 if not a.wk_cli:return
 def run(*args):subprocess.run([str(a.wk_cli.resolve()),*map(str,args)],check=True)
 with tempfile.TemporaryDirectory(prefix='ncpd-officer-sites-') as temp:
  t=Path(temp);pack=t/'NCPDPatrol_OfficerDownSites';depot=pack/'base/ncpd_patrol/officer_down_sites';depot.mkdir(parents=True)
  rt=t/'roundtrip';rt.mkdir();out=t/'out';out.mkdir()
  source=DIR/'officer_down_sites.journal.json';run('convert','deserialize',source,'--outpath',depot)
  resource=depot/'officer_down_sites.journal';expected=resource.read_bytes();assert expected[:4]==b'CR2W'
  run('convert','serialize',resource,'--outpath',rt);count=validate(json.loads((rt/source.name).read_text(encoding='utf-8-sig')))
  run('pack',pack,'--outpath',out);archive=out/'NCPDPatrol_OfficerDownSites.archive';ex=t/'extract';ex.mkdir();run('extract',archive,'--outpath',ex)
  files=[f for f in ex.rglob('*') if f.is_file()];assert len(files)==1 and files[0].read_bytes()==expected
  target=ROOT/'archive/pc/mod'/archive.name;shutil.copy2(archive,target)
  inputs=[DIR/'catalog.json',source,ROOT/'assets/officer_down/officer_down.journal.json',ROOT/'assets/quest_marker_probe/reference-contract.json']
  manifest={'archive_path':target.relative_to(ROOT).as_posix(),'archive_sha256':sha(target),'new_fixed_pins':count,
   'total_catalog_sites':len(json.loads((DIR/'catalog.json').read_text())['sites']),'original_archive_unchanged':True,
   'roundtrip_validated':True,'extracted_resource_bytes_compared':True,'all_new_pins_authored_inactive':True,
   'authored_inputs':{f.relative_to(ROOT).as_posix():sha(f) for f in inputs},'actual_game_validation':False}
  (DIR/'compiled.json').write_text(json.dumps(manifest,indent=2)+'\n')
 print('PASS: Officer Down catalogue and independent fixed pins compiled, round-tripped and extracted byte-identically')
if __name__=='__main__':main()
