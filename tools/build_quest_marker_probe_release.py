"""Build the isolated speech-event tail coverage test as a complete package."""
from pathlib import Path
from tempfile import TemporaryDirectory
import hashlib,json,os,subprocess,sys,zipfile
from build_vip_refactor_release import TESTS as EXISTING_TESTS
ROOT=Path(__file__).resolve().parents[1]
BASE='9957b3cb4f34355ea0046dc7503962e8c940b886'
PREFIX='bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrol/'
NAME='NCPD_Patrol_v0.20f1_Dialogue_Handoff_TEST.zip'
REPORT='NCPD_Patrol_v0.20f1_Dialogue_Handoff_verification.json'
TESTS=[*EXISTING_TESTS,'tests/quest_marker_probe/check_probe.py','tests/fixed_markers/check_fixed.py','tests/vip_routes/check_routes.py','tests/officer_down/check_officer_down.py','tests/scene_survey/check_survey.py','tests/scene_survey/check_settling.py','tests/scene_survey/check_staging.py','tests/scene_survey/check_functional.py','tests/officer_down/check_catalog.py','tests/officer_down/check_gameplay.py','tests/partner_safety/check_safety.py','tests/officer_down/check_repeat.py','tests/scene_survey/check_discovery.py','tests/scene_survey/check_discovery_landing.py','tests/officer_down/check_site_expansion.py','tests/cet_ui/check_current_controls.py','tests/quest_giver/check_quest_giver.py','tests/quest_giver/check_voss_media.py','tests/quest_giver/check_subtitles.py','tests/quest_giver/check_scene_ids.py','tests/quest_giver/check_timing.py','tests/quest_giver/check_pose_idle.py','tests/off_the_books/check_off_books.py','tests/off_the_books/check_retention.py','tests/off_the_books/check_handoff.py','tests/off_the_books/check_encounter.py','tests/off_the_books/check_death_loot.py','tests/off_the_books/check_evidence_receipt.py','tests/off_the_books/check_wanted.py','tests/quest_giver/check_audio_mix.py']


def blob(b):return hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()
def previous(path):return subprocess.check_output(['git','show',f'{BASE}:{path}'],cwd=ROOT)
def main():
 from lupa.luajit21 import LuaRuntime
 modules=sorted((ROOT/PREFIX).glob('*.lua'));scripts=sorted((ROOT/'r6/scripts/NCPDPatrol').glob('*.reds'))
 assert len(modules)==47 and len(scripts)==50 and len(TESTS)==46
 lua=LuaRuntime()
 for p in modules:lua.eval('function(p) local f,e=loadfile(p);assert(f,e) end')(str(p))
 oldpaths=subprocess.check_output(['git','ls-tree','-r','--name-only',BASE,'--','bin','r6','archive'],cwd=ROOT,text=True).splitlines()
 changed={PREFIX+n for n in ['init.lua','cet_ui.lua']}
 changed.add('archive/pc/mod/NCPDPatrol_QuestGiverTest.archive')
 new=set()
 sys.path.insert(0,str(ROOT/'tests/quest_marker_probe'));from probe_source import without_dialogue_handoff_branding
 for name in ['init.lua','cet_ui.lua']:assert without_dialogue_handoff_branding((ROOT/PREFIX/name).read_text())==previous(PREFIX+name).decode(),name
 for path in oldpaths:
  if path not in changed:assert (ROOT/path).read_bytes()==previous(path),'Unrelated payload changed: '+path
 for path in ['LICENSE','THIRD_PARTY_NOTICES.txt','assets/scene_survey/sites.json','assets/fixed_markers/catalog.json','assets/vip/route-sites.json','assets/officer_down_sites/catalog.json']:
  assert (ROOT/path).read_bytes()==previous(path),'Existing data changed: '+path
 # Only ten speech-event durations/cache hash and the compiled scene archive
 # change. Every absolute voice start, section length, context, source media,
 # overlap guard, native script and the nine other archives stay exact.
 sys.path.insert(0,str(ROOT/'tests/quest_giver'));from audio_source import AUDIO_ASSETS
 authored=subprocess.check_output(['git','ls-tree','-r','--name-only',BASE,'--','assets/quest_giver_test','assets/off_the_books'],cwd=ROOT,text=True).splitlines()
 for path in authored:
  if path not in AUDIO_ASSETS:assert (ROOT/path).read_bytes()==previous(path),'Existing asset changed: '+path
 paths=[p for d in ['bin','r6','archive'] for p in (ROOT/d).rglob('*') if p.is_file()]+[ROOT/n for n in ['README.txt','LICENSE','THIRD_PARTY_NOTICES.txt']]
 assert {p.relative_to(ROOT).as_posix() for p in paths}==set(oldpaths)|new|{'README.txt','LICENSE','THIRD_PARTY_NOTICES.txt'}
 assert len(paths)==131 and len(list((ROOT/'archive/pc/mod').glob('*.archive')))==10
 comparisons={'current_controls':'tests/cet_ui/check_current_controls.py','quest_giver':'tests/quest_giver/check_quest_giver.py',
  'voss_media':'tests/quest_giver/check_voss_media.py','voss_subtitles':'tests/quest_giver/check_subtitles.py','scene_ids':'tests/quest_giver/check_scene_ids.py',
  'voss_timing':'tests/quest_giver/check_timing.py','voss_pose_idle':'tests/quest_giver/check_pose_idle.py','off_the_books':'tests/off_the_books/check_off_books.py',
  'voss_retention':'tests/off_the_books/check_retention.py','continuation':'tests/off_the_books/check_handoff.py','encounter':'tests/off_the_books/check_encounter.py','death_loot':'tests/off_the_books/check_death_loot.py','receipt':'tests/off_the_books/check_evidence_receipt.py',
  'wanted':'tests/off_the_books/check_wanted.py','audio_mix':'tests/quest_giver/check_audio_mix.py'}
 with TemporaryDirectory(prefix='ncpd-dialogue-handoff-release-') as tmp:
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
  assert z.testzip() is None and len(z.namelist())==len(set(z.namelist()))==131
  assert set(z.namelist())=={p.relative_to(ROOT).as_posix() for p in paths}
  for p in paths:assert z.read(p.relative_to(ROOT).as_posix())==p.read_bytes()
 body=release.read_bytes()
 report={'version':'v0.20f1-dialogue-handoff','base_commit':BASE,'source_commit':os.environ.get('GITHUB_SHA'),
  'install_files':len(paths),'lua_modules_parsed':len(modules),'redscript_files':len(scripts),'portable_tests':TESTS,
  'comparisons':results,'changed_payload':sorted(changed|new|{'README.txt'}),'new_install_files':sorted(new),
  'quest_giver_native_api_version':5,'off_the_books_native_api_version':6,
  'native_three_star_quest_request_once_at_target_death':True,
  'higher_wanted_not_lowered_and_native_cooldown_untouched':True,
  'dead_legacy_saves_do_not_receive_a_retroactive_chase':True,
  'actual_evidence_acquisition_still_required_before_escape_or_return':True,
  'confirmed_readable_receipt_fix_preserved':True,
  'confirmed_death_loot_and_weapon_implementations_unchanged':True,
  'existing_quest_facts_and_real_wanted_escape_return_preserved':True,
  'only_ten_speech_event_durations_and_scene_cache_hash_changed':True,
  'speech_events_cover_the_former_500_ms_section_tails':True,
  'absolute_voice_starts_section_lengths_and_total_scene_time_identical':True,
  'original_media_lipsync_caption_text_and_caption_change_schedule_identical':True,
  'last_caption_can_remain_for_500_ms_longer':True,
  'vo_context_and_original_overlap_guard_unchanged':True,
  'all_50_redscripts_and_encounter_lua_byte_identical':True,
  'nine_other_archives_byte_identical':True,'all_54_officer_down_sites_unchanged':True,
  'production_dispatch_duty_and_reward_career_code_unchanged':True,
  'browser_extension_still_optional':True,'actual_game_validation':False,
  'actual_native_police_response_and_cooldown_verified':False,
  'speech_event_tail_change_experimental':True,'audible_ambience_fix_verified':False,
  'observed_string_operator_compile_error_guard_retained':True,
  'game_checks_required':['Install full 131-file package and fully restart the game',
   'Replay or use a save before Voss briefing and compare the same location/audio settings against v0.20f',
   'Listen for ambience dips before and after both Voss and V lines, including first and final lines',
   'Confirm every voice, lipsync, caption block, original pause and absence of overlapping speech',
   'The existing 300 ms Voss lead-ins remain; this experiment only fills the 500 ms eventless section tails',
   'Finish the briefing and confirm the retained Voss and existing encounter continue normally',
   'Wanted, evidence, save facts, dispatch and duty code are unchanged'],
  'zip_path':release.relative_to(ROOT).as_posix(),'zip_bytes':len(body),'zip_sha256':hashlib.sha256(body).hexdigest(),'zip_git_blob':blob(body),
  'files':{p.relative_to(ROOT).as_posix():{'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'git_blob':blob(p.read_bytes())} for p in paths}}
 (ROOT/'releases'/REPORT).write_text(json.dumps(report,indent=2)+'\n')
 print(json.dumps({k:report[k] for k in ['version','install_files','lua_modules_parsed','redscript_files','zip_path','zip_bytes','zip_sha256']},indent=2))
if __name__=='__main__':main()
