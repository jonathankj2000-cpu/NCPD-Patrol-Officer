"""Verify the career/browser prototype and package the full game installation.

No game archives are rebuilt: confirmed arrest and dispatch assets are preserved.
"""
from pathlib import Path
import hashlib,json,os,re,subprocess,sys,zipfile
ROOT=Path(__file__).resolve().parents[1]
BASE='a35ef0d44f0e2c6938f73dc1d1d070171cec7927'
NAME='NCPD_Patrol_v0.11a_Career_Rewards_Partners_TEST.zip'
def run(*args):subprocess.run([*map(str,args)],cwd=ROOT,check=True)
def baseline(path):return subprocess.check_output(['git','show',BASE+':'+path],cwd=ROOT,text=True)
def blob(data):return hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()
def main():
 from lupa.luajit21 import LuaRuntime
 lua=LuaRuntime()
 modules=sorted((ROOT/'bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrol').glob('*.lua'))
 assert len(modules)==12
 for p in modules:lua.eval('function(p) local f,e=loadfile(p);assert(f,e) end')(str(p))
 tests=['tests/arrests/check_arrest.py','tests/arrests/check_arrest_interactions.py','tests/trunk_menu/check_trunk.py','tests/dispatch_journal/check_journal.py','tests/career/check_career.py']
 for test in tests:run(sys.executable,ROOT/test)
 changed={'r6/scripts/NCPDPatrol/NCPDPatrolCareerSystem.reds',
  'r6/scripts/NCPDPatrol/NCPDPatrolCareerBrowser.reds',
  'r6/scripts/NCPDPatrol/NCPDPatrolSystem.reds',
  'r6/scripts/NCPDPatrol/NCPDPatrolSupportSystem.reds',
  'bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrol/init.lua',
  'bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrol/partner.lua'}
 original=subprocess.check_output(['git','ls-tree','-r','--name-only',BASE,'--','bin','r6','archive'],cwd=ROOT,text=True).splitlines()
 keep=[path for path in original if path not in changed]
 run('git','diff','--exit-code',BASE,'--',*keep)
 def owned_vehicle_body(source):
  start=source.index('    public func IsOwnedPoliceVehicle(')
  end=source.index('    public func BeginVehicleChatter(',start)
  return source[:start]+source[end:]
 core='r6/scripts/NCPDPatrol/NCPDPatrolSystem.reds'
 assert owned_vehicle_body(baseline(core))==owned_vehicle_body((ROOT/core).read_text()),'core changed outside owned vehicle recognition'
 def registration_body(source):
  start=source.index('    public func RegisterPartner(')
  end=source.index('    public func UnregisterPartner(',start)
  return source[:start]+source[end:]
 support='r6/scripts/NCPDPatrol/NCPDPatrolSupportSystem.reds'
 assert registration_body(baseline(support))==registration_body((ROOT/support).read_text()),'support changed outside partner model registration'
 garage=(ROOT/'r6/tweaks/NCPDPatrol_CareerVehicles.yaml').read_text()
 for record in ['v_standard2_villefort_cortes_police','v_standard25_thorton_merrimac_police','v_standard3_chevalier_emperor_police','v_standard3_militech_hellhound_police']:
  assert garage.count('!append-once Vehicle.'+record)==1
 assert 'EnableAllPlayerVehicles' not in (ROOT/'r6/scripts/NCPDPatrol/NCPDPatrolCareerSystem.reds').read_text()
 paths=[]
 for dirname in ['bin','r6','archive']:paths.extend(p for p in (ROOT/dirname).rglob('*') if p.is_file())
 paths.extend(ROOT/name for name in ['LICENSE','README.txt'])
 assert len(paths)==44
 release=ROOT/'releases'/NAME;release.parent.mkdir(exist_ok=True)
 with zipfile.ZipFile(release,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=9) as z:
  for path in sorted(paths):
   info=zipfile.ZipInfo(path.relative_to(ROOT).as_posix(),(2026,11,18,0,0,0));info.compress_type=zipfile.ZIP_DEFLATED
   info.create_system=3;info.external_attr=0o100644<<16;z.writestr(info,path.read_bytes(),compresslevel=9)
 with zipfile.ZipFile(release) as z:
  assert z.testzip() is None and set(z.namelist())=={p.relative_to(ROOT).as_posix() for p in paths}
  for p in paths:assert z.read(p.relative_to(ROOT).as_posix())==p.read_bytes()
 data=release.read_bytes()
 report={'version':'v0.11a','source_commit':os.environ.get('GITHUB_SHA'),'base_commit':BASE,
 'install_files':len(paths),'lua_modules_parsed':len(modules),'portable_tests':tests,
 'zip_path':release.relative_to(ROOT).as_posix(),'zip_bytes':len(data),'zip_sha256':hashlib.sha256(data).hexdigest(),
 'zip_git_blob':blob(data),'career_milestones':[5,10,20,35,50,75,100],'partner_milestones':[0,20,50,100],
 'reward_records':16,'equipment_items':12,'garage_vehicles':4,'test_unlocks':'session only; no synthetic activity records',
 'reward_receipts':'save-local, per record; legacy cash claims retained separately',
 'browser_extension':'optional, page requires 0.9.7','bef_reference_commit':'e2012d2d7778e5101526f9e7115708d2159e6c35','actual_game_validation':False,
 'arrest_dispatch_archives_unchanged':True,'scanner_dispatch_payment_code_unchanged':True,
 'files':{p.relative_to(ROOT).as_posix():{'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'git_blob':blob(p.read_bytes())} for p in paths}}
 (ROOT/'releases/NCPD_Patrol_v0.11a_verification.json').write_text(json.dumps(report,indent=2)+'\n')
 print(json.dumps({k:v for k,v in report.items() if k!='files'},indent=2))
if __name__=='__main__':main()
