local f={paused=false,combat=false,created={},actors={},managed={},logs={},backupRequest=false,partnerState=0}
local function vec(x,y,z) return {x=x,y=y,z=z,w=1} end
local function constructor(kind)
 return {new=function() return {kind=kind,Copy=function(self) return self end} end}
end
Vector4={new=function(x,y,z,w) return {x=x,y=y,z=z,w=w} end}
Vector3={new=function(x,y,z) return {x=x,y=y,z=z} end}
CName={new=function(v) return v end};TweakDBID={new=function(v) return v end}
EntityID={IsDefined=function(v) return v and v.hash end};DynamicEntitySpec=constructor('entity')
AISwitchToPrimaryWeaponCommand=constructor('gear');AIFollowTargetCommand=constructor('follow');AIHoldPositionCommand=constructor('hold')
AIMoveToCommand=constructor('move');MountEventData=constructor('mountData');AIMountCommand=constructor('mount');AIUnmountCommand=constructor('unmount')
AIVehicleDriveToPointAutonomousCommand=constructor('drive');AIFollowerRole={new=function() return {OnRoleCleared=function() end} end}
AINoRole={new=function() return {kind='none',OnRoleCleared=function() end} end}
WorldPosition={new=function() return {} end,SetVector4=function(v,p) v.position=p end}
AIPositionSpec={new=function() return {} end,SetWorldPosition=function(v,p) v.position=p.position end}
function NewObject() return {} end
moveMovementType={Run=1};EAIAttitude={AIA_Friendly=1}
gamedataNPCHighLevelState={Relaxed=5,Alerted=0,Combat=2,Dead=3}
worldNavigationRequestStatus={OK=1}
AINavigationSystem={HasPathFromAtoB=function() return true end}
TweakDB={GetRecord=function() return {} end}
ScriptedPuppet={IsDefeated=function(a,b) return (b or a).defeated end,IsUnconscious=function(a,b) return (b or a).unconscious end,
 IsActive=function(a,b) local v=b or a;return not v.dead and not v.defeated and not v.unconscious end,
 GetActiveWeapon=function(a,b) return (b or a).weapon or (b or a).leftWeapon end}
WeaponObject={IsFists=function(a,b) return (b or a)=='fists' end,
 GetWeaponType=function(a,b) return (b or a)=='grenade' and 0 or 1 end}
local function weapon(kind) return {GetItemID=function() return kind or 'gun' end} end
local function actor(id,record)
 local a={id=id or {hash=990},record=record,pos=vec(0,0,0),high=5,attached=true,commands={},stops={},autoEquip=true,
  tags={'NCPDPatrolOfficer'},inventory={gun=1}}
 function a:GetEntityID() return self.id end
 function a:GetRecordID() return self.record end
 function a:GetWorldPosition() return self.mounted and self.mounted.pos or self.pos end
 function a:GetWorldOrientation() return {} end
 function a:GetWorldForward() return vec(1,0,0) end
 function a:IsAttached() return self.attached end
 function a:IsDead() return self.dead==true end
 function a:IsDeadNoStatPool() return self.deadNoPool==true end
 function a:IsInCombat() return f.combat end
 function a:GetHighLevelStateFromBlackboard() if self.badAPI then error('unsupported fixture API') end;return self.high end
 function a:GetAttitudeAgent() return {GetAttitudeGroup=function() return 'player' end,SetAttitudeGroup=function() end,SetAttitudeTowards=function() end} end
 local ai={}
 function ai:GetAIRole() return a.role end
 function ai:SetAIRole(role) a.role=role end
 function ai:OnAttach() end
 function ai:IsCommandExecuting(name) return a.nativeBoarding==name end
 function ai:GetCommandState(cmd) return cmd.kind=='gear' and 'Enqueued' or 'Executing' end
 function ai:SendCommand(cmd)
  a.commands[#a.commands+1]=cmd
  if cmd.kind=='gear' and a.autoEquip then a.weapon=not cmd.unEquip and weapon() or nil end
  if cmd.kind=='mount' then a.mounted=f.actors[cmd.mountData.mountParentEntityId.hash];a.seat=cmd.mountData.slotName end
  if cmd.kind=='unmount' and not a.deferUnmount then a.mounted=nil;a.pos=vec(0,0,0) end
 end
 function ai:StopExecutingCommand(cmd) a.stops[#a.stops+1]=cmd end
 function a:GetAIControllerComponent() return ai end
 return a
end
local player=actor({hash=1});local ambient=actor({hash=990});f.managed[990]=true;f.actors[990]=ambient
ambient.tags={};player.tags={}
local patrol={Version=function() return 17 end,IsDispatchMenuOpen=function() return f.paused end,IsOnDuty=function() return not f.offDuty end,
 HasWantedLevel=function() return f.wanted==true end,
 NotifyDispatch=function() end}
local support={Version=function() return 17 end,
 RegisterPartner=function(_,a) f.partner=a;f.partnerState=1;return true end,
 UnregisterPartner=function() f.partnerState=0 end,TickPartner=function() end,GetPartnerState=function() return f.partnerState end,
 RestorePartnerFollowerRole=function() return true end,IsPartnerFollowerReady=function() return true end,
 ConfirmPartnerFollowerRestored=function() end,GetPartnerVoiceRevision=function() return 0 end,
 GetPartnerDiagnostics=function() return 'native' end,GetPartnerHealthDiagnostics=function() return 'health' end,
 GetBackupVehicle=function() return nil end,SetBackupStatus=function(_,text) f.backupStatus=text end,
 HasBackupUnit=function() return f.backupRequest or f.reserved end,
 ReleaseBackup=function() f.reserved=false;f.backupRequest=false end,
 TakeBackupRequest=function() local value=f.backupRequest;f.backupRequest=false;if value then f.reserved=true end;return value end}
local career={Version=function() return 3 end,GetSelectedPartnerRecord=function() return 'Character.cvi_ncpd_police_ranged2_copperhead_ma' end,
 GetSelectedPartnerName=function() return 'Standard' end}
local entities={IsReady=function() return true end,IsManaged=function(_,id) return f.managed[id.hash] or false end}
function entities:IsTagged(id,tag)
 local a=f.actors[id.hash];if id.hash==990 and not a then return true end
 if a then for _,v in ipairs(a.tags or {}) do if v==tag then return true end end end
 return false
end
function entities:CreateEntity(spec)
 local id={hash=100+#f.created};f.created[#f.created+1]=spec;f.managed[id.hash]=true
 local a=actor(id,spec.recordID);a.pos=spec.position;a.tags=spec.tags or {}
 if spec.recordID:sub(1,8)=='Vehicle.' then
  a.speed=0
  function a:GetCurrentSpeed() return self.speed end
  function a:IsDestroyed() return false end
  function a:ForceBrakesUntilStoppedOrFor() self.speed=0 end
  function a:GetAIComponent() return {SendCommand=function(_,cmd) a.drive=cmd;a.pos=vec(0,0,0) end,StopExecutingCommand=function() end} end
 end
 f.actors[id.hash]=a;return id
end
function entities:GetEntity(id) return f.actors[id.hash] end
function entities:DeleteEntity(id)
 assert(id.hash~=990,'ambient deletion');f.deletes=(f.deletes or 0)+1
 if f.refuseDelete then return false end
 if not f.deferDelete then f.managed[id.hash]=nil;f.actors[id.hash]=nil end
 return true
end
Game={GetPlayer=function() return player end,GetMountedVehicle=function(a) return a.mounted end,
 GetMountingFacility=function() return {GetMountingInfoSingleWithObjects=function(_,a) return {slotId={id=a.seat}} end} end,
 GetDynamicEntitySystem=function() return entities end,CreateEntityReference=function() return {} end,
 GetAINavigationSystem=function() return {FindPointInSphereForCharacter=function(_,p) return {status=1,point=p} end} end,
 GetScriptableSystemsContainer=function() return {Get=function(_,name)
  if name=='NCPDPatrolSupportSystem' then return support end
  if name=='NCPDPatrolSystem' then return patrol end
  if name=='NCPDPatrolCareerSystem' then return career end
  if name=='NCPDPatrolOfficerEquipment' then return EquipmentNative end
 end} end}
-- Run the actual redscript equipment controller, mocking only game hardware.
function IsDefined(v) return v~=nil and v~=0 end
function Equals(a,b) return a==b end
function NotEquals(a,b) return a~=b end
function ToString(v) return tostring(v) end
function ArraySize(v) return v.n end
function Deref(v) return v end
function ArrayPush(v,item) v[v.n]=item;v.n=v.n+1 end
function NativeContext() return {} end
function NativeEquipItem() return {} end
function NativeBodySlot(a,id) return 'body_'..id end
function GetPlayer() return player end
function GetMountedVehicle(a) return a.mounted end
gamedataItemType={Invalid=0}
NCPDPatrolSystem={Get=function() return patrol end}
function EquipmentNative:GetGameInstance() return {} end
-- Fixture actors are explicitly enrolled as our own, never ambient.
local originalActor=actor
actor=function(id,record)
 if not id then f.fixtureID=(f.fixtureID or 1000)+1;id={hash=f.fixtureID} end
 local a=originalActor(id,record);f.actors[id.hash]=a;f.managed[id.hash]=true;return a
end
AIHumanComponent={GetScriptContext=function(_,a,context)
 if a.noContext then return false end;context.actor=a;return true
end}
local transaction={}
function transaction:GetItemInSlot(a,slot)
 if slot=='AttachmentSlots.WeaponLeft' then return a.leftWeapon end
 return a.weapon
end
function transaction:HasItemInSlot(a,slot,id)
 local w=self:GetItemInSlot(a,slot);return w and w:GetItemID()==id or false
end
GameInstance={GetDynamicEntitySystem=function() return entities end,GetTransactionSystem=function() return transaction end}
AIActionTransactionSystem={GetEquipment=function(_,ctx,primary,list)
 local a=ctx.actor
 for _,item in ipairs(a.equipment or {{itemID='gun',slotID='AttachmentSlots.WeaponRight',bodySlotID='body_gun'}}) do
  if a.inventory[item.itemID] then ArrayPush(list,item) end
 end
 return list.n>0
end}
AISubActionEquipOnSlot_Record_Implementation={Equip=function(_,ctx,items)
 local a=ctx.actor;a.fallbackCalls=(a.fallbackCalls or 0)+1
 if a.refuseFallback then return false end
 for i=0,items.n-1 do
  local item=items[i];assert(a.inventory[item.itemID],'created a weapon outside inventory')
  if item.slotID=='AttachmentSlots.WeaponLeft' then a.leftWeapon=weapon(item.itemID) else a.weapon=weapon(item.itemID) end
 end
 return true
end}
AISubActionUnequipOnSlot_Record_Implementation={Unequip=function(_,ctx,drop,items)
 assert(not drop,'inventory weapon was dropped')
 local a=ctx.actor;a.fallbackCalls=(a.fallbackCalls or 0)+1
 if a.refuseFallback then return false end
 for i=0,items.n-1 do
  if items[i].slotID=='AttachmentSlots.WeaponLeft' then a.leftWeapon=nil else a.weapon=nil end
 end
 return true
end}
NPCPuppet={SetAnimWrapperBasedOnEquippedItem=function(_,a,slot,id,weight) a.wrapper=weight end}
AIActionHelper={ClearItemsUnequipped=function() end}
local boardingBusy=false
package.loaded.boarding={reset=function() boardingBusy=false end,cancel=function() boardingBusy=false end,
 busy=function() return boardingBusy end,update=function() end,state=function() return 'boundary' end}
package.loaded.revive_probe={reset=function() end,update=function() end,isSampling=function() return false end,
 state=function() return 'boundary' end,begin=function() end}
local function status(s) f.logs[#f.logs+1]=s end
local Ready=require('officer_ready')
local function advance(state,a,seconds,blocked)
 for _=1,math.floor(seconds*4+.0001) do Ready.update(state,.25,a,patrol,blocked,status) end
end
local function gears(a)
 local list={};for _,cmd in ipairs(a.commands) do if cmd.kind=='gear' then list[#list+1]=cmd end end;return list
end
-- Native boundary acknowledgements update actual held-weapon state.
local a=actor();local s={};player.weapon=weapon();advance(s,a,.25)
assert(#gears(a)==1 and a.weapon and not gears(a)[1].unEquip,table.concat(f.logs,'\n'))
advance(s,a,10);assert(#gears(a)==1,'duplicate draw commands')
player.weapon=nil;advance(s,a,.75);assert(#gears(a)==1);advance(s,a,.25)
assert(#gears(a)==2 and gears(a)[2].unEquip and not a.weapon)
player.weapon=weapon('fists');advance(s,a,2);assert(#gears(a)==2,'empty-hand fists treated as firearm')
-- A queued holster is cancelled on native alert/combat; no native order is stopped.
a=actor();a.weapon=weapon();a.autoEquip=false;s={};player.weapon=nil
advance(s,a,1);local queued=gears(a)[1];assert(queued and queued.unEquip)
local combatCommand={kind='nativeCombat'};a.high=2;advance(s,a,.25)
assert(a.stops[#a.stops]==queued and #gears(a)==1)
for _,stopped in ipairs(a.stops) do assert(stopped~=combatCommand) end
local drawing=actor();drawing.autoEquip=false;local drawingState={};player.weapon=weapon()
advance(drawingState,drawing,.25);local ownDraw=gears(drawing)[1]
drawing.high=2;advance(drawingState,drawing,.25)
assert(drawing.stops[#drawing.stops]==ownDraw,'pending draw prevented native combat weapon choice')
player.weapon=nil
for _,high in ipairs({0,2,3}) do a.high=high;advance(s,a,4);assert(#gears(a)==1) end
a.high=5;f.combat=true;advance(s,a,4);assert(#gears(a)==1);f.combat=false
-- Pause, mount, downed and revive/boarding must not get readiness commands.
a=actor();s={};player.weapon=weapon();f.paused=true;advance(s,a,1);assert(#gears(a)==0);f.paused=false
advance(s,a,1,true);assert(#gears(a)==0)
a.mounted={};advance(s,a,1);assert(#gears(a)==0);a.mounted=nil
player.mounted={};advance(s,a,1);assert(#gears(a)==0);player.mounted=nil
for _,flag in ipairs({'dead','deadNoPool','defeated','unconscious'}) do a[flag]=true;advance(s,a,1);assert(#gears(a)==0);a[flag]=false end
advance(s,a,.25);assert(#gears(a)==1)
-- A refusing engine gets bounded retries; unsupported API failure is isolated.
a=actor();a.autoEquip=false;a.refuseFallback=true;s={};advance(s,a,20);assert(#gears(a)==3 and a.fallbackCalls==3 and s.warned)
a=actor();a.badAPI=true;s={};local logs=#f.logs;advance(s,a,2);assert(s.failed and #f.logs==logs+1)
-- The reported live failure: accepted gear command stays Enqueued forever.
-- Verify the actual native fallback, then actual holster with inventory intact.
a=actor();a.autoEquip=false;s={};player.weapon=weapon();advance(s,a,1)
assert(not a.weapon and not a.fallbackCalls,'fallback ran before native grace period')
advance(s,a,.25);assert(a.weapon and a.fallbackCalls==1 and a.wrapper==1)
assert(a.inventory.gun==1 and Ready.diagnostics(s,a):find('officer weapon=true',1,true))
player.weapon=nil;advance(s,a,2);assert(not a.weapon and a.fallbackCalls==2 and a.inventory.gun==1 and a.wrapper==0)
-- Alerted draw is allowed; alerted holster, native combat, ambient actors,
-- unavailable context, non-weapon and non-hand equipment are not overwritten.
a=actor();a.autoEquip=false;a.high=0;s={};player.weapon=weapon();advance(s,a,1.25);assert(a.weapon)
player.weapon=nil;advance(s,a,4);assert(a.weapon and a.fallbackCalls==1)
a.high=2;assert(EquipmentNative:Apply(a,false)==0 and a.weapon)
assert(EquipmentNative:Apply(ambient,true)==0 and not ambient.weapon)
a=actor();a.autoEquip=false;a.noContext=true;assert(EquipmentNative:Apply(a,true)==0) -- V currently holstered
player.weapon=weapon();assert(EquipmentNative:Apply(a,true)==-1 and not a.weapon)
a.noContext=false;a.equipment={{itemID='grenade',slotID='AttachmentSlots.WeaponRight'},{itemID='gun',slotID='AttachmentSlots.Consumable'}}
a.inventory.grenade=1;assert(EquipmentNative:Apply(a,true)==-1 and not a.fallbackCalls)
-- Check both actual hand slots, including a right-hand fist plus left-hand gun.
a=actor();a.weapon=weapon('fists');a.leftWeapon=weapon();assert(EquipmentNative:IsReady(a))
player.weapon=nil;assert(EquipmentNative:Apply(a,false)==1 and not a.leftWeapon and a.inventory.gun==1)
assert(not EquipmentNative:IsReady(a) and a.weapon:GetItemID()=='fists')
-- Actual partner lifecycle calls readiness without changing follow/role recovery.
player.weapon=weapon()
local Partner=require('partner');Partner.spawn(true,status);Partner.update(.5,true,status)
local p=f.partner;assert(p and p.role)
Partner.update(.25,true,status);assert(#gears(p)==1 and p.weapon)
f.partnerState=2;player.weapon=nil;Partner.update(.25,true,status);local count=#gears(p)
Partner.update(.5,true,status);assert(#gears(p)==count,'downed partner received a holster')
f.partnerState=1;player.weapon=weapon()
for _=1,4 do Partner.update(.25,true,status) end
assert(p.role and Partner.state():find('restored',1,true))
boardingBusy=true;player.weapon=nil;for _=1,8 do Partner.update(.25,true,status) end
assert(#gears(p)==count,'boarding was interrupted by readiness')
boardingBusy=false;p.high=2;for _=1,8 do Partner.update(.25,true,status) end
assert(#gears(p)==count,'combat partner copied V holster')
Partner.dismiss(status);assert(f.managed[990] and not f.managed[p.id.hash])
-- Actual backup deploys, mounts, drives, brakes and exits before readiness sync.
local Backup=require('backup');player.weapon=weapon();f.backupRequest=true
for _=1,24 do Backup.update(.25,true,support,patrol,status) end
assert(Backup.state():find('on scene',1,true),table.concat(f.logs,'\n'))
local officers={}
for _,unit in pairs(f.actors) do if unit~=ambient and unit~=player and unit.record and unit.record:sub(1,10)=='Character.' then officers[#officers+1]=unit end end
assert(#officers==2)
for _,unit in ipairs(officers) do
 assert(unit.role and #gears(unit)==1 and unit.weapon)
 local follows,holds=0,0
 for _,cmd in ipairs(unit.commands) do
  if cmd.kind=='follow' then assert(cmd.target==player and cmd.teleport==false and not cmd.ignoreInCombat);follows=follows+1 end
  if cmd.kind=='hold' then holds=holds+1 end
 end
 assert(follows>=1 and holds==0,'active backup was held at the request location')
end
player.weapon=nil;officers[1].high=0
for _=1,8 do Backup.update(.25,true,support,patrol,status) end
assert(officers[1].weapon and #gears(officers[1])==1)
assert(not officers[2].weapon and #gears(officers[2])==2)
Backup.finish(support,status);assert(f.managed[990] and not Backup.isActive())
-- 10-4 is stand-down, not despawn. Pending requests can be cancelled with no actors.
assert(not Backup.release(support,patrol,status))
f.backupRequest=true;local before=#f.created;assert(Backup.release(support,patrol,status))
Backup.update(.25,true,support,patrol,status);assert(#f.created==before and not f.reserved)
local function deploy()
 f.backupRequest=true
 for _=1,24 do Backup.update(.25,true,support,patrol,status) end
 local list={}
 for _,unit in pairs(f.actors) do if unit.record and unit.record:sub(1,10)=='Character.' then list[#list+1]=unit end end
 return list
end
local units=deploy();assert(#units==2 and f.reserved)
local carID;for id,obj in pairs(f.actors) do if obj.record and obj.record:sub(1,8)=='Vehicle.' then carID=id end end
-- Original ability to ride with V is still present before stand-down.
local vcar=actor({hash=900},'Vehicle.ownedPolice');vcar.speed=5
function vcar:GetCurrentSpeed() return self.speed end
function vcar:ForceBrakesUntilStoppedOrFor() error('10-4 must not brake the player vehicle') end
units[1].mounted=vcar;units[1].seat='seat_back_left';units[1].deferUnmount=true
local deleteCount=f.deletes or 0;before=#f.created
local nativeCombat={kind='nativeCombat'};units[2]:GetAIControllerComponent():SendCommand(nativeCombat)
assert(Backup.release(support,patrol,status) and Backup.isActive() and f.reserved)
assert((f.deletes or 0)==deleteCount,'10-4 despawned actors')
for _,unit in ipairs(units) do
 assert(unit.role.kind=='none' and not unit.role.followerRef)
 for _,stopped in ipairs(unit.stops) do assert(stopped~=nativeCombat) end
end
local role=units[1].role
assert(Backup.release(support,patrol,status) and units[1].role==role,'duplicate stand-down reattached role')
-- Wait for the actual vehicle to stop; use actual parent and seat, animated exit.
local function countKind(a,kind)
 local count=0;for _,cmd in ipairs(a.commands) do if cmd.kind==kind then count=count+1 end end;return count
end
local unmounts=countKind(units[1],'unmount')
for _=1,8 do Backup.update(.25,true,support,patrol,status) end
assert(countKind(units[1],'unmount')==unmounts and units[1].mounted==vcar)
vcar.speed=0;Backup.update(.25,true,support,patrol,status)
local cmd=units[1].commands[#units[1].commands]
assert(cmd.kind=='unmount' and cmd.mountData.mountParentEntityId.hash==900 and cmd.mountData.slotName=='seat_back_left')
assert(not cmd.mountData.isInstant and not cmd.mountData.ignoreHLS and not cmd.mountData.allowFailsafeTeleport)
assert(not f.backupStatus:find('remaining on scene',1,true),'unconfirmed exit reported as complete')
-- Refused exit retries are bounded, without deleting or teleporting the officer.
for _=1,160 do Backup.update(.25,true,support,patrol,status) end
assert(countKind(units[1],'unmount')==unmounts+3 and (f.deletes or 0)==deleteCount)
units[1].mounted=nil;units[1].pos=vec(0,0,0)
Backup.update(.25,true,support,patrol,status)
assert(f.backupStatus:find('remaining on scene',1,true) and f.reserved and Backup.isActive())
-- No readiness mirroring/follower reattachment or replacement patrol after 10-4.
for _,unit in ipairs(units) do unit.weapon=nil end
player.weapon=weapon();for _=1,12 do Backup.update(.25,true,support,patrol,status) end
for _,unit in ipairs(units) do assert(not unit.weapon and unit.role.kind=='none') end
assert(#f.created==before and (f.deletes or 0)==deleteCount)
-- An old native mount finishing after stand-down cannot trap our hold command
-- above the exit request or restore a follower role.
local held=units[2].commands[#units[2].commands]
units[2].mounted=vcar;units[2].seat='seat_back_right'
Backup.update(.25,true,support,patrol,status)
assert(not units[2].mounted and units[2].stops[#units[2].stops]==held)
Backup.update(.25,true,support,patrol,status);assert(units[2].role.kind=='none')
-- Leaving 150 m for three seconds invokes existing cleanup. Deferred deletion
-- keeps the reservation even if DeleteEntity returned true.
player.pos=vec(200,0,0);f.deferDelete=true
for _=1,11 do Backup.update(.25,true,support,patrol,status) end
assert((f.deletes or 0)==deleteCount)
Backup.update(.25,true,support,patrol,status)
assert((f.deletes or 0)>deleteCount and f.reserved and Backup.isActive())
f.deferDelete=false
for _=1,16 do Backup.update(.25,true,support,patrol,status) end
assert(not f.reserved and not Backup.isActive() and f.managed[990])
-- Stand-down does not alter the primary partner or keep stale world reservations.
player.pos=vec(0,0,0);Partner.spawn(true,status);Partner.update(.5,true,status)
p=f.partner;local partnerRole=p.role;units=deploy()
assert(Backup.release(support,patrol,status) and p.role==partnerRole and f.managed[p.id.hash])
local deleted=f.deletes;Backup.reset();assert(f.deletes==deleted,'world reset deleted stale IDs')
Partner.dismiss(status)
