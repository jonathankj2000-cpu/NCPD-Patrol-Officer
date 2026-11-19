"""Author an isolated, re-armable ArchiveXL quest phase for the marker test."""
from pathlib import Path
import copy,json
ROOT=Path(__file__).resolve().parents[1]
BASE='quests/minor_quest/ncpd_patrol_marker_probe'
FACT='ncpd_patrol_marker_probe_r4c_'
POSITION={'X':-1549.817505,'Y':-1544.082886,'Z':70.155853}

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
        p=alloc('gameJournalPath',realPath=path,fileEntryIndex=2,className=cname(kind),editorPath='')
        t=alloc('questJournalEntry_NodeType',path=ref(p),sendNotification=0)
        node(number,'questJournalNodeDefinition',[(s,'Input') for s in ['Active','Inactive','Succeeded','Failed']]+[('Out','Output')],type=ref(t))
    def marker(number):
        p=alloc('gameJournalPath',realPath=BASE+'/main/inspect/location',fileEntryIndex=2,className=cname('gameJournalQuestMapPin'),editorPath='')
        node(number,'questMappinManagerNodeDefinition',[('Active','Input'),('Inactive','Input'),('Out','Output')],path=ref(p),disablePreviousMappins=0)
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
    fact(15,'ready',4);wait(16,'Greater')
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
    return phase,{'fact_prefix':FACT,'ready_value':4,'position':POSITION,'edges':edges,
        'nodes':{str(objects[n['HandleRefId']]['id']):objects[n['HandleRefId']]['$type'] for n in nodes}}

def main():
    directory=ROOT/'assets/quest_marker_probe';phase,contract=generate()
    (directory/'probe.questphase.json').write_text(json.dumps(phase,indent=2)+'\n')
    (directory/'phase-contract.json').write_text(json.dumps(contract,indent=2)+'\n')
    path=directory/'probe.journal.json';doc=json.loads(path.read_text())
    def update(value):
        if isinstance(value,dict):
            if value.get('$type')=='gameJournalQuestMapPin':
                value['reference']['type']='EntityRef';value['reference']['names']=[]
                value['reference']['reference']={'$type':'NodeRef','$storage':'uint64','$value':'0'}
                value['offset']={'$type':'Vector3',**POSITION};value['mappinData']['active']=0
                value['mappinData']['localizedCaption']={'unk1':'0','value':'NCPDPatrol_MarkerProbe_Location'}
            for child in value.values():update(child)
        elif isinstance(value,list):
            for child in value:update(child)
    update(doc);path.write_text(json.dumps(doc,indent=2)+'\n')
    path=directory/'probe_onscreens.json.json';doc=json.loads(path.read_text())
    rows=doc['Data']['RootChunk']['root']['Data']['entries']
    for row in rows:
        if row['secondaryKey'].endswith('Description'):
            row['femaleVariant']='CET TEST ONLY. The archived quest phase activates one fixed native quest marker at the test location. Compare it with your manual waypoint and remove it through CET > Testing. No incident credit or payment is awarded.'
    if not any(r['secondaryKey']=='NCPDPatrol_MarkerProbe_Location' for r in rows):
        row=copy.deepcopy(rows[0]);row['secondaryKey']='NCPDPatrol_MarkerProbe_Location';row['femaleVariant']='NCPD marker test location';rows.append(row)
    path.write_text(json.dumps(doc,indent=2)+'\n')
    print('Authored isolated 22-node passive/re-armable phase and absolute-position journal pin')
if __name__=='__main__':main()
