"""Package the Voss waiting-pose confirmation fix with the complete prototype.

The release retains all 46 native scripts and all nine archives exactly.
"""
from pathlib import Path
from tempfile import TemporaryDirectory
import hashlib,json,os,re,subprocess,sys,zipfile
from build_vip_refactor_release import TESTS as EXISTING_TESTS
ROOT=Path(__file__).resolve().parents[1]
BASE='d9d49cc8084efdcd329d2ddb9572eb2bf254f963'
PREFIX='bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrol/'
NAME='NCPD_Patrol_v0.19f1_Voss_Pose_Check_Fix_TEST.zip'
REPORT='NCPD_Patrol_v0.19f1_Voss_Pose_Check_Fix_verification.json'
TESTS=[*EXISTING_TESTS,'tests/quest_marker_probe/check_probe.py','tests/fixed_markers/check_fixed.py','tests/vip_routes/check_routes.py','tests/officer_down/check_officer_down.py','tests/scene_survey/check_survey.py','tests/scene_survey/check_settling.py','tests/scene_survey/check_staging.py','tests/scene_survey/check_functional.py','tests/officer_down/check_catalog.py','tests/officer_down/check_gameplay.py','tests/partner_safety/check_safety.py','tests/officer_down/check_repeat.py','tests/scene_survey/check_discovery.py','tests/scene_survey/check_discovery_landing.py','tests/officer_down/check_site_expansion.py','tests/cet_ui/check_current_controls.py','tests/quest_giver/check_quest_giver.py','tests/quest_giver/check_voss_media.py','tests/quest_giver/check_subtitles.py']
def blob(b):return hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()
def main():
 from lupa.luajit21 import LuaRuntime
 modules=sorted((ROOT/PREFIX).glob('*.lua'));scripts=sorted((ROOT/'r6/scripts/NCPDPatrol').glob('*.reds'))
 assert len(modules)==46 and len(scripts)==46 and len(TESTS)==35
 lua=LuaRuntime()
 for p in modules:lua.eval('function(p) local f,e=loadfile(p);assert(f,e) end')(str(p))
 previous=subprocess.check_output(['git','ls-tree','-r','--name-only',BASE,'--','bin','r6','archive'],cwd=ROOT,text=True).splitlines()
 changed={PREFIX+n for n in ['init.lua','cet_ui.lua','quest_giver_test.lua']}
 sys.path.insert(0,str(ROOT/'tests/quest_marker_probe'))
 from probe_source import without_voss_pose_fix_branding
 for name in ['init.lua','cet_ui.lua']:
  current=without_voss_pose_fix_branding((ROOT/PREFIX/name).read_text())
  old=subprocess.check_output(['git','show',f'{BASE}:{PREFIX}{name}'],cwd=ROOT,text=True)
  if name=='cet_ui.lua':
   pattern=r'^        -- qgiver UI begin\n.*?^        -- qgiver UI end\n'
   current=re.sub(pattern,'',current,flags=re.M|re.S);old=re.sub(pattern,'',old,flags=re.M|re.S)
  assert current==old,name
 added=set()
 for name in previous:
  if name not in changed:assert (ROOT/name).read_bytes()==subprocess.check_output(['git','show',f'{BASE}:{name}'],cwd=ROOT),'Unrelated payload changed: '+name
 for name in ['LICENSE','assets/scene_survey/sites.json','assets/fixed_markers/catalog.json','assets/vip/route-sites.json','assets/quest_giver_test/media/voss_briefing.anims','assets/quest_giver_test/media/voss_briefing.wem','assets/quest_giver_test/contract.json','assets/quest_giver_test/compiled.json','assets/quest_giver_test/onscreens.json.json','assets/quest_giver_test/quest_giver.questphase.json','assets/quest_giver_test/quest_giver.journal.json','assets/quest_giver_test/conversation.scene.json','assets/quest_giver_test/lines.json.json','assets/quest_giver_test/subtitles.json.json','assets/quest_giver_test/vomap.json.json','assets/quest_giver_test/voss.lipmap.json','assets/quest_giver_test/voss_wait_pose.ent.json']:
  assert (ROOT/name).read_bytes()==subprocess.check_output(['git','show',f'{BASE}:{name}'],cwd=ROOT),'Existing data changed: '+name
 assert (ROOT/'THIRD_PARTY_NOTICES.txt').read_text().startswith(subprocess.check_output(['git','show',f'{BASE}:THIRD_PARTY_NOTICES.txt'],cwd=ROOT,text=True))
 old=json.loads(subprocess.check_output(['git','show',f'{BASE}:assets/officer_down_sites/catalog.json'],cwd=ROOT));catalog=json.loads((ROOT/'assets/officer_down_sites/catalog.json').read_text())
 assert len(catalog['sites'])==54 and catalog==old and all(s['enabled'] for s in catalog['sites'])
 paths=[p for d in ['bin','r6','archive'] for p in (ROOT/d).rglob('*') if p.is_file()]+[ROOT/n for n in ['README.txt','LICENSE','THIRD_PARTY_NOTICES.txt']]
 assert {p.relative_to(ROOT).as_posix() for p in paths}==set(previous)|added|{'README.txt','LICENSE','THIRD_PARTY_NOTICES.txt'}
 assert len(paths)==123
 comparisons={
 'dispatch':'tests/dispatch_refactor/check_refactor.py','ui':'tests/cet_ui/check_cet_ui.py',
 'vip':'tests/vip_refactor/check_vip_refactor.py','probe':'tests/quest_marker_probe/check_probe.py',
 'fixed_markers':'tests/fixed_markers/check_fixed.py','vip_routes':'tests/vip_routes/check_routes.py',
 'officer_down':'tests/officer_down/check_officer_down.py','scene_survey':'tests/scene_survey/check_survey.py',
 'injured_settling':'tests/scene_survey/check_settling.py','injured_placement':'tests/scene_survey/check_staging.py',
 'injured_functional':'tests/scene_survey/check_functional.py','officer_catalog':'tests/officer_down/check_catalog.py',
 'officer_gameplay':'tests/officer_down/check_gameplay.py','partner_safety':'tests/partner_safety/check_safety.py',
 'officer_repeat':'tests/officer_down/check_repeat.py','scene_discovery':'tests/scene_survey/check_discovery.py',
 'discovery_staging':'tests/scene_survey/check_discovery_landing.py','site_expansion':'tests/officer_down/check_site_expansion.py','current_controls':'tests/cet_ui/check_current_controls.py','quest_giver':'tests/quest_giver/check_quest_giver.py','voss_media':'tests/quest_giver/check_voss_media.py','voss_subtitles':'tests/quest_giver/check_subtitles.py'}
 with TemporaryDirectory(prefix='ncpd-quest-giver-prototype-release-') as tmp:
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
  assert z.testzip() is None and len(z.namelist())==len(set(z.namelist()))==123
  assert set(z.namelist())=={p.relative_to(ROOT).as_posix() for p in paths}
  assert not any(p.endswith('.jsonl') or p.endswith('_report.json') for p in z.namelist())
  for p in paths:assert z.read(p.relative_to(ROOT).as_posix())==p.read_bytes()
 body=release.read_bytes();compiled=json.loads((ROOT/'assets/officer_down_sites/compiled.json').read_text())
 report={'version':'v0.19f1-voss-pose-check-fix','base_commit':BASE,'source_commit':os.environ.get('GITHUB_SHA'),
  'install_files':len(paths),'lua_modules_parsed':len(modules),'redscript_files':len(scripts),'portable_tests':TESTS,
  'comparisons':results,'new_payload':sorted(added),'changed_payload':sorted(changed),
  'officer_down_sites':54,'all_54_existing_catalogue_entries_unchanged':True,
  'full_catalogue_all_sites_selectable_and_native_confirmed':results['current_controls']['full_catalogue_eligible_and_native_confirmed'],
  'retired_cet_buttons':results['current_controls']['retired_buttons'],
  'ordinary_request_samples':results['current_controls']['ordinary_request_samples'],
  'independent_fixed_pins':54,'additional_marker_archive_pins':53,'marker_archive_validation':compiled,
  'all_nine_archives_and_all_46_native_scripts_unchanged':True,
  'player_scene_membership_false_rejection_reproduced':results['quest_giver']['previous_scene_membership_false_rejection_reproduced'],
  'start_and_approach_use_dialogue_and_scene_tier_checks':True,
  'owned_actor_scene_release_guard_retained':True,
  'production_dispatch_facade_unchanged':True,
  'separate_native_scene_quest_and_private_actors':True,
  'quest_giver_choices':2,'quest_giver_english_voice_and_lipsync_bundled':True,'quest_giver_automatic_activation':False,
  'voss_briefing_seconds':results['voss_media']['audio']['duration_seconds'],
  'voss_shared_audio_lipsync_lead_in_ms':300,'voss_source_animation_byte_identical':True,'player_voice':False,
  'voss_native_workspot':'base\\workspots\\common\\ground\\generic__stand_ground_arms_crossed__stand_around__02.workspot',
  'voss_native_look_at_slot':'pla_default_tgt','voss_look_at_parts':['Eyes','Head'],
  'voss_pose_ready_before_conversation':results['quest_giver']['workspot_ready_before_conversation'],
  'voss_media_sms_pose_assets_and_quest_phase_unchanged':True,
  'v019f_active_pose_missing_device_user_despawn_reproduced':results['quest_giver']['v019f_active_pose_missing_device_user_despawn_reproduced'],
  'native_activity_without_device_user_completes_both_dialogue_paths':results['quest_giver']['native_activity_without_device_user_completes_both_dialogue_paths'],
  'native_extended_info_entering_exiting_fields_checked':results['quest_giver']['native_extended_info_entering_exiting_fields_checked'],
  'cosmetic_pose_failure_retains_actors_and_quest':results['quest_giver']['cosmetic_pose_failure_retains_actors_and_quest'],
  'voss_subtitle_parts':results['voss_subtitles']['subtitle_parts'],
  'voss_subtitles_ui_only_and_native_lifetime_preserved':True,
  'voss_grounded_waiting_pose_executed':results['quest_giver']['grounded_waiting_pose_executed'],
  'voss_pose_device_detaches_before_puppet_deletion':results['quest_giver']['pose_device_detaches_before_puppet_deletion'],
  'voss_no_body_pose_restart_at_greeting':results['quest_giver']['no_body_pose_restart_at_greeting'],
  'voss_native_helper_api_version':2,'voss_spawn_height_offset_metres':0.0,
  'andrea_mit_presentation_adaptation_credited':True,
  'voss_native_sms_intro':results['quest_giver']['native_sms_intro'],
  'voss_sms_history_retained_on_clear':results['quest_giver']['sms_history_retained_on_clear'],
  'voss_no_duplicate_message_entries':results['quest_giver']['no_duplicate_message_entries'],
  'voss_sms_exact_text_and_quest_attachment':results['quest_giver']['sms_exact_text_and_quest_attachment'],
  'voss_sms_milestone_activation':False,
  'quest_giver_actual_game_validation':False,
  'production_runtime_selection_scene_marker_cleanup_code_unchanged':True,
  'recorded_survey_discovery_and_gameplay_logs_preserved':True,
  'all_payment_career_and_runtime_evidence_ledgers_unchanged':True,
  'automatic_weights':{'scanner':45,'vip':27,'cyberpsycho':18,'officer_down':10},'officer_down_reward':2000,'career_credit':1,
  'browser_extension_still_optional':True,'existing_in_game_placement_evidence_preserved':True,
  'actual_new_quest_gameplay_validation':False,'observed_redscript_dispose_error_guarded':True,
  'game_checks_required':['OFF DUTY > Testing > Quest giver prototype > activate; independent journal quest and marker',
   'incoming native SMS from Lt. Mara Voss; exact supplied text in Messages, private contact/thread and meeting quest attachment',
   'stand near Voss for more than 15 seconds before dialogue; her active pose and Hella must remain without automatic cancellation',
   'clear/replay sends one new notification using the same single message; message history survives cancellation/completion',
   'both actors at supplied XYZ/yaw, exact investigator appearance, side-on Hella 4 m behind',
   'hello subtitle, 300 ms shared lead-in, uninterrupted 42 s Voss voice and lipsync, three text blocks at 0/15/28.5 seconds, two native choices, silent V reply and goodbye subtitle',
   'test voice routing and facial/head compatibility for both player genders; matching source rig remains unmodified',
   'Voss uses the native arms-crossed workspot at her own position; look at V eye-height slot through lines/choices when V moves slightly',
   'Voss already poses while waiting outside 3 m; feet align to ground and greeting does not lift/restart her body',
   'clear/replay and save/CET recovery retire the pose device before NPC/car after scene release',
   'journal succeeds only after goodbye, either choice; no career/payout',
   'clear/replay, cancellation during the briefing or at a choice, CET reload/save-load recovery with scoped cleanup'],
  'zip_path':release.relative_to(ROOT).as_posix(),'zip_bytes':len(body),'zip_sha256':hashlib.sha256(body).hexdigest(),'zip_git_blob':blob(body),
  'files':{p.relative_to(ROOT).as_posix():{'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'git_blob':blob(p.read_bytes())} for p in paths}}
 (ROOT/'releases'/REPORT).write_text(json.dumps(report,indent=2)+'\n')
 print(json.dumps({k:v for k,v in report.items() if k not in ['files','comparisons']},indent=2))
if __name__=='__main__':main()
