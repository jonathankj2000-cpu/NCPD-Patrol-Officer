"""Build the complete scoped Off the Books restaurant encounter test."""
from pathlib import Path
from tempfile import TemporaryDirectory
import hashlib,json,os,subprocess,sys,zipfile
from build_vip_refactor_release import TESTS as EXISTING_TESTS
ROOT=Path(__file__).resolve().parents[1]
BASE='a9d4e67901b75ec3c0f655098822371afd26cff6'
PREFIX='bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrol/'
NAME='NCPD_Patrol_v0.20c_Off_the_Books_Encounter_TEST.zip'
REPORT='NCPD_Patrol_v0.20c_Off_the_Books_Encounter_verification.json'
TESTS=[*EXISTING_TESTS,'tests/quest_marker_probe/check_probe.py','tests/fixed_markers/check_fixed.py','tests/vip_routes/check_routes.py','tests/officer_down/check_officer_down.py','tests/scene_survey/check_survey.py','tests/scene_survey/check_settling.py','tests/scene_survey/check_staging.py','tests/scene_survey/check_functional.py','tests/officer_down/check_catalog.py','tests/officer_down/check_gameplay.py','tests/partner_safety/check_safety.py','tests/officer_down/check_repeat.py','tests/scene_survey/check_discovery.py','tests/scene_survey/check_discovery_landing.py','tests/officer_down/check_site_expansion.py','tests/cet_ui/check_current_controls.py','tests/quest_giver/check_quest_giver.py','tests/quest_giver/check_voss_media.py','tests/quest_giver/check_subtitles.py','tests/quest_giver/check_scene_ids.py','tests/quest_giver/check_timing.py','tests/quest_giver/check_pose_idle.py','tests/off_the_books/check_off_books.py','tests/off_the_books/check_retention.py','tests/off_the_books/check_handoff.py','tests/off_the_books/check_encounter.py']


def blob(b):return hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()
def previous(path):return subprocess.check_output(['git','show',f'{BASE}:{path}'],cwd=ROOT)
def main():
 from lupa.luajit21 import LuaRuntime
 modules=sorted((ROOT/PREFIX).glob('*.lua'));scripts=sorted((ROOT/'r6/scripts/NCPDPatrol').glob('*.reds'))
 assert len(modules)==47 and len(scripts)==50 and len(TESTS)==42
 lua=LuaRuntime()
 for p in modules:lua.eval('function(p) local f,e=loadfile(p);assert(f,e) end')(str(p))
 oldpaths=subprocess.check_output(['git','ls-tree','-r','--name-only',BASE,'--','bin','r6','archive'],cwd=ROOT,text=True).splitlines()
 changed={PREFIX+n for n in ['init.lua','cet_ui.lua','off_the_books.lua']}
 changed.add('r6/scripts/NCPDPatrol/NCPDPatrolOffBooksSystem.reds')
 new={'r6/scripts/NCPDPatrol/NCPDPatrolOffBooksCombat.reds','r6/scripts/NCPDPatrol/NCPDPatrolOffBooksLoot.reds'}
 sys.path.insert(0,str(ROOT/'tests/quest_marker_probe'));from probe_source import without_offbooks_encounter
 for name in ['init.lua','cet_ui.lua']:assert without_offbooks_encounter((ROOT/PREFIX/name).read_text())==previous(PREFIX+name).decode(),name
 lifecycle=(ROOT/PREFIX/'off_the_books.lua').read_text().replace("n:Version()~=3 then error('Install the complete v0.20c Off the Books package", "n:Version()~=2 then error('Install the complete v0.20b Off the Books package")
 assert lifecycle==previous(PREFIX+'off_the_books.lua').decode(),'Encounter actor lifecycle changed'
 for path in oldpaths:
  if path not in changed:assert (ROOT/path).read_bytes()==previous(path),'Unrelated payload changed: '+path
 for path in ['LICENSE','THIRD_PARTY_NOTICES.txt','assets/scene_survey/sites.json','assets/fixed_markers/catalog.json','assets/vip/route-sites.json','assets/officer_down_sites/catalog.json']:
  assert (ROOT/path).read_bytes()==previous(path),'Existing data changed: '+path
 # All first-scene inputs, native bridge, actor/item definitions and ten
 # archives remain exact. No new audio, lipsync, workspot or quest graph.
 authored=subprocess.check_output(['git','ls-tree','-r','--name-only',BASE,'--','assets/quest_giver_test','assets/off_the_books'],cwd=ROOT,text=True).splitlines()
 for path in authored:assert (ROOT/path).read_bytes()==previous(path),'Existing asset changed: '+path
 paths=[p for d in ['bin','r6','archive'] for p in (ROOT/d).rglob('*') if p.is_file()]+[ROOT/n for n in ['README.txt','LICENSE','THIRD_PARTY_NOTICES.txt']]
 assert {p.relative_to(ROOT).as_posix() for p in paths}==set(oldpaths)|new|{'README.txt','LICENSE','THIRD_PARTY_NOTICES.txt'}
 assert len(paths)==131 and len(list((ROOT/'archive/pc/mod').glob('*.archive')))==10
 comparisons={'current_controls':'tests/cet_ui/check_current_controls.py','quest_giver':'tests/quest_giver/check_quest_giver.py',
  'voss_media':'tests/quest_giver/check_voss_media.py','voss_subtitles':'tests/quest_giver/check_subtitles.py','scene_ids':'tests/quest_giver/check_scene_ids.py',
  'voss_timing':'tests/quest_giver/check_timing.py','voss_pose_idle':'tests/quest_giver/check_pose_idle.py','off_the_books':'tests/off_the_books/check_off_books.py',
  'voss_retention':'tests/off_the_books/check_retention.py','continuation':'tests/off_the_books/check_handoff.py','encounter':'tests/off_the_books/check_encounter.py'}
 with TemporaryDirectory(prefix='ncpd-offbooks-encounter-release-') as tmp:
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
 report={'version':'v0.20c-off-the-books-encounter','base_commit':BASE,'source_commit':os.environ.get('GITHUB_SHA'),
  'install_files':len(paths),'lua_modules_parsed':len(modules),'redscript_files':len(scripts),'portable_tests':TESTS,
  'comparisons':results,'changed_payload':sorted(changed|new|{'README.txt'}),'new_install_files':sorted(new),
  'quest_giver_native_api_version':5,'off_the_books_native_api_version':3,
  'encounter_radius_metres':20,'encounter_floor_limit_metres':3,
  'native_scene_tier_request_preserved':True,'native_exploration_owns_state_reset':True,
  'no_psm_blackboard_writes_or_global_safe_area_override':True,
  'native_zone_sender_identified':False,'native_tier_source_diagnostic_added':True,
  'owned_corpse_native_accessibility_and_quality_refresh':True,'loot_refresh_max_attempts':8,
  'inventory_readback_distinct_from_observed_native_loot_input':True,
  'exact_player_item_event_required_no_automatic_death_grant':True,
  'existing_quest_facts_actor_tags_and_spawn_lifecycle_preserved':True,
  'first_scene_voice_lipsync_captions_and_timing_byte_identical':True,
  'all_ten_archives_byte_identical':True,'all_54_officer_down_sites_unchanged':True,
  'production_dispatch_duty_and_reward_career_code_unchanged':True,
  'browser_extension_still_optional':True,'actual_game_validation':False,
  'rendered_native_loot_ui_verified':False,'observed_string_operator_compile_error_guard_retained':True,
  'game_checks_required':['Install full 131-file package and restart; retain working v0.20b quest/save',
   'Finish Voss briefing or resume target stage; draw/equip/fire inside the restaurant',
   'Leave the bounded area, enter real dialogue or cancel: native restrictions resume',
   'Log before/after death quantities; kill alone keeps Retrieve with acquired=0',
   'Approach corpse, open ordinary loot, take real readable shard; confirm exact item receipt',
   'Escape actual NCPD wanted level if necessary, then return to retained Voss',
   'Save/reload before and after pickup and return for evidence; same corpse, one shard',
   'If Loot prerequisites are ready but no native input appears, inspect template/descriptor before any fallback'],
  'zip_path':release.relative_to(ROOT).as_posix(),'zip_bytes':len(body),'zip_sha256':hashlib.sha256(body).hexdigest(),'zip_git_blob':blob(body),
  'files':{p.relative_to(ROOT).as_posix():{'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'git_blob':blob(p.read_bytes())} for p in paths}}
 (ROOT/'releases'/REPORT).write_text(json.dumps(report,indent=2)+'\n')
 print(json.dumps({k:report[k] for k in ['version','install_files','lua_modules_parsed','redscript_files','zip_path','zip_bytes','zip_sha256']},indent=2))
if __name__=='__main__':main()
