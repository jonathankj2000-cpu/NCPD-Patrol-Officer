"""Build the complete native evidence death-loot and old-corpse recovery test."""
from pathlib import Path
from tempfile import TemporaryDirectory
import hashlib,json,os,subprocess,sys,zipfile
from build_vip_refactor_release import TESTS as EXISTING_TESTS
ROOT=Path(__file__).resolve().parents[1]
BASE='9e41604a4935f55e081eab035bf122f986c8ba2e'
PREFIX='bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrol/'
NAME='NCPD_Patrol_v0.20d_Evidence_Loot_TEST.zip'
REPORT='NCPD_Patrol_v0.20d_Evidence_Loot_verification.json'
TESTS=[*EXISTING_TESTS,'tests/quest_marker_probe/check_probe.py','tests/fixed_markers/check_fixed.py','tests/vip_routes/check_routes.py','tests/officer_down/check_officer_down.py','tests/scene_survey/check_survey.py','tests/scene_survey/check_settling.py','tests/scene_survey/check_staging.py','tests/scene_survey/check_functional.py','tests/officer_down/check_catalog.py','tests/officer_down/check_gameplay.py','tests/partner_safety/check_safety.py','tests/officer_down/check_repeat.py','tests/scene_survey/check_discovery.py','tests/scene_survey/check_discovery_landing.py','tests/officer_down/check_site_expansion.py','tests/cet_ui/check_current_controls.py','tests/quest_giver/check_quest_giver.py','tests/quest_giver/check_voss_media.py','tests/quest_giver/check_subtitles.py','tests/quest_giver/check_scene_ids.py','tests/quest_giver/check_timing.py','tests/quest_giver/check_pose_idle.py','tests/off_the_books/check_off_books.py','tests/off_the_books/check_retention.py','tests/off_the_books/check_handoff.py','tests/off_the_books/check_encounter.py','tests/off_the_books/check_death_loot.py']


def blob(b):return hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()
def previous(path):return subprocess.check_output(['git','show',f'{BASE}:{path}'],cwd=ROOT)
def main():
 from lupa.luajit21 import LuaRuntime
 modules=sorted((ROOT/PREFIX).glob('*.lua'));scripts=sorted((ROOT/'r6/scripts/NCPDPatrol').glob('*.reds'))
 assert len(modules)==47 and len(scripts)==50 and len(TESTS)==43
 lua=LuaRuntime()
 for p in modules:lua.eval('function(p) local f,e=loadfile(p);assert(f,e) end')(str(p))
 oldpaths=subprocess.check_output(['git','ls-tree','-r','--name-only',BASE,'--','bin','r6','archive'],cwd=ROOT,text=True).splitlines()
 changed={PREFIX+n for n in ['init.lua','cet_ui.lua','off_the_books.lua']}
 changed.update({'r6/scripts/NCPDPatrol/NCPDPatrolOffBooksSystem.reds','r6/tweaks/NCPDPatrol_OffTheBooks.yaml'})
 new=set()
 sys.path.insert(0,str(ROOT/'tests/quest_marker_probe'));from probe_source import without_death_loot_branding
 for name in ['init.lua','cet_ui.lua']:assert without_death_loot_branding((ROOT/PREFIX/name).read_text())==previous(PREFIX+name).decode(),name
 lifecycle=(ROOT/PREFIX/'off_the_books.lua').read_text().replace("n:Version()~=4 then error('Install the complete v0.20d Off the Books package", "n:Version()~=3 then error('Install the complete v0.20c Off the Books package")
 lifecycle=lifecycle.replace('Required contractor/guard/shard records, native evidence loot table or Read action','Required contractor/guard/shard records or Read action')
 assert lifecycle==previous(PREFIX+'off_the_books.lua').decode(),'Encounter actor lifecycle changed'
 for path in oldpaths:
  if path not in changed:assert (ROOT/path).read_bytes()==previous(path),'Unrelated payload changed: '+path
 for path in ['LICENSE','THIRD_PARTY_NOTICES.txt','assets/scene_survey/sites.json','assets/fixed_markers/catalog.json','assets/vip/route-sites.json','assets/officer_down_sites/catalog.json']:
  assert (ROOT/path).read_bytes()==previous(path),'Existing data changed: '+path
 # All first-scene inputs, native bridge, item definitions and ten
 # archives remain exact. No new audio, lipsync, workspot or quest graph.
 authored=subprocess.check_output(['git','ls-tree','-r','--name-only',BASE,'--','assets/quest_giver_test','assets/off_the_books'],cwd=ROOT,text=True).splitlines()
 for path in authored:assert (ROOT/path).read_bytes()==previous(path),'Existing asset changed: '+path
 paths=[p for d in ['bin','r6','archive'] for p in (ROOT/d).rglob('*') if p.is_file()]+[ROOT/n for n in ['README.txt','LICENSE','THIRD_PARTY_NOTICES.txt']]
 assert {p.relative_to(ROOT).as_posix() for p in paths}==set(oldpaths)|new|{'README.txt','LICENSE','THIRD_PARTY_NOTICES.txt'}
 assert len(paths)==131 and len(list((ROOT/'archive/pc/mod').glob('*.archive')))==10
 comparisons={'current_controls':'tests/cet_ui/check_current_controls.py','quest_giver':'tests/quest_giver/check_quest_giver.py',
  'voss_media':'tests/quest_giver/check_voss_media.py','voss_subtitles':'tests/quest_giver/check_subtitles.py','scene_ids':'tests/quest_giver/check_scene_ids.py',
  'voss_timing':'tests/quest_giver/check_timing.py','voss_pose_idle':'tests/quest_giver/check_pose_idle.py','off_the_books':'tests/off_the_books/check_off_books.py',
  'voss_retention':'tests/off_the_books/check_retention.py','continuation':'tests/off_the_books/check_handoff.py','encounter':'tests/off_the_books/check_encounter.py','death_loot':'tests/off_the_books/check_death_loot.py'}
 with TemporaryDirectory(prefix='ncpd-evidence-loot-release-') as tmp:
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
 report={'version':'v0.20d-evidence-loot','base_commit':BASE,'source_commit':os.environ.get('GITHUB_SHA'),
  'install_files':len(paths),'lua_modules_parsed':len(modules),'redscript_files':len(scripts),'portable_tests':TESTS,
  'comparisons':results,'changed_payload':sorted(changed|new|{'README.txt'}),'new_install_files':sorted(new),
  'quest_giver_native_api_version':5,'off_the_books_native_api_version':4,
  'confirmed_combat_override_and_scope_methods_unchanged':True,
  'user_confirmed_native_tier_source':'InteriorAreaNotifier 5084',
  'inherited_empty_loot_table_identified':True,'private_native_death_loot_table_one_shard':True,
  'native_generation_readback_before_corpse_insertion':True,'one_guarded_process_request_per_binding':True,
  'old_empty_corpse_recovery_once_per_cycle_with_real_seed_receipt':True,
  'confirmed_corpse_removal_and_acquisition_never_replenished':True,
  'cross_instance_query_and_owned_duplicate_trimming':True,
  'exact_player_item_event_required_no_automatic_death_grant':True,
  'existing_quest_facts_actor_tags_and_spawn_lifecycle_preserved':True,
  'first_scene_voice_lipsync_captions_and_timing_byte_identical':True,
  'all_ten_archives_byte_identical':True,'all_54_officer_down_sites_unchanged':True,
  'production_dispatch_duty_and_reward_career_code_unchanged':True,
  'browser_extension_still_optional':True,'actual_game_validation':False,
  'rendered_native_loot_ui_verified':False,'native_generation_internals_emulated':False,
  'observed_string_operator_compile_error_guard_retained':True,
  'game_checks_required':['Install full 131-file package and restart; retain affected v0.20c save without clearing the encounter',
   'Approach same corpse and wait 2-3 seconds: configured=true, generated=true, current shard=1, acquired=0',
   'Old after-death=0 snapshot remains; recovery used=1 identifies a migrated empty corpse',
   'Open ordinary native loot and physically take the readable evidence; confirm real item receipt',
   'Escape actual NCPD wanted level if necessary, then return to retained Voss',
   'Save/reload before and after pickup and return for evidence; same corpse, one shard, no replenishment',
   'Fresh encounter: native table creates one shard without using the migration',
   'If native generation remains pending or input/UI is missing, log existing Off the Books diagnostics'],
  'zip_path':release.relative_to(ROOT).as_posix(),'zip_bytes':len(body),'zip_sha256':hashlib.sha256(body).hexdigest(),'zip_git_blob':blob(body),
  'files':{p.relative_to(ROOT).as_posix():{'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'git_blob':blob(p.read_bytes())} for p in paths}}
 (ROOT/'releases'/REPORT).write_text(json.dumps(report,indent=2)+'\n')
 print(json.dumps({k:report[k] for k in ['version','install_files','lua_modules_parsed','redscript_files','zip_path','zip_bytes','zip_sha256']},indent=2))
if __name__=='__main__':main()
