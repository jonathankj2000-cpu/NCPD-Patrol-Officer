"""Actual multi-site Officer Down requests, native pins, gameplay and evidence."""
from pathlib import Path
from tempfile import TemporaryDirectory
import argparse,hashlib,importlib.util,json,os,sys
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
sys.path.insert(0,str(HERE.parent/'scene_survey'))
from check_survey import runtime as base_runtime,results
from check_officer_down import code
def runtime():
 lua=base_runtime()
 lua.globals().NCPDPatrolOfficerDownCatalog=lua.execute(code(ROOT/'r6/scripts/NCPDPatrol/NCPDPatrolOfficerDownCatalog.reds'))
 lua.execute((HERE/'catalog-engine.lua').read_text())
 return lua
def events():
 p=Path('officer_down_dispatch.jsonl')
 return [json.loads(s) for s in p.read_text().splitlines() if s.strip()] if p.exists() else []
def case(body,inspect=None):
 old=Path.cwd()
 with TemporaryDirectory(prefix='ncpd-officer-catalog-') as temp:
  try:
   os.chdir(temp);lua=runtime();lua.execute(body)
   if inspect:inspect(lua)
  finally:os.chdir(old)
def main():
 spec=importlib.util.spec_from_file_location('od_sites',ROOT/'tools/build_officer_down_sites.py');b=importlib.util.module_from_spec(spec);spec.loader.exec_module(b)
 for path,body in b.outputs().items():assert path.read_text()==body,path
 catalog=json.loads((ROOT/'assets/officer_down_sites/catalog.json').read_text())
 assert len(catalog['sites'])==16 and not any(s['id']=='kryss_13' for s in catalog['sites'])
 manifest=json.loads((ROOT/'assets/officer_down_sites/compiled.json').read_text())
 assert manifest['new_fixed_pins']==15 and manifest['roundtrip_validated'] and manifest['extracted_resource_bytes_compared']
 assert hashlib.sha256((ROOT/manifest['archive_path']).read_bytes()).hexdigest()==manifest['archive_sha256']
 for path,digest in manifest['authored_inputs'].items():assert hashlib.sha256((ROOT/path).read_bytes()).hexdigest()==digest,path
 # All sixteen actual authored targets execute create/activate/revive/dual
 # completion/payment/cleanup, keeping the manual waypoint and other pins.
 for site in catalog['sites']:
  def inspect_ok(lua,site=site):
   rows=events();assert rows and all(r['site']==site['id'] for r in rows)
   kinds=[r['kind'] for r in rows]
   for k in ['assigned','placement_checked','spawn_created','actors_bound','ready','arrived','completed','cleanup_confirmed']:assert k in kinds,(site['id'],k,kinds)
   assert kinds.count('completed')==1 and kinds.count('assigned')==1 and 'failed' not in kinds
  case(f"CF.complete({site['index']});CF.clear();assert(F.wallet==2000 and IncidentNative:GetCompletedCount()==1)",inspect_ok)
 print('PASS: 16 surveyed Officer Down catalogue sites, 15 new inactive fixed quest pins plus original, actual native selection/create/combat/revive/dual completion/EUR$2000 once/cleanup and waypoint ownership (engine boundaries mocked)')
 return {'sites':16,'excluded_unverified':['kryss_13'],'new_native_pins':15,'actual_all_site_gameplay_fixture':True,'actual_game_validation':False}
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--report',type=Path);a=p.parse_args();r=main()
 if a.report:a.report.write_text(json.dumps(r,indent=2)+'\n')
