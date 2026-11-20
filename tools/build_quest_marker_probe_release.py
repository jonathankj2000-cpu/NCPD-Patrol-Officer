"""Verify the archived phase control and package the complete r5c fixed marker dispatch test."""
from pathlib import Path
from tempfile import TemporaryDirectory
import hashlib,json,os,subprocess,sys,zipfile
from build_vip_refactor_release import TESTS as EXISTING_TESTS

ROOT=Path(__file__).resolve().parents[1]
BASE='d68b1696e1e0042609f323816ba94f7481de6e02'
PREFIX='bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrol/'
NAME='NCPD_Patrol_v0.17d_Fixed_Quest_Markers_r5c_TEST.zip'
REPORT='NCPD_Patrol_Fixed_Quest_Markers_r5c_verification.json'
TESTS=[*EXISTING_TESTS,'tests/quest_marker_probe/check_probe.py','tests/fixed_markers/check_fixed.py']

def blob(body):return hashlib.sha1(b'blob '+str(len(body)).encode()+b'\0'+body).hexdigest()

def main():
    from lupa.luajit21 import LuaRuntime
    lua=LuaRuntime();modules=sorted((ROOT/PREFIX).glob('*.lua'))
    scripts=sorted((ROOT/'r6/scripts/NCPDPatrol').glob('*.reds'))
    static_base='63a6100602de836dd4f670fa8022f87fc1acfe99'
    for name in ['archive/pc/mod/NCPDPatrol_QuestMarkerProbe.archive','archive/pc/mod/NCPDPatrol_QuestMarkerProbe.archive.xl']:
        assert (ROOT/name).read_bytes()==subprocess.check_output(['git','show',f'{static_base}:{name}'],cwd=ROOT),name
    assert len(modules)==27 and len(scripts)==34
    for archive in sorted((ROOT/'archive/pc/mod').glob('*.archive')):
        assert archive.read_bytes()==subprocess.check_output(['git','show',f'19e8b82ea1b42f4fbbdca031ea9e9365b82d6af5:{archive.relative_to(ROOT).as_posix()}'],cwd=ROOT),archive
    for p in modules:lua.eval('function(p) local f,e=loadfile(p);assert(f,e) end')(str(p))
    previous=subprocess.check_output(['git','ls-tree','-r','--name-only',BASE,'--','bin','r6','archive'],cwd=ROOT,text=True).splitlines()
    changed={PREFIX+n for n in ['init.lua','cet_ui.lua','dispatch_scanner.lua','cyberpsycho.lua','vip_waypoint.lua']}
    changed.update('r6/scripts/NCPDPatrol/NCPDPatrol'+n+'System.reds' for n in ['DispatchJournal','VIP','Cyberpsycho'])
    changed.update('archive/pc/mod/NCPDPatrol_'+n+'.archive' for n in ['Dispatch','VIP','Cyberpsycho'])
    added={PREFIX+'quest_marker_probe.lua','r6/scripts/NCPDPatrol/NCPDPatrolQuestMarkerProbeSystem.reds',
           'archive/pc/mod/NCPDPatrol_QuestMarkerProbe.archive','archive/pc/mod/NCPDPatrol_QuestMarkerProbe.archive.xl',
           'r6/scripts/NCPDPatrol/NCPDPatrolMarkerSession.reds',
           'r6/scripts/NCPDPatrol/NCPDPatrolReferenceMappins.reds',
           'r6/scripts/NCPDPatrol/NCPDPatrolReferenceMappinData.reds','THIRD_PARTY_NOTICES.txt',
           PREFIX+'marker_catalog.lua',PREFIX+'marker_navigation.lua',
           'r6/scripts/NCPDPatrol/NCPDPatrolFixedMarkerData.reds','r6/scripts/NCPDPatrol/NCPDPatrolFixedMarkerSystem.reds'}
    for name in previous:
        if name not in changed:
            assert (ROOT/name).read_bytes()==subprocess.check_output(['git','show',f'{BASE}:{name}'],cwd=ROOT),'Unrelated gameplay changed: '+name
    assert (ROOT/'LICENSE').read_bytes()==subprocess.check_output(['git','show',f'{BASE}:LICENSE'],cwd=ROOT)
    paths=[p for d in ['bin','r6','archive'] for p in (ROOT/d).rglob('*') if p.is_file()]
    paths.extend(ROOT/n for n in ['README.txt','LICENSE','THIRD_PARTY_NOTICES.txt'])
    assert {p.relative_to(ROOT).as_posix() for p in paths}==set(previous)|added|{'README.txt','LICENSE'}
    assert len(paths)==84
    compared=['tests/dispatch_refactor/check_refactor.py','tests/cet_ui/check_cet_ui.py',
              'tests/vip_refactor/check_vip_refactor.py','tests/quest_marker_probe/check_probe.py','tests/fixed_markers/check_fixed.py']
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
            info=zipfile.ZipInfo(p.relative_to(ROOT).as_posix(),(2026,11,20,0,0,0))
            info.compress_type=zipfile.ZIP_DEFLATED;info.create_system=3;info.external_attr=0o100644<<16
            z.writestr(info,p.read_bytes(),compresslevel=9)
    with zipfile.ZipFile(release) as z:
        assert z.testzip() is None and len(z.namelist())==len(set(z.namelist()))==84
        assert set(z.namelist())=={p.relative_to(ROOT).as_posix() for p in paths}
        for p in paths:assert z.read(p.relative_to(ROOT).as_posix())==p.read_bytes()
    body=release.read_bytes()
    report={'version':'v0.17d-fixed-quest-markers-r5c','base_commit':BASE,'source_commit':os.environ.get('GITHUB_SHA'),
        'install_files':len(paths),'lua_modules_parsed':len(modules),'redscript_files':len(scripts),'portable_tests':TESTS,
        'probe':comparisons[compared[3]],'fixed_markers':comparisons[compared[4]],'fixed_marker_sources':json.loads((ROOT/'assets/fixed_markers/sources.json').read_text()),'fixed_marker_resources':json.loads((ROOT/'assets/fixed_markers/compiled.json').read_text()),'vip_comparison':comparisons[compared[2]],
        'dispatch_comparison':comparisons[compared[0]],'ui_comparison':comparisons[compared[1]],
        'zip_path':release.relative_to(ROOT).as_posix(),'zip_bytes':len(body),'zip_sha256':hashlib.sha256(body).hexdigest(),
        'zip_git_blob':blob(body),'new_payload':sorted(added),'changed_payload':sorted(changed),'existing_actor_reward_and_result_methods_unchanged':True,'native_owner_changes':'Transient navigation site, objective path helpers and guarded site selection only; source-guarded against r5','legacy_behavior_comparison_scope':'Unavailable-bank compatibility; bank-present behavior is covered by the fixed marker suite',
        'entrypoint_and_ui_changes':'Session/Ready gate around existing CET update consumers, read-only diagnostics and build labels; original actor/reward/result owners retained',
        'currency_and_progression_unchanged':True,'browser_extension_still_optional':True,
        'actual_game_validation':False,'prior_static_control_in_game_evidence':json.loads((ROOT/'assets/quest_marker_probe/r4d-game-evidence.json').read_text()),'confirmed_static_resources_unchanged':True,'runtime_relocation_used_by_dispatch':False,'all_six_archives_unchanged_from_r5a':True,'fixed_marker_bank_in_game_validation':False,'prior_r5_failure_evidence':json.loads((ROOT/'assets/fixed_markers/r5-game-evidence.json').read_text()),'fixed_journal_activation_requires_in_game_test':True,'prior_r5a_failure_evidence':json.loads((ROOT/'assets/fixed_markers/r5a-game-evidence.json').read_text()),'engine_owned_native_pins_unregistered':False,'valid_native_retained_without_claiming_full_journal_proof':True,'pre_cleanup_diagnostics_retained':True,'detached_player_blocks_native_marker_mutations':True,'reported_animation_crash_resolved':False,'reported_reload_crash_resolved':False,'r5b_native_rejection_evidence':json.loads((ROOT/'assets/fixed_markers/r5b-game-evidence.json').read_text()),'deterministic_ownership_catalog':3112,'session_readiness':'Codeware Session/BeforeStart/BeforeEnd/End/Ready; callbacks change flags only','restore_objectives_per_tick_maximum':48,
        'activation_contract_corrected':'Deterministic 3112-path ownership catalogue independent of journal availability, direct selected private-entry identity, full proof requires catalogue membership; Codeware session readiness gates native and CET work, bounded 48-objective restore slices; fallback status tracks latest observation. All six archives unchanged; no runtime relocation',
        'legacy_relocation_probe_contract':'One scoped SetMappinPosition call; runtime and quest-log position readbacks, same native ID/link and 3 active observed seconds required; no manual tracking write',
        'observed_r4_startup_error_fixed':'Direct runtime node constructor removed; quest node IDs are typed in the compiled resource',
        'files':{p.relative_to(ROOT).as_posix():{'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'git_blob':blob(p.read_bytes())} for p in paths}}
    (ROOT/'releases'/REPORT).write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({k:v for k,v in report.items() if k not in ['files','vip_comparison','dispatch_comparison','ui_comparison']},indent=2))
if __name__=='__main__':main()
