"""Verified discovery imports append sites without changing existing quest identity."""
from pathlib import Path
import argparse,copy,hashlib,importlib.util,json,subprocess,sys
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1];sys.path.insert(0,str(HERE))
BASE='1535e5f408e1767272df3d7cd459a1a4de00cad7'
def old_json(name):return json.loads(subprocess.check_output(['git','show',f'{BASE}:{name}'],cwd=ROOT))
def main():
 spec=importlib.util.spec_from_file_location('expanded_sites',ROOT/'tools/build_officer_down_sites.py');b=importlib.util.module_from_spec(spec);spec.loader.exec_module(b)
 catalog=json.loads((ROOT/'assets/officer_down_sites/catalog.json').read_text());previous=old_json('assets/officer_down_sites/catalog.json')
 evidence=json.loads((ROOT/'assets/officer_down_sites/discovery_import.json').read_text())['sites']
 assert len(previous['sites'])==16 and len(catalog['sites'])==54 and len(evidence)==38
 assert catalog['sites'][:16]==previous['sites'],'Existing site/index/quest/position/heading changed'
 expected={'City Center':6,'Heywood':10,'Pacifica':2,'Santo Domingo':14,'Watson':6}
 actual={}
 for s in catalog['sites'][16:]:actual[s['district']]=actual.get(s['district'],0)+1
 assert actual==expected
 planned,accepted,duplicates=b.discovered_catalog(previous,evidence)
 assert planned==catalog and len(accepted)==38 and not duplicates
 assert b.discovered_catalog(catalog,evidence)[0]==catalog,'Import not idempotent'
 assert {r['index'] for r in catalog['sites']}==set(range(1,55))
 assert len({r['quest_root'] for r in catalog['sites']})==54
 for entry in catalog['sites'][16:]:
  proof=next(r for r in evidence if r['candidate']['id']==entry['id']);c=proof['candidate']
  assert entry['position']==c['position'] and entry['heading']==c['heading'] and entry['layout']=='compact'
  assert entry['source_report_sha256']==proof['source_report_sha256'] and entry['survey_timestamp']==proof['result']['timestamp']
  assert entry['source_index'] not in [202,234,263] and entry['source_type']=='terminal-offset-discovery'
 # Incomplete-run status does not invalidate already completed scene proofs.
 # Only explicitly verified compact candidates enter the importer.
 full={'schema':1,'layout_revision':'od-layout-v2','primary_validation_profile':b.PROFILE,
  'catalog_revision':evidence[0]['survey_catalog_revision'],'last_run':{'status':'return_started'},'sites':[],'verified_candidates':[]}
 for row in evidence:
  c=copy.deepcopy(row['candidate']);r=row['result']
  for key in ['samples','functional_validation','observed_seconds','cleanup_confirmed']:c[key]=copy.deepcopy(r[key])
  full['verified_candidates'].append(c);full['sites'].append({'site':c['id'],'variant':'compact','injured_functional_proven':copy.deepcopy(r)})
 standard=copy.deepcopy(full['verified_candidates'][0]);standard['variant']='standard';full['verified_candidates'].append(standard)
 assert b.discovery_evidence(full,evidence[0]['source_report_sha256'])==evidence
 # Rejected data cannot partially mutate the previous catalogue.
 mutations=[lambda r:r['result'].update(status='failed'),lambda r:r['result'].update(cleanup_confirmed=False),
  lambda r:r['result'].update(observed_seconds=1),lambda r:r['result']['functional_validation'].update(path_confirmed=False),
  lambda r:r['result']['functional_validation'].update(aid_distance=4),lambda r:r['result']['functional_validation'].update(revive_executed=True),
  lambda r:r['result']['samples'].pop(),lambda r:r['candidate']['position'].update(z=r['candidate']['position']['z']+5),
  lambda r:r['candidate'].update(heading=float('nan')),lambda r:r['candidate'].update(source_id='unknown-terminal'),
  lambda r:r['candidate'].update(variant='standard'),lambda r:r['result'].update(layout_revision='unverified-layout')]
 before=copy.deepcopy(previous)
 for change in mutations:
  broken=copy.deepcopy(evidence);change(broken[0])
  try:b.discovered_catalog(previous,broken)
  except (AssertionError,KeyError,TypeError,ValueError):pass
  else:raise AssertionError('Malformed/incomplete discovery proof accepted')
  assert previous==before
 # Nearby same-level centers deduplicate, while another floor is a distinct
 # place. Existing enabled/disabled states and stable paths survive reimport.
 clone=copy.deepcopy(previous);p=evidence[0]['candidate']['position'];entry=copy.deepcopy(previous['sites'][0]);entry.update(index=17,id='existing_nearby_scene',position=copy.deepcopy(p),quest_root='quests/minor_quest/existing_nearby_scene');clone['sites'].append(entry)
 _,accepted,duplicates=b.discovered_catalog(clone,evidence);assert len(accepted)==37 and duplicates==[{'id':evidence[0]['candidate']['id'],'existing':'existing_nearby_scene'}]
 clone['sites'][-1]['position']['z']+=3
 assert len(b.discovered_catalog(clone,evidence)[1])==38
 disabled=copy.deepcopy(catalog);disabled['sites'][16]['enabled']=False;assert b.discovered_catalog(disabled,evidence)[0]==disabled
 # Original journal chunks, including handles and reference offsets, remain
 # exactly equal. All new pins use the proven fixed-position anchor contract.
 previous_doc=old_json('assets/officer_down_sites/officer_down_sites.journal.json')
 current_doc=json.loads((ROOT/'assets/officer_down_sites/officer_down_sites.journal.json').read_text())
 previous_quests={r['id']:r for r in b.walk(previous_doc) if r.get('$type')=='gameJournalQuest'}
 current_quests={r['id']:r for r in b.walk(current_doc) if r.get('$type')=='gameJournalQuest'}
 assert len(previous_quests)==15 and len(current_quests)==53
 for qid,quest in previous_quests.items():assert current_quests[qid]==quest,qid
 assert b.validate(current_doc,catalog)==53
 for name in ['officer_down.lua','officer_down_layout.lua','officer_down_selection.lua','officer_down_actors.lua','officer_down_scene.lua','officer_down_log.lua','scene_survey.lua','scene_discovery.lua']:
  path='bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrol/'+name
  assert (ROOT/path).read_bytes()==subprocess.check_output(['git','show',f'{BASE}:{path}'],cwd=ROOT),name
 from check_catalog import case
 # The final appended index also survives CET recovery and save-load marker
 # cleanup; native catalogue boundary checks never assume the original 16.
 case('''local c,f=CF,F;c.staged(54)
package.loaded.officer_down=nil;c.use(require('officer_down'));c.step(.25)
assert(c.scene.isActive() and OfficerNative:GetCatalogIndex()==54);c.clear()''')
 case('''local c,f=CF,F;c.request(54);f.generation=f.generation+1;OfficerNative:OnRestored(0,0);c.step(.5)
assert(not c.scene.isActive());assert(f.manual==654 and f.wallet==0)
for i=0,f.pins.n-1 do assert(not f.pins[i].catalog or not f.pins[i].active) end''')
 print('PASS: append 38 proven compact discovery sites across five districts to 54 Officer Down targets; exact approved XYZ/headings, idempotent import, 16 stable old entries and 15 identical old quest chunks, rejected incomplete/standard/bad proofs, level-aware dedup, last-index CET/save cleanup and unchanged runtime selection/rewards (engine boundaries mocked)')
 return {'previous_sites_preserved':16,'imported_sites':38,'total_sites':54,'imported_by_district':expected,'new_quest_pins_appended':38,
  'prior_15_authored_quest_chunks_identical':True,'actual_approved_position_and_heading':True,'idempotent_import':True,
  'invalid_proofs_rejected':len(mutations),'last_index_cet_and_save_cleanup':True,'runtime_dispatch_logic_unchanged':True,
  'in_game_placement_evidence_imported':True,'actual_new_dispatch_gameplay_validation':False}
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--report',type=Path);a=p.parse_args();r=main()
 if a.report:a.report.write_text(json.dumps(r,indent=2)+'\n')
