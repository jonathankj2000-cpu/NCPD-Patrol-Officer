local function tick(n) for i=1,n do Native:Tick(.25) end end
local function begin(mode) assert(Native:Begin(F:Anchor(),F.pos,mode or 0)) end
local function ownState() return F.entries['quests/minor_quest/ncpd_patrol_marker_probe'].state end
-- A successful ExecuteNode return is NOT proof. No native pin is the default.
F:Reset();begin();assert(not Native:IsConfirmed());tick(24)
assert(#F.requests==1 and F.requests[1]=='default' and not Native:IsConfirmed())
assert(Native.m_reason:find('NOT CONFIRMED',1,true))
assert(not Native:Begin(F:Anchor(),F.pos,0) and #F.requests==1)
Native:Stop('done');assert(F.manual==700 and F.tracked==F.previous and ownState()==1)
-- Independent conditions: hash, position, objective link and exactly one pin.
F:Reset();begin();F:AddPin(111);tick(4);assert(not Native:IsConfirmed())
F.pins={n=0};F:AddPin(nil,Vector4.new(250,0,0,1));tick(4);assert(not Native:IsConfirmed())
F.pins[0].pos=F.pos;F.linked=false;tick(4);assert(not Native:IsConfirmed())
F.linked=true;tick(4);assert(Native:IsConfirmed())
F:AddPin();tick(4);assert(not Native:IsConfirmed())
Native:Stop('done');assert(F.pins.n==0 and F.manual==700)
-- Deletion only touches matching quest hashes; retry retains pending state.
F:Reset();F.materialize=true;begin(1);local other=F:AddPin(222)
F.failDelete=true;Native:Stop('pending');assert(Native:HasPendingCleanup())
assert(not Native:Begin(F:Anchor(),F.pos,0));F.failDelete=false;tick(4)
assert(not Native:HasPendingCleanup() and F.pins.n==1 and F.pins[0]==other)
F:Reset();begin();local manual=F:AddPin();manual.kind='StaticMappin'
tick(4);assert(not Native:IsConfirmed());Native:Stop('done')
assert(F.pins.n==1 and #F.removed==0) -- matching hash alone cannot claim another type
-- A player's new story selection/waypoint takes precedence over old snapshots.
F:Reset();F.materialize=true;begin(2);assert(Native:IsConfirmed() and F.requests[1]=='In')
local newStory={path='story-new',state=2};F.tracked=newStory;F.manual=800
Native:Stop('done');assert(F.tracked==newStory and F.manual==800)
F:Reset();F.changeManual=true;F.materialize=true;begin()
assert(Native.m_reason:find('manual ID changed',1,true));assert(F.manual==701)
Native:Stop('done');assert(F.manual==701) -- do not "restore" over user intent
-- Map inspection pauses rather than cancels. Normal duty/combat ends the test.
F:Reset();begin();F.menu=true;tick(50);assert(Native:HasRequest() and Native.m_elapsed==0)
F.menu=false;F.duty=true;tick(1);assert(not Native:HasRequest() and ownState()==1)
F:Reset();begin();F.combat=true;tick(1);assert(not Native:HasRequest())
F:Reset();begin();F.wanted=true;tick(1);assert(not Native:HasRequest())
F:Reset();begin();tick(2400);assert(not Native:HasRequest() and ownState()==1)
-- Restore forgets stale handles, then closes only our saved journal entry.
F:Reset();F.materialize=true;begin();Native:OnRestored(0,0);tick(1)
assert(not Native:HasRequest() and ownState()==1 and F.pins.n==0 and F.manual==700)
F:Reset();F.ready=false;assert(not Native:Begin(F:Anchor(),F.pos,0) and #F.requests==0)
-- Real Lua controller: no implicit spawn/start/stop during unused updates.
local Probe=require('quest_marker_probe')
F:Reset();Probe.reset();F.created=0;F.deleted=0;Probe.update(.25,false)
assert(F.created==0 and #F.requests==0);Probe.finish();assert(#F.requests==0)
F.duty=true;assert(not Probe.start());assert(F.created==0);F.duty=false
assert(Probe.start());assert(F.created==1 and #F.requests==0)
local start=F.spec.position;assert(start.x==150 and start.y==0)
Probe.update(.25,false);assert(#F.requests==1 and Native:HasRequest())
assert(not Probe.start() and not Probe.cycleMode())
F.menu=true;Probe.update(.25,false);assert(Native:HasRequest() and F.spec.position==start)
F.menu=false;F.deferAnchor=true;assert(not Probe.finish());assert(F.managed)
assert(not Probe.start());F.deferAnchor=false;for i=1,4 do Probe.update(.25,false) end
assert(not F.managed and Probe.start());Probe.update(.25,false);Probe.finish()
assert(Probe.cycleMode() and Probe.mode()=='Enable');assert(Probe.start())
Probe.update(.25,false);assert(F.requests[#F.requests]=='Enable');Probe.update(.25,true)
assert(not Native:HasRequest() and not F.managed)
-- Old-world reset never deletes stale entity IDs or executes a quest node.
F:Reset();Probe.reset();assert(Probe.start());local deleted=F.deleted;Probe.reset()
assert(F.deleted==deleted and #F.requests==0)
-- Missing module is reported on explicit use; untouched normal frames are quiet.
F.noNative=true;local notices={};Probe.reset();Probe.update(.25,false,function(s) notices[#notices+1]=s end)
assert(#notices==0);assert(not Probe.start(function(s) notices[#notices+1]=s end));assert(#notices==1)
