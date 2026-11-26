"""Default full-tour validation follows injured usability, not spawn precision."""
from pathlib import Path
import argparse,json,sys
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
sys.path.insert(0,str(HERE))
from check_survey import case,results
PROFILE='injured-functional-v1'
KICK='''local s=SurveyFixture;local tour=require('scene_survey')
 s.onCreate=function(a) a.initial={x=a.pos.x,y=a.pos.y,z=a.pos.z} end
 s.onTick=function()
  for _,a in ipairs(s.allActors) do
   if a.attached and a.record=='Character.NCPDPatrol_OD_Injured' and a.down and not a.kicked then
    a.kicked=true;local angle=(a.id.hash%8)*math.pi/4
    a.pos=Vector4.new(a.initial.x+math.cos(angle)*4,a.initial.y+math.sin(angle)*4,a.initial.z,1)
   end
  end
 end
'''
def main():
 def inspect_full(lua):
  rows=results();sites=[r for r in rows if r['kind']=='site_result']
  assert len(sites)==17 and all(r['status']=='validated' and r['validation_profile']==PROFILE for r in sites)
  for r in sites:
   injured=next(s for s in r['samples'] if s['kind']=='injured');p=r['functional_validation']
   assert abs(injured['displacement']-4)<.00001
   assert p['path_confirmed'] and p['ground_supported'] and p['aid_state_ready']
   assert p['ready_seconds']>=3 and p['aid_distance']<=2.5 and p['scene_distance']<=25
   assert p['revive_executed'] is False and r['observed_seconds']>=3
  assert lua.globals().SF.actorTeleports==0 and len(lua.globals().F.creates)==170
  report=json.loads(Path('scene_survey_report.json').read_text())
  assert report['default_validation_profile']==PROFILE
  assert sum(bool(s['injured_functional_proven']) for s in report['sites'])==17
  assert sum(bool(s['proven']) for s in report['sites'])==17
  assert report['primary_validation_profile']==PROFILE and all(not s['legacy_proven'] for s in report['sites'])
 case(KICK+'''assert(tour.startFunctional('compact',false));s.untilIdle(950)
 assert(tour.summary():find('functional compact=17/17',1,true))
 assert(not tour.startFunctional('compact',true));assert(tour.export());s.assertNoGameplay()''',inspect_full)
 # Repeated 0.7 m root motion remains acceptable if one actual aid position
 # remains in reach/clear/connected. The old 0.15 m anchor is not an acceptance rule.
 def inspect_motion(lua):
  rows=results();sites=[r for r in rows if r['kind']=='site_result']
  assert len(sites)==17 and all(r['status']=='validated' for r in sites)
  frames=[r for r in rows if r['kind']=='injured_motion_sample' and r['phase']=='functional-observing']
  assert any(r['step_distance']>.6 and r['functionally_ready'] for r in frames)
 case('''local s=SurveyFixture;local tour=require('scene_survey')
 s.onCreate=function(a) a.initial={x=a.pos.x,y=a.pos.y,z=a.pos.z} end
 s.onTick=function()
  for _,a in ipairs(s.allActors) do
   if a.attached and a.down then
    local d=math.floor(s.time*4)%2==0 and .35 or -.35
    a.pos=Vector4.new(a.initial.x+d,a.initial.y,a.initial.z,1)
   end
  end
 end
 assert(tour.startFunctional('compact',false));s.untilIdle(950);s.assertNoGameplay()''',inspect_motion)
 # Functional failures are bounded/retried and report their actual cause.
 negative=[
  ('s.noGround.test_kryss_01=true','No supported ground at injured officer'),
  ('s.obstruction=true','Injured officer overlaps local Static geometry'),
  ('s.injuredVehicleBlocked=true','Injured officer overlaps a vehicle'),
  ('s.aidWallBlocked=true','Wall blocks access to injured officer'),
  ('s.aidStandingBlocked=true','Aid standing position occupied by a vehicle'),
  ('s.aidCorridorBlocked=true','Vehicle blocks access to injured officer'),
  ('s.noNav.test_kryss_01=true','No aid position within interaction range'),
  ('s.noAidPath=true','No complete walking route to injured officer'),
  ('s.partialAidPath=true','No complete walking route to injured officer'),
  ('s.partialAidStart=true','No complete walking route to injured officer'),
  ("StatusEffectHelper:RemoveStatusEffect(s.allActors[4],'BaseStatusEffect.NCPDPatrolOfficerDown')",'Injured officer is not ready for aid'),
 ]
 for inject,reason in negative:
  def inspect_bad(lua,reason=reason):
   rows=results();assert any(r['kind']=='trial_failed' and r['reason']==reason for r in rows),[(r['kind'],r.get('reason')) for r in rows[-4:]]
   assert not any(r['kind']=='site_result' and r['status']=='validated' for r in rows)
  case('''local s=SurveyFixture;local tour=require('scene_survey')
 assert(tour.startFunctional('compact',false));s.untilPhase('functional-observing',30)
 '''+inject+'''
 s.untilPhase('cleanup',20)
 s.noGround={};s.noNav={};s.obstruction=false;s.injuredVehicleBlocked=false;s.aidWallBlocked=false
 s.aidStandingBlocked=false;s.aidCorridorBlocked=false;s.noAidPath=false;s.partialAidPath=false;s.partialAidStart=false
 assert(tour.cancel());s.untilIdle(40);s.assertNoGameplay()''',inspect_bad)
 # Below-floor, absent/dead/escaped actors and non-injured displacement retain
 # rejection. No global tolerance change is smuggled in with the new profile.
 immediate=[
  ('local a=s.allActors[4];a.pos=Vector4.new(a.pos.x,a.pos.y,a.pos.z-.5,1)','Injured officer below ground'),
  ('local a=s.allActors[4];a.dead=true','Injured officer dead'),
  ('local a=s.allActors[4];a.attached=false','Actor missing/detached: injured'),
  ('local a=s.allActors[4];a.pos=Vector4.new(F.playerPoint.x+30,F.playerPoint.y,F.playerPoint.z,1)','Injured officer outside incident area'),
  ('local a=s.allActors[1];a.pos=Vector4.new(a.pos.x+2,a.pos.y,a.pos.z,1)','Actor displaced: police'),
 ]
 for inject,reason in immediate:
  def inspect_immediate(lua,reason=reason):assert any(r['kind']=='trial_failed' and r['reason']==reason for r in results())
  case('''local s=SurveyFixture;local tour=require('scene_survey')
 assert(tour.startFunctional('compact',false));s.untilPhase('functional-observing',30)
 '''+inject+'''
 s.untilPhase('cleanup',3);assert(tour.cancel());s.untilIdle(40);s.assertNoGameplay()''',inspect_immediate)
 # A single good frame or changing aid point does not claim a completed aid
 # window. Unready periods reset the timer, then a full usable window is needed.
 def inspect_reset(lua):
  rows=results();frames=[r for r in rows if r['kind']=='injured_motion_sample' and r['site']=='test_kryss_01' and r['phase']=='functional-observing']
  assert any(not r['functionally_ready'] and r['stable_seconds']==0 for r in frames)
  assert any(r['kind']=='site_result' and r['site']=='test_kryss_01' and r['status']=='validated' for r in rows)
 case('''local s=SurveyFixture;local tour=require('scene_survey')
 assert(tour.startFunctional('compact',false));s.untilPhase('functional-observing',30);s.step(1)
 s.noAidPath=true;s.step(.5);s.noAidPath=false;s.step(2)
 assert(tour.diagnostics():find('Phase: functional-observing |',1,true))
 s.untilPhase('between-sites',3);assert(tour.cancel());s.untilIdle(40);s.assertNoGameplay()''',inspect_reset)
 # Native access uses the exact created/protected injured actor; inactive/old
 # sessions and a nearby ambient actor cannot supply functional proof.
 case('''local s=SurveyFixture;local tour=require('scene_survey')
 assert(tour.startFunctional('compact',false));s.untilPhase('functional-observing',30)
 local a=s.allActors[4];assert(SurveyNative:IsInjuredAidReady(a))
 assert(not SurveyNative:IsInjuredAidReady(F.objects[999]))
 assert(not SurveyNative:HasInjuredAidPath(F.objects[999],a.pos))
 assert(not SurveyNative:HasInjuredAidPath(a,Vector4.new(a.pos.x+3,a.pos.y,a.pos.z,1)))
 assert(not SurveyNative:LockPosition(a,a.pos,0));assert(s.actorTeleports==0)
 assert(tour.cancel());s.untilIdle(40);s.assertNoGameplay()''')
 # Preserve paused clocks, disk/cancel cleanup, session invalidation and CET
 # recovery; functional validation does not bypass existing actor ownership.
 case(KICK+'''assert(tour.startFunctional('compact',false));s.untilPhase('functional-observing',30);s.step(1)
 local before=tour.diagnostics();local queries=s.pathQueries
 F.menu=true;s.step(10);assert(tour.diagnostics()==before and s.pathQueries==queries)
 F.menu=false;F.ready=false;s.step(10);assert(tour.diagnostics()==before and s.pathQueries==queries)
 F.ready=true;assert(tour.cancel());s.untilIdle(40);s.assertNoGameplay()''')
 case(KICK+'''assert(tour.startFunctional('compact',false));s.untilPhase('functional-observing',30)
 s.failFile=true;s.untilIdle(50);assert(s.live()==0 and not SurveyNative:IsActive());s.assertNoGameplay()''')
 case(KICK+'''assert(tour.startFunctional('compact',false));s.untilPhase('functional-observing',30)
 tour.shutdown();package.loaded.scene_survey=nil;package.loaded.scene_survey_store=nil
 tour=require('scene_survey');s.use(tour);assert(tour.recover());s.untilIdle(40);s.assertNoGameplay()''')
 case(KICK+'''assert(tour.startFunctional('compact',false));s.untilPhase('functional-observing',30)
 s.pathError=true;s.untilIdle(40);assert(s.live()==0);assert(tour.summary():find('Injected navigation API failure',1,true));s.assertNoGameplay()''')
 case('''local s=SurveyFixture;local tour=require('scene_survey');SurveyNative.FunctionalVersion=nil
 assert(not tour.startFunctional('compact',false));assert(#F.creates==0 and not SurveyNative:IsActive())
 assert(tour.summary():find('Install the complete v0.18b3',1,true))''')
 # Older successes remain available for heading preference but cannot skip
 # functional trials. All result profiles remain independent across reloads.
 case('''local s=SurveyFixture;local tour=require('scene_survey')
 assert(tour.start('compact',false));s.untilIdle(650)
 assert(tour.startFunctional('compact',true));s.untilIdle(950)
 assert(tour.startPilot());s.untilIdle(250);assert(tour.startPlacementPilot());s.untilIdle(250)
 package.loaded.scene_survey=nil;package.loaded.scene_survey_store=nil
 tour=require('scene_survey');s.use(tour);assert(tour.loadResults());assert(tour.export())
 assert(tour.summary():find('functional compact=17/17',1,true) and tour.summary():find('proven compact=17/17',1,true))
 assert(not tour.startFunctional('compact',true));s.assertNoGameplay()''')
 sys.path.insert(0,str(HERE.parent/'cet_ui'));from check_cet_ui import runtime as ui_runtime
 mod=ROOT/'bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrol'
 for label,event in [('TEST: Survey all recorded sites (compact)','survey.startFunctional|compact|false'),('TEST: Survey all recorded sites (standard)','survey.startFunctional|standard|false'),('TEST: Retry unverified survey sites','survey.startFunctional|compact|true')]:
  _,f=ui_runtime(mod);f.Frame(f,'Testing',label);assert f.clicks==1 and event in f.Events(f)
 print('PASS: default 17-site functional injured validation; safe 4 m landing offsets and 0.7 m motion accepted without corrections; supported/clear body and usable 2.5 m aid position for 3 s, complete native path endpoints; wall/vehicle/ground/isolated-nav/partial-path/down-state failures, scene bounds, strict other actors, paused/reset aid window, cleanup/CET recovery, old-native refusal and four isolated evidence profiles (engine boundaries mocked)')
 return {'profile':PROFILE,'default_full_tour':True,'injured_spawn_displacement_limit':None,'injured_anchor_drift_limit':None,
  'scene_radius_m':25,'aid_range_m':2.5,'usable_aid_seconds':3,'settle_seconds':4,'bounded_observation_seconds':12,
  'safe_4_m_offsets_and_07_m_motion_accepted':True,'native_complete_walking_path_required':True,'below_ground_wall_vehicle_missing_state_and_partial_paths_rejected':True,
  'actor_teleports_or_position_rebase':False,'other_nine_actors_original_15_m_limit':True,'old_evidence_preserved_separately':True,
  'actual_revive_execution_tested':False,'actual_game_validation':False}
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--report',type=Path);a=p.parse_args();r=main()
 if a.report:a.report.write_text(json.dumps(r,indent=2)+'\n')
