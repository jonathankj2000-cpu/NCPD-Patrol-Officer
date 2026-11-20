"""Verify baked VIP selection, canonical IDs, native transitions and old-flow isolation."""
from pathlib import Path
import argparse
import importlib.util
import json
import subprocess
import sys
from lupa.luajit21 import LuaRuntime

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
PREFIX = ROOT / 'bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrol'
BASE = 'fa4c9b60d4ee3908ac1a5e77c6d21b32156506d4'


def main():
    spec = importlib.util.spec_from_file_location('vip_route_builder', ROOT / 'tools/build_vip_route_catalog.py')
    builder = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(builder)
    for path, expected in builder.build().items():
        assert (ROOT / path).read_text() == expected, 'Noncanonical generated VIP routes: ' + path
    manifest = json.loads((ROOT / 'assets/vip/routes.json').read_text())
    assert manifest['endpoint_count'] == 60 and manifest['route_count'] == 360
    # Actor/quest/reward code is byte-identical; only the location policy changes.
    paths = [f'bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrol/{name}' for name in
             ['vip.lua','vip_waypoint.lua','vip_ambush.lua','vip_ambush_unit.lua','marker_navigation.lua','arrest.lua']]
    paths += subprocess.check_output(['git','ls-tree','-r','--name-only',BASE,'--','r6','archive'],cwd=ROOT,text=True).splitlines()
    for path in paths:
        assert (ROOT / path).read_bytes() == subprocess.check_output(['git','show',f'{BASE}:{path}'],cwd=ROOT), path

    def selector(source=None):
        lua = LuaRuntime(unpack_returned_tuples=True)
        lua.globals().MOD_DIR = str(PREFIX)
        lua.execute('package.path=MOD_DIR.."/?.lua;"..package.path;math.randomseed(20261120)')
        lua.execute((HERE / 'engine.lua').read_text())
        if source is not None:
            lua.globals().OverrideSource = source
            lua.execute('package.preload.vip_locations=function() return assert(loadstring(OverrideSource))() end')
        return lua.execute((HERE / 'scenarios.lua').read_text())

    positions = selector()
    current = (PREFIX / 'vip_locations.lua').read_text()
    for label, source, expected in [
        ('old live-pool selector', subprocess.check_output(['git','show',f'{BASE}:bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrol/vip_locations.lua'],cwd=ROOT,text=True), 'No safe VIP'),
        ('scanner radius mutant', current.replace('distance(site.position,point)<100','distance(site.position,point)<120'), 'Scanner exclusion exceeded'),
    ]:
        assert source != current
        try:
            selector(source)
        except Exception as error:
            assert expected in str(error), (label, str(error))
        else:
            raise AssertionError('Regression control was not detected: ' + label)

    sys.path.insert(0, str(HERE.parent / 'dispatch_refactor'))
    from check_refactor import runtime
    lua = runtime(PREFIX, [], install_trace=False)
    lua.execute((HERE / 'facade.lua').read_text())
    report = {'baked_endpoints':60,'baked_routes':360,'player_positions_exercised':positions,
              'runtime_coordinates':'shared canonical marker catalogue; unchanged two-metre match',
              'no_discovered_terminal_requirement':True,'pickup_and_delivery_scanner_exclusion':True,
              'recent_selection_window':12,'small_pool_remains_live':True,
              'old_live_pool_negative_control':True,'scanner_radius_negative_control':True,
              'actual_facade_lifecycle_reward_and_new_assignment':True,
              'native_marker_bank_integration':'tests/fixed_markers/check_fixed.py executes all 360 pairs',
              'all_native_scripts_archives_arrest_and_vip_actor_code_unchanged':True,
              'actual_game_road_and_rendering_validation':False}
    print('PASS: 60 canonical VIP endpoints / 360 baked routes; no discovery/drop-point dependency; nonzero pickup/delivery IDs; scanner safety, local/expanded bounds, recent-history exhaustion; actual VIP facade/boarding/EUR$2000/cleanup/new request; old selector and radius mutants rejected (engine boundaries mocked)')
    return report


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--report', type=Path)
    args = parser.parse_args()
    report = main()
    if args.report:
        args.report.write_text(json.dumps(report, indent=2) + '\n')
