"""Execute the narrow hit policy, both authored wrappers and actual duty rule.

Damage/prevention are recording boundaries, not an in-game wanted simulation.
The source investigation and limits are recorded in the accompanying document.
"""
from pathlib import Path
import argparse,json,re,sys,tempfile
from lupa.luajit21 import LuaRuntime
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
sys.path.insert(0,str(HERE.parent/'arrests'))
from translate import translate

def fragment(source,pattern):
    m=re.search(pattern,source);assert m,pattern
    start=source.index('{',m.start());end=start+1;depth=1
    while depth:
        depth+=(source[end]=='{')-(source[end]=='}');end+=1
    return source[m.start():end]

def main():
    lua=LuaRuntime(unpack_returned_tuples=True)
    native=ROOT/'r6/scripts/NCPDPatrol'
    source=(native/'NCPDPatrolPartnerSafety.reds').read_text()
    with tempfile.TemporaryDirectory(prefix='ncpd-partner-safety-') as d:
        p=Path(d)/'fixture.reds'
        policy=fragment(source,r'public class NCPDPatrolPartnerSafety\b')
        policy=policy.replace('receiver as NPCPuppet','AsNPC(receiver)').replace('receiver as VehicleObject','AsVehicle(receiver)')
        p.write_text(policy);lua.globals().Safety=lua.execute(translate(p))
        for kind in ['NPCPuppet','VehicleObject']:
            wrapper=fragment(source,r'@wrapMethod\('+kind+r'\)')
            wrapper=wrapper[wrapper.index('protected cb func'):]
            p.write_text('public class Fixture extends IScriptable {\n'+wrapper+'\n}')
            lua.globals()[kind+'Wrapper']=lua.execute(translate(p))
    for name,file in [('Core','NCPDPatrolSystem.reds'),('Support','NCPDPatrolSupportSystem.reds')]:
        lua.globals()[name]=lua.execute(translate(native/file))
    lua.execute((HERE/'scenarios.lua').read_text())
    result={'exact_registered_partner_only':True,'on_duty_session_only':True,
      'ranged_hits_only':True,'non_hostile_police_people_and_vehicles_only':True,
      'npc_and_vehicle_on_hit_wrappers':True,'v_and_other_companions_unchanged':True,
      'enemy_and_hostile_quest_targets_unchanged':True,'wanted_enforcement_unchanged':True,
      'world_restore_forgets_partner':True,'actual_game_wanted_reproduction':False}
    parser=argparse.ArgumentParser();parser.add_argument('--report',type=Path);args=parser.parse_args()
    if args.report:args.report.write_text(json.dumps(result,indent=2)+'\n')
    print('PASS: actual partner hit policy and NPC/vehicle wrappers: exact registered source, duty/session/attachment and ranged scope; police affiliation/occupants and hostile bypass; V/other companions/enemies and original return values retained; same-frame V hit and native criminal-termination rule unchanged; restore clears ownership (engine boundaries mocked)')
    return result

if __name__=='__main__':main()
