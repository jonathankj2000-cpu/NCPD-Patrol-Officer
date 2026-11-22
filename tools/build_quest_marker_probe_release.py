"""Verify 38 approved compact site imports and package expanded Officer Down.

The established workflow entrypoint remains. Existing site/quest identity,
other archives, runtime dispatch and durable ledgers stay unchanged.
"""
from pathlib import Path
from tempfile import TemporaryDirectory
import hashlib,json,os,subprocess,sys,zipfile
from build_vip_refactor_release import TESTS as EXISTING_TESTS
ROOT=Path(__file__).resolve().parents[1]
BASE='1535e5f408e1767272df3d7cd459a1a4de00cad7'
PREFIX='bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrol/'
NAME='NCPD_Patrol_v0.18h_Expanded_Officer_Down_TEST.zip'
REPORT='NCPD_Patrol_v0.18h_Expanded_Officer_Down_verification.json'
TESTS=[*EXISTING_TESTS,'tests/quest_marker_probe/check_probe.py','tests/fixed_markers/check_fixed.py','tests/vip_routes/check_routes.py','tests/officer_down/check_officer_down.py','tests/scene_survey/check_survey.py','tests/scene_survey/check_settling.py','tests/scene_survey/check_staging.py','tests/scene_survey/check_functional.py','tests/officer_down/check_catalog.py','tests/officer_down/check_gameplay.py','tests/partner_safety/check_safety.py','tests/officer_down/check_repeat.py','tests/scene_survey/check_discovery.py','tests/scene_survey/check_discovery_landing.py','tests/officer_down/check_site_expansion.py']
def blob(b):return hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()
def main():
 from lupa.luajit21 import LuaRuntime
 modules=sorted((ROOT/PREFIX).glob('*.lua'));scripts=sorted((ROOT/'r6/scripts/NCPDPatrol').glob('*.reds'))
 assert len(modules)==45 and len(scripts)==44 and len(TESTS)==31
 lua=LuaRuntime()
 for p in modules:lua.eval('function(p) local f,e=loadfile(p);assert(f,e) end')(str(p))
 previous=subprocess.check_output(['git','ls-tree','-r','--name-only',BASE,'--','bin','r6','archive'],cwd=ROOT,text=True).splitlines()
 changed={PREFIX+n for n in ['init.lua','cet_ui.lua','officer_down_sites.lua']}
 changed.update(['r6/scripts/NCPDPatrol/NCPDPatrolOfficerDownCatalog.reds','archive/pc/mod/NCPDPatrol_OfficerDownSites.archive'])
 added=set()
 for name in previous:
  if name not in changed:assert (ROOT/name).read_bytes()==subprocess.check_output(['git','show',f'{BASE}:{name}'],cwd=ROOT),'Unrelated payload changed: '+name
 for name in ['LICENSE','THIRD_PARTY_NOTICES.txt','assets/scene_survey/sites.json','assets/fixed_markers/catalog.json','assets/vip/route-sites.json']:
  assert (ROOT/name).read_bytes()==subprocess.check_output(['git','show',f'{BASE}:{name}'],cwd=ROOT),'Existing data changed: '+name
 old=json.loads(subprocess.check_output(['git','show',f'{BASE}:assets/officer_down_sites/catalog.json'],cwd=ROOT));catalog=json.loads((ROOT/'assets/officer_down_sites/catalog.json').read_text())
 assert len(old['sites'])==16 and len(catalog['sites'])==54 and catalog['sites'][:16]==old['sites']
 paths=[p for d in ['bin','r6','archive'] for p in (ROOT/d).rglob('*') if p.is_file()]+[ROOT/n for n in ['README.txt','LICENSE','THIRD_PARTY_NOTICES.txt']]
 assert {p.relative_to(ROOT).as_posix() for p in paths}==set(previous)|added|{'README.txt','LICENSE','THIRD_PARTY_NOTICES.txt'}
 assert len(paths)==117
 comparisons={
 'dispatch':'tests/dispatch_refactor/check_refactor.py','ui':'tests/cet_ui/check_cet_ui.py',
 'vip':'tests/vip_refactor/check_vip_refactor.py','probe':'tests/quest_marker_probe/check_probe.py',
 'fixed_markers':'tests/fixed_markers/check_fixed.py','vip_routes':'tests/vip_routes/check_routes.py',
 'officer_down':'tests/officer_down/check_officer_down.py','scene_survey':'tests/scene_survey/check_survey.py',
 'injured_settling':'tests/scene_survey/check_settling.py','injured_placement':'tests/scene_survey/check_staging.py',
 'injured_functional':'tests/scene_survey/check_functional.py','officer_catalog':'tests/officer_down/check_catalog.py',
 'officer_gameplay':'tests/officer_down/check_gameplay.py','partner_safety':'tests/partner_safety/check_safety.py',
 'officer_repeat':'tests/officer_down/check_repeat.py','scene_discovery':'tests/scene_survey/check_discovery.py',
 'discovery_staging':'tests/scene_survey/check_discovery_landing.py','site_expansion':'tests/officer_down/check_site_expansion.py'}
 with TemporaryDirectory(prefix='ncpd-expanded-officer-down-release-') as tmp:
  reports={test:Path(tmp)/(key+'.json') for key,test in comparisons.items()}
  for test in TESTS:
   args=[sys.executable,str(ROOT/test)]
   if test in reports:args+=['--report',str(reports[test])]
   subprocess.run(args,cwd=ROOT,check=True)
  results={key:json.loads(reports[test].read_text()) for key,test in comparisons.items()}
 release=ROOT/'releases'/NAME
 with zipfile.ZipFile(release,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=9) as z:
  for p in sorted(paths):
   info=zipfile.ZipInfo(p.relative_to(ROOT).as_posix(),(2026,11,22,0,0,0));info.compress_type=zipfile.ZIP_DEFLATED;info.create_system=3;info.external_attr=0o100644<<16
   z.writestr(info,p.read_bytes(),compresslevel=9)
 with zipfile.ZipFile(release) as z:
  assert z.testzip() is None and len(z.namelist())==len(set(z.namelist()))==117
  assert set(z.namelist())=={p.relative_to(ROOT).as_posix() for p in paths}
  assert not any(p.endswith('.jsonl') or p.endswith('_report.json') for p in z.namelist())
  for p in paths:assert z.read(p.relative_to(ROOT).as_posix())==p.read_bytes()
 body=release.read_bytes();compiled=json.loads((ROOT/'assets/officer_down_sites/compiled.json').read_text())
 report={'version':'v0.18h-expanded-officer-down','base_commit':BASE,'source_commit':os.environ.get('GITHUB_SHA'),
  'install_files':len(paths),'lua_modules_parsed':len(modules),'redscript_files':len(scripts),'portable_tests':TESTS,
  'comparisons':results,'new_payload':sorted(added),'changed_payload':sorted(changed),
  'officer_down_sites':54,'previous_16_entries_preserved_verbatim':True,'imported_compact_sites':38,
  'imported_districts':results['site_expansion']['imported_by_district'],'actual_approved_grounded_positions_and_headings':True,
  'independent_fixed_pins':54,'additional_marker_archive_pins':53,'previous_15_quest_chunks_identical':True,
  'all_pins_initially_inactive':True,'marker_archive_compiled_roundtripped_extracted':compiled,
  'seven_other_archives_and_43_other_native_scripts_unchanged':True,'runtime_dispatch_scene_marker_cleanup_code_unchanged':True,
  'original_17_survey_sites_and_discovery_tools_unchanged':True,'all_payment_career_and_runtime_evidence_ledgers_unchanged':True,
  'automatic_weights':{'scanner':45,'vip':27,'cyberpsycho':18,'officer_down':10},'officer_down_reward':2000,'career_credit':1,
  'browser_extension_still_optional':True,'actual_in_game_placement_evidence_imported':True,
  'actual_new_dispatch_gameplay_validation':False,'observed_redscript_dispose_error_guarded':True,
  'game_checks_required':['Officer Down dispatch near imported districts: correct scene and independent quest pin',
   'existing 50 m mounted arrival, live combat, actual F revive and both completion conditions',
   'EUR$2000 and career credit exactly once; automatic and manual repeat after cleanup',
   'CET reload/save load marker/actor cleanup and no impact on manual waypoints',
   'retain and export Officer Down gameplay reliability logs for new IDs'],
  'zip_path':release.relative_to(ROOT).as_posix(),'zip_bytes':len(body),'zip_sha256':hashlib.sha256(body).hexdigest(),'zip_git_blob':blob(body),
  'files':{p.relative_to(ROOT).as_posix():{'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'git_blob':blob(p.read_bytes())} for p in paths}}
 (ROOT/'releases'/REPORT).write_text(json.dumps(report,indent=2)+'\n')
 print(json.dumps({k:v for k,v in report.items() if k not in ['files','comparisons']},indent=2))
if __name__=='__main__':main()
