-- Native contracts only. Reward decisions execute the authored redscript class.
wallet,notifications,paymentOK,playerPresent,transactionPresent=0,{},true,true,true
NCPDPatrolIncidentSystem={Get=function() return nil end}
pins,savedPhases,mappinPresent={n=0},{},true
inMenu=false
registered,removed,nextWaypointID={}, {}, 10000
registrationOK=true
function ArraySize(a) return a.n end
function ArrayPush(a,v) a[a.n]=v; a.n=a.n+1 end
function ArrayClear(a) for i=0,a.n-1 do a[i]=nil end; a.n=0 end
function ArrayErase(a,index)
    for i=index,a.n-2 do a[i]=a[i+1] end
    a[a.n-1]=nil; a.n=a.n-1
end
function ArrayFindFirst(a,v) for i=0,a.n-1 do if a[i]==v then return i end end; return -1 end
function ArrayContains(a,v) return ArrayFindFirst(a,v)>=0 end
function Equals(a,b) if type(a)=='table' and type(b)=='table' and a.value~=nil and b.value~=nil then return a.value==b.value end; return a==b end
function NotEquals(a,b) return not Equals(a,b) end
function ToString(a) return tostring(a) end
function StrContains(a,b) return a:find(b,1,true)~=nil end
function IsDefined(a) return a~=nil end
function ToVariant(a) return a end
function StringToName(a) return a end
function Cast(a) return a end
function IntEnum(a) return a end
function GetPlayer() if playerPresent then return {} end end
function AsPointOfInterest(pin) if pin.poi then return pin end end
function AsDispatchMappinData(data) if data and data.ncpdDispatch then return data end end
function NewDispatchMappinData() return {ncpdDispatch=true} end
function NewPatrolNotice() return {} end
gamedataMappinPhase={CompletedPhase=0,DefaultPhase=1,DiscoveredPhase=2,UndiscoveredPhase=3,Invalid=5}
gamedataMappinVariant={GangWatchVariant='assault',OutpostVariant='organized',Other='gig',CustomPositionVariant='custom'}
ItemID={FromTDBID=function(self,id) return id end}
TDBID={Create=function(self,name) return name end}
local system={GetAllMappins=function()
    local copy={n=pins.n}; for i=0,pins.n-1 do
        if not pins[i].GetScriptData then pins[i].GetScriptData=function() return nil end end
        if not pins[i].GetNewMappinID then pins[i].GetNewMappinID=function() return {value=-1} end end
        copy[i]=pins[i]
    end; return copy
end,
    GetPointOfInterestMappinSavedState=function(self,hash)
        local phase=savedPhases[hash]
        return phase~=nil,phase or 0,0,false
    end,
    RegisterMappin=function(self,data,position)
        if not registrationOK then return {value=0} end
        nextWaypointID=nextWaypointID+1
        local id={value=nextWaypointID}
        local pin={poi=false,data=data,position=position,tracked=false,
            IsPlayerTracked=function(self) return self.tracked end,
            GetScriptData=function(self) return self.data.scriptData end,
            GetNewMappinID=function() return id end}
        ArrayPush(pins,pin)
        registered[#registered+1]={id=id,data=data,position=position,pin=pin}
        return id
    end,
    SetMappinPosition=function(self,id,position)
        mapRefreshCalls[#mapRefreshCalls+1]={id=id,position=position}
    end,
    SetMappinActive=function(self,id,active)
        mapActiveCalls[#mapActiveCalls+1]={id=id,active=active}
    end,
    UnregisterMappin=function(self,id)
        removed[#removed+1]=id
        local keep={n=0}
        for i=0,pins.n-1 do
            local pin=pins[i]
            if not pin.GetNewMappinID or pin:GetNewMappinID().value~=id.value then ArrayPush(keep,pin) end
        end
        pins=keep
    end}
local transaction={GiveItem=function(self,player,item,amount)
    assert(item=='Items.money' and amount==1000)
    if paymentOK then wallet=wallet+amount; return true end
    return false
end}
GameInstance={
    GetScriptableSystemsContainer=function() return {Get=function(self,key)
        if key=='PreventionSystem' then return {GetHeatStage=function() return wantedHeat end} end
        if key=='NCPDPatrolSystem' then return Patrol end
    end} end,
    GetOpenWorldSystem=function() error('must not depend on the quest phase registry') end,
    GetMappinSystem=function() if mappinPresent then return system end end,
    GetTransactionSystem=function() if transactionPresent then return transaction end end}
function GetAllBlackboardDefs() return {UI_Notifications={WarningMessage='WarningMessage'},UI_System={IsInMenu='IsInMenu',TrackedMappin='TrackedMappin'}} end
function list(...)
    local out={n=select('#',...)}
    for i=1,out.n do out[i-1]=select(i,...) end
    return out
end
function marker(hash,phase,variant)
    return {poi=true,hash=hash,phase=phase or 2,variant=variant or 'assault',enabled=true,position={x=500,y=500,z=30,w=1},
        GetJournalPathHash=function(self) return self.hash end,
        GetPhase=function(self) return self.phase end,
        GetVariant=function(self) return self.variant end,
        IsActive=function(self) return self.enabled end,
        GetScriptData=function() return nil end,
        GetNewMappinID=function() return {value=hash+100000} end,
        GetWorldPosition=function(self) return self.position end}
end
SimpleMessageType={Neutral=2,Money=6}
receiptClock=0
local queued={}
audioEvents,radioRequests,noticeTimeline={},{},{}
radioPresent=true
radioAborts,radioRecent=0,{n=3,[0]='None',[1]='None',[2]='None'}
radioSendTimeline,radioAbortTimeline={},{}
radioSystemMock={isHeat1LineRequestOngoing=false}
EPreventionHeatStage={Heat_0=0,Heat_1=1,Heat_2=2,Heat_3=3,Heat_4=4,Heat_5=5}
wantedHeat=0
vehicleAudioEvents,mapRefreshCalls,mapActiveCalls,trackingSignals,uiRefreshSignals={},{},{},{},{}
audioSystemPresent=true
local audioSystem={Play=function(self,event,id)
    assert(event=='radio_car_police_npc' and id.hash~=1,'chatter used the player emitter')
    vehicleAudioEvents[#vehicleAudioEvents+1]={op='play',event=event,id=id}
end,Stop=function(self,event,id)
    assert(event=='radio_car_police_npc' and id.hash~=1)
    vehicleAudioEvents[#vehicleAudioEvents+1]={op='stop',event=event,id=id}
end}
GameInstance.GetAudioSystem=function() if audioSystemPresent then return audioSystem end end
GameObject={PlaySoundEvent=function(self,player,event)
    assert(player and event=='ui_phone_sms')
    audioEvents[#audioEvents+1]={event=event,time=receiptClock}
end}
radioSystemMock.PoliceRadioRequest=function(self,entry)
        assert(entry=='nc_heat_1_start'); radioRequests[#radioRequests+1]=entry
        radioSendTimeline[#radioSendTimeline+1]={time=receiptClock,flag=self.isHeat1LineRequestOngoing,entry=entry}
        radioRecent[2],radioRecent[1],radioRecent[0]=radioRecent[1],radioRecent[0],entry
end
radioSystemMock.GetRecentRequests=function() return radioRecent end
radioSystemMock.AbortCurrentRadioLine=function()
    assert(wantedHeat==0); radioAborts=radioAborts+1
    radioAbortTimeline[#radioAbortTimeline+1]=receiptClock
end
GameInstance.GetPoliceRadioSystem=function()
    if radioPresent then return radioSystemMock end
end
receiptMessages={}; delayPresent=true
local delay={DelayCallback=function(self,callback,seconds,dilation)
    assert((seconds==0.5 or seconds==1 or seconds==2 or seconds==4 or seconds==8 or seconds==12) and dilation==false)
    queued[#queued+1]={callback=callback,due=receiptClock+seconds}
    return {}
end}
NCPDPatrolNoticeFinished={Create=function(self,system,session,token)
    return {system=system,session=session,token=token,Call=function(c) c.system:FinishNotice(c.session,c.token) end}
end}
NCPDPatrolVoiceWindow={Create=function(self,system,session,token)
    return {system=system,session=session,token=token,Call=function(c) c.system:EndDispatchVoiceWindow(c.session,c.token) end}
end}
NCPDPatrolRadioStep={Create=function(self,system,session,token,step)
    return {system=system,session=session,token=token,step=step,Call=function(c)
        c.system:AdvanceRadioStep(c.session,c.token,c.step)
    end}
end}
GameInstance.GetDelaySystem=function() if delayPresent then return delay end end
NCPDPatrolBonusReceipt={Create=function(self,system,amount,session)
    return {system=system,amount=amount,session=session,Call=function(c)
        c.system:ShowBonusReceipt(c.amount,c.session)
    end}
end}
local receiptBB={SignalVariant=function(self,id) assert(id=='TrackedMappin'); uiRefreshSignals[#uiRefreshSignals+1]=id end,
SignalBool=function(self,id) assert(id=='IsInMenu'); uiRefreshSignals[#uiRefreshSignals+1]={id=id,current=inMenu} end,
GetBool=function(self,id) assert(id=='IsInMenu'); return inMenu end,SetVariant=function(self,id,message,signal)
    if id=='TrackedMappin' then trackingSignals[#trackingSignals+1]=message; return true end
    assert(id=='WarningMessage' and signal==true)
    notifications[#notifications+1]=message.message
    receiptMessages[#receiptMessages+1]=message
    noticeTimeline[#noticeTimeline+1]={time=receiptClock,message=message}
end}
GameInstance.GetBlackboardSystem=function() return {Get=function() return receiptBB end} end
function advanceReceipts(seconds)
    local target=receiptClock+seconds
    while true do
        local index,due=nil,math.huge
        for i,event in ipairs(queued) do
            if event.due<=target and event.due<due then index,due=i,event.due end
        end
        if not index then break end
        receiptClock=due
        local event=table.remove(queued,index)
        event.callback:Call()
    end
    receiptClock=target
end
