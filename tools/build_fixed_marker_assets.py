"""Author a finite marker bank inside existing journals; compile and round-trip.

No runtime relocation. Original journal topology/text is preserved after removing
only the added bank_* map-pin children. Input coordinate provenance is pinned.
"""
from pathlib import Path
import argparse,copy,hashlib,json,shutil,subprocess,tempfile
ROOT=Path(__file__).resolve().parents[1]
DIR=ROOT/'assets/fixed_markers'
KINDS={'dispatch':'NCPDPatrol_Dispatch','vip':'NCPDPatrol_VIP','cyberpsycho':'NCPDPatrol_Cyberpsycho'}

def walk(x):
    if isinstance(x,dict):
        yield x
        for value in x.values():yield from walk(value)
    elif isinstance(x,list):
        for value in x:yield from walk(value)

def strip_bank(doc):
    doc=copy.deepcopy(doc)
    for row in walk(doc):
        if row.get('$type')=='gameJournalQuestPhase':
            row['entries']=[h for h in row['entries'] if '_bank_' not in h['Data']['id']]
    return doc

def generate():
    sites=json.loads((DIR/'catalog.json').read_text())['sites']
    template=json.loads((ROOT/'assets/quest_marker_probe/reference.journal.json').read_text())
    pin=next(x for x in walk(template) if x.get('$type')=='gameJournalQuestMapPin')
    inputs={}
    for kind in KINDS:
        original=json.loads((ROOT/f'assets/{kind}/{kind}.journal.json').read_text())
        doc=copy.deepcopy(original)
        next_id=max(int(x['HandleId']) for x in walk(doc) if 'HandleId' in x)+1
        reference=json.loads((ROOT/'assets/quest_marker_probe/reference-contract.json').read_text())
        for phase in list(walk(doc)):
            if phase.get('$type')!='gameJournalQuestPhase':continue
            originals=list(phase['entries'])
            for handle in originals:
                objective=handle['Data']
                for site in sites:
                    if site['kind']!=('scanner' if kind=='dispatch' else 'terminal'):continue
                    selected=copy.deepcopy(objective);selected['id']=f"{objective['id']}_bank_{site['index']}"
                    selected_handle=str(next_id);next_id+=1
                    for child in selected['entries']:
                        child['HandleId']=str(next_id);next_id+=1
                    entry=copy.deepcopy(pin);entry['id']='location'
                    entry['slotName']['$value']='None'
                    # Avoid the null-NodeRef path that failed for scanner sites.
                    # Scanner XYZ is a fixed, authored offset from the proven
                    # Coyote world anchor; nothing is moved at runtime.
                    entry['reference']['reference']['$value']=site['node_ref'] or reference['node_reference']
                    xyz={'X':0.0,'Y':0.0,'Z':0.0} if site['node_ref'] else {
                        k.upper():v-reference['position'][k.upper()]+reference['offset'][k.upper()]
                        for k,v in site['position'].items()}
                    entry['offset']={'$type':'Vector3',**xyz}
                    entry['mappinData']['active']=0
                    entry['mappinData']['debugCaption']='NCPD DISPATCH'
                    entry['mappinData']['localizedCaption']=copy.deepcopy(objective['description'])
                    selected['entries'].append({'HandleId':str(next_id),'Data':entry});next_id+=1
                    phase['entries'].append({'HandleId':selected_handle,'Data':selected})
        assert strip_bank(doc)==original
        path=DIR/f'{kind}.journal.json';path.write_text(json.dumps(doc,separators=(',',':'))+'\n');inputs[kind]=path
    # Runtime coordinate matching does not rely on decoded marker ID strings.
    lua=['-- Generated from assets/fixed_markers/catalog.json; see THIRD_PARTY_NOTICES.txt.','return {']
    for s in sites:
        p=s['position'];lua.append('  {%d,%s,%s,%s,%s},'%(s['index'],'true' if s['kind']=='scanner' else 'false',p['x'],p['y'],p['z']))
    lua.append('}\n')
    (ROOT/'bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrol/marker_catalog.lua').write_text('\n'.join(lua))
    return inputs

def canonical(x):
    if isinstance(x,dict):return {k:canonical(v) for k,v in x.items() if k!='HandleId'}
    if isinstance(x,list):return [canonical(v) for v in x]
    return x

def validate(doc,kind,baseline=None):
    original=baseline or json.loads((ROOT/f'assets/{kind}/{kind}.journal.json').read_text())
    assert canonical(strip_bank(doc)['Data']['RootChunk'])==canonical(original['Data']['RootChunk']),'Non-marker journal data changed: '+kind
    sites={s['index']:s for s in json.loads((DIR/'catalog.json').read_text())['sites']}
    handles=[x['HandleId'] for x in walk(doc) if 'HandleId' in x];assert len(handles)==len(set(handles))
    count=0
    for objective in walk(doc):
        if objective.get('$type')!='gameJournalQuestObjective':continue
        entries=[h['Data'] for h in objective['entries'] if h['Data']['$type']=='gameJournalQuestMapPin']
        assert len(entries)<=1,'An objective must never expose a pool of pins'
        if '_bank_' not in objective['id']:
            assert not entries
            continue
        assert len(entries)==1 and entries[0]['id']=='location'
        for pin in entries:
            site=sites[int(objective['id'].rsplit('_bank_',1)[1])];assert site['kind']==('scanner' if kind=='dispatch' else 'terminal')
            assert pin['$type']=='gameJournalQuestMapPin' and pin['enableGPS']
            anchor=json.loads((ROOT/'assets/quest_marker_probe/reference-contract.json').read_text())
            reference=pin['reference']['reference']['$value']
            assert reference==(site['node_ref'] or anchor['node_reference'])
            expected={'X':0.0,'Y':0.0,'Z':0.0} if site['node_ref'] else {
                k.upper():v-anchor['position'][k.upper()]+anchor['offset'][k.upper()] for k,v in site['position'].items()}
            assert all(abs(pin['offset'][k]-v)<.001 for k,v in expected.items())
            assert not pin['mappinData']['active'] and pin['mappinData']['variant']=='QuestGiverVariant'
            count+=1
    return count

def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--wk-cli',type=Path);args=parser.parse_args()
    inputs=generate()
    if not args.wk_cli:
        print('Authored fixed marker bank; pass --wk-cli to compile');return
    manifests={}
    def run(*args_):subprocess.run([str(args.wk_cli),*map(str,args_)],check=True)
    for kind,name in KINDS.items():
        count=validate(json.loads(inputs[kind].read_text()),kind)
        with tempfile.TemporaryDirectory(prefix='ncpd-fixed-markers-') as temp:
            temp=Path(temp);packed=temp/name;depot=packed/f'base/ncpd_patrol/{kind}';depot.mkdir(parents=True)
            out=temp/'packed';out.mkdir();roundtrip=temp/'roundtrip';roundtrip.mkdir()
            base_dir=temp/'baseline';base_dir.mkdir();base_roundtrip=temp/'baseline-roundtrip';base_roundtrip.mkdir()
            run('convert','deserialize',ROOT/f'assets/{kind}/{kind}.journal.json','--outpath',base_dir)
            run('convert','serialize',base_dir/f'{kind}.journal','--outpath',base_roundtrip)
            baseline=json.loads((base_roundtrip/f'{kind}.journal.json').read_text(encoding='utf-8-sig'))
            texts=ROOT/f'assets/{kind}/{kind}_onscreens.json.json'
            for path in [inputs[kind],texts]:run('convert','deserialize',path,'--outpath',depot)
            expected={f'{kind}.journal':(depot/f'{kind}.journal').read_bytes(),f'{kind}_onscreens.json':(depot/f'{kind}_onscreens.json').read_bytes()}
            for resource in expected:run('convert','serialize',depot/resource,'--outpath',roundtrip)
            validate(json.loads((roundtrip/f'{kind}.journal.json').read_text(encoding='utf-8-sig')),kind,baseline)
            actual_rows=json.loads((roundtrip/f'{kind}_onscreens.json.json').read_text(encoding='utf-8-sig'))['Data']['RootChunk']['root']['Data']['entries']
            source_rows=json.loads(texts.read_text())['Data']['RootChunk']['root']['Data']['entries']
            assert len(actual_rows)==len(source_rows)
            for actual,source in zip(actual_rows,source_rows):
                for key,value in source.items():
                    assert (int(actual[key])==int(value)) if key=='primaryKey' else actual[key]==value, (kind,key)
            run('pack',packed,'--outpath',out)
            archive=out/(name+'.archive');extracted=temp/'extracted';extracted.mkdir();run('extract',archive,'--outpath',extracted)
            assert {p.name:p.read_bytes() for p in extracted.rglob('*') if p.is_file()}==expected
            target=ROOT/'archive/pc/mod'/archive.name;shutil.copy2(archive,target)
            manifest={'archive_path':target.relative_to(ROOT).as_posix(),'archive_sha256':hashlib.sha256(target.read_bytes()).hexdigest(),
                'resource_sha256':{k:hashlib.sha256(v).hexdigest() for k,v in expected.items()},
                'authored_inputs':{p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in [inputs[kind],texts,ROOT/f'assets/{kind}/{kind}.journal.json',DIR/'catalog.json']},
                'roundtrip_validated':True,'extracted_resource_bytes_compared':True,'fixed_map_pins':count,'original_objectives_and_text_retained':True,'one_pin_per_site_objective':True,'all_pin_definitions_inactive':True,'scanner_reference':'confirmed Coyote anchor plus fixed authored relative offsets'}
            manifests[kind]=manifest
            if kind=='vip':(ROOT/'assets/vip/compiled.json').write_text(json.dumps(manifest,indent=2)+'\n')
    (DIR/'compiled.json').write_text(json.dumps(manifests,indent=2)+'\n')
    print('Built three fixed-marker journal archives; '+str(sum(x['fixed_map_pins'] for x in manifests.values()))+' fixed pins')
if __name__=='__main__':main()
