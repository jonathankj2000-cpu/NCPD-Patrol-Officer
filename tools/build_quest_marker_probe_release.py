"""Verify and package the complete Officer Down branch prototype.

The workflow entrypoint is retained. Native marker-bank assets and existing
actor controllers must remain byte-identical to v0.17f outside this whitelist.
"""
from pathlib import Path
from tempfile import TemporaryDirectory
import hashlib,json,os,subprocess,sys,zipfile
from build_vip_refactor_release import TESTS as EXISTING_TESTS
ROOT=Path(__file__).resolve().parents[1]
BASE='06054d06f933f2111edd694f0c63c60899b7dfc9'
PREFIX='bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrol/'
NAME='NCPD_Patrol_v0.18a_Officer_Down_TEST.zip'
REPORT='NCPD_Patrol_v0.18a_Officer_Down_verification.json'
TESTS=[*EXISTING_TESTS,'tests/quest_marker_probe/check_probe.py','tests/fixed_markers/check_fixed.py','tests/vip_routes/check_routes.py','tests/officer_down/check_officer_down.py']
def blob(b):return hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()
def main():
 from lupa.luajit21 import LuaRuntime
 modules=sorted((ROOT/PREFIX).glob('*.lua'));scripts=sorted((ROOT/'r6/scripts/NCPDPatrol').glob('*.reds'))
 assert len(modules)==33 and len(scripts)==40
 lua=LuaRuntime()
 for p in modules:lua.eval('function(p) local f,e=loadfile(p);assert(f,e) end')(str(p))
 previous=subprocess.check_output(['git','ls-tree','-r','--name-only',BASE,'--','bin','r6','archive'],cwd=ROOT,text=True).splitlines()
 changed={PREFIX+n for n in ['init.lua','cet_ui.lua','dispatch.lua','dispatch_results.lua']}
 changed.add('r6/scripts/NCPDPatrol/NCPDPatrolIncidentSystem.reds')
 added={PREFIX+n for n in ['officer_down.lua','officer_down_layout.lua','officer_down_scene.lua']}
 added.update('r6/scripts/NCPDPatrol/NCPDPatrol'+n+'.reds' for n in ['OfficerDownSystem','OfficerDownSite','OfficerDownInteractions','SceneMarker'])
 added.update(['r6/tweaks/NCPDPatrol_OfficerDown.yaml','archive/pc/mod/NCPDPatrol_OfficerDown.archive','archive/pc/mod/NCPDPatrol_OfficerDown.archive.xl'])
 for name in previous:
  if name not in changed:assert (ROOT/name).read_bytes()==subprocess.check_output(['git','show',f'{BASE}:{name}'],cwd=ROOT),'Unrelated payload changed: '+name
 paths=[p for d in ['bin','r6','archive'] for p in (ROOT/d).rglob('*') if p.is_file()]+[ROOT/n for n in ['README.txt','LICENSE','THIRD_PARTY_NOTICES.txt']]
 assert {p.relative_to(ROOT).as_posix() for p in paths}==set(previous)|added|{'README.txt','LICENSE','THIRD_PARTY_NOTICES.txt'}
 assert len(paths)==99
 comparisons={
 'dispatch':'tests/dispatch_refactor/check_refactor.py','ui':'tests/cet_ui/check_cet_ui.py',
 'vip':'tests/vip_refactor/check_vip_refactor.py','probe':'tests/quest_marker_probe/check_probe.py',
 'fixed_markers':'tests/fixed_markers/check_fixed.py','vip_routes':'tests/vip_routes/check_routes.py',
 'officer_down':'tests/officer_down/check_officer_down.py'}
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
   info=zipfile.ZipInfo(p.relative_to(ROOT).as_posix(),(2026,11,20,0,0,0));info.compress_type=zipfile.ZIP_DEFLATED;info.create_system=3;info.external_attr=0o100644<<16
   z.writestr(info,p.read_bytes(),compresslevel=9)
 with zipfile.ZipFile(release) as z:
  assert z.testzip() is None and len(z.namelist())==len(set(z.namelist()))==99
  assert set(z.namelist())=={p.relative_to(ROOT).as_posix() for p in paths}
  for p in paths:assert z.read(p.relative_to(ROOT).as_posix())==p.read_bytes()
 body=release.read_bytes()
 report={'version':'v0.18a-officer-down','base_commit':BASE,'source_commit':os.environ.get('GITHUB_SHA'),
  'install_files':len(paths),'lua_modules_parsed':len(modules),'redscript_files':len(scripts),'portable_tests':TESTS,
  'comparisons':results,'new_payload':sorted(added),'changed_payload':sorted(changed),
  'scene':json.loads((ROOT/'assets/officer_down/scene.json').read_text()),
  'compiled_scene_resources':json.loads((ROOT/'assets/officer_down/compiled.json').read_text()),
  'existing_six_archives_unchanged_from_v017f':True,'native_fixed_marker_controller_catalog_and_diagnostics_unchanged':True,
  'vip_actor_ambush_and_baked_routes_unchanged':True,'arrest_partner_and_backup_unchanged':True,
  'existing_economy_unchanged':True,'new_officer_down_reward':2000,'generated_career_credit':1,
  'automatic_weights':{'scanner':50,'vip':30,'cyberpsycho':20},'officer_down_manual_only':True,
  'world_reset_forgets_old_ids':True,'main_partner_registration_reused':False,
  'native_marker_never_unregistered':True,'manual_waypoint_never_written':True,
  'partial_cleanup_reserves_scene':True,'successful_aftermath_reserves_dispatch':False,
  'browser_extension_still_optional':True,'actual_game_validation':False,
  'game_checks_required':['scene street alignment and orientation','car root placement/traffic collisions','officer down/recovery animation and F interaction','combat AI/cover','native quest marker rendering and reuse'],
  'zip_path':release.relative_to(ROOT).as_posix(),'zip_bytes':len(body),'zip_sha256':hashlib.sha256(body).hexdigest(),'zip_git_blob':blob(body),
  'files':{p.relative_to(ROOT).as_posix():{'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'git_blob':blob(p.read_bytes())} for p in paths}}
 (ROOT/'releases'/REPORT).write_text(json.dumps(report,indent=2)+'\n')
 print(json.dumps({k:v for k,v in report.items() if k not in ['files','comparisons']},indent=2))
if __name__=='__main__':main()
