# Evidence receipt and Return — v0.20e

The supplied v0.20d log after pickup has killed=1, corpse confirmed=1, shard
after death=1, shard now=0, acquired=0 and acquisition event=false. Retrieve
remains active. The corpse item was present and removed, but no acquisition
receipt reached the mod. The log does not reveal whether its native notification
was absent, had zero quantity or was changed during another handler.

## Source and fix

Game source reference `81d996b584a693e8b0f0b20526a9fa38b5c83fe7`:

- `player/player.swift:2091` handles ItemAddedEvent. Its Gen_Readable branch
  removes the inventory instance and activates the readable journal entry.
- `items/actions/readAction.swift` separately activates that entry and queues
  NotifyShardRead. Readable ownership need not leave a backpack item.
- BaseItemAction.GetItemData and BaseScriptableAction.GetExecutor expose the
  incoming identity used by the scoped read observer.

The existing item wrapper now snapshots the exact incoming ID/quantity before
the original runs, and accepts zero-remaining-quantity ItemAddedEvent. Native
handling still runs once. A small ReadAction.CompleteAction wrapper similarly
snapshots the exact item/player and forwards only this evidence's completed read
by V, after invoking the original once. No global replacement or UI/input hook.

The existing quest tick also reconciles actual player possession or activation
of the exact private Shards entry. It checks this before corpse maintenance.
An empty body, target death, opening loot or a different journal entry is never
enough. The existing stage owner then selects Escape when wanted or Return
otherwise. No new item, actor, payment or scene is created.

## Persistence and history

New Begin records starting player quantity and exact readable ownership. Passive
reconciliation requires increased possession or a new journal activation; old
Shards history cannot complete a new test cycle. Actual item/read events still
work on repeated tests whose readable entry was already active.

The affected first-cycle v0.20d save has no baseline facts. With a confirmed dead
contractor and this unique readable already owned, its missing receipt can be
recovered. Older repeated cycles without a baseline conservatively capture
their present history. Existing acquired facts remain; new baseline/source facts
use the existing prefix and reset only on explicit new-cycle Begin.

Journal recovery records its real source and leaves acquisition event=false if
no direct notification was observed. Diagnostics never create the receipt.
Cancellation and world/menu guards remain in force. The confirmed death-loot
table, corpse repair, PSM exception/scope methods, native hit observer, first
Voss conversation and all ten archives are unchanged.

## Test the affected save

1. Install all 131 files, restart and load the same save without Clear, a new
   contractor or another Voss briefing.
2. Close in-game menus and wait briefly. If the taken evidence is in Shards,
   expect acquired=1 and source `legacy first-cycle shard journal receipt`.
3. No wanted: stage 4, Return objective and Voss marker. Wanted: stage 3/Escape;
   losing wanted selects Return. The final debrief remains future work.
4. Save/reload after recovery: receipt/objective persist with no new item/actor.
5. For a fresh test, try Take and direct Read. Check the receipt source, reject
   kill/open-loot/empty-body-only completion, and retain old-history guards.

The existing diagnostic now adds item callback/quantity, completed read, player
quantity, exact journal ownership, baseline and receipt source. These distinguish
missing native proof from a later journal acknowledgement problem.

## Verification limits

The regression executes the published v0.20d owner/events under independent
zero-quantity, post-native mutation and journal-without-item-event boundaries;
all reproduce its stalled Retrieve. This does not establish which native event
boundary caused the user's failure. Current tests execute actual revised hooks,
the pinned native ReadAction body, journal/Lua owner, first-cycle recovery,
foreign items/actors, empty-body rejection, old history, cancelled/paused worlds,
delayed journal writes, Escape/Return and transient loading.

The old artificial zero-quantity negative case now uses an invalid ID: remaining
quantity zero is explicitly supported for a genuine readable notification.
44 portable suites and source/API checks with BEF present/absent pass. These are
not actual game-cache compilation or native delivery/rendering proof; the
affected save still needs the in-game test above.
