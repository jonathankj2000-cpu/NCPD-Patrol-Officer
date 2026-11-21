"""Exercise the actual 17-site tour, file evidence and native survey owner."""
from pathlib import Path
from tempfile import TemporaryDirectory
import argparse,importlib.util,json,os,sys
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
sys.path.insert(0,str(HERE.parent/'officer_down'))
from check_officer_down import engine_runtime,code

def plain(value):
 if hasattr(value,'items'):
  rows=dict(value.items())
  if rows and set(rows)==set(range(1,len(rows)+1)):return [plain(rows[i]) for i in range(1,len(rows)+1)]
  return {str(k):plain(v) for k,v in rows.items()}
 return value

def runtime():
 lua=engine_runtime()
 s=code(ROOT/'r6/scripts/NCPDPatrol/NCPDPatrolSceneSurveySystem.reds')
 s=s.replace('local angle = nil','local angle = {Roll=0,Pitch=0,Yaw=0}')
 lua.globals().SurveyNative=lua.execute(s)
 def table(value):
  if isinstance(value,dict):return lua.table_from({k:table(v) for k,v in value.items()})
  if isinstance(value,list):return lua.table_from([table(v) for v in value])
  return value
 lua.globals().json=lua.table_from({'encode':lambda v:json.dumps(plain(v),separators=(',',':')),'decode':lambda s:table(json.loads(s))})
 lua.execute((HERE/'engine.lua').read_text())
 return lua

def results():
 path=Path('scene_survey_results.jsonl')
 return [json.loads(line) for line in path.read_text().splitlines() if line.strip()]

def case(body,inspect=None):
 previous=Path.cwd()
 with TemporaryDirectory(prefix='ncpd-scene-survey-') as temp:
  try:
   os.chdir(temp);lua=runtime();lua.execute(body)
   if inspect:inspect(lua)
  finally:os.chdir(previous)

def main():
 spec=importlib.util.spec_from_file_location('survey_catalog',ROOT/'tools/build_scene_survey_catalog.py')
 builder=importlib.util.module_from_spec(spec);spec.loader.exec_module(builder)
 assert builder.TARGET.read_text()==builder.output()
 data=json.loads((ROOT/'assets/scene_survey/sites.json').read_text());assert len(data['sites'])==17 and data['source_document_entries']==16
 assert data['coverage']==['City Center (Central)','Watson']
 def inspect_full(lua):
  rows=[r for r in results() if r['kind']=='site_result']
  assert len(rows)==17 and all(r['status']=='validated' and r['variant']=='compact' for r in rows)
  assert {r['site'] for r in rows}=={s['id'] for s in data['sites']}
  for row in rows:
   assert row['observed_seconds']>=3 and row['cleanup_confirmed'] and len(row['samples'])==10
   site=next(s for s in data['sites'] if s['id']==row['site']);assert row['position']==site['position']
   assert abs(row['heading']-site['heading'])<.000001
  assert Path('scene_survey_report.json').exists()
  export=json.loads(Path('scene_survey_report.json').read_text());assert len(export['sites'])==34
 case('''local s=SurveyFixture;local tour=require('scene_survey')
 assert(tour.start('compact',false));s.untilIdle(600)
 assert(s.maxLive==10 and #F.creates==170 and s.live()==0 and SurveyNative:GetCreatedCount()==0)
 assert(not SurveyNative:IsActive() and not tour.blocksDuty())
 assert(SF.godSources[501].OtherMod and not SF.godSources[501].NCPDPatrolSurveyPlayer)
 assert(math.abs(F.playerPoint.x-s.original.x)<.001 and math.abs(F.playerPoint.y-s.original.y)<.001 and math.abs(s.facing-s.original.heading)<.001)
 s.assertNoGameplay();assert(tour.export())
 assert(not tour.start('compact',true),'A successful latest test should not be queued again')''',inspect_full)
 # Standard remains a real reference variant, and geometry is checked at a
 # captured non-cardinal heading rather than only north/south rotations.
 case('''local s=SurveyFixture;local layout=require('officer_down_layout');local site=require('scene_survey_sites').sites[2]
 local h=site.heading;local a=math.rad(h);local fx,fy=-math.sin(a),math.cos(a)
 for _,variant in ipairs({'compact','standard'}) do
  local rows=layout.build(h,F.player,{site=site,variant=variant})
  assert(#rows==10)
  local forward=(rows[2].position.x-rows[1].position.x)*fx+(rows[2].position.y-rows[1].position.y)*fy
  assert(math.abs(forward-(variant=='compact' and 12 or 17))<.000001)
  assert(math.abs(Vector4:Distance(rows[2].position,rows[3].position)-11)<.000001)
 end
 local tour=require('scene_survey');assert(tour.start('standard',false));s.untilIdle(600)
 assert(#F.creates==170 and s.maxLive==10);s.assertNoGameplay()''')
 # Transient blockage is unverified, never a permanent blacklist. Retry queues
 # exactly that site after the other sixteen have passed.
 def inspect_retry(lua):
  rows=[r for r in results() if r['kind']=='site_result']
  assert len(rows)==18 and rows[0]['status']=='unverified' and rows[-1]['status']=='validated'
  assert len(rows[0]['failures'])==8 and rows[-1]['site']=='test_kryss_01'
 case('''local s=SurveyFixture;local tour=require('scene_survey')
 s.blocked.test_kryss_01=true
 assert(tour.start('compact',false));s.untilIdle(650)
 assert(#F.creates==160 and s.maxLive==10)
 s.blocked.test_kryss_01=false
 assert(tour.start('compact',true));s.untilIdle(80)
 assert(#F.creates==170);s.assertNoGameplay()''',inspect_retry)
 # A saved proven heading is reused after recreating the actual Lua modules,
 # not only while the in-memory result table is still present.
 def inspect_preferred(lua):
  rows=[r for r in results() if r['kind']=='site_result' and r['site']=='test_kryss_01']
  assert len(rows)==2 and all(r['heading']==90 for r in rows)
 case('''local s=SurveyFixture;local tour=require('scene_survey')
 s.blockHeading={test_kryss_01=0}
 assert(tour.start('compact',false));s.untilIdle(650)
 local count=#F.creates
 s.blockHeading=nil
 package.loaded.scene_survey=nil;package.loaded.scene_survey_store=nil
 tour=require('scene_survey');s.use(tour);assert(tour.loadResults())
 assert(tour.start('compact',false));s.untilPhase('observing',30)
 assert(F.creates[count+1].orientation.Yaw==180,'Proven 90-degree layout was not tried first after reload')
 s.untilIdle(650);s.assertNoGameplay()''',inspect_preferred)
 # Partial creation never allows another scene or transfer until deletion has
 # actually succeeded, including an initially refused DeleteEntity call.
 case('''local s=SurveyFixture;local tour=require('scene_survey')
 F.failCreateAt=5;F.deleteOK=false
 assert(tour.start('compact',false));s.untilPhase('cleanup',30)
 local moves=s.moves;s.step(25)
 assert(tour.active() and #F.creates==5 and s.live()==4 and s.moves==moves)
 assert(SurveyNative:GetCreatedCount()==4)
 F.deleteOK=true;s.untilIdle(650)
 assert(s.maxLive==4 and #F.creates==5 and s.live()==0 and SurveyNative:GetCreatedCount()==0);s.assertNoGameplay()''')
 # IsManaged=false is not sufficient for the test tool: attached handles must
 # disappear as well before the next world transfer can occur.
 case('''local s=SurveyFixture;local tour=require('scene_survey')
 s.holdDetached=true
 assert(tour.start('compact',false));s.untilPhase('cleanup',35)
 local moves=s.moves;s.step(25)
 assert(tour.active() and s.live()==10 and s.moves==moves and SurveyNative:GetCreatedCount()==10)
 s.holdDetached=false;s.releaseDetached();s.untilIdle(650)
 assert(s.maxLive==10 and s.live()==0);s.assertNoGameplay()''')
 # Delayed collision/nav streaming is awaited on arrival; menu/world pauses do
 # not advance placement or its deadline.
 case('''local s=SurveyFixture;local tour=require('scene_survey');local seen={}
 s.afterMove=function(q) local id=q.id or 'origin';if not seen[id] then seen[id]=true;s.groundRemaining=9 end end
 s.onCreate=function() assert(s.groundRemaining==0 and s.time>=12,'Created actors before collision settled') end
 assert(tour.start('compact',false));s.step(3)
 F.menu=true;local moves=s.moves;s.step(40);assert(#F.creates==0 and s.moves==moves)
 F.menu=false;F.ready=false;s.step(40);assert(#F.creates==0 and s.moves==moves)
 F.ready=true;s.untilIdle(850);assert(s.maxLive==10);s.assertNoGameplay()''')
 # A physical nudge after attachment is a failed trial; the tool does not
 # teleport actors back to the requested points to manufacture a stable pass.
 def inspect_drift(lua):
  rows=results();assert any(r['kind']=='trial_failed' and 'displaced' in r['reason'] for r in rows)
  first=next(r for r in rows if r['kind']=='site_result');assert first['heading']==90
 case('''local s=SurveyFixture;local tour=require('scene_survey');local injected=false
 s.onTick=function()
  if not injected and tour.diagnostics():find('Phase: observing |',1,true) then
   injected=true;local a=s.allActors[1];a.pos=Vector4.new(a.pos.x+3,a.pos.y,a.pos.z,1)
  end
 end
 assert(tour.start('compact',false));s.untilIdle(650)
 assert(injected and s.actorTeleports==0 and s.maxLive==10);s.assertNoGameplay()''',inspect_drift)
 # Each cancellable phase cleans up and returns; no partial placement is saved
 # as a validated site merely because the user interrupted the tour.
 for phase in ['landing','spawning','observing','cleanup']:
  case("""local s=SurveyFixture;local tour=require('scene_survey')
 assert(tour.start('compact',false));s.untilPhase('%s',40)
 assert(tour.cancel());s.untilIdle(40)
 assert(s.live()==0 and not SurveyNative:IsActive() and not tour.blocksDuty());s.assertNoGameplay()
 assert(SF.godSources[501].OtherMod and not SF.godSources[501].NCPDPatrolSurveyPlayer)
 """%phase)
 # An API error aborts rather than pretending each site has bad geometry.
 case('''local s=SurveyFixture;local tour=require('scene_survey')
 s.carOverlapError=true
 assert(tour.start('compact',false));s.untilIdle(50)
 assert(#F.creates==0 and s.live()==0 and not SurveyNative:IsActive())
 assert(tour.summary():find('Injected native Overlap API error',1,true));s.assertNoGameplay()''')
 # Disk errors must neither start an unrecorded tour nor prevent physical
 # cleanup/player-source release if storage later becomes unavailable.
 case('''local s=SurveyFixture;local tour=require('scene_survey')
 s.failFile=true
 assert(not tour.start('compact',false));assert(s.moves==0 and not SurveyNative:IsActive() and not tour.blocksDuty())
 assert(not SF.godSources[501].NCPDPatrolSurveyPlayer);s.assertNoGameplay()''')
 case('''local s=SurveyFixture;local tour=require('scene_survey')
 assert(tour.start('compact',false));s.untilPhase('observing',30);s.failFile=true
 s.untilIdle(50)
 assert(s.live()==0 and not SurveyNative:IsActive() and not tour.blocksDuty())
 assert(tour.summary():find('evidence write failed',1,true));s.assertNoGameplay()''')
 # CET reload has a native recovery reservation with the original position and
 # all created IDs. Recovery never enumerates ambient actors.
 case('''local s=SurveyFixture;local tour=require('scene_survey')
 assert(tour.start('compact',false));s.untilPhase('observing',30)
 F.deleteOK=false;tour.shutdown();assert(SurveyNative:IsActive() and SurveyNative:GetCreatedCount()==10)
 package.loaded.scene_survey=nil;package.loaded.scene_survey_store=nil
 tour=require('scene_survey');s.use(tour)
 assert(tour.blocksDuty() and not tour.start('compact',false))
 F.deleteOK=true;assert(tour.recover());s.untilIdle(50)
 assert(s.live()==0 and not SurveyNative:IsActive() and F.managed[999]);s.assertNoGameplay()''')
 # A saved-game/session change invalidates IDs; the new world is never moved
 # or cleaned using handles from the old test session.
 case('''local s=SurveyFixture;local tour=require('scene_survey')
 assert(tour.start('compact',false));s.untilPhase('observing',30)
 local moves,deletes=s.moves,#F.deletes
 F.generation=F.generation+1;SurveyNative:OnRestored(0,0);s.step(.25)
 assert(not tour.active() and s.moves==moves and #F.deletes==deletes)
 assert(not SurveyNative:IsActive() and SurveyNative:GetCreatedCount()==0)
 s.assertNoGameplay()''')
 # Death stops without teleporting a corpse; vehicle entry waits for an exit
 # before attempting to return the player.
 case('''local s=SurveyFixture;local tour=require('scene_survey')
 assert(tour.start('compact',false));s.untilPhase('observing',30)
 local moves=s.moves;s.playerDead=true;s.untilIdle(40)
 assert(s.moves==moves and s.live()==0 and not SurveyNative:IsActive());s.assertNoGameplay()''')
 case('''local s=SurveyFixture;local tour=require('scene_survey')
 assert(tour.start('compact',false));s.untilPhase('observing',30)
 local moves=s.moves;F.player.mounted=true;s.step(8)
 assert(tour.active() and s.moves==moves and s.live()==0)
 F.player.mounted=nil;s.untilIdle(40);assert(not SurveyNative:IsActive());s.assertNoGameplay()''')
 # Stale catalog/layout evidence cannot supply a preferred yaw. Truncated JSONL
 # tails are ignored and the next append is separated by a newline.
 case(r'''local s=SurveyFixture;local tour=require('scene_survey')
 assert(tour.start('compact',false));s.untilIdle(600)
 local file=assert(io.open('scene_survey_results.jsonl','a'))
 file:write('\n{"schema":1,"kind":"site_result","catalog_revision":"stale","site":"test_kryss_01"}\n{truncated');file:close()
 package.loaded.scene_survey=nil;package.loaded.scene_survey_store=nil
 tour=require('scene_survey');s.use(tour);assert(tour.loadResults())
 assert(tour.summary():find('incompatible/truncated lines=2',1,true))
 assert(not tour.start('compact',true))
 assert(tour.start('compact',false));assert(tour.cancel());s.untilIdle(40)
 assert(tour.export());s.assertNoGameplay()''')
 # Native preconditions also apply if a caller bypasses the menu.
 for condition in ['F.duty=true','F.wanted=true','F.combat=true','F.player.mounted=true','F.menu=true','SF.canStart=false']:
  case(condition+";local tour=require('scene_survey');assert(not tour.start('compact',false));assert(SF.moves==0 and not SurveyNative:IsActive());SF.assertNoGameplay()")
 # New CET actions are routed once. Merely opening the panel remains passive,
 # and an active/native-recovered survey blocks the ordinary duty hotkey.
 sys.path.insert(0,str(HERE.parent/'cet_ui'));from check_cet_ui import runtime as ui_runtime
 ui,f=ui_runtime(ROOT/'bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrol')
 for label,expected in {'TEST: Survey all 17 sites (compact)':'survey.startFunctional|compact|false',
  'TEST: Survey all 17 sites (standard)':'survey.startFunctional|standard|false',
  'TEST: Retry unverified survey sites':'survey.startFunctional|compact|true','Stop survey and return':'survey.cancel',
  'Recover survey cleanup and return':'survey.recover','Load saved survey results':'survey.loadResults',
  'Export scene survey report':'survey.export','Log scene survey diagnostics':'Scene survey | fixture'}.items():
  f.ClearEvents(f);f.Frame(f,'Testing',label);assert f.clicks==1 and expected in f.Events(f),label
 f.ClearEvents(f);f.Frame(f,'Testing',None);assert f.Events(f)==''
 f.surveyReserved=True;f.hotkeys.ncpdpatrol_toggle_duty();assert not f.onDuty and 'patrol.BeginShift' not in f.Events(f)
 print('PASS: actual 17-site Lua/native survey and JSONL/export; standard/compact geometry, 170 actors per full tour, stable spawn proof, physical cleanup before movement, saved preferred yaw/retry, transient blockage, partial/refused/delayed deletion, stream/menu/world waits, displacement, cancellation, API/disk errors, CET recovery, session-ID invalidation, death/mount guards and eight passive/routed CET controls; no quests/money/manual marker writes (engine boundaries mocked)')
 return {'sites':17,'source_docx_entries':16,'original_test_included':True,'coverage':data['coverage'],
  'actual_game_validation':False,'actual_lua_and_translated_native_owner':True,
  'full_tour_actor_creations':170,'maximum_concurrent_test_actors':10,'observed_stability_seconds':3,
  'actual_physical_detach_before_transfer':True,'source_specific_god_mode_cleanup':True,
  'saved_heading_reused_after_module_reload':True,'retry_only_unverified':True,
  'partial_and_delayed_cleanup':True,'menu_and_world_readiness_pause':True,'displaced_actor_is_rejected_without_locking':True,
  'cancel_and_api_errors':True,'disk_failure_does_not_prevent_cleanup':True,
  'explicit_cet_reload_recovery':True,'world_generation_forgets_old_ids':True,
  'death_and_mount_guards':True,'incompatible_and_truncated_evidence_ignored':True,
  'quest_money_career_and_manual_waypoint_unchanged':True,'ui_routes':8,'duty_blocked_during_survey':True}

if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--report',type=Path);a=p.parse_args();report=main()
 if a.report:a.report.write_text(json.dumps(report,indent=2)+'\n')
