from pathlib import Path
import tempfile
import re,sys
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
scratch=tempfile.TemporaryDirectory()
path=Path(scratch.name)/'arrest-interaction-wrappers.reds'
path.write_text('public class WrapperFixture extends IScriptable {\n'+'\n'.join(methods)+'\n}')
translated=translate(path).replace('local choice = nil','local choice = {choiceMetaData={type={}},captionParts={}}')
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
function wrappedMethod(...) wrapped=wrapped+1;return false end
local suspect=arrestSuspect(1102)
local dead=arrestSuspect(1103);dead.dead=true
local partner=arrestSuspect(1104);partner.police=true;partner.companion=true
local quest=arrestSuspect(1105);quest.quest=true
supportPlayer=supportActor(1101,'player',0,0,0)
wantedHeat=0;pins=list();Patrol:ResetSession();Patrol:BeginShift()
local ps={GetGameInstance=function() return {} end,GetOwnerEntity=function() return suspect end}
local ctx={requestType=1,interactionLayerTag='Loot'}
local choices=list({caption='vanilla pickup'})
Wrappers.GetValidChoices(ps,list(),ctx,nil,false,choices)
assert(wrapped==0 and choices.n==1 and choices[0].choiceMetaData.tweakDBID=='Interactions.NCPDPatrolArrest')
local enabled
function suspect:EnableInteraction(layer,value) enabled={layer=layer,value=value} end
Wrappers.UpdateLootInteraction(suspect)
assert(wrapped==0 and enabled.layer=='Loot' and enabled.value==true,'empty inventory blocked the primary arrest action')
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
local pickup={choice={choiceMetaData={tweakDBName='PickUpBody'}}}
assert(Wrappers.OnInteractionUsed(suspect,pickup) and wrapped==before,'pending body could be carried away through a stale choice')
for _=1,7 do ArrestNative:Tick(0.25,false) end
assert(ArrestNative:ConfirmArrestPose(suspect,ArrestNative:GetToken()))
before=wrapped;Wrappers.GetValidChoices(ps,list(),ctx,nil,false,choices)
assert(wrapped==before+1,'registered body did not regain ordinary body/loot choices')
before=wrapped;Wrappers.UpdateLootInteraction(suspect);assert(wrapped==before+1)
Patrol:FinishShift();before=wrapped
ps.GetOwnerEntity=function() return quest end
Wrappers.GetValidChoices(ps,list(),ctx,nil,false,choices)
assert(wrapped==before+1,'off-duty interaction changed')
''')
config=Path(ROOT/'r6/tweaks/NCPDPatrol_Arrest.yaml').read_text()
assert config.count('$base: Interactions.Loot')==2 and config.count('action: Choice1')==2
print('PASS: authored arrest body wrappers: primary Loot/F inheritance, empty inventory, duplicate callbacks, pending caption and pickup guard, protected/dead/remote/other-layer fallthrough, normal loot after payment and off duty (game APIs mocked)')
