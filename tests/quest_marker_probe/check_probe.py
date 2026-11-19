"""Execute the archived phase data and authored controller; engine APIs mocked."""
from pathlib import Path
import argparse,copy,hashlib,importlib.util,json,subprocess,sys
from lupa.luajit21 import LuaRuntime
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
sys.path.insert(0,str(HERE.parent/'arrests'))
from translate import translate
from probe_source import without_probe,PROBE_BUTTONS
PREFIX='bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrol'
BASE='d68b1696e1e0042609f323816ba94f7481de6e02'

def phase_model(doc):
    handles={}
    def collect(x):
        if isinstance(x,dict):
            if 'HandleId' in x and isinstance(x.get('Data'),dict):handles[x['HandleId']]=x['Data']
            for v in x.values():collect(v)
        elif isinstance(x,list):
            for v in x:collect(v)
    collect(doc)
    def key(x):return x.get('HandleId',x.get('HandleRefId'))
    def get(x):return handles[key(x)]
    graph=get(doc['Data']['RootChunk']['graph'])
    nodes={str(get(n)['id']):get(n) for n in graph['nodes']}
    owners={key(s):n['id'] for n in nodes.values() for s in n['sockets']}
    model={}
    for ident,node in nodes.items():
        row={'kind':node['$type']}
        if row['kind']=='questFactsDBManagerNodeDefinition':
            t=get(node['type']);row.update(fact=t['factName'],value=t['value'],exact=bool(t['setExactValue']))
        elif row['kind']=='questPauseConditionNodeDefinition':
            t=get(get(node['condition'])['type']);row.update(fact=t['factName'],value=t['value'],comparison=t['comparisonType'])
        elif row['kind']=='questJournalNodeDefinition':
            path=get(get(node['type'])['path']);row.update(path=path['realPath'],**{'class':path['className']['$value']})
        elif row['kind']=='questMappinManagerNodeDefinition':
            path=get(node['path']);row.update(path=path['realPath'],index=path['fileEntryIndex'],disablePrevious=bool(node['disablePreviousMappins']))
        for s in node['sockets']:
            socket=get(s)
            if socket['name']['$value']=='Out':
                connections=socket['connections']
                if connections:
                    assert len(connections)==1
                    target=get(get(connections[0])['destination'])
                    row['out']={'node':owners[key(get(connections[0])['destination'])],'input':target['name']['$value']}
        model[ident]=row
    return model

def main():
    for name in ['init.lua','cet_ui.lua']:
        old=subprocess.check_output(['git','show',f'{BASE}:{PREFIX}/{name}'],cwd=ROOT,text=True)
        assert without_probe((ROOT/PREFIX/name).read_text())==old,name
    src=ROOT/'r6/scripts/NCPDPatrol/NCPDPatrolQuestMarkerProbeSystem.reds'
    native=src.read_text();controller=(ROOT/PREFIX/'quest_marker_probe.lua').read_text()
    for forbidden in ['RegisterMappin','CustomPositionVariant','TrackMappin','SetMappinPosition',
                      'GiveItem','Items.money','CompleteIncident','m_paidActivities','CreateEntity','ExecuteNode(']:
        assert forbidden not in native+controller,forbidden
    for fact in ['ready','stage','request']:
        assert 'ncpd_patrol_marker_probe_r4c_'+fact in native
    phase=json.loads((ROOT/'assets/quest_marker_probe/probe.questphase.json').read_text())
    contract=json.loads((ROOT/'assets/quest_marker_probe/phase-contract.json').read_text())
    code=translate(src).replace('self:Root() + ', 'self:Root() .. ').replace(
        'self:PhasePath() + ', 'self:PhasePath() .. ').replace('self:ObjectivePath() + ', 'self:ObjectivePath() .. ')
    code=code.replace('pin = pins[i]', 'pin = AsQuestMappin(pins[i])').replace('pin = linked', 'pin = AsQuestMappin(linked)')
    lua=LuaRuntime(unpack_returned_tuples=True)
    def convert(x):
        if isinstance(x,dict):return lua.table_from({k:convert(v) for k,v in x.items()})
        if isinstance(x,list):return lua.table_from([convert(v) for v in x])
        return x
    lua.globals().GraphModel=convert(phase_model(phase));lua.globals().PhasePosition=convert(contract['position'])
    lua.globals().Native=lua.execute(code);lua.globals().MOD_DIR=str(ROOT/PREFIX)
    lua.execute('package.path=MOD_DIR.."/?.lua;"..package.path')
    lua.execute((HERE/'native-mocks.lua').read_text());lua.execute((HERE/'scenarios.lua').read_text())
    sys.path.insert(0,str(HERE.parent/'cet_ui'));from check_cet_ui import runtime,click
    _,f=runtime(ROOT/PREFIX);f.Frame(f,'Testing',None);assert f.Events(f)==''
    for label,needle in {'TEST: Start static quest marker':'probe.start',
                         'Log quest marker test diagnostics':'Quest marker test | fixture'}.items():
        assert needle in click(ROOT/PREFIX,False,False,'Testing',label)
    ui,f=runtime(ROOT/PREFIX)
    ui.execute('package.loaded.quest_marker_probe.finish=function() UIFixture.probeRemoved=true end')
    f.Frame(f,'Testing','Remove quest marker test');assert f.clicks==1 and f.probeRemoved
    spec=importlib.util.spec_from_file_location('probe_assets',ROOT/'tools/build_quest_marker_probe_assets.py')
    builder=importlib.util.module_from_spec(spec);spec.loader.exec_module(builder)
    names=['probe.journal','probe_onscreens.json','probe_anchor.ent','probe.questphase']
    builder.validate(*(json.loads((ROOT/'assets/quest_marker_probe'/(n+'.json')).read_text()) for n in names))
    broken=copy.deepcopy(phase)
    def mutate(x):
        if isinstance(x,dict):
            if x.get('$type')=='gameJournalPath':x['fileEntryIndex']=-1
            for v in x.values():mutate(v)
        elif isinstance(x,list):
            for v in x:mutate(v)
    mutate(broken)
    try:builder.validate_phase(broken)
    except AssertionError:pass
    else:raise AssertionError('Unconfigured phase journal paths accepted')
    broken=copy.deepcopy(phase)
    def wrong_socket(x):
        if isinstance(x,dict):
            if x.get('$type')=='questSocketDefinition' and x['name']['$value']=='Active':x['name']['$value']='Enable'
            for v in x.values():wrong_socket(v)
        elif isinstance(x,list):
            for v in x:wrong_socket(v)
    wrong_socket(broken)
    try:builder.validate_phase(broken)
    except AssertionError:pass
    else:raise AssertionError('Unsupported activation edge accepted')
    manifest=json.loads((ROOT/'assets/quest_marker_probe/compiled.json').read_text())
    for path,digest in manifest['authored_inputs'].items():assert hashlib.sha256((ROOT/path).read_bytes()).hexdigest()==digest
    assert hashlib.sha256((ROOT/manifest['archive_path']).read_bytes()).hexdigest()==manifest['archive_sha256']
    xl=(ROOT/'archive/pc/mod/NCPDPatrol_QuestMarkerProbe.archive.xl').read_text()
    assert xl.count('quest:')==1 and 'parent: cyberpunk2077.quest' in xl and 'probe.questphase' in xl
    report={'actual_game_validation':False,'actual_native_creation_proven':False,
      'archived_phase_nodes':len(contract['nodes']),'archived_phase_edges':len(contract['edges']),
      'phase_ack_alone_is_not_marker_proof':True,'absolute_fixed_position':contract['position'],
      'manual_waypoint_never_written':True,'objective_hash_position_unique_pin_and_phase_stage_required':True,
      'phase_controls_own_journal_and_mappin_states':True,'private_fact_namespace':contract['fact_prefix'],
      'normal_dispatch_unchanged':True,'no_dynamic_entity_spawning':True,
      'menu_pauses_lifetime':True,'confirmed_phase_and_actor_free_marker_cleanup_before_restart':True,
      'phase_is_rearmable_without_restart':True,'save_restore_forgets_old_handles':True,
      'ui_controls':sorted(PROBE_BUTTONS),
      'assets_roundtrip_and_extraction':manifest['roundtrip_validated'] and manifest['extracted_resource_bytes_compared']}
    print('PASS: actual authored 22-node phase data + native/Lua controller: passive boot, missing-phase rejection, asynchronous start/stop, no-pin false-success rejection, hash/type/position/objective proof, scoped fallback cleanup, save/menu/duty/rearm guards and three CET routes; actual game execution still requires testing')
    return report
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--report',type=Path);a=p.parse_args();r=main()
    if a.report:a.report.write_text(json.dumps(r,indent=2)+'\n')
