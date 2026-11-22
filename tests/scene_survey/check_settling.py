"""Three-site transition probe; full v0.18b tour remains a comparison oracle."""
from pathlib import Path
from tempfile import TemporaryDirectory
import argparse,json,os,subprocess,sys
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
sys.path.insert(0,str(HERE))
from check_survey import runtime,case,results,plain
BASE='6b8db2612cb2504270a6fad779ee436c34bbfb1f'
PREFIX='bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrol/'
PROFILE='injured-settling-pilot-v1'

MOTION='''local s=SurveyFixture;local tour=require('scene_survey')
 s.onCreate=function(a)
  a.initial={x=a.pos.x,y=a.pos.y,z=a.pos.z}
  a.spawnYaw=F.creates[#F.creates].orientation.Yaw
 end
 s.onTick=function()
  for _,a in ipairs(s.allActors) do
   if a.attached and a.record=='Character.NCPDPatrol_OD_Injured' and a.down then
    a.downStart=a.downStart or s.time
    local age=s.time-a.downStart
    local offset=age<2.5 and 1.8 or .8
    local angle=math.rad(a.spawnYaw)
    a.pos=Vector4.new(a.initial.x-math.sin(angle)*offset,a.initial.y+math.cos(angle)*offset,a.initial.z,1)
   end
  end
 end
'''

def full_trace(reference):
 previous=Path.cwd()
 with TemporaryDirectory(prefix='ncpd-legacy-survey-oracle-') as temp:
  try:
   os.chdir(temp);lua=runtime()
   if reference:
    for name in ['officer_down_actors','scene_survey_store','scene_survey']:
     source=subprocess.check_output(['git','show',f'{BASE}:{PREFIX}{name}.lua'],cwd=ROOT,text=True)
     lua.globals().package.loaded[name]=lua.execute(source)
    lua.execute("SurveyFixture.use(require('scene_survey'))")
   lua.execute("assert(require('scene_survey').start('compact',false));SurveyFixture.untilIdle(650);SurveyFixture.assertNoGameplay()")
   events=results()
   for row in events:
    for name in ['timestamp','run','validation_profile']:row.pop(name,None)
   return {'events':events,'time':lua.globals().SF.time,'moves':lua.globals().SF.moves,'creates':plain(lua.globals().F.creates),'deletes':plain(lua.globals().F.deletes)}
  finally:os.chdir(previous)

def main():
 before,after=full_trace(True),full_trace(False)
 assert before==after,'Opt-in settling pilot changed the full 17-site procedure'
 def inspect_happy(lua):
  rows=results();sites=[r for r in rows if r['kind']=='site_result']
  assert [r['site'] for r in sites]==['kryss_04','kryss_11','kryss_15']
  assert all(r['status']=='validated' and r['validation_profile']==PROFILE for r in sites)
  frames=[r for r in rows if r['kind']=='injured_motion_sample']
  assert any(r['phase']=='spawning' and r['since_down_request']==0 for r in frames)
  assert any(r['phase']=='settling' and r['injured']['displacement']>1.5 for r in frames)
  assert all(r['injured']['displacement']<=1.5 and r['ground']['static_clear'] and r['ground']['vehicle_clear'] for r in frames if r['phase']=='observing')
  for row in sites:
   assert row['pilot_settling_seconds']==4 and row['observed_seconds']>=3 and row['maximum_observation_drift']<=.15
   assert row['injured_transition_peak_displacement']>1.5 and row['max_displacement']<=1.5
  assert lua.globals().SF.maxLive==10 and len(lua.globals().F.creates)==30
  export=json.loads(Path('scene_survey_report.json').read_text())
  assert all(r['proven'] is False for r in export['sites'])
  assert sum(bool(r['injured_settling_pilot_proven']) for r in export['sites'])==3
 case(MOTION+'''assert(tour.startPilot());s.untilIdle(250)
 assert(tour.summary():find('proven compact=0/17',1,true) and tour.summary():find('settling pilot=3/3',1,true))
 assert(s.actorTeleports==0 and #F.creates==30);s.assertNoGameplay();assert(tour.export())''',inspect_happy)
 # Same temporary movement still fails immediately in the unchanged legacy path.
 case(MOTION+'''assert(tour.start('compact',false));s.untilPhase('observing',30)
 s.step(.5);assert(tour.diagnostics():find('Phase: cleanup |',1,true))
 assert(tour.cancel());s.untilIdle(40);s.assertNoGameplay()''')
 def inspect_persistent(lua):
  rows=results();sites=[r for r in rows if r['kind']=='site_result']
  assert len(sites)==3 and all(r['status']=='unverified' for r in sites)
  failed=[r for r in rows if r['kind']=='injured_motion_sample' and r.get('failure')]
  assert len(failed)==24 and all(r['phase']=='observing' and r['failure']=='Actor displaced: injured' for r in failed)
  assert all(r['injured']['displacement']>1.5 and r['ground']['hit'] for r in failed)
  assert all(abs(r['delta_local']['forward']-1.8)<.00001 for r in failed)
 case(MOTION.replace('age<2.5 and 1.8 or .8','1.8')+'''assert(tour.startPilot());s.untilIdle(400)
 assert(tour.summary():find('settling pilot=0/3',1,true));s.assertNoGameplay()''',inspect_persistent)
 # Nine other actors retain 1.5 m during the transition; a displaced police car
 # is not excused just because the injured actor has a temporary window.
 def inspect_other(lua):
  failed=[r for r in results() if r['kind']=='injured_motion_sample' and r.get('failure')]
  assert any(r['phase']=='settling' and r['failure']=='Actor displaced: police' for r in failed)
 case('''local s=SurveyFixture;local tour=require('scene_survey');local moved=false
 s.onTick=function()
  if not moved and tour.diagnostics():find('Phase: settling |',1,true) then
   moved=true;local a=s.allActors[1];a.pos=Vector4.new(a.pos.x+2,a.pos.y,a.pos.z,1)
  end
 end
 assert(tour.startPilot());s.untilIdle(250);assert(moved);s.assertNoGameplay()''',inspect_other)
 # Actual catastrophic transition motion and below-ground movement still reject
 # immediately. The temporary envelope is never a final acceptance radius.
 for offset,reason in [('3.2','Injured transition outside hard envelope'),('0','Injured root below supported ground')]:
  script=MOTION.replace('age<2.5 and 1.8 or .8',offset)
  if offset=='0':script=script.replace('a.initial.z,1)','a.initial.z-.4,1)')
  def inspect_bad(lua,reason=reason):
   frames=[r for r in results() if r['kind']=='injured_motion_sample' and r.get('failure')==reason]
   assert frames and all(r['phase']=='settling' for r in frames)
   assert not any(r['kind']=='site_result' and r['status']=='validated' for r in results())
  case(script+'''assert(tour.startPilot());s.untilIdle(300);s.assertNoGameplay()''',inspect_bad)
 # Local ground and collision failures remain strict after settling.
 for flag,reason in [('noGround','Injured ground support not confirmed'),('static','Injured final local Static clearance blocked'),('vehicle','Injured final local Vehicle clearance blocked')]:
  script='''local s=SurveyFixture;local tour=require('scene_survey');local injected=false
 s.onTick=function()
  local observing=tour.diagnostics():find('Phase: observing |',1,true)
  if not injected and observing then injected=true;%s
  elseif not observing then %s end
 end
 assert(tour.startPilot());s.untilIdle(250);assert(injected);s.assertNoGameplay()'''
  enable={'noGround':"s.noGround.kryss_04=true",'static':'s.obstruction=true','vehicle':'s.injuredVehicleBlocked=true'}[flag]
  disable={'noGround':"s.noGround.kryss_04=nil",'static':'s.obstruction=false','vehicle':'s.injuredVehicleBlocked=false'}[flag]
  def inspect_collision(lua,reason=reason):assert any(r['kind']=='injured_motion_sample' and r.get('failure')==reason for r in results())
  case(script%(enable,disable),inspect_collision)
 # Merely staying within 1.5 m is insufficient for the pilot: a 0.2 m movement
 # during the three-second final window fails the fixed observation anchor.
 def inspect_unstable(lua):assert any(r['kind']=='injured_motion_sample' and r.get('failure')=='Actor not stable after settling: injured' and r['anchor_drift']>.15 for r in results())
 case('''local s=SurveyFixture;local tour=require('scene_survey');local ticks=0
 s.onTick=function()
  if tour.diagnostics():find('Phase: observing |',1,true) then
   ticks=ticks+1
   if ticks==3 then local a=s.allActors[4];a.pos=Vector4.new(a.pos.x+.2,a.pos.y,a.pos.z,1) end
  end
 end
 assert(tour.startPilot());s.untilIdle(250);s.assertNoGameplay()''',inspect_unstable)
 # Active timers, evidence sampling and cleanup retain the established gates.
 case('''local s=SurveyFixture;local tour=require('scene_survey')
 assert(tour.startPilot());s.untilPhase('settling',30);s.step(1)
 local before=tour.diagnostics();local creates=#F.creates
 F.menu=true;s.step(20);assert(tour.diagnostics()==before and #F.creates==creates)
 F.menu=false;F.ready=false;s.step(20);assert(tour.diagnostics()==before)
 F.ready=true;assert(tour.cancel());s.untilIdle(40)
 assert(s.live()==0 and not SurveyNative:IsActive());s.assertNoGameplay()''')
 case('''local s=SurveyFixture;local tour=require('scene_survey')
 assert(tour.startPilot());s.untilPhase('settling',30);s.failFile=true;s.untilIdle(50)
 assert(s.live()==0 and not SurveyNative:IsActive());s.assertNoGameplay()''')
 # Existing v0.18b successes remain legacy evidence. A successful pilot does
 # not change which sites the full-tour retry filter regards as unverified.
 case('''local s=SurveyFixture;local tour=require('scene_survey')
 assert(tour.start('compact',false));s.untilIdle(650)
 assert(tour.startPilot());s.untilIdle(250)
 assert(not tour.start('compact',true));assert(tour.export())
 assert(tour.summary():find('proven compact=17/17',1,true) and tour.summary():find('settling pilot=3/3',1,true));s.assertNoGameplay()''')
 sys.path.insert(0,str(HERE.parent/'cet_ui'));from check_cet_ui import runtime as ui_runtime
 _,f=ui_runtime(ROOT/PREFIX);f.Frame(f,'Testing','TEST: Injured settling pilot (3 sites)')
 assert f.clicks==0 and f.Events(f)=='','Historical pilot launcher must remain retired'
 print('PASS: opt-in three-site injured settling pilot, transient 1.8 m motion vs unchanged legacy rejection, original 1.5 m final bound, 0.15 m anchor stability, per-frame local/world positions, strict other actors/ground/clearance, pause/cancel/disk cleanup, isolated pilot evidence and exact legacy 17-site runtime/evidence comparison (engine boundaries mocked)')
 return {'profile':PROFILE,'pilot_sites':['kryss_04','kryss_11','kryss_15'],'settle_active_seconds':4,
  'observe_active_seconds':3,'final_original_position_limit_m':1.5,'observation_anchor_drift_m':.15,
  'legacy_17_site_runtime_and_evidence_identical':True,'legacy_successes_preserved_and_pilot_results_separate':True,
  'movement_logged_without_actor_teleport_or_rebase':True,'ground_and_local_clearance_checks':True,
  'actual_game_animation_confirmation':False,'precision_pilot_policy_and_layout_preserved':True}

if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--report',type=Path);a=p.parse_args();r=main()
 if a.report:a.report.write_text(json.dumps(r,indent=2)+'\n')
