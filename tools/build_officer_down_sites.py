"""Import verified survey sites and bake independent, initially inactive quest pins.

New sites need a normal asset/package build; no journal marker is moved at runtime.
Existing indices/quest paths remain stable when another site is appended.
"""
from pathlib import Path
import argparse,copy,hashlib,json,math,re,shutil,subprocess,tempfile
ROOT=Path(__file__).resolve().parents[1]
DIR=ROOT/'assets/officer_down_sites'
MOD=ROOT/'bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrol'
PROFILE='injured-functional-v1'
LEGACY='quests/minor_quest/ncpd_patrol_officer_down'
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def coverage_union(*groups):
 names={('City Center (Central)' if name=='City Center' else name) for group in groups for name in group}
 return sorted(names)
def finite(v):return isinstance(v,(int,float)) and not isinstance(v,bool) and math.isfinite(v) and abs(v)<100000
def position(p):return isinstance(p,dict) and all(finite(p.get(k)) for k in 'xyz')
def distance(a,b):return math.dist([a[k] for k in 'xyz'],[b[k] for k in 'xyz'])
def discovery_evidence(report,digest):
 assert report['schema']==1 and report['layout_revision']=='od-layout-v2' and report['primary_validation_profile']==PROFILE
 rows={(r['site'],r['variant']):r for r in report['sites']}
 evidence=[]
 for candidate in report['verified_candidates']:
  if candidate['variant']!='compact':continue
  result=rows[(candidate['id'],'compact')]['injured_functional_proven']
  assert isinstance(result,dict) and result['status']=='validated'
  for key in ['position','heading','samples','functional_validation','observed_seconds','cleanup_confirmed']:
   assert candidate[key]==result[key],('Candidate/proof mismatch',candidate['id'],key)
  # Keep the accepted evidence once. Rejected attempts and full gameplay logs
  # are not needed in the checked-in production catalogue provenance.
  metadata={k:copy.deepcopy(v) for k,v in candidate.items() if k not in ['samples','functional_validation','observed_seconds','cleanup_confirmed']}
  keys=['schema','kind','site','variant','status','validation_profile','layout_revision','catalog_revision','timestamp',
   'position','heading','samples','functional_validation','observed_seconds','cleanup_confirmed']
  evidence.append({'source_report_sha256':digest,'survey_catalog_revision':report['catalog_revision'],
   'candidate':metadata,'result':{k:copy.deepcopy(result[k]) for k in keys}})
 assert evidence,'No validated compact discovery results to import'
 return evidence
def discovered_catalog(old,evidence):
 """Pure, append-only catalogue planning; all evidence is validated first."""
 vip=json.loads((ROOT/'assets/vip/route-sites.json').read_text())['sites']
 canonical={r['index']:r for r in json.loads((ROOT/'assets/fixed_markers/catalog.json').read_text())['sites']}
 sources={r['site']:r for r in vip};seen=set();validated=[]
 expected_kinds={'police':1,'gangcar':2,'injured':1,'defender':1,'enemy':5}
 for row in evidence:
  c,r=copy.deepcopy(row['candidate']),row['result']
  for key in ['samples','functional_validation','observed_seconds','cleanup_confirmed']:
   if key in c:assert c[key]==r[key]
   c[key]=r[key]
  source=sources[c['source_index']];anchor=canonical[c['source_index']]
  assert c['variant']=='compact' and c['source_id']==source['source_id'] and c['district']==source['district'] and c['label']==source['name']
  assert c['anchor_id']=='terminal_'+str(c['source_index']) and c['anchor_position']==anchor['position']
  assert c['radius'] in [10,20,30] and c['bearing'] in range(0,360,45)
  assert c['id']==c['anchor_id']+'_r'+str(c['radius'])+'_b'+str(c['bearing']) and re.fullmatch(r'terminal_\d+_r\d+_b\d+',c['id'])
  assert c['id'] not in seen;seen.add(c['id'])
  assert position(c['position']) and position(c['nominal_position']) and finite(c['heading']) and 0<=c['heading']<360
  nominal=c['nominal_position'];a=math.radians(c['bearing']);p=anchor['position']
  assert abs(nominal['x']-(p['x']+math.cos(a)*c['radius']))<.000002 and abs(nominal['y']-(p['y']+math.sin(a)*c['radius']))<.000002 and nominal['z']==p['z']
  assert (c['position']['x']-nominal['x'])**2+(c['position']['y']-nominal['y'])**2<=.250001 and abs(c['position']['z']-nominal['z'])<=1.3
  assert r['schema']==1 and r['kind']=='site_result' and r['site']==c['id'] and r['variant']=='compact' and r['status']=='validated'
  assert r['validation_profile']==PROFILE and r['layout_revision']=='od-layout-v2' and r['catalog_revision']==row['survey_catalog_revision']
  assert re.fullmatch('[0-9a-f]{64}',row['source_report_sha256']) and c['cleanup_confirmed'] is True
  assert finite(c['observed_seconds']) and c['observed_seconds']>=3 and isinstance(c['samples'],list) and len(c['samples'])==10
  kinds={}
  for sample in c['samples']:
   assert position(sample['expected']) and position(sample['actual']) and finite(sample['displacement']) and sample['displacement']>=0
   kinds[sample['kind']]=kinds.get(sample['kind'],0)+1
  assert kinds==expected_kinds
  proof=c['functional_validation']
  assert all(proof[k] is True for k in ['ground_supported','static_clear','vehicle_clear','aid_state_ready','path_confirmed']) and proof['revive_executed'] is False
  assert finite(proof['ready_seconds']) and proof['ready_seconds']>=3 and proof['scene_radius']==25
  assert finite(proof['aid_distance']) and 0<=proof['aid_distance']<=2.5 and finite(proof['scene_distance']) and 0<=proof['scene_distance']<=25
  assert position(proof['actual_position']) and position(proof['assistance_position'])
  assert abs(distance(proof['actual_position'],proof['assistance_position'])-proof['aid_distance'])<.02
  assert abs(distance(proof['actual_position'],c['position'])-proof['scene_distance'])<.02
  for key in ['position','heading','samples','functional_validation','observed_seconds','cleanup_confirmed']:assert c[key]==r[key]
  validated.append(row)
 indexed={s['id']:copy.deepcopy(s) for s in old['sites']};next_index=max((s['index'] for s in old['sites']),default=0)+1
 imported=[];duplicates=[];districts=[]
 for row in sorted(validated,key=lambda r:(r['candidate']['source_index'],r['candidate']['id'])):
  c,r=row['candidate'],row['result'];existing=indexed.get(c['id'])
  if existing:assert existing.get('source_type')=='terminal-offset-discovery','Refuse to replace a manually surveyed site'
  duplicate=next((s for s in indexed.values() if s['id']!=c['id'] and s['enabled']
   and (s['position']['x']-c['position']['x'])**2+(s['position']['y']-c['position']['y'])**2<=25 and abs(s['position']['z']-c['position']['z'])<=1),None)
  if duplicate:duplicates.append({'id':c['id'],'existing':duplicate['id']});continue
  index=existing['index'] if existing else next_index
  if not existing:next_index+=1
  indexed[c['id']]={'index':index,'id':c['id'],'label':c['label'],'position':copy.deepcopy(c['position']),'heading':c['heading'],
   'enabled':existing['enabled'] if existing else True,'quest_root':existing['quest_root'] if existing else 'quests/minor_quest/ncpd_patrol_officer_down_'+c['id'],
   'validation_profile':PROFILE,'survey_catalog_revision':row['survey_catalog_revision'],'survey_layout_revision':'od-layout-v2',
   'survey_timestamp':r.get('timestamp'),'source_report_sha256':row['source_report_sha256'],'source_type':'terminal-offset-discovery',
   'district':c['district'],'source_anchor_id':c['anchor_id'],'source_index':c['source_index'],'source_id':c['source_id'],
   'radius':c['radius'],'bearing':c['bearing'],'nominal_position':copy.deepcopy(c['nominal_position']),'layout':'compact'}
  imported.append(c['id']);districts.append(c['district'])
 return {'schema':1,'coverage':coverage_union(old.get('coverage',[]),districts),'sites':sorted(indexed.values(),key=lambda s:s['index'])},imported,duplicates
def import_discovery_report(path):
 report=json.loads(path.read_text());entries=discovery_evidence(report,sha(path));evidence_path=DIR/'discovery_import.json'
 previous=json.loads(evidence_path.read_text())['sites'] if evidence_path.exists() else []
 combined={row['candidate']['id']:row for row in previous}
 combined.update({row['candidate']['id']:row for row in entries})
 evidence=sorted(combined.values(),key=lambda r:(r['candidate']['source_index'],r['candidate']['id']))
 old=json.loads((DIR/'catalog.json').read_text());data,accepted,duplicates=discovered_catalog(old,evidence)
 evidence_path.write_text(json.dumps({'schema':1,'sites':evidence},indent=2)+'\n')
 (DIR/'catalog.json').write_text(json.dumps(data,indent=2)+'\n')
 print('Imported validated compact discovery sites: %d | duplicates skipped: %d | total catalogue: %d'%(len(accepted),len(duplicates),len(data['sites'])))
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
 data={'schema':1,'coverage':coverage_union(old.get('coverage',[]),source['coverage']),'sites':sorted(indexed.values(),key=lambda s:s['index'])}
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
 p=argparse.ArgumentParser(description=__doc__);group=p.add_mutually_exclusive_group();group.add_argument('--import-report',type=Path);group.add_argument('--import-discovery-report',type=Path);p.add_argument('--check',action='store_true');p.add_argument('--wk-cli',type=Path);a=p.parse_args()
 if a.import_report:import_report(a.import_report)
 if a.import_discovery_report:import_discovery_report(a.import_discovery_report)
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
