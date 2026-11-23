-- Native ProcessLoot internals are opaque. Opt-in scenarios model the reported
-- live-item removal, generated corpse loot, deferred generation and refusal;
-- the production code, TweakXL declarations, receipts and loot UI predicates
-- remain real. This is not a claim that REDengine regeneration is emulated.
local f=F;local spec=OTBDeathLoot
f.obNativeProcessCalls=0;f.obNativeGeneratedItems=0;f.obRemovedEvidence=0
ItemID.CreateQuery=function(_,id) return {query=id} end
local tx=GameInstance:GetTransactionSystem({});local quantity=tx.GetItemQuantity
function tx:GetItemQuantity(object,item)
 if type(item)=='table' and item.query then return quantity(self,object,item.query) end
 if f.obExactInstanceMiss and object~=f.player and item==f.obitem then return 0 end
 return quantity(self,object,item)
end
function tx:RemoveItemByTDBID(object,item,amount,multiple)
 assert(object~=f.player and object:GetRecordID()=='Character.NCPDPatrol_VossContractor01' and item==f.obitem and multiple)
 if f.obRemoveFailed then return false end
 local items=f.obInventory[object:GetEntityID().hash] or {};local count=items[item] or 0
 local removed=math.min(count,amount);items[item]=count-removed;f.obRemovedEvidence=f.obRemovedEvidence+removed
 return removed==amount
end
local getItem=TweakDBInterface.GetItemRecord
function TweakDBInterface:GetItemRecord(id)
 local record=getItem(self,id);if record then function record:GetID() return self.id end end;return record
end
local getActor=TweakDBInterface.GetCharacterRecord
function TweakDBInterface:GetCharacterRecord(id)
 local record=getActor(self,id)
 if record and id=='Character.NCPDPatrol_VossContractor01' then
  function record:LootDrop()
   if f.obMissingDeathLoot then return nil end
   return {
    GetID=function() return f.obWrongDeathLoot and 'LootTables.Empty' or spec.tableID end,
    GetLootItemsCount=function() return f.obWrongDeathCount and 0 or #spec.table.lootItems end,
    MinItemsToLoot=function() return spec.table.minItemsToLoot end,
    MaxItemsToLoot=function() return spec.table.maxItemsToLoot end,
    GetLootItemsItem=function(_,index)
     assert(index==0)
     return {ItemID=function() return TweakDBInterface:GetItemRecord(spec.entry.itemID) end,
      DropChance=function() return spec.entry.dropChance end,
      DropCountMin=function() return spec.entry.dropCountMin end,
      DropCountMax=function() return spec.entry.dropCountMax end}
    end}
  end
 end
 return record
end
local factory=f.Actor
function f:Actor(record,id,position)
 local actor=factory(self,record,id,position)
 if record=='Character.NCPDPatrol_VossContractor01' then
  actor.obNativeLootGenerated=false
  function actor:WasLootGenerated()
   if not f.obModelDeathLoot then return self.dead==true or self.down==true end
   return self.obNativeLootGenerated
  end
  function actor:ProcessLoot()
   f.obNativeProcessCalls=f.obNativeProcessCalls+1
   if self.obNativeLootGenerated or f.obNativeLootPending then return end
   local key=self:GetEntityID().hash;local items=f.obInventory[key] or {};f.obInventory[key]=items
   if not f.obNativePreserveLiveItem then items[f.obitem]=0 end
   local amount=f.obNativeEmptyRoll and 0 or spec.entry.dropCountMin
   assert(spec.table['$type']=='LootTable' and spec.entry['$type']=='LootItem' and spec.entry.dropChance==1)
   items[spec.entry.itemID]=(items[spec.entry.itemID] or 0)+amount
   f.obNativeGeneratedItems=f.obNativeGeneratedItems+amount;self.obNativeLootGenerated=true
  end
 end
 return actor
end
local advance=f.obAdvance
function f.obAdvance(seconds)
 if f.obModelDeathLoot then
  local actor=f.obRole('target')
  if actor and actor:IsAttached() and (actor.dead or actor.down) and not actor.obIncapacitationSeen then
   actor.obIncapacitationSeen=true;actor:ProcessLoot()
  end
 end
 advance(seconds)
end
