"""Execute the real finite-bank controller and Lua navigation, mock engine APIs."""
from pathlib import Path
import argparse,hashlib,importlib.util,json,subprocess,sys,tempfile
from lupa.luajit21 import LuaRuntime
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
sys.path.insert(0,str(HERE.parent/'arrests'))
from translate import translate
PREFIX=ROOT/'bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrol'

# RED4ext Murmur3_32 seed; checked against both user-reported r5 hashes.
def journal_hash(text):
    data=text.encode();h=0x5eedba5e
    rot=lambda v,n:((v<<n)|(v>>(32-n)))&0xffffffff
    for i in range(0,len(data)//4*4,4):
        k=int.from_bytes(data[i:i+4],'little');k=k*0xcc9e2d51&0xffffffff;k=rot(k,15);k=k*0x1b873593&0xffffffff
        h^=k;h=rot(h,13);h=(h*5+0xe6546b64)&0xffffffff
    tail=data[len(data)//4*4:]
    if tail:
        k=int.from_bytes(tail,'little');k=k*0xcc9e2d51&0xffffffff;k=rot(k,15);k=k*0x1b873593&0xffffffff;h^=k
    h^=len(data);h^=h>>16;h=h*0x85ebca6b&0xffffffff;h^=h>>13;h=h*0xc2b2ae35&0xffffffff;h^=h>>16
    return h

def main():
    catalog=json.loads((ROOT/'assets/fixed_markers/catalog.json').read_text())
    assert len(catalog['sites'])==323 and {s['index'] for s in catalog['sites']}==set(range(1,324))
    assert sum(s['kind']=='scanner' for s in catalog['sites'])==132
    spec=importlib.util.spec_from_file_location('bank_assets',ROOT/'tools/build_fixed_marker_assets.py')
    builder=importlib.util.module_from_spec(spec);spec.loader.exec_module(builder)
    definitions=[];entries=[];counts={}
    for kind in builder.KINDS:
        doc=json.loads((ROOT/f'assets/fixed_markers/{kind}.journal.json').read_text());counts[kind]=builder.validate(doc,kind)
        folder=doc['Data']['RootChunk']['entry']['Data']['entries'][0]['Data']
        def collect(data,path,site=None):
            row={'path':path,'kind':data['$type'],'children':[path+'/'+h['Data']['id'] for h in data.get('entries',[])]}
            if site is not None:row['site']=site
            if data['$type']=='gameJournalQuestMapPin':
                row['active']=data['mappinData']['active']
            entries.append(row)
            for handle in data.get('entries',[]):
                child=handle['Data'];collect(child,path+'/'+child['id'],site)
        for handle in folder['entries']:
            quest=handle['Data'];root='quests/minor_quest/'+quest['id']
            entries.extend([{'path':root,'kind':'gameJournalQuest','children':[]},{'path':root+'/main','kind':'gameJournalQuestPhase','children':[]}])
            for objective_handle in quest['entries'][0]['Data']['entries']:
                objective=objective_handle['Data'];path=root+'/main/'+objective['id']
                site=int(objective['id'].rsplit('_bank_',1)[1]) if '_bank_' in objective['id'] else None
                collect(objective,path,site)
                if site is not None:definitions.append({'root':root,'objective':path,'path':path+'/location','site':site})
    assert counts=={'dispatch':792,'vip':382,'cyberpsycho':382}
    assert len(definitions)==1556 and all(not e.get('active',False) for e in entries)
    src=ROOT/'r6/scripts/NCPDPatrol/NCPDPatrolFixedMarkerSystem.reds';source=src.read_text()
    for forbidden in ['SetMappinPosition','TrackMappin','CustomPositionVariant','CreateEntity','GiveItem','m_paidActivities']:
        assert forbidden not in source,forbidden
    assert 'node.disablePreviousMappins = false' in source and 'node.id = Cast<Uint16>(0)' in source
    assert 'node.path = journalPath' in source and 'journalPath.fileEntryIndex = 1' in source
    assert 'system.ExecuteNode(node, n"Active")' in source and 'system.ExecuteNode(node, n"Inactive")' in source
    def executable(path):
        code=translate(path).replace('self:Root(scope) + ','self:Root(scope) .. ')
        code=code.replace('pin = pins[i]', 'pin = AsQuestMappin(pins[i])').replace('pin = linked', 'pin = AsQuestMappin(linked)')
        code=code.replace('tag = pins[i]:GetScriptData()', 'tag = AsFixedData(pins[i]:GetScriptData())')
        code=code.replace('IsDefined(live:GetScriptData())','IsDefined(AsFixedData(live:GetScriptData()))')
        code=code.replace('IsDefined(pin:GetScriptData())','IsDefined(AsFixedData(pin:GetScriptData()))')
        code=code.replace('new NCPDPatrolFixedMarkerData()', 'NewFixedData()').replace('new gameJournalPath()', 'NewJournalPath()').replace('new questMappinManagerNodeDefinition()', 'NewManagerNode()')
        for name in ['point','runtimePoint','questPoint']:code=code.replace('local '+name+' = nil','local '+name+' = Vector4.new(0,0,0,0)')
        # RED structs zero-initialize; Lua tables do not.
        code=code.replace('local empty = {}','local empty = {value=0}')
        code=code.replace('known = map:GetQuestMappinPosition(self.m_hash, point)','known, point = map:GetQuestMappinPosition(self.m_hash)')
        return code
    lua=LuaRuntime(unpack_returned_tuples=True)
    def convert(value):
        if isinstance(value,dict):return lua.table_from({k:convert(v) for k,v in value.items()})
        if isinstance(value,list):return lua.table_from([convert(v) for v in value])
        return value
    lua.globals().Definitions=convert(definitions);lua.globals().Entries=convert(entries);lua.globals().Sites=convert(catalog['sites'])
    # Native path hashing is an engine boundary. Use RED4ext's algorithm and
    # seed, independently checked against both actual r5 game logs.
    assert journal_hash('quests/minor_quest/ncpd_patrol_vip/main/pickup/bank_204')==764426284
    assert journal_hash('quests/minor_quest/ncpd_patrol_dispatch_4/main/resolve/bank_42')==1219236847
    owned=[d['path'] for d in definitions]+[d['objective'].rsplit('_bank_',1)[0]+'/bank_'+str(d['site']) for d in definitions]
    assert len({journal_hash(p) for p in owned})==3112,'Private bank hash collision'
    lua.globals().PathHash=journal_hash
    lua.globals().Native=lua.execute(executable(src));lua.globals().MOD_DIR=str(PREFIX)
    for file,name in [('NCPDPatrolDispatchJournalSystem.reds','ScannerNative'),('NCPDPatrolCyberpsychoSystem.reds','CyberNative'),('NCPDPatrolVIPSystem.reds','VIPNative')]:
        lua.globals()[name]=lua.execute(executable(ROOT/'r6/scripts/NCPDPatrol'/file))
    lua.execute('package.path=MOD_DIR.."/?.lua;"..package.path')
    lua.execute((HERE/'engine.lua').read_text());lua.execute((HERE/'scenarios.lua').read_text())
    # Known r5a implementation must fail both new regressions. These are
    # alternative documented engine states, not claims about this game dump.
    old_source=subprocess.check_output(['git','show','19e8b82ea1b42f4fbbdca031ea9e9365b82d6af5:r6/scripts/NCPDPatrol/NCPDPatrolFixedMarkerSystem.reds'],cwd=ROOT,text=True)
    negatives=[
        ("F:Reset();for _,d in ipairs(Definitions) do F:AddPin(F.entries[d.path].hash).active=false end;Native:OnRestored(0,0);Native:Tick(.25)", 'Engine-managed quest pins must not be unregistered'),
        ("F:Reset();F.entries[F.objective..'_bank_42'].state=2;F.entries[F.objective..'_bank_42/briefing'].state=2;F.attached=false;Native:OnRestored(0,0);local writes=#F.writes;Native:Tick(.25);assert(#F.writes==writes,'Detached player mutation')",'Detached player mutation'),
    ]
    with tempfile.TemporaryDirectory(prefix='ncpd-bank-r5a-regression-') as temp:
        old_path=Path(temp)/'r5a.reds';old_path.write_text(old_source)
        for scenario,expected in negatives:
            lua=LuaRuntime(unpack_returned_tuples=True)
            lua.globals().Definitions=convert(definitions);lua.globals().Entries=convert(entries);lua.globals().Sites=convert(catalog['sites'])
            lua.globals().PathHash=journal_hash;lua.globals().Native=lua.execute(executable(old_path))
            for file,name in [('NCPDPatrolDispatchJournalSystem.reds','ScannerNative'),('NCPDPatrolCyberpsychoSystem.reds','CyberNative'),('NCPDPatrolVIPSystem.reds','VIPNative')]:
                lua.globals()[name]=lua.execute(executable(ROOT/'r6/scripts/NCPDPatrol'/file))
            lua.execute((HERE/'engine.lua').read_text())
            try:lua.execute(scenario)
            except Exception as error:assert expected in str(error),str(error)
            else:raise AssertionError('r5a negative regression was not detected: '+expected)
    sys.path.insert(0,str(HERE.parent/'quest_marker_probe'));from probe_source import without_probe
    for name in ['dispatch_scanner.lua','cyberpsycho.lua','vip_waypoint.lua']:
        base=subprocess.check_output(['git','show',f'a15e4ea35eb738050f45fccf42360b86f96fa4fc:bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrol/{name}'],cwd=ROOT,text=True)
        assert without_probe((PREFIX/name).read_text())==base,name
    from owner_source import check_owners
    check_owners(ROOT)
    manifests=json.loads((ROOT/'assets/fixed_markers/compiled.json').read_text())
    for manifest in manifests.values():
        assert hashlib.sha256((ROOT/manifest['archive_path']).read_bytes()).hexdigest()==manifest['archive_sha256']
        for path,digest in manifest['authored_inputs'].items():assert hashlib.sha256((ROOT/path).read_bytes()).hexdigest()==digest
        assert manifest['roundtrip_validated'] and manifest['extracted_resource_bytes_compared']
    report={'native_game_execution':False,'sites':323,'fixed_map_pins':counts,'runtime_relocation_used':False,
        'original_objectives_and_text_retained':True,'same_target_native_hash_position_objective_proof':True,
        'default_no_native_pin_falls_back_honestly':True,'manual_waypoint_never_written':True,
        'stale_tokens_and_background_owner_cleanup_scoped':True,'vip_pickup_delivery_and_cyberpsycho_stage_switch':True,
        'load_rediscovery_and_refused_deletion_retry':True,'gameplay_actor_reward_and_result_methods_unchanged':True,'one_pin_per_site_objective':True,'all_pin_definitions_inactive':True,'mappin_manager_activation_explicit':True,'unexpected_and_legacy_bank_pins_pruned':True,'actual_native_owner_transitions_executed':True,'inactive_native_cache_retained':True,'same_id_native_reuse':True,'valid_native_retained_without_false_journal_confirmation':True,'pre_cleanup_snapshot_retained':True,'fallback_registration_liveness_observed':True,'detached_player_blocks_mutations':True,'r5a_negative_controls_detected':2}
    print('PASS: actual finite journal bank/native and Lua adapter: 323 sites/1556 fixed pins, same-position native proof, inactive definitions/single-pin objectives, explicit MappinManager activation, legacy/flood cleanup, default no-pin fallback, actual VIP/CP/scanner owner transitions, stale token/owner isolation, 1556 cached native instances/reuse without native unregistration, retained partial proof, preserved snapshot/fallback liveness, detached-world guards, two r5a negative controls, manual waypoint preservation and preserved gameplay owners (engine boundaries mocked)')
    return report
if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--report',type=Path);args=parser.parse_args();report=main()
    if args.report:args.report.write_text(json.dumps(report,indent=2)+'\n')
