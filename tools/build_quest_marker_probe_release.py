"""Verify and package ownership-scoped Officer Down cleanup and repeat calls.

The established workflow entrypoint is retained. Fixed markers, dispatch actors,
archives, career ledgers, partner AI and existing shift cleanup stay unchanged.
"""
from pathlib import Path
from tempfile import TemporaryDirectory
import hashlib,json,os,subprocess,sys,zipfile
from build_vip_refactor_release import TESTS as EXISTING_TESTS
ROOT=Path(__file__).resolve().parents[1]
BASE='aa062a50866a26385e8441a3d818a919d6b979f5'
PREFIX='bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrol/'
NAME='NCPD_Patrol_v0.18e_Officer_Down_Cleanup_TEST.zip'
REPORT='NCPD_Patrol_v0.18e_Officer_Down_Cleanup_verification.json'
TESTS=[*EXISTING_TESTS,'tests/quest_marker_probe/check_probe.py','tests/fixed_markers/check_fixed.py','tests/vip_routes/check_routes.py','tests/officer_down/check_officer_down.py','tests/scene_survey/check_survey.py','tests/scene_survey/check_settling.py','tests/scene_survey/check_staging.py','tests/scene_survey/check_functional.py','tests/officer_down/check_catalog.py','tests/officer_down/check_gameplay.py','tests/partner_safety/check_safety.py','tests/officer_down/check_repeat.py']
def blob(b):return hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()
def main():
 from lupa.luajit21 import LuaRuntime
 modules=sorted((ROOT/PREFIX).glob('*.lua'));scripts=sorted((ROOT/'r6/scripts/NCPDPatrol').glob('*.reds'))
 assert len(modules)==43 and len(scripts)==44 and len(TESTS)==28
 lua=LuaRuntime()
 for p in modules:lua.eval('function(p) local f,e=loadfile(p);assert(f,e) end')(str(p))
 previous=subprocess.check_output(['git','ls-tree','-r','--name-only',BASE,'--','bin','r6','archive'],cwd=ROOT,text=True).splitlines()
 changed={PREFIX+n for n in ['init.lua','cet_ui.lua','officer_down.lua','officer_down_actors.lua']}
 changed.add('r6/scripts/NCPDPatrol/NCPDPatrolOfficerDownSystem.reds')
 added=set()
 for name in previous:
  if name not in changed:assert (ROOT/name).read_bytes()==subprocess.check_output(['git','show',f'{BASE}:{name}'],cwd=ROOT),'Unrelated payload changed: '+name
 paths=[p for d in ['bin','r6','archive'] for p in (ROOT/d).rglob('*') if p.is_file()]+[ROOT/n for n in ['README.txt','LICENSE','THIRD_PARTY_NOTICES.txt']]
 assert {p.relative_to(ROOT).as_posix() for p in paths}==set(previous)|added|{'README.txt','LICENSE','THIRD_PARTY_NOTICES.txt'}
 assert len(paths)==115
 comparisons={
 'dispatch':'tests/dispatch_refactor/check_refactor.py','ui':'tests/cet_ui/check_cet_ui.py',
 'vip':'tests/vip_refactor/check_vip_refactor.py','probe':'tests/quest_marker_probe/check_probe.py',
 'fixed_markers':'tests/fixed_markers/check_fixed.py','vip_routes':'tests/vip_routes/check_routes.py',
 'officer_down':'tests/officer_down/check_officer_down.py','scene_survey':'tests/scene_survey/check_survey.py',
 'injured_settling':'tests/scene_survey/check_settling.py','injured_placement':'tests/scene_survey/check_staging.py',
 'injured_functional':'tests/scene_survey/check_functional.py','officer_catalog':'tests/officer_down/check_catalog.py',
 'officer_gameplay':'tests/officer_down/check_gameplay.py','partner_safety':'tests/partner_safety/check_safety.py','officer_repeat':'tests/officer_down/check_repeat.py'}
 with TemporaryDirectory(prefix='ncpd-shift-controls-release-') as tmp:
  reports={test:Path(tmp)/(key+'.json') for key,test in comparisons.items()}
  for test in TESTS:
   args=[sys.executable,str(ROOT/test)]
   if test in reports:args+=['--report',str(reports[test])]
   subprocess.run(args,cwd=ROOT,check=True)
  results={key:json.loads(reports[test].read_text()) for key,test in comparisons.items()}
 release=ROOT/'releases'/NAME
 with zipfile.ZipFile(release,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=9) as z:
  for p in sorted(paths):
   info=zipfile.ZipInfo(p.relative_to(ROOT).as_posix(),(2026,11,21,0,0,0));info.compress_type=zipfile.ZIP_DEFLATED;info.create_system=3;info.external_attr=0o100644<<16
   z.writestr(info,p.read_bytes(),compresslevel=9)
 with zipfile.ZipFile(release) as z:
  assert z.testzip() is None and len(z.namelist())==len(set(z.namelist()))==115
  assert set(z.namelist())=={p.relative_to(ROOT).as_posix() for p in paths}
  assert not any(p.endswith('.jsonl') or p.endswith('officer_down_dispatch_report.json') or p.endswith('scene_survey_report.json') for p in z.namelist())
  for p in paths:assert z.read(p.relative_to(ROOT).as_posix())==p.read_bytes()
 body=release.read_bytes()
 report={'version':'v0.18e-officer-down-cleanup','base_commit':BASE,'source_commit':os.environ.get('GITHUB_SHA'),
  'install_files':len(paths),'lua_modules_parsed':len(modules),'redscript_files':len(scripts),'portable_tests':TESTS,
  'comparisons':results,'new_payload':sorted(added),'changed_payload':sorted(changed),
  'career_start_end_uses_existing_native_desired_request':True,'career_end_on_all_three_sections':True,
  'career_pending_duplicate_stale_and_world_guards':True,'career_button_never_directly_finishes_shift':True,
  'fast_travel_existing_start_end_unchanged':True,'officer_down_test_under_other_dispatch_tests':True,
  'partner_guard_exact_registered_actor_only':True,'partner_guard_on_duty_ready_world_only':True,
  'partner_guard_ranged_police_npc_and_vehicle_hits_only':True,'partner_guard_hostile_police_bypass':True,
  'partner_guard_before_original_on_hit':True,'original_v_and_other_actor_hits_passthrough':True,
  'global_heat_reset_or_immunity':False,'existing_wanted_termination_unchanged':True,
  'reference_vehicle_threat_and_combat_hit_paths_found':True,'reported_wanted_cause_proven':False,
  'reference_game_source_commit':'81d996b584a693e8b0f0b20526a9fa38b5c83fe7',
  'existing_43_native_scripts_and_eight_archives_unchanged_from_v018d':True,
  'scanner_vip_cyberpsycho_markers_survey_arrest_partner_and_backup_unchanged':True,
  'all_payment_and_career_ledgers_unchanged':True,'automatic_weights':{'scanner':45,'vip':27,'cyberpsycho':18,'officer_down':10},
  'officer_down_sites':16,'officer_down_reward':2000,'officer_down_career_credit':1,
  'browser_extension_still_optional':True,'actual_game_validation':False,
  'officer_down_reported_pattern':{'phase':'aftermath','stage':3,'owned_rows':3,'retained_handles':10},
  'manual_retry_can_end_completed_retention':True,'automatic_retention_seconds':90,'automatic_retention_distance_m':150,
  'vehicle_native_dispose_after_accepted_delete_seconds':5,'vehicle_dispose_requires_id_reference_record_generation_and_receipt':True,
  'disposal_is_not_physical_cleanup_proof':True,'detached_vehicle_id_registry_capacity':256,
  'detached_codeware_id_receipts_are_retained_and_pruned':True,'foreground_actor_id_ownership_kept_until_physical_clear':True,
  'background_cleanup_errors_preserve_successful_quest_and_other_types':True,'runtime_cause_and_engine_acknowledgement_confirmed':False,
  'game_checks_required':['repeat completed Officer Down calls through CET and automatic dispatch',
    'real stalled-car native disposal and/or detached Codeware ID retirement','no visible actors lost from cleanup ownership',
    'cancel/partial setup/CET reload/save load and refused physical cleanup','existing marker/reward/career behavior'],
  'zip_path':release.relative_to(ROOT).as_posix(),'zip_bytes':len(body),'zip_sha256':hashlib.sha256(body).hexdigest(),'zip_git_blob':blob(body),
  'files':{p.relative_to(ROOT).as_posix():{'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'git_blob':blob(p.read_bytes())} for p in paths}}
 (ROOT/'releases'/REPORT).write_text(json.dumps(report,indent=2)+'\n')
 print(json.dumps({k:v for k,v in report.items() if k not in ['files','comparisons']},indent=2))
if __name__=='__main__':main()
