-- Execute the pinned native quest handler at an asynchronous engine boundary.
-- Police spawning, detection and cooldown are native and not emulated here.
local f=F
f.obWantedRequests={};f.obWantedQueue={};f.obNativeWantedCalls=0
f.obHeat=0;f.obWantedDue=0.25
function NewWantedRequest()
 return {m_wantedLevel=0,m_forceGreyStars=false,m_resetGreyStars=false,
  m_forcePlayerPositionAsLastCrimePoint=false,m_forceIgnoreSecurityAreas=false}
end
function NewReferenceDeescalation() return {} end
EPreventionHeatStage={Heat_0=0,Heat_1=1,Heat_2=2,Heat_3=3,Heat_4=4,Heat_5=5,Invalid=-1}
PreventionSystem=GameReference.PreventionSystem
local service={m_forceEternalGreyStars=false,m_ignoreSecurityAreasByQuest=false,m_player=f.player}
f.obPrevention=service
function service:GetGameInstance() return {} end
function service:GetHeatStage() return f.wanted and math.max(f.obHeat,1) or 0 end
function service:IsChasingPlayer() return self:GetHeatStage()>0 end
function service:QueueRequest(request)
 f.obWantedRequests[#f.obWantedRequests+1]=request
 f.obWantedQueue[#f.obWantedQueue+1]={request=request,due=f.obTime+f.obWantedDue}
end
function service:TogglePreventionSystem(value) self.enabled=value end
function service:GetLastKnownPlayerPosition() return self.lastKnown or Vector4.new(0,0,0,0) end
function service:SetLastKnownPlayerPosition(value) self.lastKnown=value end
function service:TogglePreventionGlobalQuestObjective_Internal(value,source)
 self.objective=value;self.objectiveSource=source
end
function service:ChangeHeatStage(level,reason)
 -- Recording boundary for native OnHeatChanged/spawning/blackboards.
 f.obHeat=level;f.wanted=level>0;f.obHeatReason=reason
end
function Vector4:IsZero(value) return value.x==0 and value.y==0 and value.z==0 end
local box=Game.GetScriptableSystemsContainer();local previous=box.Get
function box:Get(name)
 if name=='PreventionSystem' then return not f.obMissingPrevention and service or nil end
 return previous(self,name)
end
local advance=f.obAdvance
function f.obAdvance(seconds)
 advance(seconds)
 for i=#f.obWantedQueue,1,-1 do
  local row=f.obWantedQueue[i]
  if row.due<=f.obTime and not f.obHoldWantedQueue then
   table.remove(f.obWantedQueue,i);f.obNativeWantedCalls=f.obNativeWantedCalls+1
   GameReference.PreventionSystem.OnSetWantedLevel(service,row.request)
  end
 end
end
