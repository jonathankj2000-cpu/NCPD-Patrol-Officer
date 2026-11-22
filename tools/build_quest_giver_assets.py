"""Author the Voss briefing scene and its isolated rearmable test quest.

Minimal scene schemas adapted from Andrea Olivato's MIT fixer01 reference.
The private media assets are supplied by the NCPD Patrol author.
"""
from pathlib import Path
import argparse,copy,hashlib,json,math,shutil,subprocess,tempfile

ROOT=Path(__file__).resolve().parents[1];DIR=ROOT/'assets/quest_giver_test'
DEPOT='base\\ncpd_patrol\\quest_giver_test\\'
def read(name):return json.loads((DIR/name).read_text())
def cn(s):return {'$type':'CName','$storage':'string','$value':s}
def rid(typ,n):return {'$type':typ,'id':n}
def soft(path):return {'DepotPath':{'$type':'ResourcePath','$storage':'string','$value':path},'Flags':'Soft'}
def briefing_ms(c):return math.ceil(max(c['briefing']['audio_seconds'],c['briefing']['animation_seconds'])*1000)
def subtitle_controller(c):
    parts=c['briefing']['subtitle_parts']
    assert len(parts)==3 and parts[0]['start_seconds']==0
    assert ' '.join(p['text'] for p in parts)==c['briefing']['text']
    assert all(parts[i]['start_seconds']<parts[i+1]['start_seconds'] for i in range(2))
    assert parts[-1]['start_seconds']<c['briefing']['audio_seconds']
    source=(DIR/'subtitle-controller.reds.template').read_text()
    for i in [2,3]:source=source.replace('@@PART'+str(i)+'_SECONDS@@',str(float(parts[i-1]['start_seconds'])))
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
    presentation=read('presentation-templates.json')
    r=copy.deepcopy(t['scene_root']);r.update(debugSymbols={'$type':'scnDebugSymbols','performersDebugSymbols':[],'sceneEventsDebugSymbols':[],'sceneNodesDebugSymbols':[],'workspotsDebugSymbols':[]},
        actors=[copy.deepcopy(t['actor'])],playerActors=[copy.deepcopy(t['player'])],workspotInstances=[],workspots=[],resouresReferences=copy.deepcopy(t['resource_refs']),ridResources=[])
    r['sceneSolutionHash']['sceneSolutionHash']['sceneSolutionHashDate']=fnv('ncpd_patrol_qgiver_test_scene_v4_grounded_wait_pose')
    workspot=copy.deepcopy(presentation['workspot']);workspot['Data']['dataId']['id']=1
    workspot['Data']['workspotResource']={**soft(c['presentation']['workspot']),'Flags':'Default'}
    instance=copy.deepcopy(presentation['workspot_instance'])
    instance['dataId']['id']=1;instance['workspotInstanceId']['id']=1;instance['playAtActorLocation']=1
    r['workspots']=[workspot];r['workspotInstances']=[instance]
    r['resouresReferences']['lipsyncAnimSets']=[{'$type':'scnLipsyncAnimSetSRRef',
        'asyncRefLipsyncAnimSet':soft(DEPOT+'voss_briefing.anims'),
        'lipsyncAnimSet':{'DepotPath':{'$type':'ResourcePath','$storage':'uint64','$value':'0'},'Flags':'Default'}}]
    actor=r['actors'][0];actor.update(acquisitionPlan='findInWorld',actorName='Lt. Mara Voss',specAppearance=cn(c['appearance']),
        specCharacterRecordId={'$type':'TweakDBID','$storage':'string','$value':c['npc_record']},lipsyncAnimSet=rid('scnLipsyncAnimSetSRRefId',0),voicetagId={'$type':'scnVoicetagId','id':fnv('ncpd_patrol_qgiver_test_investigator')})
    actor['findActorInWorldParams']['actorRef'].update(type='Tag',names=[cn(c['tag']+'_npc')])
    actor['communityParams']['reference']={'$type':'NodeRef','$storage':'uint64','$value':'0'}
    actor['communityParams']['entryName']=cn('None');actor['spawnDespawnParams'].update(isEnabled=0,spawnOnStart=0)
    def output(target=None,name=0,ordinal=0):
        dest=[] if target is None else [{'$type':'scnInputSocketId','isockStamp':{'$type':'scnInputSocketStamp','name':0,'ordinal':1 if target in [4,5,11] else 0},'nodeId':rid('scnNodeId',target)}]
        return {'$type':'scnOutputSocket','destinations':dest,'stamp':{'$type':'scnOutputSocketStamp','name':name,'ordinal':ordinal}}
    nodes=[]
    def add(n,x):x['nodeId']=rid('scnNodeId',n);nodes.append({'HandleId':'pending','Data':x});return x
    start=add(1,copy.deepcopy(t['start']));start['outputSockets']=[output(12)]
    def look_at(n):
        event=copy.deepcopy(presentation['look_at_event'])
        event['id']['id']=fnv('qgiver_look_at_'+str(n))
        basic=event['basicData']['basic']
        basic['performerId']['id']=1 # actor 0: Voss
        basic['targetPerformerId']['id']=257 # actor 1: V, resolved every frame
        basic['targetSlot']=cn(c['presentation']['look_at_slot'])
        # Eye/head tracking must not animate the chest or unfold her arms.
        request=event['basicData']['requests'][0]['request']
        request['additionalParts']['Elements']=[x for x in request['additionalParts']['Elements'] if x['partName']['$value']=='Head']
        return {'HandleId':'pending','Data':event}
    def line(n,item,target,ms,start_ms=0):
        x=copy.deepcopy(t['section']);x['sectionDuration']['stu']=start_ms+ms+300;x['outputSockets']=[output(target),output(name=1)]
        e=x['events'][0]['Data'];e.update(startTime=start_ms,duration=ms,screenplayLineId=rid('scnscreenplayItemId',item));e['id']['id']=fnv('qgiver_event_'+str(n))
        e['voParams']['ignoreSpeakerIncapacitation']=0
        x['events'].append(look_at(n))
        add(n,x)
    line(2,1,10,c['subtitle_ms'])
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
    # One event owns both voice and facial animation. Delay both together;
    # padding only the audio would offset the supplied matching lipsync bank.
    line(10,1025,3,briefing_ms(c),c['briefing']['lead_in_ms'])
    # Retain the old, now unreachable workspot node/data for saved-scene
    # compatibility. New scenes never fire it: the grounded device already owns
    # Voss's body while she waits, so greeting must not restart/snap her pose.
    pose=copy.deepcopy(presentation['workspot_node'])
    command=pose['questNode']['Data'];command['id']=11
    command['entityReference']=copy.deepcopy(actor['findActorInWorldParams']['actorRef'])
    params=command['paramsV1']['Data']
    params.update(workspotInstanceId=rid('scnSceneWorkspotInstanceId',1),
        enableIdleMode=0,jumpToEntry=0,entryId=rid('workWorkEntryId',4294967295),playAtActorLocation=1)
    pose['outputSockets']=[output(ordinal=0),output(ordinal=1)]
    add(11,pose)
    intro=copy.deepcopy(t['section']);intro['sectionDuration']['stu']=c['presentation']['intro_ms']
    intro['events']=[look_at(12)]
    intro['outputSockets']=[output(2),output(name=1),output(name=2)]
    add(12,intro)
    r['sceneGraph']={'HandleId':'pending','Data':{'$type':'scnSceneGraph','graph':nodes,'startNodes':[rid('scnNodeId',1)],'endNodes':[rid('scnNodeId',9)]}}
    r['entryPoints']=[{'$type':'scnEntryPoint','name':cn('conversation_in'),'nodeId':rid('scnNodeId',1)}]
    r['exitPoints']=[{'$type':'scnExitPoint','name':cn('conversation_out'),'nodeId':rid('scnNodeId',9)}]
    words={'hello':c['hello'],'goodbye':c['goodbye'],'option1':c['choices'][0],'option2':c['choices'][1],'briefing':c['briefing']['text']}
    ids={k:fnv('NCPDPatrol_QG_'+k) for k in words};vd=[];vp=[]
    for k,text in words.items():
        for locale in ['en_us','db_db']:
            variant=fnv('NCPDPatrol_QG_'+k+'_'+locale)
            vd.append({'$type':'scnlocLocStoreEmbeddedVariantDescriptorEntry','localeId':locale,'locstringId':{'$type':'scnlocLocstringId','ruid':ids[k]},'signature':{'$type':'scnlocSignature','val':'3'},'variantId':{'$type':'scnlocVariantId','ruid':variant},'vpeIndex':len(vp)})
            vp.append({'$type':'scnlocLocStoreEmbeddedVariantPayloadEntry','content':text,'variantId':{'$type':'scnlocVariantId','ruid':variant}})
    r['locStore']={'$type':'scnlocLocStoreEmbedded','vdEntries':vd,'vpEntries':vp}
    lines=[];options=[]
    for item,key,speaker in [(1,'hello',0),(257,'goodbye',0),(513,'option1',1),(769,'option2',1),(1025,'briefing',0)]:
        x=copy.deepcopy(t['line']);x.update(itemId=rid('scnscreenplayItemId',item),speaker=rid('scnActorId',speaker),addressee=rid('scnActorId',1-speaker),locstringId={'$type':'scnlocLocstringId','ruid':ids[key]})
        clip=c['briefing']['clip'] if key=='briefing' else 'None'
        x['femaleLipsyncAnimationName']=cn(clip);x['maleLipsyncAnimationName']=cn(clip);lines.append(x)
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
    text={'Title':'NCPD: Investigator Contact (Test)','Objective':'Meet Lieutenant Mara Voss','Description':'Lieutenant Mara Voss has sent you a private message. Meet her at the supplied location, listen to her briefing and choose either reply.','Name':'Lt. Mara Voss',
        'SmsTitle':c['sms']['title'],'Invitation':c['sms']['text']}
    text['BriefingFull']=c['briefing']['text']
    for i,part in enumerate(c['briefing']['subtitle_parts'],1):text['BriefingPart'+str(i)]=part['text']
    onscreens=resource('JsonResource',root={'HandleId':'0','Data':{'$type':'localizationPersistenceOnScreenEntries','entries':[{'$type':'localizationPersistenceOnScreenEntry','primaryKey':fnv('NCPDPatrol_QG_'+k),'secondaryKey':'NCPDPatrol_QG_'+k,'femaleVariant':v,'maleVariant':v} for k,v in text.items()]}})
    lines=resource('JsonResource',root={'HandleId':'0','Data':{'$type':'localizationPersistenceSubtitleEntries','entries':[{'$type':'localizationPersistenceSubtitleEntry','stringId':ids[k],'femaleVariant':v,'maleVariant':v} for k,v in [('hello',c['hello']),('goodbye',c['goodbye']),('option1',c['choices'][0]),('option2',c['choices'][1]),('briefing',c['briefing']['text'])]]}})
    subtitles=resource('JsonResource',root={'HandleId':'0','Data':{'$type':'localizationPersistenceSubtitleMap','entries':[{'$type':'localizationPersistenceSubtitleMapEntry','subtitleFile':{'DepotPath':{'$type':'ResourcePath','$storage':'string','$value':DEPOT+'lines.json'},'Flags':'Soft'},'subtitleGroup':cn('quest')}]}})
    vomap=resource('JsonResource',root={'HandleId':'0','Data':{'$type':'locVoiceoverMap','entries':[{'$type':'locVoLineEntry','stringId':ids['briefing'],'femaleResPath':soft(DEPOT+'voss_briefing.wem'),'maleResPath':soft(DEPOT+'voss_briefing.wem')}]}})
    scene_path=(DEPOT+'conversation.scene').lower()
    lipmap=resource('animLipsyncMapping',languageCodeName=cn('en-us'),
        sceneEntries=[{'$type':'animLipsyncMappingSceneEntry','actorVoiceTags':[fnv('ncpd_patrol_qgiver_test_investigator')],'animSets':[soft(DEPOT+'voss_briefing.anims')]}],
        scenePaths=[fnv(scene_path)],scenePreviewPaths=[fnv(scene_path+'preview')])
    return {'conversation.scene.json':scn,'quest_giver.questphase.json':qp,'quest_giver.journal.json':journal,'onscreens.json.json':onscreens,'lines.json.json':lines,'subtitles.json.json':subtitles,'vomap.json.json':vomap,'voss.lipmap.json':lipmap,'voss_wait_pose.ent.json':pose_helper(c)},edges

def validate(docs):
    c=read('contract.json');s=docs['conversation.scene.json']['Data']['RootChunk'];g=s['sceneGraph']['Data']['graph'];byid={n['Data']['nodeId']['id']:n['Data'] for n in g}
    assert len(g)==12 and s['actors'][0]['acquisitionPlan']=='findInWorld'
    ref=s['actors'][0]['findActorInWorldParams']['actorRef'];assert ref['type']=='Tag' and ref['names']==[cn(c['tag']+'_npc')]
    assert s['actors'][0]['spawnDespawnParams']['isEnabled']==0
    assert len(s['workspots'])==len(s['workspotInstances'])==1
    workspot=s['workspots'][0]['Data'];instance=s['workspotInstances'][0]
    assert workspot['workspotResource']=={**soft(c['presentation']['workspot']),'Flags':'Default'}
    assert workspot['dataId']['id']==instance['dataId']['id']==instance['workspotInstanceId']['id']==1
    assert instance['playAtActorLocation']==1
    assert byid[1]['outputSockets'][0]['destinations'][0]['nodeId']['id']==12
    intro=byid[12];assert intro['sectionDuration']['stu']==c['presentation']['intro_ms']==500
    assert intro['outputSockets'][0]['destinations'][0]['nodeId']['id']==2
    assert all(e['Data']['$type']=='scnLookAtEvent' for e in intro['events'])
    assert not intro['outputSockets'][2]['destinations']
    assert not any(d['nodeId']['id']==11 for n in g for o in n['Data'].get('outputSockets',[]) for d in o['destinations'])
    pose=byid[11];assert pose['isockMappings'][1]==cn('In') and not any(o['destinations'] for o in pose['outputSockets'])
    command=pose['questNode']['Data'];params=command['paramsV1']['Data']
    assert command['$type']=='questUseWorkspotNodeDefinition' and command['entityReference']==ref
    assert params['function']=='UseWorkspot' and params['playAtActorLocation']==params['isWorkspotInfinite']==1
    assert params['isPlayer']==params['enableIdleMode']==params['jumpToEntry']==0 and params['workspotInstanceId']['id']==1
    helper=docs['voss_wait_pose.ent.json']['Data']['RootChunk']
    components=[x for x in walk(helper) if x.get('$type')=='workWorkspotResourceComponent']
    assert len(components)==2
    for component in components:
        assert component['id']=='19005001' and component['name']==cn(c['presentation']['helper_component'])
        assert component['workspotResource']=={**soft(c['presentation']['workspot']),'Flags':'Default'}
        assert all(p['Bits']==0 for p in component['localTransform']['Position'].values() if isinstance(p,dict))
    assert c['presentation']['spawn_height_offset']==0 and not c['presentation']['scene_restarts_pose']
    for n in [12,2,10,6,7,8]:
        events=[e['Data'] for e in byid[n]['events'] if e['Data']['$type']=='scnLookAtEvent'];assert len(events)==1
        event=events[0];basic=event['basicData']['basic']
        assert event['startTime']==0 and basic['isStart']==1 and basic['targetType']=='Actor'
        assert basic['performerId']['id']==1 and basic['targetPerformerId']['id']==257
        assert basic['targetSlot']==cn('pla_default_tgt') and basic['targetOffsetEntitySpace']=={'$type':'Vector4','W':0,'X':0,'Y':0,'Z':0}
        requests=event['basicData']['requests'];assert len(requests)==1 and requests[0]['bodyPart']==cn('Eyes')
        assert [x['partName'] for x in requests[0]['request']['additionalParts']['Elements']]==[cn('Head')]
    refs=s['resouresReferences'];assert len(refs['lipsyncAnimSets'])==1
    assert refs['lipsyncAnimSets'][0]['asyncRefLipsyncAnimSet']==soft(DEPOT+'voss_briefing.anims')
    assert not any(v for k,v in refs.items() if k not in ['$type','lipsyncAnimSets'])
    assert s['actors'][0]['lipsyncAnimSet']['id']==0 and s['playerActors'][0]['lipsyncAnimSet']['id']==4294967295
    assert byid[2]['outputSockets'][0]['destinations'][0]['nodeId']['id']==10
    assert byid[10]['outputSockets'][0]['destinations'][0]['nodeId']['id']==3
    events=[e for e in byid[10]['events'] if e['Data']['$type']=='scnDialogLineEvent'];assert len(events)==1
    event=events[0]['Data'];assert event['screenplayLineId']['id']==1025
    assert event['startTime']==c['briefing']['lead_in_ms']==300 and event['duration']==briefing_ms(c)
    assert byid[10]['sectionDuration']['stu']==event['startTime']+event['duration']+300
    spoken=next(x for x in s['screenplayStore']['lines'] if x['itemId']['id']==1025)
    assert spoken['speaker']['id']==0
    for x in s['screenplayStore']['lines']:
        clip=c['briefing']['clip'] if x['itemId']['id']==1025 else 'None'
        assert x['femaleLipsyncAnimationName']==x['maleLipsyncAnimationName']==cn(clip)
    voice=docs['vomap.json.json']['Data']['RootChunk']['root']['Data']['entries']
    assert len(voice)==1 and voice[0]['stringId']==spoken['locstringId']['ruid']
    assert voice[0]['femaleResPath']==voice[0]['maleResPath']==soft(DEPOT+'voss_briefing.wem')
    lip=docs['voss.lipmap.json']['Data']['RootChunk']
    assert lip['languageCodeName']==cn('en-us') and lip['scenePaths']==[fnv((DEPOT+'conversation.scene').lower())]
    assert lip['scenePreviewPaths']==[fnv((DEPOT+'conversation.scenepreview').lower())]
    assert lip['sceneEntries']==[{'$type':'animLipsyncMappingSceneEntry','actorVoiceTags':[s['actors'][0]['voicetagId']['id']],'animSets':[soft(DEPOT+'voss_briefing.anims')]}]
    ch=byid[3];assert len(ch['options'])==2
    for option,flag,line in [(0,4,6),(1,5,7)]:
        assert ch['outputSockets'][option]['destinations'][0]['nodeId']['id']==flag
        assert ch['outputSockets'][option]['destinations'][0]['isockStamp']['ordinal']==1
        assert byid[flag]['questNode']['Data']['type']['Data']['value']==option+1
        assert byid[flag]['outputSockets'][0]['destinations'][0]['nodeId']['id']==line
        assert byid[line]['outputSockets'][0]['destinations'][0]['nodeId']['id']==8
    assert byid[8]['outputSockets'][0]['destinations'][0]['nodeId']['id']==9
    assert {e['femaleVariant'] for e in docs['lines.json.json']['Data']['RootChunk']['root']['Data']['entries']}=={c['hello'],c['goodbye'],*c['choices'],c['briefing']['text']}
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
        for name in docs:
            run('convert','deserialize',DIR/name,'--outpath',depot);binary=name[:-5];body=(depot/binary).read_bytes();assert body[:4]==b'CR2W';expected[binary]=body
            run('convert','serialize',depot/binary,'--outpath',roundtrip)
        validate({name:json.loads((roundtrip/name).read_text(encoding='utf-8-sig')) for name in docs})
        media=read('media/manifest.json')
        for name in ['voss_briefing.anims','voss_briefing.wem']:
            body=(DIR/'media'/name).read_bytes()
            assert hashlib.sha256(body).hexdigest()==media['packaged'][name]['sha256']
            (depot/name).write_bytes(body);expected[name]=body
        run('pack',packed,'--outpath',out);archive=out/'NCPDPatrol_QuestGiverTest.archive';extracted=temp/'extracted';extracted.mkdir();run('extract',archive,'--outpath',extracted)
        assert {p.name:p.read_bytes() for p in extracted.rglob('*') if p.is_file()}==expected
        target=ROOT/'archive/pc/mod'/archive.name;shutil.copy2(archive,target)
        inputs=[DIR/n for n in ['contract.json','reference-templates.json','presentation-templates.json','sms-templates.json','subtitle-controller.reds.template','media/manifest.json','media/voss_briefing.anims','media/voss_briefing.wem',*docs]]+[ROOT/'assets/arrest/arrest_workspot.ent.json']
        (DIR/'compiled.json').write_text(json.dumps({'archive_path':target.relative_to(ROOT).as_posix(),'archive_sha256':hashlib.sha256(target.read_bytes()).hexdigest(),'resources':sorted(expected),'roundtrip_validated':True,'extracted_resource_bytes_compared':True,'authored_inputs':{p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in inputs},'actual_game_validation':False},indent=2)+'\n')
    print('PASS: voiced Voss briefing scene and localization compiled, round-tripped and extracted with both media files byte-identical')
if __name__=='__main__':main()
