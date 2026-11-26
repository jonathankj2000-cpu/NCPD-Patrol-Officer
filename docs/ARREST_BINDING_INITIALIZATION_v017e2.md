Arrest animation initialization — v0.17e2 branch test

Observed in v0.17e

The user reports T-pose for every attempted suspect. The vanilla/private resource
tokens are loaded and the native play callback succeeds; workspot state is active
and not entering/exiting. The requested clip is named in metadata, but actual
clip telemetry is unavailable. These observations prove accepted playback, not
a rendered handcuff animation. The user confirms immediate T-pose together with
EUR$250 and NCPD ARREST REGISTERED. All attempted suspects are affected; their
individual physics flags were not captured in the supplied log.

The supplied external analysis was compared with repository history. The
v0.7f/v0.16b arrest.lua bytes match; v0.16c adds physics recovery and v0.16d changes
placement/sliding. The arrest archive and NCPDPatrolArrestPlayback.reds are
byte-identical across all six inspected releases through v0.17e. This limits
the history investigation; it does not establish the first failing game build.

The pinned NPCPuppet.swift source defines IsRagdollEnabled() as
m_isRagdolling || m_hasAnimatedRagdoll. It covers physical and animated ragdoll,
and is not merely the ragdoll component's general permission switch. A visually
animated downed NPC can therefore use the physics-recovery path. No ragdoll
predicate or recovery change is included in this initialization test.

Verified source weakness

The shipped private loop has no bundled finalAnimsets. In v0.17e, create() creates
its helper entity first; prepare() copies the native binding setups on a later
update after the helper has attached. Thus the workspot component may initialize
while the private resource still has zero bindings. Whether the engine caches
that empty state explains this user's T-pose remains an in-game hypothesis.

The module's configuredLoop flag also accepted every later resource without
checking its identity or binding count. A later resource copy or emptied private
binding list could pass setup with no animation bindings. Both weaknesses existed
before the recent marker/UI refactor; unchanged files do not establish causality.

Change

- Load and validate the vanilla metadata and private loop before creating the
  helper. Pending resource tokens wait without creating a helper or starting
  playback. An eight-second preparation deadline is retained.
- Copy only the existing binding/rig/prop fields to the private resource. Its
  authored infinite sequence, entry 2, status, tags and exit-free graph remain.
- Validate the actual resource/source identity and private binding count for
  each new preparation. Read back finalAnimsets before permitting creation.
- Transfer prepared tokens, entry and resource handles to the created unit.
  Attachment/component lookup and the clean native start still happen normally.
- Preserve the existing short ground retry after resources are ready, with
  resource latency included in the overall setup budget.

No native script, archive or animation topology changes. Native activation
acknowledgment, payment amount/ledger, ragdoll recovery, body pickup, health and
defeat state retain their existing owners. Observed clip remains unavailable;
this build does not claim that native success proves visible animation.

Verification

The executable fixture records private binding count at helper attachment. The
actual v0.17e arrest.lua fails that invariant; the changed implementation passes.
Later fresh resource instances and emptied binding lists are covered without a
module/world reset. Existing delayed/failed source/private loads, malformed
topology, ground/carry/recovery, cleanup, callback and exactly-once payment cases
remain. Engine initialization snapshots are a boundary model, not captured game
internals or a rendered T-pose test.

Game test

Install the entire v0.17e2 package and fully exit/restart the game to discard old
resource/workspot instances. It includes the H10 location exclusion from v0.17e1.
Use a living downed enemy that has not already been credited as arrested. Check
the lying handcuff animation and one EUR$250 receipt. The setup log should show
"private binding readback=N | prepared before helper creation=true" before the
new helper-attached line. If T-pose persists, that result will narrow the next
investigation to playback/animation binding after initialization; this patch is
not yet confirmed to resolve the rendered symptom in game.
