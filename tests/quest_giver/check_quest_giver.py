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
        self.scn=docs['conversation.scene.json']['Data']['RootChunk']
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
                t=self.resolve(n['type']);path=self.resolve(t['path'])['realPath'];assert path.startswith(self.f.qroot)
                self.f.entries[path]['state']={'Inactive':1,'Active':2,'Succeeded':3,'Failed':4}[port];self.emit(i,'Out')
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
            event=n['events'][0]['Data'];item=event['screenplayLineId']['id']
            line=next(x for x in self.scn['screenplayStore']['lines'] if x['itemId']['id']==item)
            text=next(x['content'] for x in self.scn['locStore']['vpEntries'] if next(v for v in self.scn['locStore']['vdEntries'] if v['variantId']==x['variantId'])['locstringId']==line['locstringId'])
            self.lines.append(text);self.remaining=n['sectionDuration']['stu']/1000
        elif typ=='scnChoiceNode':self.choice_ready=True
        elif typ=='scnQuestNode':
            assert n['isockMappings'][ordinal]['$value']=='In','Scene routed choice into CutDestination'
            t=n['questNode']['Data']['type']['Data'];self.f.qfacts[t['factName']]=t['value'];self.scn_emit(n)
        elif typ=='scnEndNode':
            self.scene=None;self.f.qsceneOwned=False;self.emit(12,'conversation_out');self.run()
        else:raise AssertionError(typ)
    def scn_emit(self,n,option=0):
        out=next(s for s in n['outputSockets'] if s['stamp']['name']==0 and s['stamp']['ordinal']==option)
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
                if self.release<=0:self.f.qsceneOwned=False
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
        assert len(self.f.creates)==2
        npc,car=self.f.creates[1],self.f.creates[2]
        assert npc.appearanceName=='corpo__ncpd_wa_investigator__lvl3_02'
        assert abs(npc.orientation.Yaw+143.376)<.0001 and abs(car.orientation.Yaw+53.376)<.0001
        assert abs(((npc.position.x-car.position.x)**2+(npc.position.y-car.position.y)**2)**.5-4)<.0001
    def talk(self):
        self.f.playerPoint=self.lua.globals().Vector4.new(1424.737,-2752.759,204.665,1);self.step(1)
        assert self.f.qfacts['ncpd_patrol_qgiver_test_stage']==2
    def clear(self):
        assert self.f.qmod.clear(self.f.qstatus);self.step(2)
        assert not self.f.qmod.active() and self.f.manual==654 and self.f.wallet==0

def runtime(docs,legacy_guard=False):
    lua=engine_runtime();s=code(ROOT/'r6/scripts/NCPDPatrol/NCPDPatrolQuestGiverTest.reds')
    s=s.replace('local p = nil','local p = Vector4.new(0,0,0,0)')
    lua.globals().QNative=lua.execute(s)
    if legacy_guard:
        previous=subprocess.check_output(['git','show','281ec019319c67e332e1cdc99c1e6bc9f3f22ad9:'+PREFIX+'quest_giver_test.lua'],cwd=ROOT,text=True)
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
    for option in [0,1]:
        m=runtime(docs);m.step(1);assert not m.f.qmod.active() and len(m.f.creates)==0
        m.start();assert m.f.qpin.active and m.f.tracked.path==m.f.qroot+'/main/talk'
        m.arrive();m.talk();assert m.lines==['quest giver hello']
        m.step(4);assert not m.choice_ready and m.lines==['quest giver hello',assets.read('contract.json')['briefing']['text']]
        m.step(35);assert not m.choice_ready and m.f.qfacts['ncpd_patrol_qgiver_test_stage']==2
        assert m.f.entries[m.f.qroot].state==2 and m.f.wallet==0
        m.await_choices();assert m.choice_ready and len(m.lines)==2
        m.choose(option);m.step(2.5);assert m.lines[-1]=='quest giver goodbye'
        assert m.f.qfacts['ncpd_patrol_qgiver_test_stage']==2 and m.f.entries[m.f.qroot].state==2
        m.step(4);assert m.f.qfacts['ncpd_patrol_qgiver_test_stage']==3 and m.f.entries[m.f.qroot].state==3
        assert m.f.qmod.state().startswith('Quest completed after goodbye.')
        assert m.f.wallet==0 and not m.f.qpin.active and m.f.tracked.path=='story'
        m.f.qtagStale=True;m.clear();m.start();assert m.f.qfacts['ncpd_patrol_qgiver_test_choice']==0;m.clear()
    # Cancel at the native choice; actors remain until the scene releases.
    m=runtime(docs);m.start();m.arrive();m.f.qoverlay=True
    m.f.playerPoint=m.lua.globals().Vector4.new(1424.737,-2752.759,204.665,1);m.step(2)
    assert m.f.qfacts['ncpd_patrol_qgiver_test_stage']==1 and not m.lines
    m.f.qoverlay=False;m.talk();assert m.lines==['quest giver hello'];m.clear()
    # Cancelling during the uninterrupted briefing uses the same release gate.
    m=runtime(docs);m.start();m.arrive();m.talk();m.step(10)
    assert m.scene==10 and m.f.qsceneOwned and not m.choice_ready
    m.f.qmod.clear(m.f.qstatus);m.step(.25);assert len(m.f.deletes)==0 and m.f.qsceneOwned
    m.step(2);assert not m.f.qmod.active() and not m.f.qpin.active and m.f.entries[m.f.qroot].state==1
    m=runtime(docs);m.start();m.arrive();m.talk();m.await_choices()
    assert m.f.qsceneOwned and m.choice_ready
    m.f.qmod.clear(m.f.qstatus);m.step(.25);assert len(m.f.deletes)==0 and m.f.qsceneOwned
    m.step(2);assert not m.f.qmod.active() and not m.f.qpin.active and m.f.entries[m.f.qroot].state==1
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
    m=runtime(docs);m.f.qforeignScene=True;m.start();m.arrive();m.talk();m.await_choices()
    assert m.choice_ready;m.choose(0);m.step(7);assert m.f.qmod.state().startswith('Quest completed after goodbye.');m.clear()
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
    # A malformed scene socket must fail validation, rather than pretending a
    # clickable choice proves that the next dialogue node will execute.
    broken=copy.deepcopy(docs);choice=broken['conversation.scene.json']['Data']['RootChunk']['sceneGraph']['Data']['graph'][2]['Data']
    choice['outputSockets'][0]['destinations'][0]['isockStamp']['ordinal']=0
    try:assets.validate(broken)
    except AssertionError:pass
    else:raise AssertionError('Wrong scene quest-input ordinal accepted')
    sys.path.insert(0,str(HERE.parent/'cet_ui'));from check_cet_ui import runtime as ui
    _,f=ui(ROOT/PREFIX)
    for label,event in [('TEST: Activate quest giver quest','questGiver.start'),('Clear quest giver test','questGiver.clear')]:
        f.ClearEvents(f);f.Frame(f,'Testing',label);assert f.clicks==1 and f.Events(f).count(event)==1
    for path in ['dispatch.lua','officer_down.lua','officer_down_sites.lua','marker_navigation.lua']:
        rel=PREFIX+path;assert (ROOT/rel).read_bytes()==subprocess.check_output(['git','show',f'{BASE}:{rel}'],cwd=ROOT),path
    print('PASS: isolated quest giver: actual native/Lua bridge and authored scene/quest graphs, hello/uninterrupted Voss briefing/two choices/silent V reply/goodbye/journal success, no early choices or completion, correct scene input ordinals, background-scene activation with dialogue/tier guards retained, no payout/progress writes, private two-actor staging, geometry rejection, cancellation during briefing and choices with scene-release gate, refused/deferred/tag-tombstone cleanup, replay and load recovery; existing dispatch/marker code unchanged (engine boundaries mocked)')
    return {'npc_briefing_voice':True,'player_voice':False,'uninterrupted_briefing_before_choices':True,'choices':2,'dialogue_paths_executed':2,'complete_only_after_goodbye':True,
        'spawned_private_actors':2,'geometry_checked_before_spawn':True,'scene_release_before_deletion':True,
        'cleanup_and_replay':True,'save_cet_recovery':True,'existing_dispatch_unchanged':True,
        'no_rewards_or_career_changes':True,'compiled_assets':manifest,'actual_game_validation':False,
        'previous_scene_membership_false_rejection_reproduced':True,
        'background_scene_membership_allows_start_and_greeting':True,
        'actual_dialogue_and_restricted_tiers_block_both_entry_points':True}

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--report',type=Path);a=p.parse_args();report=main()
    if a.report:a.report.write_text(json.dumps(report,indent=2)+'\n')
