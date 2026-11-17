"""Verify the career/browser prototype and package the full game installation.

No game archives are rebuilt: confirmed arrest and dispatch assets are preserved.
"""
from pathlib import Path
import hashlib,json,os,re,subprocess,sys,zipfile
ROOT=Path(__file__).resolve().parents[1]
BASE='0b5274200776740f0f260b06496d806fd5d494bf'
NAME='NCPD_Patrol_v0.10a_Career_Browser_TEST.zip'
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
 keep=['archive','r6/tweaks','r6/scripts/NCPDPatrol/NCPDPatrolArrestSystem.reds',
  'r6/scripts/NCPDPatrol/NCPDPatrolArrestPlayback.reds','r6/scripts/NCPDPatrol/NCPDPatrolArrestEvents.reds',
  'r6/scripts/NCPDPatrol/NCPDPatrolArrestInteractions.reds','r6/scripts/NCPDPatrol/NCPDPatrolSupportSystem.reds',
  'r6/scripts/NCPDPatrol/NCPDPatrolTrunkVehicle.reds','r6/scripts/NCPDPatrol/NCPDPatrolDispatchJournalSystem.reds',
  'bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrol/arrest.lua',
  'bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrol/partner.lua',
  'bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrol/backup.lua',
  'bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrol/dispatch.lua',
  'bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrol/dispatch_journal.lua']
 run('git','diff','--exit-code',BASE,'--',*keep)
 core='r6/scripts/NCPDPatrol/NCPDPatrolSystem.reds'
 current=(ROOT/core).read_text()
 stripped,n=re.subn(r'\n    public func NotifyCareerReward\(amount: Int32, milestone: Int32\) -> Void \{\n        if amount > 0 \{ this.ShowMessage\(s"NCPD CAREER REWARD: \+€\$\\\(amount\) \| \\\(milestone\) recorded activities", true, 8\.0\); \};\n    \}\n','',current)
 assert n==1 and stripped==baseline(core),'Unexpected scanner/core changes'
 trunk='r6/scripts/NCPDPatrol/NCPDPatrolTrunkSystem.reds'
 stats=r'    public func ShowStats\(\) -> Void \{.*?\n    \}\n'
 old,n1=re.subn(stats,'',baseline(trunk),flags=re.S)
 new,n2=re.subn(stats,'',(ROOT/trunk).read_text(),flags=re.S)
 assert n1==n2==1 and old==new,'Trunk behavior changed outside career stats'
 paths=[]
 for dirname in ['bin','r6','archive']:paths.extend(p for p in (ROOT/dirname).rglob('*') if p.is_file())
 paths.extend(ROOT/name for name in ['LICENSE','README.txt'])
 assert len(paths)==42
 release=ROOT/'releases'/NAME;release.parent.mkdir(exist_ok=True)
 with zipfile.ZipFile(release,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=9) as z:
  for path in sorted(paths):
   info=zipfile.ZipInfo(path.relative_to(ROOT).as_posix(),(2026,11,17,23,0,0));info.compress_type=zipfile.ZIP_DEFLATED
   info.create_system=3;info.external_attr=0o100644<<16;z.writestr(info,path.read_bytes(),compresslevel=9)
 with zipfile.ZipFile(release) as z:
  assert z.testzip() is None and set(z.namelist())=={p.relative_to(ROOT).as_posix() for p in paths}
  for p in paths:assert z.read(p.relative_to(ROOT).as_posix())==p.read_bytes()
 data=release.read_bytes()
 report={'version':'v0.10a','source_commit':os.environ.get('GITHUB_SHA'),'base_commit':BASE,
 'install_files':len(paths),'lua_modules_parsed':len(modules),'portable_tests':tests,
 'zip_path':release.relative_to(ROOT).as_posix(),'zip_bytes':len(data),'zip_sha256':hashlib.sha256(data).hexdigest(),
 'zip_git_blob':blob(data),'career_milestones':[10,20,40,60,80,100],'prototype_reward_per_milestone':1000,
 'browser_extension':'optional, page requires 0.9.7','actual_game_validation':False,
 'arrest_dispatch_archives_unchanged':True,'scanner_dispatch_payment_code_unchanged':True,
 'files':{p.relative_to(ROOT).as_posix():{'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'git_blob':blob(p.read_bytes())} for p in paths}}
 (ROOT/'releases/NCPD_Patrol_v0.10a_verification.json').write_text(json.dumps(report,indent=2)+'\n')
 print(json.dumps({k:v for k,v in report.items() if k!='files'},indent=2))
if __name__=='__main__':main()
