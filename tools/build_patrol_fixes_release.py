"""Verify terrain-aware arrest/VIP/ambush fixes; package the complete mod."""
from pathlib import Path
import hashlib,json,os,subprocess,sys,zipfile
ROOT=Path(__file__).resolve().parents[1]
BASE='25d5d79c6c82aee5a8aea23ad68c88b202d2a28c'
NAME='NCPD_Patrol_v0.16d_Terrain_VIP_Ambush_Fixes_TEST.zip'
def run(*args):subprocess.run([*map(str,args)],cwd=ROOT,check=True)
def blob(data):return hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()
def main():
 from lupa.luajit21 import LuaRuntime
 lua=LuaRuntime();modules=sorted((ROOT/'bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrol').glob('*.lua'))
 scripts=sorted((ROOT/'r6/scripts/NCPDPatrol').glob('*.reds'))
 assert len(modules)==17 and len(scripts)==27
 for p in modules:lua.eval('function(p) local f,e=loadfile(p);assert(f,e) end')(str(p))
 tests=['tests/beanbagger/check_visuals.py','tests/beanbagger/check_beanbagger.py','tests/shift_entry/check_shift.py','tests/compile_compatibility/check_legacy_api.py','tests/arrests/check_arrest.py','tests/arrests/check_arrest_interactions.py','tests/trunk_menu/check_trunk.py',
  'tests/dispatch_journal/check_journal.py','tests/career/check_career.py','tests/cyberpsycho/check_cyberpsycho.py',
  'tests/vip/check_vip.py','tests/officer_readiness/check_ready.py']
 for test in tests:run(sys.executable,ROOT/test)
 prefix='bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrol/'
 changed={prefix+name for name in ['init.lua','arrest.lua','vip.lua','vip_ambush.lua']}
 changed.add('r6/scripts/NCPDPatrol/NCPDPatrolArrestInteractions.reds')
 changed.add('r6/scripts/NCPDPatrol/NCPDPatrolArrestSystem.reds')
 added=set()
 original=subprocess.check_output(['git','ls-tree','-r','--name-only',BASE,'--','bin','r6','archive'],cwd=ROOT,text=True).splitlines()
 run('git','diff','--exit-code',BASE,'--','LICENSE',*[path for path in original if path not in changed])
 paths=[]
 for dirname in ['bin','r6','archive']:paths.extend(p for p in (ROOT/dirname).rglob('*') if p.is_file())
 paths.extend(ROOT/name for name in ['LICENSE','README.txt'])
 assert {p.relative_to(ROOT).as_posix() for p in paths}==set(original)|added|{'LICENSE','README.txt'} and len(paths)==64
 release=ROOT/'releases'/NAME;release.parent.mkdir(exist_ok=True)
 with zipfile.ZipFile(release,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=9) as z:
  for path in sorted(paths):
   info=zipfile.ZipInfo(path.relative_to(ROOT).as_posix(),(2026,11,19,0,0,0));info.compress_type=zipfile.ZIP_DEFLATED
   info.create_system=3;info.external_attr=0o100644<<16;z.writestr(info,path.read_bytes(),compresslevel=9)
 with zipfile.ZipFile(release) as z:
  assert z.testzip() is None and set(z.namelist())=={p.relative_to(ROOT).as_posix() for p in paths}
  for path in paths:assert z.read(path.relative_to(ROOT).as_posix())==path.read_bytes()
 data=release.read_bytes()
 report={'version':'v0.16d','source_commit':os.environ.get('GITHUB_SHA'),'base_commit':BASE,
  'install_files':len(paths),'lua_modules_parsed':len(modules),'redscript_files':len(scripts),'portable_tests':tests,
  'zip_path':release.relative_to(ROOT).as_posix(),'zip_bytes':len(data),'zip_sha256':hashlib.sha256(data).hexdigest(),'zip_git_blob':blob(data),
  'native_arrest_interface':6,'native_trunk_interface':4,'native_officer_equipment_interface':1,'native_cyberpsycho_interface':3,'native_vip_interface':2,
  'trunk_menu':'native R hold opens Codeware blocking popup; two rows of four cards; independent 1-7 and 9 actions; numpad/mouse; scoped lifecycle',
  'active_backup':'explicit follow commands replace permanent scene hold; boarding priority; existing 10-4 retains scene and reservation',
  'readiness':'verify actual held slots; stalled command falls back to native equip/unequip with existing tagged-officer inventory; native combat priority',
  'codeware_api_source':'v1.21.4 / 6dfdbceff7882d8ad8632ab1ff8d42bcef20a8ad',
  'existing_archives_unchanged':True,'redscript_changed':['NCPDPatrolArrestInteractions.reds','NCPDPatrolArrestSystem.reds'],'weapon_readiness_rules_unchanged':True,'cyberpsycho_pool_and_tweaks_unchanged':True,
  'vip_ambush_aftermath_and_tyre_repair_unchanged':True,'scanner_arrest_and_dispatch_payments_unchanged':True,
  'shift_entry_fix_included':True,
  'arrest_recovery':{'living_ragdolls':True,'max_displacement_metres':2,'max_height_change_metres':0.75,'navigation_and_static_collision_footprint_checked':True,'prefer_flatter_nearby_ground':True,'native_workspot_ground_alignment':True,'position_check_after_native_activation':True,'life_health_and_defeat_unchanged':True,'native_physics_ownership_released_on_cleanup':True,'native_pickup_handoff':True,'native_R_pickup_preserved_before_arrest_and_after_failure':True,'payment_requires_existing_activation_proof':True},
  'vip_locations':{'fast_travel_interaction_availability_ignored':True,'drop_point_fallback':True,'fast_travel_discovery_unchanged':True,'pickup_distance_metres':[500,2000],'trip_distance_metres':[800,2500],'unfinished_scanner_clearance_metres':100,'candidate_counts_in_diagnostics':True,'arrival_navigation_check_retained':True},
  'ambush_road_placement':{'recent_driven_route_distance_metres':[35,65],'sample_seconds':0.25,'static_surface_and_vehicle_footprint_checked':True,'swept_corridor_barrier_checks':True,'actual_car_position_checked_before_crew_and_chase':True,'crew_spawn_within_checked_car_footprint':True,'mount_as_each_actor_attaches':True,'max_spawn_attempts':3,'cleanup_confirmed_before_retry':True,'warning_after_actual_mount_and_placement':True},
  'cyberpsycho_dispatch':{'vehicle_interaction_availability_ignored':True,'completed_call_releases_dispatch':True,'retained_scenes_max':3,'scene_cleanup_seconds':120,'scene_cleanup_distance_metres':150,'old_scene_cleanup_cannot_clear_new_waypoint_or_journal':True},
  'bean_bagger':{'inventory_icon':'weapon_Preset_Tactician_Default_None__Default','id':'Items.NCPDBeanBagger_M2038','tier':2,'milestone':20,'damage_multiplier':0.9,'native_interface':1,'scope':'V ranged human hits; existing native defeat mechanic','downed_hit_damage':0,'test_button':True,'old_receipts_preserved':True,'partner_loadouts_unchanged':True,'stock_visuals':False,'private_factory':'NCPDPatrol_BeanBagger','blue_parts':['pistol grip','pump fore-end'],'color_srgb':'#28567D','first_and_third_person_masks':True,'geometry_and_animations_preserved':True,'runtime_localization':'existing Codeware provider'},
  'compatibility_guard':'observed game compiler forms rejected in CI; negative controls included; not a game-cache compiler',
  'actual_game_validation':False,
  'files':{p.relative_to(ROOT).as_posix():{'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'git_blob':blob(p.read_bytes())} for p in paths}}
 (ROOT/'releases/NCPD_Patrol_v0.16d_verification.json').write_text(json.dumps(report,indent=2)+'\n')
 print(json.dumps({k:v for k,v in report.items() if k!='files'},indent=2))
if __name__=='__main__':main()
