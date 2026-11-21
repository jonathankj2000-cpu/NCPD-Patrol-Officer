-- Native/UI boundaries only. Both the pinned old entrypoint and current
-- entrypoint/menu run unchanged against this same action recorder.
UIFixture={events={},frames={},selectedTab='Patrol',pressed=nil,openHeaders=true,
    windowVisible=true,tabBarVisible=true,contentVisible=true,footerVisible=true,
    loaded=true,nativeAvailable=true,testUnlocks=false,busy=false,automatic=false,
    sound=false,voice=false,chatter=false,lineHeight=18,progress=30,onDuty=false}
local f=UIFixture
local function repr(value)
    if type(value)=='function' then return '<callback>' end
    if type(value)=='table' then return value.fixtureName or '<table>' end
    return tostring(value)
end
local function record(name,...)
    local fields={name}
    for i=1,select('#',...) do fields[#fields+1]=repr(select(i,...)) end
    f.events[#f.events+1]=table.concat(fields,'|')
end
local function noop() end
local function display() return 'fixture' end
local function no() return false end
local function zero() return 0 end
local function command(name)
    return function(...) record(name,...);return true end
end
local partner={state=display,activeProfile=display,vehicleState=display,aidState=display,
    diagnostics=display,healthDiagnostics=display,readinessDiagnostics=display}
function partner.state()
    if f.failPartnerRead then error('fixture partner display unavailable') end
    return 'fixture'
end
for _,name in ipairs({'spawn','replace','dismiss','reset','update'}) do partner[name]=command('partner.'..name) end
local dispatch={state=display,isBusy=function() return f.busy end,isAutomatic=function() return f.automatic end,
    isSoundEnabled=function() return f.sound end,isVoiceEnabled=function() return f.voice end,
    isActive=no,completed=zero,failedCount=zero,seconds=zero,vipAmbushCars=display,
    mixDescription=display,vipState=display,vipDiagnostics=display,cyberpsychoState=display,
    cyberpsychoDiagnostics=display,cyberpsychoVariantState=display,vipAmbushState=display,
    rewardDiagnostics=display,schedulerStatus=display,schedulerDiagnostics=display,
    navigationState=display,lastOutcome=display,journalDiagnostics=display,hudState=display}
for _,name in ipairs({'requestMixed','request','requestCyberpsycho','requestVIP','requestVIPAmbush',
    'cycleCyberpsychoVariant','randomCyberpsychoVariants','cycleVIPAmbushCars','cancel',
    'refreshVIPWaypoint','armTimeoutTest','testAudio','init','start','finish','reset','update','shutdown'}) do
    dispatch[name]=command('dispatch.'..name)
end
function dispatch.setAutomatic(value,status) record('dispatch.setAutomatic',value,status);f.automatic=value end
function dispatch.setSoundEnabled(value,status) record('dispatch.setSoundEnabled',value,status);f.sound=value end
function dispatch.setVoiceEnabled(value,status) record('dispatch.setVoiceEnabled',value,status);f.voice=value end
local radio={state=display,isEnabled=function() return f.chatter end}
function radio.setEnabled(value,patrol,status) record('radio.setEnabled',value,patrol,status);f.chatter=value end
for _,name in ipairs({'reset','finish','update'}) do radio[name]=command('radio.'..name) end
local backup={state=display,diagnostics=display}
for _,name in ipairs({'release','reset','finish','update'}) do backup[name]=command('backup.'..name) end
local arrest={state=display}
for _,name in ipairs({'reset','finish','update'}) do arrest[name]=command('arrest.'..name) end
local trunk={repairSeconds=function() return f.repair or 0 end}
for _,name in ipairs({'prepareShift','finish','reset','update','showStats'}) do trunk[name]=command('trunk.'..name) end
function trunk.setBusy(value,status) record('trunk.setBusy',value,status);f.busy=value end
for name,value in pairs({partner=partner,dispatch=dispatch,vehicle_radio=radio,backup=backup,arrest=arrest,trunk=trunk}) do package.loaded[name]=value end
package.loaded.quest_marker_probe={state=display,startVisual=command('probe.visual'),relocate=command('probe.relocate'),mode=function() return 'default' end,
    diagnostics=display,reset=noop,update=noop,finish=noop,
    start=command('probe.start'),cycleMode=command('probe.cycleMode')}
package.loaded.scene_survey={configure=noop,blocksDuty=function() return f.surveyReserved==true end,summary=display,diagnostics=display,active=no,
    update=noop,reset=noop,shutdown=noop,start=command('survey.start'),cancel=command('survey.cancel'),recover=command('survey.recover'),
    loadResults=command('survey.loadResults'),export=command('survey.export'),startPilot=command('survey.startPilot'),startPlacementPilot=command('survey.startPlacementPilot')}

local patrol={fixtureName='patrol',Version=function() return 17 end,
    IsOnDuty=function() return f.onDuty end,HasWantedLevel=no,WasTerminatedForCrime=no,
    GetMonitorState=display,GetShiftJobs=zero,GetShiftBonus=zero,GetMonitorDiagnostics=display,
    GetLastBonusAmount=zero,GetVoiceDiagnostics=display,GetVoiceDiagnosticRevision=zero,
    TakeDutyRequest=zero,IsDispatchMenuOpen=no}
function patrol:BeginShift() record('patrol.BeginShift');f.onDuty=true end
function patrol:FinishShift() record('patrol.FinishShift');f.onDuty=false end
for _,name in ipairs({'TickBonuses','ResetSession','EnforceDutyRules'}) do patrol[name]=function() record('patrol.'..name) end end
local support={fixtureName='support',Version=function() return 17 end,IsPartnerDownConfigured=function() return true end}
for _,name in ipairs({'RequestBackup','DownPartner','StartPartnerRevive'}) do support[name]=function() record('support.'..name);return true end end
local partnerNames={'Standard NCPD Patrol Officer','NCPD Shotgun Enforcer','NCPD Tactical Officer','MaxTac Netrunner'}
local career={Version=function() return f.careerVersion or 3 end,GetLastStatus=display,
    GetSelectedPartnerName=display,PartnerCount=function() return #partnerNames end,
    PartnerName=function(_,index) return partnerNames[index+1] end,
    IsPartnerUnlocked=function(_,index) return index==0 end,
    IsTestUnlockActive=function() return f.testUnlocks end,GetRank=function() return 'Officer' end,
    GetRecordedActivities=function() return 3 end,GetNextMilestone=function() return f.maxRank and 0 or 5 end,
    GetNextReward=display,GetProgressPercent=function() return f.progress end,GetAvailableRewards=zero}
function career:SetTestUnlocks(value) record('career.SetTestUnlocks',value);f.testUnlocks=value;return true end
for _,name in ipairs({'ClaimNextReward','SelectPartner','TestGiveTieredWeapons','TestGiveBeanBagger'}) do
    career[name]=function(_,...) record('career.'..name,...);return true end
end
local browser={Version=function() return 1 end,GetDiagnostics=display,OpenCareer=function() record('browser.OpenCareer');return true end}
local bean={Version=function() return 1 end,GetDiagnostics=display}
local container={Get=function(_,name)
    if not f.nativeAvailable then return nil end
    if name=='NCPDPatrolSystem' then return patrol end
    if name=='NCPDPatrolSupportSystem' then return support end
    if name=='NCPDPatrolCareerSystem' then return career end
    if name=='NCPDPatrol.Career.NCPDPatrolCareerBrowserState' and not f.noBrowser then return browser end
    if name=='NCPDPatrolBeanBaggerSystem' then return bean end
end}
local vehicle={EnablePlayerVehicle=function(_,id,a,b) record('vehicle.EnablePlayerVehicle',id,a,b) end,IsVehiclePlayerUnlocked=function() return true end}
Game={GetPlayer=function() return f.loaded and {} or nil end,GetScriptableSystemsContainer=function() return container end,
    GetVehicleSystem=function() return vehicle end,GetTransactionSystem=function() return {GetItemQuantity=function() return 1 end} end,
    AddToInventory=command('Game.AddToInventory')}
TweakDB={GetRecord=function() return {} end};TweakDBID={new=function(v) return v end};ItemID={CreateQuery=function(v) return v end}
f.callbacks={};f.hotkeys={}
function registerForEvent(name,fn) assert(not f.callbacks[name],'duplicate event registration');f.callbacks[name]=fn end
function registerHotkey(name,_,fn) assert(not f.hotkeys[name],'duplicate hotkey');f.hotkeys[name]=fn end
function Observe(...) record('Observe',...) end
function print(message)
    if not tostring(message):find('loaded.',1,true) then record('print',message) end
end

-- Match CET's Begin/End obligations, not an always-open synthetic tab bar.
local stack={}
local function push(kind,label) stack[#stack+1]={kind=kind,label=label} end
local function pop(kind) assert(stack[#stack] and stack[#stack].kind==kind,'unbalanced ImGui '..kind);table.remove(stack) end
local function where(kind)
    for index=#stack,1,-1 do if stack[index].kind==kind then return stack[index].label end end
end
local function widget(kind,label)
    assert(where('window'),'widget outside window')
    f.frame[#f.frame+1]={kind=kind,label=label,tab=where('tab'),child=where('child')}
end
ImGuiCond={FirstUseEver=4}
ImGui={
    SetNextWindowSize=function(x,y,condition) assert(x==660 and y==620 and condition==4) end,
    SetNextWindowSizeConstraints=function(minX,minY,maxX,maxY) assert(minX==520 and minY==360 and maxX>=minX and maxY>=minY) end,
    Begin=function(label) push('window',label);return f.windowVisible end,
    End=function() pop('window') end,
    BeginTabBar=function(label) if f.tabBarVisible then push('bar',label) end;return f.tabBarVisible end,
    EndTabBar=function() pop('bar') end,
    BeginTabItem=function(...)
        assert(select('#',...)==1,'use CET single-result tab overload')
        local label=...
        if label==f.selectedTab then push('tab',label);return true end
        return false
    end,
    EndTabItem=function() pop('tab') end,
    GetTextLineHeightWithSpacing=function() return f.lineHeight end,
    BeginChild=function(label,width,height,border)
        assert(width==0 and border==false)
        local footer=label=='NCPDPatrolLastStatus'
        assert(height==(footer and 0 or -(f.lineHeight*3+12)),'footer does not scale with font')
        push('child',label)
        return footer and f.footerVisible or not footer and f.contentVisible
    end,
    EndChild=function() pop('child') end,
    Button=function(label)
        widget('button',label)
        if label==f.pressed then f.clicks=f.clicks+1;return true end
        return false
    end,
    Text=function(label) widget('text',label) end,
    TextWrapped=function(label) widget('text',label) end,
    TextColored=function(r,g,b,a,label) widget('text',label) end,
    Separator=noop,Spacing=noop,SameLine=noop,
    CollapsingHeader=function(label) widget('header',label);return f.openHeaders end,
    ProgressBar=function(fraction,width,height,overlay)
        assert(fraction>=0 and fraction<=1 and width==-1 and height==0)
        widget('progress',overlay);f.progressValue=fraction
    end,
}
function f:Frame(tab,pressed)
    assert(#stack==0)
    self.selectedTab=tab or self.selectedTab;self.pressed=pressed;self.frame={};self.clicks=0
    self.callbacks.onDraw()
    self.pressed=nil;assert(#stack==0,'ImGui frame leaked stack state')
    self.frames[#self.frames+1]=self.frame
    return self.frame
end
function f:ClearEvents() self.events={} end
function f:Events() return table.concat(self.events,'\n') end
