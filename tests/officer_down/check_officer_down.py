"""Execute actual native quest/aid/marker/reward code and CET scene lifecycle."""
from pathlib import Path
from tempfile import TemporaryDirectory
import argparse,hashlib,importlib.util,json,subprocess,sys
from lupa.luajit21 import LuaRuntime
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
sys.path.insert(0,str(HERE.parent/'arrests'));from translate import translate
sys.path.insert(0,str(HERE.parent/'fixed_markers'));from check_fixed import journal_hash
MOD=ROOT/'bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrol'
LAYOUT_BASE='14d22d3ef13259d23438bb942fb66541117d06ab'

def check_layout_boundaries(lua):
 # The game's raycast result is Vector3, while character navigation requires
 # Vector4. Reproduce the reported failure with the exact previous layout.
 old=subprocess.check_output(['git','show',f'{LAYOUT_BASE}:{MOD.relative_to(ROOT).as_posix()}/officer_down_layout.lua'],cwd=ROOT,text=True)
 lua.globals().OldLayout=lua.execute(old)
 # Isolate the old +0.7 m probe from the separate native argument type bug.
 assert old.count('return result.position')==1
 typed=old.replace('return result.position','return Vector4.new(result.position.x,result.position.y,result.position.z,1)')
 lua.globals().TypedOldLayout=lua.execute(typed)
 lua.execute('''local f=F
 f:Reset()
 local ok,err=pcall(OldLayout.build,90,f.player)
 assert(not ok and tostring(err):find('parameter 1 must be Vector4',1,true),tostring(err))
 f:Reset();f.surfaceOffset=1.1
 ok,err=pcall(TypedOldLayout.build,0,f.player)
 assert(not ok and tostring(err):find('Unsupported scene ground at police',1,true),tostring(err))
 local layout=require('officer_down_layout')
 for _,heading in ipairs({0,90,180,270}) do
  for _,offset in ipairs({-1.1,0,1.1}) do
   f:Reset();f.surfaceOffset=offset
   local rows=layout.build(heading,f.player)
   assert(#rows==10 and f.navQueries==7,'Valid scene did not reach all seven typed navigation calls')
   for _,row in ipairs(rows) do assert(row.position.__vector=='Vector4' and row.position.w==1) end
  end
 end
 local cases={
  {'noGround',true,'no Static surface hit'},
  {'lowerFloor',true,'no Static surface hit'},
  {'surfaceOffset',1.4,'maximum=1.300 m'},
  {'surfaceOffset',-1.4,'maximum=1.300 m'},
  {'normalZ',.6,'surface normal Z=0.600'},
  {'surfaceOffsetAt',function(p) local s=require('officer_down_scene');return math.abs(p.x-s.x)>.5 and .5 or 0 end,'corner height delta=0.500 m'},
 }
 for _,case in ipairs(cases) do
  f:Reset();f[case[1]]=case[2]
  ok,err=pcall(layout.build,0,f.player)
  assert(not ok and tostring(err):find(case[3],1,true),tostring(err))
  if case[1]~='surfaceOffsetAt' then
   assert(tostring(err):find('heading=0',1,true) and tostring(err):find('probe=',1,true),tostring(err))
  end
  assert(f.navQueries==0,'Invalid car support reached NPC navigation')
 end
 f:Reset()''')
 return {'raycast_hit_type':'Vector3','navigation_argument_type':'Vector4',
 'previous_layout_reproduces_reported_type_error':True,'previous_probe_rejects_supported_uphill_ground':True,
 'accepted_heading_height_combinations':12,'rejected_support_cases':6,
 'height_normal_footprint_and_road_level_limits_preserved':True}

def code(path):
 s=translate(path)
 s=s.replace('new NCPDPatrolSceneMarker()','NewSceneMarker()').replace('new gameJournalPath()','NewJournalPath()').replace('new questMappinManagerNodeDefinition()','NewManagerNode()')
 for name in ['Objective','Phase','Root']:
  s=s.replace('self:'+name+'() + ','self:'+name+'() .. ')
 s=s.replace('NCPDPatrolOfficerDownCatalog:Root(i) + ','NCPDPatrolOfficerDownCatalog:Root(i) .. ')
 s=s.replace('pin = pins[i]','pin = AsQuestMappin(pins[i])')
 s=s.replace('known = map:GetQuestMappinPosition(self.m_hash, point)','known, point = map:GetQuestMappinPosition(self.m_hash)')
 for name in ['point','world']:s=s.replace('local '+name+' = nil','local '+name+' = Vector4.new(0,0,0,0)')
 s=s.replace('local linkedID = {}','local linkedID = {value=0}').replace('local rotation = nil','local rotation = {Roll=0,Pitch=0,Yaw=0}')
 return s

def engine_runtime():
 lua=LuaRuntime(unpack_returned_tuples=True);lua.globals().PathHash=journal_hash;lua.globals().MOD_DIR=str(MOD)
 lua.execute('package.path=MOD_DIR.."/?.lua;"..package.path;math.randomseed(20261120)')
 lua.globals().SceneMarker=lua.execute(code(ROOT/'r6/scripts/NCPDPatrol/NCPDPatrolSceneMarker.reds'))
 lua.globals().NCPDPatrolAidAccess=lua.execute(code(ROOT/'r6/scripts/NCPDPatrol/NCPDPatrolAidAccess.reds'))
 lua.globals().OfficerNative=lua.execute(code(ROOT/'r6/scripts/NCPDPatrol/NCPDPatrolOfficerDownSystem.reds'))
 lua.globals().SiteNative=lua.execute(code(ROOT/'r6/scripts/NCPDPatrol/NCPDPatrolOfficerDownSite.reds'))
 lua.globals().IncidentNative=lua.execute(code(ROOT/'r6/scripts/NCPDPatrol/NCPDPatrolIncidentSystem.reds'))
 # Execute the actual shared journal write helper, not a second implementation.
 source=(ROOT/'r6/scripts/NCPDPatrol/NCPDPatrolFixedMarkerSystem.reds').read_text();start=source.index('    public static func WriteNavigationState(');end=source.index('    // Called by',start)
 with TemporaryDirectory(prefix='ncpd-scene-writer-') as temp:
  p=Path(temp)/'writer.reds';p.write_text('public class Writer extends IScriptable {\n'+source[start:end]+'\n}')
  lua.globals().NCPDPatrolFixedMarkerSystem=lua.execute(translate(p))
 lua.execute((HERE/'engine.lua').read_text())
 return lua

def main():
 spec=importlib.util.spec_from_file_location('officer_assets',ROOT/'tools/build_officer_down_assets.py');builder=importlib.util.module_from_spec(spec);spec.loader.exec_module(builder)
 for name,body in builder.outputs().items():assert (ROOT/name).read_text()==body,name
 builder.validate(json.loads((ROOT/'assets/officer_down/officer_down.journal.json').read_text()),json.loads((ROOT/'assets/officer_down/officer_down_onscreens.json.json').read_text()))
 manifest=json.loads((ROOT/'assets/officer_down/compiled.json').read_text())
 marker_source=(ROOT/'r6/scripts/NCPDPatrol/NCPDPatrolSceneMarker.reds').read_text()
 for forbidden in ['UnregisterMappin','TrackMappin','SetMappinPosition','CustomPositionVariant','GiveItem']:
  assert forbidden not in marker_source,forbidden
 own_hash=journal_hash('quests/minor_quest/ncpd_patrol_officer_down/main/assist/location')
 for scope in range(10):
  root=('ncpd_patrol_dispatch'+('' if scope==0 else '_'+str(scope))) if scope<6 else ('ncpd_patrol_cyberpsycho' if scope<8 else 'ncpd_patrol_vip')
  obj='resolve' if scope<6 else ['respond','neutralize','pickup','deliver'][scope-6]
  for site in (range(1,133) if scope<6 else range(133,324)):
   for suffix in [f'{obj}_bank_{site}/location',f'{obj}/bank_{site}']:
    assert own_hash!=journal_hash('quests/minor_quest/'+root+'/main/'+suffix),'Scene/bank ownership hash collision'
 assert hashlib.sha256((ROOT/manifest['archive_path']).read_bytes()).hexdigest()==manifest['archive_sha256']
 for path,sha in manifest['authored_inputs'].items():assert hashlib.sha256((ROOT/path).read_bytes()).hexdigest()==sha,path
 assert manifest['roundtrip_validated'] and manifest['extracted_resource_bytes_compared']
 lua=engine_runtime()
 layout_checks=check_layout_boundaries(lua)
 lua.execute((HERE/'placement_scenarios.lua').read_text())
 lua.execute((HERE/'scenarios.lua').read_text())
 # New UI controls must route once; historical UI suite covers retained actions.
 sys.path.insert(0,str(HERE.parent/'cet_ui'));from check_cet_ui import runtime
 ui,f=runtime(MOD,True)
 ui.execute('''local d=package.loaded.dispatch;local f=UIFixture
 for _,name in ipairs({'requestOfficerDown','rotateOfficerDown','reviveOfficerDown','clearOfficerDown'}) do
   d[name]=function() f.sceneAction=name end
 end
 d.officerDownState=function() return 'scene fixture' end
 d.officerDownDiagnostics=function() return 'native scene diagnostics' end''')
 for label,tab,action in [('Revive scene officer (nearby)','Testing','reviveOfficerDown'),('Clear Officer Down scene','Diagnostics','clearOfficerDown')]:
  f.sceneAction=None;f.Frame(f,tab,label);assert f.sceneAction==action and f.clicks==1,label
 f.ClearEvents(f);f.Frame(f,'Diagnostics','Log Officer Down diagnostics');assert 'native scene diagnostics' in f.Events(f)
 # Old fixed-site requests and manual-waypoint creation are no longer reachable
 # from any tab. Their backend lifecycle coverage above is intentionally kept.
 for label in ['TEST: Request Officer Down','TEST: Rotate Officer Down scene 90 degrees','TEST: Waypoint to Officer Down intersection']:
  for tab in ['Patrol','Dispatch','Career','Settings','Diagnostics','Testing']:
   f.ClearEvents(f);f.Frame(f,tab,label);assert f.clicks==0 and f.Events(f)=='',label
 report={'manual_fixed_scene':True,'position':json.loads((ROOT/'assets/officer_down/scene.json').read_text())['position'],
 'cars':3,'officers':2,'gang_members':5,'arrival_metres':50,'prepare_metres':250,
 'production_layout':'compact','compact_line_gap_metres':12,'gang_lateral_offset_metres':5.5,'gang_center_gap_metres':11,
 'automatic_rotation_order':[0,90,180,270],'manual_preferred_heading_retained':True,
 'vehicle_overlap_queries_typed':True,'all_ten_positions_checked_before_creation':True,
 'prepare_near_metres':180,'prepare_interval_seconds':1,'prepare_near_grace_seconds':8,
 'early_missing_ground_retry_on_approach':True,'placement_grace_pauses_with_menus_and_unready_session':True,
 'unexpected_engine_errors_not_retried_as_geometry':True,'no_rotation_after_partial_creation':True,
 'prearrival_protection_and_position_lock':True,'actual_native_aid_and_dual_completion':True,
 'existing_partner_identity_untouched':True,'reward':2000,'one_career_incident':True,
 'dispatch_manual_waypoint_preserved':True,'native_marker_never_unregistered':True,
 'retired_fixed_scene_and_locator_launchers_absent':True,
 'partial_refused_and_delayed_cleanup':True,'automatic_weights_unchanged':True,
 'typed_ground_and_probe_regressions':layout_checks,
 'ui_controls_routed':3,'actual_game_rendering_combat_traffic_and_layout_validation':False}
 print('PASS: Officer Down automatic 0/90/180/270 selection, typed Vehicle overlap on all ten positions, 250 m early preparation, bounded/paused near retry, no rotation after creation or API-error masking; Vector3 raycast / Vector4 navigation regression reproduces the previous type error; ground/slope/footprint limits, actual Lua/native quest, staging protection, aid/dual completion, EUR$2000 once, cleanup/dispatch reservation, world reset/manual waypoint, three current CET routes and retired-launcher absence (engine boundaries mocked)')
 return report
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--report',type=Path);a=p.parse_args();r=main()
 if a.report:a.report.write_text(json.dumps(r,indent=2)+'\n')
