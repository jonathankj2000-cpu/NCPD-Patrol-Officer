"""Execute the real finite-bank controller and Lua navigation, mock engine APIs."""
from pathlib import Path
import argparse,hashlib,importlib.util,json,subprocess,sys
from lupa.luajit21 import LuaRuntime
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
sys.path.insert(0,str(HERE.parent/'arrests'))
from translate import translate
PREFIX=ROOT/'bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrol'

def main():
    catalog=json.loads((ROOT/'assets/fixed_markers/catalog.json').read_text())
    assert len(catalog['sites'])==323 and {s['index'] for s in catalog['sites']}==set(range(1,324))
    assert sum(s['kind']=='scanner' for s in catalog['sites'])==132
    spec=importlib.util.spec_from_file_location('bank_assets',ROOT/'tools/build_fixed_marker_assets.py')
    builder=importlib.util.module_from_spec(spec);spec.loader.exec_module(builder)
    definitions=[];counts={}
    for kind in builder.KINDS:
        doc=json.loads((ROOT/f'assets/fixed_markers/{kind}.journal.json').read_text());counts[kind]=builder.validate(doc,kind)
        folder=doc['Data']['RootChunk']['entry']['Data']['entries'][0]['Data']
        for handle in folder['entries']:
            quest=handle['Data'];root='quests/minor_quest/'+quest['id']
            for objective_handle in quest['entries'][0]['Data']['entries']:
                objective=objective_handle['Data'];path=root+'/main/'+objective['id']
                for h in objective['entries'][1:]:
                    definitions.append({'root':root,'objective':path,'path':path+'/'+h['Data']['id'],'site':int(h['Data']['id'][5:])})
    assert counts=={'dispatch':792,'vip':382,'cyberpsycho':382}
    src=ROOT/'r6/scripts/NCPDPatrol/NCPDPatrolFixedMarkerSystem.reds';source=src.read_text()
    for forbidden in ['SetMappinPosition','TrackMappin','CustomPositionVariant','TrackEntry','CreateEntity','GiveItem','m_paidActivities','ExecuteNode']:
        assert forbidden not in source,forbidden
    code=translate(src).replace('self:Root(scope) + ','self:Root(scope) .. ')
    code=code.replace('pin = pins[i]', 'pin = AsQuestMappin(pins[i])').replace('pin = linked', 'pin = AsQuestMappin(linked)')
    code=code.replace('tag = pins[i]:GetScriptData()', 'tag = AsFixedData(pins[i]:GetScriptData())')
    code=code.replace('IsDefined(live:GetScriptData())','IsDefined(AsFixedData(live:GetScriptData()))')
    code=code.replace('new NCPDPatrolFixedMarkerData()', 'NewFixedData()')
    code=code.replace('local point = nil','local point = Vector4.new(0,0,0,0)').replace('local questPoint = nil','local questPoint = Vector4.new(0,0,0,0)')
    code=code.replace('known = map:GetQuestMappinPosition(self.m_hash, point)','known, point = map:GetQuestMappinPosition(self.m_hash)')
    lua=LuaRuntime(unpack_returned_tuples=True)
    def convert(value):
        if isinstance(value,dict):return lua.table_from({k:convert(v) for k,v in value.items()})
        if isinstance(value,list):return lua.table_from([convert(v) for v in value])
        return value
    lua.globals().Definitions=convert(definitions);lua.globals().Sites=convert(catalog['sites'])
    lua.globals().Native=lua.execute(code);lua.globals().MOD_DIR=str(PREFIX)
    lua.execute('package.path=MOD_DIR.."/?.lua;"..package.path')
    lua.execute((HERE/'engine.lua').read_text());lua.execute((HERE/'scenarios.lua').read_text())
    # Narrow source guards preserve unrelated scheduler/AI/cleanup/reward code.
    sys.path.insert(0,str(HERE.parent/'quest_marker_probe'));from probe_source import without_probe
    for name in ['dispatch_scanner.lua','cyberpsycho.lua','vip_waypoint.lua']:
        base=subprocess.check_output(['git','show',f'a15e4ea35eb738050f45fccf42360b86f96fa4fc:bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrol/{name}'],cwd=ROOT,text=True)
        assert without_probe((PREFIX/name).read_text())==base,name
    manifests=json.loads((ROOT/'assets/fixed_markers/compiled.json').read_text())
    for manifest in manifests.values():
        assert hashlib.sha256((ROOT/manifest['archive_path']).read_bytes()).hexdigest()==manifest['archive_sha256']
        for path,digest in manifest['authored_inputs'].items():assert hashlib.sha256((ROOT/path).read_bytes()).hexdigest()==digest
        assert manifest['roundtrip_validated'] and manifest['extracted_resource_bytes_compared']
    report={'native_game_execution':False,'sites':323,'fixed_map_pins':counts,'runtime_relocation_used':False,
        'existing_journal_topology_and_text_retained':True,'same_target_native_hash_position_objective_proof':True,
        'default_no_native_pin_falls_back_honestly':True,'manual_waypoint_never_written':True,
        'stale_tokens_and_background_owner_cleanup_scoped':True,'vip_pickup_delivery_and_cyberpsycho_stage_switch':True,
        'load_rediscovery_and_refused_deletion_retry':True,'gameplay_owners_unchanged':True}
    print('PASS: actual finite journal bank/native and Lua adapter: 323 sites/1556 fixed pins, same-position native proof, default no-pin fallback, VIP/CP stage switches, stale token/owner isolation, load/refused cleanup, manual waypoint preservation and preserved gameplay owners (engine boundaries mocked)')
    return report
if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--report',type=Path);args=parser.parse_args();report=main()
    if args.report:args.report.write_text(json.dumps(report,indent=2)+'\n')
