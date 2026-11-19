"""Build/check the optional Chinese text-provider overlay and journal resources.

Compile with --wk-cli /path/to/WolvenKit.CLI. Without it, validate the checked-in
round-tripped archive and deterministic install ZIP using the Python stdlib.
"""
from pathlib import Path
import argparse,copy,hashlib,json,re,subprocess,tempfile,zipfile

ROOT=Path(__file__).resolve().parents[1]
ADDON=ROOT/'addons/chinese-localization'
BASE='ff0d0024d85d31df783e5f989a1d2cb3d9cefbc1'
SCRIPT='r6/scripts/NCPDPatrol/NCPDPatrolLocalization.reds'
ARCHIVE='archive/pc/mod/NCPDPatrol_Chinese.archive'
XL=ARCHIVE+'.xl'
NAME='NCPD_Patrol_Chinese_Localization_Preview_v0.1a.zip'
REPORT='NCPD_Patrol_Chinese_Preview_v0.1a_verification.json'
DOCS=['NCPD_Patrol_Chinese_README.txt','NCPD_Patrol_Chinese_LICENSE.txt']

def sha(data):return hashlib.sha256(data).hexdigest()
def blob(data):return hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()
def jsonbytes(value):return (json.dumps(value,ensure_ascii=False,indent=2)+'\n').encode()
def resources(language):return f'base/ncpd_patrol/chinese/{language}/onscreens.json'

def expected_files():
 data=json.loads((ADDON/'translations.json').read_text())
 assert data['version']=='0.1a' and set(data['languages'])=={'zh-cn','zh-tw'}
 original=(ROOT/'r6/scripts/NCPDPatrol/NCPDPatrolLocalization.reds').read_text()
 keys=set(re.findall(r'this.Text\("([^"]+)"',original));assert len(keys)==19
 journal={}
 for group in ['dispatch','cyberpsycho','vip']:
  source=json.loads((ROOT/f'assets/{group}/{group}_onscreens.json.json').read_text())
  journal.update({row['secondaryKey']:row['femaleVariant'] for row in source['Data']['RootChunk']['root']['Data']['entries']})
 assert len(journal)==30
 anchor='        if Equals(language, n"en-us") { return new NCPDPatrolEnglishText(); }'
 assert original.count(anchor)==1
 localized=original.replace(anchor,anchor+'\n        if Equals(language, n"zh-cn") { return new NCPDPatrolChineseSimplifiedText(); }\n        if Equals(language, n"zh-tw") { return new NCPDPatrolChineseTraditionalText(); }')
 lines=[localized.rstrip(),'']
 generated={}
 for language,cls in [('zh-cn','NCPDPatrolChineseSimplifiedText'),('zh-tw','NCPDPatrolChineseTraditionalText')]:
  texts=data['languages'][language]
  assert set(texts['interactions'])==keys and set(texts['journal'])==set(journal)
  assert all(isinstance(s,str) and re.search(r'[\u3400-\u9fff]',s) for section in texts.values() for s in section.values())
  lines.extend([f'public class {cls} extends ModLocalizationPackage {{','    protected func DefineTexts() -> Void {'])
  for key,value in texts['interactions'].items():
   lines.append('        this.Text('+json.dumps(key)+', '+json.dumps(value,ensure_ascii=False)+');')
  lines.extend(['    }','}',''])
  document=copy.deepcopy(source)
  rows=[{'$type':'localizationPersistenceOnScreenEntry','primaryKey':'0','secondaryKey':key,'femaleVariant':value,'maleVariant':''} for key,value in texts['journal'].items()]
  document['Data']['RootChunk']['root']['Data']['entries']=rows
  generated[f'source/onscreens_{language}.json.json']=jsonbytes(document)
  for key,value in texts['journal'].items():
   if key.startswith('NCPDPatrol_Dispatch_Description'):assert '3' in value and '500' in value
  assert '3' in texts['journal']['NCPDPatrol_Cyberpsycho_ResponseDescription']
  assert '5' not in texts['journal']['NCPDPatrol_VIP_ResponseDescription']
 generated[SCRIPT]=('\n'.join(lines)).encode()
 generated[XL]=('localization:\n  onscreens:\n    zh-cn: '+resources('zh-cn').replace('/','\\')+'\n    zh-tw: '+resources('zh-tw').replace('/','\\')+'\n').encode()
 return generated

def compile_archive(cli,generated):
 def run(*args):
  result=subprocess.run([str(cli),*map(str,args)],capture_output=True,text=True)
  if result.returncode:raise RuntimeError(result.stdout[-5000:]+result.stderr[-5000:])
 with tempfile.TemporaryDirectory(prefix='ncpd-chinese-') as folder:
  tmp=Path(folder);depot=tmp/'depot';out=tmp/'out';roundtrip=tmp/'roundtrip';extract=tmp/'extract'
  out.mkdir();roundtrip.mkdir();extract.mkdir()
  expected={}
  for language in ['zh-cn','zh-tw']:
   path=resources(language);target=depot/Path(path).parent;target.mkdir(parents=True)
   run('convert','deserialize',ADDON/f'source/onscreens_{language}.json.json','--outpath',target)
   # WKit uses the source filename without the final .json extension.
   produced=target/f'onscreens_{language}.json'
   produced.rename(depot/path)
   binary=(depot/path).read_bytes();assert binary[:4]==b'CR2W';expected[path]=binary
   check=roundtrip/language;check.mkdir()
   run('convert','serialize',depot/path,'--outpath',check)
   actual=json.loads((check/'onscreens.json.json').read_text(encoding='utf-8-sig'))
   authored=json.loads(generated[f'source/onscreens_{language}.json.json'])
   assert actual['Data']['RootChunk']['root']['Data']['entries']==authored['Data']['RootChunk']['root']['Data']['entries']
  run('pack',depot,'--outpath',out)
  archives=list(out.glob('*.archive'));assert len(archives)==1
  run('extract',archives[0],'--outpath',extract)
  actual={p.relative_to(extract).as_posix():p.read_bytes() for p in extract.rglob('*') if p.is_file()}
  assert actual==expected
  target=ADDON/ARCHIVE;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(archives[0].read_bytes())
  authored={p:sha((ADDON/p).read_bytes()) for p in ['translations.json',*generated]}
  manifest={'version':'0.1a','compiler':'WolvenKit 9.1.1','archive_sha256':sha(target.read_bytes()),'authored_inputs':authored,
   'resources':{p:sha(value) for p,value in expected.items()},'roundtrip_entries_verified':True,'extracted_resource_bytes_verified':True}
  (ADDON/'compiled.json').write_bytes(jsonbytes(manifest))

def main():
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--wk-cli',type=Path);parser.add_argument('--check',action='store_true');args=parser.parse_args()
 generated=expected_files()
 for path,content in generated.items():
  target=ADDON/path
  if args.check:assert target.read_bytes()==content,'stale generated file: '+path
  else:target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(content)
 if args.wk_cli:compile_archive(args.wk_cli.resolve(),generated)
 manifest=json.loads((ADDON/'compiled.json').read_text())
 assert manifest['version']=='0.1a' and manifest['roundtrip_entries_verified'] and manifest['extracted_resource_bytes_verified']
 assert set(manifest['resources'])=={resources(lang) for lang in ['zh-cn','zh-tw']}
 for path,digest in manifest['authored_inputs'].items():assert sha((ADDON/path).read_bytes())==digest,'archive needs rebuild: '+path
 assert sha((ADDON/ARCHIVE).read_bytes())==manifest['archive_sha256']
 # Only the existing text provider is overlaid; no gameplay/quest graph changes.
 subprocess.run(['git','diff','--exit-code',BASE,'--','bin','r6','archive','LICENSE'],cwd=ROOT,check=True)
 paths=[SCRIPT,ARCHIVE,XL,*DOCS]
 main_paths=set(subprocess.check_output(['git','ls-tree','-r','--name-only',BASE,'--','bin','r6','archive','LICENSE','README.txt'],cwd=ROOT,text=True).splitlines())
 assert set(paths)&main_paths=={SCRIPT}
 payload={p:(ADDON/p).read_bytes() for p in paths}
 release=ROOT/'releases'/NAME;release.parent.mkdir(exist_ok=True)
 with tempfile.TemporaryDirectory(prefix='ncpd-chinese-zip-') as folder:
  archive=Path(folder)/NAME
  with zipfile.ZipFile(archive,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=9) as z:
   for path,data in sorted(payload.items()):
    info=zipfile.ZipInfo(path,(2026,11,19,0,0,0));info.compress_type=zipfile.ZIP_DEFLATED;info.create_system=3;info.external_attr=0o100644<<16
    z.writestr(info,data,compresslevel=9)
  zipdata=archive.read_bytes()
  with zipfile.ZipFile(archive) as z:
   assert z.testzip() is None and len(z.infolist())==5 and set(z.namelist())==set(payload)
   for path,data in payload.items():assert z.read(path)==data
  if args.check:assert release.read_bytes()==zipdata,'release ZIP does not match sources'
  else:release.write_bytes(zipdata)
 report={'addon_version':'0.1a','tested_main_version':'0.17d','base_commit':BASE,'languages':['zh-cn','zh-tw'],
  'interaction_and_item_keys_per_language':19,'journal_keys_per_language':30,'total_translations':98,
  'main_install_files_overwritten':[SCRIPT],'main_gameplay_and_resources_unchanged':True,'zip_path':'releases/'+NAME,
  'zip_bytes':len(zipdata),'zip_sha256':sha(zipdata),'zip_git_blob':blob(zipdata),'install_files':5,
  'archive_sha256':manifest['archive_sha256'],'archive_roundtrip_and_extraction_verified':True,
  'requires_base_mod':True,'english_fallback_preserved':True,'coverage':'interaction/button captions, Bean Bagger name/description, scanner/VIP/cyberpsycho journal entries',
  'still_english':['HUD and notifications','career pages','CET controls and logs','hardcoded popup headings/help'],
  'actual_game_validation':False,'native_speaker_review_completed':False,
  'files':{p:{'sha256':sha(data),'git_blob':blob(data)} for p,data in payload.items()}}
 reportpath=ROOT/'releases'/REPORT
 if args.check:assert json.loads(reportpath.read_text())==report,'verification report differs'
 else:reportpath.write_bytes(jsonbytes(report))
 print(json.dumps({k:v for k,v in report.items() if k!='files'},ensure_ascii=False,indent=2))
 print('PASS: 98 Chinese translations; exact existing keys; original English fallback; compiled/archive provenance; deterministic optional ZIP; only the text provider is overlaid')

if __name__=='__main__':main()
