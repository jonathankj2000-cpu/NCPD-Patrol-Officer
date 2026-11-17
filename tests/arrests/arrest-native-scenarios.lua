local player=supportActor(901,'player',0,0,0)
local a=arrestSuspect(902)
local b=arrestSuspect(903)
supportPlayer=player; wantedHeat=0; pins=list(); Patrol:ResetSession(); ArrestNative:OnAttach()
assert(not ArrestNative:CanStartArrest(a),'off-duty arrest accepted')
Patrol:BeginShift(); assert(ArrestNative:CanStartArrest(a))
local godCount,healCount,roleCount=#godCalls,#healCalls,#roleChanges
for _,flag in ipairs({'dead','persistentDead','civilian','police','companion','quest','boss','friendly'}) do
    a[flag]=true; assert(not ArrestNative:CanStartArrest(a),flag..' target accepted'); a[flag]=false
end
for _,kind in ipairs({'android','drone'}) do a.npcType=kind; assert(not ArrestNative:CanStartArrest(a)) end
a.npcType=nil; a.effects={}; assert(not ArrestNative:CanStartArrest(a),'active enemy accepted')
a.effects['BaseStatusEffect.Unconscious']=true; assert(ArrestNative:CanStartArrest(a),'living unconscious enemy rejected')
a.effects={['BaseStatusEffect.Defeated']=true}
a.vehicle={}; assert(not ArrestNative:CanStartArrest(a)); a.vehicle=nil
wantedHeat=1; assert(not ArrestNative:StartArrest(a)); wantedHeat=0
player.vehicle={}; assert(not ArrestNative:StartArrest(a)); player.vehicle=nil
player.position.x=10; assert(not ArrestNative:StartArrest(a)); player.position.x=0

-- Duplicate events share one reservation and cannot skip two seconds or pay.
assert(ArrestNative:StartArrest(a)); local token=ArrestNative:GetToken()
assert(not ArrestNative:StartArrest(a) and not ArrestNative:StartArrest(b))
local bank=wallet
assert(not ArrestNative:ConfirmArrestPose(a,token) and wallet==bank)
ArrestNative:Tick(20,false)
for _=1,20 do ArrestNative:Tick(0.25,true) end
assert(ArrestNative:GetStage()==1,'hitch/menu advanced securing')
for _=1,7 do ArrestNative:Tick(0.25,false) end
assert(ArrestNative:GetStage()==1 and wallet==bank)
ArrestNative:Tick(0.25,false); assert(ArrestNative:GetStage()==2 and wallet==bank)
assert(not ArrestNative:ConfirmArrestPose(b,token),'another body could confirm this reservation')
assert(not ArrestNative:ConfirmArrestPose(a,token+1),'stale token could confirm')
local scannerJobs,scannerBonus=Patrol:GetShiftJobs(),Patrol:GetShiftBonus()
local scannerPaid=ArraySize(Patrol.m_paidActivities)
local scannerNotices=ArraySize(Patrol.m_pendingNotices)
assert(ArrestNative:ConfirmArrestPose(a,token) and wallet==bank+250)
assert(ArrestNative:GetPaidArrests()==1 and ArrestNative:IsArrested(a))
assert(not ArrestNative:ConfirmArrestPose(a,token) and not ArrestNative:StartArrest(a))
assert(Patrol:GetShiftJobs()==scannerJobs and Patrol:GetShiftBonus()==scannerBonus)
assert(ArraySize(Patrol.m_paidActivities)==scannerPaid and ArraySize(Patrol.m_pendingNotices)==scannerNotices,'arrest changed scanner payment/receipt state')
ArrestNative:Tick(0.25,false)
assert(receiptMessages[#receiptMessages].message=='NCPD ARREST REGISTERED | +EUR$250' and receiptMessages[#receiptMessages].type==SimpleMessageType.Money)

-- Same character record, different entity: its own independent single reward.
assert(ArrestNative:StartArrest(b)); token=ArrestNative:GetToken()
for _=1,8 do ArrestNative:Tick(0.25,false) end
assert(ArrestNative:ConfirmArrestPose(b,token) and ArrestNative:GetPaidArrests()==2 and wallet==bank+500)
Patrol:FinishShift(); Patrol:BeginShift()
assert(not ArrestNative:StartArrest(a),'shift restart erased payment history')
ArrestNative:OnRestored(1,1)
local sameIdentity=arrestSuspect(902)
assert(ArrestNative:IsArrested(sameIdentity) and not ArrestNative:StartArrest(sameIdentity),'load forgot paid body identity')
assert(ArrestNative:GetPaidArrests()==2)

-- Cancel/death/range/wanted/save transitions and failed animation never pay.
local c=arrestSuspect(904); bank=wallet
assert(ArrestNative:StartArrest(c)); token=ArrestNative:GetToken()
player.position.x=20; ArrestNative:Tick(0.25,false); player.position.x=0
assert(ArrestNative:GetStage()==0 and not ArrestNative:ConfirmArrestPose(c,token))
assert(ArrestNative:StartArrest(c)); c.dead=true; ArrestNative:Tick(0.25,false); c.dead=false
assert(ArrestNative:GetStage()==0)
assert(ArrestNative:StartArrest(c)); wantedHeat=1; ArrestNative:Tick(0.25,true); wantedHeat=0
assert(ArrestNative:GetStage()==0,'wanted/menu did not cancel')
assert(ArrestNative:StartArrest(c)); ArrestNative:OnRestored(1,1)
assert(ArrestNative:GetStage()==0)
assert(ArrestNative:StartArrest(c)); token=ArrestNative:GetToken()
for _=1,8 do ArrestNative:Tick(0.25,false) end
ArrestNative:FailPose(token,'No actual lying pose')
assert(not ArrestNative:ConfirmArrestPose(c,token) and wallet==bank)
assert(ArrestNative:StartArrest(c)); token=ArrestNative:GetToken()
for _=1,60 do ArrestNative:Tick(0.25,false) end
assert(ArrestNative:GetStage()==0 and wallet==bank,'timeout paid an unconfirmed animation')
assert(ArrestNative:StartArrest(c)); token=ArrestNative:GetToken()
for _=1,8 do ArrestNative:Tick(0.25,false) end
arrestPaymentOK=false
assert(not ArrestNative:ConfirmArrestPose(c,token) and wallet==bank and not ArrestNative:IsArrested(c))
arrestPaymentOK=true
assert(#godCalls==godCount and #healCalls==healCount and #roleChanges==roleCount and #reviveEvents==0,'arrest healed/resurrected or rebound an ambient NPC')

-- Scanner bonus still earns and counts only scanner completions, alongside an
-- arrest payment. Neither ledger can suppress or inflate the other one.
Patrol:FinishShift(); pins=list(marker(909,2,'assault')); Patrol:BeginShift(); bank=wallet
assert(ArrestNative:StartArrest(c)); token=ArrestNative:GetToken()
for _=1,8 do ArrestNative:Tick(0.25,false) end
assert(ArrestNative:ConfirmArrestPose(c,token) and wallet==bank+250)
assert(Patrol:GetShiftJobs()==0 and Patrol:GetShiftBonus()==0)
pins[0].phase=0; Patrol:TickBonuses()
assert(wallet==bank+1250 and Patrol:GetShiftJobs()==1 and Patrol:GetShiftBonus()==1000)
assert(ArrestNative:GetPaidArrests()==3)
Patrol:FinishShift(); supportPlayer=nil
