"""Current CET routes and full Officer Down catalogue eligibility, without gameplay changes."""
from pathlib import Path
import argparse,json,sys

HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
sys.path.insert(0,str(HERE.parent/'officer_down'))
from check_catalog import case
from check_cet_ui import runtime,rows,TABS
from probe_source import PROBE_BUTTONS,RETIRED_BUTTONS
MOD=ROOT/'bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrol'

def main():
    catalog=json.loads((ROOT/'assets/officer_down_sites/catalog.json').read_text())
    assert len(catalog['sites'])==54 and all(s['enabled'] for s in catalog['sites'])
    # All sites remain enabled together. Select each eligible RNG outcome at a
    # normal 800 m approach, through the actual dispatcher and native owner.
    # This is distinct from lifecycle tests that isolate one catalogue entry.
    for site in catalog['sites']:
        case('''local c,f=CF,F;c.dispatch()
local sites=require('officer_down_sites').sites
local target=sites[%d];f.playerPoint=Vector4.new(target.x-800,target.y,target.z,1)
local ordinal,count=0,0
for _,s in ipairs(sites) do
 assert(s.enabled)
 local d=math.sqrt((f.playerPoint.x-s.x)^2+(f.playerPoint.y-s.y)^2+(f.playerPoint.z-s.z)^2)
 if d>=500 and d<=1000 then count=count+1;if s.index==target.index then ordinal=count end end
end
assert(ordinal>0)
local originalRandom=math.random;local selected=false
math.random=function(a,b)
 if not selected then selected=true;assert(a==1 and b==count);return ordinal end
 return originalRandom(a,b)
end
assert(c.d.officerDownCatalogueInfo():find('54 enabled locations',1,true))
assert(c.d.requestOfficerDownNearby(f.patrol,c.status))
assert(OfficerNative:GetCatalogIndex()==target.index and f.manual==654 and f.wallet==0)
c.step(.25);assert(OfficerNative.m_marker.m_confirmed)
assert(c.scene.diagnostics():find('selected site='..target.id,1,true))
c.clear()
''' % site['index'])
    # Ordinary random requests at five distant origins must use their nearest
    # available band, including imported sites, instead of forcing Kryss 1.
    origins=[(-2650,-2300,18),(900,-1100,25),(-1100,3000,8),(-1900,700,12),(0,-2100,10)]
    selected=[]
    for point in origins:
        observed={}
        def inspect(lua):observed['index']=lua.globals().AuditIndex
        case('''local c,f=CF,F;math.randomseed(20261122);c.dispatch()
f.playerPoint=Vector4.new(%s,1)
local radius=5000
for _,r in ipairs({1000,2000,5000}) do
 local eligible=false
 for _,s in ipairs(require('officer_down_sites').sites) do
  local d=math.sqrt((f.playerPoint.x-s.x)^2+(f.playerPoint.y-s.y)^2+(f.playerPoint.z-s.z)^2)
  if s.enabled and d>=500 and d<=r then eligible=true end
 end
 if eligible then radius=r;break end
end
assert(c.d.requestOfficerDownNearby(f.patrol,c.status))
AuditIndex=OfficerNative:GetCatalogIndex()
local s=require('officer_down_sites').sites[AuditIndex]
local d=math.sqrt((f.playerPoint.x-s.x)^2+(f.playerPoint.y-s.y)^2+(f.playerPoint.z-s.z)^2)
assert(d>=500 and d<=radius and AuditIndex~=1 and f.manual==654)
c.clear()
''' % ','.join(map(str,point)),inspect)
        selected.append({'origin':point,**observed})
    assert len({s['index'] for s in selected})>=3
    lua,f=runtime(MOD)
    # Use the real read-only summary rather than a hard-coded display stub.
    lua.execute('''package.loaded.dispatch.officerDownCatalogueInfo=function()
 local c=require('officer_down_sites');local n=0
 for _,s in ipairs(c.sites) do if s.enabled then n=n+1 end end
 return tostring(n)..' enabled locations | '..c.coverage
end''')
    inventory=set()
    for tab in TABS:
        frame=rows(f.Frame(f,tab,None))
        inventory.update(r['label'] for r in frame if r['kind']=='button')
        assert f.Events(f)==''
    assert PROBE_BUTTONS-RETIRED_BUTTONS<=inventory and not RETIRED_BUTTONS&inventory
    for tab in ['Dispatch','Diagnostics']:
        frame=rows(f.Frame(f,tab,None))
        assert any('54 enabled locations' in r['label'] and 'Santo Domingo' in r['label'] for r in frame)
    frame=rows(f.Frame(f,'Testing',None))
    headers=[r['label'] for r in frame if r['kind']=='header']
    assert headers[0]=='Dispatch scenarios'
    assert headers.index('Audio previews')<headers.index('Scene survey: recorded sites')<headers.index('Scene discovery: terminal offsets')
    for tab,label,event in [
        ('Dispatch','Request Officer Down dispatch','dispatch.requestOfficerDownNearby'),
        ('Testing','TEST: Request Officer Down dispatch','dispatch.requestOfficerDownNearby'),
        ('Testing','Revive scene officer (nearby)','dispatch.reviveOfficerDown'),
        ('Diagnostics','Clear Officer Down scene','dispatch.clearOfficerDown'),
        ('Diagnostics','Export Officer Down gameplay report','dispatch.exportOfficerDownLog')]:
        f.ClearEvents(f);f.Frame(f,tab,label)
        assert f.clicks==1 and f.Events(f).count(event)==1,(label,f.Events(f))
    print('PASS: current CET controls: all 54 sites selectable with the entire catalogue enabled and native pins confirmed; five ordinary distant requests use their nearest band; legacy launchers absent, current routes once, passive summary and developer tools retained (engine boundaries mocked)')
    return {'catalogue_enabled':54,'full_catalogue_eligible_and_native_confirmed':54,
        'ordinary_request_samples':selected,'retired_buttons':sorted(RETIRED_BUTTONS),
        'current_added_controls':sorted(PROBE_BUTTONS-RETIRED_BUTTONS),
        'dispatch_scenarios_first':True,'passive_drawing_has_no_actions':True,
        'actual_game_validation':False}

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--report',type=Path)
    args=parser.parse_args();report=main()
    if args.report:args.report.write_text(json.dumps(report,indent=2)+'\n')
