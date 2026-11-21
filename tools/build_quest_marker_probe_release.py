"""Verify isolated terminal-offset discovery and package the complete test build.

The established workflow entrypoint remains. Production dispatch, approved
sites, marker archives, progression and existing survey evidence stay unchanged.
"""
from pathlib import Path
from tempfile import TemporaryDirectory
import hashlib,json,os,subprocess,sys,zipfile
from build_vip_refactor_release import TESTS as EXISTING_TESTS
ROOT=Path(__file__).resolve().parents[1]
BASE='26bd1ec4bc5c709faea4efe1caa3afb8328aa26c'
PREFIX='bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrol/'
NAME='NCPD_Patrol_v0.18g_Scene_Discovery_TEST.zip'
REPORT='NCPD_Patrol_v0.18g_Scene_Discovery_verification.json'
TESTS=[*EXISTING_TESTS,'tests/quest_marker_probe/check_probe.py','tests/fixed_markers/check_fixed.py','tests/vip_routes/check_routes.py','tests/officer_down/check_officer_down.py','tests/scene_survey/check_survey.py','tests/scene_survey/check_settling.py','tests/scene_survey/check_staging.py','tests/scene_survey/check_functional.py','tests/officer_down/check_catalog.py','tests/officer_down/check_gameplay.py','tests/partner_safety/check_safety.py','tests/officer_down/check_repeat.py','tests/scene_survey/check_discovery.py']
def blob(b):return hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()
def main():
 from lupa.luajit21 import LuaRuntime
 modules=sorted((ROOT/PREFIX).glob('*.lua'));scripts=sorted((ROOT/'r6/scripts/NCPDPatrol').glob('*.reds'))
 assert len(modules)==45 and len(scripts)==44 and len(TESTS)==29
 lua=LuaRuntime()
 for p in modules:lua.eval('function(p) local f,e=loadfile(p);assert(f,e) end')(str(p))
 previous=subprocess.check_output(['git','ls-tree','-r','--name-only',BASE,'--','bin','r6','archive'],cwd=ROOT,text=True).splitlines()
 changed={PREFIX+n for n in ['init.lua','cet_ui.lua','scene_survey.lua','scene_survey_store.lua']}
 changed.add('r6/scripts/NCPDPatrol/NCPDPatrolSceneSurveySystem.reds')
 added={PREFIX+n for n in ['scene_discovery.lua','scene_discovery_sites.lua']}
 for name in previous:
  if name not in changed:assert (ROOT/name).read_bytes()==subprocess.check_output(['git','show',f'{BASE}:{name}'],cwd=ROOT),'Unrelated payload changed: '+name
 for name in ['LICENSE','THIRD_PARTY_NOTICES.txt','assets/officer_down_sites/catalog.json','assets/scene_survey/sites.json','assets/fixed_markers/catalog.json','assets/vip/route-sites.json']:
  assert (ROOT/name).read_bytes()==subprocess.check_output(['git','show',f'{BASE}:{name}'],cwd=ROOT),'Existing data changed: '+name
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
 'officer_repeat':'tests/officer_down/check_repeat.py','scene_discovery':'tests/scene_survey/check_discovery.py'}
 with TemporaryDirectory(prefix='ncpd-scene-discovery-release-') as tmp:
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
 body=release.read_bytes()
 report={'version':'v0.18g-scene-discovery','base_commit':BASE,'source_commit':os.environ.get('GITHUB_SHA'),
  'install_files':len(paths),'lua_modules_parsed':len(modules),'redscript_files':len(scripts),'portable_tests':TESTS,
  'comparisons':results,'new_payload':sorted(added),'changed_payload':sorted(changed),
  'existing_43_other_native_scripts_and_eight_archives_unchanged_from_v018f':True,
  'production_dispatch_markers_rewards_arrest_partner_backup_and_wanted_logic_unchanged':True,
  'existing_17_survey_sites_and_16_approved_dispatch_sites_unchanged':True,'original_survey_ledgers_preserved':True,
  'scene_discovery':{'source':'Existing VIP terminal catalogue','anchors':60,'districts':6,
   'offset_radii_m':[10,20,30],'offset_bearings':8,'headings':[0,90,180,270,45,135,225,315],
   'layouts':['compact','standard'],'passes':2,'max_geometric_poses_per_terminal_layout':384,
   'min_geometry_interval_seconds':0.1,'nearby_pilot_terminals':3,'geometry_before_actor_creation':True,
   'full_ten_actor_functional_validation_required':True,'actual_grounded_candidate_coordinates_exported':True,
   'navmesh_alone_is_not_approval':True,'dedup_same_elevation_only':True,'automatic_dispatch_import':False,
   'off_duty_developer_only':True,'uses_existing_protected_teleport_and_recovery':True,'new_loading_screen':False,
   'native_recovery_mode_tag':True,'fresh_world_actor_lookup_before_discovery_transfer':True,
   'jsonl':'scene_discovery_results.jsonl','json':'scene_discovery_report.json'},
  'automatic_weights':{'scanner':45,'vip':27,'cyberpsycho':18,'officer_down':10},'browser_extension_still_optional':True,
  'observed_redscript_dispose_error_guarded':True,'actual_game_validation':False,
  'game_checks_required':['Nearest-three-terminal discovery on manual off-duty test save',
   'actual terrain/streaming support, slopes, nearby vehicles and alternate floors',
   'actual injured body landing and aid access at found compact/standard centers',
   'stop and CET reload recovery with no transfer before physical scene cleanup',
   'separate JSONL/JSON exports and original survey/production behavior',
   'combat and actual F revive at promising sites before later dispatch catalogue import'],
  'zip_path':release.relative_to(ROOT).as_posix(),'zip_bytes':len(body),'zip_sha256':hashlib.sha256(body).hexdigest(),'zip_git_blob':blob(body),
  'files':{p.relative_to(ROOT).as_posix():{'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'git_blob':blob(p.read_bytes())} for p in paths}}
 (ROOT/'releases'/REPORT).write_text(json.dumps(report,indent=2)+'\n')
 print(json.dumps({k:v for k,v in report.items() if k not in ['files','comparisons']},indent=2))
if __name__=='__main__':main()
