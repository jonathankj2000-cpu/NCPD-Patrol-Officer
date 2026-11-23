-- Event delivery and component accessibility are recording boundaries. Native
-- game method bodies and all production scope/loot logic are executed.
local f=F
function f.player:IsDead() return f.obPlayerDead==true end
TDBID=TDBID or {}
TDBID.ToStringDEBUG=function(_,id) return id end
IntToString=tostring
AbsF=math.abs
function EnumInt(value) return value end
function IsNameValid(name) return type(name)=='string' and name~='' and name~='None' end
GameplayTier={Undefined=0,Tier1_FullGameplay=1,Tier2_StagedGameplay=2,Tier3_LimitedGameplay=3,Tier4_FPPCinematic=4,Tier5_Cinematic=5}
gamedataQuality={Invalid=-1,Random=-2,Common=0,Uncommon=1,Rare=2,Epic=3,Legendary=4,Iconic=5}
gamedataItemType={Con_Ammo=1}
function ReferenceBool(value) return value~=nil and value~=false and value~=0 end
function NewLootAccessEvent() return {kind='loot-access'} end
function NewReferenceAnimFeature() return {} end
function NewReferenceInteractionEvent() return {kind='interaction-layer'} end
f.obLootEvents={};f.obAccessRequests=0;f.obQualityRequests=0;f.obInteractionRequests=0;f.obNativeInventoryUpdates=0
f.obPSMOriginalCalls={initial=0,tier2=0,exploration=0};f.obPSMWrites={}
local qs=GameInstance:GetQuestsSystem({})
function qs:GetFact(name) return f.qfacts[name] or 0 end
local originalActor=f.Actor
function f:Actor(record,id,position)
 local actor=originalActor(self,record,id,position)
 if record=='Character.NCPDPatrol_VossContractor01' then
  for name,method in pairs(GameReference.ScriptedPuppet) do actor[name]=method end
  for name,method in pairs(NativeEvidenceLoot) do actor[name]=method end
  actor.m_lootQuality=gamedataQuality.Invalid;actor.m_activeQualityRangeInteraction='';actor.m_hasQuestItems=false;actor.m_isIconic=false
  actor.m_inventoryComponent={accessible=not f.obInitialLootInaccessible,IsAccessible=function(self) return self.accessible end}
  actor.m_interactionComponent={isEnabled=true,GetActiveInputLayers=function(self,layers)
   if actor.obLootLayer and f.obLookingAtBody then ArrayPush(layers,{layerName='Loot',activator=f.player}) end
   return ArraySize(layers)>0
  end}
  if f.obMissingInventory then actor.m_inventoryComponent=nil end
  if f.obMissingInteraction then actor.m_interactionComponent=nil end
  if f.obDisabledInteraction then actor.m_interactionComponent.isEnabled=false end
  function actor:IsActive() return not self.dead and not self.down end
  function actor:IsQuest() return self.m_hasQuestItems end
  function actor:GetIsIconic() return self.m_isIconic end
  function actor:RequestHUDRefresh() self.obHUDRefreshes=(self.obHUDRefreshes or 0)+1 end
  function actor:EvaluateLootQualityEvent()
   f.obQualityRequests=f.obQualityRequests+1;f.obLootEvents[#f.obLootEvents+1]={actor=self,kind='evaluate-loot'}
  end
  function actor:QueueEvent(evt)
   if evt.kind=='loot-access' then f.obAccessRequests=f.obAccessRequests+1 end
   f.obLootEvents[#f.obLootEvents+1]={actor=self,kind=evt.kind,event=evt}
  end
  function actor:EnableInteraction(layer,enabled)
   assert(layer=='Loot');self.obLootLayer=enabled;f.obInteractionRequests=f.obInteractionRequests+1
  end
  function actor:DetermineInteractionStateByTask() self.obDetermineRequests=(self.obDetermineRequests or 0)+1 end
 end
 return actor
end
local tx=GameInstance:GetTransactionSystem({})
function tx:GetItemList(actor,items)
 if self:GetItemQuantity(actor,f.obitem)>0 then
  ArrayPush(items,{GetItemType=function() return 0 end,HasTag=function(_,tag) return tag=='Quest' end})
 end
 return true
end
RPGManager=RPGManager or {}
RPGManager.GetItemDataQuality=function() return gamedataQuality.Common end
RPGManager.ToggleLootHighlight=function(_,actor,isQuest) actor.obQuestHighlight=isQuest end
RPGManager.IsItemIconic=function() return false end
UIItemsHelper={QualityEnumToInt=function(_,quality) return quality end}
local advance=f.obAdvance
function f.obAdvance(seconds)
 advance(seconds)
 local queue=f.obLootEvents;f.obLootEvents={}
 for _,row in ipairs(queue) do
  local actor=row.actor
  if row.kind=='loot-access' then
   if not f.obAccessDeliveryBlocked and actor.m_inventoryComponent then
    -- This is the unimplemented native Inventory event handler, not proof of
    -- its in-game behavior. Delayed/rejected delivery is tested independently.
    actor.m_inventoryComponent.accessible=row.event.accessible;f.obNativeInventoryUpdates=f.obNativeInventoryUpdates+1
    actor:OnSetLootInteractionAccessEvent(row.event)
   end
  elseif row.kind=='evaluate-loot' then
   if actor:EvaluateLootQuality() then actor:RequestHUDRefresh() end
  elseif row.kind=='interaction-layer' then
   actor.obQualityLayer=row.event.enable and row.event.layer or nil
  else error('Unknown encounter native event') end
 end
end
-- Main-player PSM services are separate from the briefing workspot fixture.
local oldDefs=GetAllBlackboardDefs
GetAllBlackboardDefs=function()
 local defs=oldDefs();defs.PlayerStateMachine={HighLevel='high',UpperBody='upper',SceneAimForced='aim',SceneSafeForced='safe',Vitals='vitals'};return defs
end
f.obBoard={values={high=2,upper=5,aim=false,safe=false}}
function f.obBoard:GetInt(id) return self.values[id] or 0 end
function f.obBoard:GetBool(id) return self.values[id]==true end
function f.obBoard:SetInt(id,value)
 f.obPSMWrites[#f.obPSMWrites+1]={key=id,value=value};self.values[id]=value
 if id=='high' then GameReference.WeaponReadyListenerTransition.OnHighLevelChanged(f.obWeaponReady,value) end
end
function f.obBoard:SetBool(id,value) f.obPSMWrites[#f.obPSMWrites+1]={key=id,value=value};self.values[id]=value end
f.obWeaponReady={m_beingCreated=false,m_isInSafeSceneTier=true,m_isSceneAimForced=false}
f.obWeaponReady.UpdateWeaponReadyListenerReturnValue=GameReference.WeaponReadyListenerTransition.UpdateWeaponReadyListenerReturnValue
f.obWeaponReady:UpdateWeaponReadyListenerReturnValue()
f.obTierData={tier=2,emptyHands=true,userDebugInfo='recorded native Tier2 request (fixture)'}
f.obTier={GetTierData=function() return f.obTierData end}
f.obContext={values={ForceEmptyHands=true}}
function f.obContext:GetPermanentScriptableParameter(name) assert(name=='SceneTier');return f.obMissingTier and nil or f.obTier end
function f.obContext:GetBoolParameter(name,permanent) return self.values[name]==true end
function f.obContext:IsStateMachineActive(name) assert(name=='LocomotionTakedown');return f.obTakedown==true end
function f.obContext:SetPermanentBoolParameter(name,value,signal)
 f.obPSMWrites[#f.obPSMWrites+1]={parameter=name,value=value};self.values[name]=value
end
f.obSI={executionOwner=f.player,owner=f.player,localBlackboard=f.obBoard,
 IsSceneAnimationActive=function() return f.obSceneAnimation==true end,
 GetSceneSystem=function() return Game.GetSceneSystem() end,
 GetQuestsSystem=function() return qs end,
 SetAnimationParameterFeature=function() end,
 GetAudioSystem=function() return {Play=function() end} end}
local workspots=Game.GetWorkspotSystem();local oldWorkspot=workspots.IsActorInWorkspot
function workspots:IsActorInWorkspot(actor)
 if actor==f.player then return f.obPlayerWorkspot==true end
 return oldWorkspot(self,actor)
end
StatusEffectSystem=StatusEffectSystem or {}
StatusEffectSystem.ObjectHasStatusEffect=function(_,actor,id) assert(actor==f.player);return f.obRestrictions and f.obRestrictions[id]==true or false end
VehicleComponent=VehicleComponent or {}
VehicleComponent.IsMountedToVehicle=function(_,game,actor) assert(actor==f.player);return f.mounted==true end
local common={}
for _,owner in ipairs({'DefaultTransition','HighLevelTransition','SceneTierAbstract'}) do for k,v in pairs(GameReference[owner]) do common[k]=v end end
function common:SceneTierToEnter() return 2 end
function common:IsNoCombatActionsForced() return f.obNoCombatTag==true end
for _,name in ipairs({'BlockMovement','ResetForceWalkSpeed','RemoveAllTierLocomotions','ForceDefaultLocomotion','SetPlayerVitalsAnimFeatureData','SetPlayerDeathAnimFeatureData','ForceDisableToggleWalk','UpdateCameraParams','SetAudioParameter'}) do common[name]=function() end end
function common:GetCurrentHealthPerc() return 100 end
function IsClient() return false end
for _,owner in ipairs({'SceneTierInitialDecisions','SceneTierIIDecisions','SceneTierAbstractDecisions','SceneTierAbstractEvents','ExplorationEvents'}) do
 setmetatable(GameReference[owner],{__index=common})
end
function ReferenceSuperOnEnter() f.obNativeSuperCalls=(f.obNativeSuperCalls or 0)+1 end
PlayerPuppet.ReevaluateAllBreathingEffects=function() end
GameObject=GameObject or {};GameObject.PlaySoundEvent=function() end
function OriginalSceneTierInitialDecisions(self,ctx,si)
 f.obPSMOriginalCalls.initial=f.obPSMOriginalCalls.initial+1;return GameReference.SceneTierInitialDecisions:EnterCondition(ctx,si)
end
function OriginalSceneTierIIDecisions(self,ctx,si)
 f.obPSMOriginalCalls.tier2=f.obPSMOriginalCalls.tier2+1;return GameReference.SceneTierIIDecisions:EnterCondition(ctx,si)
end
function OriginalSceneTierAbstractDecisions(self,ctx,si)
 f.obPSMOriginalCalls.exploration=f.obPSMOriginalCalls.exploration+1;return GameReference.SceneTierAbstractDecisions:ToExploration(ctx,si)
end
