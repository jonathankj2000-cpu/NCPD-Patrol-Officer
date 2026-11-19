"""Verify adaptive VIP routes, convoy ownership and arrest notices; package the full mod."""
from pathlib import Path
import hashlib,json,os,subprocess,sys,zipfile
ROOT=Path(__file__).resolve().parents[1]
BASE='6ea9949fa4c1b4ba6c03bd22713a2a1001079999'
NAME='NCPD_Patrol_v0.16e_VIP_Convoy_Arrest_Notices_TEST.zip'
def run(*args):subprocess.run([*map(str,args)],cwd=ROOT,check=True)
def blob(data):return hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()
def main():
 from lupa.luajit21 import LuaRuntime
 lua=LuaRuntime();modules=sorted((ROOT/'bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrol').glob('*.lua'))
 scripts=sorted((ROOT/'r6/scripts/NCPDPatrol').glob('*.reds'))
 assert len(modules)==18 and len(scripts)==27
 for p in modules:lua.eval('function(p) local f,e=loadfile(p);assert(f,e) end')(str(p))
 tests=['tests/beanbagger/check_visuals.py','tests/beanbagger/check_beanbagger.py','tests/shift_entry/check_shift.py','tests/compile_compatibility/check_legacy_api.py','tests/arrests/check_arrest.py','tests/arrests/check_arrest_interactions.py','tests/trunk_menu/check_trunk.py',
  'tests/dispatch_journal/check_journal.py','tests/career/check_career.py','tests/cyberpsycho/check_cyberpsycho.py',
  'tests/vip/check_vip.py','tests/officer_readiness/check_ready.py']
 for test in tests:run(sys.executable,ROOT/test)
 prefix='bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrol/'
 changed={prefix+name for name in ['init.lua','arrest.lua','vip.lua','vip_ambush.lua','dispatch.lua']}
 changed|={'r6/scripts/NCPDPatrol/NCPDPatrolVIPSystem.reds','archive/pc/mod/NCPDPatrol_VIP.archive'}
 added={prefix+'vip_ambush_unit.lua'}
 original=subprocess.check_output(['git','ls-tree','-r','--name-only',BASE,'--','bin','r6','archive'],cwd=ROOT,text=True).splitlines()
 run('git','diff','--exit-code',BASE,'--','LICENSE',*[path for path in original if path not in changed])
 paths=[]
 for dirname in ['bin','r6','archive']:paths.extend(p for p in (ROOT/dirname).rglob('*') if p.is_file())
 paths.extend(ROOT/name for name in ['LICENSE','README.txt'])
 assert {p.relative_to(ROOT).as_posix() for p in paths}==set(original)|added|{'LICENSE','README.txt'} and len(paths)==65
 release=ROOT/'releases'/NAME;release.parent.mkdir(exist_ok=True)
 with zipfile.ZipFile(release,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=9) as z:
  for path in sorted(paths):
   info=zipfile.ZipInfo(path.relative_to(ROOT).as_posix(),(2026,11,19,0,0,0));info.compress_type=zipfile.ZIP_DEFLATED
   info.create_system=3;info.external_attr=0o100644<<16;z.writestr(info,path.read_bytes(),compresslevel=9)
 with zipfile.ZipFile(release) as z:
  assert z.testzip() is None and set(z.namelist())=={p.relative_to(ROOT).as_posix() for p in paths}
  for path in paths:assert z.read(path.relative_to(ROOT).as_posix())==path.read_bytes()
 data=release.read_bytes()
 report={'version':'v0.16e','source_commit':os.environ.get('GITHUB_SHA'),'base_commit':BASE,
  'install_files':len(paths),'lua_modules_parsed':len(modules),'redscript_files':len(scripts),'portable_tests':tests,
  'zip_path':release.relative_to(ROOT).as_posix(),'zip_bytes':len(data),'zip_sha256':hashlib.sha256(data).hexdigest(),'zip_git_blob':blob(data),
  'native_arrest_interface':6,'native_trunk_interface':4,'native_officer_equipment_interface':1,'native_cyberpsycho_interface':3,'native_vip_interface':3,
  'trunk_menu':'native R hold opens Codeware blocking popup; two rows of four cards; independent 1-7 and 9 actions; numpad/mouse; scoped lifecycle',
  'active_backup':'explicit follow commands replace permanent scene hold; boarding priority; existing 10-4 retains scene and reservation',
  'readiness':'verify actual held slots; stalled command falls back to native equip/unequip with existing tagged-officer inventory; native combat priority',
  'codeware_api_source':'v1.21.4 / 6dfdbceff7882d8ad8632ab1ff8d42bcef20a8ad',
  'archives_changed':['NCPDPatrol_VIP.archive'],'other_archives_unchanged':True,'redscript_changed':['NCPDPatrolVIPSystem.reds'],'weapon_readiness_rules_unchanged':True,'cyberpsycho_pool_and_tweaks_unchanged':True,
  'aftermath_rules_and_tyre_repair_unchanged':True,'scanner_arrest_and_dispatch_payments_unchanged':True,
  'shift_entry_fix_included':True,
  'arrest_recovery':{'living_ragdolls':True,'max_displacement_metres':2,'max_height_change_metres':0.75,'navigation_and_static_collision_footprint_checked':True,'prefer_flatter_nearby_ground':True,'native_workspot_ground_alignment':True,'position_check_after_native_activation':True,'life_health_and_defeat_unchanged':True,'native_physics_ownership_released_on_cleanup':True,'native_pickup_handoff':True,'native_R_pickup_preserved_before_arrest_and_after_failure':True,'payment_requires_existing_activation_proof':True},
  'arrest_notices':{'player_notice':'Move the suspect to flat, clear ground and try again.','technical_errors_logged_only':True,'fresh_ground_checks':True,'ground_retry_seconds_at_most':2,'navigation_probe_radius_metres':0.9,'displacement_and_surface_limits_unchanged':True,'rejection_counters_in_log':True,'no_fixed_20_second_cooldown':True},
  'vip_locations':{'fast_travel_interaction_availability_ignored':True,'drop_point_fallback':True,'fast_travel_discovery_unchanged':True,'preferred_pickup_metres':[500,2000],'fallback_pickup_metres':[250,5000],'preferred_trip_metres':[800,2500],'fallback_trip_metres':[500,5000],'response_deadline_seconds':[300,600],'unfinished_scanner_clearance_metres':100,'distance_buckets_and_nearest_clear_in_diagnostics':True,'arrival_navigation_check_retained':True,'journal_briefing_updated_for_adaptive_deadline':True},
  'ambush_road_placement':{'recent_driven_route_distance_metres':[35,65],'sample_seconds':0.25,'static_surface_and_vehicle_footprint_checked':True,'swept_corridor_barrier_checks':True,'actual_car_position_checked_before_crew_and_chase':True,'crew_spawn_within_checked_car_footprint':True,'mount_as_each_actor_attaches':True,'max_spawn_attempts_per_car':3,'cleanup_confirmed_before_retry':True,'warning_after_actual_mount_and_placement':True},
  'ambush_convoy':{'cars':[1,3],'crew_per_car':2,'default':'random 1-3','cet_fixed_choices':[1,2,3],'minimum_separation_metres':12,'pending_car_window_seconds':20,'independent_commands_and_cleanup':True,'single_warning':True,'one_convoy_per_transport':True,'unsafe_extra_cars_can_be_skipped':True},
  'cyberpsycho_dispatch':{'vehicle_interaction_availability_ignored':True,'completed_call_releases_dispatch':True,'retained_scenes_max':3,'scene_cleanup_seconds':120,'scene_cleanup_distance_metres':150,'old_scene_cleanup_cannot_clear_new_waypoint_or_journal':True},
  'bean_bagger':{'inventory_icon':'weapon_Preset_Tactician_Default_None__Default','id':'Items.NCPDBeanBagger_M2038','tier':2,'milestone':20,'damage_multiplier':0.9,'native_interface':1,'scope':'V ranged human hits; existing native defeat mechanic','downed_hit_damage':0,'test_button':True,'old_receipts_preserved':True,'partner_loadouts_unchanged':True,'stock_visuals':False,'private_factory':'NCPDPatrol_BeanBagger','blue_parts':['pistol grip','pump fore-end'],'color_srgb':'#28567D','first_and_third_person_masks':True,'geometry_and_animations_preserved':True,'runtime_localization':'existing Codeware provider'},
  'compatibility_guard':'observed game compiler forms rejected in CI; negative controls included; not a game-cache compiler',
  'actual_game_validation':False,
  'files':{p.relative_to(ROOT).as_posix():{'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'git_blob':blob(p.read_bytes())} for p in paths}}
 (ROOT/'releases/NCPD_Patrol_v0.16e_verification.json').write_text(json.dumps(report,indent=2)+'\n')
 print(json.dumps({k:v for k,v in report.items() if k!='files'},indent=2))
if __name__=='__main__':main()
