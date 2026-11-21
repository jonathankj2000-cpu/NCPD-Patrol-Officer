"""Execute the narrow hit policy, both authored wrappers and actual duty rule.

Damage/prevention are recording boundaries, not an in-game wanted simulation.
The source investigation and limits are recorded in the accompanying document.
"""
from pathlib import Path
import argparse,json,re,subprocess,sys,tempfile
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
        for source_name in ['receiver','object']:
            policy=policy.replace(source_name+' as NPCPuppet','AsNPC('+source_name+')').replace(source_name+' as VehicleObject','AsVehicle('+source_name+')')
        policy=policy.replace('receiver as PlayerPuppet','AsPlayer(receiver)')
        p.write_text(policy);lua.globals().Safety=lua.execute(translate(p))
        previous=subprocess.check_output(['git','show','82ed62c3987854acb06cbf527d648079b9a086e6:r6/scripts/NCPDPatrol/NCPDPatrolPartnerSafety.reds'],cwd=ROOT,text=True)
        previous=fragment(previous,r'public class NCPDPatrolPartnerSafety\b')
        previous=previous.replace('receiver as NPCPuppet','AsNPC(receiver)').replace('receiver as VehicleObject','AsVehicle(receiver)')
        p.write_text(previous);lua.globals().PreviousSafety=lua.execute(translate(p))
        for kind in ['NPCPuppet','VehicleObject','GameObject']:
            wrapper=fragment(source,r'@wrapMethod\('+kind+r'\)')
            wrapper=wrapper[wrapper.index('protected cb func'):]
            p.write_text('public class Fixture extends IScriptable {\n'+wrapper+'\n}')
            lua.globals()[kind+'Wrapper']=lua.execute(translate(p))
    for name,file in [('Core','NCPDPatrolSystem.reds'),('Support','NCPDPatrolSupportSystem.reds')]:
        lua.globals()[name]=lua.execute(translate(native/file))
    lua.execute((HERE/'scenarios.lua').read_text()+'\n'+(HERE/'player-scenarios.lua').read_text())
    sys.path.insert(0,str(HERE.parent/'cet_ui'));from check_cet_ui import runtime as ui_runtime
    _,ui=ui_runtime(ROOT/'bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrol')
    ui.Frame(ui,'Diagnostics','Log police fire diagnostics')
    assert ui.clicks==1 and 'Police fire |' in ui.Events(ui)
    result={'partner_guard_exact_registered_partner_only':True,'on_duty_session_only':True,
      'ranged_hits_only':True,'non_hostile_police_people_and_vehicles_only':True,
      'npc_and_vehicle_on_hit_wrappers':True,'ordinary_v_hits_and_other_companions_unchanged':True,
      'enemy_and_hostile_quest_targets_unchanged':True,'wanted_enforcement_unchanged':True,
      'v_stray_fire_requires_hostile_combat_context':True,'v_allowance_one_discharge_per_ten_seconds':True,
      'direct_police_aim_and_repeated_fire_passthrough':True,'incoming_hostile_player_hit_recorded_before_original':True,
      'exact_discharge_pellet_deduplication':True,'v018e2_stray_fire_gap_reproduced':True,
      'world_restore_forgets_partner':True,'actual_game_wanted_reproduction':False}
    parser=argparse.ArgumentParser();parser.add_argument('--report',type=Path);args=parser.parse_args()
    if args.report:args.report.write_text(json.dumps(result,indent=2)+'\n')
    print('PASS: actual partner/V police-hit policy and three wrappers: hostile combat context, one stray discharge per 10 s, exact-shot pellet deduplication, direct police aim/repeated fire and non-ranged bypass, incoming hostile hit source, real v0.18e2 negative control; duty/world/identity and unchanged criminal termination, lifecycle reset (engine boundaries mocked)')
    return result

if __name__=='__main__':main()
