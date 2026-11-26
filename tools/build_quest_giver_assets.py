"""Author the Voss briefing scene and its isolated rearmable test quest.

Minimal scene schemas adapted from Andrea Olivato's MIT fixer01 reference.
The private media assets are supplied by the NCPD Patrol author.
"""
from pathlib import Path
import argparse,copy,hashlib,json,math,shutil,subprocess,tempfile,zlib

ROOT=Path(__file__).resolve().parents[1];DIR=ROOT/'assets/quest_giver_test'
DEPOT='base\\ncpd_patrol\\quest_giver_test\\'
SPEECH_NODES=(2,3,4,5,6,7,8,10,13,14)
RECEIPT_NODE=15
def screenplay_line_id(index):
    assert isinstance(index,int) and 0<=index<0x1000000
    return (index<<8)|1
def read(name):return json.loads((DIR/name).read_text())
def tweak_matches(value,name):return value['$value']==name or value['$value']==str(zlib.crc32(name.encode())|(len(name.encode())<<32))
def cn(s):return {'$type':'CName','$storage':'string','$value':s}
def rid(typ,n):return {'$type':typ,'id':n}
def soft(path):return {'DepotPath':{'$type':'ResourcePath','$storage':'string','$value':path},'Flags':'Soft'}
def media_ms(row):
    return math.ceil(max(row['audio_seconds'],row['animation_seconds'])*1000) if row['speaker']=='voss' else math.ceil(row['event_seconds']*1000)
def turn_ms(row,timing):
    # Established voice/startup budget. Section boundaries retain the separate
    # 500 ms pause; the speech event now covers that pause as well.
    return media_ms(row)+(timing['voss_playback_guard_ms'] if row['speaker']=='voss' else 0)
def subtitle_delay(part,timing):
    return round(part['start_seconds']+timing['subtitle_delay_ms']/1000,3)
def subtitle_controller(c):
    npcs=[row for row in c['conversation'] if row['speaker']=='voss']
    initial=[];first=[];schedule=[]
    for i,row in enumerate(npcs,1):
        prefix='NCPDPatrol_QG_'+row['key']
        initial.append('    if Equals(data.text, GetLocalizedTextByKey(n"'+prefix+'_Full")) { turn = '+str(i)+'; };')
        first.append('    if turn == '+str(i)+' { data.text = GetLocalizedTextByKey(n"'+prefix+'_Part1"); };')
        calls=['        this.NCPDVossQueueSubtitle(speaker, n"'+prefix+'_Part'+str(j)+'", '+str(float(subtitle_delay(p,c['timing'])))+');' for j,p in enumerate(row['subtitle_parts'][1:],2)]
        schedule.append('    if turn == '+str(i)+' {\n'+'\n'.join(calls)+'\n    };')
    source=(DIR/'subtitle-controller.reds.template').read_text()
    for key,value in [('INITIAL',initial),('FIRST',first),('SCHEDULE',schedule)]:source=source.replace('@@'+key+'@@','\n'.join(value))
    assert '@@' not in source
    return source

def sms_paths(c):
    contact='contacts/'+c['sms']['contact_id'];thread=contact+'/'+c['sms']['conversation_id']
    return contact,thread,thread+'/'+c['sms']['message_id']
def pose_helper(c):
    # Mod-owned minimal device schema already used by the arrest helper. The
    # Voss device has its own identity and references the unmodified vanilla bank.
    doc=json.loads((ROOT/'assets/arrest/arrest_workspot.ent.json').read_text())
    root=doc['Data']['RootChunk'];root['compiledData']['Data']['CruidDict']['1']='19005001'
    for component in walk(root):
        if component.get('$type')=='workWorkspotResourceComponent':
            component.update(id='19005001',name=cn(c['presentation']['helper_component']),
                workspotResource={**soft(c['presentation']['workspot']),'Flags':'Default'})
    return doc
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
    def journal(n,path,typ,notify=1):
        p=g.alloc('gameJournalPath',realPath=path,fileEntryIndex=1,className=cn(typ),editorPath='')
        t=g.alloc('questJournalEntry_NodeType',path=p,sendNotification=notify)
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
    # Completion receipt survives ordinary scene/graph return cleanup. Only
    # explicit Begin/RequestClear resets it in the native bridge.
    setfact(35,'briefed',1)
    for n,path,typ in [(21,base+'/main/talk','gameJournalQuestObjective'),(22,base+'/main','gameJournalQuestPhase'),(23,base,'gameJournalQuest')]:journal(n,path,typ)
    setfact(24,'stage',0);setfact(25,'talk',0);setfact(26,'choice',0);setfact(27,'request',0);cut(30)
    for n in [90,91,92]:marker(n)
    contact,thread,message=sms_paths(c)
    journal(31,contact,'gameJournalContact',0);journal(32,thread,'gameJournalPhoneConversation',0)
    journal(33,message,'gameJournalPhoneMessage',0);journal(34,message,'gameJournalPhoneMessage',1)
    g.link(0,'Out',92,'Inactive');g.link(92,'Out',1,'In')
    for a,b in [(1,2),(2,3),(3,4)]:g.link(a,'Out',b,'In')
    # One private message entry is reused on explicit replay. A silent reset
    # gives a fresh Direct/Active notification without adding duplicate bubbles.
    # Nothing touches the player's other contacts or advances from reading SMS.
    g.link(4,'Out',31,'Active');g.link(31,'Out',32,'Active');g.link(32,'Out',33,'Inactive')
    g.link(33,'Out',34,'Active');g.link(34,'Out',5,'Active')
    g.link(5,'Out',6,'Active');g.link(6,'Out',7,'Active');g.link(7,'Out',8,'In')
    g.link(8,'Out',9,'In');g.link(8,'Out',10,'In');g.link(9,'Out',11,'In');g.link(11,'Out',12,'conversation_in')
    g.link(12,'conversation_out',13,'In');g.link(13,'True',14,'In');g.link(13,'False',30,'In')
    g.link(14,'CutSource',10,'CutDestination');g.link(14,'Out',91,'Inactive');g.link(91,'Out',15,'Succeeded')
    g.link(15,'Out',16,'Succeeded');g.link(16,'Out',17,'Succeeded');g.link(17,'Out',35,'In');g.link(35,'Out',18,'In');g.link(18,'Out',19,'In');g.link(19,'Out',20,'In')
    g.link(10,'Out',30,'In');g.link(12,'Default INT',30,'In')
    # A normal native return must evaluate the actual final scene receipt.
    # An early return (choice=0) still follows the existing cancellation path.
    g.link(12,'Default RET',13,'In')
    for n in [20,30]:
        for target in [9,10,11,12,13,19]:g.link(n,'CutSource',target,'CutDestination')
        g.link(n,'Out',90,'Inactive')
    g.link(90,'Out',21,'Inactive')
    g.link(21,'Out',22,'Inactive');g.link(22,'Out',23,'Inactive');g.link(23,'Out',24,'In')
    for a,b in [(24,25),(25,26),(26,27),(27,2)]:g.link(a,'Out',b,'In')
    return resource('questQuestPhaseResource',graph=g.emit(graph),inplacePhases=[],phasePrefabs=[]),g.edges

def scene(c,t):
    presentation=read('presentation-templates.json')
    r=copy.deepcopy(t['scene_root'])
    r.update(debugSymbols={'$type':'scnDebugSymbols','performersDebugSymbols':[],'sceneEventsDebugSymbols':[],'sceneNodesDebugSymbols':[],'workspotsDebugSymbols':[]},actors=[copy.deepcopy(t['actor'])],playerActors=[copy.deepcopy(t['player'])],resouresReferences=copy.deepcopy(t['resource_refs']),ridResources=[])
    r['sceneSolutionHash']['sceneSolutionHash']['sceneSolutionHashDate']=fnv('ncpd_patrol_voss_automatic_conversation_v7_event_tail_v1')
    workspot=copy.deepcopy(presentation['workspot']);workspot['Data']['dataId']['id']=1
    workspot['Data']['workspotResource']={**soft(c['presentation']['workspot']),'Flags':'Default'}
    instance=copy.deepcopy(presentation['workspot_instance']);instance['dataId']['id']=instance['workspotInstanceId']['id']=1;instance['playAtActorLocation']=1
    r['workspots']=[workspot];r['workspotInstances']=[instance]
    r['resouresReferences']['lipsyncAnimSets']=[{'$type':'scnLipsyncAnimSetSRRef','asyncRefLipsyncAnimSet':soft(DEPOT+'voss_conversation.anims'),'lipsyncAnimSet':{'DepotPath':{'$type':'ResourcePath','$storage':'uint64','$value':'0'},'Flags':'Default'}}]
    actor=r['actors'][0];actor.update(acquisitionPlan='findInWorld',actorName='Lt. Mara Voss',specAppearance=cn(c['appearance']),specCharacterRecordId={'$type':'TweakDBID','$storage':'string','$value':c['npc_record']},lipsyncAnimSet=rid('scnLipsyncAnimSetSRRefId',0),voicetagId={'$type':'scnVoicetagId','id':fnv('ncpd_patrol_qgiver_test_investigator')})
    actor['findActorInWorldParams']['actorRef'].update(type='Tag',names=[cn(c['tag']+'_npc')]);actor['communityParams']['reference']={'$type':'NodeRef','$storage':'uint64','$value':'0'};actor['communityParams']['entryName']=cn('None');actor['spawnDespawnParams'].update(isEnabled=0,spawnOnStart=0)
    def output(target=None,name=0,ordinal=0):
        dest=[] if target is None else [{'$type':'scnInputSocketId','isockStamp':{'$type':'scnInputSocketStamp','name':0,'ordinal':1 if target in [RECEIPT_NODE,11] else 0},'nodeId':rid('scnNodeId',target)}]
        return {'$type':'scnOutputSocket','destinations':dest,'stamp':{'$type':'scnOutputSocketStamp','name':name,'ordinal':ordinal}}
    nodes=[]
    def add(n,x):x['nodeId']=rid('scnNodeId',n);nodes.append({'HandleId':'pending','Data':x});return x
    def look_at(n):
        e=copy.deepcopy(presentation['look_at_event']);e['id']['id']=fnv('qgiver_look_at_'+str(n));b=e['basicData']['basic'];b['performerId']['id']=1;b['targetPerformerId']['id']=257;b['targetSlot']=cn(c['presentation']['look_at_slot'])
        request=e['basicData']['requests'][0]['request'];request['additionalParts']['Elements']=[x for x in request['additionalParts']['Elements'] if x['partName']['$value']=='Head']
        return {'HandleId':'pending','Data':e}
    add(1,copy.deepcopy(t['start']))['outputSockets']=[output(12)]
    intro=copy.deepcopy(t['section']);intro['sectionDuration']['stu']=c['presentation']['intro_ms'];intro['events']=[look_at(12)];intro['outputSockets']=[output(SPEECH_NODES[0]),output(name=1),output(name=2)];add(12,intro)
    ids={}
    for i,row in enumerate(c['conversation']):
        n=SPEECH_NODES[i];item=screenplay_line_id(i);key=row['key'];ids[key]=row.get('string_id',fnv('NCPDPatrol_QG_'+key));duration=turn_ms(row,c['timing']);start=row.get('lead_in_ms',0)
        x=copy.deepcopy(t['section']);x['sectionDuration']['stu']=start+duration+c['timing']['section_tail_ms'];x['outputSockets']=[output(SPEECH_NODES[i+1] if i+1<len(SPEECH_NODES) else RECEIPT_NODE),output(name=1)]
        # Preserve the section and every subsequent voice start. Only extend
        # event ownership through the former eventless tail, as in the reference.
        e=x['events'][0]['Data'];e.update(startTime=start,duration=duration+c['timing']['section_tail_ms'],screenplayLineId=rid('scnscreenplayItemId',item));e['id']['id']=fnv('qgiver_conversation_event_'+key);e['voParams']['ignoreSpeakerIncapacitation']=0
        # Per-line native mix context only. Keep the exact VO/clip/timing and
        # avoid a global mixer override to address the reported ambience dips.
        e['voParams']['voContext']='Vo_Context_Minor_Activity'
        x['events'].append(look_at(n));add(n,x)
    # Reuse the private completion receipt expected by the existing quest
    # phase/native bridge. It is set only after all ten automatic turns.
    add(RECEIPT_NODE,{'$type':'scnQuestNode','ffStrategy':'automatic','isockMappings':[cn('CutDestination'),cn('In')],'osockMappings':[cn('Out')],'outputSockets':[output(9)],'questNode':{'HandleId':'pending','Data':{'$type':'questFactsDBManagerNodeDefinition','id':RECEIPT_NODE,'sockets':[{'HandleId':'pending','Data':{'$type':'questSocketDefinition','connections':[],'name':cn(k),'type':typ}} for k,typ in [('CutDestination','CutDestination'),('In','Input'),('Out','Output')]],'type':{'HandleId':'pending','Data':{'$type':'questSetVar_NodeType','factName':c['fact_prefix']+'choice','value':c['completion_receipt'],'setExactValue':1}}}}})
    add(9,copy.deepcopy(t['end']))['outputSockets']=[]
    # Keep the legacy body node/data for restore cleanup; never activate it.
    pose=copy.deepcopy(presentation['workspot_node']);command=pose['questNode']['Data'];command['id']=11;command['entityReference']=copy.deepcopy(actor['findActorInWorldParams']['actorRef']);command['paramsV1']['Data'].update(workspotInstanceId=rid('scnSceneWorkspotInstanceId',1),enableIdleMode=0,jumpToEntry=0,entryId=rid('workWorkEntryId',4294967295),playAtActorLocation=1);pose['outputSockets']=[output(ordinal=0),output(ordinal=1)];add(11,pose)
    r['sceneGraph']={'HandleId':'pending','Data':{'$type':'scnSceneGraph','graph':sorted(nodes,key=lambda n:n['Data']['nodeId']['id']),'startNodes':[rid('scnNodeId',1)],'endNodes':[rid('scnNodeId',9)]}}
    r['entryPoints']=[{'$type':'scnEntryPoint','name':cn('conversation_in'),'nodeId':rid('scnNodeId',1)}];r['exitPoints']=[{'$type':'scnExitPoint','name':cn('conversation_out'),'nodeId':rid('scnNodeId',9)}]
    vd=[];vp=[];lines=[]
    for i,row in enumerate(c['conversation']):
        key=row['key']
        for locale in ['en_us','db_db']:
            variant=fnv('NCPDPatrol_QG_'+key+'_'+locale);vd.append({'$type':'scnlocLocStoreEmbeddedVariantDescriptorEntry','localeId':locale,'locstringId':{'$type':'scnlocLocstringId','ruid':ids[key]},'signature':{'$type':'scnlocSignature','val':'3'},'variantId':{'$type':'scnlocVariantId','ruid':variant},'vpeIndex':len(vp)});vp.append({'$type':'scnlocLocStoreEmbeddedVariantPayloadEntry','content':row['text'],'variantId':{'$type':'scnlocVariantId','ruid':variant}})
        speaker=0 if row['speaker']=='voss' else 1;x=copy.deepcopy(t['line']);x.update(itemId=rid('scnscreenplayItemId',screenplay_line_id(i)),speaker=rid('scnActorId',speaker),addressee=rid('scnActorId',1-speaker),locstringId={'$type':'scnlocLocstringId','ruid':ids[key]});clip=row.get('clip','None');x['femaleLipsyncAnimationName']=x['maleLipsyncAnimationName']=cn(clip);lines.append(x)
    r['locStore']={'$type':'scnlocLocStoreEmbedded','vdEntries':vd,'vpEntries':vp};r['screenplayStore']={'$type':'scnscreenplayStore','lines':lines,'options':[]}
    doc=resource('scnSceneResource');doc['Data']['RootChunk']=r;return renumber(doc),ids


def validate_scene(docs,c):
    s=docs['conversation.scene.json']['Data']['RootChunk'];g=s['sceneGraph']['Data']['graph'];nodes={n['Data']['nodeId']['id']:n['Data'] for n in g};turns=c['conversation']
    assert len(g)==15 and c['automatic_replies'] and len(turns)==10 and c['completion_receipt']==1
    assert not s['screenplayStore']['options'] and not any(n['$type']=='scnChoiceNode' for n in nodes.values())
    actor=s['actors'][0];assert actor['acquisitionPlan']=='findInWorld' and not actor['spawnDespawnParams']['isEnabled']
    assert actor['findActorInWorldParams']['actorRef']['names']==[cn(c['tag']+'_npc')]
    assert tweak_matches(actor['specCharacterRecordId'],c['npc_record']) and actor['lipsyncAnimSet']['id']==0
    assert s['playerActors'][0]['lipsyncAnimSet']['id']==4294967295 and tweak_matches(s['playerActors'][0]['specCharacterRecordId'],'Character.Player_Puppet_Base')
    assert len(s['resouresReferences']['lipsyncAnimSets'])==1 and s['resouresReferences']['lipsyncAnimSets'][0]['asyncRefLipsyncAnimSet']==soft(DEPOT+'voss_conversation.anims')
    def target(n):return nodes[n]['outputSockets'][0]['destinations'][0]['nodeId']['id']
    assert [n['Data']['nodeId']['id'] for n in g]==list(range(1,len(g)+1))
    assert [line['itemId']['id'] for line in s['screenplayStore']['lines']]==[screenplay_line_id(i) for i in range(len(turns))]
    assert target(1)==12 and target(12)==SPEECH_NODES[0]
    assert nodes[12]['sectionDuration']['stu']==500 and not nodes[12]['outputSockets'][2]['destinations']
    assert not any(d['nodeId']['id']==11 for n in nodes.values() for o in n.get('outputSockets',[]) for d in o['destinations'])
    assert nodes[11]['questNode']['Data']['paramsV1']['Data']['isPlayer']==0
    assert not any(o['destinations'] for o in nodes[11]['outputSockets'])
    assert len(s['workspots'])==len(s['workspotInstances'])==1
    assert s['workspots'][0]['Data']['workspotResource']=={**soft(c['presentation']['workspot']),'Flags':'Default'}
    for i,row in enumerate(turns):
        node_id=SPEECH_NODES[i];n=nodes[node_id];assert n['$type']=='scnSectionNode' and target(node_id)==(SPEECH_NODES[i+1] if i+1<len(SPEECH_NODES) else RECEIPT_NODE)
        events=[x['Data'] for x in n['events'] if x['Data']['$type']=='scnDialogLineEvent'];assert len(events)==1;e=events[0]
        assert e['screenplayLineId']['id']==screenplay_line_id(i) and e['startTime']==row.get('lead_in_ms',0)
        assert e['duration']==turn_ms(row,c['timing'])+c['timing']['section_tail_ms']
        assert n['sectionDuration']['stu']==e['startTime']+e['duration']
        assert e['voParams']['voContext']=='Vo_Context_Minor_Activity'
        line=next(x for x in s['screenplayStore']['lines'] if x['itemId']['id']==screenplay_line_id(i))
        assert line['speaker']['id']==(0 if row['speaker']=='voss' else 1)
        assert line['locstringId']['ruid']==row.get('string_id',fnv('NCPDPatrol_QG_'+row['key']))
        assert line['maleLipsyncAnimationName']==line['femaleLipsyncAnimationName']==cn(row.get('clip','None'))
        assert line['usage']['playerGenderMask']['mask']==3
    finish=nodes[RECEIPT_NODE];assert finish['isockMappings'][1]==cn('In') and nodes[SPEECH_NODES[-1]]['outputSockets'][0]['destinations'][0]['isockStamp']['ordinal']==1
    assert finish['questNode']['Data']['type']['Data']=={'$type':'questSetVar_NodeType','factName':c['fact_prefix']+'choice','value':1,'setExactValue':1}
    assert target(RECEIPT_NODE)==9
    for n in [12,*SPEECH_NODES]:
        look=[x['Data'] for x in nodes[n]['events'] if x['Data']['$type']=='scnLookAtEvent'];assert len(look)==1;b=look[0]['basicData']['basic']
        assert b['isStart']==1 and b['performerId']['id']==1 and b['targetPerformerId']['id']==257 and b['targetSlot']==cn('pla_default_tgt')
        request=look[0]['basicData']['requests'][0]['request'];assert [p['partName'] for p in request['additionalParts']['Elements']]==[cn('Head')]
    helper=docs['voss_wait_pose.ent.json']['Data']['RootChunk'];components=[x for x in walk(helper) if x.get('$type')=='workWorkspotResourceComponent'];assert len(components)==2
    for component in components:
        assert component['name']==cn(c['presentation']['helper_component']) and component['id']=='19005001'
        assert component['workspotResource']=={**soft(c['presentation']['workspot']),'Flags':'Default'}
        assert all(p['Bits']==0 for p in component['localTransform']['Position'].values() if isinstance(p,dict))
    assert c['presentation']['spawn_height_offset']==0 and not c['presentation']['scene_restarts_pose']
    npcs=[t for t in turns if t['speaker']=='voss'];voices=docs['vomap.json.json']['Data']['RootChunk']['root']['Data']['entries'];assert len(voices)==6
    for voice,row in zip(voices,npcs):assert voice['stringId']==fnv('NCPDPatrol_QG_'+row['key']) and voice['femaleResPath']==voice['maleResPath']==soft(DEPOT+row['wem'])
    lines=docs['lines.json.json']['Data']['RootChunk']['root']['Data']['entries'];assert len(lines)==6 and {e['stringId'] for e in lines}=={fnv('NCPDPatrol_QG_'+row['key']) for row in npcs}
    native={t['string_id'] for t in turns if t['speaker']=='v'};assert len(native)==4 and native.isdisjoint({e['stringId'] for e in voices+lines})
    lip=docs['voss.lipmap.json']['Data']['RootChunk'];assert lip['scenePaths']==[fnv((DEPOT+'conversation.scene').lower())] and lip['sceneEntries']==[{'$type':'animLipsyncMappingSceneEntry','actorVoiceTags':[actor['voicetagId']['id']],'animSets':[soft(DEPOT+'voss_conversation.anims')]}]
    strings={e['secondaryKey']:e for e in docs['onscreens.json.json']['Data']['RootChunk']['root']['Data']['entries']}
    for row in npcs:
        parts=row['subtitle_parts'];assert parts[0]['start_seconds']==0 and ' '.join(p['text'] for p in parts)==row['text']
        assert all(parts[i]['start_seconds']<parts[i+1]['start_seconds'] for i in range(len(parts)-1)) and parts[-1]['start_seconds']<row['audio_seconds']
        assert subtitle_delay(parts[-1],c['timing'])<turn_ms(row,c['timing'])/1000
        assert strings['NCPDPatrol_QG_'+row['key']+'_Full']['femaleVariant']==row['text']
        for i,p in enumerate(parts,1):assert strings['NCPDPatrol_QG_'+row['key']+'_Part'+str(i)]['femaleVariant']==p['text']

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
    folder=copy.deepcopy(read('sms-templates.json')['contacts_folder'])
    contact=folder['Data']['entries'][0]['Data'];thread=contact['entries'][0]['Data'];message=thread['entries'][0]['Data']
    contact.update(id=c['sms']['contact_id'],name={'unk1':'0','value':'NCPDPatrol_QG_Name'},type='Texter',
        avatarID={'$type':'TweakDBID','$storage':'string','$value':c['sms']['avatar']},isCallableDefault=0)
    thread.update(id=c['sms']['conversation_id'],title={'unk1':'0','value':'NCPDPatrol_QG_SmsTitle'})
    message.update(id=c['sms']['message_id'],sender='NPC',delay=0,isQuestImportant=1,
        text={'unk1':'0','value':'NCPDPatrol_QG_Invitation'},
        attachment={'HandleId':'pending','Data':{'$type':'gameJournalPath','realPath':c['quest_root'],
            'fileEntryIndex':1,'className':cn('gameJournalQuest'),'editorPath':''}})
    journal['Data']['RootChunk']['entry']['Data']['entries'].append(folder);renumber(journal)
    text={'Title':'NCPD: Investigator Contact (Test)','Objective':'Meet Lieutenant Mara Voss','Description':'Lieutenant Mara Voss has sent you a private message. Meet her at the supplied location, listen to her private briefing.','Name':'Lt. Mara Voss',
        'SmsTitle':c['sms']['title'],'Invitation':c['sms']['text']}
    for row in c['conversation']:
        if row['speaker']!='voss':continue
        text[row['key']+'_Full']=row['text']
        for i,part in enumerate(row['subtitle_parts'],1):text[row['key']+'_Part'+str(i)]=part['text']
    onscreens=resource('JsonResource',root={'HandleId':'0','Data':{'$type':'localizationPersistenceOnScreenEntries','entries':[{'$type':'localizationPersistenceOnScreenEntry','primaryKey':fnv('NCPDPatrol_QG_'+k),'secondaryKey':'NCPDPatrol_QG_'+k,'femaleVariant':v,'maleVariant':v} for k,v in text.items()]}})
    npcs=[row for row in c['conversation'] if row['speaker']=='voss']
    lines=resource('JsonResource',root={'HandleId':'0','Data':{'$type':'localizationPersistenceSubtitleEntries','entries':[{'$type':'localizationPersistenceSubtitleEntry','stringId':ids[row['key']],'femaleVariant':row['text'],'maleVariant':row['text']} for row in npcs]}})
    subtitles=resource('JsonResource',root={'HandleId':'0','Data':{'$type':'localizationPersistenceSubtitleMap','entries':[{'$type':'localizationPersistenceSubtitleMapEntry','subtitleFile':{'DepotPath':{'$type':'ResourcePath','$storage':'string','$value':DEPOT+'lines.json'},'Flags':'Soft'},'subtitleGroup':cn('quest')}]}})
    vomap=resource('JsonResource',root={'HandleId':'0','Data':{'$type':'locVoiceoverMap','entries':[{'$type':'locVoLineEntry','stringId':ids[row['key']],'femaleResPath':soft(DEPOT+row['wem']),'maleResPath':soft(DEPOT+row['wem'])} for row in npcs]}})
    scene_path=(DEPOT+'conversation.scene').lower()
    lipmap=resource('animLipsyncMapping',languageCodeName=cn('en-us'),
        sceneEntries=[{'$type':'animLipsyncMappingSceneEntry','actorVoiceTags':[fnv('ncpd_patrol_qgiver_test_investigator')],'animSets':[soft(DEPOT+'voss_conversation.anims')]}],
        scenePaths=[fnv(scene_path)],scenePreviewPaths=[fnv(scene_path+'preview')])
    return {'conversation.scene.json':scn,'quest_giver.questphase.json':qp,'quest_giver.journal.json':journal,'onscreens.json.json':onscreens,'lines.json.json':lines,'subtitles.json.json':subtitles,'vomap.json.json':vomap,'voss.lipmap.json':lipmap,'voss_wait_pose.ent.json':pose_helper(c)},edges

def validate(docs):
    c=read('contract.json');validate_scene(docs,c)
    for doc in docs.values():
        handles=[x['HandleId'] for x in walk(doc) if 'HandleId' in x];assert len(handles)==len(set(handles))
        assert all(x['HandleRefId'] in handles for x in walk(doc) if 'HandleRefId' in x)
    journal=docs['quest_giver.journal.json'];contacts=[x for x in walk(journal) if x.get('$type')=='gameJournalContact']
    assert len(contacts)==1;contact=contacts[0]
    assert contact['id']==c['sms']['contact_id'] and contact['type']=='Texter' and contact['isCallableDefault']==0
    assert contact['name']['value']=='NCPDPatrol_QG_Name' and contact['avatarID']['$value']==c['sms']['avatar']
    assert len(contact['entries'])==1;thread=contact['entries'][0]['Data']
    assert thread['$type']=='gameJournalPhoneConversation' and thread['id']==c['sms']['conversation_id']
    assert len(thread['entries'])==1;message=thread['entries'][0]['Data']
    assert message['$type']=='gameJournalPhoneMessage' and message['id']==c['sms']['message_id']
    assert message['sender']=='NPC' and message['delay']==0 and message['isQuestImportant']==1
    assert message['text']['value']=='NCPDPatrol_QG_Invitation'
    attachment=message['attachment']['Data'];assert attachment['realPath']==c['quest_root'] and attachment['className']==cn('gameJournalQuest')
    strings={x['secondaryKey']:x for x in docs['onscreens.json.json']['Data']['RootChunk']['root']['Data']['entries']}
    assert strings['NCPDPatrol_QG_Invitation']['femaleVariant']==strings['NCPDPatrol_QG_Invitation']['maleVariant']==c['sms']['text']
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
    nodes_by_id={x['id']:x for x in nodes}
    for i,path,kind,notify in [(31,sms_paths(c)[0],'gameJournalContact',0),(32,sms_paths(c)[1],'gameJournalPhoneConversation',0),
        (33,sms_paths(c)[2],'gameJournalPhoneMessage',0),(34,sms_paths(c)[2],'gameJournalPhoneMessage',1)]:
        t=get(nodes_by_id[i]['type']);p=get(t['path'])
        assert p['realPath']==path and p['className']==cn(kind) and t['sendNotification']==notify
    serialized=json.dumps(docs)
    for forbidden in ['mod\\\\fixer01','cc_f01','fixer01.wem','Items.money','CompleteIncident']:assert forbidden not in serialized,forbidden

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--wk-cli',type=Path);p.add_argument('--check',action='store_true');a=p.parse_args()
    docs,edges=outputs();validate(docs)
    script=ROOT/'r6/scripts/NCPDPatrol/NCPDPatrolVossSubtitles.reds'
    body=subtitle_controller(read('contract.json'))
    if a.check:assert script.read_text()==body,'Stale Voss subtitle controller'
    else:script.write_text(body)
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
        run('convert','deserialize',*[DIR/name for name in docs],'--outpath',depot)
        for name in docs:
            binary=name[:-5];body=(depot/binary).read_bytes();assert body[:4]==b'CR2W';expected[binary]=body
        run('convert','serialize',*[depot/name[:-5] for name in docs],'--outpath',roundtrip)
        validate({name:json.loads((roundtrip/name).read_text(encoding='utf-8-sig')) for name in docs})
        media=read('media/manifest.json')
        for name in media['packaged']:
            body=(DIR/'media'/name).read_bytes()
            assert hashlib.sha256(body).hexdigest()==media['packaged'][name]['sha256']
            (depot/name).write_bytes(body);expected[name]=body
        run('pack',packed,'--outpath',out);archive=out/'NCPDPatrol_QuestGiverTest.archive';extracted=temp/'extracted';extracted.mkdir();run('extract',archive,'--outpath',extracted)
        assert {p.name:p.read_bytes() for p in extracted.rglob('*') if p.is_file()}==expected
        target=ROOT/'archive/pc/mod'/archive.name;shutil.copy2(archive,target)
        inputs=[DIR/n for n in ['contract.json','reference-templates.json','presentation-templates.json','sms-templates.json','subtitle-controller.reds.template','scene-id-reference.json','media/manifest.json',*[str(p.relative_to(DIR)) for p in (DIR/'media').rglob('*') if p.is_file() and (p.name in media['packaged'] or p.parent.name=='source')],*docs]]+[ROOT/'assets/arrest/arrest_workspot.ent.json']
        (DIR/'compiled.json').write_text(json.dumps({'archive_path':target.relative_to(ROOT).as_posix(),'archive_sha256':hashlib.sha256(target.read_bytes()).hexdigest(),'resources':sorted(expected),'roundtrip_validated':True,'extracted_resource_bytes_compared':True,'authored_inputs':{p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in inputs},'actual_game_validation':False},indent=2)+'\n')
    print('PASS: voiced Voss briefing scene and localization compiled, round-tripped and extracted with all seven packaged media files byte-identical')
if __name__=='__main__':main()
