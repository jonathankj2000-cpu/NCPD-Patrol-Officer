"""Execute the off-duty native quest/events and actual Lua over recording services.

The fixture models native readable auto-consumption independently. Actor AI,
animation, actual loot UI and save serialization still require the game.
"""
from pathlib import Path
from tempfile import TemporaryDirectory
import argparse, hashlib, json, sys
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
sys.path.insert(0,str(HERE.parent/'quest_giver'))
from check_quest_giver import runtime as first_runtime,assets as first_assets,code
sys.path.insert(0,str(HERE.parent/'arrests'));from translate import translate
sys.path.insert(0,str(HERE.parent/'fixed_markers'));from check_fixed import journal_hash
sys.path.insert(0,str(ROOT/'tools'));import build_off_the_books_assets as assets
PREFIX='bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrol/'
ROOTPATH='quests/minor_quest/ncpd_patrol_off_the_books'

def runtime(retain=True,documents=None):
    docs=assets.outputs();assets.validate(docs)
    m=first_runtime(documents or first_assets.outputs()[0]);lua=m.lua;g=lua.globals()
    native=code(ROOT/'r6/scripts/NCPDPatrol/NCPDPatrolOffBooksSystem.reds')
    native=native.replace('local p = nil','local p = Vector4.new(0,0,0,0)').replace('new AIHoldPositionCommand()','NewOTBHold()')
    native=native.replace('path + ','path .. ')
    native=native.replace('self:Objective(self:GetStage()) + ','self:Objective(self:GetStage()) .. ')
    import re
    native=re.sub(r'(self:Objective\([^)]*\)) \+ ',r'\1 .. ',native)
    g.Books=lua.execute(native)
    from encounter_fixture import prepare
    prepare(lua)
    event=(ROOT/'r6/scripts/NCPDPatrol/NCPDPatrolOffBooksEvents.reds').read_text()
    with TemporaryDirectory(prefix='ncpd-offbooks-events-') as d:
        for owner,name,original in [('NPCPuppet','HitObserver','OriginalOTBHit'),('PlayerPuppet','ItemObserver','OriginalOTBAdded')]:
            body=event.split('@wrapMethod('+owner+')')[1].split('@wrapMethod')[0]
            body=body.replace('wrappedMethod(evt)',original+'(this, evt)')
            p=Path(d)/(name+'.reds');p.write_text('public class '+name+' extends IScriptable {\n'+body+'\n}')
            g[name]=lua.execute(translate(p))
    ref=json.loads((ROOT/'assets/quest_marker_probe/reference-contract.json').read_text())
    entries={};pins={}
    def register(wrapped,parent=''):
        row=wrapped['Data'];path='/'.join(x for x in [parent,row.get('id','')] if x)
        entries[path]={'path':path,'kind':row['$type'],'state':1}
        if row['$type']=='gameJournalQuestMapPin':
            pins[path]={'index':len(pins)+1,'hash':journal_hash(path),**{a:ref['position'][a.upper()]+row['offset'][a.upper()]-ref['offset'][a.upper()] for a in ['x','y','z']}}
        for child in row.get('entries',[]):register(child,path)
    register(docs['off_the_books.journal.json']['Data']['RootChunk']['entry'])
    assert len(pins)==3
    g.OTBEntries=lua.table_from(entries,recursive=True);g.OTBPins=lua.table_from(pins,recursive=True)
    lua.execute((HERE/'engine.lua').read_text())
    lua.execute((HERE/'encounter_engine.lua').read_text())
    if retain:m.f.obConfigureRetention()
    oldstep=m.step
    def step(seconds=.25):
        for _ in range(round(seconds/.25)):
            m.f.obAdvance(.25);m.f.books.update(.25);oldstep(.25)
    m.step=step;m.books=g.Books
    return m

def fact(m,key):return m.f.qfacts['ncpd_patrol_otb_'+key] or 0
def position(m,x=-649.795,y=929.771,z=9.4):m.f.playerPoint=m.lua.globals().Vector4.new(x,y,z,1)
def briefing(m):m.start();m.arrive();m.talk();m.finish_conversation();m.step(2);assert fact(m,'stage')==1,m.f.books.diagnostics()
def encounter(m):briefing(m);position(m);m.step(2);assert len(m.f.creates)==6,m.f.books.diagnostics()
def killed(m):m.f.obRole('target').dead=True;m.step(1)
def restore(m):m.books.OnRestored(m.books,0,0);m.f.books.reset();m.f.qmod.reset();m.step(2)
def state(m,obj):return m.f.entries[ROOTPATH+'/main/'+obj].state

def main():
    docs=assets.outputs();assets.validate(docs)
    for name,doc in docs.items():assert json.loads((assets.DIR/name).read_text())==doc,name
    compiled=assets.read('compiled.json')
    assert compiled['roundtrip_validated'] and compiled['extracted_resource_bytes_compared']
    assert hashlib.sha256((ROOT/compiled['archive_path']).read_bytes()).hexdigest()==compiled['archive_sha256']
    for path,digest in compiled['authored_inputs'].items():assert hashlib.sha256((ROOT/path).read_bytes()).hexdigest()==digest,path
    m=runtime();m.step(2);assert fact(m,'stage')==0 and len(m.f.creates)==0
    assert not m.f.books.begin(m.f.obStatus) and len(m.f.creates)==0
    # Fully execute the existing ten-turn first conversation, then a separate
    # quest. No fabricated first-scene completion and no dispatch reservation.
    encounter(m);assert fact(m,'seeded')==1 and m.f.obseedCount==1 and fact(m,'cycle')==1
    assert fact(m,'created_target')==fact(m,'created_guard1')==fact(m,'created_guard2')==1
    assert m.books.BlocksDuty(m.books) and state(m,'eliminate')==2 and state(m,'retrieve')==1
    assert len(m.f.obholds)==3 and not m.f.obthreats[1] and m.f.manual==654 and m.f.wallet==0
    m.step(20);assert len(m.f.creates)==6 and m.f.obseedCount==1
    # Non-lethal defeat must not fulfil the assassination. Evidence can be
    # looted earlier, but it is never automatically granted on assignment.
    target=m.f.obRole('target');target.down=True;target.unconscious=True;m.step(1)
    assert fact(m,'stage')==1 and fact(m,'killed')==0 and not m.books.HasEvidence(m.books)
    m.f.obLoot();m.step(1);assert fact(m,'acquired')==1 and fact(m,'stage')==1
    assert m.f.obPlayerItems[m.f.obitem]==0 and m.f.entries[m.f.obpath].state==2 and m.f.obOriginalAdded==1
    killed(m);assert fact(m,'stage')==4 and state(m,'escape')==1 and state(m,'return')==2
    assert not m.books.BlocksDuty(m.books) and m.f.manual==654 and m.f.wallet==0
    m.f.wanted=True;m.step(1);assert fact(m,'stage')==3 and fact(m,'escape_used')==1 and state(m,'escape')==2
    m.f.wanted=False;m.step(1);assert fact(m,'stage')==4 and state(m,'escape')==3
    # Owned observers run vanilla once, preserve wanted consequences, release
    # only these three holds and give both elite guards a concrete aggressor.
    m=runtime();encounter(m);m.f.obPoliceResponse=True
    assert m.f.obHit(m.f.obRole('target'),m.f.player)
    assert m.f.obOriginalHits==1 and m.f.wanted and fact(m,'player_provoked')==1
    assert len(m.f.obcancels)==3 and len(m.f.obthreats)>=2
    assert m.f.obRole('guard1').obAttitudes[m.f.player.GetAttitudeAgent(m.f.player)]==2
    assert m.f.obRole('target').group=='neutral'
    killed(m);assert fact(m,'stage')==2 and state(m,'retrieve')==2
    m.f.obLoot();m.step(1);assert fact(m,'stage')==3
    m.f.wanted=False;m.step(1);assert fact(m,'stage')==4
    # The current stage and item receipt survive Lua/native transient resets;
    # killed or unloaded managed actors are never recreated.
    created=len(m.f.creates);seeded=m.f.obseedCount;restore(m)
    assert fact(m,'stage')==4 and fact(m,'killed')==fact(m,'acquired')==1
    assert len(m.f.creates)==created and m.f.obseedCount==seeded and state(m,'return')==2
    m.f.books.shutdown();m.step(1);assert fact(m,'stage')==4 and not m.f.deletes[1]
    # Explicit cancellation waits for physical detach even when deletion is
    # accepted; repeat tests cannot duplicate still-owned scene actors.
    m.f.deleteDeferred=True;assert m.f.books.clear(m.f.obStatus);m.step(2)
    assert fact(m,'stage')==0 and 'cleanup=true' in m.f.books.diagnostics()
    assert not m.f.books.begin(m.f.obStatus)
    m.f.qCompleteDeletes();m.f.deleteDeferred=False;m.step(2)
    assert 'cleanup=false' in m.f.books.diagnostics() and m.f.books.begin(m.f.obStatus)
    m.step(1);assert fact(m,'cycle')==2 and len(m.f.creates)==created+3 and m.f.obseedCount==seeded+1
    # Geometric checks run for every missing actor before the first creation.
    for flag,value in [('obNoGround',True),('obObstruction',True),('obSlope',.5),('noNav',True)]:
        m=runtime();briefing(m);setattr(m.f,flag,value);position(m);m.step(2)
        assert len(m.f.creates)==3 and not fact(m,'created_target'),(flag,m.f.books.diagnostics())
    # Missing/misdirected real record/readable data must reject assignment.
    for flag,value in [('obMissingRecord','Character.CorpoManArasaka'),('obMissingRecord','Items.NCPDPatrol_VossEvidence01'),('obBadReadAction',True),('obBadReadPath',True),('duty',True)]:
        m=runtime(retain=False);briefing_done=False
        m.start();m.arrive();m.talk();m.finish_conversation();m.step(1)
        setattr(m.f,flag,value)
        assert not m.f.books.begin(m.f.obStatus) and fact(m,'stage')==0 and len(m.f.creates)==3,flag
    # Paused/unready worlds do no entity or quest work.
    m=runtime();briefing(m);position(m);m.f.ready=False;m.step(3);assert len(m.f.creates)==3
    m.f.ready=True;m.f.menu=True;m.step(3);assert len(m.f.creates)==3
    m.f.menu=False;m.step(2);assert len(m.f.creates)==6
    # Main-player and exact-event guards; vanilla still receives every event.
    m.lua.execute("ItemObserver.OnItemAddedToInventory(F.player,{itemID='Items.money',currentQuantity=1});ItemObserver.OnItemAddedToInventory(F.player,{itemID=F.obitem,currentQuantity=0})")
    assert fact(m,'acquired')==0 and m.f.obOriginalAdded==2
    m.f.duty=True;killed(m);assert fact(m,'killed')==1 and fact(m,'stage')==1
    m.f.duty=False;m.step(1);assert fact(m,'stage')==2
    assert m.f.manual==654 and m.f.wallet==0
    report={'actual_native_lua_events_and_shared_marker_executed':True,'original_ten_turn_briefing_handoff_executed':True,
        'native_readable_auto_consumed_but_receipt_persists':True,'true_death_required':True,
        'native_hit_and_crime_handlers_preserved':True,'private_guards_defend_on_owned_hit':True,
        'conditional_escape_and_return_executed':True,'save_transient_reset_no_duplicate_actors':True,
        'accepted_delete_requires_detach':True,'geometric_checks_before_creation':True,
        'manual_waypoint_and_payments_unchanged':True,'native_record_and_readable_guards_executed':True,
        'roundtrip_archive':compiled,'actual_game_validation':False}
    p=argparse.ArgumentParser();p.add_argument('--report',type=Path);a=p.parse_args()
    if a.report:a.report.write_text(json.dumps(report,indent=2)+'\n')
    print('PASS: off-duty quest/loot/event progression, scoped guard response, geometric preflight, conditional escape, save reset and physical cleanup boundaries')
if __name__=='__main__':main()
