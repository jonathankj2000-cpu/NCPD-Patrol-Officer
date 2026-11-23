"""Build the complete off-duty Off the Books test, preserving existing payloads."""
from pathlib import Path
from tempfile import TemporaryDirectory
import hashlib,json,os,re,subprocess,sys,zipfile
from build_vip_refactor_release import TESTS as EXISTING_TESTS
ROOT=Path(__file__).resolve().parents[1]
BASE='6197a48def37b8bdcf2dcf785a0e81e9a7d9fee4'
PREFIX='bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrol/'
NAME='NCPD_Patrol_v0.20a1_Startup_Fix_TEST.zip'
REPORT='NCPD_Patrol_v0.20a1_Startup_Fix_verification.json'
TESTS=[*EXISTING_TESTS,'tests/quest_marker_probe/check_probe.py','tests/fixed_markers/check_fixed.py','tests/vip_routes/check_routes.py','tests/officer_down/check_officer_down.py','tests/scene_survey/check_survey.py','tests/scene_survey/check_settling.py','tests/scene_survey/check_staging.py','tests/scene_survey/check_functional.py','tests/officer_down/check_catalog.py','tests/officer_down/check_gameplay.py','tests/partner_safety/check_safety.py','tests/officer_down/check_repeat.py','tests/scene_survey/check_discovery.py','tests/scene_survey/check_discovery_landing.py','tests/officer_down/check_site_expansion.py','tests/cet_ui/check_current_controls.py','tests/quest_giver/check_quest_giver.py','tests/quest_giver/check_voss_media.py','tests/quest_giver/check_subtitles.py','tests/quest_giver/check_scene_ids.py','tests/quest_giver/check_timing.py','tests/quest_giver/check_pose_idle.py','tests/off_the_books/check_off_books.py','tests/off_the_books/check_retention.py']

def blob(b):return hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()
def previous(path):return subprocess.check_output(['git','show',f'{BASE}:{path}'],cwd=ROOT)
def main():
 from lupa.luajit21 import LuaRuntime
 modules=sorted((ROOT/PREFIX).glob('*.lua'));scripts=sorted((ROOT/'r6/scripts/NCPDPatrol').glob('*.reds'))
 assert len(modules)==47 and len(scripts)==48 and len(TESTS)==40
 lua=LuaRuntime()
 for p in modules:lua.eval('function(p) local f,e=loadfile(p);assert(f,e) end')(str(p))
 oldpaths=subprocess.check_output(['git','ls-tree','-r','--name-only',BASE,'--','bin','r6','archive'],cwd=ROOT,text=True).splitlines()
 changed={PREFIX+n for n in ['init.lua','cet_ui.lua','quest_giver_test.lua']}
 changed.add('r6/scripts/NCPDPatrol/NCPDPatrolQuestGiverTest.reds')
 added={PREFIX+'off_the_books.lua','r6/scripts/NCPDPatrol/NCPDPatrolOffBooksSystem.reds',
  'r6/scripts/NCPDPatrol/NCPDPatrolOffBooksEvents.reds','r6/tweaks/NCPDPatrol_OffTheBooks.yaml',
  'archive/pc/mod/NCPDPatrol_OffTheBooks.archive','archive/pc/mod/NCPDPatrol_OffTheBooks.archive.xl'}
 sys.path.insert(0,str(ROOT/'tests/quest_marker_probe'));from probe_source import without_offbooks
 sys.path.insert(0,str(ROOT/'tests/quest_giver'));from pose_source import without_retained_lua,without_retained_native
 for name in ['init.lua','cet_ui.lua']:
  assert without_offbooks((ROOT/PREFIX/name).read_text())==previous(PREFIX+name).decode(),name
 assert without_retained_lua((ROOT/PREFIX/'quest_giver_test.lua').read_text())==previous(PREFIX+'quest_giver_test.lua').decode()
 assert without_retained_native((ROOT/'r6/scripts/NCPDPatrol/NCPDPatrolQuestGiverTest.reds').read_text())==previous('r6/scripts/NCPDPatrol/NCPDPatrolQuestGiverTest.reds').decode()
 # The hotfix changes exactly one gameplay expression from v0.20a. Validate
 # that scope in addition to the older pre-encounter payload freeze above.
 hotfix_base='720ea85924a52fbc2eb98c54ad62349c7057eaf1'
 hotfix_paths=subprocess.check_output(['git','ls-tree','-r','--name-only',hotfix_base,'--','bin','r6','archive'],cwd=ROOT,text=True).splitlines()
 from probe_source import without_offbooks_compile_fix
 for path in hotfix_paths:
  before=subprocess.check_output(['git','show',hotfix_base+':'+path],cwd=ROOT)
  after=(ROOT/path).read_bytes()
  if path in {PREFIX+'init.lua',PREFIX+'cet_ui.lua'}:after=without_offbooks_compile_fix(after.decode()).encode()
  if path=='r6/scripts/NCPDPatrol/NCPDPatrolOffBooksSystem.reds':
   assert before.count(b'ReadAction.GetJournalEntryFromAction(read.GetID()) == this.ShardPath()')==1
   before=before.replace(b'ReadAction.GetJournalEntryFromAction(read.GetID()) == this.ShardPath()',b'Equals(ReadAction.GetJournalEntryFromAction(read.GetID()), this.ShardPath())')
  assert after==before,'Unrelated v0.20a hotfix payload changed: '+path
 for path in oldpaths:
  if path not in changed:assert (ROOT/path).read_bytes()==previous(path),'Unrelated payload changed: '+path
 frozen=['LICENSE','assets/scene_survey/sites.json','assets/fixed_markers/catalog.json','assets/vip/route-sites.json',
  'assets/officer_down_sites/catalog.json','assets/quest_giver_test/contract.json','assets/quest_giver_test/conversation.scene.json',
  'assets/quest_giver_test/onscreens.json.json','assets/quest_giver_test/media/manifest.json','assets/quest_giver_test/quest_giver.questphase.json',
  'assets/quest_giver_test/quest_giver.journal.json','assets/quest_giver_test/lines.json.json','assets/quest_giver_test/vomap.json.json',
  'assets/quest_giver_test/voss.lipmap.json','assets/quest_giver_test/subtitles.json.json','assets/quest_giver_test/voss_wait_pose.ent.json']
 for path in frozen:assert (ROOT/path).read_bytes()==previous(path),'Existing data changed: '+path
 assert (ROOT/'THIRD_PARTY_NOTICES.txt').read_text().startswith(previous('THIRD_PARTY_NOTICES.txt').decode())
 catalog=json.loads((ROOT/'assets/officer_down_sites/catalog.json').read_text());assert len(catalog['sites'])==54 and all(s['enabled'] for s in catalog['sites'])
 paths=[p for d in ['bin','r6','archive'] for p in (ROOT/d).rglob('*') if p.is_file()]+[ROOT/n for n in ['README.txt','LICENSE','THIRD_PARTY_NOTICES.txt']]
 assert {p.relative_to(ROOT).as_posix() for p in paths}==set(oldpaths)|added|{'README.txt','LICENSE','THIRD_PARTY_NOTICES.txt'}
 assert len(paths)==129 and len(list((ROOT/'archive/pc/mod').glob('*.archive')))==10
 comparisons={
  'current_controls':'tests/cet_ui/check_current_controls.py','quest_giver':'tests/quest_giver/check_quest_giver.py',
  'voss_media':'tests/quest_giver/check_voss_media.py','voss_subtitles':'tests/quest_giver/check_subtitles.py',
  'scene_ids':'tests/quest_giver/check_scene_ids.py','voss_timing':'tests/quest_giver/check_timing.py',
  'voss_pose_idle':'tests/quest_giver/check_pose_idle.py','off_the_books':'tests/off_the_books/check_off_books.py',
  'voss_retention':'tests/off_the_books/check_retention.py'}
 with TemporaryDirectory(prefix='ncpd-offbooks-release-') as tmp:
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
  assert not any(p.endswith('.jsonl') or p.endswith('_report.json') for p in z.namelist())
  for p in paths:assert z.read(p.relative_to(ROOT).as_posix())==p.read_bytes()
 body=release.read_bytes()
 report={'version':'v0.20a1-startup-fix','base_commit':BASE,'hotfix_base_commit':hotfix_base,'source_commit':os.environ.get('GITHUB_SHA'),
  'install_files':len(paths),'lua_modules_parsed':len(modules),'redscript_files':len(scripts),'portable_tests':TESTS,
  'comparisons':results,'new_payload':sorted(added),'changed_payload':sorted(changed),
  'officer_down_sites':54,'all_54_existing_catalogue_entries_unchanged':True,
  'all_nine_existing_archives_byte_identical':True,'existing_voss_scene_media_sms_caption_timing_unchanged':True,
  'quest_giver_native_api_version':4,'off_the_books_native_api_version':1,'off_duty_operation':True,
  'real_shard_loot_and_native_read_action':True,'native_readable_consumption_handled_by_acquisition_receipt':True,
  'conditional_wanted_escape':True,'retained_voss_same_meeting':True,'new_return_debrief_or_reward':False,
  'production_dispatch_facade_unchanged':True,'all_payment_career_and_runtime_evidence_ledgers_unchanged':True,
  'automatic_weights':{'scanner':45,'vip':27,'cyberpsycho':18,'officer_down':10},
  'browser_extension_still_optional':True,'actual_new_quest_gameplay_validation':False,
  'observed_v020a_string_operator_compile_error_guarded':True,'hotfix_gameplay_change':'Use Equals for the readable journal path String comparison',
  'all_ten_v020a_archives_byte_identical':True,
  'record_provenance':json.loads((ROOT/'assets/off_the_books/records.json').read_text()),
  'new_archive_validation':json.loads((ROOT/'assets/off_the_books/compiled.json').read_text()),
  'game_checks_required':['Complete original Voss briefing; off-duty operation and contractor pin activate',
   'Standing neutral male contractor and two elite guards at supplied restaurant transforms',
   'Both guards defend target on attack; native police and civilian consequences remain',
   'Non-lethal defeat does not fulfil eliminate; actual death switches to retrieve',
   'Loot real target item, read custom title/contents in Shards; no automatic item grant',
   'Wanted escape is conditional; return to retained Voss without replaying briefing',
   'Save/load and re-entry at each stage preserve actors/death/evidence/objective without duplicates',
   'Explicit encounter-only/full clear, delayed cleanup and repeat test',
   'Manual waypoints, dispatch, career and existing Voss timing remain intact'],
  'zip_path':release.relative_to(ROOT).as_posix(),'zip_bytes':len(body),'zip_sha256':hashlib.sha256(body).hexdigest(),'zip_git_blob':blob(body),
  'files':{p.relative_to(ROOT).as_posix():{'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'git_blob':blob(p.read_bytes())} for p in paths}}
 (ROOT/'releases'/REPORT).write_text(json.dumps(report,indent=2)+'\n')
 print(json.dumps({k:report[k] for k in ['version','install_files','lua_modules_parsed','redscript_files','zip_path','zip_bytes','zip_sha256']},indent=2))
if __name__=='__main__':main()
