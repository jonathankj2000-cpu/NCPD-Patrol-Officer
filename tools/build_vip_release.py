"""Verify VIP transport/tyre changes and build the complete game installation."""
from pathlib import Path
import argparse,hashlib,io,json,os,subprocess,sys,tempfile,urllib.request,zipfile
ROOT=Path(__file__).resolve().parents[1]
BASE='b5bb290de6801baaf52b15349fef18432590dfc8'
NAME='NCPD_Patrol_v0.14a_VIP_Transport_Tyre_Repair_TEST.zip'
def run(*args):subprocess.run([*map(str,args)],cwd=ROOT,check=True)
def blob(data):return hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()
def main():
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--wk-cli',type=Path);args=parser.parse_args()
 from lupa.luajit21 import LuaRuntime
 lua=LuaRuntime();modules=sorted((ROOT/'bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrol').glob('*.lua'))
 scripts=sorted((ROOT/'r6/scripts/NCPDPatrol').glob('*.reds'))
 assert len(modules)==15 and len(scripts)==24
 for p in modules:lua.eval('function(p) local f,e=loadfile(p);assert(f,e) end')(str(p))
 tests=['tests/arrests/check_arrest.py','tests/arrests/check_arrest_interactions.py','tests/trunk_menu/check_trunk.py',
  'tests/dispatch_journal/check_journal.py','tests/career/check_career.py','tests/cyberpsycho/check_cyberpsycho.py','tests/vip/check_vip.py']
 for test in tests:run(sys.executable,ROOT/test)
 changed={'bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrol/init.lua',
  'bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrol/dispatch.lua','r6/scripts/NCPDPatrol/NCPDPatrolTrunkVehicle.reds'}
 original=subprocess.check_output(['git','ls-tree','-r','--name-only',BASE,'--','bin','r6','archive'],cwd=ROOT,text=True).splitlines()
 keep=[path for path in original if path not in changed]
 run('git','diff','--exit-code',BASE,'--','LICENSE',*keep)
 if args.wk_cli:cli=args.wk_cli.resolve()
 else:
  from build_journal_release import WK_URL,WK_SHA
  dest=ROOT/'.ci-wolvenkit';dest.mkdir(exist_ok=True)
  with urllib.request.urlopen(WK_URL,timeout=120) as response:data=response.read()
  assert hashlib.sha256(data).hexdigest()==WK_SHA
  with zipfile.ZipFile(io.BytesIO(data)) as z:z.extractall(dest)
  cli=next(dest.rglob('WolvenKit.CLI'));cli.chmod(cli.stat().st_mode|0o111)
 with tempfile.TemporaryDirectory(prefix='ncpd-vip-resources-') as d:
  resource_manifest=Path(d)/'resources.json'
  run(sys.executable,ROOT/'tools/build_vip_assets.py','--wk-cli',cli,'--resource-manifest',resource_manifest)
  resource_hashes=json.loads(resource_manifest.read_text())
 paths=[]
 for dirname in ['bin','r6','archive']:paths.extend(p for p in (ROOT/dirname).rglob('*') if p.is_file())
 paths.extend(ROOT/name for name in ['LICENSE','README.txt'])
 new={'bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrol/vip.lua','bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrol/vip_ambush.lua',
  'r6/scripts/NCPDPatrol/NCPDPatrolVIPSystem.reds','r6/tweaks/NCPDPatrol_VIP.yaml',
  'archive/pc/mod/NCPDPatrol_VIP.archive','archive/pc/mod/NCPDPatrol_VIP.archive.xl'}
 assert {p.relative_to(ROOT).as_posix() for p in paths}==set(original)|new|{'LICENSE','README.txt'}
 assert len(paths)==56
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
 report={'version':'v0.14a','source_commit':os.environ.get('GITHUB_SHA'),'base_commit':BASE,
  'install_files':len(paths),'lua_modules_parsed':len(modules),'redscript_files':len(scripts),'portable_tests':tests,
  'zip_path':release.relative_to(ROOT).as_posix(),'zip_bytes':len(data),'zip_sha256':hashlib.sha256(data).hexdigest(),'zip_git_blob':blob(data),
  'quest':'quests/minor_quest/ncpd_patrol_vip/main','quest_objectives':['pickup','deliver'],
  'pickup_range_m':[500,2000],'delivery_distance_from_pickup_m':[800,2500],'spawn_trigger_distance_m':140,
  'pickup_deadline_s':300,'delivery_deadline_s':900,'native_vip_interface':1,
  'boarding':'actual witness and player driver mounted in same owned police vehicle; rear-right/rear-left/front-right free seats only',
  'completion':'actual live witness unmounted near destination after stopped drop-off began; no kill-all requirement',
  'ambush':'one car/two gang members per trip; recorded road history 120-220 m behind; native chase; 3 s stopped -> brake -> actual exit -> combat; 350 m/10 s escape',
  'tyre_repair':'after body reset, bounded delayed retries and mount/unmount activation; fresh puncture invalidates repair receipt/generation',
  'record_reference_commit':'0f39f780c92ca389f97fc19cb5ba3c10ba32dd7d',
  'records':{'VIP':'Character.ma_wat_lch_03_garbage_man','attacker':'Character.maelstrom_grunt1_ranged1_lexington_ma','car':'Vehicle.v_standard2_archer_hella'},
  'vip_resources_roundtrip_and_exact_extraction':True,'vip_resource_sha256':resource_hashes,
  'existing_cyberpsycho_scanner_arrest_archives_unchanged':True,
  'existing_cyberpsycho_career_partner_backup_arrest_code_unchanged':True,
  'rewards_and_career':'unchanged; generated incident prototype does not issue payment or career credit',
  'actual_game_validation':False,
  'files':{p.relative_to(ROOT).as_posix():{'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'git_blob':blob(p.read_bytes())} for p in paths}}
 (ROOT/'releases/NCPD_Patrol_v0.14a_verification.json').write_text(json.dumps(report,indent=2)+'\n')
 print(json.dumps({k:v for k,v in report.items() if k!='files'},indent=2))
if __name__=='__main__':main()
