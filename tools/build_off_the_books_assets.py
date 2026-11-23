"""Compile the separate Off the Books journal and native readable-shard text.

Uses the existing fixed journal-pin schema and Andrea Olivato's MIT onscreen
folder schema. Does not rebuild or edit the working Voss scene/media archive.
"""
from pathlib import Path
import argparse,copy,hashlib,json,shutil,subprocess,sys,tempfile
ROOT=Path(__file__).resolve().parents[1];DIR=ROOT/'assets/off_the_books'
sys.path.insert(0,str(ROOT/'tools'))
from build_quest_giver_assets import resource,cn,fnv,renumber

def read(name):return json.loads((DIR/name).read_text())
def outputs():
    c=read('contract.json')
    journal=json.loads((ROOT/'assets/quest_giver_test/quest_giver.journal.json').read_text())
    entry=journal['Data']['RootChunk']['entry']['Data'];entry['entries']=entry['entries'][:1]
    quest=entry['entries'][0]['Data']['entries'][0]['Data']
    quest['id']='ncpd_patrol_off_the_books';quest['title']['value']='NCPDPatrol_OTB_Title'
    phase=quest['entries'][0]['Data'];template=copy.deepcopy(phase['entries'][0]);phase['entries']=[]
    original=json.loads((ROOT/'assets/quest_giver_test/contract.json').read_text())['position']
    for name,key,position in [('eliminate','Eliminate',c['actors'][0]),('retrieve','Retrieve',c['actors'][0]),('escape','Escape',None),('return','Return',c['voss'])]:
        wrapped=copy.deepcopy(template);obj=wrapped['Data'];obj['id']=name;obj['description']['value']='NCPDPatrol_OTB_'+key
        description=obj['entries'][0]['Data'];description['description']['value']='NCPDPatrol_OTB_Description'
        if position is None:obj['entries']=obj['entries'][:1]
        else:
            pin=obj['entries'][1]['Data'];pin['mappinData']['active']=0
            for axis in ['x','y','z']:pin['offset'][axis.upper()]+=position[axis]-original[axis]
        phase['entries'].append(wrapped)
    shard={'HandleId':'pending','Data':{'$type':'gameJournalOnscreen','id':'evidence01','journalEntryOverrideDataList':[],
        'title':{'unk1':'0','value':'NCPDPatrol_OTB_ShardTitle'},'description':{'unk1':'0','value':'NCPDPatrol_OTB_ShardBody'},
        'iconID':{'$type':'TweakDBID','$storage':'uint64','$value':'0'},'tag':cn('None')}}
    def folder(typ,name,child):return {'HandleId':'pending','Data':{'$type':typ,'id':name,'journalEntryOverrideDataList':[],'entries':[child]}}
    shard=folder('gameJournalOnscreenGroup','onscreens',shard)
    for name in ['ncpd_patrol_off_the_books','quests','emails']:shard=folder('gameJournalFolderEntry',name,shard)
    entry['entries'].append(folder('gameJournalPrimaryFolderEntry','onscreens',shard));renumber(journal)
    onscreens=resource('JsonResource',root={'HandleId':'0','Data':{'$type':'localizationPersistenceOnScreenEntries',
        'entries':[{'$type':'localizationPersistenceOnScreenEntry','primaryKey':fnv('NCPDPatrol_OTB_'+k),'secondaryKey':'NCPDPatrol_OTB_'+k,'femaleVariant':v,'maleVariant':v} for k,v in c['text'].items()]}})
    return {'off_the_books.journal.json':journal,'onscreens.json.json':onscreens}

def validate(docs):
    c=read('contract.json');j=docs['off_the_books.journal.json']['Data']['RootChunk']['entry']['Data']
    quest=j['entries'][0]['Data']['entries'][0]['Data'];assert quest['id']=='ncpd_patrol_off_the_books'
    objects=quest['entries'][0]['Data']['entries'];assert [x['Data']['id'] for x in objects]==['eliminate','retrieve','escape','return']
    assert len(objects[2]['Data']['entries'])==1
    for i in [0,1,3]:
        pin=objects[i]['Data']['entries'][1]['Data'];assert not pin['mappinData']['active'] and pin['reference']['reference']['$value']=='#coyote_performance_test'
    node=j['entries'][1]['Data'];path=node['id']
    while node.get('entries'):node=node['entries'][0]['Data'];path+='/'+node['id']
    assert path==c['shard_path'] and node['$type']=='gameJournalOnscreen'
    text={e['secondaryKey']:e['femaleVariant'] for e in docs['onscreens.json.json']['Data']['RootChunk']['root']['Data']['entries']}
    assert text['NCPDPatrol_OTB_ShardTitle']==c['text']['ShardTitle'] and text['NCPDPatrol_OTB_ShardBody']==c['text']['ShardBody']
    assert c['off_duty'] and not c['automatic_milestone_activation'] and len(c['actors'])==3

def main():
    p=argparse.ArgumentParser();p.add_argument('--wk-cli',type=Path);p.add_argument('--check',action='store_true');a=p.parse_args()
    docs=outputs();validate(docs)
    for name,data in docs.items():
        text=json.dumps(data,indent=2)+'\n'
        if a.check:assert (DIR/name).read_text()==text,name
        else:(DIR/name).write_text(text)
    if not a.wk_cli:return
    def run(*args):subprocess.run([str(a.wk_cli.resolve()),*map(str,args)],check=True)
    with tempfile.TemporaryDirectory(prefix='ncpd-off-books-') as d:
        d=Path(d);packed=d/'NCPDPatrol_OffTheBooks';depot=packed/'base/ncpd_patrol/off_the_books';depot.mkdir(parents=True)
        back=d/'back';out=d/'out';extracted=d/'extracted'
        for target in [back,out,extracted]:target.mkdir()
        run('convert','deserialize',*[DIR/n for n in docs],'--outpath',depot)
        run('convert','serialize',*[depot/n[:-5] for n in docs],'--outpath',back)
        validate({n:json.loads((back/n).read_text(encoding='utf-8-sig')) for n in docs})
        expected={n[:-5]:(depot/n[:-5]).read_bytes() for n in docs}
        run('pack',packed,'--outpath',out);archive=out/'NCPDPatrol_OffTheBooks.archive'
        run('extract',archive,'--outpath',extracted)
        assert {p.name:p.read_bytes() for p in extracted.rglob('*') if p.is_file()}==expected
        target=ROOT/'archive/pc/mod'/archive.name;shutil.copy2(archive,target)
        inputs=[DIR/n for n in ['contract.json','records.json',*docs]]
        (DIR/'compiled.json').write_text(json.dumps({'archive_path':target.relative_to(ROOT).as_posix(),'archive_sha256':hashlib.sha256(target.read_bytes()).hexdigest(),
            'resources':sorted(expected),'roundtrip_validated':True,'extracted_resource_bytes_compared':True,
            'authored_inputs':{p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in inputs},'actual_game_validation':False},indent=2)+'\n')
    print('PASS: Off the Books quest journal, three fixed pins and native readable shard compiled, round-tripped and extracted; existing Voss archive untouched')

if __name__=='__main__':main()
