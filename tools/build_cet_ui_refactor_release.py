"""Verify isolated CET presentation and package the full refactor r2 install."""
from pathlib import Path
from tempfile import TemporaryDirectory
import hashlib, json, os, subprocess, sys, zipfile
from build_dispatch_refactor_release import TESTS as DISPATCH_TESTS

ROOT=Path(__file__).resolve().parents[1]
BASE='3c20841bba35d69289e5f70784b3202a5fbf8881'
PREFIX='bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrol/'
NAME='NCPD_Patrol_v0.17d_CET_Interface_Refactor_r2_TEST.zip'
TESTS=[*DISPATCH_TESTS,'tests/cet_ui/check_cet_ui.py']

def blob(data):
    return hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()

def original(path):
    return subprocess.check_output(['git','show',f'{BASE}:{path}'],cwd=ROOT)

def main():
    from lupa.luajit21 import LuaRuntime
    lua=LuaRuntime()
    modules=sorted((ROOT/PREFIX).glob('*.lua'))
    scripts=sorted((ROOT/'r6/scripts/NCPDPatrol').glob('*.reds'))
    assert len(modules)==22 and len(scripts)==28
    for path in modules:
        lua.eval('function(p) local f,e=loadfile(p);assert(f,e) end')(str(path))

    original_paths=subprocess.check_output(['git','ls-tree','-r','--name-only',BASE,'--','bin','r6','archive'],cwd=ROOT,text=True).splitlines()
    changed={PREFIX+'init.lua'}
    added={PREFIX+'cet_ui.lua'}
    # This includes all three extracted dispatch modules, every gameplay
    # controller/native script, localization, tweaks and all binary assets.
    for path in original_paths:
        if path not in changed:assert (ROOT/path).read_bytes()==original(path),f'Unrelated gameplay payload changed: {path}'
    assert (ROOT/'LICENSE').read_bytes()==original('LICENSE')
    paths=[]
    for dirname in ['bin','r6','archive']:
        paths.extend(p for p in (ROOT/dirname).rglob('*') if p.is_file())
    paths.extend(ROOT/name for name in ['LICENSE','README.txt'])
    assert {p.relative_to(ROOT).as_posix() for p in paths}==set(original_paths)|added|{'LICENSE','README.txt'}
    assert len(paths)==70

    with TemporaryDirectory(prefix='ncpd-cet-refactor-verification-') as tmp:
        reports={
            'tests/dispatch_refactor/check_refactor.py':Path(tmp)/'dispatch.json',
            'tests/cet_ui/check_cet_ui.py':Path(tmp)/'cet-ui.json',
        }
        for test in TESTS:
            args=[sys.executable,str(ROOT/test)]
            if test in reports:args.extend(['--report',str(reports[test])])
            subprocess.run(args,cwd=ROOT,check=True)
        dispatch=json.loads(reports['tests/dispatch_refactor/check_refactor.py'].read_text())
        ui=json.loads(reports['tests/cet_ui/check_cet_ui.py'].read_text())

    release=ROOT/'releases'/NAME
    with zipfile.ZipFile(release,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=9) as archive:
        for path in sorted(paths):
            info=zipfile.ZipInfo(path.relative_to(ROOT).as_posix(),(2026,11,19,0,0,0))
            info.compress_type=zipfile.ZIP_DEFLATED;info.create_system=3;info.external_attr=0o100644<<16
            archive.writestr(info,path.read_bytes(),compresslevel=9)
    with zipfile.ZipFile(release) as archive:
        assert archive.testzip() is None
        assert len(archive.namelist())==len(set(archive.namelist()))
        assert set(archive.namelist())=={p.relative_to(ROOT).as_posix() for p in paths}
        for path in paths:assert archive.read(path.relative_to(ROOT).as_posix())==path.read_bytes()
    data=release.read_bytes()
    report={
        'version':'v0.17d-cet-refactor-r2','base_commit':BASE,'source_commit':os.environ.get('GITHUB_SHA'),
        'install_files':len(paths),'lua_modules_parsed':len(modules),'redscript_files':len(scripts),
        'portable_tests':TESTS,'ui_comparison':ui,'dispatch_comparison':dispatch,
        'zip_path':release.relative_to(ROOT).as_posix(),'zip_bytes':len(data),
        'zip_sha256':hashlib.sha256(data).hexdigest(),'zip_git_blob':blob(data),
        'new_runtime_modules':sorted(added),'native_scripts_changed':[],'archives_changed':[],
        'gameplay_modules_changed':[],'entrypoint_session_source_unchanged_except_build_labels':True,
        'persistent_fields_changed':[],'native_interfaces_changed':[],
        'browser_extension_still_optional':True,'localization_provider_unchanged':True,
        'actual_game_validation':False,
        'files':{p.relative_to(ROOT).as_posix():{'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),
                                             'git_blob':blob(p.read_bytes())} for p in paths},
    }
    (ROOT/'releases/NCPD_Patrol_CET_Refactor_r2_verification.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({k:v for k,v in report.items() if k!='files'},indent=2))

if __name__=='__main__':main()
