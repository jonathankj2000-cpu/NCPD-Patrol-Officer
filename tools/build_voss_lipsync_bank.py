"""Merge the three supplied Voss banks without altering animation payloads.

Requires WolvenKit CLI for CR2W read/write; never runs in the game. Source
banks stay byte-identical. Only handles, buffers and chunk indices relocate.
"""
from pathlib import Path
import argparse,base64,copy,hashlib,json,subprocess,tempfile
ROOT=Path(__file__).resolve().parents[1];MEDIA=ROOT/'assets/quest_giver_test/media'
def walk(x):
    if isinstance(x,dict):
        yield x
        for v in x.values():yield from walk(v)
    elif isinstance(x,list):
        for v in x:yield from walk(v)
def canonical(x):
    x=copy.deepcopy(x)
    for v in walk(x):
        v.pop('HandleId',None)
        if 'BufferId' in v:v['BufferId']='buffer'
        if v.get('$type')=='animAnimDataAddress':v['unkIndex']=0
    return x
def merge(docs):
    out=copy.deepcopy(docs[0]);r=out['Data']['RootChunk'];r['animations']=[];r['animationDataChunks']=[]
    for doc in docs:
        s=copy.deepcopy(doc['Data']['RootChunk']);assert s['rig']==r['rig']
        assert all(v['HandleRefId']=='-1' for v in walk(s) if 'HandleRefId' in v)
        assert not any('BufferRefId' in v for v in walk(s))
        assert not any(v for k,v in s.items() if k.startswith('fallback'))
        offset=len(r['animationDataChunks'])
        for e in s['animations']:
            for v in walk(e):
                if v.get('$type')=='animAnimDataAddress':v['unkIndex']+=offset
        r['animations']+=s['animations'];r['animationDataChunks']+=s['animationDataChunks']
    h=b=0
    for v in walk(out):
        if 'HandleId'in v:v['HandleId']=str(h);h+=1
        if 'BufferId'in v:v['BufferId']=str(b);b+=1
    return out
def validate(docs,merged):
    r=merged['Data']['RootChunk'];assert len(r['animations'])==len(r['animationDataChunks'])==6
    for doc in docs:
        original=doc['Data']['RootChunk'];assert original['rig']==r['rig']
        for e in original['animations']:
            a=e['Data']['animation']['Data'];target=next(x for x in r['animations'] if x['Data']['animation']['Data']['name']==a['name'])
            assert canonical(e)==canonical(target),a['name']
            old=a['animBuffer']['Data']['dataAddress'];new=target['Data']['animation']['Data']['animBuffer']['Data']['dataAddress']
            assert original['animationDataChunks'][old['unkIndex']]['buffer']['Bytes']==r['animationDataChunks'][new['unkIndex']]['buffer']['Bytes']
def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--wk-cli',type=Path,required=True);a=p.parse_args()
    manifest=json.loads((MEDIA/'manifest.json').read_text());names=manifest['lipsync_merge']['source_banks']
    for n in names:assert hashlib.sha256((MEDIA/'source'/n).read_bytes()).hexdigest()==manifest['source_uploads'][n]['sha256']
    def run(*args):subprocess.run([str(a.wk_cli.resolve()),*map(str,args)],check=True)
    with tempfile.TemporaryDirectory(prefix='ncpd-voss-merge-') as d:
        d=Path(d);raw=d/'raw';out=d/'out';back=d/'back'
        for x in [raw,out,back]:x.mkdir()
        run('convert','serialize',*[MEDIA/'source'/n for n in names],'--outpath',raw)
        docs=[json.loads((raw/(n+'.json')).read_text(encoding='utf-8-sig')) for n in names]
        combined=merge(docs);validate(docs,combined);name=manifest['lipsync_merge']['merged_bank']
        path=raw/(name+'.json');path.write_text(json.dumps(combined,indent=2)+'\n')
        run('convert','deserialize',path,'--outpath',out);run('convert','serialize',out/name,'--outpath',back)
        validate(docs,json.loads((back/(name+'.json')).read_text(encoding='utf-8-sig')))
        body=(out/name).read_bytes();assert hashlib.sha256(body).hexdigest()==manifest['packaged'][name]['sha256'],'Generated bank differs from reviewed media manifest'
        (MEDIA/name).write_bytes(body)
    print('PASS: six source clips/chunks preserved through deterministic merge and CR2W roundtrip')
if __name__=='__main__':main()
