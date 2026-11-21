"""Completed Officer Down reuse through the actual facade/native cleanup owner."""
from pathlib import Path
from tempfile import TemporaryDirectory
import argparse,json,os,subprocess,sys
from lupa.luajit21 import LuaError
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
sys.path.insert(0,str(HERE));from check_catalog import runtime,events
BASE='aa062a50866a26385e8441a3d818a919d6b979f5'
MOD='bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrol/officer_down.lua'
SETUP='''local c,f,s=CF,F,SurveyFixture
local d=c.dispatch()
local function observe() d.update(0,f.duty,c.status,function() return f.patrol end) end
local function candidate(preferred)
 local rows=require('officer_down_sites').sites
 local function usable(site)
  local p=f.playerPoint;local dist=math.sqrt((site.x-p.x)^2+(site.y-p.y)^2+(site.z-p.z)^2)
  return dist>=500 and dist<=5000
 end
 for _,site in ipairs(rows) do if site.index==preferred and usable(site) then c.only(site.index);return site.index end end
 for _,site in ipairs(rows) do if usable(site) then c.only(site.index);return site.index end end
 error('Repeat fixture has no eligible second site')
end
local function finishCurrent(expected)
 local before=#f.creates;f.playerPoint=c.point(-100);c.step(9)
 assert(#f.creates==before+10 and OfficerNative:GetCreatedCount()==10)
 f.playerPoint=c.point(-40);c.step(.25);assert(OfficerNative:GetStage()==2)
 c.neutralize();f.playerPoint=OfficerNative.m_injured.pos
 assert(c.scene.revive(c.status));c.step(5.5);observe()
 assert(f.wallet==2000*expected and IncidentNative:GetCompletedCount()==expected and d.completed()==expected)
 assert(c.scene.lifecycle().phase=='aftermath' and not d.isActive())
 assert(f.manual==654 and f.managed[999])
end
c.complete(1);observe()
assert(f.wallet==2000 and d.completed()==1 and c.scene.lifecycle().phase=='aftermath')
'''
def case(body,inspect=None,legacy=False,residual_legacy=False):
    previous=Path.cwd()
    with TemporaryDirectory(prefix='ncpd-officer-repeat-') as temp:
        try:
            os.chdir(temp);lua=runtime()
            if residual_legacy:
                from check_officer_down import code
                native=Path(temp)/'v018e1-native.reds'
                native.write_text(subprocess.check_output(['git','show','1ba23f29e6f44322935e9a9510890f08414659e9:r6/scripts/NCPDPatrol/NCPDPatrolOfficerDownSystem.reds'],cwd=ROOT,text=True))
                lua.globals().OfficerNative=lua.execute(code(native))
                lua.execute('function OfficerNative:GetGameInstance() return {} end;OfficerNative:OnAttach()')
                lua.globals().PreviousOfficerSource=subprocess.check_output(['git','show',f'1ba23f29e6f44322935e9a9510890f08414659e9:{MOD}'],cwd=ROOT,text=True)
                lua.execute("local old=assert(loadstring(PreviousOfficerSource))();package.loaded.officer_down=old;CF.use(old)")
            if legacy:
                lua.globals().PreviousOfficerSource=subprocess.check_output(['git','show',f'{BASE}:{MOD}'],cwd=ROOT,text=True)
                lua.execute("local old=assert(loadstring(PreviousOfficerSource))();package.loaded.officer_down=old;CF.use(old)")
            lua.execute(SETUP+body)
            if inspect:inspect(lua)
        finally:os.chdir(previous)

def main():
    # One managed row and no attached cached actors: an NPC record or an
    # already-deleted vehicle with no positive receipt could never retire in e1.
    detached='''local target
for _,a in pairs(f.objects) do if a.record==TARGET_RECORD then target=a;break end end
assert(target)
local remove=f.entities.DeleteEntity;local first=true
f.entities.DeleteEntity=function(self,id)
 if id.hash==target.id.hash then
  f.deletes[#f.deletes+1]=id.hash;target.attached=false;f.objects[id.hash]=nil
  if first then first=false;return ACCEPT_DELETE end
  return false
 end
 return remove(self,id)
end
c.step(96)
assert(not c.scene.hasCleanup(),'Detached owned actor still blocks repeat | '..c.scene.diagnostics())
assert(OfficerNative:GetCreatedCount()==0 and OfficerNative:GetRetiredActorCount()==1)
assert(f.managed[target.id.hash] and f.wallet==2000 and d.completed()==1)
candidate();assert(d.requestOfficerDownNearby(f.patrol,c.status));finishCurrent(2)
f.entities.DeleteEntity=remove;c.clear()
f.managed[target.id.hash]=nil;c.step(2)
assert(OfficerNative:GetRetiredActorCount()==0 and f.wallet==4000 and f.managed[999])'''
    def inspect_detached(lua):
        retired=[r for r in events() if r['kind']=='detached_actor_id_retired']
        assert len(retired)==1
    for record,accepted in [('Character.NCPDPatrol_OD_Ganger',True),('Character.NCPDPatrol_OD_Ganger',False),('Vehicle.NCPDPatrol_OD_Police',False)]:
        body=detached.replace('TARGET_RECORD',json.dumps(record)).replace('ACCEPT_DELETE','true' if accepted else 'false')
        case(body,inspect_detached)
        try:case(body,residual_legacy=True)
        except LuaError as error:
            assert 'Detached owned actor still blocks repeat' in str(error),str(error)
            assert 'owned actors=1' in str(error) and 'attached handles=0' in str(error),str(error)
        else:raise AssertionError('v0.18e1 one-ID/zero-attached stall was not detected')
    # An old detached wrapper is not proof: fresh lookup or pending spawning
    # must still hold the assignment until the actual world becomes clear.
    for guard in ['fresh','spawning']:
        prefix=detached[:detached.index('c.step(96)')].replace('TARGET_RECORD',json.dumps('Character.NCPDPatrol_OD_Ganger')).replace('ACCEPT_DELETE','false')
        if guard=='fresh':
            prefix=prefix.replace('local remove=f.entities.DeleteEntity;local first=true',"local fresh=f:Actor(target.record,target.id,target.pos);local remove=f.entities.DeleteEntity;local first=true")
            prefix=prefix.replace('f.objects[id.hash]=nil','f.objects[id.hash]=fresh')
            release='fresh=nil'
            diagnostic='lookup attached/spawning/errors=1/0/0'
        else:
            prefix+='\nf.spawningIDs={[target.id.hash]=true}\n'
            release='f.spawningIDs={}'
            diagnostic='lookup attached/spawning/errors=0/1/0'
        case(prefix+f'''c.step(110)
assert(c.scene.hasCleanup() and OfficerNative:GetCreatedCount()==10 and OfficerNative:GetRetiredActorCount()==0)
assert(c.scene.diagnostics():find('{diagnostic}',1,true))
candidate();assert(not d.requestOfficerDownNearby(f.patrol,c.status))
{release};c.step(2)
assert(not c.scene.hasCleanup() and OfficerNative:GetRetiredActorCount()==1)
assert(d.requestOfficerDownNearby(f.patrol,c.status));f.entities.DeleteEntity=remove;c.clear()''')
    repeat='''local second=candidate()
assert(d.requestOfficerDownNearby(f.patrol,c.status),'Manual retry stayed blocked after a completed scene')
assert(OfficerNative:GetStage()==1 and OfficerNative:GetCatalogIndex()==second and OfficerNative:GetCreatedCount()==0)
assert(f.wallet==2000 and #f.creates==10)
finishCurrent(2)
assert(candidate(1)==1)
assert(d.requestOfficerDownNearby(f.patrol,c.status))
assert(OfficerNative:GetCatalogIndex()==1);finishCurrent(3)
local closed=0
for i=0,f.pins.n-1 do if f.pins[i].catalog and f.pins[i].active then closed=closed+1 end end
assert(closed==0 and f.wallet==6000 and d.completed()==3)
c.clear()'''
    def inspect_repeat(lua):
        rows=events()
        assert sum(r['kind']=='assigned' for r in rows)==3
        assert sum(r['kind']=='completed' for r in rows)==3
        assert sum(r['kind']=='cleanup_confirmed' for r in rows)==3
    case(repeat,inspect_repeat)
    try:case(repeat,legacy=True)
    except LuaError as error:assert 'Manual retry stayed blocked after a completed scene' in str(error),str(error)
    else:raise AssertionError('Previous silent rejection was not detected')
    stalled_cars='''local remove=f.entities.DeleteEntity;local requested={}
f.entities.DeleteEntity=function(self,id)
 local actor=f.objects[id.hash]
 if actor and (actor.record=='Vehicle.NCPDPatrol_OD_Police' or actor.record=='Vehicle.NCPDPatrol_OD_GangCar') then
  f.deletes[#f.deletes+1]=id.hash
  if requested[id.hash] then return false end
  requested[id.hash]=true;return true
 end
 return remove(self,id)
end
f.disposeCompletes=true
-- Reproduce the reported terminal quest, three managed rows and ten handles
-- after the ordinary retention interval. Codeware accepted each car once.
c.step(92)
assert(c.scene.lifecycle().phase=='aftermath' and OfficerNative:GetStage()==3)
assert(c.scene.diagnostics():find('owned actors=3',1,true) and c.scene.diagnostics():find('retained handles=10',1,true))
c.step(12)
assert(not c.scene.hasCleanup(),'Accepted vehicle deletion remained stuck')
assert(OfficerNative:GetCreatedCount()==0 and #f.disposals==3 and f.wallet==2000 and d.completed()==1)
for _,row in ipairs(f.disposals) do assert(not row.actor.attached and not f.managed[row.id]) end
candidate();assert(d.requestOfficerDownNearby(f.patrol,c.status));finishCurrent(2)
f.entities.DeleteEntity=remove;c.clear()'''
    def inspect_cars(lua):
        rows=events()
        assert sum(r['kind']=='vehicle_dispose_requested' for r in rows)==3
        assert not any(r['kind']=='failed' for r in rows)
    case(stalled_cars,inspect_cars)
    try:case(stalled_cars,legacy=True)
    except LuaError as error:assert 'Accepted vehicle deletion remained stuck' in str(error),str(error)
    else:raise AssertionError('Previous accepted-car cleanup stall was not detected')
    # Disposal is only a request, never proof that a vehicle has detached.
    deferred=stalled_cars[:stalled_cars.index('f.disposeCompletes=true')]+'''
c.step(110)
assert(c.scene.hasCleanup() and OfficerNative:GetCreatedCount()==10 and #f.disposals==3)
assert(not d.isActive() and f.wallet==2000 and OfficerNative:GetStage()==3)
candidate();assert(not d.requestOfficerDownNearby(f.patrol,c.status))
assert(#f.creates==10)
for _,row in ipairs(f.disposals) do row.actor.attached=false;f.managed[row.id]=nil;f.objects[row.id]=nil end
c.step(2);assert(not c.scene.hasCleanup() and OfficerNative:GetCreatedCount()==0)
assert(d.requestOfficerDownNearby(f.patrol,c.status));f.entities.DeleteEntity=remove;c.clear()'''
    case(deferred)
    # No CET Dispose capability: the callback remains optional and bounded.
    # Its absence cannot become a native compile dependency or lose ownership.
    unavailable=stalled_cars[:stalled_cars.index('f.disposeCompletes=true')]+'''
for _,a in pairs(f.objects) do
 if a.record=='Vehicle.NCPDPatrol_OD_Police' or a.record=='Vehicle.NCPDPatrol_OD_GangCar' then a.Dispose=nil end
end
c.step(125)
assert(c.scene.hasCleanup() and OfficerNative:GetCreatedCount()==10 and OfficerNative:GetStage()==3)
assert(f.wallet==2000 and #f.creates==10 and not f.disposals and not d.isActive())
for id,a in pairs(f.objects) do
 if a.record=='Vehicle.NCPDPatrol_OD_Police' or a.record=='Vehicle.NCPDPatrol_OD_GangCar' then
  a.attached=false;f.managed[id]=nil;f.objects[id]=nil
 end
end
c.step(2);assert(not c.scene.hasCleanup() and OfficerNative:GetCreatedCount()==0 and f.wallet==2000)'''
    def inspect_unavailable(lua):
        rows=events()
        assert sum(r['kind']=='vehicle_dispose_unavailable' for r in rows)==3
        assert not any(r['kind']=='failed' for r in rows)
    case(unavailable,inspect_unavailable)
    # A refused delete has no acceptance receipt, so even an otherwise valid
    # owned vehicle cannot be disposed through the fallback.
    case('''candidate();f.deleteOK=false;f.disposeCompletes=true
assert(not d.requestOfficerDownNearby(f.patrol,c.status));c.step(30)
assert(not f.disposals and OfficerNative:GetCreatedCount()==10 and #f.creates==10)
assert(OfficerNative:GetStage()==3 and not d.isActive())
f.deleteOK=true;c.step(2);assert(not c.scene.hasCleanup());assert(d.requestOfficerDownNearby(f.patrol,c.status));c.clear()''')
    # Native deletion receipts and one-shot disposal survive CET reload.
    recover=stalled_cars[:stalled_cars.index('f.disposeCompletes=true')]+'''
f.disposeCompletes=true;c.step(92)
package.loaded.officer_down=nil;c.use(require('officer_down'));c.step(.25)
assert(c.scene.isActive() and OfficerNative:GetCreatedCount()==10)
c.step(8);assert(not c.scene.isActive() and OfficerNative:GetCreatedCount()==0 and #f.disposals==3)
candidate();assert(d.requestOfficerDownNearby(f.patrol,c.status));f.entities.DeleteEntity=remove;c.clear()'''
    # Refresh the facade as well: it uses the same module loaded above.
    recover=recover.replace("candidate();assert(d.requestOfficerDownNearby(f.patrol,c.status));f.entities.DeleteEntity=remove;c.clear()",
        "candidate();assert(c.scene.requestNearby(f.patrol,c.status,true,true,'manual'));f.entities.DeleteEntity=remove;c.clear()")
    case(recover)
    # Physical teardown can finish while Codeware retains a deleted ID. Keep
    # those ID-only receipts separately, never a live actor or new-call lock.
    stale=stalled_cars[:stalled_cars.index('f.disposeCompletes=true')]+'''
f.disposeCompletes=true;f.disposeLeavesManaged=true;c.step(104)
assert(not c.scene.hasCleanup() and OfficerNative:GetCreatedCount()==0 and OfficerNative:GetRetiredActorCount()==3)
local old={};for _,row in ipairs(f.disposals) do
 old[#old+1]=row.id;assert(not row.actor.attached and f.managed[row.id] and not f.objects[row.id])
end
candidate();assert(d.requestOfficerDownNearby(f.patrol,c.status));finishCurrent(2)
f.entities.DeleteEntity=remove;c.clear();assert(OfficerNative:GetRetiredActorCount()==3)
for _,id in ipairs(old) do f.managed[id]=nil end
c.step(2);assert(OfficerNative:GetRetiredActorCount()==0 and f.wallet==4000 and f.managed[999])'''
    def inspect_stale(lua):
        assert sum(r['kind']=='detached_actor_id_retired' for r in events())==3
    case(stale,inspect_stale)
    scoped=stalled_cars[:stalled_cars.index('f.disposeCompletes=true')]+'''
f.disposeCompletes=true;f.disposeLeavesManaged=true;c.step(104)
assert(OfficerNative:GetRetiredActorCount()==3)
local id=f.disposals[1].id;local before=#f.deletes
f.generation=f.generation+1;OfficerNative:OnRestored(0,0)
f.objects[id]=f:Actor('ambient',{hash=id},f.playerPoint);f.managed[id]=true
c.step(2)
assert(OfficerNative:GetRetiredActorCount()==0 and #f.deletes==before and f.objects[id].record=='ambient')'''
    case(scoped)
    # Native fallback rejects NPCs, foreign references/IDs, missing deletion
    # receipts, changed records and stale/unready worlds before calling Dispose.
    case('''local car,npc
for _,row in pairs(f.objects) do
 if row.record=='Vehicle.NCPDPatrol_OD_Police' then car=row end
 if row.record=='Character.NCPDPatrol_OD_Injured' then npc=row end
end
assert(OfficerNative:CacheCreatedObject(car) and OfficerNative:CacheCreatedObject(npc))
assert(not OfficerNative:PrepareCreatedVehicleDisposal(car))
assert(OfficerNative:MarkDeleteAccepted(car.id) and OfficerNative:MarkDeleteAccepted(npc.id))
assert(not OfficerNative:PrepareCreatedVehicleDisposal(npc) and not OfficerNative:RetireDetachedActorID(npc.id))
local foreign=f:Actor(car.record,car.id,car.pos)
assert(not OfficerNative:PrepareCreatedVehicleDisposal(foreign) and not OfficerNative:PrepareCreatedVehicleDisposal(f.objects[999]))
local record=car.record;car.record='Vehicle.OtherMod'
assert(not OfficerNative:PrepareCreatedVehicleDisposal(car));car.record=record
f.ready=false;assert(not OfficerNative:PrepareCreatedVehicleDisposal(car));f.ready=true
local gen=f.generation;f.generation=gen+1
assert(not OfficerNative:PrepareCreatedVehicleDisposal(car) and not OfficerNative:RetireDetachedActorID(car.id));f.generation=gen
assert(not f.disposals);c.clear()''')
    # Automatic selection preserves the retained scene and can choose another
    # type while bodies remain. It never shortens retention on its own.
    case('''local before=#f.deletes
assert(not d.requestOfficerDownNearby(f.patrol,c.status,'automatic'))
assert(c.scene.lifecycle().phase=='aftermath' and #f.deletes==before and OfficerNative:GetCreatedCount()==10)
local random=math.random;math.random=function(a,b) if b==100 then return 1 end;return random(a,b) end
assert(d.requestMixed(f.patrol,c.status,'automatic'));math.random=random
assert(c.fallback=='Scanner' and OfficerNative:GetCreatedCount()==10)
c.step(89);assert(c.scene.hasCleanup() and #f.deletes==before)
c.step(3);assert(not c.scene.hasCleanup() and OfficerNative:GetCreatedCount()==0)
candidate();assert(d.requestOfficerDownNearby(f.patrol,c.status));c.clear()''')
    # Codeware manager removal is not proof that physical actors detached.
    def inspect_pending(lua):
        pending=[r for r in events() if r['kind']=='cleanup_pending']
        assert len(pending)==1 and pending[0]['details']['attached_handles']==10
    case('''candidate();s.holdDetached=true
assert(not d.requestOfficerDownNearby(f.patrol,c.status))
assert(#f.deletes==10 and #f.creates==10 and OfficerNative:GetCreatedCount()==10)
assert(not d.isActive() and c.scene.lifecycle().phase=='aftermath')
assert(c.scene.state():find('cleanup requested',1,true))
c.step(20);assert(OfficerNative:GetCreatedCount()==10 and #f.creates==10 and not d.isActive())
assert(c.scene.state():find('cleanup pending',1,true))
local before=#f.deletes
assert(not d.requestOfficerDownNearby(f.patrol,c.status))
assert(#f.deletes==before and OfficerNative:GetCreatedCount()==10)
s.holdDetached=false;s.releaseDetached();c.step(2)
assert(not c.scene.hasCleanup() and OfficerNative:GetCreatedCount()==0 and f.wallet==2000)
assert(d.requestOfficerDownNearby(f.patrol,c.status));finishCurrent(2);c.clear()''',inspect_pending)
    # Refused deletion and cleanup API failures retain IDs and the successful
    # outcome; they never become foreground assignment failures.
    def inspect_error(lua):
        assert sum(r['kind']=='cleanup_error' for r in events())==1
        assert not any(r['kind']=='failed' for r in events())
    case('''candidate();f.deleteOK=false
assert(not d.requestOfficerDownNearby(f.patrol,c.status))
assert(OfficerNative:GetCreatedCount()==10 and #f.creates==10)
f.deleteOK=true
-- Exercise the actual cleanup boundary before any new token is reserved.
local remove=require('officer_down_actors').remove
require('officer_down_actors').remove=function() error('Injected cleanup API failure') end
c.step(4)
assert(c.scene.lifecycle().phase=='aftermath' and not d.isActive() and OfficerNative:GetStage()==3)
assert(OfficerNative:GetCreatedCount()==10 and f.wallet==2000 and #f.creates==10)
require('officer_down_actors').remove=remove
c.step(2);assert(not c.scene.hasCleanup() and OfficerNative:GetCreatedCount()==0)
assert(d.requestOfficerDownNearby(f.patrol,c.status));c.clear()''',inspect_error)
    # No manual cleanup mutation from unavailable/wanted/dead/menu contexts.
    case('''candidate();local before=#f.deletes
for _,condition in ipairs({'menu','wanted','duty'}) do
 if condition=='duty' then f.duty=false else f[condition]=true end
 assert(not d.requestOfficerDownNearby(f.patrol,c.status))
 assert(#f.deletes==before and OfficerNative:GetCreatedCount()==10)
 f.menu=false;f.wanted=false;f.duty=true
end
c.clear()''')
    case('''candidate();local oldDeletes=#f.deletes
f.ready=false;assert(not d.requestOfficerDownNearby(f.patrol,c.status))
assert(#f.deletes==oldDeletes and OfficerNative:GetCreatedCount()==10)
f.ready=true
local id=OfficerNative:GetCreatedID(0);f.generation=f.generation+1
OfficerNative:OnRestored(0,0)
f.objects[id.hash]=f:Actor('ambient',id,f.playerPoint);f.managed[id.hash]=true
assert(not d.requestOfficerDownNearby(f.patrol,c.status))
assert(#f.deletes==oldDeletes and f.objects[id.hash].record=='ambient')
assert(c.scene.lifecycle().phase=='idle' and OfficerNative:GetCreatedCount()==0 and f.wallet==2000)''')
    print('PASS: actual Officer Down repeat: v0.18e1 one-ID/zero-attached NPC and no-receipt stalls reproduced and rejected; detached owned actor retirement, fresh lookup/spawn guards; prior three-row/CET-disposal regressions; three completions/rearmed pin/EUR$6000 once; automatic retention/fallback and world/ownership guards (engine boundaries mocked)')
    return {'three_sequential_completions':True,'same_site_native_pin_rearmed':True,'previous_silent_refusal_detected':True,
      'manual_retry_shortens_aftermath_only':True,'automatic_retention_and_other_types_preserved':True,
      'physical_cleanup_before_next_token':True,'cleanup_error_does_not_fail_successful_quest':True,
      'one_pending_report':True,'payments_and_career_once_per_incident':True,
      'reported_three_pending_rows_and_ten_handles_reproduced':True,'accepted_vehicle_disposal_recovers_stall':True,
      'native_disposal_requires_private_actor_receipt_and_generation':True,'deferred_dispose_is_not_cleanup_proof':True,
      'detached_id_only_receipts_do_not_block_new_call':True,'retired_receipts_prune_and_forget_on_world_change':True,
      'native_disposal_and_stale_codeware_manager_game_validation':False,'actual_game_validation':False}

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--report',type=Path);a=p.parse_args();r=main()
    if a.report:a.report.write_text(json.dumps(r,indent=2)+'\n')
