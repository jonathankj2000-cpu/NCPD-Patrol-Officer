"""Verify close off-camera ambush/retention; preserve the confirmed v0.14a assets."""
from pathlib import Path
import hashlib,json,os,subprocess,sys,zipfile
ROOT=Path(__file__).resolve().parents[1]
BASE='6bef95a5bf9b23ccdcaf74b77eaae009bd7a4b9e'
NAME='NCPD_Patrol_v0.14b_Close_VIP_Ambush_TEST.zip'
def run(*args):subprocess.run([*map(str,args)],cwd=ROOT,check=True)
def blob(data):return hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()
def main():
 from lupa.luajit21 import LuaRuntime
 lua=LuaRuntime();modules=sorted((ROOT/'bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrol').glob('*.lua'))
 scripts=sorted((ROOT/'r6/scripts/NCPDPatrol').glob('*.reds'))
 assert len(modules)==15 and len(scripts)==24
 for p in modules:lua.eval('function(p) local f,e=loadfile(p);assert(f,e) end')(str(p))
 tests=['tests/arrests/check_arrest.py','tests/arrests/check_arrest_interactions.py','tests/trunk_menu/check_trunk.py',
  'tests/dispatch_journal/check_journal.py','tests/career/check_career.py','tests/cyberpsycho/check_cyberpsycho.py','tests/vip/check_vip.py']
 for test in tests:run(sys.executable,ROOT/test)
 changed={'bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrol/init.lua',
  'bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrol/vip.lua','bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrol/vip_ambush.lua',
  'r6/scripts/NCPDPatrol/NCPDPatrolVIPSystem.reds'}
 original=subprocess.check_output(['git','ls-tree','-r','--name-only',BASE,'--','bin','r6','archive'],cwd=ROOT,text=True).splitlines()
 keep=[path for path in original if path not in changed]
 run('git','diff','--exit-code',BASE,'--','LICENSE',*keep)
 paths=[]
 for dirname in ['bin','r6','archive']:paths.extend(p for p in (ROOT/dirname).rglob('*') if p.is_file())
 paths.extend(ROOT/name for name in ['LICENSE','README.txt'])
 assert {p.relative_to(ROOT).as_posix() for p in paths}==set(original)|{'LICENSE','README.txt'} and len(paths)==56
 release=ROOT/'releases'/NAME;release.parent.mkdir(exist_ok=True)
 with zipfile.ZipFile(release,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=9) as z:
  for path in sorted(paths):
   info=zipfile.ZipInfo(path.relative_to(ROOT).as_posix(),(2026,11,18,0,0,0));info.compress_type=zipfile.ZIP_DEFLATED
   info.create_system=3;info.external_attr=0o100644<<16;z.writestr(info,path.read_bytes(),compresslevel=9)
 with zipfile.ZipFile(release) as z:
  assert z.testzip() is None and set(z.namelist())=={p.relative_to(ROOT).as_posix() for p in paths}
  for path in paths:assert z.read(path.relative_to(ROOT).as_posix())==path.read_bytes()
 data=release.read_bytes()
 report={'version':'v0.14b','source_commit':os.environ.get('GITHUB_SHA'),'base_commit':BASE,
  'install_files':len(paths),'lua_modules_parsed':len(modules),'redscript_files':len(scripts),'portable_tests':tests,
  'zip_path':release.relative_to(ROOT).as_posix(),'zip_bytes':len(data),'zip_sha256':hashlib.sha256(data).hexdigest(),'zip_git_blob':blob(data),
  'native_vip_interface':2,'ambush_spawn_range_m':[35,65],
  'camera_gate':'active native camera transform/FOV/aspect; padded 12 m scene sphere entirely outside view; invalid data waits',
  'native_spawn_in_view':False,'warning':'after actual car/crew attachment and seating, with chase requested',
  'neutralized_scene_retention_s':90,'scene_departure_m':150,'scene_departure_grace_s':3,
  'scene_departure_checks':'car and every attached body; retained after successful delivery; explicit cancel/shift end still closes',
  'native_vehicle_combat_unchanged':True,'confirmed_v014a_tyre_repair_unchanged':True,'all_archives_and_tweaks_unchanged':True,
  'existing_cyberpsycho_career_partner_backup_arrest_code_unchanged':True,'actual_game_validation':False,
  'files':{p.relative_to(ROOT).as_posix():{'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'git_blob':blob(p.read_bytes())} for p in paths}}
 (ROOT/'releases/NCPD_Patrol_v0.14b_verification.json').write_text(json.dumps(report,indent=2)+'\n')
 print(json.dumps({k:v for k,v in report.items() if k!='files'},indent=2))
if __name__=='__main__':main()
