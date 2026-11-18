"""Verify the career/browser prototype and package the full game installation.

No game archives are rebuilt: confirmed arrest and dispatch assets are preserved.
"""
from pathlib import Path
import hashlib,json,os,re,subprocess,sys,zipfile
ROOT=Path(__file__).resolve().parents[1]
BASE='f38cbf1dd903e0261e62085cae5922ffd368aead'
NAME='NCPD_Patrol_v0.11b_Milestone_Weapon_Tiers_TEST.zip'
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
  'bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrol/init.lua',
  'bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrol/partner.lua'}
 original=subprocess.check_output(['git','ls-tree','-r','--name-only',BASE,'--','bin','r6','archive'],cwd=ROOT,text=True).splitlines()
 keep=[path for path in original if path not in changed]
 run('git','diff','--exit-code',BASE,'--',*keep)
 garage=(ROOT/'r6/tweaks/NCPDPatrol_CareerVehicles.yaml').read_text()
 for record in ['v_standard2_villefort_cortes_police','v_standard25_thorton_merrimac_police','v_standard3_chevalier_emperor_police','v_standard3_militech_hellhound_police']:
  assert garage.count('!append-once Vehicle.'+record)==1
 assert 'EnableAllPlayerVehicles' not in (ROOT/'r6/scripts/NCPDPatrol/NCPDPatrolCareerSystem.reds').read_text()
 paths=[]
 for dirname in ['bin','r6','archive']:paths.extend(p for p in (ROOT/dirname).rglob('*') if p.is_file())
 paths.extend(ROOT/name for name in ['LICENSE','README.txt'])
 assert len(paths)==45
 release=ROOT/'releases'/NAME;release.parent.mkdir(exist_ok=True)
 with zipfile.ZipFile(release,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=9) as z:
  for path in sorted(paths):
   info=zipfile.ZipInfo(path.relative_to(ROOT).as_posix(),(2026,11,18,0,0,0));info.compress_type=zipfile.ZIP_DEFLATED
   info.create_system=3;info.external_attr=0o100644<<16;z.writestr(info,path.read_bytes(),compresslevel=9)
 with zipfile.ZipFile(release) as z:
  assert z.testzip() is None and set(z.namelist())=={p.relative_to(ROOT).as_posix() for p in paths}
  for p in paths:assert z.read(p.relative_to(ROOT).as_posix())==p.read_bytes()
 data=release.read_bytes()
 report={'version':'v0.11b','source_commit':os.environ.get('GITHUB_SHA'),'base_commit':BASE,
 'install_files':len(paths),'lua_modules_parsed':len(modules),'portable_tests':tests,
 'zip_path':release.relative_to(ROOT).as_posix(),'zip_bytes':len(data),'zip_sha256':hashlib.sha256(data).hexdigest(),
 'zip_git_blob':blob(data),'career_milestones':[5,10,20,35,50,75,100],'partner_milestones':[0,20,50,100],
 'reward_records':16,'equipment_items':12,'garage_vehicles':4,'test_unlocks':'session only; no synthetic activity records',
 'weapon_tier_rules':{'through_20':2,'through_50':3,'through_75':4,'over_75':5},
 'weapon_rewards':{'Lexington Military':2,'Masamune Military':3,'Defender Military':5},
 'weapon_delivery':'fixed-quality reward-only clones; original receipt keys preserved',
 'test_weapons':'separate copies, once per session; requires TEST unlocks; normal claims unchanged',
 'reward_receipts':'save-local, per record; legacy cash claims retained separately',
 'browser_extension':'optional, page requires 0.9.7','bef_reference_commit':'e2012d2d7778e5101526f9e7115708d2159e6c35','actual_game_validation':False,
 'arrest_dispatch_archives_unchanged':True,'scanner_dispatch_payment_code_unchanged':True,
 'files':{p.relative_to(ROOT).as_posix():{'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'git_blob':blob(p.read_bytes())} for p in paths}}
 (ROOT/'releases/NCPD_Patrol_v0.11b_verification.json').write_text(json.dumps(report,indent=2)+'\n')
 print(json.dumps({k:v for k,v in report.items() if k!='files'},indent=2))
if __name__=='__main__':main()
