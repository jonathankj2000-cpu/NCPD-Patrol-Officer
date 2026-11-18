-- Native boundaries. All encounter, completion and dispatch decisions are production code.
CyberFixture={}
local f=CyberFixture
local root='quests/minor_quest/ncpd_patrol_cyberpsycho'
local oldChange=JournalFixture.ChangeEntryState
function JournalFixture:ChangeEntryState(path,kind,state,notify)
 if path:sub(1,#root)~=root then return oldChange(self,path,kind,state,notify) end
 local entry=self:GetEntryByString(path,kind);assert(entry,'invalid private cyberpsycho journal path')
 self.writes[#self.writes+1]={path=path,state=state,notify=notify}
 if self.rejectState==state then return false end
 if self.rejectReset and state==1 and (entry.state==3 or entry.state==4) then return false end
 if not self.ignoreWrites then entry.state=state end
 return true
end
function IsDefined(v) return v~=nil and v~=0 end
function Equals(a,b) return a==b end
function NotEquals(a,b) return a~=b end
Vector4={Distance=function(_,a,b) return math.sqrt((a.x-b.x)^2+(a.y-b.y)^2+(a.z-b.z)^2) end,
 new=function(x,y,z,w) return {x=x,y=y,z=z,w=w} end}
CName={new=function(v) return v end};TweakDBID={new=function(v) return v end}
worldNavigationRequestStatus={OK=0,FAIL=1}
EntityID={IsDefined=function(id) return id and id.hash and id.hash~=0 end}
DynamicEntitySpec={new=function() return {} end}
AIInjectCombatThreatCommand={new=function() return {} end}
EAIAttitude={AIA_Hostile=2}
local player={}
function player:IsAttached() return f.playerAttached end
function player:IsDead() return f.playerDead end
function player:IsInCombat() return f.combat end
function player:GetWorldPosition() return {x=f.playerPosition.x,y=f.playerPosition.y,z=f.playerPosition.z,w=1} end
function player:GetWorldOrientation() return {} end
function player:GetWorldForward() return {x=1,y=0,z=0,w=0} end
function player:GetAttitudeAgent() return {player=true} end
local patrol={}
function patrol:GetGameInstance() return {} end
function patrol:Version() return 17 end
function patrol:IsOnDuty() return f.duty end
function patrol:HasWantedLevel() return f.wanted end
function patrol:IsDispatchMenuOpen() return f.paused end
function patrol:NotifyDispatch(text,seconds,sound,voice) f.notices[#f.notices+1]={text=text,seconds=seconds,sound=sound,voice=voice} end
function patrol:ClearDispatchWaypoints() f.markers={} end
function patrol:PlaceDispatchWaypoint(pos)
 if not f.markerOK then return {value=0} end
 f.markers[#f.markers+1]=pos;return {value=#f.markers}
end
function patrol:TickBonuses() end
function patrol:GetDispatchCandidates() return f.scanners end
function patrol:GetScannerPhase(hash,marker) return marker and marker.phase or 'complete' end
function patrol:NotifyDispatchReward() error('Cyberpsycho test must not award scanner/dispatch money') end
f.patrol=patrol
function GetPlayer() if f.playerPresent then return player end end
NCPDPatrolSystem={Get=function() return patrol end}
function CyberNative:GetGameInstance() return {} end
ScriptedPuppet={IsActive=function(_,npc) return npc.active end,
 IsDefeated=function(_,npc) return npc.defeated end,IsUnconscious=function(_,npc) return npc.unconscious end}
function f:Actor(record,id)
 local a={record=record or 'Character.NCPDPatrol_Cyberpsycho',id=id,attached=true,active=true,
  dead=false,deadNoPool=false,defeated=false,unconscious=false,pos={x=65,y=0,z=0,w=1},commands={},attitudes={}}
 function a:GetRecordID() return self.record end
 function a:GetEntityID() return self.id end
 function a:GetWorldPosition() return {x=self.pos.x,y=self.pos.y,z=self.pos.z,w=1} end
 function a:IsAttached() return self.attached end
 function a:IsDead() return self.dead end
 function a:IsDeadNoStatPool() return self.deadNoPool end
 function a:GetAttitudeAgent()
  if f.aiMissing then return nil end
  return {SetAttitudeGroup=function(_,value) a.attitudes.group=value end,
   SetAttitudeTowards=function(_,target,value) assert(target.player);a.attitudes.hostile=value end}
 end
 function a:GetAIControllerComponent()
  if f.aiMissing then return nil end
  return {SendCommand=function(_,command)
   assert(command.duration==-1 and command.isPersistent==true and command.dontForceHostileAttitude==false)
   assert(command.targetPuppetRef.root=='#player');a.commands[#a.commands+1]=command
  end}
 end
 return a
end
local entities={}
function entities:IsReady() return f.entityReady end
function entities:IsManaged(id) return f.managed[id.hash]==true end
function entities:CreateEntity(spec)
 assert(spec.recordID=='Character.NCPDPatrol_Cyberpsycho')
 assert(spec.persistSpawn==false and spec.persistState==false and spec.alwaysSpawned==false and spec.active and spec.spawnInView)
 f.creates[#f.creates+1]=spec
 if not f.createOK then return {hash=0} end
 local id={hash=1000+#f.creates};f.managed[id.hash]=true
 local a=f:Actor(spec.recordID,id);a.pos=spec.position;f.actors[id.hash]=a
 return id
end
function entities:DeleteEntity(id)
 assert(id and id.hash~=990,'ambient actor delete attempted')
 f.deletes[#f.deletes+1]=id.hash
 if not f.deleteOK then return false end
 if not f.deleteDeferred then f.managed[id.hash]=nil;f.actors[id.hash]=nil end
 return true
end
local nav={FindPointInSphereForCharacter=function(_,point,radius,target)
 assert(radius==4 and target==player)
 f.probes[#f.probes+1]=point
 if f.navOK then return {status=0,point=f.navOverride or point} end
 return {status=1}
end}
AINavigationSystem={HasPathFromAtoB=function(target) assert(target==player);return f.pathOK end}
Game={GetPlayer=GetPlayer,GetDynamicEntitySystem=function() return entities end,
 GetMountedVehicle=function() if f.mounted then return {} end end,
 GetAINavigationSystem=function() return nav end,
 FindEntityByID=function(id) if f.actorVisible then return f.actors[id.hash] end end,
 CreateEntityReference=function(root) return {root=root} end,
 GetScriptableSystemsContainer=function() return {Get=function(_,name)
  if name=='NCPDPatrolCyberpsychoSystem' and f.nativePresent then return CyberNative end
  if name=='NCPDPatrolDispatchJournalSystem' then return DispatchJournalBridge end
  if name=='NCPDPatrolSystem' then return patrol end
 end} end}
TweakDB={GetRecord=function(_,id) if f.recordOK then return {} end end}
f.hud={text='',visible=false}
package.loaded.dispatch_hud={init=function() end,shutdown=function() end,state=function() return 'fixture' end,
 set=function(text,visible) f.hud.text=text;f.hud.visible=visible end}
function f:Status(text) self.logs[#self.logs+1]=text end
function f:Reset()
 self.duty=true;self.wanted=false;self.paused=false;self.playerPresent=true;self.playerAttached=true
 self.playerDead=false;self.combat=false;self.mounted=false;self.entityReady=true;self.nativePresent=true
 self.playerPosition={x=0,y=0,z=0,w=1};self.navOK=true;self.pathOK=true;self.navOverride=nil
 self.markerOK=true;self.createOK=true;self.deleteOK=true;self.deleteDeferred=false
 self.recordOK=true;self.actorVisible=true;self.aiMissing=false
 self.creates={};self.deletes={};self.managed={[990]='ambient'};self.actors={};self.probes={}
 self.notices={};self.markers={};self.logs={};self.scanners={}
 JournalFixture:ResetRuntime(DispatchJournalNative);DispatchRewardFixture:Reset()
 for _,v in ipairs({{root,'gameJournalQuest'},{root..'/main','gameJournalQuestPhase'},
  {root..'/main/neutralize','gameJournalQuestObjective'},{root..'/main/neutralize/briefing','gameJournalQuestDescription'}}) do
  JournalFixture.entries[v[1]]={path=v[1],className=v[2],state=1}
 end
 CyberNative:OnAttach()
end
function f:State() return JournalFixture.entries[root].state end
function f:Advance(seconds) for _=1,math.floor(seconds*4+0.0001) do CyberNative:Tick(0.25) end end
f:Reset()
