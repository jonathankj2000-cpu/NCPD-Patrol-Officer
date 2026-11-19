"""Compare actual refactored dispatch against the pinned pre-refactor runtime.

Native classes execute through the existing translator; only engine boundaries
are mocked. Includes all generated-incident scenarios, not a second scheduler.
"""
from pathlib import Path
from tempfile import TemporaryDirectory
import argparse, hashlib, json, re, subprocess, sys
from lupa.luajit21 import LuaRuntime

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
BASE='ff0d0024d85d31df783e5f989a1d2cb3d9cefbc1'
PREFIX='bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrol'
sys.path.insert(0,str(HERE.parent/'arrests'))
from translate import translate

SCENARIOS=[HERE.parent/'incidents'/name for name in ['native-scenarios.lua','mixed-scenarios.lua','background-scenarios.lua','partial-cleanup-scenarios.lua']] + [HERE/'scanner-contracts.lua']

def runtime(modules, trace, observe_lifecycle=False):
    lua=LuaRuntime(unpack_returned_tuples=True)
    lua.execute('math.randomseed(20261119)')
    lua.execute((HERE.parent/'arrests/mappin-native-mocks.lua').read_text())
    for name,alias in [('NCPDPatrolIncidentSystem','IncidentNative'),('NCPDPatrolCyberpsychoSystem','CyberNative'),('NCPDPatrolDispatchJournalSystem','DispatchJournalNative'),('NCPDPatrolVIPSystem','VIPNative'),('NCPDPatrolCareerSystem','CareerNative')]:
        lua.globals()[alias]=lua.execute(translate(ROOT/'r6/scripts/NCPDPatrol'/f'{name}.reds'))
    for path in ['dispatch_journal/native-mocks.lua','cyberpsycho/native-mocks.lua']:
        lua.execute((HERE.parent/path).read_text())
    lua.globals().MOD_DIR=str(modules)
    lua.execute('package.path=MOD_DIR.."/?.lua;"..package.path')
    for path in ['vip/native-mocks.lua','incidents/engine-mocks.lua']:
        lua.execute((HERE.parent/path).read_text())
    def record(row):
        # Moving a throwing statement necessarily changes its source location.
        trace.append(re.sub(r'[^\s|]*\.lua:\d+', '<lua>', row))
    lua.globals().Trace=record
    lua.execute((HERE/'trace.lua').read_text())
    if observe_lifecycle:
        lua.execute((HERE/'lifecycle.lua').read_text())
    return lua

def execute(modules, observe_lifecycle=False):
    trace=[]
    lua=runtime(modules,trace,observe_lifecycle)
    for scenario in SCENARIOS:
        trace.append('scenario|'+scenario.name)
        lua.execute(scenario.read_text())
    return trace

def materialize_baseline(destination):
    paths=subprocess.check_output(['git','ls-tree','-r','--name-only',BASE,'--',PREFIX],cwd=ROOT,text=True).splitlines()
    for path in paths:
        if path.endswith('.lua'):
            (destination/Path(path).name).write_bytes(subprocess.check_output(['git','show',f'{BASE}:{path}'],cwd=ROOT))

def main():
    with TemporaryDirectory(prefix='ncpd-dispatch-reference-') as tmp:
        baseline=Path(tmp)
        materialize_baseline(baseline)
        expected=execute(baseline)
        actual=execute(ROOT/PREFIX,observe_lifecycle=True)
        if expected!=actual:
            for index,(old,new) in enumerate(zip(expected,actual)):
                if old!=new:
                    raise AssertionError(f'Behavior changed at trace row {index}:\nBASE: {old}\nNEW:  {new}')
            raise AssertionError(f'Trace lengths differ: {len(expected)} vs {len(actual)}')
        # Prove this comparison detects a timing regression that ordinary
        # success/failure assertions can miss. Only mutate the temporary oracle.
        source=baseline/'dispatch.lua'
        text=source.read_text()
        needle='countdown = math.random(30, 60)'
        assert needle in text
        source.write_text(text.replace(needle,needle+' + 1',1))
        negative=[]
        probe=runtime(baseline,negative)
        probe.execute("require('dispatch').start(CyberFixture.patrol)")
        positive=[]
        control=runtime(ROOT/PREFIX,positive)
        control.execute("require('dispatch').start(CyberFixture.patrol)")
        assert negative!=positive,'negative control failed to detect a one-second timer change'
    digest=hashlib.sha256('\n'.join(actual).encode()).hexdigest()
    print(f'PASS: v0.17d comparison: {len(actual)} identical trace rows; random draws, facade, timers, results, native tokens, money, notices, markers, actor ownership and cleanup; lifecycle invariants; timing-regression negative control. SHA256={digest}')
    return {'base_commit':BASE,'identical_trace_rows':len(actual),'trace_sha256':digest,
            'scenario_files':[p.relative_to(ROOT).as_posix() for p in SCENARIOS],
            'lifecycle_invariants':True,'timing_regression_negative_control':True}

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--report',type=Path)
    args=parser.parse_args()
    report=main()
    if args.report:args.report.write_text(json.dumps(report,indent=2)+'\n')
