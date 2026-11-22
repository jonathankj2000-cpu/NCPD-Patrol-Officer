"""Author a silent, native two-choice scene and its isolated rearmable quest.

Minimal scene schemas adapted from Andrea Olivato's MIT fixer01 reference.
No original story, voice, animation, community or streaming assets are shipped.
"""
from pathlib import Path
import argparse,copy,hashlib,json,math,shutil,subprocess,tempfile

ROOT=Path(__file__).resolve().parents[1];DIR=ROOT/'assets/quest_giver_test'
DEPOT='base\\ncpd_patrol\\quest_giver_test\\'
def read(name):return json.loads((DIR/name).read_text())
def cn(s):return {'$type':'CName','$storage':'string','$value':s}
def rid(typ,n):return {'$type':typ,'id':n}
def resource(typ,**fields):
    return {'Header':{'WolvenKitVersion':'9.1.1','WKitJsonVersion':'0.0.9','GameVersion':2500,'DataType':'CR2W'},
        'Data':{'Version':195,'BuildVersion':0,'RootChunk':{'$type':typ,'cookingPlatform':'PLATFORM_PC',**fields},'EmbeddedFiles':[]}}
def fnv(s):
    h=14695981039346656037
    for b in s.encode():h=((h^b)*1099511628211)&((1<<64)-1)
    return str(h)
def walk(x):
    if isinstance(x,dict):
        yield x
        for v in x.values():yield from walk(v)
    elif isinstance(x,list):
        for v in x:yield from walk(v)
def renumber(doc):
    handles=[x for x in walk(doc) if 'HandleId' in x]
    assert not any('HandleRefId' in x for x in walk(doc))
    for i,x in enumerate(handles):x['HandleId']=str(i)
    return doc

class Graph:
    def __init__(self):self.objects={};self.nodes=[];self.sockets={};self.edges=[]
    def alloc(self,typ,**props):
        k=str(len(self.objects));self.objects[k]={'$type':typ,**props};return {'HandleRefId':k}
    def obj(self,ref):return self.objects[ref['HandleRefId']]
    def node(self,n,typ,ports,**props):
        ref=self.alloc(typ,id=n,sockets=[],**props);self.nodes.append(ref)
        for name,kind in [('CutDestination','CutDestination'),*ports]:
            s=self.alloc('questSocketDefinition',connections=[],name=cn(name),type=kind)
            self.obj(ref)['sockets'].append(s);self.sockets[n,name]=s
        return ref
    def link(self,a,out,b,inp):
        source,destination=self.sockets[a,out],self.sockets[b,inp]
        edge=self.alloc('graphGraphConnectionDefinition',source=source,destination=destination)
        self.obj(source)['connections'].append(edge);self.obj(destination)['connections'].append(edge)
        self.edges.append([a,out,b,inp])
    def emit(self,ref):
        emitted=set()
        def expand(x):
            if isinstance(x,list):return [expand(v) for v in x]
            if isinstance(x,dict):
                if 'HandleRefId' in x:
                    k=x['HandleRefId']
                    if k in emitted:return x
                    emitted.add(k);return {'HandleId':k,'Data':expand(self.objects[k])}
                return {k:expand(v) for k,v in x.items()}
            return x
        return expand(ref)

def phase(c):
    g=Graph();fact=c['fact_prefix'];base=c['quest_root']
    def setfact(n,key,value):
        t=g.alloc('questSetVar_NodeType',factName=fact+key,value=value,setExactValue=1)
        g.node(n,'questFactsDBManagerNodeDefinition',[('In','Input'),('Out','Output')],type=t)
    def condition(key,comparison,value):
        t=g.alloc('questVarComparison_ConditionType',factName=fact+key,comparisonType=comparison,value=value)
        return g.alloc('questFactsDBCondition',type=t)
    def wait(n,key,comparison,value):
        g.node(n,'questPauseConditionNodeDefinition',[('In','Input'),('Out','Output')],condition=condition(key,comparison,value))
    def journal(n,path,typ):
        p=g.alloc('gameJournalPath',realPath=path,fileEntryIndex=1,className=cn(typ),editorPath='')
        t=g.alloc('questJournalEntry_NodeType',path=p,sendNotification=1)
        g.node(n,'questJournalNodeDefinition',[(k,'Input') for k in ['Active','Inactive','Succeeded','Failed']]+[('Out','Output')],type=t)
    def cut(n):g.node(n,'questCutControlNodeDefinition',[('In','Input'),('Out','Output'),('CutSource','CutSource')],permanent=0)
    def marker(n):
        p=g.alloc('gameJournalPath',realPath=base+'/main/talk/location',fileEntryIndex=1,className=cn('gameJournalQuestMapPin'),editorPath='')
        g.node(n,'questMappinManagerNodeDefinition',[('Active','Input'),('Inactive','Input'),('Out','Output')],path=p,disablePreviousMappins=0)
    graph=g.alloc('questGraphDefinition',nodes=g.nodes)
    g.node(0,'questInputNodeDefinition',[('Out','Output')],socketName=cn('In1'))
    setfact(1,'stage',0);setfact(2,'ready',1);wait(3,'request','Greater',0);setfact(4,'ready',0)
    for n,path,typ in [(5,base,'gameJournalQuest'),(6,base+'/main','gameJournalQuestPhase'),(7,base+'/main/talk','gameJournalQuestObjective')]:journal(n,path,typ)
    setfact(8,'stage',1);wait(9,'talk','Greater',0);wait(10,'request','Equal',0);setfact(11,'stage',2)
    g.node(12,'questSceneNodeDefinition',[('conversation_in','Input'),('conversation_out','Output'),('Default INT','Output'),('Default RET','Output'),('Prefetch','Input')],
        sceneFile={'DepotPath':{'$type':'ResourcePath','$storage':'string','$value':DEPOT+'conversation.scene'},'Flags':'Soft'},
        sceneLocation={'$type':'scnWorldMarker','nodeRef':{'$type':'NodeRef','$storage':'uint64','$value':'0'},'tag':cn(c['tag']+'_npc'),'type':'Tag'},
        interruptionOperations=[],notAllowedToBeFrozen=0,reapplyInterruptionOperationsAfterGameLoad=0,syncToMusic=0)
    g.node(13,'questConditionNodeDefinition',[('In','Input'),('True','Output'),('False','Output')],condition=condition('choice','Greater',0))
    cut(14)
    for n,path,typ in [(15,base+'/main/talk','gameJournalQuestObjective'),(16,base+'/main','gameJournalQuestPhase'),(17,base,'gameJournalQuest')]:journal(n,path,typ)
    setfact(18,'stage',3);wait(19,'request','Equal',0);cut(20)
    for n,path,typ in [(21,base+'/main/talk','gameJournalQuestObjective'),(22,base+'/main','gameJournalQuestPhase'),(23,base,'gameJournalQuest')]:journal(n,path,typ)
    setfact(24,'stage',0);setfact(25,'talk',0);setfact(26,'choice',0);setfact(27,'request',0);cut(30)
    for n in [90,91,92]:marker(n)
    g.link(0,'Out',92,'Inactive');g.link(92,'Out',1,'In')
    for a,b in [(1,2),(2,3),(3,4)]:g.link(a,'Out',b,'In')
    g.link(4,'Out',5,'Active');g.link(5,'Out',6,'Active');g.link(6,'Out',7,'Active');g.link(7,'Out',8,'In')
    g.link(8,'Out',9,'In');g.link(8,'Out',10,'In');g.link(9,'Out',11,'In');g.link(11,'Out',12,'conversation_in')
    g.link(12,'conversation_out',13,'In');g.link(13,'True',14,'In');g.link(13,'False',30,'In')
    g.link(14,'CutSource',10,'CutDestination');g.link(14,'Out',91,'Inactive');g.link(91,'Out',15,'Succeeded')
    g.link(15,'Out',16,'Succeeded');g.link(16,'Out',17,'Succeeded');g.link(17,'Out',18,'In');g.link(18,'Out',19,'In');g.link(19,'Out',20,'In')
    g.link(10,'Out',30,'In');g.link(12,'Default INT',30,'In');g.link(12,'Default RET',30,'In')
    for n in [20,30]:
        for target in [9,10,11,12,13,19]:g.link(n,'CutSource',target,'CutDestination')
        g.link(n,'Out',90,'Inactive')
    g.link(90,'Out',21,'Inactive')
    g.link(21,'Out',22,'Inactive');g.link(22,'Out',23,'Inactive');g.link(23,'Out',24,'In')
    for a,b in [(24,25),(25,26),(26,27),(27,2)]:g.link(a,'Out',b,'In')
    return resource('questQuestPhaseResource',graph=g.emit(graph),inplacePhases=[],phasePrefabs=[]),g.edges

def scene(c,t):
    r=copy.deepcopy(t['scene_root']);r.update(debugSymbols={'$type':'scnDebugSymbols','performersDebugSymbols':[],'sceneEventsDebugSymbols':[],'sceneNodesDebugSymbols':[],'workspotsDebugSymbols':[]},
        actors=[copy.deepcopy(t['actor'])],playerActors=[copy.deepcopy(t['player'])],workspotInstances=[],workspots=[],resouresReferences=copy.deepcopy(t['resource_refs']),ridResources=[])
    r['sceneSolutionHash']['sceneSolutionHash']['sceneSolutionHashDate']=fnv('ncpd_patrol_qgiver_test_scene_v1')
    actor=r['actors'][0];actor.update(acquisitionPlan='findInWorld',actorName='NCPD Investigator',specAppearance=cn(c['appearance']),
        specCharacterRecordId={'$type':'TweakDBID','$storage':'string','$value':c['npc_record']},lipsyncAnimSet=rid('scnLipsyncAnimSetSRRefId',4294967295),voicetagId={'$type':'scnVoicetagId','id':fnv('ncpd_patrol_qgiver_test_investigator')})
    actor['findActorInWorldParams']['actorRef'].update(type='Tag',names=[cn(c['tag']+'_npc')])
    actor['communityParams']['reference']={'$type':'NodeRef','$storage':'uint64','$value':'0'}
    actor['communityParams']['entryName']=cn('None');actor['spawnDespawnParams'].update(isEnabled=0,spawnOnStart=0)
    def output(target=None,name=0,ordinal=0):
        dest=[] if target is None else [{'$type':'scnInputSocketId','isockStamp':{'$type':'scnInputSocketStamp','name':0,'ordinal':1 if target in [4,5] else 0},'nodeId':rid('scnNodeId',target)}]
        return {'$type':'scnOutputSocket','destinations':dest,'stamp':{'$type':'scnOutputSocketStamp','name':name,'ordinal':ordinal}}
    nodes=[]
    def add(n,x):x['nodeId']=rid('scnNodeId',n);nodes.append({'HandleId':'pending','Data':x});return x
    start=add(1,copy.deepcopy(t['start']));start['outputSockets']=[output(2)]
    def line(n,item,target,ms):
        x=copy.deepcopy(t['section']);x['sectionDuration']['stu']=ms+300;x['outputSockets']=[output(target),output(name=1)]
        e=x['events'][0]['Data'];e.update(startTime=0,duration=ms,screenplayLineId=rid('scnscreenplayItemId',item));e['id']['id']=fnv('qgiver_event_'+str(n))
        e['voParams']['ignoreSpeakerIncapacitation']=0
        add(n,x)
    line(2,1,3,c['subtitle_ms'])
    choice=add(3,copy.deepcopy(t['choice']));choice['options']=choice['options'][:2]
    choice['outputSockets']=[output(4,ordinal=0),output(5,ordinal=1)]+[output(name=i) for i in range(1,7)]
    choice['localizedDisplayNameOverride']={'unk1':'0','value':'NCPDPatrol_QG_Name'}
    choice['shapeParams']['Data'].update(customActivationRange=4,customIndicationRange=8)
    for opt,item in zip(choice['options'],[2,258]):opt['screenplayOptionId']=rid('scnscreenplayItemId',item)
    def chosen(n,value,target):
        add(n,{'$type':'scnQuestNode','ffStrategy':'automatic','isockMappings':[cn('CutDestination'),cn('In')],
            'osockMappings':[cn('Out')],'outputSockets':[output(target)],'questNode':{'HandleId':'pending','Data':{
                '$type':'questFactsDBManagerNodeDefinition','id':n,'sockets':[{'HandleId':'pending','Data':{'$type':'questSocketDefinition','connections':[],'name':cn(k),'type':typ}} for k,typ in [('CutDestination','CutDestination'),('In','Input'),('Out','Output')]],
                'type':{'HandleId':'pending','Data':{'$type':'questSetVar_NodeType','factName':c['fact_prefix']+'choice','value':value,'setExactValue':1}}}}})
    chosen(4,1,6);chosen(5,2,7);line(6,513,8,2000);line(7,769,8,2000);line(8,257,9,c['subtitle_ms'])
    end=add(9,copy.deepcopy(t['end']));end['outputSockets']=[]
    r['sceneGraph']={'HandleId':'pending','Data':{'$type':'scnSceneGraph','graph':nodes,'startNodes':[rid('scnNodeId',1)],'endNodes':[rid('scnNodeId',9)]}}
    r['entryPoints']=[{'$type':'scnEntryPoint','name':cn('conversation_in'),'nodeId':rid('scnNodeId',1)}]
    r['exitPoints']=[{'$type':'scnExitPoint','name':cn('conversation_out'),'nodeId':rid('scnNodeId',9)}]
    words={'hello':c['hello'],'goodbye':c['goodbye'],'option1':c['choices'][0],'option2':c['choices'][1]}
    ids={k:fnv('NCPDPatrol_QG_'+k) for k in words};vd=[];vp=[]
    for k,text in words.items():
        for locale in ['en_us','db_db']:
            variant=fnv('NCPDPatrol_QG_'+k+'_'+locale)
            vd.append({'$type':'scnlocLocStoreEmbeddedVariantDescriptorEntry','localeId':locale,'locstringId':{'$type':'scnlocLocstringId','ruid':ids[k]},'signature':{'$type':'scnlocSignature','val':'3'},'variantId':{'$type':'scnlocVariantId','ruid':variant},'vpeIndex':len(vp)})
            vp.append({'$type':'scnlocLocStoreEmbeddedVariantPayloadEntry','content':text,'variantId':{'$type':'scnlocVariantId','ruid':variant}})
    r['locStore']={'$type':'scnlocLocStoreEmbedded','vdEntries':vd,'vpEntries':vp}
    lines=[];options=[]
    for item,key,speaker in [(1,'hello',0),(257,'goodbye',0),(513,'option1',1),(769,'option2',1)]:
        x=copy.deepcopy(t['line']);x.update(itemId=rid('scnscreenplayItemId',item),speaker=rid('scnActorId',speaker),addressee=rid('scnActorId',1-speaker),locstringId={'$type':'scnlocLocstringId','ruid':ids[key]})
        x['femaleLipsyncAnimationName']=cn('None');x['maleLipsyncAnimationName']=cn('None');lines.append(x)
    for item,key in [(2,'option1'),(258,'option2')]:
        x=copy.deepcopy(t['option']);x.update(itemId=rid('scnscreenplayItemId',item),locstringId={'$type':'scnlocLocstringId','ruid':ids[key]});options.append(x)
    r['screenplayStore']={'$type':'scnscreenplayStore','lines':lines,'options':options}
    doc=resource('scnSceneResource');doc['Data']['RootChunk']=r
    return renumber(doc),ids

def outputs():
    c,t=read('contract.json'),read('reference-templates.json');scn,ids=scene(c,t);qp,edges=phase(c)
    journal=json.loads((ROOT/'assets/officer_down/officer_down.journal.json').read_text());anchor=json.loads((ROOT/'assets/quest_marker_probe/reference-contract.json').read_text())
    for x in walk(journal):
        if x.get('$type')=='gameJournalQuest':x['id']='ncpd_patrol_quest_giver_test'
        if x.get('$type')=='gameJournalQuestObjective':x['id']='talk'
        for key,val in list(x.items()):
            if isinstance(val,str) and val.startswith('NCPDPatrol_OfficerDown_'):x[key]=val.replace('NCPDPatrol_OfficerDown_','NCPDPatrol_QG_')
        if x.get('$type')=='gameJournalQuestMapPin':
            for k,v in c['position'].items():x['offset'][k.upper()]=v-anchor['position'][k.upper()]+anchor['offset'][k.upper()]
            x['mappinData']['active']=0
    text={'Title':'NCPD: Investigator Contact (Test)','Objective':'Meet the NCPD investigator','Description':'Meet the investigator and choose either reply to complete this text-only dialogue prototype.','Name':'NCPD Investigator'}
    onscreens=resource('JsonResource',root={'HandleId':'0','Data':{'$type':'localizationPersistenceOnScreenEntries','entries':[{'$type':'localizationPersistenceOnScreenEntry','primaryKey':fnv('NCPDPatrol_QG_'+k),'secondaryKey':'NCPDPatrol_QG_'+k,'femaleVariant':v,'maleVariant':v} for k,v in text.items()]}})
    lines=resource('JsonResource',root={'HandleId':'0','Data':{'$type':'localizationPersistenceSubtitleEntries','entries':[{'$type':'localizationPersistenceSubtitleEntry','stringId':ids[k],'femaleVariant':v,'maleVariant':v} for k,v in [('hello',c['hello']),('goodbye',c['goodbye']),('option1',c['choices'][0]),('option2',c['choices'][1])]]}})
    subtitles=resource('JsonResource',root={'HandleId':'0','Data':{'$type':'localizationPersistenceSubtitleMap','entries':[{'$type':'localizationPersistenceSubtitleMapEntry','subtitleFile':{'DepotPath':{'$type':'ResourcePath','$storage':'string','$value':DEPOT+'lines.json'},'Flags':'Soft'},'subtitleGroup':cn('quest')}]}})
    return {'conversation.scene.json':scn,'quest_giver.questphase.json':qp,'quest_giver.journal.json':journal,'onscreens.json.json':onscreens,'lines.json.json':lines,'subtitles.json.json':subtitles},edges

def validate(docs):
    c=read('contract.json');s=docs['conversation.scene.json']['Data']['RootChunk'];g=s['sceneGraph']['Data']['graph'];byid={n['Data']['nodeId']['id']:n['Data'] for n in g}
    assert len(g)==9 and s['actors'][0]['acquisitionPlan']=='findInWorld'
    ref=s['actors'][0]['findActorInWorldParams']['actorRef'];assert ref['type']=='Tag' and ref['names']==[cn(c['tag']+'_npc')]
    assert s['actors'][0]['spawnDespawnParams']['isEnabled']==0 and not s['workspots'] and not any(v for k,v in s['resouresReferences'].items() if k!='$type')
    ch=byid[3];assert len(ch['options'])==2
    for option,flag,line in [(0,4,6),(1,5,7)]:
        assert ch['outputSockets'][option]['destinations'][0]['nodeId']['id']==flag
        assert ch['outputSockets'][option]['destinations'][0]['isockStamp']['ordinal']==1
        assert byid[flag]['questNode']['Data']['type']['Data']['value']==option+1
        assert byid[flag]['outputSockets'][0]['destinations'][0]['nodeId']['id']==line
        assert byid[line]['outputSockets'][0]['destinations'][0]['nodeId']['id']==8
    assert byid[8]['outputSockets'][0]['destinations'][0]['nodeId']['id']==9
    assert {e['femaleVariant'] for e in docs['lines.json.json']['Data']['RootChunk']['root']['Data']['entries']}=={c['hello'],c['goodbye'],*c['choices']}
    for doc in docs.values():
        handles=[x['HandleId'] for x in walk(doc) if 'HandleId' in x];assert len(handles)==len(set(handles))
        assert all(x['HandleRefId'] in handles for x in walk(doc) if 'HandleRefId' in x)
    # Validate the serialized quest graph as well as its scene: in particular,
    # CutSource connections and named scene outputs must survive compilation.
    qp=docs['quest_giver.questphase.json'];handles={x['HandleId']:x['Data'] for x in walk(qp) if 'HandleId' in x}
    def get(ref):return handles[ref.get('HandleId',ref.get('HandleRefId'))]
    graph=get(qp['Data']['RootChunk']['graph']);owners={};nodes=[get(n) for n in graph['nodes']]
    for n in nodes:
        for socket in n['sockets']:
            k=socket.get('HandleId',socket.get('HandleRefId'));owners[k]=(n['id'],get(socket)['name']['$value'])
    edges=[]
    for n in nodes:
        for socket in n['sockets']:
            socket=get(socket)
            if socket['type'] not in ['Output','CutSource']:continue
            for connection in socket['connections']:
                destination=get(connection)['destination'];k=destination.get('HandleId',destination.get('HandleRefId'))
                edges.append([n['id'],socket['name']['$value'],*owners[k]])
    assert sorted(edges)==sorted(phase(c)[1]),'Serialized quest graph lost a transition/cut connection'
    serialized=json.dumps(docs)
    for forbidden in ['mod\\\\fixer01','cc_f01','fixer01.wem','Items.money','CompleteIncident']:assert forbidden not in serialized,forbidden

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--wk-cli',type=Path);p.add_argument('--check',action='store_true');a=p.parse_args()
    docs,edges=outputs();validate(docs)
    for name,doc in docs.items():
        body=json.dumps(doc,indent=2)+'\n'
        if a.check:assert (DIR/name).read_text()==body,name
        else:(DIR/name).write_text(body)
    (DIR/'graph-contract.json').write_text(json.dumps({'edges':edges},indent=2)+'\n')
    if not a.wk_cli:return
    def run(*args):subprocess.run([str(a.wk_cli.resolve()),*map(str,args)],check=True)
    with tempfile.TemporaryDirectory(prefix='ncpd-quest-giver-') as temp:
        temp=Path(temp);packed=temp/'NCPDPatrol_QuestGiverTest';depot=packed/'base/ncpd_patrol/quest_giver_test';depot.mkdir(parents=True)
        out=temp/'out';out.mkdir();roundtrip=temp/'roundtrip';roundtrip.mkdir()
        expected={}
        for name in docs:
            run('convert','deserialize',DIR/name,'--outpath',depot);binary=name[:-5];body=(depot/binary).read_bytes();assert body[:4]==b'CR2W';expected[binary]=body
            run('convert','serialize',depot/binary,'--outpath',roundtrip)
        validate({name:json.loads((roundtrip/name).read_text(encoding='utf-8-sig')) for name in docs})
        run('pack',packed,'--outpath',out);archive=out/'NCPDPatrol_QuestGiverTest.archive';extracted=temp/'extracted';extracted.mkdir();run('extract',archive,'--outpath',extracted)
        assert {p.name:p.read_bytes() for p in extracted.rglob('*') if p.is_file()}==expected
        target=ROOT/'archive/pc/mod'/archive.name;shutil.copy2(archive,target)
        inputs=[DIR/n for n in ['contract.json','reference-templates.json',*docs]]
        (DIR/'compiled.json').write_text(json.dumps({'archive_path':target.relative_to(ROOT).as_posix(),'archive_sha256':hashlib.sha256(target.read_bytes()).hexdigest(),'resources':sorted(expected),'roundtrip_validated':True,'extracted_resource_bytes_compared':True,'authored_inputs':{p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in inputs},'actual_game_validation':False},indent=2)+'\n')
    print('PASS: silent two-choice quest scene compiled, round-tripped and extracted byte-identically')
if __name__=='__main__':main()
