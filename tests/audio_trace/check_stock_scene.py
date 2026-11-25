"""Validate a stock-VO scene delta and recovery; never claim audible playback."""
from pathlib import Path
import argparse
import copy
import json
import subprocess
import sys
from lupa.luajit21 import LuaRuntime

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT/'tools'))
import build_voss_stock_scene_test as build


def rejected(before, after):
    try:
        build.validate_delta(before, after)
    except AssertionError:
        return
    raise AssertionError('Unexpected change passed the stock-scene whitelist')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--compiler', type=Path, required=True)
    parser.add_argument('--report', type=Path)
    args = parser.parse_args()
    before = json.loads((ROOT/'assets/quest_giver_test/conversation.scene.json').read_text())
    after, changes = build.stock_scene(before)
    assert len(changes) == 6 and {c['after'] for c in changes} == set(build.STOCK_IDS)
    assert before != after
    nodes = build.root(after)['sceneGraph']['Data']['graph']
    events = [e['Data'] for n in nodes for e in n['Data'].get('events', [])
              if e['Data']['$type'] == 'scnDialogLineEvent']
    assert len(events) == 10
    # Each corrupted example must fail independently of the ID substitutions.
    wrong = copy.deepcopy(after)
    build.root(wrong)['screenplayStore']['lines'][0]['locstringId']['ruid'] = '999'
    rejected(before, wrong)
    wrong = copy.deepcopy(after)
    build.root(wrong)['screenplayStore']['lines'][1]['locstringId']['ruid'] = build.STOCK_IDS[1]
    rejected(before, wrong)
    wrong = copy.deepcopy(after)
    build.root(wrong)['screenplayStore']['lines'][0]['femaleLipsyncAnimationName']['$value'] = 'None'
    rejected(before, wrong)
    for key, value in [('startTime', 999), ('duration', 999)]:
        wrong = copy.deepcopy(after)
        next(e['Data'] for n in build.root(wrong)['sceneGraph']['Data']['graph']
             for e in n['Data'].get('events', []) if e['Data']['$type'] == 'scnDialogLineEvent')[key] = value
        rejected(before, wrong)
    rejected(before, before)
    try:
        build.stock_scene(after)
    except AssertionError:
        pass
    else:
        raise AssertionError('An already-patched scene was accepted as baseline')

    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute('''Callbacks={}; Draws=0
      function registerForEvent(name,cb) assert(not Callbacks[name]);Callbacks[name]=cb end
      function print(_) end
      ImGui={Begin=function() Draws=Draws+1;return true end,End=function() end,
        TextWrapped=function(_) end,Button=function() error('Retired helper offered playback') end}
      Game=setmetatable({}, {__index=function() error('Retired helper accessed gameplay') end})
      function NewObject(_) error('Retired helper created a native event') end''')
    helper = (ROOT/'tools/stock_scene/disabled_voice_ab.lua').read_text()
    lua.execute(helper)
    callbacks = lua.globals().Callbacks
    assert set(callbacks.keys()) == {'onInit', 'onDraw', 'onOverlayOpen', 'onOverlayClose'}
    callbacks['onInit']()
    callbacks['onDraw']()
    assert lua.globals().Draws == 0
    callbacks['onOverlayOpen']()
    callbacks['onDraw']()
    assert lua.globals().Draws == 1
    callbacks['onOverlayClose']()
    callbacks['onDraw']()
    assert lua.globals().Draws == 1
    legacy = subprocess.run([sys.executable, str(ROOT/'tools/build_voice_ab_release.py'),
                             '--compiler', '/not-a-compiler'], capture_output=True, text=True)
    assert legacy.returncode != 0 and 'Rejected in-game control' in legacy.stderr
    stub = ROOT/'tools/voice_ab/recovery/NCPDPatrolVossLengthTest.reds'
    assert 'RegisterCallback(' not in stub.read_text()
    subprocess.run([str(args.compiler.resolve()), str(ROOT/'tests/audio_trace/length-api.reds'), '--', str(stub)], check=True)
    result = {'six_private_line_refs_replaced_by_four_already_working_native_v_ids': True,
              'all_other_scene_data_exactly_preserved': True,
              'unexpected_id_original_v_timing_and_lipsync_changes_rejected': True,
              'retired_helper_executes_without_gameplay_or_audio_access': True,
              'historical_silent_control_build_blocked_by_default': True,
              'unchanged_inert_length_recovery_offline_compiled': True,
              'actual_native_playback_verified': False}
    if args.report:
        args.report.write_text(json.dumps(result, indent=2)+'\n')
    print('PASS: six-ID scene whitelist, unchanged original replies/events/timing/lipsync, negative controls, inert helper execution and recovery API compile; audio requires game testing')


if __name__ == '__main__':
    main()
