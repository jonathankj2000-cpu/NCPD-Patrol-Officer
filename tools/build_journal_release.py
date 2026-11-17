"""CI build, portable regression checks and complete-install ZIP."""
from pathlib import Path
import argparse,hashlib,io,json,os,re,subprocess,sys,urllib.request,zipfile
ROOT=Path(__file__).resolve().parents[1]
BASE='3f1038db5b30a842bc2c29acd1286e0c61cf5595'
WK_URL='https://github.com/WolvenKit/WolvenKit/releases/download/9.1.1/WolvenKit.ConsoleLinux-9.1.1.zip'
WK_SHA='e6b7bcd109318e6762294bbf859bae31ab907c344815afe007b61a0abb80c2cc'
NAME='NCPD_Patrol_v0.9b_Dispatch_Briefings_Rewards_TEST.zip'
def run(*args):subprocess.run([*map(str,args)],cwd=ROOT,check=True)
def main():
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--wk-cli',type=Path);args=parser.parse_args()
 from lupa.luajit21 import LuaRuntime
 lua=LuaRuntime()
 modules=sorted((ROOT/'bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrol').glob('*.lua'))
 assert len(modules)==12
 for module in modules:
  lua.eval('function(p) local f,e=loadfile(p);assert(f,e);return true end')(str(module))
 tests=['tests/arrests/check_arrest.py','tests/arrests/check_arrest_interactions.py','tests/trunk_menu/check_trunk.py','tests/dispatch_journal/check_journal.py']
 for test in tests:run(sys.executable,ROOT/test)
 # Preserve established gameplay. The core's sole addition is a receipt wrapper
 # using its existing serialized message queue; scanner payment code is identical.
 keep=['archive/pc/mod/NCPDPatrol_Arrest.archive','r6/scripts/NCPDPatrol/NCPDPatrolArrestSystem.reds',
 'r6/scripts/NCPDPatrol/NCPDPatrolArrestPlayback.reds','r6/scripts/NCPDPatrol/NCPDPatrolArrestEvents.reds',
 'r6/scripts/NCPDPatrol/NCPDPatrolArrestInteractions.reds','r6/scripts/NCPDPatrol/NCPDPatrolSupportSystem.reds',
 'r6/scripts/NCPDPatrol/NCPDPatrolTrunkSystem.reds',
 'r6/scripts/NCPDPatrol/NCPDPatrolTrunkVehicle.reds','bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrol/arrest.lua',
 'bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrol/partner.lua','bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrol/backup.lua']
 run('git','diff','--exit-code',BASE,'--',*keep)
 core='r6/scripts/NCPDPatrol/NCPDPatrolSystem.reds'
 before=subprocess.check_output(['git','show',BASE+':'+core],cwd=ROOT,text=True)
 current=(ROOT/core).read_text()
 stripped,count=re.subn(r'\n    public func NotifyDispatchReward\(amount: Int32\) -> Void \{\n        if amount > 0 \{ this.ShowMessage\(s"DISPATCH BONUS PAID: \+€\$\\\(amount\)", true, 8\.0\); \};\n    \}\n','',current)
 assert count==1 and stripped==before,'Unexpected scanner/core changes'
 assert hashlib.sha256((ROOT/keep[0]).read_bytes()).hexdigest()=='906aba8def92a54553a1c1bff4afc490e71928ca2b7cf4233b8a566f75b432f3'
 if args.wk_cli:
  cli=args.wk_cli.resolve()
 else:
  dest=ROOT/'.ci-wolvenkit';dest.mkdir(exist_ok=True)
  with urllib.request.urlopen(WK_URL,timeout=120) as r:data=r.read()
  assert hashlib.sha256(data).hexdigest()==WK_SHA
  with zipfile.ZipFile(io.BytesIO(data)) as z:z.extractall(dest)
  cli=next(dest.rglob('WolvenKit.CLI'));cli.chmod(cli.stat().st_mode|0o111)
 run(sys.executable,ROOT/'tools/build_dispatch_assets.py','--wk-cli',cli)
 paths=[]
 for dirname in ['bin','r6','archive']:
  paths.extend(p for p in (ROOT/dirname).rglob('*') if p.is_file())
 paths.extend(ROOT/name for name in ['LICENSE','README.txt'])
 assert len(paths)==40,[(str(p),p.stat().st_size) for p in paths]
 release=ROOT/'releases'/NAME;release.parent.mkdir(exist_ok=True)
 with zipfile.ZipFile(release,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=9) as z:
  for path in sorted(paths):
   info=zipfile.ZipInfo(path.relative_to(ROOT).as_posix(),(2026,11,17,20,0,0));info.compress_type=zipfile.ZIP_DEFLATED
   info.create_system=3;info.external_attr=0o100644<<16;z.writestr(info,path.read_bytes(),compresslevel=9)
 with zipfile.ZipFile(release) as z:
  assert z.testzip() is None
  assert set(z.namelist())=={p.relative_to(ROOT).as_posix() for p in paths}
  for p in paths:assert z.read(p.relative_to(ROOT).as_posix())==p.read_bytes()
 def blob(data):return hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()
 report={'version':'v0.9b','source_commit':os.environ.get('GITHUB_SHA'),'base_commit':BASE,'install_files':len(paths),
 'zip_path':release.relative_to(ROOT).as_posix(),'zip_bytes':release.stat().st_size,
 'zip_sha256':hashlib.sha256(release.read_bytes()).hexdigest(),'zip_git_blob':blob(release.read_bytes()),
 'lua_modules_parsed':len(modules),'portable_tests':tests,'journal_resources_roundtrip_and_exact_extraction':True,
 'arrest_archive_unchanged':True,'scanner_payment_code_unchanged':True,'dispatch_briefings':6,'dispatch_supplement':500,'actual_game_validation':False,
 'files':{p.relative_to(ROOT).as_posix():{'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'git_blob':blob(p.read_bytes())} for p in paths}}
 (ROOT/'releases/NCPD_Patrol_v0.9b_verification.json').write_text(json.dumps(report,indent=2)+'\n')
 print(json.dumps({k:v for k,v in report.items() if k!='files'},indent=2))
if __name__=='__main__':main()
