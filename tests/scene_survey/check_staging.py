"""Bounded production-style placement, then independent stability/readback proof."""
from pathlib import Path
import argparse,json,sys
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
sys.path.insert(0,str(HERE))
from check_survey import case,results
PROFILE='injured-staging-pilot-v1'
MOD=ROOT/'bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrol'
KICK='''local s=SurveyFixture;local tour=require('scene_survey')
 s.onCreate=function(a)
  a.initial={x=a.pos.x,y=a.pos.y,z=a.pos.z}
  a.spawnYaw=F.creates[#F.creates].orientation.Yaw
 end
 s.onTick=function()
  for _,a in ipairs(s.allActors) do
   if a.attached and a.record=='Character.NCPDPatrol_OD_Injured' and a.down and not a.kicked then
    a.kicked=true
    local angle=math.rad(a.spawnYaw+(a.id.hash%3)*90)
    a.pos=Vector4.new(a.initial.x-math.sin(angle)*1.8,a.initial.y+math.cos(angle)*1.8,a.initial.z,1)
   end
  end
 end
'''
def main():
 def inspect_ok(lua):
  rows=results();sites=[r for r in rows if r['kind']=='site_result']
  assert [r['site'] for r in sites]==['kryss_04','kryss_11','kryss_15']
  assert all(r['status']=='validated' and r['validation_profile']==PROFILE for r in sites)
  assert all(r['placement_corrections']==1 and r['placement_release_seconds']==.5 for r in sites)
  assert all(r['observed_seconds']>=3 and r['maximum_observation_drift']<=.15 for r in sites)
  frames=[r for r in rows if r['kind']=='injured_motion_sample']
  requests=[r for r in frames if r.get('correction_requested')]
  assert len(requests)==3 and all(r['phase']=='staging' and r['injured']['displacement']>1.5 for r in requests)
  assert all(r['correction_target']==r['injured']['expected'] for r in requests)
  assert all(not r.get('correction_requested') and not r['corrections_enabled'] for r in frames if r['phase'] in ['placement-release','observing'])
  assert all(r['injured']['displacement']<=1.5 and r['ground']['static_clear'] and r['ground']['vehicle_clear'] for r in frames if r['phase']=='observing')
  report=json.loads(Path('scene_survey_report.json').read_text())
  assert sum(bool(r['injured_placement_pilot_proven']) for r in report['sites'])==3
  assert all(not r['proven'] and not r['injured_settling_pilot_proven'] for r in report['sites'])
  assert lua.globals().SF.actorTeleports==3 and len(lua.globals().F.creates)==30
 case(KICK+'''assert(tour.startPlacementPilot());s.untilIdle(250)
 assert(tour.summary():find('placement pilot=3/3',1,true))
 assert(s.actorTeleports==3);s.assertNoGameplay(true);assert(tour.export())''',inspect_ok)
 # The same fixed post-animation offset still fails the passive pilot. Merely
 # waiting does not make the following negative control pass.
 def inspect_old(lua):
  sites=[r for r in results() if r['kind']=='site_result']
  assert len(sites)==3 and all(r['status']=='unverified' for r in sites)
 case(KICK+'''assert(tour.startPilot());s.untilIdle(400);s.assertNoGameplay()''',inspect_old)
 # Return true from native Teleport while its engine boundary ignores the
 # request. Position readback, not a successful call, must reject the scene.
 def inspect_failed(lua):
  rows=results();sites=[r for r in rows if r['kind']=='site_result']
  assert len(sites)==3 and all(r['status']=='unverified' for r in sites)
  assert any(r['kind']=='injured_motion_sample' and r.get('failure')=='Injured placement did not hold after staging; site geometry remains unverified' for r in rows)
 case(KICK+'''s.ignoreActorTeleports=true;assert(tour.startPlacementPilot());s.untilIdle(450)
 assert(s.actorTeleports>0);s.assertNoGameplay(true)''',inspect_failed)
 # Real continued drift is not held in place during final observation.
 continuous=KICK.replace('and not a.kicked then','then')
 case(continuous+'''assert(tour.startPlacementPilot());s.untilIdle(450)
 assert(s.actorTeleports>0);s.assertNoGameplay(true)''',inspect_failed)
 # Even 0.2 m of drift while still inside the original 1.5 m radius fails.
 def inspect_drift(lua):
  assert any(r['kind']=='injured_motion_sample' and r.get('failure')=='Actor not stable after settling: injured' for r in results())
 case('''local s=SurveyFixture;local tour=require('scene_survey');local ticks=0
 s.onTick=function()
  if tour.diagnostics():find('Phase: observing |',1,true) then
   ticks=ticks+1
   if ticks==3 then local a=s.allActors[4];a.pos=Vector4.new(a.pos.x+.2,a.pos.y,a.pos.z,1) end
  end
 end
 assert(tour.startPlacementPilot());s.untilIdle(250);s.assertNoGameplay(true)''',inspect_drift)
 # Local target obstruction/support failures are rejected before correction.
 for flag,enable,disable,reason in [
  ('static','s.obstruction=true','s.obstruction=false','Injured final local Static clearance blocked'),
  ('vehicle','s.injuredVehicleBlocked=true','s.injuredVehicleBlocked=false','Injured final local Vehicle clearance blocked'),
  ('ground','s.noGround.kryss_04=true','s.noGround.kryss_04=nil','Injured ground support not confirmed')]:
  script=KICK.replace('s.onTick=function()','s.onTick=function()\n if tour.diagnostics():find("Phase: staging |",1,true) then '+enable+' else '+disable+' end',1)
  def inspect_target(lua,reason=reason):
   rows=results();assert any(r['kind']=='injured_motion_sample' and r.get('failure')=='Injured placement target unsafe: '+reason for r in rows)
   # No unsafe request at Kryss_04; the other two sites may later be valid.
   requests=[r for r in rows if r['kind']=='injured_motion_sample' and r.get('correction_requested')]
   if reason=='Injured ground support not confirmed':assert all(r['site']!='kryss_04' for r in requests)
   else:assert not requests
  case(script+'''assert(tour.startPlacementPilot());s.untilIdle(450);s.assertNoGameplay(true)''',inspect_target)
 # Other actors retain the original strict displacement bound during staging.
 def inspect_car(lua):assert any(r['kind']=='injured_motion_sample' and r.get('failure')=='Actor displaced: police' for r in results())
 case('''local s=SurveyFixture;local tour=require('scene_survey');local injected=false
 s.onTick=function()
  if not injected and tour.diagnostics():find('Phase: staging |',1,true) then
   injected=true;local a=s.allActors[1];a.pos=Vector4.new(a.pos.x+2,a.pos.y,a.pos.z,1)
  end
 end
 assert(tour.startPlacementPilot());s.untilIdle(250);s.assertNoGameplay(true)''',inspect_car)
 # Native ownership and phase guards execute from the actual REDscript body.
 case('''local s=SurveyFixture;local tour=require('scene_survey')
 assert(tour.startPlacementPilot());s.untilPhase('staging',30)
 local a=s.allActors[4];local p=Vector4.new(a.pos.x,a.pos.y,a.pos.z,1);local count=s.actorTeleports
 assert(not SurveyNative:LockPosition(s.allActors[1],p,0))
 assert(not SurveyNative:LockPosition(F.objects[999],p,0))
 assert(not SurveyNative:LockPosition(a,Vector4.new(p.x+2,p.y,p.z,1),0))
 assert(not SurveyNative:LockPosition(a,p,0/0))
 assert(s.actorTeleports==count)
 s.untilPhase('placement-release',20)
 assert(not SurveyNative:LockPosition(a,p,0));assert(s.actorTeleports==count)
 assert(tour.cancel());s.untilIdle(40);s.assertNoGameplay(true)''')
 # Active clock / no teleport on paused menu or unready world. Cancellation,
 # disk failure and a CET reload retain strict physical cleanup before return.
 case(KICK+'''assert(tour.startPlacementPilot());s.untilPhase('staging',30);s.step(.5)
 local before=tour.diagnostics();local moves=s.actorTeleports
 F.menu=true;s.step(10);assert(tour.diagnostics()==before and s.actorTeleports==moves)
 F.menu=false;F.ready=false;s.step(10);assert(tour.diagnostics()==before and s.actorTeleports==moves)
 F.ready=true;assert(tour.cancel());s.untilIdle(40);assert(s.live()==0);s.assertNoGameplay(true)''')
 case(KICK+'''assert(tour.startPlacementPilot());s.untilPhase('staging',30);s.failFile=true;s.untilIdle(60)
 assert(s.live()==0 and not SurveyNative:IsActive());s.assertNoGameplay(true)''')
 case(KICK+'''assert(tour.startPlacementPilot());s.untilPhase('staging',30);s.step(.5);tour.shutdown()
 package.loaded.scene_survey=nil;package.loaded.scene_survey_store=nil
 tour=require('scene_survey');s.use(tour);assert(tour.recover());s.untilIdle(40)
 assert(s.live()==0 and not SurveyNative:IsActive());s.assertNoGameplay(true)''')
 # A stale native module refuses this pilot before reservation/spawning.
 case('''local s=SurveyFixture;local tour=require('scene_survey');SurveyNative.PlacementVersion=nil
 assert(not tour.startPlacementPilot());assert(not SurveyNative:IsActive() and #F.creates==0)
 assert(tour.summary():find('Install the complete v0.18b2',1,true))''')
 # All three evidence profiles survive export/reload and stay separate.
 case('''local s=SurveyFixture;local tour=require('scene_survey')
 assert(tour.start('compact',false));s.untilIdle(650)
 assert(tour.startPilot());s.untilIdle(250)
 assert(tour.startPlacementPilot());s.untilIdle(250)
 package.loaded.scene_survey=nil;package.loaded.scene_survey_store=nil
 tour=require('scene_survey');s.use(tour);assert(tour.loadResults())
 assert(tour.summary():find('proven compact=17/17',1,true))
 assert(tour.summary():find('settling pilot=3/3',1,true) and tour.summary():find('placement pilot=3/3',1,true))
 assert(not tour.start('compact',true));assert(tour.export());s.assertNoGameplay(true)''')
 sys.path.insert(0,str(HERE.parent/'cet_ui'));from check_cet_ui import runtime as ui_runtime
 _,f=ui_runtime(MOD);f.Frame(f,'Testing','TEST: Injured placement pilot (3 sites)')
 assert f.clicks==1 and 'survey.startPlacementPilot' in f.Events(f)
 print('PASS: three-site injured placement pilot; production-style bounded correction, target support/clearance, native ownership/phase guards, correction disabled before release and final observation, actual position readback, unchanged 1.5 m bound and 0.15 m stability, continued drift/ignored teleport rejected, independent legacy/passive/placement evidence, paused clocks and cancel/disk/CET recovery (engine boundaries mocked)')
 return {'profile':PROFILE,'pilot_sites':['kryss_04','kryss_11','kryss_15'],'staging_active_seconds':4,
  'uncorrected_release_seconds':.5,'uncorrected_observation_seconds':3,'final_original_position_limit_m':1.5,
  'observation_anchor_drift_m':.15,'native_corrects_only_owned_injured_during_staging':True,
  'continued_drift_and_ignored_teleport_rejected':True,'target_static_ground_and_vehicle_clearance_required':True,
  'three_evidence_profiles_kept_separate':True,'legacy_manual_scene_and_arrest_policy_preserved':True,'actual_game_validation':False}
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--report',type=Path);a=p.parse_args();r=main()
 if a.report:a.report.write_text(json.dumps(r,indent=2)+'\n')
