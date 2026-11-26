"""Reproduce exact-terminal rejection and keep nearby search/stop evidence safe."""
from pathlib import Path
from tempfile import TemporaryDirectory
import argparse,json,os,subprocess,sys
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1];sys.path.insert(0,str(HERE))
from check_survey import runtime
from check_discovery import events
BASE='14dc206fdfc0198bf78dbc36e8fe89b884dbd92a'
PREFIX='bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrol/'
SETUP='''local s,f=SurveyFixture,F;s.allowDiscoveryFiles=true
for _,p in ipairs(require('scene_discovery_sites').sites) do s.addLocation(p) end
local t=require('scene_survey')
'''
NO_EXACT_NAV='''local nav=Game.GetAINavigationSystem();local find=nav.FindPointInSphereForCharacter
nav.FindPointInSphereForCharacter=function(self,p,radius,owner)
 for _,a in ipairs(require('scene_discovery_sites').sites) do
  if (p.x-a.x)^2+(p.y-a.y)^2<.01 then s.exactNavDenials=(s.exactNavDenials or 0)+1;return {status=1} end
 end
 return find(self,p,radius,owner)
end
'''
def case(body,inspect=None,legacy=False):
    previous=Path.cwd()
    with TemporaryDirectory(prefix='ncpd-discovery-staging-') as temp:
        try:
            os.chdir(temp);lua=runtime()
            if legacy:
                source=subprocess.check_output(['git','show',f'{BASE}:{PREFIX}scene_survey.lua'],cwd=ROOT,text=True)
                lua.globals().package.loaded.scene_survey=lua.execute(source)
                lua.execute("SurveyFixture.use(require('scene_survey'))")
            lua.execute(SETUP+body)
            if inspect:inspect(lua)
        finally:os.chdir(previous)
def report():return json.loads(Path('scene_discovery_report.json').read_text())
def main():
    def inspect_legacy(lua):
        rows=[r for r in events() if r['kind']=='site_result']
        assert len(rows)==120 and all(r['status']=='unverified' and 'Landing not confirmed' in r['reason'] for r in rows)
        assert not any(r['kind'] in ['geometry_rejected','geometry_passed','trial_started'] for r in events())
    case(NO_EXACT_NAV+'''assert(t.startDiscovery('all',true));s.untilIdle(7000)
assert(#f.creates==0 and s.exactNavDenials>0);s.assertNoGameplay()''',inspect_legacy,True)
    def inspect_nearby(lua):
        j=report();assert j['verified_count']==120 and j['verified_anchor_count']==60
        assert j['last_run']['status']=='completed' and j['last_run']['completed_pairs']==120
        assert len([r for r in events() if r['kind']=='staging_passed'])==120
        assert all('_r' in r['site'] for r in events() if r['kind']=='staging_passed')
        assert len([r for r in events() if r['kind']=='staging_rejected'])>=120
    case(NO_EXACT_NAV+'''assert(t.startDiscovery('all',true));s.untilIdle(7000)
assert(#f.creates==1200 and s.maxLive==10 and s.live()==0);s.assertNoGameplay()''',inspect_nearby)
    # Static clearance at the anchor is also a staging failure, not proof that
    # every nearby layout is unsuitable. Scene footprint checks remain strict.
    case('''local spatial=Game.GetSpatialQueriesSystem();local overlap=spatial.Overlap
spatial.Overlap=function(self,box,center,angle,group)
 if box.x==.4 then for _,a in ipairs(require('scene_discovery_sites').sites) do
  if (center.x-a.x)^2+(center.y-a.y)^2<.01 then return true end
 end end
 return overlap(self,box,center,angle,group)
end
assert(t.startDiscovery('nearby',true));s.untilIdle(400);assert(#f.creates==60);s.assertNoGameplay()''',
        lambda lua:assert_verified(6))
    # An actor that genuinely attaches in the wrong place still fails. After
    # physical cleanup, a retry returns to supported staging, not the bad anchor.
    case(NO_EXACT_NAV+'''local misplaced=false
s.onCreate=function(a) if not misplaced then a.pos=Vector4.new(a.pos.x+6,a.pos.y,a.pos.z,1);misplaced=true end end
local tele=GameInstance:GetTeleportationFacility({});local move=tele.Teleport
tele.Teleport=function(self,actor,p,angle)
 if actor==Game.GetPlayer() and #f.creates>0 and t.diagnostics():find('current pair=1',1,true) then
  for _,a in ipairs(require('scene_discovery_sites').sites) do assert((p.x-a.x)^2+(p.y-a.y)^2>.01,'Returned to unsupported exact anchor after actor trial') end
 end
 return move(self,actor,p,angle)
end
assert(t.startDiscovery('nearby',true));s.untilIdle(450)
assert(misplaced and #f.creates>60 and s.maxLive==10 and s.live()==0);s.assertNoGameplay()''',lambda lua:assert_verified(6))
    # There is no 35-pair cap. Simulate an explicit safety stop at that pair to
    # check evidence and retained UI reason; this is not a diagnosis of the user's stop.
    def inspect_stop(lua):
        rows=events();stop=next(r for r in rows if r['kind']=='stop_requested')
        assert stop['pair_index']==35 and 'combat=true' in stop['reason']
        assert next(i for i,r in enumerate(rows) if r['kind']=='stop_requested')<next(i for i,r in enumerate(rows) if r['kind']=='return_started')
        j=report();assert j['last_run']['status']=='stopped' and j['last_run']['completed_pairs']==34
        assert 'combat=true' in j['last_run']['reason'] and j['last_run']['returned_to_origin']
    case(NO_EXACT_NAV+'''local stopped=false;local clearAt
s.onTick=function()
 if not stopped and t.diagnostics():find('current pair=35',1,true) and t.diagnostics():find('Phase: functional-settling',1,true) then
  stopped=true;f.combat=true;clearAt=s.time+.5
 elseif clearAt and s.time>=clearAt then f.combat=false;clearAt=nil end
end
assert(t.startDiscovery('all',true));s.untilIdle(2200)
assert(stopped and #f.creates==350 and s.live()==0)
local returnReason=false;for _,line in ipairs(s.logs) do
 if line:find('Returning to the original position',1,true) and line:find('combat=true',1,true) then returnReason=true end
end
assert(returnReason);s.assertNoGameplay()''',inspect_stop)
    case('''assert(t.startDiscovery('nearby',true));s.untilPhase('searching-offsets',30)
assert(t.exportDiscovery());assert(t.cancel());s.untilIdle(40);s.assertNoGameplay()''',
        lambda lua:assert_cancelled())
    # A partial export must not invent a final reason or imply completion.
    case('''assert(t.startDiscovery('nearby',true));s.untilPhase('searching-offsets',30);assert(t.exportDiscovery())''',
        lambda lua:assert_incomplete())
    # The successful v0.18g ledger remains byte-compatible and is not rerun or
    # rewritten just because the developer search's staging procedure improved.
    with TemporaryDirectory(prefix='ncpd-old-discovery-ledger-') as tmp:
        old=Path.cwd()
        try:
            os.chdir(tmp);lua=runtime();source=subprocess.check_output(['git','show',f'{BASE}:{PREFIX}scene_survey.lua'],cwd=ROOT,text=True)
            lua.globals().package.loaded.scene_survey=lua.execute(source);lua.execute("SurveyFixture.use(require('scene_survey'))")
            lua.execute(SETUP+"assert(t.startDiscovery('nearby',true));s.untilIdle(350)")
            ledger=Path('scene_discovery_results.jsonl').read_bytes()
            lua.execute("package.loaded.scene_survey=nil;package.loaded.scene_discovery=nil;SurveyFixture.use(require('scene_survey'));assert(not require('scene_survey').startDiscovery('nearby',true));assert(require('scene_survey').exportDiscovery())")
            assert Path('scene_discovery_results.jsonl').read_bytes()==ledger and report()['verified_count']==6
        finally:os.chdir(old)
    print('PASS: v0.18g exact-terminal navmesh failure reproduced across 120 pairs; supported offset staging recovers both layouts without weakening scene checks, unsafe actor retry, no 35-pair limit, explicit stop/return reason and incomplete report, prior successful ledger preserved (engine boundaries mocked)')
    return {'previous_v018g_exact_anchor_rejection_reproduced':True,'nearby_staging_full_120_scenes':True,
        'scene_geometry_unchanged':True,'wrong_actor_position_still_rejected':True,'no_35_pair_limit':True,
        'stop_reason_retained_before_cleanup_and_during_return':True,'partial_export_not_reported_complete':True,
        'existing_successful_evidence_compatible':True,'reported_stop_cause_proven':False,'actual_game_validation':False}
def assert_verified(n):assert report()['verified_count']==n
def assert_cancelled():assert report()['last_run']['status']=='stopped' and report()['last_run']['reason']=='Survey cancelled'
def assert_incomplete():assert report()['last_run']['status']=='incomplete' and report()['last_run']['reason']=='No final stop/completion event recorded'
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--report',type=Path);a=p.parse_args();r=main()
    if a.report:a.report.write_text(json.dumps(r,indent=2)+'\n')
