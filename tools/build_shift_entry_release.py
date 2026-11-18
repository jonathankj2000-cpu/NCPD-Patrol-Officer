"""Verify shared shift-entry compatibility and package the complete mod."""
from pathlib import Path
import hashlib,json,os,subprocess,sys,zipfile
ROOT=Path(__file__).resolve().parents[1]
BASE='da3b67ad2be3d48f7710c571352a0ab8621e51ea'
NAME='NCPD_Patrol_v0.15e_Shift_Start_Fix_TEST.zip'
def run(*args):subprocess.run([*map(str,args)],cwd=ROOT,check=True)
def blob(data):return hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()
def main():
 from lupa.luajit21 import LuaRuntime
 lua=LuaRuntime();modules=sorted((ROOT/'bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrol').glob('*.lua'))
 scripts=sorted((ROOT/'r6/scripts/NCPDPatrol').glob('*.reds'))
 assert len(modules)==17 and len(scripts)==26
 for p in modules:lua.eval('function(p) local f,e=loadfile(p);assert(f,e) end')(str(p))
 tests=['tests/shift_entry/check_shift.py','tests/compile_compatibility/check_legacy_api.py','tests/arrests/check_arrest.py','tests/arrests/check_arrest_interactions.py','tests/trunk_menu/check_trunk.py',
  'tests/dispatch_journal/check_journal.py','tests/career/check_career.py','tests/cyberpsycho/check_cyberpsycho.py',
  'tests/vip/check_vip.py','tests/officer_readiness/check_ready.py']
 for test in tests:run(sys.executable,ROOT/test)
 prefix='bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrol/'
 changed={prefix+name for name in ['init.lua','trunk.lua']}
 added=set()
 original=subprocess.check_output(['git','ls-tree','-r','--name-only',BASE,'--','bin','r6','archive'],cwd=ROOT,text=True).splitlines()
 run('git','diff','--exit-code',BASE,'--','LICENSE',*[path for path in original if path not in changed])
 paths=[]
 for dirname in ['bin','r6','archive']:paths.extend(p for p in (ROOT/dirname).rglob('*') if p.is_file())
 paths.extend(ROOT/name for name in ['LICENSE','README.txt'])
 assert {p.relative_to(ROOT).as_posix() for p in paths}==set(original)|added|{'LICENSE','README.txt'} and len(paths)==60
 release=ROOT/'releases'/NAME;release.parent.mkdir(exist_ok=True)
 with zipfile.ZipFile(release,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=9) as z:
  for path in sorted(paths):
   info=zipfile.ZipInfo(path.relative_to(ROOT).as_posix(),(2026,11,18,0,0,0));info.compress_type=zipfile.ZIP_DEFLATED
   info.create_system=3;info.external_attr=0o100644<<16;z.writestr(info,path.read_bytes(),compresslevel=9)
 with zipfile.ZipFile(release) as z:
  assert z.testzip() is None and set(z.namelist())=={p.relative_to(ROOT).as_posix() for p in paths}
  for path in paths:assert z.read(path.relative_to(ROOT).as_posix())==path.read_bytes()
 data=release.read_bytes()
 report={'version':'v0.15e','source_commit':os.environ.get('GITHUB_SHA'),'base_commit':BASE,
  'install_files':len(paths),'lua_modules_parsed':len(modules),'redscript_files':len(scripts),'portable_tests':tests,
  'zip_path':release.relative_to(ROOT).as_posix(),'zip_bytes':len(data),'zip_sha256':hashlib.sha256(data).hexdigest(),'zip_git_blob':blob(data),
  'native_trunk_interface':4,'native_officer_equipment_interface':1,'native_cyberpsycho_interface':3,'native_vip_interface':2,
  'trunk_menu':'native R hold opens Codeware blocking popup; two rows of four cards; independent 1-7 and 9 actions; numpad/mouse; scoped lifecycle',
  'active_backup':'explicit follow commands replace permanent scene hold; boarding priority; existing 10-4 retains scene and reservation',
  'readiness':'verify actual held slots; stalled command falls back to native equip/unequip with existing tagged-officer inventory; native combat priority',
  'codeware_api_source':'v1.21.4 / 6dfdbceff7882d8ad8632ab1ff8d42bcef20a8ad',
  'archives_unchanged':True,'cyberpsycho_pool_and_tweaks_unchanged':True,
  'vip_ambush_aftermath_and_tyre_repair_unchanged':True,'career_and_payment_code_unchanged':True,
  'fixed_runtime_error':'stale trunk API 3 gate at shift start; shared trunk API 4 check',
  'native_scripts_unchanged_from_user_confirmed_v015d':True,
  'compatibility_guard':'observed game compiler forms rejected in CI; negative controls included; not a game-cache compiler',
  'actual_game_validation':False,
  'files':{p.relative_to(ROOT).as_posix():{'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'git_blob':blob(p.read_bytes())} for p in paths}}
 (ROOT/'releases/NCPD_Patrol_v0.15e_verification.json').write_text(json.dumps(report,indent=2)+'\n')
 print(json.dumps({k:v for k,v in report.items() if k!='files'},indent=2))
if __name__=='__main__':main()
