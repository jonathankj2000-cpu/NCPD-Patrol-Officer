"""Compile and round-trip the private cyberpsycho journal/localization archive."""
from pathlib import Path
import argparse,hashlib,json,shutil,subprocess,tempfile
ROOT=Path(__file__).resolve().parents[1]
KEYS={f'NCPDPatrol_Cyberpsycho_{field}' for field in ['Title','Objective','Description','Name','ResponseObjective','ResponseDescription']}

def validate(journal,texts):
 root=journal['Data']['RootChunk'];assert root['$type']=='gameJournalResource'
 assert root['cookingPlatform']=='PLATFORM_PC'
 def data(v):return v['Data']
 entry=data(root['entry']);assert entry['$type']=='gameJournalRootFolderEntry'
 assert len(entry['entries'])==1
 folder=data(entry['entries'][0]);assert folder['id']=='quests/minor_quest' and len(folder['entries'])==1
 handle=folder['entries'][0];quest=data(handle)
 assert quest['$type']=='gameJournalQuest' and quest['id']=='ncpd_patrol_cyberpsycho' and quest['type']=='MinorQuest'
 assert len(quest['entries'])==1
 phase_handle=quest['entries'][0];phase=data(phase_handle)
 assert phase['$type']=='gameJournalQuestPhase' and phase['id']=='main' and len(phase['entries'])==2
 handles={v['HandleId'] for v in [root['entry'],entry['entries'][0],handle,phase_handle]}
 keys={quest['title']['value']}
 for objective_handle,identifier,suffix in zip(phase['entries'],['respond','neutralize'],['Response','']):
  objective=data(objective_handle)
  assert objective['$type']=='gameJournalQuestObjective' and objective['id']==identifier and not objective['optional']
  assert len(objective['entries'])==1
  description_handle=objective['entries'][0];description=data(description_handle)
  assert description['$type']=='gameJournalQuestDescription' and description['id']=='briefing'
  for h in [objective_handle,description_handle]:
   assert h['HandleId'] not in handles;handles.add(h['HandleId'])
  assert objective['description']['value']=='NCPDPatrol_Cyberpsycho_'+suffix+'Objective'
  assert description['description']['value']=='NCPDPatrol_Cyberpsycho_'+suffix+'Description'
  keys.update([objective['description']['value'],description['description']['value']])
 assert len(handles)==8 and keys==KEYS-{'NCPDPatrol_Cyberpsycho_Name'}
 tr=texts['Data']['RootChunk'];assert tr['$type']=='JsonResource' and tr['cookingPlatform']=='PLATFORM_PC'
 rows=data(tr['root'])['entries'];assert len(rows)==6 and {r['secondaryKey'] for r in rows}==KEYS
 assert all(r['femaleVariant'] and int(r['primaryKey'])==0 for r in rows)
 assert 'gameJournalQuestMapPin' not in json.dumps(root)

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--wk-cli',required=True,type=Path)
 p.add_argument('--resource-manifest',type=Path)
 p.add_argument('--output',type=Path,default=ROOT/'archive/pc/mod/NCPDPatrol_Cyberpsycho.archive');args=p.parse_args()
 cli=str(args.wk_cli.resolve())
 def run(*a):subprocess.run([cli,*map(str,a)],check=True)
 with tempfile.TemporaryDirectory(prefix='ncpd-cyberpsycho-build-') as d:
  tmp=Path(d);packed=tmp/'NCPDPatrol_Cyberpsycho';depot=packed/'base/ncpd_patrol/cyberpsycho';depot.mkdir(parents=True)
  roundtrip=tmp/'roundtrip';roundtrip.mkdir();out=tmp/'packed';out.mkdir()
  for filename in ['cyberpsycho.journal.json','cyberpsycho_onscreens.json.json']:
   run('convert','deserialize',ROOT/'assets/cyberpsycho'/filename,'--outpath',depot)
  expected={name:(depot/name).read_bytes() for name in ['cyberpsycho.journal','cyberpsycho_onscreens.json']}
  assert all(data[:4]==b'CR2W' for data in expected.values())
  for name in expected:run('convert','serialize',depot/name,'--outpath',roundtrip)
  validate(json.loads((roundtrip/'cyberpsycho.journal.json').read_text(encoding='utf-8-sig')),json.loads((roundtrip/'cyberpsycho_onscreens.json.json').read_text(encoding='utf-8-sig')))
  run('pack',packed,'--outpath',out)
  archive=out/'NCPDPatrol_Cyberpsycho.archive';extracted=tmp/'extracted';extracted.mkdir()
  run('extract',archive,'--outpath',extracted)
  files=[v for v in extracted.rglob('*') if v.is_file()]
  assert len(files)==2 and {v.name:v.read_bytes() for v in files}==expected
  args.output.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(archive,args.output)
  if args.resource_manifest:
   args.resource_manifest.write_text(json.dumps({name:hashlib.sha256(data).hexdigest() for name,data in expected.items()},indent=2)+'\n')
  print('Built and verified '+str(args.output))
if __name__=='__main__':main()
