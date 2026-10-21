-- Run after the existing addon tests, using the actual imported catalog and UI.
local crates,bags,bundles=0,0,0
for _,entry in ipairs(F.storage) do
 assert(F.storageByID[entry.id]==entry and entry.minLevel>=0)
 if entry.type=="crate" then
  crates=crates+1
  assert(#entry.bundles>=1 and #entry.bundles<=5)
  for _,bundle in ipairs(entry.bundles) do bundles=bundles+1; assert(bundle.quantity>0) end
 else bags=bags+1 end
end
assert(crates==30 and bags==31 and bundles==96)
assert(not F.storageByID[242709], "Internal bank placeholders must not become player bags")
assert(#F.recipes==2258, "Containers must not become fake learned recipes")
local inventory,level={},10
UnitLevel=function() return level end
UnitFactionGroup=function() return "Alliance" end
C_Item=C_Item or {}
C_Item.GetItemCount=function(id,bank,charges,reagentBank)
 assert(bank==false and charges==false and reagentBank==false, "Read carried items only")
 return inventory[id] or 0
end
local parts=F.storageByID[248704]
inventory[parts.id]=1; inventory[4359]=15
assert(not F.StorageReady(parts), "An incomplete bundle is not ready")
inventory[4359]=16
assert(F.StorageReady(parts), "Only ONE complete bundle is needed")
inventory[parts.id]=0; assert(not F.StorageReady(parts), "Materials without the crate are not ready")
inventory[parts.id]=1; level=9; assert(not F.StorageReady(parts), "Apply the crate level requirement")
level=10
F.storageMode="crate"; F.storageQuery="copper bolts"
local results=F.StorageResults(); assert(#results==1 and results[1]==parts)
F.storageQuery=""; F.storageReadyOnly=true
results=F.StorageResults(); assert(#results==1 and results[1]==parts)
F.storageReadyOnly=false; F.storageLevelOnly=true
results=F.StorageResults(); assert(#results==14, "Apprentice and journeyman crates start at level 10")
F.storageLevelOnly=false; F.storageOwnedOnly=true
results=F.StorageResults(); assert(#results==1)
F.storageOwnedOnly=false
local ore=F.storageByID[248697]
assert(ore.bundles[3].name=="Dark Iron Ore" and not ore.bundles[3].id and ore.bundles[3].note)
level=60; inventory[ore.id]=1; inventory[11099]=100; inventory[11370]=100
assert(not F.StorageReady(ore), "Ambiguous Dark Iron Ore IDs must not produce a ready result")
local currentCount=C_Item.GetItemCount
C_Item.GetItemCount=function() error("API unavailable") end
GetItemCount=function(id) return inventory[id] or 0 end
assert(F.CarriedCount(4359)==16, "Legacy inventory API remains usable")
GetItemCount=nil
assert(F.CarriedCount(4359)==nil and not F.StorageReady(parts), "Missing APIs mean unknown, not ready")
C_Item.GetItemCount=currentCount
F.Command("boxes")
local frame=F.storageFrame
assert(frame:IsShown() and not F.frame:IsShown() and #F.storageResults==30)
assert(frame.built and frame.ready.enabled)
frame.search:SetText("apprentice parts"); assert(#F.storageResults==1)
frame.rows[1].scripts.OnClick(frame.rows[1]); assert(F.storageSelected==parts)
assert(frame.bundles[1].storageItem.id==4359 and frame.bundles[1]:IsShown())
local savedRecipeCount=#F.recipes
F.sessionKnown={}; F.db.known={}
IsShiftKeyDown=function() return false end
frame.bundles[1].scripts.OnClick(frame.bundles[1])
assert(F.frame:IsShown() and not frame:IsShown())
assert(F.selected.items[1].id==4359 and #F.results==1)
assert(not next(F.sessionKnown) and not next(F.db.known), "Browsing must not mark recipes learned")
F.Command("bags"); frame.search:SetText("")
assert(frame:IsShown() and #F.storageResults==31 and not frame.ready.enabled)
frame.search:SetText("linen reagent")
assert(#F.storageResults==1 and F.storageSelected.id==253664)
assert(frame.recipe.enabled)
frame.recipe.scripts.OnClick(frame.recipe)
assert(F.selected.id==1257013 and F.frame:IsShown() and not frame:IsShown())
F.Command("bags"); frame.search:SetText("mining pack")
assert(#F.storageResults==1 and not frame.recipe.enabled)
assert(F.StorageDescription(F.storageSelected):find("No crafting recipe",1,true))
frame.search:SetText("does-not-exist")
assert(#F.storageResults==0 and F.storageSelected==nil and not frame.recipe.enabled)
for _,row in ipairs(frame.rows) do assert(not row:IsShown()) end
frame.search:SetText(""); frame.next.scripts.OnClick(frame.next)
assert(F.storagePage==2 and frame.previous.enabled)
frame.previous.scripts.OnClick(frame.previous); assert(F.storagePage==1)

-- Supply item links use item IDs, preserve the chat draft and never send it.
local linked
local originalLink=F.LinkCraftedItem
F.LinkCraftedItem=function(recipe) linked=recipe.items[1].id; return true end
IsShiftKeyDown=function() return true end
frame.rows[1].scripts.OnClick(frame.rows[1]); assert(linked==frame.rows[1].storageItem.id)
F.LinkCraftedItem=originalLink
IsShiftKeyDown=function() return false end

-- Inventory events refresh the open list, and hidden windows stay idle.
F.Command("boxes"); frame.search:SetText("apprentice parts")
frame.ready:SetChecked(true); frame.ready.scripts.OnClick(frame.ready)
assert(#F.storageResults==1)
inventory[4359]=0
local events
for _,candidate in ipairs(frames) do if candidate.events.BAG_UPDATE_DELAYED then events=candidate end end
events.scripts.OnEvent(events,"BAG_UPDATE_DELAYED"); assert(#F.storageResults==0)
F.Command(""); assert(F.frame:IsShown() and not frame:IsShown())
local calls=0
C_Item.GetItemCount=function() calls=calls+1; return 0 end
events.scripts.OnEvent(events,"BAG_UPDATE_DELAYED"); assert(calls==0)
C_Item.GetItemCount=currentCount
assert(#F.recipes==savedRecipeCount)
print("PASS: 30 crates, 96 alternative bundles, 31 bags, item IDs, level/owned/readiness filters, unknown counts, recipe links, UI paging, chat item IDs and inventory refresh.")
