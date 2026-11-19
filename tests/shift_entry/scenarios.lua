local function scenario(route,trunkVersion,missing)
 local f={callbacks={},hotkeys={},messages={},begins=0,spawns=0,finishes=0,trunkFinishes=0,request=0}
 local function noop() end
 local player={}
 local function display() return 'fixture' end
 package.loaded.partner={spawn=function(onDuty) assert(onDuty);f.spawns=f.spawns+1 end,update=noop,reset=noop,dismiss=noop,
  state=display,activeProfile=display,vehicleState=display,aidState=display}
 package.loaded.dispatch=setmetatable({init=noop,start=function() f.dispatchStarted=true end,finish=noop,update=noop,reset=noop,setBusy=noop,
  isBusy=function() return false end,isAutomatic=function() return false end,isActive=function() return false end,
  isSoundEnabled=function() return false end,isVoiceEnabled=function() return false end,
  completed=function() return 0 end,failedCount=function() return 0 end},{__index=function() return display end})
 package.loaded.vehicle_radio={reset=noop,finish=noop,update=noop,isEnabled=function() return false end,state=display}
 package.loaded.backup={reset=noop,finish=noop,update=noop,state=display}
 package.loaded.arrest={reset=noop,finish=noop,update=noop,state=display}
 -- The trunk bridge itself is production code; feature controllers are separate
 -- already-tested modules. These boundaries record entry/exit side effects.
 package.loaded.trunk=nil
 local patrol={Version=function() return NativeVersions.NCPDPatrolSystem end,
  BeginShift=function() f.begins=f.begins+1;if not f.wanted then f.onDuty=true end end,
  FinishShift=function() f.onDuty=false;f.finishes=f.finishes+1 end,
  IsOnDuty=function() return f.onDuty==true end,
  HasWantedLevel=function() return f.wanted==true end,WasTerminatedForCrime=function() return false end,
  GetMonitorState=function() return 'monitoring' end,GetShiftJobs=function() return 0 end,GetShiftBonus=function() return 0 end,
  GetMonitorDiagnostics=display,IsDispatchMenuOpen=function() return false end,
  EnforceDutyRules=noop,TakeDutyRequest=function() local r=f.request;f.request=0;return r end,
  GetVoiceDiagnosticRevision=function() return 0 end,TickBonuses=noop}
 local support={Version=function() return NativeVersions.NCPDPatrolSupportSystem end,IsPartnerDownConfigured=function() return true end}
 local nativeTrunk={Version=function() return trunkVersion end,FinishSession=function() f.trunkFinishes=f.trunkFinishes+1 end,
  Tick=noop,IsBusy=function() return false end,TakeCommand=function() return 0 end}
 local container={Get=function(_,name)
  if name=='NCPDPatrolSystem' then return patrol end
  if name=='NCPDPatrolSupportSystem' then return support end
  if name=='NCPDPatrolTrunkSystem' and not missing then return nativeTrunk end
 end}
 Game={GetPlayer=function() return not f.unloaded and player or nil end,GetScriptableSystemsContainer=function() return container end,
  GetVehicleSystem=function() return {EnablePlayerVehicle=noop,IsVehiclePlayerUnlocked=function() return true end} end,
  GetTransactionSystem=function() return {GetItemQuantity=function() return 1 end} end}
 TweakDB={GetRecord=function() return {} end};TweakDBID={new=function(v) return v end};ItemID={CreateQuery=function(v) return v end}
 function registerForEvent(name,fn) f.callbacks[name]=fn end
 function registerHotkey(name,_,fn) f.hotkeys[name]=fn end
 function Observe() end
 function print(value) f.messages[#f.messages+1]=value end
 local pressed=nil
 ImGui={Begin=function() return true end,End=noop,Text=noop,TextWrapped=noop,Separator=noop,
  CollapsingHeader=function() return false end,Button=function(label) return label==pressed end}
 ImGuiCond={FirstUseEver=4}
 ImGui.SetNextWindowSize=noop;ImGui.SetNextWindowSizeConstraints=noop
 ImGui.SameLine=noop;ImGui.Spacing=noop;ImGui.TextColored=noop;ImGui.ProgressBar=noop
 ImGui.GetTextLineHeightWithSpacing=function() return 18 end
 ImGui.BeginChild=function() return true end;ImGui.EndChild=noop
 ImGui.BeginTabBar=function() return true end;ImGui.EndTabBar=noop;ImGui.EndTabItem=noop
 ImGui.BeginTabItem=function(name) return name=="Patrol" end
 dofile(MOD_DIR..'/init.lua');f.callbacks.onInit()
 local function invoke(start)
  if route=='hotkey' then f.hotkeys.ncpdpatrol_toggle_duty()
  elseif route=='terminal' then f.request=start and 1 or 2;f.callbacks.onUpdate(.25)
  else f.callbacks.onOverlayOpen();pressed=start and 'Start Shift' or 'End Shift';f.callbacks.onDraw();pressed=nil end
 end
 invoke(true)
 return f,invoke,nativeTrunk
end
for _,route in ipairs({'hotkey','terminal','cet'}) do
 local f,invoke=scenario(route,NativeVersions.NCPDPatrolTrunkSystem,false)
 assert(f.onDuty and f.begins==1 and f.spawns==1 and f.trunkFinishes==1 and f.dispatchStarted,table.concat(f.messages,'\n'))
 -- CET/native queued Start while already on duty must not create another partner.
 if route~='hotkey' then invoke(true);assert(f.begins==1 and f.spawns==1) end
 invoke(false);assert(not f.onDuty and f.finishes==1)
 invoke(true);assert(f.onDuty and f.begins==2 and f.spawns==2)
end
-- The complete current install is accepted; old or absent native trunk modules
-- fail before BeginShift, dispatch initialization, outfit grants or spawning.
for _,case in ipairs({{3,false},{4,true}}) do
 local f,invoke,nativeTrunk=scenario('hotkey',case[1],case[2])
 assert(not f.onDuty and f.begins==0 and f.spawns==0 and not f.dispatchStarted)
 assert(table.concat(f.messages,'\n'):find('Cannot start shift',1,true))
 if not case[2] then
  nativeTrunk.Version=function() return NativeVersions.NCPDPatrolTrunkSystem end
  invoke(true);assert(f.onDuty and f.begins==1 and f.spawns==1,'failed version check latched duty state')
 end
end
