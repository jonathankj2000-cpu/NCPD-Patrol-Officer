"""Verify and package multi-site Officer Down dispatch with gameplay evidence.

The workflow entrypoint is retained. Existing incident/marker archives are
unchanged; one independent journal archive adds surveyed Officer Down sites.
"""
from pathlib import Path
from tempfile import TemporaryDirectory
import hashlib,json,os,subprocess,sys,zipfile
from build_vip_refactor_release import TESTS as EXISTING_TESTS
ROOT=Path(__file__).resolve().parents[1]
BASE='25d0afb06c5240423d92f11ec842c333986fe164'
PREFIX='bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrol/'
NAME='NCPD_Patrol_v0.18c_Officer_Down_Dispatch_TEST.zip'
REPORT='NCPD_Patrol_v0.18c_Officer_Down_Dispatch_verification.json'
TESTS=[*EXISTING_TESTS,'tests/quest_marker_probe/check_probe.py','tests/fixed_markers/check_fixed.py','tests/vip_routes/check_routes.py','tests/officer_down/check_officer_down.py','tests/scene_survey/check_survey.py','tests/scene_survey/check_settling.py','tests/scene_survey/check_staging.py','tests/scene_survey/check_functional.py','tests/officer_down/check_catalog.py','tests/officer_down/check_gameplay.py']
def blob(b):return hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()
def main():
 from lupa.luajit21 import LuaRuntime
 modules=sorted((ROOT/PREFIX).glob('*.lua'));scripts=sorted((ROOT/'r6/scripts/NCPDPatrol').glob('*.reds'))
 assert len(modules)==43 and len(scripts)==43
 lua=LuaRuntime()
 for p in modules:lua.eval('function(p) local f,e=loadfile(p);assert(f,e) end')(str(p))
 previous=subprocess.check_output(['git','ls-tree','-r','--name-only',BASE,'--','bin','r6','archive'],cwd=ROOT,text=True).splitlines()
 changed={PREFIX+n for n in ['init.lua','cet_ui.lua','dispatch.lua','dispatch_scheduler.lua','officer_down.lua','officer_down_actors.lua','scene_survey.lua']}
 changed.update('r6/scripts/NCPDPatrol/'+n for n in ['NCPDPatrolSceneSurveySystem.reds','NCPDPatrolOfficerDownSystem.reds'])
 added={PREFIX+n for n in ['officer_down_sites.lua','officer_down_selection.lua','officer_down_log.lua']}
 added.update('r6/scripts/NCPDPatrol/'+n for n in ['NCPDPatrolOfficerDownCatalog.reds','NCPDPatrolAidAccess.reds'])
 added.update('archive/pc/mod/'+n for n in ['NCPDPatrol_OfficerDownSites.archive','NCPDPatrol_OfficerDownSites.archive.xl'])
 for name in previous:
  if name not in changed:assert (ROOT/name).read_bytes()==subprocess.check_output(['git','show',f'{BASE}:{name}'],cwd=ROOT),'Unrelated payload changed: '+name
 paths=[p for d in ['bin','r6','archive'] for p in (ROOT/d).rglob('*') if p.is_file()]+[ROOT/n for n in ['README.txt','LICENSE','THIRD_PARTY_NOTICES.txt']]
 assert {p.relative_to(ROOT).as_posix() for p in paths}==set(previous)|added|{'README.txt','LICENSE','THIRD_PARTY_NOTICES.txt'}
 assert len(paths)==114
 comparisons={
 'dispatch':'tests/dispatch_refactor/check_refactor.py','ui':'tests/cet_ui/check_cet_ui.py',
 'vip':'tests/vip_refactor/check_vip_refactor.py','probe':'tests/quest_marker_probe/check_probe.py',
 'fixed_markers':'tests/fixed_markers/check_fixed.py','vip_routes':'tests/vip_routes/check_routes.py',
 'officer_down':'tests/officer_down/check_officer_down.py','scene_survey':'tests/scene_survey/check_survey.py',
 'injured_settling':'tests/scene_survey/check_settling.py','injured_placement':'tests/scene_survey/check_staging.py',
 'injured_functional':'tests/scene_survey/check_functional.py','officer_catalog':'tests/officer_down/check_catalog.py',
 'officer_gameplay':'tests/officer_down/check_gameplay.py'}
 with TemporaryDirectory(prefix='ncpd-officer-down-release-') as tmp:
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
  assert z.testzip() is None and len(z.namelist())==len(set(z.namelist()))==114
  assert set(z.namelist())=={p.relative_to(ROOT).as_posix() for p in paths}
  for p in paths:assert z.read(p.relative_to(ROOT).as_posix())==p.read_bytes()
 body=release.read_bytes()
 report={'version':'v0.18c-officer-down-dispatch','base_commit':BASE,'source_commit':os.environ.get('GITHUB_SHA'),
  'install_files':len(paths),'lua_modules_parsed':len(modules),'redscript_files':len(scripts),'portable_tests':TESTS,
  'comparisons':results,'new_payload':sorted(added),'changed_payload':sorted(changed),
  'scene':json.loads((ROOT/'assets/officer_down/scene.json').read_text()),
  'compiled_scene_resources':json.loads((ROOT/'assets/officer_down/compiled.json').read_text()),
  'existing_six_archives_unchanged_from_v017f':True,'native_fixed_marker_controller_catalog_and_diagnostics_unchanged':True,
  'vip_actor_ambush_and_baked_routes_unchanged':True,'arrest_partner_and_backup_unchanged':True,
  'existing_economy_unchanged':True,'officer_down_reward':2000,'generated_career_credit':1,
  'automatic_weights':{'scanner':45,'vip':27,'cyberpsycho':18,'officer_down':10},'officer_down_manual_only':False,
  'unavailable_catalogue_preserves_original_relative_mix':{'scanner':50,'vip':30,'cyberpsycho':20},
  'world_reset_forgets_old_ids':True,'main_partner_registration_reused':False,
  'native_marker_never_unregistered':True,'automatic_dispatch_manual_waypoint_never_written':True,
  'manual_test_locator_on_explicit_click':True,'existing_39_native_scripts_and_seven_archives_unchanged_from_v018b3':True,
  'ground_probe_height_metres':1.5,
  'ground_height_limit_metres':1.3,'ground_normal_z_minimum':0.85,'vehicle_corner_height_limit_metres':0.4,
  'raycast_vector3_converted_to_navigation_vector4':True,'ground_rejections_include_specific_reason':True,
  'automatic_scene_rotation_order':[0,90,180,270],'manual_preferred_heading_retained':True,
  'vehicle_overlap_for_all_ten_spawn_positions':True,'rotation_only_before_any_actor_creation':True,
  'prepare_radius_metres':250,'prepare_retry_near_radius_metres':180,
  'prepare_retry_interval_seconds':1,'prepare_retry_near_grace_seconds':8,
  'placement_retries_pause_with_menus_and_unready_session':True,'ambient_traffic_settings_unchanged':True,
  'ambient_traffic_free_scene_guaranteed':False,
  'production_officer_down_layout':'compact','police_gang_line_gap_metres':12,'gang_lateral_offsets_metres':[-5.5,5.5],'gang_center_gap_metres':11,
  'survey_sites':17,'new_docx_sites':16,'original_test_site_included':True,'survey_coverage':['City Center (Central)','Watson'],
  'survey_catalog_source':'assets/scene_survey/sites.json','survey_catalog_sha256':hashlib.sha256((ROOT/'assets/scene_survey/sites.json').read_bytes()).hexdigest(),
  'survey_off_duty_only':True,'survey_starts_quests_or_pays_rewards':False,'survey_max_concurrent_test_actors':10,
  'survey_stability_seconds':3,'survey_reuses_production_layout_and_actor_code':True,
  'survey_confirms_physical_detach_before_next_transfer':True,'survey_saves_proven_rotations_and_positions':True,
  'survey_automatic_resume_after_save_reload':False,'survey_cet_reload_has_native_id_recovery':True,
  'survey_uses_controlled_teleport_and_readiness_checks':True,'memory_purging_loading_screen_claimed':False,
  'survey_results_are_preapproved_dispatch_locations':False,
  'changed_native_scripts':['NCPDPatrolOfficerDownSystem.reds','NCPDPatrolSceneSurveySystem.reds'],
  'new_native_scripts':['NCPDPatrolOfficerDownCatalog.reds','NCPDPatrolAidAccess.reds'],
  'officer_down_layout_geometry_unchanged_from_v018b':True,'explicit_legacy_17_site_runtime_and_evidence_comparison_identical':True,
  'injured_settling_opt_in_only':True,'injured_pilot_sites':['kryss_04','kryss_11','kryss_15'],
  'injured_pilot_profile':'injured-settling-pilot-v1','injured_settle_active_seconds':4,
  'injured_pilot_final_original_position_limit_m':1.5,'injured_pilot_observation_anchor_drift_m':0.15,
  'injured_pilot_temporal_motion_envelope_m':{'horizontal':3,'vertical':1.5},
  'injured_motion_samples_include_original_actual_world_and_local_delta':True,
  'passive_settling_pilot_actor_teleport_or_spawn_offset_compensation':False,
  'injured_pilot_results_separate_from_legacy':True,'animation_root_motion_cause_proven':False,
  'injured_placement_opt_in_only':True,'injured_placement_profile':'injured-staging-pilot-v1',
  'injured_placement_stage_active_seconds':4,'injured_placement_uncorrected_release_seconds':.5,
  'injured_placement_uncorrected_observation_seconds':3,'injured_placement_final_original_position_limit_m':1.5,
  'injured_placement_native_gate_closed_before_final_observation':True,
  'injured_placement_expected_position_rebased_or_offset_compensated':False,
  'injured_placement_ignored_teleports_and_continued_drift_rejected':True,
  'injured_placement_results_separate_from_legacy_and_passive_pilot':True,
  'normal_full_tour_UI_uses_functional_profile':True,'functional_profile':'injured-functional-v1',
  'functional_injured_spawn_displacement_limit_m':None,'functional_injured_root_stability_anchor_m':None,
  'functional_scene_radius_m':25,'functional_aid_range_m':2.5,'functional_usable_aid_window_seconds':3,
  'functional_initial_settle_seconds':4,'functional_observation_timeout_seconds':12,
  'functional_complete_navigation_path_and_local_access_required':True,
  'functional_actor_teleport_or_position_rebase':False,'functional_other_nine_actors_keep_original_checks':True,
  'functional_actual_revive_executed':False,'functional_profiles_primary_export_and_retry_are_separate':True,
  'officer_down_catalog':json.loads((ROOT/'assets/officer_down_sites/catalog.json').read_text()),
  'officer_down_new_resources':json.loads((ROOT/'assets/officer_down_sites/compiled.json').read_text()),
  'officer_down_sites':16,'officer_down_excluded_unverified_sites':['kryss_13'],'officer_down_new_inactive_pins':15,
  'officer_down_search_bands_m':[1000,2000,5000],'officer_down_minimum_assignment_distance_m':500,
  'officer_down_failed_site_active_cooldown_seconds':120,'officer_down_injured_uses_functional_checks_without_position_lock':True,
  'officer_down_native_created_ids_and_physical_handles_retained_for_cet_recovery':True,
  'officer_down_gameplay_logs':['officer_down_dispatch.jsonl','officer_down_dispatch_report.json'],
  'officer_down_log_failure_does_not_change_gameplay_or_payments':True,'officer_down_survey_tools_and_old_logs_preserved':True,
  'partial_cleanup_reserves_scene':True,'successful_aftermath_reserves_dispatch':False,
  'browser_extension_still_optional':True,'actual_game_validation':False,
  'game_checks_required':['16 new catalogue call paths and native quest marker rendering/reuse','real traffic/road streaming and natural injured access','officer recovery animation and F interaction','combat AI/cover and backup cooperation','repeated completions/failures and automatic resume','gameplay JSONL/export over longer sessions','survey cancellation/return and CET recovery'],
  'zip_path':release.relative_to(ROOT).as_posix(),'zip_bytes':len(body),'zip_sha256':hashlib.sha256(body).hexdigest(),'zip_git_blob':blob(body),
  'files':{p.relative_to(ROOT).as_posix():{'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'git_blob':blob(p.read_bytes())} for p in paths}}
 (ROOT/'releases'/REPORT).write_text(json.dumps(report,indent=2)+'\n')
 print(json.dumps({k:v for k,v in report.items() if k not in ['files','comparisons']},indent=2))
if __name__=='__main__':main()
