local root='quests/minor_quest/ncpd_patrol_marker_probe'
local prefix='ncpd_patrol_marker_probe_r4c_'
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
