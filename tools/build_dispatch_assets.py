"""Build and round-trip the one-objective dispatch journal/localization archive.
Developer tool only. Players install the compiled archive and .archive.xl.
WolvenKit CLI 9.1.1 requires .NET 10.
"""
from pathlib import Path
import argparse,json,shutil,subprocess,tempfile
ROOT=Path(__file__).resolve().parents[1]
KEYS={f'NCPDPatrol_Dispatch_{field}'+('' if i==0 else f'_{i}') for i in range(6) for field in ['Title','Objective','Description']}

def validate(journal,texts):
 root=journal['Data']['RootChunk'];assert root['$type']=='gameJournalResource'
 assert root['cookingPlatform']=='PLATFORM_PC'
 def data(v):return v['Data']
 entry=data(root['entry']);assert entry['$type']=='gameJournalRootFolderEntry'
 folder=data(entry['entries'][0]);assert folder['id']=='quests/minor_quest'
 assert len(entry['entries'])==1 and len(folder['entries'])==6
 used_keys=set();handles={'0','1'}
 for i,handle in enumerate(folder['entries']):
  quest=data(handle);suffix='' if i==0 else f'_{i}'
  assert quest['$type']=='gameJournalQuest' and quest['id']=='ncpd_patrol_dispatch'+suffix and quest['type']=='MinorQuest'
  phase_handle=quest['entries'][0];phase=data(phase_handle);assert phase['$type']=='gameJournalQuestPhase' and phase['id']=='main'
  objective_handle=phase['entries'][0];objective=data(objective_handle);assert objective['$type']=='gameJournalQuestObjective' and objective['id']=='resolve' and not objective['optional']
  description_handle=objective['entries'][0];description=data(description_handle);assert description['$type']=='gameJournalQuestDescription' and description['id']=='briefing'
  assert all(len(v['entries'])==1 for v in [quest,phase,objective])
  for v in [handle,phase_handle,objective_handle,description_handle]:
   assert v['HandleId'] not in handles;handles.add(v['HandleId'])
  keys={quest['title']['value'],objective['description']['value'],description['description']['value']}
  assert keys=={f'NCPDPatrol_Dispatch_{field}'+suffix for field in ['Title','Objective','Description']}
  assert not keys & used_keys;used_keys.update(keys)
 assert used_keys==KEYS
 tr=texts['Data']['RootChunk'];assert tr['$type']=='JsonResource' and tr['cookingPlatform']=='PLATFORM_PC'
 rows=data(tr['root'])['entries'];assert len(rows)==18 and {r['secondaryKey'] for r in rows}==KEYS
 assert all(r['femaleVariant'] and int(r['primaryKey'])==0 for r in rows)
 serialized=json.dumps(root)
 assert 'gameJournalQuestMapPin' not in serialized and 'generic_gameplay_quest' not in serialized

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--wk-cli',required=True,type=Path)
 p.add_argument('--output',type=Path,default=ROOT/'archive/pc/mod/NCPDPatrol_Dispatch.archive');args=p.parse_args()
 cli=str(args.wk_cli.resolve())
 def run(*a):subprocess.run([cli,*map(str,a)],check=True)
 with tempfile.TemporaryDirectory(prefix='ncpd-journal-build-') as d:
  tmp=Path(d);packed=tmp/'NCPDPatrol_Dispatch';depot=packed/'base/ncpd_patrol/dispatch';depot.mkdir(parents=True)
  roundtrip=tmp/'roundtrip';roundtrip.mkdir();out=tmp/'packed';out.mkdir()
  for filename in ['dispatch.journal.json','dispatch_onscreens.json.json']:
   run('convert','deserialize',ROOT/'assets/dispatch'/filename,'--outpath',depot)
  expected={name:(depot/name).read_bytes() for name in ['dispatch.journal','dispatch_onscreens.json']}
  assert all(data[:4]==b'CR2W' for data in expected.values())
  for name in expected:run('convert','serialize',depot/name,'--outpath',roundtrip)
  validate(json.loads((roundtrip/'dispatch.journal.json').read_text(encoding='utf-8-sig')),json.loads((roundtrip/'dispatch_onscreens.json.json').read_text(encoding='utf-8-sig')))
  run('pack',packed,'--outpath',out)
  archive=out/'NCPDPatrol_Dispatch.archive';extracted=tmp/'extracted';extracted.mkdir()
  run('extract',archive,'--outpath',extracted)
  files=[v for v in extracted.rglob('*') if v.is_file()]
  assert len(files)==2 and {v.name:v.read_bytes() for v in files}==expected
  args.output.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(archive,args.output)
  print('Built and verified '+str(args.output))
if __name__=='__main__':main()
