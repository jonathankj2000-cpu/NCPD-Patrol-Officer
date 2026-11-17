"""Build and round-trip the one-objective dispatch journal/localization archive.
Developer tool only. Players install the compiled archive and .archive.xl.
WolvenKit CLI 9.1.1 requires .NET 10.
"""
from pathlib import Path
import argparse,json,shutil,subprocess,tempfile
ROOT=Path(__file__).resolve().parents[1]
KEYS={'NCPDPatrol_Dispatch_Title','NCPDPatrol_Dispatch_Objective','NCPDPatrol_Dispatch_Description'}

def validate(journal,texts):
 root=journal['Data']['RootChunk'];assert root['$type']=='gameJournalResource'
 assert root['cookingPlatform']=='PLATFORM_PC'
 def data(v):return v['Data']
 entry=data(root['entry']);assert entry['$type']=='gameJournalRootFolderEntry'
 folder=data(entry['entries'][0]);assert folder['id']=='quests/minor_quest'
 quest=data(folder['entries'][0]);assert quest['$type']=='gameJournalQuest' and quest['id']=='ncpd_patrol_dispatch' and quest['type']=='MinorQuest'
 phase=data(quest['entries'][0]);assert phase['$type']=='gameJournalQuestPhase' and phase['id']=='main'
 objective=data(phase['entries'][0]);assert objective['$type']=='gameJournalQuestObjective' and objective['id']=='resolve' and not objective['optional']
 description=data(objective['entries'][0]);assert description['$type']=='gameJournalQuestDescription' and description['id']=='briefing'
 assert all(len(v['entries'])==1 for v in [entry,folder,quest,phase,objective])
 assert {quest['title']['value'],objective['description']['value'],description['description']['value']}==KEYS
 tr=texts['Data']['RootChunk'];assert tr['$type']=='JsonResource' and tr['cookingPlatform']=='PLATFORM_PC'
 rows=data(tr['root'])['entries'];assert len(rows)==3 and {r['secondaryKey'] for r in rows}==KEYS
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
