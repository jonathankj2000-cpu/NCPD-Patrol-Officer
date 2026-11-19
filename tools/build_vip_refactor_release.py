"""Verify VIP responsibility extraction and package the complete r3 build."""
from pathlib import Path
from tempfile import TemporaryDirectory
import hashlib,json,os,subprocess,sys,zipfile
from build_cet_ui_refactor_release import TESTS as UI_TESTS

ROOT=Path(__file__).resolve().parents[1]
BASE='a9b654fed01145dd908ffe82de6e097bf2917c56'
PREFIX='bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrol/'
NAME='NCPD_Patrol_v0.17d_VIP_Refactor_r3_TEST.zip'
TESTS=[*UI_TESTS,'tests/vip_refactor/check_vip_refactor.py']

def blob(body):
    return hashlib.sha1(b'blob '+str(len(body)).encode()+b'\0'+body).hexdigest()

def main():
    from lupa.luajit21 import LuaRuntime
    lua=LuaRuntime()
    modules=sorted((ROOT/PREFIX).glob('*.lua'))
    scripts=sorted((ROOT/'r6/scripts/NCPDPatrol').glob('*.reds'))
    assert len(modules)==24 and len(scripts)==28
    for path in modules:
        lua.eval('function(p) local f,e=loadfile(p);assert(f,e) end')(str(path))
    previous=subprocess.check_output(['git','ls-tree','-r','--name-only',BASE,'--','bin','r6','archive'],cwd=ROOT,text=True).splitlines()
    changed={PREFIX+name for name in ['vip.lua','init.lua','cet_ui.lua']}
    added={PREFIX+name for name in ['vip_locations.lua','vip_waypoint.lua']}
    # The VIP suite separately proves extraction-only edits and branding-only
    # entrypoint/UI changes. All other installed gameplay bytes stay identical.
    for name in previous:
        if name not in changed:
            old=subprocess.check_output(['git','show',f'{BASE}:{name}'],cwd=ROOT)
            assert (ROOT/name).read_bytes()==old,'Unrelated gameplay changed: '+name
    assert (ROOT/'LICENSE').read_bytes()==subprocess.check_output(['git','show',f'{BASE}:LICENSE'],cwd=ROOT)
    paths=[]
    for directory in ['bin','r6','archive']:
        paths.extend(p for p in (ROOT/directory).rglob('*') if p.is_file())
    paths.extend(ROOT/name for name in ['README.txt','LICENSE'])
    assert {p.relative_to(ROOT).as_posix() for p in paths}==set(previous)|added|{'README.txt','LICENSE'}
    assert len(paths)==72
    with TemporaryDirectory(prefix='ncpd-vip-r3-verification-') as tmp:
        reports={test:Path(tmp)/(str(index)+'.json') for index,test in enumerate(TESTS) if test in [
            'tests/dispatch_refactor/check_refactor.py','tests/cet_ui/check_cet_ui.py','tests/vip_refactor/check_vip_refactor.py']}
        for test in TESTS:
            args=[sys.executable,str(ROOT/test)]
            if test in reports:args.extend(['--report',str(reports[test])])
            subprocess.run(args,cwd=ROOT,check=True)
        comparisons={test:json.loads(path.read_text()) for test,path in reports.items()}
    release=ROOT/'releases'/NAME
    with zipfile.ZipFile(release,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=9) as archive:
        for path in sorted(paths):
            info=zipfile.ZipInfo(path.relative_to(ROOT).as_posix(),(2026,11,19,0,0,0))
            info.compress_type=zipfile.ZIP_DEFLATED;info.create_system=3;info.external_attr=0o100644<<16
            archive.writestr(info,path.read_bytes(),compresslevel=9)
    with zipfile.ZipFile(release) as archive:
        assert archive.testzip() is None
        assert len(archive.namelist())==len(set(archive.namelist()))==72
        assert set(archive.namelist())=={p.relative_to(ROOT).as_posix() for p in paths}
        for path in paths:assert archive.read(path.relative_to(ROOT).as_posix())==path.read_bytes()
    body=release.read_bytes()
    report={
        'version':'v0.17d-vip-refactor-r3','base_commit':BASE,'source_commit':os.environ.get('GITHUB_SHA'),
        'install_files':len(paths),'lua_modules_parsed':len(modules),'redscript_files':len(scripts),
        'portable_tests':TESTS,'vip_comparison':comparisons['tests/vip_refactor/check_vip_refactor.py'],
        'dispatch_comparison':comparisons['tests/dispatch_refactor/check_refactor.py'],
        'ui_comparison':comparisons['tests/cet_ui/check_cet_ui.py'],
        'zip_path':release.relative_to(ROOT).as_posix(),'zip_bytes':len(body),
        'zip_sha256':hashlib.sha256(body).hexdigest(),'zip_git_blob':blob(body),
        'new_runtime_modules':sorted(added),'native_scripts_changed':[],'archives_changed':[],
        'ambush_modules_changed':[],'remaining_transport_actor_and_cleanup_flow_unchanged':True,
        'location_policy_and_rng_order_source_unchanged':True,'waypoint_recovery_source_unchanged':True,
        'entrypoint_and_ui_changes':'three build labels only',
        'native_interfaces_changed':[],'persistent_fields_changed':[],
        'browser_extension_still_optional':True,'localization_provider_unchanged':True,
        'actual_game_validation':False,
        'files':{p.relative_to(ROOT).as_posix():{'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),
                                             'git_blob':blob(p.read_bytes())} for p in paths},
    }
    (ROOT/'releases/NCPD_Patrol_VIP_Refactor_r3_verification.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({k:v for k,v in report.items() if k!='files'},indent=2))

if __name__=='__main__':main()
