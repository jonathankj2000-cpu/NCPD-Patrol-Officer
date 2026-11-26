"""Compare actual VIP extraction with r2 under native/engine-boundary fixtures."""
from pathlib import Path
from tempfile import TemporaryDirectory
import argparse,hashlib,json,shutil,subprocess,sys
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
sys.path.insert(0,str(HERE));from source_guard import BASE,PREFIX,verify
sys.path.insert(0,str(HERE.parent/'dispatch_refactor'));from check_refactor import runtime
GROUPS={
    'vip':[HERE.parent/'vip'/name for name in ['scenarios.lua','fleet-scenarios.lua','waypoint-scenarios.lua']],
    'dispatch':[HERE.parent/'incidents'/name for name in ['native-scenarios.lua','mixed-scenarios.lua','background-scenarios.lua','partial-cleanup-scenarios.lua']],
}

def boot(modules,trace):
    lua=runtime(modules,trace,install_trace=False,legacy_vip_locations=True)
    lua.execute((HERE/'trace.lua').read_text())
    return lua

def execute(modules):
    trace=[]
    for group,scenarios in GROUPS.items():
        lua=boot(modules,trace)
        trace.append('group|'+group)
        for scenario in scenarios:
            trace.append('scenario|'+scenario.name);lua.execute(scenario.read_text())
    return trace

def materialize(destination):
    paths=subprocess.check_output(['git','ls-tree','-r','--name-only',BASE,'--',PREFIX],cwd=ROOT,text=True).splitlines()
    for path in paths:
        if path.endswith('.lua'):(destination/Path(path).name).write_bytes(subprocess.check_output(['git','show',f'{BASE}:{path}'],cwd=ROOT))

def probe(modules,kind):
    trace=[];lua=boot(modules,trace);lua.globals().ProbeKind=kind
    lua.execute('''local VIP=require('vip');local f,v=CyberFixture,VIPFixture
        VIP.reset();v:Reset()
        if ProbeKind=='clearance' then f.places={f:Place(800),f:Place(1800),f:Place(900,0,0,'assault',true,2)} end
        VIP.request(f.patrol,function(text) f.logs[#f.logs+1]=text end,true,true)
        if ProbeKind=='cooldown' then
            for _,pin in pairs(v.pins) do Game.GetMappinSystem():UnregisterMappin(pin.id);break end
            f.markerOK=false
            for _=1,28 do VIP.update(.25,true,f.patrol,nil,{set=function() end}) end
        end''')
    return trace

def main():
    verify(ROOT)
    current=ROOT/PREFIX
    with TemporaryDirectory(prefix='ncpd-vip-r3-oracle-') as tmp:
        reference=Path(tmp)/'reference';reference.mkdir();materialize(reference)
        expected=execute(reference);actual=execute(current)
        if expected!=actual:
            for index,(old,new) in enumerate(zip(expected,actual)):
                if old!=new:raise AssertionError(f'VIP behavior changed at row {index}:\nOLD: {old}\nNEW: {new}')
            raise AssertionError(f'VIP trace lengths differ: {len(expected)} vs {len(actual)}')
        for kind,name,needle,replacement in [
            ('cooldown','vip_waypoint.lua','waypointCooldown=5','waypointCooldown=6')]:
            broken=Path(tmp)/kind;broken.mkdir()
            for path in current.glob('*.lua'):shutil.copyfile(path,broken/path.name)
            target=broken/name;text=target.read_text();assert text.count(needle)==1;target.write_text(text.replace(needle,replacement))
            assert probe(reference,kind)!=probe(broken,kind),kind+' negative control missed policy regression'
        # Independent marker/location owners are tested only for the new API;
        # the public VIP facade above stays the oracle for behavior.
        helper=runtime(current,[],install_trace=False,legacy_vip_locations=True)
        helper.execute((HERE/'helper-contracts.lua').read_text())
    digest=hashlib.sha256('\n'.join(actual).encode()).hexdigest()
    report={'base_commit':BASE,'identical_trace_rows':len(actual),'trace_sha256':digest,
        'scenario_files':[p.relative_to(ROOT).as_posix() for group in GROUPS.values() for p in group],
        'extracted_policies_and_remaining_actor_flow_source_guard':True,
        'geography_scope':'Pinned v0.17e2 location provider; new baked selection and scanner clearance negative control tested separately',
        'recovery_cooldown_negative_control':True,
        'independent_helpers_and_old_world_reset':True,'actual_game_validation':False}
    print(f'PASS: VIP actor extraction with pinned legacy geography: {len(actual)} identical r2 trace rows; registry/quest/actor/reward/cleanup outcomes; source guards, independent helper ownership, world reset and recovery-cooldown negative control. SHA256={digest}')
    return report

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--report',type=Path)
    args=parser.parse_args();report=main()
    if args.report:args.report.write_text(json.dumps(report,indent=2)+'\n')
