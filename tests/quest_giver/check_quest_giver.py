"""Execute actual Lua/native bridge plus the authored quest and scene graphs."""
from pathlib import Path
from collections import deque
import argparse,copy,hashlib,importlib.util,json,subprocess,sys
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
sys.path.insert(0,str(HERE.parent/'officer_down'))
from check_officer_down import engine_runtime,code
sys.path.insert(0,str(ROOT/'tools'));import build_quest_giver_assets as assets
BASE='b30655074198aa958a289fb826b6e1e180907e2e'
PREFIX='bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrol/'

class Machine:
    """Engine boundary interpreter: resources supply every transition/result."""
    def __init__(self,lua,docs):
        self.lua=lua;self.f=lua.globals().F;self.handles={};self.queue=deque();self.waits=set();self.scene=None
        self.release=0;self.lines=[];self.choice_ready=False;self.scn_nodes={n['Data']['nodeId']['id']:n['Data'] for n in docs['conversation.scene.json']['Data']['RootChunk']['sceneGraph']['Data']['graph']}
        self.legacy_workspot_requests=0;self.look_at=None
        self.scn=docs['conversation.scene.json']['Data']['RootChunk']
        self.phone={};self.sms_notifications=[]
        def register(ref,parent=''):
            entry=ref['Data'];path='/'.join(x for x in [parent,entry.get('id','')] if x)
            if entry['$type'] in ['gameJournalContact','gameJournalPhoneConversation','gameJournalPhoneMessage']:
                self.phone[path]=(entry,parent)
                self.f.entries[path]=lua.table_from({'path':path,'kind':entry['$type'],'state':1})
            for child in entry.get('entries',[]):register(child,path)
        register(docs['quest_giver.journal.json']['Data']['RootChunk']['entry'])
        self.onscreens={e['secondaryKey']:e['femaleVariant'] for e in docs['onscreens.json.json']['Data']['RootChunk']['root']['Data']['entries']}
        for x in assets.walk(docs['quest_giver.questphase.json']):
            if 'HandleId' in x:self.handles[x['HandleId']]=x['Data']
        graph=self.resolve(docs['quest_giver.questphase.json']['Data']['RootChunk']['graph'])
        self.nodes={self.resolve(n)['id']:self.resolve(n) for n in graph['nodes']}
        self.owner={}
        for i,n in self.nodes.items():
            for s in n['sockets']:
                key=s.get('HandleId',s.get('HandleRefId'));self.owner[key]=(i,self.resolve(s)['name']['$value'])
        self.activate(0,'In');self.run()
    def resolve(self,ref):return self.handles[ref.get('HandleId',ref.get('HandleRefId'))]
    def fact(self,key):return self.f.qfacts[key] or 0
    def condition(self,c):
        c=self.resolve(c);t=self.resolve(c['type']);v=self.fact(t['factName'])
        return {'Greater':v>t['value'],'Equal':v==t['value']}[t['comparisonType']]
    def emit(self,i,name):
        for s in self.nodes[i]['sockets']:
            socket=self.resolve(s)
            if socket['name']['$value']==name:
                for edge in socket['connections']:
                    target=self.resolve(edge)['destination'];key=target.get('HandleId',target.get('HandleRefId'))
                    self.queue.append(self.owner[key])
    def activate(self,i,port):self.queue.append((i,port))
    def run(self):
        budget=1000
        while self.queue:
            budget-=1;assert budget>0,'Graph did not reach a passive boundary'
            i,port=self.queue.popleft();n=self.nodes[i];typ=n['$type']
            if port=='CutDestination':
                self.waits.discard(i);self.queue=deque((k,p) for k,p in self.queue if k!=i)
                if typ=='questSceneNodeDefinition' and self.scene is not None:
                    self.scene=None;self.choice_ready=False;self.release=.75
                continue
            if typ=='questInputNodeDefinition':self.emit(i,'Out')
            elif typ=='questFactsDBManagerNodeDefinition':
                t=self.resolve(n['type']);assert t['factName'].startswith('ncpd_patrol_qgiver_test_')
                self.f.qfacts[t['factName']]=t['value'];self.emit(i,'Out')
            elif typ=='questPauseConditionNodeDefinition':
                if self.condition(n['condition']):self.emit(i,'Out')
                else:self.waits.add(i)
            elif typ=='questConditionNodeDefinition':self.emit(i,'True' if self.condition(n['condition']) else 'False')
            elif typ=='questJournalNodeDefinition':
                t=self.resolve(n['type']);path=self.resolve(t['path'])['realPath'];assert path.startswith(self.f.qroot) or path in self.phone
                previous=self.f.entries[path].state
                self.f.entries[path]['state']={'Inactive':1,'Active':2,'Succeeded':3,'Failed':4}[port];self.emit(i,'Out')
                if path in self.phone:
                    entry,parent=self.phone[path]
                    assert self.resolve(t['path'])['className']['$value']==entry['$type']
                    if entry['$type']=='gameJournalPhoneMessage' and port=='Active' and previous!=2 and t['sendNotification']:
                        assert entry['sender']=='NPC' and self.f.entries[parent].state==2
                        thread,contact_path=self.phone[parent];contact,_=self.phone[contact_path]
                        assert self.f.entries[contact_path].state==2
                        self.sms_notifications.append({'path':path,'contact':self.onscreens[contact['name']['value']],
                            'text':self.onscreens[entry['text']['value']],'attachment':entry['attachment']['Data']['realPath']})
            elif typ=='questMappinManagerNodeDefinition':
                path=self.resolve(n['path'])['realPath'];assert path==self.f.qroot+'/main/talk/location' and not n['disablePreviousMappins']
                self.f.qpin.active=port=='Active';self.emit(i,'Out')
            elif typ=='questCutControlNodeDefinition':self.emit(i,'CutSource');self.emit(i,'Out')
            elif typ=='questSceneNodeDefinition':
                assert port=='conversation_in' and 'quest_giver_test' in n['sceneFile']['DepotPath']['$value']
                assert n['sceneLocation']['type']=='Tag' and self.f.qsceneOwned is False
                self.f.qsceneOwned=True;self.enter_scene(1)
            else:raise AssertionError(typ)
    def enter_scene(self,i,ordinal=0):
        n=self.scn_nodes[i];typ=n['$type'];self.scene=i
        if typ=='scnStartNode':self.scn_emit(n)
        elif typ=='scnSectionNode':
            self.remaining=n['sectionDuration']['stu']/1000
            for wrapped in n['events']:
                event=wrapped['Data']
                if event['$type']=='scnDialogLineEvent':
                    item=event['screenplayLineId']['id']
                    line=next(x for x in self.scn['screenplayStore']['lines'] if x['itemId']['id']==item)
                    text=next(x['content'] for x in self.scn['locStore']['vpEntries'] if next(v for v in self.scn['locStore']['vdEntries'] if v['variantId']==x['variantId'])['locstringId']==line['locstringId'])
                    self.lines.append(text)
                elif event['$type']=='scnLookAtEvent':self.look_at=event['basicData']['basic']
                elif event['$type']=='scneventsSocket':
                    # A scene socket forks a background command without
                    # replacing the main dialogue section or waiting on exit.
                    self.scn_emit(n,event['osockStamp']['ordinal'],event['osockStamp']['name']);self.scene=i
                else:raise AssertionError(event['$type'])
        elif typ=='scnChoiceNode':self.choice_ready=True
        elif typ=='scnQuestNode':
            assert n['isockMappings'][ordinal]['$value']=='In','Scene routed choice into CutDestination'
            command=n['questNode']['Data']
            if command['$type']=='questUseWorkspotNodeDefinition':
                assert command['paramsV1']['Data']['isPlayer']==0
                self.legacy_workspot_requests+=1
            else:
                t=command['type']['Data'];self.f.qfacts[t['factName']]=t['value'];self.scn_emit(n)
        elif typ=='scnEndNode':
            self.scene=None;self.f.qsceneOwned=False;self.look_at=None;self.emit(12,'conversation_out');self.run()
        else:raise AssertionError(typ)
    def scn_emit(self,n,option=0,name=0):
        out=next(s for s in n['outputSockets'] if s['stamp']['name']==name and s['stamp']['ordinal']==option)
        dest=out['destinations'][0];self.enter_scene(dest['nodeId']['id'],dest['isockStamp']['ordinal'])
    def choose(self,option):
        assert self.choice_ready and option in [0,1]
        self.choice_ready=False;self.scn_emit(self.scn_nodes[self.scene],option)
    def await_choices(self):
        for _ in range(240):
            if self.choice_ready:return
            self.step(.25)
        raise AssertionError('Briefing did not reach the two native choices')
    def step(self,seconds=.25):
        for _ in range(round(seconds/.25)):
            if not self.f.ready or self.f.menu:continue
            if self.release>0:
                self.release-=.25
                if self.release<=0:self.f.qsceneOwned=False;self.look_at=None
            for i in list(self.waits):
                if self.condition(self.nodes[i]['condition']):self.waits.remove(i);self.emit(i,'Out')
            self.run()
            if self.scene is not None and self.scn_nodes[self.scene]['$type']=='scnSectionNode':
                self.remaining-=.25
                if self.remaining<=0:self.scn_emit(self.scn_nodes[self.scene])
            self.f.qmod.update(.25)
    def start(self):
        assert self.f.qmod.start(self.f.qstatus);self.step(.5)
    def arrive(self):
        self.f.playerPoint=self.lua.globals().Vector4.new(1424.737,-2750.759,204.665,1);self.step(1)
        assert len(self.f.creates)==3
        npc,car=self.f.creates[1],self.f.creates[2]
        assert npc.appearanceName=='corpo__ncpd_wa_investigator__lvl3_02'
        assert abs(npc.orientation.Yaw+143.376)<.0001 and abs(car.orientation.Yaw+53.376)<.0001
        assert abs(((npc.position.x-car.position.x)**2+(npc.position.y-car.position.y)**2)**.5-4)<.0001
        assert npc.position.z==self.f.qpoint.z+self.f.surfaceOffset
        assert self.f.creates[3].position.z==npc.position.z and self.f.qPoseActive()
        assert len(self.f.qposeCalls)==1 and not self.f.qsceneOwned
    def talk(self):
        self.f.playerPoint=self.lua.globals().Vector4.new(1424.737,-2752.759,204.665,1);self.step(1)
        assert self.f.qfacts['ncpd_patrol_qgiver_test_stage']==2
    def finish_conversation(self):
        for _ in range(1200):
            assert not self.choice_ready,'Automatic dialogue exposed a choice'
            if self.f.qfacts['ncpd_patrol_qgiver_test_stage']==3:return
            self.step(.25)
        raise AssertionError('Automatic conversation did not finish')
    def clear(self):
        assert self.f.qmod.clear(self.f.qstatus);self.step(2)
        assert not self.f.qmod.active() and self.f.manual==654 and self.f.wallet==0

def runtime(docs,legacy_guard=False,legacy_pose=False):
    lua=engine_runtime();s=code(ROOT/'r6/scripts/NCPDPatrol/NCPDPatrolQuestGiverTest.reds')
    s=s.replace('local p = nil','local p = Vector4.new(0,0,0,0)')
    lua.globals().QNative=lua.execute(s)
    if legacy_guard:
        # Keep the original API version for the historical Lua-only guard
        # regression; the current source's two resource getters are additive.
        lua.globals().QNative.Version=lambda _self:1
        previous=subprocess.check_output(['git','show','281ec019319c67e332e1cdc99c1e6bc9f3f22ad9:'+PREFIX+'quest_giver_test.lua'],cwd=ROOT,text=True)
        lua.globals().PreviousQuestGiver=lua.execute(previous)
        lua.execute("package.loaded.quest_giver_test=PreviousQuestGiver")
    if legacy_pose:
        previous=subprocess.check_output(['git','show','d9d49cc8084efdcd329d2ddb9572eb2bf254f963:'+PREFIX+'quest_giver_test.lua'],cwd=ROOT,text=True)
        lua.globals().PreviousQuestGiver=lua.execute(previous)
        lua.execute("package.loaded.quest_giver_test=PreviousQuestGiver")
    lua.execute((HERE/'engine.lua').read_text())
    return Machine(lua,docs)

def main():
    docs,_=assets.outputs();assets.validate(docs)
    for name,doc in docs.items():assert json.loads((assets.DIR/name).read_text())==doc,name
    manifest=assets.read('compiled.json')
    assert manifest['roundtrip_validated'] and manifest['extracted_resource_bytes_compared']
    assert hashlib.sha256((ROOT/manifest['archive_path']).read_bytes()).hexdigest()==manifest['archive_sha256']
    for path,sha in manifest['authored_inputs'].items():assert hashlib.sha256((ROOT/path).read_bytes()).hexdigest()==sha,path
    m=runtime(docs);contract=assets.read('contract.json')
    assert m.lua.eval('QNative:GetPoseHelperTemplate()')==contract['presentation']['helper_template']
    assert m.lua.eval('QNative:GetPoseResource()')==contract['presentation']['workspot']
    m.lua.execute('QNative.Version=function() return 1 end')
    assert not m.f.qmod.start(m.f.qstatus) and len(m.f.creates)==0
    assert 'complete v0.19e' in m.f.qlog[len(m.f.qlog)]
    m=runtime(docs);m.step(1);assert not m.f.qmod.active() and len(m.f.creates)==0 and not m.sms_notifications
    m.start();assert m.f.qpin.active and m.f.tracked.path==m.f.qroot+'/main/talk'
    assert len(m.sms_notifications)==1 and m.sms_notifications[0]['text']==contract['sms']['text']
    assert m.sms_notifications[0]['contact']=='Lt. Mara Voss' and m.sms_notifications[0]['attachment']==m.f.qroot
    m.arrive();m.talk();assert m.lines==[contract['conversation'][0]['text']]
    assert len(m.f.qposeCalls)==1 and m.f.qPoseActive() and m.legacy_workspot_requests==0
    assert m.look_at['targetSlot']['$value']=='pla_default_tgt' and m.look_at['targetPerformerId']['id']==257
    m.step(8);assert not m.choice_ready and m.f.qfacts['ncpd_patrol_qgiver_test_choice']==0
    assert m.f.qfacts['ncpd_patrol_qgiver_test_stage']==2 and m.f.entries[m.f.qroot].state==2 and m.f.wallet==0
    m.finish_conversation()
    assert m.lines==[row['text'] for row in contract['conversation']] and not m.choice_ready
    assert m.f.qfacts['ncpd_patrol_qgiver_test_stage']==3 and m.f.qfacts['ncpd_patrol_qgiver_test_choice']==1 and m.f.entries[m.f.qroot].state==3
    assert m.f.qPoseActive() and len(m.f.qposeCalls)==1 and m.look_at is None
    assert m.f.qmod.state().startswith('Quest completed after goodbye.')
    assert m.f.wallet==0 and not m.f.qpin.active and m.f.tracked.path=='story'
    m.step(30);assert len(m.f.deletes)==0 and m.f.qPoseActive()
    sms_path=m.sms_notifications[0]['path'];m.f.qtagStale=True;m.clear()
    assert len(m.sms_notifications)==1 and m.f.entries[sms_path].state==2
    m.start();assert m.f.qfacts['ncpd_patrol_qgiver_test_choice']==0 and len(m.sms_notifications)==2
    assert len([p for p in m.phone if m.phone[p][0]['$type']=='gameJournalPhoneMessage'])==1;m.clear()
    # Ordinary updates do not resend the SMS. Reading it is optional; the
    # existing travel/proximity trigger still owns the start of the scene.
    m=runtime(docs);m.start();m.step(30)
    assert len(m.sms_notifications)==1 and m.f.qfacts['ncpd_patrol_qgiver_test_stage']==1 and not m.lines
    m.clear();assert len(m.sms_notifications)==1 and m.f.entries[m.sms_notifications[0]['path']].state==2
    # Overlay blocks proximity dialogue; cancellation waits for scene release.
    m=runtime(docs);m.start();m.arrive();m.f.qoverlay=True
    m.f.playerPoint=m.lua.globals().Vector4.new(1424.737,-2752.759,204.665,1);m.step(2)
    assert m.f.qfacts['ncpd_patrol_qgiver_test_stage']==1 and not m.lines
    m.f.qoverlay=False;m.talk();assert m.lines==[contract['conversation'][0]['text']];m.clear()
    # Cancelling during the uninterrupted briefing uses the same release gate.
    m=runtime(docs);m.start();m.arrive();m.talk();m.step(10)
    assert m.scene==1000 and m.f.qsceneOwned and not m.choice_ready
    m.f.qmod.clear(m.f.qstatus);m.step(.25);assert len(m.f.deletes)==0 and m.f.qsceneOwned
    m.step(2);assert not m.f.qmod.active() and not m.f.qpin.active and m.f.entries[m.f.qroot].state==1
    assert not m.f.qPoseActive() and m.look_at is None
    m=runtime(docs);m.start();m.arrive();m.talk();m.step(35)
    assert m.f.qsceneOwned and not m.choice_ready
    m.f.qmod.clear(m.f.qstatus);m.step(.25);assert len(m.f.deletes)==0 and m.f.qsceneOwned
    m.step(2);assert not m.f.qmod.active() and not m.f.qpin.active and m.f.entries[m.f.qroot].state==1
    assert not m.f.qPoseActive() and m.look_at is None
    # Reproduce the reported v0.19f false negative with its actual Lua: Voss is
    # in an active pose but no device-user mapping exists, so the old watchdog
    # incorrectly deletes the complete scene after eight seconds.
    old=runtime(docs,legacy_pose=True);old.f.qposeNoDeviceUser=True;old.start();old.arrive()
    assert old.f.qPoseActive() and not old.lines
    old.step(12);assert not old.f.qmod.active() and not old.f.qPoseActive() and len(old.f.deletes)==3
    assert 'waiting pose did not become active' in old.f.qmod.diagnostics()
    for attempt in [0,1]:
        m=runtime(docs);m.f.qposeNoDeviceUser=True;m.start();m.arrive();m.step(15)
        assert m.f.qPoseActive() and len(m.f.deletes)==0 and m.f.qmod.active()
        assert 'phase=approaching' in m.f.qmod.diagnostics() and 'device user=not registered' in m.f.qmod.diagnostics()
        assert 'last failure=none' in m.f.qmod.diagnostics()
        m.talk();m.finish_conversation()
        assert m.f.qmod.state().startswith('Quest completed after goodbye.') and len(m.f.qposeCalls)==1
        m.clear();assert not m.f.qPoseActive()
    # Real native entry/exit states cannot be mistaken for a stable pose, and
    # a different helper user is never counted as confirmation.
    for flag in ['qposeEntering','qposeExiting','qposeOtherDeviceUser','qposeNoInfo']:
        m=runtime(docs);setattr(m.f,flag,True);m.start();m.arrive();m.step(3)
        assert 'phase=posing' in m.f.qmod.diagnostics() and len(m.f.deletes)==0,flag
        setattr(m.f,flag,False);m.step(1)
        assert 'phase=approaching' in m.f.qmod.diagnostics() and 'last failure=none' in m.f.qmod.diagnostics(),flag
        m.clear()
    # Missing, slow or unconfirmed cosmetic resources/playback have a bounded
    # preparation phase, but preserve Voss, the Hella, SMS and meeting quest.
    for flag in ['qposeResourcesMissing','qposeLoadFailed','qposeLoadPending','qposePlayFailed']:
        m=runtime(docs);setattr(m.f,flag,True);m.start()
        m.f.playerPoint=m.lua.globals().Vector4.new(1424.737,-2750.759,204.665,1);m.step(12)
        assert m.f.qmod.active() and not m.f.qPoseActive() and not m.lines and m.f.wallet==0 and len(m.f.deletes)==0,flag
        assert m.f.qfacts['ncpd_patrol_qgiver_test_stage']==1 and m.f.qpin.active and 'pose=unconfirmed' in m.f.qmod.diagnostics(),flag
        m.talk();m.finish_conversation()
        assert m.f.qmod.state().startswith('Quest completed after goodbye.') and len(m.f.deletes)==0,flag
        m.clear()
    # A grounded pose starts at the recorded floor, including small legitimate
    # site-height differences, before V enters the talk radius.
    for height in [-.4,0,.4]:
        m=runtime(docs);m.f.surfaceOffset=height;m.start();m.arrive();m.step(30)
        assert m.f.qPoseActive() and len(m.f.qposeCalls)==1 and not m.lines
        m.talk();assert len(m.f.qposeCalls)==1 and m.f.qPoseActive();m.clear()
    # A menu pauses the setup budget. Cancelling a pending load cannot create
    # a late helper after the private actors have already been cleared.
    m=runtime(docs);m.f.qposeLoadPending=True;m.start()
    m.f.playerPoint=m.lua.globals().Vector4.new(1424.737,-2750.759,204.665,1);m.step(4)
    m.f.menu=True;m.step(90);assert m.f.qmod.active() and len(m.f.creates)==2
    m.f.menu=False;m.clear();m.f.qposeLoadPending=False;m.step(5)
    assert len(m.f.creates)==2 and not m.f.qmod.active() and not m.f.qPoseActive()
    # Refused/deferred deletion must retain ownership and prevent a new test.
    for deferred in [False,True]:
        m=runtime(docs);m.start();m.arrive();m.f.deleteDeferred=deferred;m.f.deleteOK=deferred
        m.f.qmod.clear(m.f.qstatus);m.step(1);assert m.f.qmod.active() and not m.f.qmod.start(m.f.qstatus)
        m.f.deleteOK=True;m.f.deleteDeferred=False
        if deferred:m.f.qCompleteDeletes()
        m.step(1);assert not m.f.qmod.active() and m.f.managed[999]
    # Geometry is checked for the whole car and NPC before either is created.
    for key,value in [('noGround',True),('lowerFloor',True),('normalZ',.5),('obstruction',True),('vehiclePresent',True),('noNav',True)]:
        m=runtime(docs);setattr(m.f,key,value);m.start();m.f.playerPoint=m.f.qpoint;m.step(2)
        assert len(m.f.creates)==0 and m.f.wallet==0 and not m.f.qmod.active(),key
    for key in ['duty','wanted','combat','menu','qforeignDialogue','qsurvey','qdispatch']:
        m=runtime(docs);setattr(m.f,key,True);assert not m.f.qmod.start(m.f.qstatus) and len(m.f.creates)==0,key
    # Reproduce v0.19a's rejection using its actual previous module. Mere
    # membership in a background scene must allow activation and greeting.
    old=runtime(docs,legacy_guard=True);old.f.qforeignScene=True
    assert not old.f.qmod.start(old.f.qstatus)
    assert 'Finish the current game scene' in old.f.qlog[len(old.f.qlog)]
    m=runtime(docs);m.f.qforeignScene=True;m.start();m.arrive();m.talk();m.step(35)
    m.finish_conversation();assert m.f.qmod.state().startswith('Quest completed after goodbye.');m.clear()
    # Real conversations/restricted tiers still block both entry points.
    for tier in [2,3,4,5]:
        m=runtime(docs);m.f.qsceneTier=tier
        assert not m.f.qmod.start(m.f.qstatus) and len(m.f.creates)==0,tier
    for key,value in [('qforeignDialogue',True),('qsceneTier',3)]:
        m=runtime(docs);m.start();m.arrive();setattr(m.f,key,value)
        m.f.playerPoint=m.lua.globals().Vector4.new(1424.737,-2752.759,204.665,1);m.step(2)
        assert m.f.qfacts['ncpd_patrol_qgiver_test_stage']==1 and not m.lines,key
        setattr(m.f,key,False if key=='qforeignDialogue' else 1);m.talk();m.clear()
    # Loading/CET recovery works from the current world's private tags only.
    m=runtime(docs);m.start();m.arrive();m.talk()
    m.f.ready=False;m.f.qmod.reset();m.step(5);assert len(m.f.deletes)==0
    m.f.ready=True;m.step(3);assert not m.f.qmod.active() and m.f.managed[999] and m.f.wallet==0
    m=runtime(docs);m.f.failCreateAt=2;m.start();m.f.playerPoint=m.f.qpoint;m.step(3)
    assert not m.f.qmod.active() and len(m.f.deletes)==1 and m.f.managed[999]
    # The automatic final receipt must enter its fact command, never the cut
    # socket; a displayable subtitle alone is not a completion proof.
    broken=copy.deepcopy(docs)
    final=next(n['Data'] for n in broken['conversation.scene.json']['Data']['RootChunk']['sceneGraph']['Data']['graph'] if n['Data']['nodeId']['id']==1009)
    final['outputSockets'][0]['destinations'][0]['isockStamp']['ordinal']=0
    try:assets.validate(broken)
    except AssertionError:pass
    else:raise AssertionError('Wrong completion-receipt quest-input ordinal accepted')
    sys.path.insert(0,str(HERE.parent/'cet_ui'));from check_cet_ui import runtime as ui
    _,f=ui(ROOT/PREFIX)
    for label,event in [('TEST: Activate quest giver quest','questGiver.start'),('Clear quest giver test','questGiver.clear')]:
        f.ClearEvents(f);f.Frame(f,'Testing',label);assert f.clicks==1 and f.Events(f).count(event)==1
    for path in ['dispatch.lua','officer_down.lua','officer_down_sites.lua','marker_navigation.lua']:
        rel=PREFIX+path;assert (ROOT/rel).read_bytes()==subprocess.check_output(['git','show',f'{BASE}:{rel}'],cwd=ROOT),path
    print('PASS: isolated quest giver: actual v0.19f active-pose/no-device-user despawn reproduced and prevented; real native entering/exiting fields, exact-actor stable activity and no pose restart; cosmetic failures retain both actors/SMS/quest and allow dialogue; explicit helper-before-puppet cleanup, menu/cancel/recovery, all ten automatic speech turns/final receipt/journal success; dispatch/markers unchanged (engine boundaries mocked)')
    return {'npc_briefing_voice':True,'player_voice':True,'automatic_replies':True,'speech_turns':10,'native_v_replies':4,'choices':0,'dialogue_paths_executed':1,'complete_only_after_goodbye':True,
        'grounded_waiting_pose_executed':True,'workspot_ready_before_conversation':True,
        'v019f_active_pose_missing_device_user_despawn_reproduced':True,
        'native_activity_without_device_user_completes_automatic_dialogue':True,
        'native_extended_info_entering_exiting_fields_checked':True,
        'cosmetic_pose_failure_retains_actors_and_quest':True,
        'native_look_at_target_slot':'pla_default_tgt','look_at_release_on_completion_and_pose_release_on_clear':True,
        'native_sms_intro':True,'sms_notifications_per_explicit_start':1,'sms_history_retained_on_clear':True,
        'sms_exact_text_and_quest_attachment':True,'no_duplicate_message_entries':True,
        'spawned_private_actors':2,'spawned_private_pose_devices':1,'geometry_checked_before_spawn':True,'scene_release_before_deletion':True,
        'pose_device_detaches_before_puppet_deletion':True,'no_body_pose_restart_at_greeting':True,
        'cleanup_and_replay':True,'save_cet_recovery':True,'existing_dispatch_unchanged':True,
        'no_rewards_or_career_changes':True,'compiled_assets':manifest,'actual_game_validation':False,
        'previous_scene_membership_false_rejection_reproduced':True,
        'background_scene_membership_allows_start_and_greeting':True,
        'actual_dialogue_and_restricted_tiers_block_both_entry_points':True}

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--report',type=Path);a=p.parse_args();report=main()
    if a.report:a.report.write_text(json.dumps(report,indent=2)+'\n')
