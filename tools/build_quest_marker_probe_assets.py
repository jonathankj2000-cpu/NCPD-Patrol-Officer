"""Build/round-trip a private journal and passive ArchiveXL quest phase."""
from pathlib import Path
import argparse,hashlib,json,math,shutil,subprocess,tempfile
ROOT=Path(__file__).resolve().parents[1]
TAG='NCPDPatrol_QuestMarkerProbeAnchor'

def validate_phase(doc):
 contract=json.loads((ROOT/'assets/quest_marker_probe/phase-contract.json').read_text())
 handles={}
 def collect(value):
  if isinstance(value,dict):
   if 'HandleId' in value and isinstance(value.get('Data'),dict):
    assert value['HandleId'] not in handles;handles[value['HandleId']]=value['Data']
   for child in value.values():collect(child)
  elif isinstance(value,list):
   for child in value:collect(child)
 collect(doc)
 def key(h):return h.get('HandleId',h.get('HandleRefId'))
 def resolve(h):return handles[key(h)]
 root=doc['Data']['RootChunk'];assert root['$type']=='questQuestPhaseResource' and not root['phasePrefabs'] and not root['inplacePhases']
 graph=resolve(root['graph']);nodes={str(resolve(n)['id']):resolve(n) for n in graph['nodes']}
 assert {k:v['$type'] for k,v in nodes.items()}==contract['nodes']
 owners={key(s):int(n['id']) for n in nodes.values() for s in n['sockets']}
 edges=[]
 for ident,d in handles.items():
  if d['$type']=='graphGraphConnectionDefinition':
   source,destination=key(d['source']),key(d['destination'])
   assert source in owners and destination in owners
   assert [key(x) for x in handles[source]['connections']].count(ident)==1
   assert [key(x) for x in handles[destination]['connections']].count(ident)==1
   edges.append([owners[source],handles[source]['name']['$value'],owners[destination],handles[destination]['name']['$value']])
  if d['$type']=='gameJournalPath':
   assert d['fileEntryIndex']==2 and d['realPath'].startswith('quests/minor_quest/ncpd_patrol_marker_probe')
  if d['$type']=='questSetVar_NodeType':assert d['factName'].startswith(contract['fact_prefix']) and d['setExactValue']
  if d['$type']=='questVarComparison_ConditionType':assert d['factName']==contract['fact_prefix']+'request'
  if d['$type']=='questMappinManagerNodeDefinition':assert not d['disablePreviousMappins']
  if d['$type']=='questJournalEntry_NodeType':assert not d['sendNotification']
 assert sorted(edges)==sorted(contract['edges'])
 return contract

def validate(journal,texts,anchor,quest_phase):
 contract=validate_phase(quest_phase)
 root=journal['Data']['RootChunk'];folder=root['entry']['Data']['entries'][0]['Data']
 quest=folder['entries'][0]['Data'];assert len(folder['entries'])==1 and quest['id']=='ncpd_patrol_marker_probe'
 phase=quest['entries'][0]['Data'];objective=phase['entries'][0]['Data']
 assert len(phase['entries'])==1 and objective['id']=='inspect' and len(objective['entries'])==2
 pin=objective['entries'][1]['Data'];assert pin['$type']=='gameJournalQuestMapPin' and pin['id']=='location' and pin['enableGPS']
 assert pin['reference']['type']=='EntityRef' and not pin['reference']['names']
 assert pin['reference']['reference']['$value'] in ['0','']
 assert all(math.isclose(pin['offset'][k],v,abs_tol=.001) for k,v in contract['position'].items())
 assert not pin['mappinData']['active'] and pin['mappinData']['localizedCaption']['value']=='NCPDPatrol_MarkerProbe_Location'
 assert pin['slotName']['$value'] in ['', 'None'] and pin['mappinData']['mappinType']['$value']=='Mappins.QuestStaticMappinDefinition'
 assert pin['mappinData']['variant']=='DefaultQuestVariant' and 'CustomPositionVariant' not in json.dumps(root)
 rows=texts['Data']['RootChunk']['root']['Data']['entries'];assert len(rows)==4
 assert {x['secondaryKey'] for x in rows}=={'NCPDPatrol_MarkerProbe_'+x for x in ['Title','Objective','Description','Location']}
 a=anchor['Data']['RootChunk'];assert not a['components'] and not a['includes']
 assert a['entity']['Data']['$type']=='gameObject' and a['entity']['Data']['tags']['tags'][0]['$value']==TAG
 assert a['compiledData']['Data']['Chunks']==[a['entity']['Data']]
 assert all(doc['Data']['RootChunk']['cookingPlatform']=='PLATFORM_PC' for doc in [journal,texts,anchor,quest_phase])

def main():
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--wk-cli',type=Path,required=True);args=parser.parse_args()
 def run(*a):subprocess.run([str(args.wk_cli),*map(str,a)],check=True)
 names=['probe.journal','probe_onscreens.json','probe_anchor.ent','probe.questphase']
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
