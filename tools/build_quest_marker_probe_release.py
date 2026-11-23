"""Build the complete Voss-to-Off-the-Books continuation fix."""
from pathlib import Path
from tempfile import TemporaryDirectory
import hashlib,json,os,subprocess,sys,zipfile
from build_vip_refactor_release import TESTS as EXISTING_TESTS
ROOT=Path(__file__).resolve().parents[1]
BASE='bc60498ee9bcd62b649f51d4cb09eded79ecee1c'
PREFIX='bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrol/'
NAME='NCPD_Patrol_v0.20b_Voss_Continuation_TEST.zip'
REPORT='NCPD_Patrol_v0.20b_Voss_Continuation_verification.json'
TESTS=[*EXISTING_TESTS,'tests/quest_marker_probe/check_probe.py','tests/fixed_markers/check_fixed.py','tests/vip_routes/check_routes.py','tests/officer_down/check_officer_down.py','tests/scene_survey/check_survey.py','tests/scene_survey/check_settling.py','tests/scene_survey/check_staging.py','tests/scene_survey/check_functional.py','tests/officer_down/check_catalog.py','tests/officer_down/check_gameplay.py','tests/partner_safety/check_safety.py','tests/officer_down/check_repeat.py','tests/scene_survey/check_discovery.py','tests/scene_survey/check_discovery_landing.py','tests/officer_down/check_site_expansion.py','tests/cet_ui/check_current_controls.py','tests/quest_giver/check_quest_giver.py','tests/quest_giver/check_voss_media.py','tests/quest_giver/check_subtitles.py','tests/quest_giver/check_scene_ids.py','tests/quest_giver/check_timing.py','tests/quest_giver/check_pose_idle.py','tests/off_the_books/check_off_books.py','tests/off_the_books/check_retention.py','tests/off_the_books/check_handoff.py']


def blob(b):return hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()
def previous(path):return subprocess.check_output(['git','show',f'{BASE}:{path}'],cwd=ROOT)
def main():
 from lupa.luajit21 import LuaRuntime
 modules=sorted((ROOT/PREFIX).glob('*.lua'));scripts=sorted((ROOT/'r6/scripts/NCPDPatrol').glob('*.reds'))
 assert len(modules)==47 and len(scripts)==48 and len(TESTS)==41
 lua=LuaRuntime()
 for p in modules:lua.eval('function(p) local f,e=loadfile(p);assert(f,e) end')(str(p))
 oldpaths=subprocess.check_output(['git','ls-tree','-r','--name-only',BASE,'--','bin','r6','archive'],cwd=ROOT,text=True).splitlines()
 changed={PREFIX+n for n in ['init.lua','cet_ui.lua','quest_giver_test.lua','off_the_books.lua']}
 changed.update({'r6/scripts/NCPDPatrol/NCPDPatrolQuestGiverTest.reds','r6/scripts/NCPDPatrol/NCPDPatrolOffBooksSystem.reds','archive/pc/mod/NCPDPatrol_QuestGiverTest.archive'})
 sys.path.insert(0,str(ROOT/'tests/quest_marker_probe'));from probe_source import without_offbooks_handoff
 sys.path.insert(0,str(ROOT/'tests/quest_giver'));from handoff_source import without_handoff_lua,without_handoff_native
 for name in ['init.lua','cet_ui.lua']:assert without_offbooks_handoff((ROOT/PREFIX/name).read_text())==previous(PREFIX+name).decode(),name
 assert without_handoff_lua((ROOT/PREFIX/'quest_giver_test.lua').read_text())==previous(PREFIX+'quest_giver_test.lua').decode()
 assert without_handoff_native((ROOT/'r6/scripts/NCPDPatrol/NCPDPatrolQuestGiverTest.reds').read_text())==previous('r6/scripts/NCPDPatrol/NCPDPatrolQuestGiverTest.reds').decode()
 for path in oldpaths:
  if path not in changed:assert (ROOT/path).read_bytes()==previous(path),'Unrelated payload changed: '+path
 for path in ['LICENSE','THIRD_PARTY_NOTICES.txt','assets/scene_survey/sites.json','assets/fixed_markers/catalog.json','assets/vip/route-sites.json','assets/officer_down_sites/catalog.json']:
  assert (ROOT/path).read_bytes()==previous(path),'Existing data changed: '+path
 # Every authored first-conversation input except its phase/manifest stays
 # exact, including scene timing, all captions, SMS, workspot, lip and audio.
 assets=subprocess.check_output(['git','ls-tree','-r','--name-only',BASE,'--','assets/quest_giver_test','assets/off_the_books'],cwd=ROOT,text=True).splitlines()
 for path in assets:
  if path not in {'assets/quest_giver_test/quest_giver.questphase.json','assets/quest_giver_test/graph-contract.json','assets/quest_giver_test/compiled.json'}:
   assert (ROOT/path).read_bytes()==previous(path),'Unrelated asset changed: '+path
 audit=json.loads((ROOT/'assets/quest_giver_test/handoff-resource-audit.json').read_text())
 assert audit['baseline']==BASE and audit['extracted_resources']==16 and len(audit['unchanged_binary_resources'])==15
 assert audit['only_changed_resources']==['base/ncpd_patrol/quest_giver_test/quest_giver.questphase']
 assert audit['archive_sha256']==hashlib.sha256((ROOT/audit['archive_path']).read_bytes()).hexdigest()
 paths=[p for d in ['bin','r6','archive'] for p in (ROOT/d).rglob('*') if p.is_file()]+[ROOT/n for n in ['README.txt','LICENSE','THIRD_PARTY_NOTICES.txt']]
 assert {p.relative_to(ROOT).as_posix() for p in paths}==set(oldpaths)|{'README.txt','LICENSE','THIRD_PARTY_NOTICES.txt'}
 assert len(paths)==129 and len(list((ROOT/'archive/pc/mod').glob('*.archive')))==10
 comparisons={'current_controls':'tests/cet_ui/check_current_controls.py','quest_giver':'tests/quest_giver/check_quest_giver.py',
  'voss_media':'tests/quest_giver/check_voss_media.py','voss_subtitles':'tests/quest_giver/check_subtitles.py','scene_ids':'tests/quest_giver/check_scene_ids.py',
  'voss_timing':'tests/quest_giver/check_timing.py','voss_pose_idle':'tests/quest_giver/check_pose_idle.py','off_the_books':'tests/off_the_books/check_off_books.py',
  'voss_retention':'tests/off_the_books/check_retention.py','continuation':'tests/off_the_books/check_handoff.py'}
 with TemporaryDirectory(prefix='ncpd-voss-continuation-release-') as tmp:
  reports={test:Path(tmp)/(key+'.json') for key,test in comparisons.items()}
  for test in TESTS:
   args=[sys.executable,str(ROOT/test)]
   if test in reports:args+=['--report',str(reports[test])]
   subprocess.run(args,cwd=ROOT,check=True)
  results={key:json.loads(reports[test].read_text()) for key,test in comparisons.items()}
 release=ROOT/'releases'/NAME
 with zipfile.ZipFile(release,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=9) as z:
  for p in sorted(paths):
   info=zipfile.ZipInfo(p.relative_to(ROOT).as_posix(),(2026,11,23,0,0,0));info.compress_type=zipfile.ZIP_DEFLATED;info.create_system=3;info.external_attr=0o100644<<16
   z.writestr(info,p.read_bytes(),compresslevel=9)
 with zipfile.ZipFile(release) as z:
  assert z.testzip() is None and len(z.namelist())==len(set(z.namelist()))==129
  assert set(z.namelist())=={p.relative_to(ROOT).as_posix() for p in paths}
  for p in paths:assert z.read(p.relative_to(ROOT).as_posix())==p.read_bytes()
 body=release.read_bytes()
 report={'version':'v0.20b-voss-continuation','base_commit':BASE,'source_commit':os.environ.get('GITHUB_SHA'),
  'install_files':len(paths),'lua_modules_parsed':len(modules),'redscript_files':len(scripts),'portable_tests':TESTS,
  'comparisons':results,'changed_payload':sorted(changed),'new_install_files':[],
  'quest_giver_native_api_version':5,'off_the_books_native_api_version':2,
  'reported_journal_completion_auto_clear_reproduced':True,'durable_final_briefing_receipt':True,
  'normal_native_return_checks_receipt_before_cancellation':True,'handoff_retries_without_deleting_voss':True,
  'accepted_continuation_not_eagerly_cancelled_for_pending_journal':True,'current_description_and_parents_activate_before_objective':True,
  'activation_confirmed_only_after_native_readback':True,'explicit_cancellation_not_automatically_restarted':True,
  'missing_dependency_and_rejected_path_diagnostics':True,
  'first_scene_voice_lipsync_captions_and_timing_byte_identical':True,'voss_archive_audit':audit,
  'other_nine_archives_byte_identical':True,'all_54_officer_down_sites_unchanged':True,
  'production_dispatch_and_all_reward_career_code_unchanged':True,
  'browser_extension_still_optional':True,'actual_game_validation':False,
  'observed_string_operator_compile_error_guard_retained':True,
  'game_checks_required':['Install full package and restart; old failed test has no completion receipt, activate Voss test once again',
   'Let final Voss reply finish: Voss/Hella remain and separate Off the Books objective activates without manual Continue',
   'No auto-clear when native journal acknowledgement is delayed; log briefing receipt and precise continuation status',
   'Standing contractor plus two guards, native readable loot, wanted escape and return to retained Voss',
   'Save/load during pending activation and target quest; one cycle, no duplicate actors or dialogue replay',
   'Explicit encounter-only/full clear remains cleared; manual Continue or a new briefing can rearm'],
  'zip_path':release.relative_to(ROOT).as_posix(),'zip_bytes':len(body),'zip_sha256':hashlib.sha256(body).hexdigest(),'zip_git_blob':blob(body),
  'files':{p.relative_to(ROOT).as_posix():{'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'git_blob':blob(p.read_bytes())} for p in paths}}
 (ROOT/'releases'/REPORT).write_text(json.dumps(report,indent=2)+'\n')
 print(json.dumps({k:report[k] for k in ['version','install_files','lua_modules_parsed','redscript_files','zip_path','zip_bytes','zip_sha256']},indent=2))
if __name__=='__main__':main()
