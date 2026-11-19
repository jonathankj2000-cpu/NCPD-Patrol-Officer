"""Build private probe journal/localization and a meshless tagged target anchor."""
from pathlib import Path
import argparse,hashlib,json,shutil,subprocess,tempfile
ROOT=Path(__file__).resolve().parents[1]
TAG='NCPDPatrol_QuestMarkerProbeAnchor'

def validate(journal,texts,anchor):
 root=journal['Data']['RootChunk'];folder=root['entry']['Data']['entries'][0]['Data']
 quest=folder['entries'][0]['Data'];assert len(folder['entries'])==1 and quest['id']=='ncpd_patrol_marker_probe'
 phase=quest['entries'][0]['Data'];objective=phase['entries'][0]['Data']
 assert len(phase['entries'])==1 and objective['id']=='inspect' and len(objective['entries'])==2
 pin=objective['entries'][1]['Data'];assert pin['$type']=='gameJournalQuestMapPin' and pin['id']=='location' and pin['enableGPS']
 assert pin['reference']['type']=='Tag' and pin['reference']['names'][0]['$value']==TAG
 assert pin['slotName']['$value'] in ['', 'None'] and pin['mappinData']['mappinType']['$value']=='Mappins.QuestStaticMappinDefinition'
 assert pin['mappinData']['variant']=='DefaultQuestVariant' and 'CustomPositionVariant' not in json.dumps(root)
 rows=texts['Data']['RootChunk']['root']['Data']['entries'];assert len(rows)==3
 assert {x['secondaryKey'] for x in rows}=={'NCPDPatrol_MarkerProbe_'+x for x in ['Title','Objective','Description']}
 a=anchor['Data']['RootChunk'];assert not a['components'] and not a['includes']
 assert a['entity']['Data']['$type']=='gameObject' and a['entity']['Data']['tags']['tags'][0]['$value']==TAG
 assert a['compiledData']['Data']['Chunks']==[a['entity']['Data']]
 assert all(doc['Data']['RootChunk']['cookingPlatform']=='PLATFORM_PC' for doc in [journal,texts,anchor])

def main():
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--wk-cli',type=Path,required=True);args=parser.parse_args()
 def run(*a):subprocess.run([str(args.wk_cli),*map(str,a)],check=True)
 names=['probe.journal','probe_onscreens.json','probe_anchor.ent']
 authored={n:ROOT/'assets/quest_marker_probe'/(n+'.json') for n in names}
 validate(*(json.loads(authored[n].read_text()) for n in names))
 with tempfile.TemporaryDirectory(prefix='ncpd-marker-assets-') as tmp:
  tmp=Path(tmp);packed=tmp/'NCPDPatrol_QuestMarkerProbe';depot=packed/'base/ncpd_patrol/quest_marker_probe';depot.mkdir(parents=True)
  roundtrip=tmp/'roundtrip';roundtrip.mkdir();out=tmp/'packed';out.mkdir()
  for n in names:
   run('convert','deserialize',authored[n],'--outpath',depot)
   run('convert','serialize',depot/n,'--outpath',roundtrip)
  validate(*(json.loads((roundtrip/(n+'.json')).read_text(encoding='utf-8-sig')) for n in names))
  expected={n:(depot/n).read_bytes() for n in names};assert all(v[:4]==b'CR2W' for v in expected.values())
  run('pack',packed,'--outpath',out)
  archive=out/'NCPDPatrol_QuestMarkerProbe.archive';extracted=tmp/'extracted';extracted.mkdir();run('extract',archive,'--outpath',extracted)
  assert {p.name:p.read_bytes() for p in extracted.rglob('*') if p.is_file()}==expected
  target=ROOT/'archive/pc/mod'/archive.name;shutil.copy2(archive,target)
  manifest={'archive_path':target.relative_to(ROOT).as_posix(),'archive_sha256':hashlib.sha256(target.read_bytes()).hexdigest(),
   'authored_inputs':{p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in authored.values()},
   'resources':{n:hashlib.sha256(data).hexdigest() for n,data in expected.items()},'roundtrip_validated':True,'extracted_resource_bytes_compared':True}
  (ROOT/'assets/quest_marker_probe/compiled.json').write_text(json.dumps(manifest,indent=2)+'\n')
  print('Built/round-trip checked private quest-marker probe archive')
if __name__=='__main__':main()
