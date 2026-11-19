"""Run actual probe control flow; native node/engine creation remains unproven."""
from pathlib import Path
import argparse,hashlib,importlib.util,json,subprocess,sys
from tempfile import TemporaryDirectory
from lupa.luajit21 import LuaRuntime
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
sys.path.insert(0,str(HERE.parent/'arrests'))
from translate import translate
from probe_source import without_probe,PROBE_BUTTONS
PREFIX='bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrol'
BASE='d68b1696e1e0042609f323816ba94f7481de6e02'

def main():
    # Exact whitelist: all old entrypoint and UI code remains byte-identical
    # after removing the reviewed hooks/block/branding, not broad AST guesses.
    for name in ['init.lua','cet_ui.lua']:
        old=subprocess.check_output(['git','show',f'{BASE}:{PREFIX}/{name}'],cwd=ROOT,text=True)
        current=(ROOT/PREFIX/name).read_text()
        assert without_probe(current)==old,name
    src=ROOT/'r6/scripts/NCPDPatrol/NCPDPatrolQuestMarkerProbeSystem.reds'
    native=src.read_text();controller=(ROOT/PREFIX/'quest_marker_probe.lua').read_text()
    for forbidden in ['RegisterMappin','CustomPositionVariant','TrackMappin','SetMappinPosition',
                      'GiveItem','Items.money','CompleteIncident','m_paidActivities']:
        assert forbidden not in native+controller,forbidden
    # Execute translated authored native, mocking only the game API boundary.
    code=translate(src).replace('new gameJournalPath()','NewJournalPath()').replace(
        'new questMappinManagerNodeDefinition()','NewMarkerNode()')
    # redscript's String + String; the shared translator handles literal/local
    # operands already, while these path helpers return a String directly.
    code=code.replace('self:Root() + ', 'self:Root() .. ').replace(
        'self:PhasePath() + ', 'self:PhasePath() .. ').replace('self:ObjectivePath() + ', 'self:ObjectivePath() .. ')
    code=code.replace('pin = pins[i]', 'pin = AsQuestMappin(pins[i])').replace('pin = linked', 'pin = AsQuestMappin(linked)')
    lua=LuaRuntime(unpack_returned_tuples=True);lua.globals().Native=lua.execute(code)
    lua.globals().MOD_DIR=str(ROOT/PREFIX);lua.execute('package.path=MOD_DIR.."/?.lua;"..package.path')
    lua.execute((HERE/'native-mocks.lua').read_text());lua.execute((HERE/'scenarios.lua').read_text())
    # Actual CET entrypoint/menu routes for the new controls, beyond the 156
    # unchanged old routes. Merely rendering the new group has no side effects.
    sys.path.insert(0,str(HERE.parent/'cet_ui'));from check_cet_ui import runtime,click
    _,f=runtime(ROOT/PREFIX);f.Frame(f,'Testing',None);assert f.Events(f)==''
    expected={'TEST: Start static quest marker':'probe.start',
              'Activation input: default':'probe.cycleMode',
              'Log quest marker test diagnostics':'Quest marker test | fixture'}
    for label,needle in expected.items():assert needle in click(ROOT/PREFIX,False,False,'Testing',label)
    # finish is a no-op fixture for existing shutdown routing; assert the actual
    # callback is invoked separately here with a recorder.
    ui,f=runtime(ROOT/PREFIX)
    ui.execute('package.loaded.quest_marker_probe.finish=function() UIFixture.probeRemoved=true end')
    f.Frame(f,'Testing','Remove quest marker test');assert f.clicks==1 and f.probeRemoved
    module=importlib.util.spec_from_file_location('probe_assets',ROOT/'tools/build_quest_marker_probe_assets.py')
    builder=importlib.util.module_from_spec(module);module.loader.exec_module(builder)
    names=['probe.journal','probe_onscreens.json','probe_anchor.ent']
    builder.validate(*(json.loads((ROOT/'assets/quest_marker_probe'/(n+'.json')).read_text()) for n in names))
    manifest=json.loads((ROOT/'assets/quest_marker_probe/compiled.json').read_text())
    for p,digest in manifest['authored_inputs'].items():assert hashlib.sha256((ROOT/p).read_bytes()).hexdigest()==digest
    assert hashlib.sha256((ROOT/manifest['archive_path']).read_bytes()).hexdigest()==manifest['archive_sha256']
    report={'actual_game_validation':False,'actual_native_creation_proven':False,
      'node_return_is_not_success':True,'fixed_snapshot_position':True,'manual_waypoint_never_written':True,
      'objective_hash_position_and_unique_pin_required':True,'single_request_per_start':True,
      'map_menu_pauses_test':True,'own_journal_and_hash_scoped_cleanup':True,
      'confirmed_cleanup_before_restart':True,'save_restore_forgets_old_handles':True,
      'normal_dispatch_unchanged':True,'ui_controls':sorted(PROBE_BUTTONS),
      'assets_roundtrip_and_extraction':manifest['roundtrip_validated'] and manifest['extracted_resource_bytes_compared']}
    print('PASS: actual marker-probe native/Lua flows; no-pin false-success rejection, hash/position/objective proof, manual waypoint preservation, scoped cleanup/retry, menu/load/duty guards and four CET routes; real node execution still requires in-game test')
    return report

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--report',type=Path);a=p.parse_args();r=main()
    if a.report:a.report.write_text(json.dumps(r,indent=2)+'\n')
