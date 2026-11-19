"""Verify the isolated marker experiment and package the complete r4 build."""
from pathlib import Path
from tempfile import TemporaryDirectory
import hashlib,json,os,subprocess,sys,zipfile
from build_vip_refactor_release import TESTS as EXISTING_TESTS

ROOT=Path(__file__).resolve().parents[1]
BASE='d68b1696e1e0042609f323816ba94f7481de6e02'
PREFIX='bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrol/'
NAME='NCPD_Patrol_v0.17d_Quest_Marker_Probe_r4_TEST.zip'
REPORT='NCPD_Patrol_Quest_Marker_Probe_r4_verification.json'
TESTS=[*EXISTING_TESTS,'tests/quest_marker_probe/check_probe.py']

def blob(body):return hashlib.sha1(b'blob '+str(len(body)).encode()+b'\0'+body).hexdigest()

def main():
    from lupa.luajit21 import LuaRuntime
    lua=LuaRuntime();modules=sorted((ROOT/PREFIX).glob('*.lua'))
    scripts=sorted((ROOT/'r6/scripts/NCPDPatrol').glob('*.reds'))
    assert len(modules)==25 and len(scripts)==29
    for p in modules:lua.eval('function(p) local f,e=loadfile(p);assert(f,e) end')(str(p))
    previous=subprocess.check_output(['git','ls-tree','-r','--name-only',BASE,'--','bin','r6','archive'],cwd=ROOT,text=True).splitlines()
    changed={PREFIX+n for n in ['init.lua','cet_ui.lua']}
    added={PREFIX+'quest_marker_probe.lua','r6/scripts/NCPDPatrol/NCPDPatrolQuestMarkerProbeSystem.reds',
           'archive/pc/mod/NCPDPatrol_QuestMarkerProbe.archive','archive/pc/mod/NCPDPatrol_QuestMarkerProbe.archive.xl'}
    for name in previous:
        if name not in changed:
            assert (ROOT/name).read_bytes()==subprocess.check_output(['git','show',f'{BASE}:{name}'],cwd=ROOT),'Unrelated gameplay changed: '+name
    assert (ROOT/'LICENSE').read_bytes()==subprocess.check_output(['git','show',f'{BASE}:LICENSE'],cwd=ROOT)
    paths=[p for d in ['bin','r6','archive'] for p in (ROOT/d).rglob('*') if p.is_file()]
    paths.extend(ROOT/n for n in ['README.txt','LICENSE'])
    assert {p.relative_to(ROOT).as_posix() for p in paths}==set(previous)|added|{'README.txt','LICENSE'}
    assert len(paths)==76
    compared=['tests/dispatch_refactor/check_refactor.py','tests/cet_ui/check_cet_ui.py',
              'tests/vip_refactor/check_vip_refactor.py','tests/quest_marker_probe/check_probe.py']
    with TemporaryDirectory(prefix='ncpd-marker-r4-check-') as tmp:
        reports={t:Path(tmp)/(str(i)+'.json') for i,t in enumerate(compared)}
        for test in TESTS:
            args=[sys.executable,str(ROOT/test)]
            if test in reports:args+=['--report',str(reports[test])]
            subprocess.run(args,cwd=ROOT,check=True)
        comparisons={t:json.loads(p.read_text()) for t,p in reports.items()}
    release=ROOT/'releases'/NAME
    with zipfile.ZipFile(release,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=9) as z:
        for p in sorted(paths):
            info=zipfile.ZipInfo(p.relative_to(ROOT).as_posix(),(2026,11,19,0,0,0))
            info.compress_type=zipfile.ZIP_DEFLATED;info.create_system=3;info.external_attr=0o100644<<16
            z.writestr(info,p.read_bytes(),compresslevel=9)
    with zipfile.ZipFile(release) as z:
        assert z.testzip() is None and len(z.namelist())==len(set(z.namelist()))==76
        assert set(z.namelist())=={p.relative_to(ROOT).as_posix() for p in paths}
        for p in paths:assert z.read(p.relative_to(ROOT).as_posix())==p.read_bytes()
    body=release.read_bytes()
    report={'version':'v0.17d-quest-marker-probe-r4','base_commit':BASE,'source_commit':os.environ.get('GITHUB_SHA'),
        'install_files':len(paths),'lua_modules_parsed':len(modules),'redscript_files':len(scripts),'portable_tests':TESTS,
        'probe':comparisons[compared[3]],'vip_comparison':comparisons[compared[2]],
        'dispatch_comparison':comparisons[compared[0]],'ui_comparison':comparisons[compared[1]],
        'zip_path':release.relative_to(ROOT).as_posix(),'zip_bytes':len(body),'zip_sha256':hashlib.sha256(body).hexdigest(),
        'zip_git_blob':blob(body),'new_payload':sorted(added),'existing_dispatch_and_native_scripts_unchanged':True,
        'entrypoint_and_ui_changes':'isolated probe hooks, four Testing controls and build labels',
        'currency_and_progression_unchanged':True,'browser_extension_still_optional':True,
        'actual_game_validation':False,'native_node_activation_requires_in_game_test':True,
        'files':{p.relative_to(ROOT).as_posix():{'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'git_blob':blob(p.read_bytes())} for p in paths}}
    (ROOT/'releases'/REPORT).write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({k:v for k,v in report.items() if k not in ['files','vip_comparison','dispatch_comparison','ui_comparison']},indent=2))
if __name__=='__main__':main()
