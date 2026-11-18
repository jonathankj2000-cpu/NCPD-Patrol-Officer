"""Verify officer readiness and the 17-variant catalog; package the full mod."""
from pathlib import Path
import hashlib,json,os,subprocess,sys,zipfile
ROOT=Path(__file__).resolve().parents[1]
BASE='814358f3cbadb7ddec7caaca6ee836e949811e92'
NAME='NCPD_Patrol_v0.15a_Officer_Readiness_Cyberpsycho_Variants_TEST.zip'
def run(*args):subprocess.run([*map(str,args)],cwd=ROOT,check=True)
def blob(data):return hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()
def main():
 from lupa.luajit21 import LuaRuntime
 lua=LuaRuntime();modules=sorted((ROOT/'bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrol').glob('*.lua'))
 scripts=sorted((ROOT/'r6/scripts/NCPDPatrol').glob('*.reds'))
 assert len(modules)==17 and len(scripts)==24
 for p in modules:lua.eval('function(p) local f,e=loadfile(p);assert(f,e) end')(str(p))
 tests=['tests/arrests/check_arrest.py','tests/arrests/check_arrest_interactions.py','tests/trunk_menu/check_trunk.py',
  'tests/dispatch_journal/check_journal.py','tests/career/check_career.py','tests/cyberpsycho/check_cyberpsycho.py',
  'tests/vip/check_vip.py','tests/officer_readiness/check_ready.py']
 for test in tests:run(sys.executable,ROOT/test)
 prefix='bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrol/'
 changed={prefix+name for name in ['init.lua','partner.lua','backup.lua','dispatch.lua','cyberpsycho.lua']}
 changed|={'r6/scripts/NCPDPatrol/NCPDPatrolCyberpsychoSystem.reds','r6/tweaks/NCPDPatrol_Cyberpsycho.yaml'}
 original=subprocess.check_output(['git','ls-tree','-r','--name-only',BASE,'--','bin','r6','archive'],cwd=ROOT,text=True).splitlines()
 run('git','diff','--exit-code',BASE,'--','LICENSE',*[path for path in original if path not in changed])
 paths=[]
 for dirname in ['bin','r6','archive']:paths.extend(p for p in (ROOT/dirname).rglob('*') if p.is_file())
 paths.extend(ROOT/name for name in ['LICENSE','README.txt'])
 new={prefix+'officer_ready.lua',prefix+'cyberpsycho_variants.lua'}
 assert {p.relative_to(ROOT).as_posix() for p in paths}==set(original)|new|{'LICENSE','README.txt'} and len(paths)==58
 release=ROOT/'releases'/NAME;release.parent.mkdir(exist_ok=True)
 with zipfile.ZipFile(release,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=9) as z:
  for path in sorted(paths):
   info=zipfile.ZipInfo(path.relative_to(ROOT).as_posix(),(2026,11,18,0,0,0));info.compress_type=zipfile.ZIP_DEFLATED
   info.create_system=3;info.external_attr=0o100644<<16;z.writestr(info,path.read_bytes(),compresslevel=9)
 with zipfile.ZipFile(release) as z:
  assert z.testzip() is None and set(z.namelist())=={p.relative_to(ROOT).as_posix() for p in paths}
  for path in paths:assert z.read(path.relative_to(ROOT).as_posix())==path.read_bytes()
 data=release.read_bytes();catalog=json.loads((ROOT/'assets/cyberpsycho/variants.json').read_text())
 report={'version':'v0.15a','source_commit':os.environ.get('GITHUB_SHA'),'base_commit':BASE,
  'install_files':len(paths),'lua_modules_parsed':len(modules),'redscript_files':len(scripts),'portable_tests':tests,
  'zip_path':release.relative_to(ROOT).as_posix(),'zip_bytes':len(data),'zip_sha256':hashlib.sha256(data).hexdigest(),'zip_git_blob':blob(data),
  'native_cyberpsycho_interface':3,'native_vip_interface':2,'cyberpsycho_variants':17,
  'variant_records':[{'record':r['record'],'base':r['base']} for r in catalog['variants']],
  'record_reference_commit':catalog['reference_commit'],'variant_selection':'random without adjacent repeats where multiple available; manual next/random CET controls; exact selected record fixed at assignment',
  'readiness':'own on-foot partner/backup primary draw/holster; native alert/combat priority; vehicle/boarding/down/revive guards; own equipment commands only',
  'archives_unchanged':True,'confirmed_v014b_vip_ambush_and_aftermath_unchanged':True,'confirmed_tyre_repair_unchanged':True,
  'career_progression_and_payment_code_unchanged':True,'actual_game_validation':False,
  'files':{p.relative_to(ROOT).as_posix():{'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'git_blob':blob(p.read_bytes())} for p in paths}}
 (ROOT/'releases/NCPD_Patrol_v0.15a_verification.json').write_text(json.dumps(report,indent=2)+'\n')
 print(json.dumps({k:v for k,v in report.items() if k!='files'},indent=2))
if __name__=='__main__':main()
