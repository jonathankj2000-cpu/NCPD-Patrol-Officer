-- Engine boundaries for the actual catalogue, quest owner, scene and scheduler.
local f,s=F,SurveyFixture
local catalog=require('officer_down_sites')
f.duty=true
local byPath,byHash={},{}
for _,site in ipairs(catalog.sites) do
 local root=NCPDPatrolOfficerDownCatalog:Root(site.index)
 local path=root..'/main/assist/location'
 local p=Vector4.new(site.x,site.y,site.z,1)
 byPath[path]={site=site,point=p};byHash[PathHash(path)]=p
 for _,entry in ipairs({{'','gameJournalQuest'},{'/main','gameJournalQuestPhase'},
  {'/main/assist','gameJournalQuestObjective'},{'/main/assist/briefing','gameJournalQuestDescription'},{'/main/assist/location','gameJournalQuestMapPin'}}) do
  local key=root..entry[1];f.entries[key]={path=key,kind=entry[2],state=1}
 end
 local pin={hash=PathHash(path),kind='quest',id=8000+site.index,active=false,pos=p,catalog=true}
 function pin:GetJournalPathHash() return self.hash end
 function pin:IsActive() return self.active end
 function pin:GetNewMappinID() return {value=self.id} end
 function pin:GetWorldPosition() return self.pos end
 ArrayPush(f.pins,pin)
end
local quests=GameInstance:GetQuestsSystem({})
function quests:ExecuteNode(node,input)
 assert(byPath[node.path.realPath] and node.id==0 and node.path.fileEntryIndex==1 and node.disablePreviousMappins==false)
 for i=0,f.pins.n-1 do if f.pins[i].hash==PathHash(node.path.realPath) then f.pins[i].active=input=='Active' end end
end
function f.map:GetQuestMappinPosition(hash) return self and f.lookupKnown,byHash[hash] end
local scene=require('officer_down')
CF={scene=scene,hud={set=function(text,visible) f.hud=visible and text or '' end},logs={}}
local c=CF
function c.use(value) scene=value;c.scene=value end
function c.status(line) c.logs[#c.logs+1]=line end
function c.step(seconds)
 for _=1,math.floor(seconds*4+.001) do
  s.time=s.time+.25
  if s.onTick then s.onTick() end
  scene.update(.25,f.duty,f.patrol,c.status,c.hud)
  IncidentNative:Tick(.25)
 end
end
function c.only(index)
 for _,site in ipairs(catalog.sites) do site.enabled=site.index==index;if site.enabled then c.site=site end end
end
function c.point(dx,dy,dz) return Vector4.new(c.site.x+(dx or 0),c.site.y+(dy or 0),c.site.z+(dz or 0),1) end
function c.request(index)
 c.only(index);f.playerPoint=c.point(-800)
 assert(scene.requestNearby(f.patrol,c.status,true,true,'test'),scene.state())
 assert(OfficerNative:GetCatalogIndex()==index and #f.creates==0 and f.manual==654)
 c.step(.25)
 assert(OfficerNative.m_marker.m_confirmed,OfficerNative:GetDiagnostics())
 local active=0
 for i=0,f.pins.n-1 do if f.pins[i].catalog and f.pins[i].active then active=active+1;assert(f.pins[i].hash==OfficerNative.m_marker.m_hash) end end
 assert(active==1,'More than the selected authored quest pin activated')
end
function c.staged(index)
 c.request(index);f.playerPoint=c.point(-100);c.step(.75)
 assert(#f.creates==10 and OfficerNative:GetCreatedCount()==10 and OfficerNative:GetStage()==1)
 c.step(8);assert(scene.diagnostics():find('access ready seconds=',1,true))
 assert(#f.threats==0 and OfficerNative:GetStage()==1)
end
function c.active(index)
 c.staged(index);f.playerPoint=c.point(-40);c.step(.25)
 assert(OfficerNative:GetStage()==2,scene.state()..' | '..scene.diagnostics())
 assert(#f.threats==15)
end
function c.neutralize()
 for _,a in pairs(f.objects) do if a.record=='Character.NCPDPatrol_OD_Ganger' then a.down=true end end
end
function c.complete(index)
 c.active(index);c.neutralize();f.playerPoint=OfficerNative.m_injured.pos
 assert(scene.revive(c.status));c.step(5.5)
 assert(OfficerNative:GetStage()==3 and f.wallet==2000 and IncidentNative:GetCompletedCount()==1)
 assert(not scene.isActive() and scene.hasCleanup())
end
function c.clear()
 assert(scene.cancel(f.patrol,c.status));c.step(2)
 assert(not scene.isActive() and not scene.hasCleanup() and OfficerNative:GetCreatedCount()==0 and f.managed[999])
 for _,a in ipairs(s.allActors) do assert(not a.attached) end
 assert(f.manual==654)
end
function c.dispatch()
 local empty={state=function() return 'idle' end,isActive=function() return false end,hasCleanup=function() return false end,
  lifecycle=function() return {reserved=false,foregroundCleanup=false,backgroundCleanup=false} end,
  reset=function() end,update=function() return false end,finish=function() end}
 package.loaded.vip=setmetatable({request=function() c.fallback='VIP';return true end},{__index=empty})
 package.loaded.cyberpsycho=setmetatable({request=function() c.fallback='Cyberpsycho';return true end},{__index=empty})
 package.loaded.dispatch_scanner=setmetatable({isFailed=function() return false end,candidates=function() return 0 end,
  request=function() c.fallback='Scanner';return true end},{__index=function() return function() end end})
 package.loaded.dispatch_journal=setmetatable({},{__index=function() return function() end end})
 package.loaded.dispatch_hud={set=c.hud.set,state=function() return '' end,shutdown=function() end}
 local box=Game.GetScriptableSystemsContainer();local get=box.Get
 function box:Get(name)
  if name=='NCPDPatrolVIPSystem' or name=='NCPDPatrolCyberpsychoSystem' then
   return {Version=function() return 4 end,IsReady=function() return true end,GetStage=function() return 0 end}
  end
  return get(self,name)
 end
 package.loaded.dispatch=nil
 local d=require('dispatch');d.reset();d.start(f.patrol,c.status);d.setAutomatic(false)
 c.d=d
 return d
end
