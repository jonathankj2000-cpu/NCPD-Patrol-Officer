from pathlib import Path
import re,sys,tempfile
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
sys.path.insert(0,str(HERE))
from lupa.luajit21 import LuaRuntime
from translate import translate
source=Path(ROOT/'r6/scripts/NCPDPatrol/NCPDPatrolArrestInteractions.reds').read_text()
methods=[]
for name in ['GetValidChoices','OnInteractionUsed','OnInteraction','UpdateLootInteraction']:
    m=re.search(r'(?:public|protected)\s+(?:(?:cb|final|const)\s+)*func\s+'+name+r'\(',source)
    assert m,name
    start=m.start(); body=source.index('{',m.end());depth=1;end=body+1
    while depth:
        depth+=(source[end]=='{')-(source[end]=='}');end+=1
    methods.append(source[start:end].replace('protected cb func','public func').replace('protected final func','public func'))
scratch=tempfile.TemporaryDirectory(prefix='ncpd-arrest-tests-')
path=Path(scratch.name)/'arrest-interaction-wrappers.reds'
path.write_text('public class WrapperFixture extends IScriptable {\n'+'\n'.join(methods)+'\n}')
translated=translate(path).replace('local choice = nil','local choice = {choiceMetaData={type={}},captionParts={}}')
scratch.cleanup()
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute(Path(HERE/'mappin-native-mocks.lua').read_text())
lua.globals().Patrol=lua.execute(translate(ROOT/'r6/scripts/NCPDPatrol/NCPDPatrolSystem.reds'))
lua.execute('function Patrol:GetGameInstance() return {} end')
lua.execute(Path(HERE/'support-native-mocks.lua').read_text())
lua.execute(Path(HERE/'arrest-native-mocks.lua').read_text())
lua.globals().ArrestNative=lua.execute(translate(ROOT/'r6/scripts/NCPDPatrol/NCPDPatrolArrestSystem.reds'))
lua.execute('function ArrestNative:GetGameInstance() return {} end; ArrestNative:OnAttach()')
lua.globals().Wrappers=lua.execute(translated)
lua.execute('''
function Deref(a) return a end
gamedeviceRequestType={Direct=1,Remote=2}
GetLocalizedTextByKey=function(key) return key end
InteractionChoiceCaption={AddTextPart=function(self,parts,text) parts.text=text end}
gameinteractionsChoiceType={Inactive='inactive'}
ChoiceTypeWrapper={SetType=function(self,flags,value) flags.value=value end}
local wrapped=0
function ArrayInsert(a,index,value)
    for i=a.n,index+1,-1 do a[i]=a[i-1] end
    a[index]=value;a.n=a.n+1
end
local vanillaChoices={
 {caption='Loot',choiceMetaData={tweakDBName='Loot',tweakDBID='Interactions.Loot'}},
 {caption='Pick up body',choiceMetaData={tweakDBName='PickUpBody',tweakDBID='Interactions.PickUpBody'}},
 {caption='Other secondary',choiceMetaData={tweakDBName='OtherSecondary',tweakDBID='Interactions.OtherSecondary'}}}
function wrappedMethod(actions,context,callback,check,choices)
    wrapped=wrapped+1
    if choices then
        ArrayClear(choices)
        for _,choice in ipairs(vanillaChoices) do ArrayPush(choices,choice) end
    end
    return false
end
local suspect=arrestSuspect(1102)
local dead=arrestSuspect(1103);dead.dead=true
local partner=arrestSuspect(1104);partner.police=true;partner.companion=true
local quest=arrestSuspect(1105);quest.quest=true
supportPlayer=supportActor(1101,'player',0,0,0)
wantedHeat=0;pins=list();Patrol:ResetSession();Patrol:BeginShift()
local ps={GetGameInstance=function() return {} end,GetOwnerEntity=function() return suspect end}
local ctx={requestType=1,interactionLayerTag='Loot'}
local choices=list()
Wrappers.GetValidChoices(ps,list(),ctx,nil,false,choices)
assert(wrapped==1 and choices.n==3 and choices[0].choiceMetaData.tweakDBID=='Interactions.NCPDPatrolArrest')
assert(choices[1]==vanillaChoices[2] and choices[2]==vanillaChoices[3],'native R pickup/secondary choice data was lost')
local pickup={choice=vanillaChoices[2]}
local before=wrapped
assert(not Wrappers.OnInteractionUsed(suspect,pickup) and wrapped==before+1 and ArrestNative:GetStage()==0,'R pickup before arrest did not reach vanilla')
suspect.carried=true
assert(not ArrestNative:CanStartArrest(suspect) and not ArrestNative:StartArrest(suspect),'carried body could start arrest/recovery')
suspect.carried=false
local enabled
function suspect:EnableInteraction(layer,value) enabled={layer=layer,value=value} end
Wrappers.UpdateLootInteraction(suspect)
assert(wrapped==before+1 and enabled.layer=='Loot' and enabled.value==true,'empty inventory blocked the primary arrest action')
for _,npc in ipairs({dead,partner,quest}) do
    local before=wrapped;ps.GetOwnerEntity=function() return npc end
    Wrappers.GetValidChoices(ps,list(),ctx,nil,false,choices)
    assert(wrapped==before+1,'protected/dead NPC interaction was replaced')
end
ps.GetOwnerEntity=function() return suspect end
local before=wrapped;ctx.requestType=2
Wrappers.GetValidChoices(ps,list(),ctx,nil,false,choices);assert(wrapped==before+1)
ctx.requestType=1;ctx.interactionLayerTag='Grapple';before=wrapped
Wrappers.GetValidChoices(ps,list(),ctx,nil,false,choices);assert(wrapped==before+1)
ctx.interactionLayerTag='Loot'
local event={choice={choiceMetaData={tweakDBName='NCPDPatrolArrest'}}}
assert(Wrappers.OnInteractionUsed(suspect,event) and ArrestNative:GetStage()==1)
ArrestNative:Tick(0.25,false);local elapsed=ArrestNative.m_elapsed
assert(Wrappers.OnInteraction(suspect,event) and ArrestNative.m_elapsed==elapsed,'duplicate event restarted treatment')
choices=list();Wrappers.GetValidChoices(ps,list(),ctx,nil,false,choices)
assert(choices.n==1 and choices[0].choiceMetaData.tweakDBID=='Interactions.NCPDPatrolArresting' and choices[0].choiceMetaData.type.value=='inactive')
before=wrapped
assert(Wrappers.OnInteractionUsed(suspect,pickup) and wrapped==before,'pending body could be carried away through a stale choice')
for _=1,7 do ArrestNative:Tick(0.25,false) end
assert(ArrestNative:ConfirmArrestPose(suspect,ArrestNative:GetToken()))
before=wrapped;Wrappers.GetValidChoices(ps,list(),ctx,nil,false,choices)
assert(wrapped==before+1,'registered body did not regain ordinary body/loot choices')
before=wrapped;Wrappers.UpdateLootInteraction(suspect);assert(wrapped==before+1)
local failed=arrestSuspect(1106);ps.GetOwnerEntity=function() return failed end
assert(ArrestNative:StartArrest(failed))
for _=1,8 do ArrestNative:Tick(0.25,false) end
ArrestNative:FailPose(ArrestNative:GetToken(),'Unsupported ground')
Wrappers.GetValidChoices(ps,list(),ctx,nil,false,choices)
assert(choices.n==3 and choices[1]==vanillaChoices[2],'failed arrest did not restore native R pickup')
before=wrapped
assert(not Wrappers.OnInteraction(failed,pickup) and wrapped==before+1 and ArrestNative:GetStage()==0)
Patrol:FinishShift();before=wrapped
ps.GetOwnerEntity=function() return quest end
Wrappers.GetValidChoices(ps,list(),ctx,nil,false,choices)
assert(wrapped==before+1,'off-duty interaction changed')
''')
config=Path(ROOT/'r6/tweaks/NCPDPatrol_Arrest.yaml').read_text()
assert config.count('$base: Interactions.Loot')==2 and config.count('action: Choice1')==2
print('PASS: authored arrest body wrappers: replace only Loot/F, preserve native R pickup/secondary data before arrest and after failure, empty inventory, duplicate callbacks, pending pickup guard, protected/dead/remote/other-layer fallthrough, normal loot after payment/off duty (game APIs mocked)')
