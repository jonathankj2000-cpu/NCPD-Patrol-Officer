-- Original ReadAction body comes from the pinned game sources. Item transfer,
-- event ordering/mutation and journal acknowledgement are engine boundaries.
local f=F
f.obOriginalReads=0;f.obReadUI={};f.obReadSuper=0
function NewReferenceShardRead() return {} end
function ReferenceItemActionComplete() f.obReadSuper=f.obReadSuper+1 end
function IsStringValid(value) return type(value)=='string' and value~='' end
local entries={f.obpath,'onscreens/foreign/readable'}
for _,path in ipairs(entries) do
 f.entries[path]=f.entries[path] or {path=path,kind='gameJournalOnscreen',state=1}
 local entry=f.entries[path]
 function entry:GetTitle() return 'Native readable title' end
 function entry:GetDescription() return 'Native readable content' end
 function entry:GetIconID() return 0 end
end
GameInstance.GetUISystem=function() return {QueueEvent=function(_,evt) f.obReadUI[#f.obReadUI+1]=evt end} end
function OriginalOTBRead(self,game)
 f.obOriginalReads=f.obOriginalReads+1
 GameReference.ReadAction.CompleteAction(self,game)
end
function f.obRead(item,player)
 item=item or f.obitem;player=player or f.player
 local action={GetItemData=function() return {GetID=function() return item end} end,
  GetExecutor=function() return player end,
  GetJournalEntryFromAction=function() return item==f.obitem and f.obpath or 'onscreens/foreign/readable' end}
 -- Ordinary native in-world Read removes the item; this is not used as proof
 -- by the production code. Native CompleteAction records the readable entry.
 if item==f.obitem then
  local body=f.obRole('target');if body then f.obInventory[body:GetEntityID().hash][item]=0 end
 end
 ReadObserver.CompleteAction(action,{})
end
