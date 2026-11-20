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
        if row.get('$type')=='gameJournalQuestObjective':
            row['entries']=[h for h in row['entries'] if not h['Data']['id'].startswith('bank_')]
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
        for objective in list(walk(doc)):
            if objective.get('$type')!='gameJournalQuestObjective':continue
            for site in sites:
                if site['kind']!=('scanner' if kind=='dispatch' else 'terminal'):continue
                entry=copy.deepcopy(pin);entry['id']=f"bank_{site['index']}"
                entry['slotName']['$value']='None'
                entry['reference']['reference']['$value']=site['node_ref']
                xyz={'X':0.0,'Y':0.0,'Z':0.0} if site['node_ref'] else {k.upper():v for k,v in site['position'].items()}
                entry['offset']={'$type':'Vector3',**xyz}
                entry['mappinData']['debugCaption']='NCPD DISPATCH'
                entry['mappinData']['localizedCaption']=copy.deepcopy(objective['description'])
                objective['entries'].append({'HandleId':str(next_id),'Data':entry});next_id+=1
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
        entries=[h['Data'] for h in objective['entries'] if h['Data']['id'].startswith('bank_')]
        assert len(entries)==(132 if kind=='dispatch' else 191)
        assert len({p['id'] for p in entries})==len(entries)
        for pin in entries:
            site=sites[int(pin['id'][5:])];assert site['kind']==('scanner' if kind=='dispatch' else 'terminal')
            assert pin['$type']=='gameJournalQuestMapPin' and pin['enableGPS']
            reference=pin['reference']['reference']['$value']
            assert reference==site['node_ref'] or (not site['node_ref'] and reference in ['', '0']), (kind,site['index'],reference)
            expected={'X':0.0,'Y':0.0,'Z':0.0} if site['node_ref'] else {k.upper():v for k,v in site['position'].items()}
            assert all(abs(pin['offset'][k]-v)<.001 for k,v in expected.items())
            assert pin['mappinData']['active'] and pin['mappinData']['variant']=='QuestGiverVariant'
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
                'roundtrip_validated':True,'extracted_resource_bytes_compared':True,'fixed_map_pins':count,'original_journal_topology_and_text_retained':True}
            manifests[kind]=manifest
            if kind=='vip':(ROOT/'assets/vip/compiled.json').write_text(json.dumps(manifest,indent=2)+'\n')
    (DIR/'compiled.json').write_text(json.dumps(manifests,indent=2)+'\n')
    print('Built three fixed-marker journal archives; '+str(sum(x['fixed_map_pins'] for x in manifests.values()))+' fixed pins')
if __name__=='__main__':main()
