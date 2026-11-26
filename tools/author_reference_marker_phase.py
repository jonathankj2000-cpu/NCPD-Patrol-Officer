"""Author the MIT-attributed Andrea Olivato reference chain in a private namespace."""
# Adapted resource layout: Cyberpunk.Codes Negative Balance, MIT, Andrea Olivato.
# See THIRD_PARTY_NOTICES.txt and assets/quest_marker_probe/reference-source.json.
from pathlib import Path
import copy,json
ROOT=Path(__file__).resolve().parents[1]
BASE='quests/street_stories/ncpd_patrol_marker_reference'
FACT='ncpd_patrol_marker_reference_r4d_'
POSITION={'X':-1259.598,'Y':-989.166,'Z':12.037}
OFFSET={'X':0.114500001,'Y':-0.294,'Z':-0.000199999995}
REFERENCE='#coyote_performance_test'

def generate():
    objects={};nodes=[];sockets={};edges=[]
    def alloc(kind,**props):
        key=str(len(objects));objects[key]={'$type':kind,**props};return key
    def ref(key):return {'HandleRefId':key}
    def cname(value):return {'$type':'CName','$storage':'string','$value':value}
    def node(number,kind,ports,**props):
        key=alloc(kind,id=number,sockets=[],**props);nodes.append(ref(key))
        for name,typ in [('CutDestination','CutDestination'),*ports]:
            socket=alloc('questSocketDefinition',connections=[],name=cname(name),type=typ)
            objects[key]['sockets'].append(ref(socket));sockets[number,name]=socket
        return key
    def journal(number,path,kind):
        p=alloc('gameJournalPath',realPath=path,fileEntryIndex=1,className=cname(kind),editorPath='')
        t=alloc('questJournalEntry_NodeType',path=ref(p),sendNotification=0)
        if number==20:
            objects[t].update({'$type':'questJournalQuestEntry_NodeType','optional':0,'version':'Initial','trackQuest':1,'sendNotification':1})
        node(number,'questJournalNodeDefinition',[(s,'Input') for s in ['Active','Inactive','Succeeded','Failed']]+[('Out','Output')],type=ref(t))
    def marker(number):
        journal(number,BASE+'/main/inspect/location','gameJournalQuestMapPin')
    def fact(number,name,value):
        t=alloc('questSetVar_NodeType',factName=FACT+name,value=value,setExactValue=1)
        node(number,'questFactsDBManagerNodeDefinition',[('In','Input'),('Out','Output')],type=ref(t))
    def wait(number,comparison):
        t=alloc('questVarComparison_ConditionType',factName=FACT+'request',comparisonType=comparison,value=0)
        c=alloc('questFactsDBCondition',type=ref(t))
        node(number,'questPauseConditionNodeDefinition',[('In','Input'),('Out','Output')],condition=ref(c))
    def link(a,out,b,inp):
        source,destination=sockets[a,out],sockets[b,inp]
        key=alloc('graphGraphConnectionDefinition',source=ref(source),destination=ref(destination))
        objects[source]['connections'].append(ref(key));objects[destination]['connections'].append(ref(key))
        edges.append([a,out,b,inp])
    graph=alloc('questGraphDefinition',nodes=nodes)
    node(0,'questInputNodeDefinition',[('Out','Output')],socketName=cname('In1'))
    node(1,'questOutputNodeDefinition',[('In','Input')],socketName=cname('Out1'),type='Terminating')
    # Root attachment starts passive and cleans any saved previous experiment.
    fact(2,'ready',0);fact(3,'request',0)
    for base in [10,30]:
        marker(base)
        journal(base+1,BASE+'/main/inspect','gameJournalQuestObjective')
        journal(base+2,BASE+'/main','gameJournalQuestPhase')
        journal(base+3,BASE,'gameJournalQuest')
        fact(base+4,'stage',0)
    fact(15,'ready',5);wait(16,'Greater')
    journal(20,BASE,'gameJournalQuest');journal(21,BASE+'/main','gameJournalQuestPhase')
    journal(22,BASE+'/main/inspect','gameJournalQuestObjective');marker(23)
    fact(24,'stage',1);wait(25,'Equal')
    link(0,'Out',2,'In');link(2,'Out',3,'In');link(3,'Out',10,'Inactive')
    for base in [10,30]:
        link(base,'Out',base+1,'Inactive');link(base+1,'Out',base+2,'Inactive')
        link(base+2,'Out',base+3,'Inactive');link(base+3,'Out',base+4,'In')
    link(14,'Out',15,'In');link(15,'Out',16,'In')
    link(16,'Out',20,'Active');link(20,'Out',21,'Active');link(21,'Out',22,'Active')
    link(22,'Out',23,'Active');link(23,'Out',24,'In');link(24,'Out',25,'In')
    link(25,'Out',30,'Inactive');link(34,'Out',16,'In')
    emitted=set()
    def emit(value):
        if isinstance(value,list):return [emit(v) for v in value]
        if isinstance(value,dict):
            if 'HandleRefId' in value:
                key=value['HandleRefId']
                if key in emitted:return ref(key)
                emitted.add(key);return {'HandleId':key,'Data':emit(objects[key])}
            return {k:emit(v) for k,v in value.items()}
        return value
    header={'WolvenKitVersion':'9.1.1','WKitJsonVersion':'0.0.9','GameVersion':2500,'DataType':'CR2W'}
    phase={'Header':header,'Data':{'Version':195,'BuildVersion':0,'RootChunk':{
        '$type':'questQuestPhaseResource','cookingPlatform':'PLATFORM_PC',
        'graph':emit(ref(graph)),'inplacePhases':[],'phasePrefabs':[]},'EmbeddedFiles':[]}}
    return phase,{'fact_prefix':FACT,'ready_value':5,'file_entry_index':1,'quest_root':BASE,'node_reference':REFERENCE,'offset':OFFSET,'variant':'QuestGiverVariant','position':POSITION,'edges':edges,
        'nodes':{str(objects[n['HandleRefId']]['id']):objects[n['HandleRefId']]['$type'] for n in nodes}}

def main():
    directory=ROOT/'assets/quest_marker_probe';phase,contract=generate()
    (directory/'reference.questphase.json').write_text(json.dumps(phase,indent=2)+'\n')
    (directory/'reference-contract.json').write_text(json.dumps(contract,indent=2)+'\n')
    path=directory/'reference.journal.json';doc=json.loads((directory/'probe.journal.json').read_text())
    folder=doc['Data']['RootChunk']['entry']['Data']['entries'][0]['Data']
    folder['id']='quests/street_stories'
    quest=folder['entries'][0]['Data'];quest['id']='ncpd_patrol_marker_reference';quest['type']='StreetStory';quest['districtID']='Districts.Heywood';quest['recommendedLevelID']={'$type':'TweakDBID','$storage':'uint64','$value':'0'}
    def update(value):
        if isinstance(value,dict):
            if value.get('$type')=='gameJournalQuestMapPin':
                value['reference']['type']='EntityRef';value['reference']['names']=[]
                value['reference']['reference']={'$type':'NodeRef','$storage':'string','$value':REFERENCE}
                for key in ['slotName','sceneActorContextName','dynamicEntityUniqueName']:
                    value['reference'][key]={'$type':'CName','$storage':'string','$value':'None'}
                value['slotName']={'$type':'CName','$storage':'string','$value':'UI_Interaction'}
                value['uiAnimation']={'$type':'TweakDBID','$storage':'uint64','$value':'0'}
                value['mappinData']['scriptData']=None
                value['offset']={'$type':'Vector3',**OFFSET};value['mappinData']['active']=1;value['mappinData']['variant']='QuestGiverVariant'
                value['mappinData']['localizedCaption']={'unk1':'0','value':'NCPDPatrol_MarkerReference_Location'}
            for child in value.values():update(child)
        elif isinstance(value,list):
            for child in value:update(child)
    update(doc)
    def rename_keys(x):
        if isinstance(x,dict):
            for k,v in x.items():
                if isinstance(v,str):x[k]=v.replace('NCPDPatrol_MarkerProbe_','NCPDPatrol_MarkerReference_')
                else:rename_keys(v)
        elif isinstance(x,list):
            for v in x:rename_keys(v)
    rename_keys(doc);path.write_text(json.dumps(doc,indent=2)+'\n')
    path=directory/'reference_onscreens.json.json';doc=json.loads((directory/'probe_onscreens.json.json').read_text());rename_keys(doc)
    rows=doc['Data']['RootChunk']['root']['Data']['entries']
    for row in rows:
        if row['secondaryKey'].endswith('Description'):
            row['femaleVariant']='CET REFERENCE TEST. A private quest uses the journal-pin activation and world anchor from Andrea Olivato Negative Balance reference. Inspect the map near El Coyote Cojo, then remove through CET. No incident credit or payment is awarded.'
    if not any(r['secondaryKey']=='NCPDPatrol_MarkerReference_Location' for r in rows):
        row=copy.deepcopy(rows[0]);row['secondaryKey']='NCPDPatrol_MarkerReference_Location';row['femaleVariant']='NCPD marker test location';rows.append(row)
    path.write_text(json.dumps(doc,indent=2)+'\n')
    print('Authored isolated 22-node reference phase and NodeRef-based journal pin')
if __name__=='__main__':main()
