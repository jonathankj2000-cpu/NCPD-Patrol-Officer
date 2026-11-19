"""Verify behavior-preserving dispatch extraction; build the full branch test ZIP."""
from pathlib import Path
from tempfile import TemporaryDirectory
import hashlib, json, os, subprocess, sys, zipfile

ROOT=Path(__file__).resolve().parents[1]
BASE='ff0d0024d85d31df783e5f989a1d2cb3d9cefbc1'
PREFIX='bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrol/'
NAME='NCPD_Patrol_v0.17d_Dispatch_Refactor_r1_TEST.zip'
TESTS=[
    'tests/beanbagger/check_visuals.py','tests/beanbagger/check_beanbagger.py',
    'tests/shift_entry/check_shift.py','tests/compile_compatibility/check_legacy_api.py',
    'tests/arrests/check_arrest.py','tests/arrests/check_arrest_interactions.py',
    'tests/trunk_menu/check_trunk.py','tests/dispatch_journal/check_journal.py',
    'tests/career/check_career.py','tests/cyberpsycho/check_cyberpsycho.py',
    'tests/vip/check_vip.py','tests/officer_readiness/check_ready.py',
    'tests/incidents/check_incidents.py','tests/dispatch_refactor/check_refactor.py',
]

def blob(data):
    return hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()

def original(path):
    return subprocess.check_output(['git','show',f'{BASE}:{path}'],cwd=ROOT)

def unchanged_actor_logic(name,begin,end):
    text=(ROOT/PREFIX/name).read_text()
    assert text.count(begin)==1
    start=text.index(begin)
    finish=text.index(end,start)
    assert (text[:start]+text[finish:]).encode()==original(PREFIX+name),name

def main():
    from lupa.luajit21 import LuaRuntime
    lua=LuaRuntime()
    modules=sorted((ROOT/PREFIX).glob('*.lua'))
    scripts=sorted((ROOT/'r6/scripts/NCPDPatrol').glob('*.reds'))
    assert len(modules)==21 and len(scripts)==28
    for path in modules:
        lua.eval('function(p) local f,e=loadfile(p);assert(f,e) end')(str(path))

    # Actor flow is byte-identical after removing only the new read-only view.
    unchanged_actor_logic('vip.lua','-- Read-only lifecycle view.','function M.reset()')
    unchanged_actor_logic('cyberpsycho.lua','-- Read-only lifecycle view;','function M.variantState()')
    init=original(PREFIX+'init.lua').decode()
    init=init.replace('-- NCPD Patrol v0.17d | completed VIP dispatch releases partial ambush cleanup',
                      '-- NCPD Patrol v0.17d dispatch refactor r1 | unchanged gameplay contracts')
    init=init.replace('v0.17d loaded. Completed VIP delivery releases known ambush cleanup, including never-attached cars and pending crew despawn. Marker recovery and rewards retained. Install the complete package and restart.',
                      'v0.17d dispatch refactor r1 loaded. Scanner, scheduling and result tracking are separate modules. Existing rewards, progression, markers and actor cleanup retained. Install the complete package and restart.')
    init=init.replace('ImGui.Begin("NCPD Patrol - v0.17d")','ImGui.Begin("NCPD Patrol - v0.17d dispatch refactor r1")')
    assert (ROOT/PREFIX/'init.lua').read_text()==init,'Only the CET build labels may change in init.lua'

    original_paths=subprocess.check_output(['git','ls-tree','-r','--name-only',BASE,'--','bin','r6','archive'],cwd=ROOT,text=True).splitlines()
    changed={PREFIX+name for name in ['dispatch.lua','init.lua','vip.lua','cyberpsycho.lua']}
    added={PREFIX+name for name in ['dispatch_scanner.lua','dispatch_scheduler.lua','dispatch_results.lua']}
    for path in original_paths:
        if path not in changed:assert (ROOT/path).read_bytes()==original(path),f'Unrelated payload changed: {path}'
    assert (ROOT/'LICENSE').read_bytes()==original('LICENSE')

    paths=[]
    for dirname in ['bin','r6','archive']:
        paths.extend(p for p in (ROOT/dirname).rglob('*') if p.is_file())
    paths.extend(ROOT/name for name in ['LICENSE','README.txt'])
    assert {p.relative_to(ROOT).as_posix() for p in paths}==set(original_paths)|added|{'LICENSE','README.txt'}
    assert len(paths)==69

    with TemporaryDirectory(prefix='ncpd-refactor-verification-') as tmp:
        comparison=Path(tmp)/'comparison.json'
        for test in TESTS:
            args=[sys.executable,str(ROOT/test)]
            if test==TESTS[-1]:args.extend(['--report',str(comparison)])
            subprocess.run(args,cwd=ROOT,check=True)
        trace=json.loads(comparison.read_text())

    release=ROOT/'releases'/NAME
    release.parent.mkdir(exist_ok=True)
    with zipfile.ZipFile(release,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=9) as archive:
        for path in sorted(paths):
            info=zipfile.ZipInfo(path.relative_to(ROOT).as_posix(),(2026,11,19,0,0,0))
            info.compress_type=zipfile.ZIP_DEFLATED;info.create_system=3;info.external_attr=0o100644<<16
            archive.writestr(info,path.read_bytes(),compresslevel=9)
    with zipfile.ZipFile(release) as archive:
        assert archive.testzip() is None
        assert set(archive.namelist())=={p.relative_to(ROOT).as_posix() for p in paths}
        for path in paths:assert archive.read(path.relative_to(ROOT).as_posix())==path.read_bytes()
    data=release.read_bytes()
    report={
        'version':'v0.17d-dispatch-refactor-r1','base_commit':BASE,'source_commit':os.environ.get('GITHUB_SHA'),
        'install_files':len(paths),'lua_modules_parsed':len(modules),'redscript_files':len(scripts),
        'portable_tests':TESTS,'behavior_comparison':trace,
        'zip_path':release.relative_to(ROOT).as_posix(),'zip_bytes':len(data),
        'zip_sha256':hashlib.sha256(data).hexdigest(),'zip_git_blob':blob(data),
        'new_runtime_modules':sorted(added),'native_scripts_changed':[], 'archives_changed':[],
        'actor_logic_unchanged_except_read_only_lifecycle_views':True,
        'other_payload_unchanged':True,'existing_facade_preserved':True,
        'weights':{'scanner':50,'vip':30,'cyberpsycho':20},
        'standby_seconds':[60,120],'initial_standby_seconds':[30,60],'all_unavailable_retry_seconds':30,
        'rewards':{'scanner':1000,'attended_scanner_dispatch':500,'vip':2000,
                   'cyberpsycho':3000,'non_lethal_cyberpsycho_extra':500,'arrest':250},
        'persistent_fields_changed':[],'native_interfaces_changed':[],
        'optional_browser_requirement_unchanged':True,'localization_provider_unchanged':True,
        'actual_game_validation':False,
        'files':{p.relative_to(ROOT).as_posix():{'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),
                                             'git_blob':blob(p.read_bytes())} for p in paths},
    }
    (ROOT/'releases/NCPD_Patrol_Dispatch_Refactor_r1_verification.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({k:v for k,v in report.items() if k!='files'},indent=2))

if __name__=='__main__':main()
