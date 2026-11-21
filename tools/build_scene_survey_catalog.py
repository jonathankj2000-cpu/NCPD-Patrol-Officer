"""Generate recorded survey candidates; this does not approve sites or add quests."""
from pathlib import Path
import argparse,hashlib,json,math
ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'assets/scene_survey/sites.json'
TARGET=ROOT/'bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrol/scene_survey_sites.lua'
def output():
 data=json.loads(SOURCE.read_text());sites=data['sites']
 assert data['schema']==1 and sites and len({s['id'] for s in sites})==len(sites)
 rows=[]
 for s in sites:
  p=s['position'];assert all(math.isfinite(p[k]) and abs(p[k])<100000 for k in ['x','y','z'])
  assert math.isfinite(s['heading']) and 0<=s['heading']<360
  rows.append('    {id=%s,label=%s,x=%.9f,y=%.9f,z=%.9f,heading=%.6f},'%(json.dumps(s['id']),json.dumps(s['label']),p['x'],p['y'],p['z'],s['heading']))
 digest=hashlib.sha256(SOURCE.read_bytes()).hexdigest()
 names=data['coverage'];coverage=(', '.join(names[:-1])+' and '+names[-1]) if len(names)>1 else names[0]
 return '-- Generated from assets/scene_survey/sites.json; candidates, not approved dispatch sites.\nreturn {schema=1,revision="'+digest+'",coverage='+json.dumps(coverage+' only')+',sites={\n'+'\n'.join(rows)+'\n}}\n'
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--check',action='store_true');a=p.parse_args();body=output()
 if a.check:assert TARGET.read_text()==body
 else:TARGET.write_text(body)
 print('PASS: recorded survey candidates and coverage; exact positions/headings preserved')
if __name__=='__main__':main()
