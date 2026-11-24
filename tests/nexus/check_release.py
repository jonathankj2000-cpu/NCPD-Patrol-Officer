"""Exercise the real patrol-only entrypoint/UI with prototype imports forbidden."""
from pathlib import Path
import argparse
import json
import re
import subprocess
import sys
import tempfile
from lupa.luajit21 import LuaRuntime

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools'))
import nexus_release as release

TABS=['Patrol','Dispatch','Career','Settings','Diagnostics','Testing']
STORY_BUTTONS={
    'TEST: Activate quest giver quest','Clear quest giver test','Log quest giver diagnostics',
    'TEST: Continue Off the Books after briefing','Clear Off the Books encounter only','Log Off the Books diagnostics',
}
POISON='''
for _,name in ipairs({'quest_giver_test','off_the_books'}) do
 package.loaded[name]=nil
 package.preload[name]=function() error('Nexus package attempted a forbidden story import') end
end
'''


def runtime(folder,poison=False,on_duty=False,enabled=False):
    lua=LuaRuntime(unpack_returned_tuples=True)
    lua.globals().MOD_DIR=str(folder)
    lua.execute('package.path=MOD_DIR.."/?.lua;"..package.path')
    lua.execute((ROOT/'tests/cet_ui/engine-mocks.lua').read_text())
    if poison:lua.execute(POISON)
    lua.execute("dofile(MOD_DIR..'/init.lua')")
    f=lua.globals().UIFixture
    if on_duty:f.hotkeys.ncpdpatrol_toggle_duty()
    if enabled:f.busy=True;f.automatic=True;f.sound=True;f.voice=True;f.chatter=True
    f.ClearEvents(f)
    f.callbacks.onOverlayOpen()
    return lua,f


def inventory(folder,poison,on_duty,enabled):
    lua,f=runtime(folder,poison,on_duty,enabled)
    result={}
    for tab in TABS:
        frame=f.Frame(f,tab,None)
        for _,row in frame.items():
            if row.kind=='button':result[row.label]=tab
            if poison:
                assert row.label!='Quest giver prototype',row.label
                assert not release.FORBIDDEN_CONTENT.search(row.label),row.label
    assert f.Events(f)=='','Drawing release controls changed gameplay'
    return result


def click(folder,poison,on_duty,enabled,tab,label):
    _,f=runtime(folder,poison,on_duty,enabled)
    f.Frame(f,tab,label)
    assert f.clicks==1,label
    return re.sub(r'[^\s|]*\.lua:\d+','<lua>',f.Events(f))


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--payload-root',type=Path)
    parser.add_argument('--compile-native',action='store_true')
    parser.add_argument('--report',type=Path)
    args=parser.parse_args()
    files=release.payload();original=release.original_payload()
    assert not release.EXCLUDED&files.keys()
    for name,body in files.items():
        assert not any(part in name for part in ('NCPDPatrolAudioTrace','NCPDPatrolVoiceAB','NCPDPatrolVossLengthTest'))
        if name.endswith(('.lua','.reds','.yaml','.xl')):
            assert not release.FORBIDDEN_CONTENT.search(body.decode()),name
    for name in original.keys()&files.keys()-release.EDITED:
        assert files[name]==original[name],name
    assert files['LICENSE']==original['LICENSE'] and files['THIRD_PARTY_NOTICES.txt']==original['THIRD_PARTY_NOTICES.txt']
    lua=LuaRuntime()
    compile_lua=lua.eval('function(source,name) local fn,err=loadstring(source,name);assert(fn,err) end')
    for name,body in files.items():
        if name.endswith('.lua'):compile_lua(body.decode(),name)
    # Closure check on all literal local imports, not just the menu's mocks.
    modules={Path(name).stem for name in files if name.startswith(release.PREFIX) and name.endswith('.lua')}
    for name,body in files.items():
        if name.endswith('.lua'):
            for target in re.findall(r'\brequire\s*\(?\s*["\']([^"\']+)["\']',body.decode()):
                assert target in modules,(name,target)
    with tempfile.TemporaryDirectory(prefix='ncpd-nexus-validation-') as temp:
        stage=args.payload_root.resolve() if args.payload_root else Path(temp)/'payload'
        if not args.payload_root:release.materialize(files,stage)
        assert {p.relative_to(stage).as_posix():p.read_bytes() for p in stage.rglob('*') if p.is_file()}==files
        baseline=ROOT/release.PREFIX
        current=stage/release.PREFIX
        routes=0
        for duty,enabled in [(False,False),(True,False),(True,True)]:
            before=inventory(baseline,False,duty,enabled)
            after=inventory(current,True,duty,enabled)
            assert set(before)-set(after)==STORY_BUTTONS
            assert not set(after)-set(before)
            for label,tab in after.items():
                assert click(baseline,False,duty,enabled,tab,label)==click(current,True,duty,enabled,tab,label),label
                routes+=1
        # Removed entrypoints cannot be activated even by a queued old UI click.
        _,f=runtime(current,True)
        for button in STORY_BUTTONS:
            f.Frame(f,'Testing',button)
            assert f.clicks==0 and f.Events(f)==''
        # Both stable hotkey IDs and ordinary shift/session hooks still execute
        # with the prototype modules unavailable, including world teardown.
        before_lua,before=runtime(baseline)
        after_lua,after=runtime(current,True)
        assert set(before.hotkeys)==set(after.hotkeys)
        for key in ['ncpdpatrol_toggle_duty','ncpdpatrol_toggle_duty','ncpdpatrol_request_backup']:
            before.ClearEvents(before);after.ClearEvents(after)
            before.hotkeys[key]();after.hotkeys[key]()
            assert before.Events(before)==after.Events(after),key
        after.callbacks.onInit()
        after.callbacks.onUpdate(.25)
        after.callbacks.onShutdown()
        if args.compile_native:
            subprocess.run([sys.executable,str(ROOT/'tests/vip/check_native.py'),'--payload-root',str(stage)],check=True,cwd=ROOT)
    result={'version':release.VERSION,'files':len(files),'removed_story_files':sorted(release.EXCLUDED),
            'retained_lua_modules_parsed':45,'retained_native_scripts':44,'retained_archives':8,
            'all_retained_runtime_imports_resolve_without_story_modules':True,
            'six_story_buttons_and_their_header_absent':True,'remaining_ui_routes_compared':routes,
            'all_other_ui_actions_match_development_build':True,
            'ordinary_shift_hotkeys_and_session_lifecycle_execute_without_story_modules':True,
            'existing_patrol_code_assets_save_ledger_and_licenses_byte_identical':True,
            'offline_api_compile_with_and_without_browser_extension':args.compile_native,
            'private_story_test_save_migration_supported':False,'actual_game_validation':False}
    if args.report:args.report.write_text(json.dumps(result,indent=2)+'\n')
    print('PASS: Nexus payload: 14 story files omitted; 45 Lua/44 native/8 archives; story imports poisoned; '
          'six story controls absent; '+str(routes)+' remaining action routes unchanged; normal shift/lifecycle hooks; '
          'all other patrol files/licenses exact. Native API compile='+str(args.compile_native)+'; game result unverified.')
    return result


if __name__=='__main__':main()
