"""Officer Down mixed dispatch, failure cleanup, mounted access and durable logs."""
from pathlib import Path
import argparse,json,sys
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
sys.path.insert(0,str(HERE));from check_catalog import case,events
def main():
 # Every possible first weighted draw uses the real dispatcher. Other type
 # request boundaries are covered by their full existing engine suites.
 case('''local c,f,s=CF,F,SurveyFixture;c.only(1);f.playerPoint=c.point(-800)
 local d=c.dispatch();local random=math.random;local roll
 local counts={Scanner=0,VIP=0,Cyberpsycho=0,['Officer Down']=0}
 math.random=function(a,b) if a==1 and b==100 then return roll end;return random(a,b) end
 for i=1,100 do
  roll=i;c.fallback=nil;d.reset();d.start(f.patrol,c.status)
  assert(d.requestMixed(f.patrol,c.status,'test'))
  local kind=c.scene.isActive() and 'Officer Down' or c.fallback
  counts[kind]=counts[kind]+1
  if c.scene.isActive() then c.clear() end
 end
 math.random=random
 assert(counts.Scanner==45 and counts.VIP==27 and counts.Cyberpsycho==18 and counts['Officer Down']==10)
 assert(d.mixDescription()=='45% Scanner / 27% VIP / 18% Cyberpsycho / 10% Officer Down')
 assert(f.wallet==0 and IncidentNative:GetCompletedCount()==0 and f.manual==654 and f.managed[999])''')
 # Officer Down outside its geography falls back with the remaining 90 weight.
 case('''local c,f=CF,F;c.only(1);f.playerPoint=Vector4.new(20000,20000,100,1)
 local d=c.dispatch();local random=math.random;local draws=0
 math.random=function(a,b)
  if a==1 and b==100 then draws=draws+1;return 95 end
  if a==1 and b==90 then draws=draws+1;return 1 end
  return random(a,b)
 end
 assert(d.requestMixed(f.patrol,c.status));math.random=random
 assert(draws==2 and c.fallback=='Scanner' and #f.creates==0 and OfficerNative:GetStage()==0)''')
 # Real automatic assignment, successful aid/combat, independent retained
 # scene and next automatic call inside the original 120-second maximum.
 def inspect_auto(lua):
  rows=events();assigned=[r for r in rows if r['kind']=='assigned']
  assert len(assigned)==1 and assigned[0]['details']['source']=='automatic'
  assert sum(r['kind']=='completed' for r in rows)==1
 case('''local c,f=CF,F;c.only(1);f.playerPoint=c.point(-800)
 local d=c.dispatch();local random=math.random;local chooseOfficer=true
 math.random=function(a,b) if a==1 and b==100 then return chooseOfficer and 95 or 1 end;return random(a,b) end
 d.setAutomatic(true)
 local function tick(seconds) for _=1,math.floor(seconds*4+.001) do d.update(.25,f.duty,c.status,function() return f.patrol end) end end
 for _=1,65 do tick(1);if c.scene.isActive() then break end end
 assert(c.scene.isActive() and OfficerNative:GetStage()==1)
 f.playerPoint=c.point(-100);tick(9);f.playerPoint=c.point(-40);tick(.5)
 assert(OfficerNative:GetStage()==2 and d.isActive())
 c.neutralize();f.playerPoint=OfficerNative.m_injured.pos;assert(d.reviveOfficerDown(c.status));tick(5.5)
 assert(OfficerNative:GetStage()==3 and d.completed()==1 and f.wallet==2000 and not d.isActive())
 chooseOfficer=false;c.fallback=nil
 local waited=0
 while not c.fallback and waited<122 do tick(1);waited=waited+1 end
 math.random=random
 assert(c.fallback=='Scanner' and waited<=121 and f.wallet==2000 and IncidentNative:GetCompletedCount()==1)
 assert(f.manual==654 and f.managed[999])''',inspect_auto)
 # Natural shifted landings are not teleported back. Other actors remain held.
 def inspect_offset(lua):
  ready=next(r for r in events() if r['kind']=='ready')
  injured=next(a for a in ready['details']['actors'] if a['kind']=='injured')
  assert abs(injured['actual']['x']-injured['expected']['x']-3)<.0001
 case('''local c,f,s=CF,F,SurveyFixture;c.request(4)
 s.onCreate=function(a) a.initial={x=a.pos.x,y=a.pos.y,z=a.pos.z} end
 s.onTick=function()
  for _,a in ipairs(s.allActors) do
   if a.attached and a.record=='Character.NCPDPatrol_OD_Injured' and a.down and not a.offset then
    a.offset=true;a.pos=Vector4.new(a.initial.x+3,a.initial.y,a.initial.z,1)
   end
  end
 end
 f.playerPoint=c.point(-100);c.step(9)
 assert(s.actorTeleports==0 and OfficerNative:GetStage()==1)
 f.playerPoint=c.point(-40);c.step(.25);assert(OfficerNative:GetStage()==2)
 c.clear()''',inspect_offset)
 # Arrival in a vehicle samples a nearby road-level nav source. No lower
 # bridge/other floor is accepted when it is outside the source sphere.
 case('''local c,f=CF,F;c.request(2);f.playerPoint=c.point(-100,0,1);f.player.mounted={}
 local nav=Game.GetAINavigationSystem();local find=nav.FindPointInSphereForCharacter;local checked=false
 nav.FindPointInSphereForCharacter=function(self,p,r,owner)
  if r==1.5 then checked=true;return {status=0,point=Vector4.new(p.x,p.y,c.site.z,1)} end
  return find(self,p,r,owner)
 end
 c.step(9);assert(checked)
 f.playerPoint=c.point(-40,0,1);c.step(.25);assert(OfficerNative:GetStage()==2)
 f.player.mounted=nil;c.clear()''')
 # Unsafe geometry at the current selected site fails without credits and
 # receives only a temporary cooldown; file logging does not blacklist it.
 def inspect_fail(lua):
  assert any(r['kind']=='failed' and 'placement' in r['details']['reason'].lower() for r in events())
 case('''local c,f,s=CF,F,SurveyFixture;c.request(1);s.blocked.test_kryss_01=true
 f.playerPoint=c.point(-100);c.step(10)
 assert(not c.scene.isActive() and f.wallet==0 and #f.creates==0)
 s.blocked.test_kryss_01=nil;f.playerPoint=c.point(-800)
 assert(not c.scene.requestNearby(f.patrol,c.status,true,true))
 c.step(121);assert(c.scene.requestNearby(f.patrol,c.status,true,true));c.clear()''',inspect_fail)
 # Partial/async deletion reserves foreground cleanup until physical handles
 # detach, including a CET reload after Codeware has removed manager entries.
 case('''local c,f,s=CF,F,SurveyFixture;c.staged(1);s.holdDetached=true
 assert(not c.scene.cancel(f.patrol,c.status));assert(c.scene.isActive() and OfficerNative:GetCreatedCount()==10)
 assert(not next(f.managed,999) or f.managed[999]);local deletes=#f.deletes
 package.loaded.officer_down=nil;c.use(require('officer_down'));c.step(.25)
 assert(c.scene.isActive() and OfficerNative:GetCreatedCount()==10)
 c.step(20);assert(c.scene.isActive() and not c.scene.requestNearby(f.patrol,c.status))
 s.holdDetached=false;s.releaseDetached();c.step(2)
 assert(not c.scene.isActive() and OfficerNative:GetCreatedCount()==0 and f.wallet==0 and f.managed[999])
 assert(#f.deletes==deletes,'Recovered cleanup deleted unrelated or already unmanaged IDs')''')
 # Failure before attachment/protection still retains native handles for an
 # asynchronous delete and CET reload; only our three successfully created IDs.
 case('''local c,f,s=CF,F,SurveyFixture;c.request(1);f.failCreateAt=4;f.deleteOK=false
 f.playerPoint=c.point(-100);c.step(.5)
 assert(c.scene.isActive() and OfficerNative:GetCreatedCount()==3 and OfficerNative.m_npcs.n==0)
 f.deleteOK=true;s.holdDetached=true;c.step(1.5)
 assert(c.scene.isActive() and OfficerNative:GetCreatedCount()==3)
 package.loaded.officer_down=nil;c.use(require('officer_down'));c.step(.25)
 assert(c.scene.isActive());s.holdDetached=false;s.releaseDetached();c.step(2)
 assert(not c.scene.isActive() and OfficerNative:GetCreatedCount()==0 and f.managed[999] and f.wallet==0)''')
 # Runtime aid access is a real requirement; an isolated navigation surface
 # cannot activate combat or pay a reward merely because survey data was valid.
 case('''local c,f,s=CF,F,SurveyFixture;c.request(1);s.noAidPath=true
 f.playerPoint=c.point(-40);c.step(20)
 assert(not c.scene.isActive() and OfficerNative:GetStage()==4 and f.wallet==0 and #f.threats==0)
 assert(OfficerNative:GetCreatedCount()==0 and f.managed[999])''')
 # A reload before spawning still closes the native quest instead of leaving
 # an actor-free, active journal reservation behind.
 case('''local c,f=CF,F;c.request(3);assert(#f.creates==0)
 package.loaded.officer_down=nil;c.use(require('officer_down'));c.step(.25)
 assert(OfficerNative:GetStage()==5 and not c.scene.isActive() and OfficerNative:GetCreatedCount()==0)
 for i=0,f.pins.n-1 do assert(not f.pins[i].catalog or not f.pins[i].active) end
 assert(f.manual==654 and f.wallet==0)''')
 # World changes invalidate ID ownership. Do not delete a reused identifier.
 case('''local c,f,s=CF,F,SurveyFixture;c.staged(4);local old=#f.deletes
 local id=OfficerNative:GetCreatedID(0);f.generation=f.generation+1;OfficerNative:OnRestored(0,0)
 f.objects[id.hash]=f:Actor('ambient',id,c.point());c.step(.25)
 assert(#f.deletes==old and f.objects[id.hash].record=='ambient' and OfficerNative:GetCreatedCount()==0)
 assert(not c.scene.isActive() and f.wallet==0 and f.manual==654)''')
 # Disk failures report diagnostics and never cancel a valid assignment or
 # duplicate a payout. Export/reload aggregates stream the append-only log.
 case('''local c,f,s=CF,F,SurveyFixture;c.only(1);f.playerPoint=c.point(-800);s.failFile=true
 assert(c.scene.requestNearby(f.patrol,c.status,true,true));s.failFile=false
 f.playerPoint=c.point(-100);c.step(9);f.playerPoint=c.point(-40);c.step(.25)
 assert(OfficerNative:GetStage()==2);c.neutralize();f.playerPoint=OfficerNative.m_injured.pos
 assert(c.scene.revive(c.status));c.step(5.5);assert(f.wallet==2000);c.clear()
 assert(require('officer_down_log').state():find('error=',1,true))''')
 def inspect_export(lua):
  report=json.loads(Path('officer_down_dispatch_report.json').read_text());row=next(s for s in report['sites'] if s['site']=='kryss_02')
  assert row['statistics']['assigned']==1 and row['statistics']['completed']==1 and row['statistics']['cleanup_confirmed']==1
  assert report['ignored_lines']==0 and report['records']==len(events())
 case('''CF.complete(2);CF.clear();assert(CF.scene.exportLog(CF.status))
 package.loaded.officer_down_log=nil;local log=require('officer_down_log');assert(log.export(CF.status))''',inspect_export)
 # Added CET actions route once without adding a hotkey or changing trunk keys.
 sys.path.insert(0,str(HERE.parent/'cet_ui'));from check_cet_ui import runtime as ui_runtime
 mod=ROOT/'bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrol'
 for tab,label,event in [('Dispatch','Request Officer Down dispatch','dispatch.requestOfficerDownNearby'),('Testing','TEST: Request Officer Down dispatch','dispatch.requestOfficerDownNearby'),('Diagnostics','Export Officer Down gameplay report','dispatch.exportOfficerDownLog')]:
  _,f=ui_runtime(mod);f.Frame(f,tab,label);assert f.clicks==1 and event in f.Events(f)
 print('PASS: actual 45/27/18/10 mixed selection and 90-weight fallback, automatic Officer Down/closure/next call, natural shifted and mounted aid access, temporary blockage cooldown, strict physical/partial cleanup and CET recovery, world-ID invalidation, best-effort append-only logs/export, rewards once and three CET routes (engine boundaries mocked)')
 return {'automatic_weights':{'scanner':45,'vip':27,'cyberpsycho':18,'officer_down':10},'weighted_first_draws':100,
  'automatic_resume_with_retained_scene':True,'physical_cleanup_and_cet_recovery':True,'world_change_never_deletes_reused_ids':True,
  'gameplay_log_preserved_and_streamed':True,'logging_failure_does_not_block_gameplay':True,'natural_and_mounted_access':True,
  'existing_rewards_unchanged':True,'actual_game_validation':False}
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--report',type=Path);a=p.parse_args();r=main()
 if a.report:a.report.write_text(json.dumps(r,indent=2)+'\n')
