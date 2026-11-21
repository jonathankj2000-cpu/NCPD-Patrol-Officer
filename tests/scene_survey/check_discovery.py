"""Execute the real terminal-offset search, unchanged geometry and survey owner."""
from pathlib import Path
from tempfile import TemporaryDirectory
import argparse,importlib.util,json,os,subprocess,sys
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
sys.path.insert(0,str(HERE));from check_survey import runtime as survey_runtime
BASE='26bd1ec4bc5c709faea4efe1caa3afb8328aa26c'
SETUP='''local s,f=SurveyFixture,F;s.allowDiscoveryFiles=true
for _,p in ipairs(require('scene_discovery_sites').sites) do s.addLocation(p) end
local t=require('scene_survey')
'''
def case(body,inspect=None):
    previous=Path.cwd()
    with TemporaryDirectory(prefix='ncpd-terminal-discovery-') as temp:
        try:
            os.chdir(temp);lua=survey_runtime();lua.execute(SETUP+body)
            if inspect:inspect(lua)
        finally:os.chdir(previous)
def events():
    p=Path('scene_discovery_results.jsonl')
    return [json.loads(s) for s in p.read_text().splitlines() if s.strip()] if p.exists() else []
def main():
    spec=importlib.util.spec_from_file_location('discovery_catalog',ROOT/'tools/build_scene_discovery_catalog.py')
    builder=importlib.util.module_from_spec(spec);spec.loader.exec_module(builder);assert builder.TARGET.read_text()==builder.output()
    # All selected labels/IDs/XYZ remain sourced from the existing, unchanged
    # dataset. No scanner records/H10 or discovered-terminal state is added.
    original=json.loads((ROOT/'assets/fixed_markers/catalog.json').read_text());points={p['index']:p for p in original['sites']}
    selected=json.loads((ROOT/'assets/vip/route-sites.json').read_text())['sites']
    case('''local d=require('scene_discovery').new();local a=d.catalog.sites[1]
assert(#d.catalog.sites==60);d:begin(a,'compact')
local seen={}
for i=1,384 do
 local p,h,pass=d:next();assert(p and (pass==1 or pass==2))
 local r=math.sqrt((p.x-a.x)^2+(p.y-a.y)^2);assert(math.abs(r-p.radius)<.00001)
 assert(p.radius==10 or p.radius==20 or p.radius==30);assert(p.bearing%45==0 and h%45==0)
 local k=p.id..'/'..h;seen[k]=(seen[k] or 0)+1
end
assert(d:next()==nil);local n=0;for _,count in pairs(seen) do assert(count==2);n=n+1 end;assert(n==192)
assert(#f.creates==0 and s.moves==0);s.assertNoGameplay()''')
    def inspect_success(lua):
        rows=events();verified=[r for r in rows if r['kind']=='site_result' and r['status']=='validated']
        assert len(verified)==6 and {r['variant'] for r in verified}=={'compact','standard'}
        for row in verified:
            assert row['cleanup_confirmed'] and len(row['samples'])==10 and row['observed_seconds']>=3
            assert row['functional_validation']['path_confirmed'] and row['functional_validation']['revive_executed'] is False
            assert row['site'].startswith(row['source_anchor']+'_r')
        report=json.loads(Path('scene_discovery_report.json').read_text())
        assert report['verified_count']==6 and report['search']['production_sites_changed'] is False
        assert report['search']['original_approved_dispatch_sites']==16
        for row in report['verified_candidates']:
            assert row['position']!=row['anchor_position'] and row['radius'] in [10,20,30]
            assert row['variant'] in ['standard','compact'] and row['cleanup_confirmed']
        assert not Path('scene_survey_results.jsonl').exists() and not Path('scene_survey_report.json').exists()
    case('''assert(t.startDiscovery('nearby',true));assert(t.active() and t.blocksDuty())
assert(SurveyNative:IsDiscovery());assert(not t.startFunctional('compact',false))
s.untilIdle(350);assert(not t.active() and not SurveyNative:IsActive());assert(#f.creates==60 and s.maxLive==10)
assert(s.live()==0);assert(t.exportDiscovery());s.assertNoGameplay()
local n=#f.creates;assert(not t.startDiscovery('nearby',true));assert(#f.creates==n)
''',inspect_success)
    # A large empty tour checks every one of the 60 source anchors and both
    # variants; each result requires the actual ten actor lifecycle and cleanup.
    def inspect_full(lua):
        report=json.loads(Path('scene_discovery_report.json').read_text())
        assert report['verified_count']==120
        assert {r['source_index'] for r in report['verified_candidates']}=={p['site'] for p in selected}
        for row in report['verified_candidates']:
            assert row['anchor_position']==points[row['source_index']]['position']
    case('''assert(t.startDiscovery('all',true));s.untilIdle(7000)
assert(#f.creates==1200 and s.maxLive==10 and s.live()==0);s.assertNoGameplay()''',inspect_full)
    # Geometry is a real gate. Vehicle clearance rejected at every offset
    # creates zero actors; a nav point alone cannot claim a successful scene.
    def inspect_blocked(lua):
        assert not any(r['kind']=='trial_started' for r in events())
        assert sum(r['kind']=='geometry_rejected' for r in events())==6*384
        assert json.loads(Path('scene_discovery_report.json').read_text())['verified_count']==0
    case('''local spatial=Game.GetSpatialQueriesSystem();local overlap=spatial.Overlap
spatial.Overlap=function(self,box,center,angle,group) if box.x==1.05 then return true end;return overlap(self,box,center,angle,group) end
assert(t.startDiscovery('nearby',true));s.untilIdle(1600)
assert(#f.creates==0 and s.live()==0);s.assertNoGameplay()''',inspect_blocked)
    # Cardinal rotations fail actual vehicle clearance; diagonal headings must
    # clear the same real layout before any entity can be created.
    case('''local spatial=Game.GetSpatialQueriesSystem();local overlap=spatial.Overlap
spatial.Overlap=function(self,box,center,angle,group)
 if box.x==1.05 and angle.Yaw%90==0 then return true end
 return overlap(self,box,center,angle,group)
end
assert(t.startDiscovery('nearby',true));s.untilIdle(1700)
assert(#f.creates>0 and #f.creates<=60);s.assertNoGameplay()''',
        lambda lua:assert_diagonal_results())
    # Supported grounded Z is exported; broad snapping to another road/floor
    # and bad centre landing never authorize actors.
    def inspect_grounded(lua):
        report=json.loads(Path('scene_discovery_report.json').read_text())
        assert report['verified_count']>0
        for row in report['verified_candidates']:
            assert abs(row['position']['z']-row['anchor_position']['z']+.6)<.000001
            assert row['nominal_position']['z']==row['anchor_position']['z']
    case('''s.heightOffset=-.6;assert(t.startDiscovery('nearby',true));s.untilIdle(350)
assert(t.exportDiscovery());s.assertNoGameplay()''',inspect_grounded)
    case('''local d=require('scene_discovery').new();d:begin(d.catalog.sites[1],'compact')
local a=require('officer_down_sites').sites[1]
assert(d:duplicate(a,'compact'));assert(not d:duplicate({x=a.x,y=a.y,z=a.z+5},'compact'))
local candidate=d:next()
assert(not d:grounded(candidate,{x=candidate.x+1,y=candidate.y,z=candidate.z+.1}))
assert(not d:grounded(candidate,{x=candidate.x,y=candidate.y,z=candidate.z+3.1}))
assert(#f.creates==0 and s.moves==0)''')
    # Missing geometry at another elevation must never become an actor trial.
    case('''s.heightOffset=3;assert(t.startDiscovery('nearby',true));s.step(40)
assert(#f.creates==0);assert(t.cancel());s.step(3);assert(#f.creates==0)
assert(t.active());s.heightOffset=0;s.untilIdle(40);s.assertNoGameplay()''',lambda lua:assert_no_validated())
    # Functional access remains necessary even after complete geometric fit.
    case('''s.noAidPath=true;assert(t.startDiscovery('nearby',true));s.untilPhase('functional-observing',40)
s.step(14);assert(t.active());assert(t.cancel());s.untilIdle(50);s.assertNoGameplay()''',
        lambda lua:assert_no_validated())
    # Native recovery tag selects the separate ledger after CET reload. A
    # manager-free but still attached actor must continue to block teleport.
    case('''assert(t.startDiscovery('nearby',true));s.untilPhase('functional-settling',40)
s.holdDetached=true;assert(t.cancel());s.step(1)
local moves=s.moves;assert(t.active() and SurveyNative:GetCreatedCount()==10)
t.shutdown();package.loaded.scene_survey=nil;package.loaded.scene_discovery=nil
t=require('scene_survey');s.use(t);assert(t.recover());s.step(4)
assert(t.active() and SurveyNative:GetCreatedCount()==10 and s.moves==moves)
s.holdDetached=false;s.releaseDetached();s.untilIdle(50)
assert(not t.active() and SurveyNative:GetCreatedCount()==0);s.assertNoGameplay()''',lambda lua:assert_old_files_absent())
    # Preserve original evidence byte-for-byte, including when exporting or
    # retrying discovery. Ordinary recorded-site tours remain usable afterwards.
    case('''assert(t.startFunctional('compact',false));s.untilIdle(950);assert(t.export())
local function read(n) local h=assert(io.open(n,'r'));local v=h:read('*a');h:close();return v end
local raw,report=read('scene_survey_results.jsonl'),read('scene_survey_report.json')
assert(t.startDiscovery('nearby',true));s.untilIdle(350);assert(t.exportDiscovery())
assert(read('scene_survey_results.jsonl')==raw and read('scene_survey_report.json')==report)
assert(not t.startFunctional('compact',true));s.assertNoGameplay()''')
    # Reopen the separate append-only ledger with a truncated tail and stale
    # revision: neither grants verification nor discards earlier valid evidence.
    case(r'''assert(t.startDiscovery('nearby',true));s.untilIdle(350)
local d=require('scene_discovery').new();d.store:load();assert(d.store:count('compact')==3)
local row;for _,r in pairs(d.store.functionalBest) do row=json.decode(json.encode(r));break end
row.catalog_revision='obsolete';local h=assert(io.open(d.logFile,'a'))
assert(h:write('\n'..json.encode(row)..'\n{truncated'));h:close()
local reopened=require('scene_discovery').new();reopened.store:load()
assert(reopened.store.ignored==2 and reopened.store:count('compact')==3)
assert(#reopened:queue('both',true,'nearby')==0);s.assertNoGameplay()''')
    # Existing world/menu/cancel/start restrictions still apply to this mode.
    for inject in ['F.duty=true','F.wanted=true','F.combat=true','F.player.mounted={}','F.menu=true','SurveyFixture.canStart=false']:
        case(inject+''';assert(not t.startDiscovery('nearby',true));assert(s.moves==0 and #f.creates==0)''')
    case('''assert(t.startDiscovery('nearby',true));s.untilPhase('searching-offsets',30)
local moves=s.moves;f.menu=true;s.step(10);assert(s.moves==moves and #f.creates==0)
f.menu=false;assert(t.cancel());s.untilIdle(40);s.assertNoGameplay()''')
    case('''s.failFile=true;assert(not t.startDiscovery('nearby',true));assert(s.moves==0)
assert(not SurveyNative:IsActive());s.assertNoGameplay()''')
    case('''s.carOverlapError=true;assert(t.startDiscovery('nearby',true));s.untilIdle(50)
assert(#f.creates==0);s.assertNoGameplay()''',lambda lua:assert_no_validated())
    case('''assert(t.startDiscovery('nearby',true));s.untilPhase('functional-settling',40)
local moves=s.moves;f.generation=f.generation+1;SurveyNative:OnRestored(0,0);s.step(.5)
assert(not t.active() and s.moves==moves and f.managed[999])''')
    # Source preservation is stronger than comparing only selected outcomes.
    unchanged=['assets/officer_down_sites/catalog.json','assets/scene_survey/sites.json',
      'bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrol/officer_down.lua',
      'bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrol/officer_down_layout.lua']
    for name in unchanged:assert (ROOT/name).read_bytes()==subprocess.check_output(['git','show',f'{BASE}:{name}'],cwd=ROOT),name
    sys.path.insert(0,str(HERE.parent/'cet_ui'));from check_cet_ui import runtime as ui_runtime
    mod=ROOT/'bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrol'
    for label,expected in [('TEST: Discover scenes near 3 closest terminals','survey.startDiscovery|nearby|true'),
      ('TEST: Discover scenes near all 60 terminals','survey.startDiscovery|all|true'),('Export discovery report','survey.exportDiscovery'),
      ('Stop discovery and return','survey.cancel'),('Recover discovery cleanup and return','survey.recover'),
      ('Load discovery results','survey.loadDiscovery')]:
        _,ui=ui_runtime(mod);ui.Frame(ui,'Testing',label);assert ui.clicks==1 and expected in ui.Events(ui)
    print('PASS: actual 60-terminal offset discovery: 10/20/30 m, eight bearings/headings and bounded passes; both layouts and 120 full scenes, geometry-only rejection, functional access, physical cleanup/CET recovery tag, original ledgers/catalogue preserved, retry/load/menu/world guards and new CET routes (engine boundaries mocked)')
    return {'anchors':60,'offsets_per_anchor':24,'headings_per_offset':8,'passes':2,'variants':['compact','standard'],
      'full_120_scene_lifecycle_fixture':True,'existing_approved_sites':16,'production_dispatch_unchanged':True,
      'old_results_preserved':True,'separate_jsonl_and_json':True,'cleanup_and_reload_protection':True,'actual_game_validation':False}
def assert_no_validated():
    assert not any(r['kind']=='site_result' and r['status']=='validated' for r in events())
def assert_diagonal_results():
    report=json.loads(Path('scene_discovery_report.json').read_text())
    assert report['verified_count']>0
    assert all(row['heading']%90==45 for row in report['verified_candidates'])
def assert_old_files_absent():
    assert not Path('scene_survey_results.jsonl').exists() and not Path('scene_survey_report.json').exists()
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--report',type=Path);a=p.parse_args();result=main()
    if a.report:a.report.write_text(json.dumps(result,indent=2)+'\n')
