"""Readable acquisition receipt, existing-save recovery and stage progression.

Native event delivery/field lifetime are explicit boundaries. The published old
controller, new actual hooks, native ReadAction body and journal owner execute.
"""
from pathlib import Path
import argparse,hashlib,json,subprocess,sys
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
sys.path.insert(0,str(HERE))
from check_off_books import runtime,encounter,killed,restore,fact,state,PREFIX
BASE='bbd2b88fdf617dedfcb2fbd0a4e7891ec792e62b'
EVENTS='r6/scripts/NCPDPatrol/NCPDPatrolOffBooksEvents.reds'
SYSTEM='r6/scripts/NCPDPatrol/NCPDPatrolOffBooksSystem.reds'

def old(path):return subprocess.check_output(['git','show',BASE+':'+path],cwd=ROOT,text=True)
def source(m):return m.books.EvidenceReceiptSource(m.books)
def body_empty(m):
    body=m.f.obRole('target');m.f.obInventory[body.GetEntityID(body).hash][m.f.obitem]=0
def pickup_event(m,quantity=0,mutate=False):
    body_empty(m);m.f.obPlayerItems[m.f.obitem]=1
    m.f.obIncomingQuantity=quantity
    if mutate:
        m.lua.execute("local native=OriginalOTBAdded;function OriginalOTBAdded(self,evt) local result=native(self,evt);evt.itemID='Items.money';evt.currentQuantity=0;return result end")
    m.lua.execute("assert(ItemObserver.OnItemAddedToInventory(F.player,{itemID=F.obitem,currentQuantity=F.obIncomingQuantity}))")

def baseline():
    m=runtime(native_source=old(SYSTEM),events_source=old(EVENTS))
    m.f.books=m.lua.execute(old(PREFIX+'off_the_books.lua'))
    m.lua.execute("F.books.configure({status=F.obStatus,worldReady=function() return F.ready end,onDuty=function() return F.duty end,voss=function() return F.qmod.actor() end});F.obConfigureRetention()")
    return m

def escaped_death(m):
    # Receipt-only cases continue after native pursuit has cooled off. The
    # mandatory three-star sequence is tested independently in check_wanted.
    killed(m);m.f.wanted=False;m.step(.25)

def main():
    # Actual v0.20d rejects a zero-remaining-quantity readable event even while
    # native handling creates its Shards entry. Journal activation without that
    # event has the same failure, matching the supplied stalled stage 2 log.
    for mode in ['zero quantity','journal-only','payload changes']:
        m=baseline();encounter(m);escaped_death(m);m.step(2)
        if mode=='journal-only':body_empty(m);m.f.entries[m.f.obpath].state=2
        else:pickup_event(m,0 if mode=='zero quantity' else 1,mode=='payload changes')
        m.step(12)
        assert fact(m,'stage')==2 and fact(m,'acquired')==0 and not m.books.HasEvidence(m.books),mode
        assert m.books.EvidenceQuantity(m.books)==0 and m.f.entries[m.f.obpath].state==2
    # Zero quantity and post-native payload mutation retain exact incoming item
    # identity. Original player handler still executes once and consumes the
    # readable; Return uses the existing journal/pin owner without a new spawn.
    for quantity,mutate in [(0,False),(1,True),(1,False)]:
        m=runtime();encounter(m);escaped_death(m);m.step(2);created=len(m.f.creates)
        pickup_event(m,quantity,mutate);m.step(1)
        assert fact(m,'acquired')==fact(m,'acquisition_event')==fact(m,'evidence_item_seen')==1
        assert source(m)=='native item-added event' and fact(m,'evidence_item_quantity')==quantity
        assert fact(m,'stage')==4 and state(m,'return')==2 and state(m,'retrieve')==3
        assert m.f.obOriginalAdded==1 and m.f.obPlayerItems[m.f.obitem]==0 and len(m.f.creates)==created
        assert m.f.obseedCount==1 and m.f.manual==654 and m.f.wallet==0
        restore(m);assert fact(m,'stage')==4 and fact(m,'acquired')==1 and len(m.f.creates)==created
    # Direct Read from loot executes the pinned game's ReadAction, activates
    # the exact onscreen entry, displays native shard UI and records a receipt
    # without relying on an item-added notification or a lingering backpack item.
    m=runtime();encounter(m);escaped_death(m);m.step(2);m.f.wanted=True;m.f.obRead();m.step(1)
    assert fact(m,'evidence_read_seen')==fact(m,'acquired')==1 and fact(m,'evidence_item_seen')==0
    assert source(m)=='native evidence Read action' and fact(m,'stage')==3 and state(m,'escape')==2
    assert m.f.obOriginalReads==1 and m.f.obReadSuper==1 and len(m.f.obReadUI)==1
    assert m.f.obOriginalAdded==0 and m.f.entries[m.f.obpath].state==2 and m.f.obseedCount==1
    m.f.wanted=False;m.step(1);assert fact(m,'stage')==4 and state(m,'return')==2
    # New native journal activation and actual player possession are independent
    # durable proofs if an external handler consumes/swallow the event route.
    for receipt in ['journal','inventory']:
        m=runtime();encounter(m);escaped_death(m);m.step(2);body_empty(m)
        if receipt=='journal':m.f.entries[m.f.obpath].state=2
        else:m.f.obPlayerItems[m.f.obitem]=1
        m.step(1)
        assert fact(m,'acquired')==1 and fact(m,'stage')==4 and fact(m,'acquisition_event')==0
        assert source(m)==('unique shard journal activation' if receipt=='journal' else 'player inventory readback')
    # User's existing first-cycle v0.20d save: item already taken, no event
    # receipt, native private journal entry owned and no new baseline facts.
    m=runtime();encounter(m);escaped_death(m);m.step(2);body_empty(m)
    for key in ['evidence_baseline','evidence_journal_before','evidence_player_before']:m.f.qfacts['ncpd_patrol_otb_'+key]=0
    m.f.entries[m.f.obpath].state=2;restore(m)
    assert fact(m,'acquired')==1 and fact(m,'stage')==4 and source(m)=='legacy first-cycle shard journal receipt'
    assert len(m.f.creates)==6 and m.f.obseedCount==1 and m.books.EvidenceQuantity(m.books)==0
    # Empty corpse alone, missing/wrong/inactive entries, cancellation and a
    # menu/unready world cannot fabricate an acquisition or a replacement shard.
    for mode in ['empty','inactive','foreign','missing','cancelled','menu','unready']:
        m=runtime();encounter(m);escaped_death(m);m.step(2);body_empty(m)
        if mode=='foreign':m.f.entries['onscreens/foreign/readable'].state=2
        if mode=='missing':m.f.entries[m.f.obpath]=None
        if mode in ['menu','unready','cancelled']:m.f.entries[m.f.obpath].state=2
        if mode=='cancelled':m.books.Cancel(m.books)
        if mode=='menu':m.f.menu=True
        if mode=='unready':m.f.ready=False
        m.step(3);assert fact(m,'acquired')==0 and m.f.obseedCount==1,mode
    # Old journal history or a pre-existing physical copy at new Begin is not
    # evidence of this cycle's pickup. A real Read action still works on repeat.
    for previous in ['journal','inventory']:
        m=runtime()
        if previous=='journal':m.f.entries[m.f.obpath].state=2
        else:m.f.obPlayerItems[m.f.obitem]=1
        encounter(m);escaped_death(m);m.step(2)
        assert fact(m,'acquired')==0 and fact(m,'stage')==2,previous
        m.f.obRead();m.step(1);assert fact(m,'acquired')==1 and fact(m,'stage')==4
    m=runtime();encounter(m);escaped_death(m);m.step(2);body_empty(m)
    m.f.qfacts.ncpd_patrol_otb_cycle=2;m.f.qfacts.ncpd_patrol_otb_evidence_baseline=0
    m.f.entries[m.f.obpath].state=2;restore(m)
    assert fact(m,'acquired')==0 and fact(m,'stage')==2
    m.f.obRead();m.step(1);assert fact(m,'acquired')==1 and fact(m,'stage')==4
    # Foreign-item and non-player events/read actions leave this quest alone,
    # while native handlers still run once for their original behavior.
    m=runtime();encounter(m);escaped_death(m);m.step(2)
    m.f.obRead('Items.other_readable');m.step(1)
    assert fact(m,'acquired')==0 and m.f.obOriginalReads==1
    m.f.obRead(m.f.obitem,m.f.obRole('guard1'))
    assert fact(m,'acquired')==0 and m.f.obOriginalReads==2
    # Previous native read created the journal entry, so suppress passive polling
    # here to isolate the direct main-player callback guard.
    m.f.entries[m.f.obpath].state=1
    m.lua.execute("ItemObserver.OnItemAddedToInventory(F.obRole('guard1'),{itemID=F.obitem,currentQuantity=1})")
    assert fact(m,'acquired')==0
    # Delayed/rejected quest journal writes do not undo a durable receipt. The
    # existing owner retries, then switches to Return without respawn/replay.
    m=runtime();encounter(m);escaped_death(m);m.step(2)
    m.f.obJournalDelay=2;pickup_event(m);m.step(1)
    assert fact(m,'acquired')==1 and fact(m,'stage')==4 and state(m,'return')!=2
    m.step(4);assert state(m,'return')==2 and len(m.f.creates)==6
    # All in-game-confirmed corpse/weapon helpers and the loot table are frozen.
    for path in ['r6/tweaks/NCPDPatrol_OffTheBooks.yaml','r6/scripts/NCPDPatrol/NCPDPatrolOffBooksCombat.reds','r6/scripts/NCPDPatrol/NCPDPatrolOffBooksLoot.reds']:
        assert (ROOT/path).read_text()==old(path),path
    current=(ROOT/SYSTEM).read_text();previous=old(SYSTEM)
    def slice_method(text,start,end):return text[text.index(start):text.index(end,text.index(start))]
    assert slice_method(current,'    // A decision exception','    public func Version()')==slice_method(previous,'    // A decision exception','    public func Version()')
    assert slice_method(current,'    private func MaintainEvidenceLoot(','    public func HasEvidence()')==slice_method(previous,'    private func MaintainEvidenceLoot(','    public func HasEvidence()')
    assert (ROOT/EVENTS).read_text().split('@wrapMethod(PlayerPuppet)')[0]==old(EVENTS).split('@wrapMethod(PlayerPuppet)')[0]
    report={'exact_v020d_readable_zero_quantity_and_journal_only_stall_reproduced':True,
        'incoming_item_identity_saved_before_original':True,'zero_quantity_real_item_event_accepted':True,
        'actual_pinned_native_read_action_and_scoped_wrapper_executed':True,
        'unique_readable_journal_and_player_possession_readback':True,'first_cycle_existing_save_recovery':True,
        'old_history_and_repeated_cycle_baselines_do_not_auto_complete':True,
        'empty_corpse_never_sufficient':True,'native_handlers_once_and_foreign_main_player_guards':True,
        'conditional_escape_return_and_delayed_journal_retry':True,'receipt_survives_transient_reload':True,
        'no_new_actor_or_item_or_reward':True,'confirmed_weapon_and_death_loot_implementation_unchanged':True,
        'actual_native_event_delivery_verified':False,'actual_game_validation':False}
    p=argparse.ArgumentParser();p.add_argument('--report',type=Path);args=p.parse_args()
    if args.report:args.report.write_text(json.dumps(report,indent=2)+'\n')
    print('PASS: exact v0.20d acquisition stall, zero-quantity/snapshot events, actual native Read action, durable shard receipts, existing-save recovery, history guards and Escape/Return')
if __name__=='__main__':main()
