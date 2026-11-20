"""Execute actual old/new CET entrypoints: routes, tabs and session boundaries."""
from pathlib import Path
from tempfile import TemporaryDirectory
import argparse, json, re, subprocess, sys
from lupa.luajit21 import LuaRuntime

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
BASE='3c20841bba35d69289e5f70784b3202a5fbf8881'
PREFIX='bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrol'
TABS=['Patrol','Dispatch','Career','Settings','Diagnostics','Testing']
sys.path.insert(0,str(HERE.parent/'quest_marker_probe'))
from probe_source import without_probe,PROBE_BUTTONS

def base_file(name):
    return subprocess.check_output(['git','show',f'{BASE}:{PREFIX}/{name}'],cwd=ROOT,text=True)

def verify_session_source():
    before=base_file('init.lua').split('registerForEvent("onDraw", function()',1)[0]
    after=(ROOT/PREFIX/'init.lua').read_text().split('-- The menu reads live session state',1)[0]
    after=without_probe(after)
    after=after.replace('-- NCPD Patrol v0.17d VIP refactor r3 | extracted locations and waypoint ownership',
                        '-- NCPD Patrol v0.17d CET refactor r2 | separated menu and live session')
    after=after.replace('v0.17d VIP refactor r3 loaded. VIP locations and waypoint ownership are separate modules. Transport, ambush, rewards and the CET menu retain their existing behavior. Install the complete package and restart.',
                        'v0.17d CET refactor r2 loaded. Patrol, Dispatch, Career, Settings, Diagnostics and Testing tabs. Existing gameplay and dispatch refactor retained. Install the complete package and restart.')
    after=after.replace('-- NCPD Patrol v0.17d CET refactor r2 | separated menu and live session',
                        '-- NCPD Patrol v0.17d dispatch refactor r1 | unchanged gameplay contracts')
    after=after.replace('v0.17d CET refactor r2 loaded. Patrol, Dispatch, Career, Settings, Diagnostics and Testing tabs. Existing gameplay and dispatch refactor retained. Install the complete package and restart.',
                        'v0.17d dispatch refactor r1 loaded. Scanner, scheduling and result tracking are separate modules. Existing rewards, progression, markers and actor cleanup retained. Install the complete package and restart.')
    assert after==before,'Session/shift/update/shutdown code changed during UI extraction'

def runtime(modules,on_duty=False,enabled=False):
    lua=LuaRuntime(unpack_returned_tuples=True)
    lua.globals().MOD_DIR=str(modules)
    lua.execute('package.path=MOD_DIR.."/?.lua;"..package.path')
    lua.execute((HERE/'engine-mocks.lua').read_text())
    lua.execute("dofile(MOD_DIR..'/init.lua')")
    f=lua.globals().UIFixture
    if on_duty:f.hotkeys.ncpdpatrol_toggle_duty()
    if enabled:
        f.busy=True;f.automatic=True;f.sound=True;f.voice=True;f.chatter=True
    f.ClearEvents(f)
    f.callbacks.onOverlayOpen()
    return lua,f

def rows(table):
    return [dict(row.items()) for _,row in table.items()]

def buttons(modules,on_duty,enabled):
    lua,f=runtime(modules,on_duty,enabled)
    found={}
    for tab in TABS:
        for row in rows(f.Frame(f,tab,None)):
            if row['kind']=='button':
                found.setdefault(row['label'],row.get('tab') or 'Patrol')
    assert f.Events(f)=='','Merely opening the menu produced gameplay side effects'
    return found

def click(modules,on_duty,enabled,tab,label):
    lua,f=runtime(modules,on_duty,enabled)
    f.Frame(f,tab,label)
    assert f.clicks==1,f'Button missing/duplicated: {tab}/{label}'
    # Source paths move when native display/error handlers move into the UI.
    events=re.sub(r'[^\s|]*\.lua:\d+','<lua>',f.Events(f))
    return events

def check_routes(reference,current):
    total=0;inventory=[]
    for duty,enabled in [(False,False),(True,False),(True,True)]:
        old=buttons(reference,duty,enabled);new=buttons(current,duty,enabled)
        assert PROBE_BUTTONS<=set(new),'The isolated probe controls must remain available'
        new={label:tab for label,tab in new.items() if label not in PROBE_BUTTONS}
        assert set(old)==set(new),{'missing':sorted(set(old)-set(new)),'added':sorted(set(new)-set(old))}
        for label,tab in sorted(new.items()):
            before=click(reference,duty,enabled,'Patrol',label)
            after=click(current,duty,enabled,tab,label)
            assert before==after,f'Action changed: {label}\nOLD: {before}\nNEW: {after}'
            total+=1
        if not duty:inventory=[{'button':label,'tab':tab} for label,tab in sorted(new.items())]
    return total,inventory

def check_layout(current):
    lua,f=runtime(current)
    normal={}
    for tab in TABS:
        f.openHeaders=False
        frame=rows(f.Frame(f,tab,None))
        normal[tab]=[row['label'] for row in frame if row['kind']=='button']
        assert any(row.get('child')=='NCPDPatrolLastStatus' and row['kind']=='text' for row in frame)
        for row in frame:
            assert not row.get('tab') or row['tab']==tab
            if row['kind']=='button' and tab not in ['Testing','Diagnostics']:
                assert not row['label'].startswith(('TEST:','Test:','Test timeout:','Log ')),row
        assert f.Events(f)=='','Drawing a tab mutated gameplay'
    assert 'Request backup patrol' in normal['Patrol'] and 'Request new partner' in normal['Patrol']
    assert 'Request dispatch now' in normal['Dispatch'] and 'Cancel active dispatch' in normal['Dispatch']
    assert 'Claim next milestone reward' in normal['Career']
    assert 'TEST: Unlock all milestones (session)' in normal['Testing']
    # A collapsed window/tab bar or clipped content still requires the native
    # matching End calls; hidden controls must not execute a queued click.
    for property in ['windowVisible','tabBarVisible','contentVisible']:
        setattr(f,property,False);f.Frame(f,'Testing','TEST: Unlock all milestones (session)')
        assert f.clicks==0 and f.Events(f)==''
        setattr(f,property,True)
    f.footerVisible=False;f.Frame(f,'Patrol',None);f.footerVisible=True
    # Font-scaled footer reservation, progress at boundaries and missing native
    # modules/optional browser exercise real panel paths without grants/writes.
    for line_height in [14,18,24,32]:
        f.lineHeight=line_height
        for tab in TABS:f.Frame(f,tab,None)
    for percent,expected in [(-20,0),(0,0),(50,.5),(100,1),(150,1)]:
        f.progress=percent;f.Frame(f,'Career',None);assert f.progressValue==expected
    f.maxRank=True;assert any(row['label']=='All milestones reached' for row in rows(f.Frame(f,'Career',None)))
    for prop in ['loaded','nativeAvailable']:
        setattr(f,prop,False)
        for tab in TABS:f.Frame(f,tab,None)
        setattr(f,prop,True)
    f.noBrowser=True;f.Frame(f,'Career',None)
    f.repair=7
    assert any(row['label']=='Vehicle repair: 7 s remaining' for row in rows(f.Frame(f,'Patrol',None)))
    assert f.Events(f)==''
    # A failed native/display query must not leak ImGui scopes or trap the
    # other tabs in an invalid frame. Report a persistent failure only once.
    f.failPartnerRead=True
    f.Frame(f,'Patrol',None);assert 'CET UI | Patrol:' in f.Events(f)
    f.ClearEvents(f);f.Frame(f,'Patrol',None);assert f.Events(f)==''
    f.Frame(f,'Career',None);assert f.Events(f)==''
    f.failPartnerRead=False;f.Frame(f,'Patrol',None);assert f.Events(f)==''
    # UI state is live: a hotkey updates the header/partner action, and the
    # footer receives the result of a button in that same frame.
    f.hotkeys.ncpdpatrol_toggle_duty();f.ClearEvents(f)
    assert any(row['label']=='End Shift' for row in rows(f.Frame(f,'Patrol',None)))
    f.Frame(f,'Patrol','Spawn partner');assert 'partner.spawn|true|<callback>' in f.Events(f)
    f.ClearEvents(f);f.Frame(f,'Testing','TEST: Unlock all milestones (session)')
    f.ClearEvents(f)
    for tab in TABS:
        assert any('TEST UNLOCKS ACTIVE' in row['label'] for row in rows(f.Frame(f,tab,None)))
    frame=rows(f.Frame(f,'Testing','Clear test unlocks'))
    assert any(row.get('child')=='NCPDPatrolLastStatus' and row['label']=='Career | fixture' for row in frame)
    assert not any('TEST UNLOCKS ACTIVE' in row['label'] for row in rows(f.Frame(f,'Patrol',None)))
    f.ClearEvents(f);f.callbacks.onOverlayClose();assert not rows(f.Frame(f,'Testing','TEST: Unlock all milestones (session)'))
    assert f.Events(f)==''
    return normal

def main():
    verify_session_source()
    current=ROOT/PREFIX
    api=json.loads((HERE/'cet-api-contract.json').read_text())
    methods=set(re.findall(r'ImGui\.(\w+)\(', (current/'cet_ui.lua').read_text()))
    assert methods==set(api['methods']),'Review new ImGui calls against the pinned CET bindings'
    assert api['version']=='v1.37.1' and api['enum']=='ImGuiCond.FirstUseEver'
    with TemporaryDirectory(prefix='ncpd-cet-ui-oracle-') as tmp:
        reference=Path(tmp)/'before';reference.mkdir()
        (reference/'init.lua').write_text(base_file('init.lua'))
        total,inventory=check_routes(reference,current)
        normal=check_layout(current)
        # A valid but incorrect target must be caught by the old/new recorder.
        broken=Path(tmp)/'negative';broken.mkdir()
        (broken/'init.lua').write_text((current/'init.lua').read_text())
        for name in ['marker_navigation.lua','marker_catalog.lua']:
            (broken/name).write_text((current/name).read_text())
        source=(current/'cet_ui.lua').read_text();needle='Dispatch.requestMixed(getPatrolSystem(), status)'
        assert source.count(needle)==1
        (broken/'cet_ui.lua').write_text(source.replace(needle,'Dispatch.requestVIP(getPatrolSystem(), status)'))
        assert click(reference,False,False,'Patrol','Request dispatch now')!=click(broken,False,False,'Dispatch','Request dispatch now')
    report={'base_commit':BASE,'tabs':TABS,'button_inventory':inventory,'compared_action_routes':total,
            'cet_api_version':api['version'],'cet_api_commit':api['commit'],'cet_methods':sorted(methods),
            'default_buttons':normal,'session_source_unchanged_except_probe_hooks_and_build_labels':True,
            'begin_end_balancing':True,'inactive_tabs_do_not_run_actions':True,'live_session_and_status_getters':True,
            'panel_errors_preserve_scopes_and_log_once':True,
            'font_scaled_footer':[14,18,24,32],'missing_native_and_optional_browser':True,
            'wrong_dispatch_target_negative_control':True,'actual_game_rendering':False}
    print(f'PASS: CET UI: {len(inventory)} retained controls, {total} old/new action routes; six isolated tabs, scoped Begin/End, live duty/status, test banner, missing modules/browser, font-scaled footer and routing-regression negative control')
    return report

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--report',type=Path)
    args=parser.parse_args();report=main()
    if args.report:args.report.write_text(json.dumps(report,indent=2)+'\n')
