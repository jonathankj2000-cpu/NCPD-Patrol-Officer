"""Verify the isolated encounter prototype and build a complete game install ZIP."""
from pathlib import Path
import argparse,hashlib,io,json,os,subprocess,sys,tempfile,urllib.request,zipfile
ROOT=Path(__file__).resolve().parents[1]
BASE='abdf2d64e3b4fbb72e65c59e14b0720d10f08856'
NAME='NCPD_Patrol_v0.13a_Cyberpsycho_Dispatch_TEST.zip'
def run(*args):subprocess.run([*map(str,args)],cwd=ROOT,check=True)
def blob(data):return hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()
def main():
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--wk-cli',type=Path);args=parser.parse_args()
 from lupa.luajit21 import LuaRuntime
 lua=LuaRuntime();modules=sorted((ROOT/'bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrol').glob('*.lua'))
 assert len(modules)==13
 for p in modules:lua.eval('function(p) local f,e=loadfile(p);assert(f,e) end')(str(p))
 tests=['tests/arrests/check_arrest.py','tests/arrests/check_arrest_interactions.py','tests/trunk_menu/check_trunk.py',
  'tests/dispatch_journal/check_journal.py','tests/career/check_career.py','tests/cyberpsycho/check_cyberpsycho.py']
 for test in tests:run(sys.executable,ROOT/test)
 changed={'bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrol/init.lua',
  'bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrol/dispatch.lua'}
 original=subprocess.check_output(['git','ls-tree','-r','--name-only',BASE,'--','bin','r6','archive'],cwd=ROOT,text=True).splitlines()
 keep=[path for path in original if path not in changed]
 run('git','diff','--exit-code',BASE,'--',*keep)
 if args.wk_cli:cli=args.wk_cli.resolve()
 else:
  from build_journal_release import WK_URL,WK_SHA
  dest=ROOT/'.ci-wolvenkit';dest.mkdir(exist_ok=True)
  with urllib.request.urlopen(WK_URL,timeout=120) as response:data=response.read()
  assert hashlib.sha256(data).hexdigest()==WK_SHA
  with zipfile.ZipFile(io.BytesIO(data)) as z:z.extractall(dest)
  cli=next(dest.rglob('WolvenKit.CLI'));cli.chmod(cli.stat().st_mode|0o111)
 with tempfile.TemporaryDirectory(prefix='ncpd-cyberpsycho-resources-') as d:
  resource_manifest=Path(d)/'resources.json'
  run(sys.executable,ROOT/'tools/build_cyberpsycho_assets.py','--wk-cli',cli,'--resource-manifest',resource_manifest)
  resource_hashes=json.loads(resource_manifest.read_text())
 paths=[]
 for dirname in ['bin','r6','archive']:paths.extend(p for p in (ROOT/dirname).rglob('*') if p.is_file())
 paths.extend(ROOT/name for name in ['LICENSE','README.txt'])
 new={'bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrol/cyberpsycho.lua',
  'r6/scripts/NCPDPatrol/NCPDPatrolCyberpsychoSystem.reds','r6/tweaks/NCPDPatrol_Cyberpsycho.yaml',
  'archive/pc/mod/NCPDPatrol_Cyberpsycho.archive','archive/pc/mod/NCPDPatrol_Cyberpsycho.archive.xl'}
 assert {p.relative_to(ROOT).as_posix() for p in paths}==set(original)|new|{'LICENSE','README.txt'}
 assert len(paths)==50
 release=ROOT/'releases'/NAME;release.parent.mkdir(exist_ok=True)
 with zipfile.ZipFile(release,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=9) as z:
  for path in sorted(paths):
   info=zipfile.ZipInfo(path.relative_to(ROOT).as_posix(),(2026,11,18,0,0,0));info.compress_type=zipfile.ZIP_DEFLATED
   info.create_system=3;info.external_attr=0o100644<<16;z.writestr(info,path.read_bytes(),compresslevel=9)
 with zipfile.ZipFile(release) as z:
  assert z.testzip() is None
  assert set(z.namelist())=={p.relative_to(ROOT).as_posix() for p in paths}
  for path in paths:assert z.read(path.relative_to(ROOT).as_posix())==path.read_bytes()
 data=release.read_bytes()
 report={'version':'v0.13a','source_commit':os.environ.get('GITHUB_SHA'),'base_commit':BASE,
  'install_files':len(paths),'lua_modules_parsed':len(modules),'redscript_files':23,'portable_tests':tests,
  'zip_path':release.relative_to(ROOT).as_posix(),'zip_bytes':len(data),'zip_sha256':hashlib.sha256(data).hexdigest(),'zip_git_blob':blob(data),
  'encounter':'manual CET cyberpsycho test; one private target at a reachable nearby point',
  'target_record':'Character.NCPDPatrol_Cyberpsycho','base_record':'Character.ma_wat_lch_06_cyberpsycho',
  'record_reference_commit':'0f39f780c92ca389f97fc19cb5ba3c10ba32dd7d',
  'completion':'attached exact target dead, defeated or unconscious for 0.75 gameplay seconds; missing target never succeeds',
  'quest':'quests/minor_quest/ncpd_patrol_cyberpsycho/main/neutralize',
  'cleanup':'one reservation until owned entity is no longer managed; distance/time after success or manual clear; no old-world deletion',
  'rewards_and_career':'unchanged; encounter prototype does not issue payment or career credit',
  'cyberpsycho_resources_roundtrip_and_exact_extraction':True,
  'cyberpsycho_resource_sha256':resource_hashes,
  'existing_scanner_career_partner_backup_arrest_code_unchanged':True,'existing_archives_unchanged':True,
  'actual_game_validation':False,
  'files':{p.relative_to(ROOT).as_posix():{'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'git_blob':blob(p.read_bytes())} for p in paths}}
 (ROOT/'releases/NCPD_Patrol_v0.13a_verification.json').write_text(json.dumps(report,indent=2)+'\n')
 print(json.dumps({k:v for k,v in report.items() if k!='files'},indent=2))
if __name__=='__main__':main()
