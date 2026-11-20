local root='quests/street_stories/ncpd_patrol_marker_reference'
local prefix='ncpd_patrol_marker_reference_r4d_'
local function tick(n) for _=1,n do F:StepGraph();Native:Tick(.25) end end
local function begin() assert(Native:Begin());F:StepGraph();Native:Tick(.25) end
local function stop() Native:Stop('done');tick(2) end
local function ownState() return F.entries[root].state end
-- A journal alone is insufficient: require a real loaded phase acknowledgement.
F:Reset(false);assert(not Native:IsReady() and not Native:Begin() and #F.requests==0)
F:StepGraph();assert(Native:IsReady() and Native:GetGraphStage()==0 and ownState()==1)
-- Native phase Out/stage acknowledgement is NOT proof of a rendered quest pin.
F:Reset();begin();assert(Native:GetGraphStage()==1 and not Native:IsConfirmed())
tick(24);assert(#F.requests==1 and F.requests[1]=='Active' and not Native:IsConfirmed())
assert(Native.m_reason:find('NOT CONFIRMED',1,true))
assert(not Native:Begin() and #F.requests==1);stop()
assert(F.manual==700 and F.tracked==F.previous and ownState()==1)
assert(F.requests[2]=='Inactive' and not Native:HasPendingCleanup())
-- Hash, position, objective link, type and unique pin remain independent gates.
F:Reset();begin();F:AddPin(111);tick(1);assert(not Native:IsConfirmed())
F.pins={n=0};F:AddPin(nil,Vector4.new(0,0,0,1));tick(1);assert(not Native:IsConfirmed())
F.pins[0].pos=F.pos;F.linked=false;tick(1);assert(not Native:IsConfirmed())
F.linked=true;tick(1);assert(Native:IsConfirmed())
F:AddPin();tick(1);assert(not Native:IsConfirmed());stop();assert(F.pins.n==0)
F:Reset();begin();local manual=F:AddPin();manual.kind='StaticMappin';tick(1)
assert(not Native:IsConfirmed());stop();assert(F.pins.n==1 and #F.removed==0)
-- Stop must wait for phase acknowledgement, then confirm current-world cleanup.
F:Reset();F.materialize=true;begin();local other=F:AddPin(222)
F.graphStalled=true;Native:Stop('pending');tick(12)
assert(Native:HasPendingCleanup() and #F.removed==0 and not Native:Begin())
F.graphStalled=false;F.failDelete=true;tick(2);assert(Native:HasPendingCleanup())
F.failDelete=false;tick(2);assert(not Native:HasPendingCleanup() and F.pins.n==1 and F.pins[0]==other)
-- A player's newer story selection or waypoint takes precedence over snapshots.
F:Reset();F.materialize=true;begin();assert(Native:IsConfirmed())
local newStory={state=2,path='new-story'};F.tracked=newStory;F.manual=800;tick(1)
assert(Native.m_afterCreate.value==700);stop();assert(F.tracked==newStory and F.manual==800)
F:Reset();F.changeManual=true;F.materialize=true;begin()
assert(Native.m_reason:find('manual ID changed',1,true));stop();assert(F.manual==701)
-- Menu inspection pauses lifetime. Duty/combat/wanted terminate and clean up.
F:Reset();begin();local elapsed=Native.m_elapsed;F.menu=true;tick(50)
assert(Native:HasRequest() and Native.m_elapsed==elapsed)
F.menu=false;F.duty=true;tick(3);assert(not Native:HasRequest() and not Native:HasPendingCleanup())
F:Reset();begin();F.combat=true;tick(3);assert(not Native:HasRequest())
F:Reset();begin();F.wanted=true;tick(3);assert(not Native:HasRequest())
F:Reset();begin();tick(2402);assert(not Native:HasRequest() and ownState()==1)
-- The actual graph loops: start/stop/start needs no game restart or new journal.
F:Reset();F.materialize=true;begin();stop();begin();assert(Native:IsConfirmed());stop()
assert(#F.requests==4 and F.facts[prefix..'request']==0 and F.facts[prefix..'stage']==0)
-- Save restore forgets old tracking/IDs, signals off, then closes the saved phase.
F:Reset();F.materialize=true;begin();Native.m_lastMarker={value=999999}
Native:OnRestored(0,0);tick(3)
assert(not Native:HasRequest() and ownState()==1 and F.pins.n==0 and F.manual==700)
for _,id in ipairs(F.removed) do assert(id~=999999) end
-- Actual Lua coordinator: no dynamic entity API is even supplied in Game.
local Probe=require('quest_marker_probe')
F:Reset();Probe.reset();Probe.update(.25,false);Probe.finish()
assert(#F.requests==0 and ownState()==1)
F.duty=true;assert(not Probe.start());F.duty=false
assert(Probe.start() and not Probe.start());F:StepGraph();Probe.update(.25,false)
assert(Native:GetGraphStage()==1 and #F.requests==1)
F.graphStalled=true;assert(not Probe.finish());assert(not Probe.start())
F.graphStalled=false;F:StepGraph();Probe.update(.25,false);assert(Probe.start())
F:StepGraph();Probe.update(.25,false);Probe.update(.25,true)
F:StepGraph();Probe.update(.25,false);assert(not Native:HasPendingCleanup())
-- No old-world native handles are unregistered by a Lua reset.
F:Reset();Probe.reset();assert(Probe.start());local requests=#F.requests;Probe.reset()
assert(#F.requests==requests)
F.noNative=true;local notices={};Probe.reset()
Probe.update(.25,false,function(s) notices[#notices+1]=s end);assert(#notices==0)
assert(not Probe.start(function(s) notices[#notices+1]=s end) and #notices==1)

-- MIT visual helper: a separate renderer cannot satisfy journal proof.
F:Reset();Probe.reset();assert(Probe.startVisual());Probe.update(.25,false)
assert(Native.m_visualConfirmed and not Native:IsConfirmed())
assert(Native:GetGraphStage()==0 and ownState()==1 and F.tracked==F.previous and F.manual==700)
assert(F.lastData.active and F.lastData.visibleThroughWalls)
assert(F.lastData.mappinType=='Mappins.QuestStaticMappinDefinition')
assert(Probe.diagnostics():find('VISUAL CONTROL',1,true))
local ownID=Native.m_visualID
NCPDPatrolReferenceMappins:Move({},ownID,Vector4.new(0,0,0,1));Probe.update(.25,false)
assert(not Native.m_visualConfirmed and not Native:IsConfirmed())
local foreign=F:AddPin(222);foreign.kind='StaticMappin';foreign.data={kind='DispatchData'}
NCPDPatrolReferenceMappins:Move({},foreign:GetNewMappinID(),Vector4.new(4,4,4,1))
assert(foreign.pos==F.pos)
NCPDPatrolReferenceMappins:Hide({},foreign:GetNewMappinID());assert(F.pins.n==2)
F.failDelete=true;assert(not Probe.finish() and not Probe.startVisual())
F.failDelete=false;Probe.update(.25,false)
assert(not Native:HasPendingCleanup() and F.pins.n==1 and F.pins[0]==foreign)
-- A reused cached ID belonging to another class must never be removed.
F:Reset();assert(Native:BeginVisual());local originalID=Native.m_visualID
F.pins[0].data={kind='DispatchData'};Native:Stop('ID reused')
assert(F.pins.n==1 and F.pins[0].id==originalID.value and #F.removed==0)
-- Missing renderer creation is never reported as visual/native success.
F:Reset();F.failCreate=true;assert(Native:BeginVisual());tick(1)
assert(not Native.m_visualConfirmed and not Native:IsConfirmed());stop()
-- The independent renderer can run when the reference quest phase is missing.
F:Reset(false);assert(Native:BeginVisual());tick(1)
assert(Native.m_visualConfirmed and Native:GetGraphStage()==0);stop()
F:Reset();assert(Native:BeginVisual());local savedID=Native.m_visualID
Native:OnRestored(0,0);tick(2)
assert(not Native:HasRequest() and F.pins.n==0)
-- Migration waits for the r4c phase to become inactive; fallback is hash-scoped.
F:Reset();local legacy='quests/minor_quest/ncpd_patrol_marker_probe'
F.entries[legacy].state=2;F.facts.ncpd_patrol_marker_probe_r4c_stage=1;F.legacyStalled=true
local legacyPin=F:AddPin(8888);foreign=F:AddPin(222)
Native:OnRestored(0,0);tick(2)
assert(not Native:Begin() and not Native:BeginVisual() and #F.removed==0)
assert(F.facts.ncpd_patrol_marker_probe_r4c_request==0)
F.legacyStalled=false;F.failDelete=true;tick(2)
assert(Native.m_legacyPending and not Native:Begin())
F.failDelete=false;tick(2)
assert(not Native.m_legacyPending and F.pins.n==1 and F.pins[0]==foreign)
assert(Native:Begin());F:StepGraph();Native:Tick(.25);stop()
-- Root tracking selected by the reference graph also restores a prior story.
F:Reset();begin();F.tracked=F.entries[root];stop();assert(F.tracked==F.previous)

-- Runtime relocation is unproven by default: a void API call is not success.
F:Reset();assert(not Native:RelocateNearPlayer() and #F.nativeMoves==0)
F.materialize=true;begin();assert(Native:RelocateNearPlayer());tick(24)
assert(#F.nativeMoves==1 and not Native:IsConfirmed() and not Native:IsRelocationConfirmed())
assert(Native.m_runtimePosition==F.pos and Native.m_questPosition==F.pos);stop()
-- A moved renderer alone cannot prove the quest-log location changed.
F:Reset();F.materialize=true;F.allowNativeMove=true;begin()
assert(Native:RelocateNearPlayer());tick(24)
assert(Native:IsConfirmed() and not Native:IsRelocationConfirmed())
assert(not Native.m_questPositionOK and Native.m_relocationStable==0 and #F.nativeMoves==1);stop()
-- Both positions, same live pin, objective link and 3 observed seconds required.
F:Reset();F.materialize=true;F.allowNativeMove=true;F.moveQuestPosition=true;begin()
local pinID=Native.m_lastMarker.value
assert(Native:RelocateNearPlayer());tick(11)
assert(Native:IsConfirmed() and not Native:IsRelocationConfirmed())
tick(1);assert(Native:IsRelocationConfirmed() and Native.m_relocationStable==3)
assert(Native.m_lastMarker.value==pinID and #F.nativeMoves==1 and F.manual==700)
assert(F.nativeMoves[1].spot.X==150 and F.nativeMoves[1].spot.Y==0)
assert(F.nativeMoves[1].spot.Z==F.playerPosition.Z and F.tracked==F.entries[root..'/main/inspect'])
-- No ongoing position forcing: a snap-back is detected and clears proof.
F.pins[0].pos=F.pos;tick(1)
assert(not Native:IsRelocationConfirmed() and Native.m_relocationStable==0 and #F.nativeMoves==1)
F.pins[0].pos=Native.m_target;F.questPositionKnown=false;tick(16)
assert(not Native:IsRelocationConfirmed() and not Native.m_questPositionKnown)
F.questPositionKnown=true;tick(12);assert(Native:IsRelocationConfirmed())
-- Menu inspection pauses observed stability; a later move restarts the window.
F.playerPosition=Vector4.new(300,100,4,1);assert(Native:RelocateNearPlayer());tick(4)
local stable=Native.m_relocationStable;F.menu=true;tick(24)
assert(Native.m_relocationStable==stable and not Native:IsRelocationConfirmed())
assert(not Native:RelocateNearPlayer() and #F.nativeMoves==2)
F.menu=false;tick(8);assert(Native:IsRelocationConfirmed())
-- Query and objective linkage are independent of runtime position.
F.linked=false;tick(1);assert(not Native:IsRelocationConfirmed())
F.linked=true;tick(12);assert(Native:IsRelocationConfirmed())
F.questPosition=F.pos;tick(1);assert(not Native:IsRelocationConfirmed())
F.questPosition=Native.m_target;tick(12);assert(Native:IsRelocationConfirmed())
-- User waypoint/story changes between operations are respected.
local newerStory={state=2,path='newer-after-move'};F.tracked=newerStory;F.manual=800
F.playerPosition=Vector4.new(600,100,4,1);assert(Native:RelocateNearPlayer());tick(12)
assert(Native:IsRelocationConfirmed() and Native.m_beforeMove.value==800 and F.manual==800)
assert(#F.nativeMoves==3);stop();assert(F.tracked==newerStory and not Native:IsRelocationConfirmed())
-- Cached IDs, duplicates and foreign types cannot redirect position writes.
F:Reset();F.materialize=true;F.allowNativeMove=true;begin()
Native.m_lastMarker={value=99999};assert(Native:RelocateNearPlayer() and F.nativeMoves[1].id~=99999);stop()
F:Reset();F.materialize=true;begin();F:AddPin()
assert(not Native:RelocateNearPlayer() and #F.nativeMoves==0);stop()
F:Reset();F.materialize=true;begin();F.pins[0].kind='StaticMappin'
assert(not Native:RelocateNearPlayer() and #F.nativeMoves==0);stop()
-- Same hash at a new ID after relocation is insufficient for stability proof.
F:Reset();F.materialize=true;F.allowNativeMove=true;F.moveQuestPosition=true;begin()
assert(Native:RelocateNearPlayer());F.pins[0].id=10000;tick(16)
assert(Native:IsConfirmed() and not Native:IsRelocationConfirmed());stop()
F:Reset();F.materialize=true;F.allowNativeMove=true;F.moveQuestPosition=true;F.moveChangesManual=true;begin()
assert(Native:RelocateNearPlayer());tick(16)
assert(Native:IsConfirmed() and not Native:IsRelocationConfirmed() and F.manual==987);stop()
-- Save restore forgets move requests/IDs; a new activation uses static Coyote.
F:Reset();F.materialize=true;F.allowNativeMove=true;F.moveQuestPosition=true;begin()
assert(Native:RelocateNearPlayer());tick(12);Native:OnRestored(0,0);tick(3)
assert(not Native:IsRelocationConfirmed() and not Native.m_relocationRequested and F.pins.n==0)
F.questPosition=F.pos;begin();assert(Native:IsConfirmed() and Native.m_target.X==PhasePosition.X);stop()
-- Actual CET controller rejects visual/idle moves and routes a native move.
F:Reset();Probe.reset();assert(not Probe.relocate())
assert(Probe.startVisual());assert(not Probe.relocate());Probe.finish()
F.materialize=true;F.allowNativeMove=true;F.moveQuestPosition=true
assert(Probe.start());F:StepGraph();Probe.update(.25,false)
assert(Probe.relocate());tick(12);assert(Native:IsRelocationConfirmed());Probe.finish();tick(2)

-- A non-null player during reload is insufficient: do not write quest facts,
-- hide legacy entries or remove markers until the player has reattached.
F:Reset(false);Native:OnRestored(0,0);F.attached=false
local previousWrites,previousFacts,previousDeletes=#F.writes,#F.factWrites,#F.removed
for _=1,20 do Native:Tick(.25) end
assert(#F.writes==previousWrites and #F.factWrites==previousFacts and #F.removed==previousDeletes)
assert(Native.m_restorePending)
F.attached=true;Native:Tick(.25);assert(not Native.m_restorePending)
