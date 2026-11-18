-- Run after the original recipe and storage suites.
local oldItem,oldCount=C_Item,GetItemCount
local inventory={[4359]=8,[2840]=5}
local calls={}
C_Item={GetItemCount=function(id,bank,charges,reagentBank)
    assert(bank==false and charges==false and reagentBank==false)
    calls[id]=(calls[id] or 0)+1
    return inventory[id]
end}
GetItemCount=nil
local recipe={items={},craftType="Craft",tools="",fields={},reagents={
    {id=4359,name="Handful of Copper Bolts",quantity=2},
    {id=2840,name="Copper Bar",quantity=2},
    {id=4359,name="Handful of Copper Bolts",quantity=2},
}}
local materials,crafts=F.MaterialAvailability(recipe)
assert(#materials==2 and crafts==2, "Shared materials must be combined before estimating crafts")
assert(materials[1].quantity==4 and materials[1].carried==8 and materials[1].missing==0)
assert(calls[4359]==1, "Read a shared material count once per calculation")
inventory[2840]=1
materials,crafts=F.MaterialAvailability(recipe)
assert(crafts==0 and materials[2].missing==1, "Report the limiting material and shortfall")
local details=F.MaterialDetails(recipe)
assert(details:find("1 carried, 1 missing",1,true) and details:find("cover 0 crafts",1,true))
inventory[2840]=nil
materials,crafts=F.MaterialAvailability(recipe)
assert(crafts==nil and materials[2].missing==nil, "An unavailable count is not zero")
assert(F.MaterialDetails(recipe):find("Carried count unknown",1,true))
recipe.reagents[2].quantity=nil
inventory[2840]=5
assert(select(2,F.MaterialAvailability(recipe))==nil, "Unknown requirements cannot produce a craft count")
recipe.reagents[2].quantity=2
recipe.reagents[2].id=nil
assert(select(2,F.MaterialAvailability(recipe))==nil, "An unidentified material cannot produce a craft count")
assert(select(2,F.MaterialAvailability({reagents={}}))==nil, "No recorded materials is not unlimited crafting")

-- Real recipe details update when carried inventory changes, without a full list refresh.
local actual=F.byID[3979]
for _,reagent in ipairs(actual.reagents) do inventory[reagent.id]=0 end
F.Show(); F.ResetFilters(); F.profession="All professions"; F.Select(actual)
F.detailTab="Materials"; F.RenderDetails()
assert(F.detailText:GetText():find("cover 0 crafts",1,true))
for _,reagent in ipairs(actual.reagents) do inventory[reagent.id]=reagent.quantity end
for _,event in ipairs(frames) do
    if event.events.BAG_UPDATE_DELAYED then event.scripts.OnEvent(event,"BAG_UPDATE_DELAYED") end
end
assert(F.detailText:GetText():find("cover 1 craft.",1,true))
local render,refreshes=F.RenderDetails,0
F.RenderDetails=function() refreshes=refreshes+1 end
F.frame:Hide()
for _,event in ipairs(frames) do
    if event.events.BAG_UPDATE_DELAYED then event.scripts.OnEvent(event,"BAG_UPDATE_DELAYED") end
end
assert(refreshes==0, "Hidden recipe details should stay idle")
F.RenderDetails=render
C_Item,GetItemCount=oldItem,oldCount

-- Storage mouse-leave and async item events must not hide or steal another tooltip.
F.storageReadyOnly,F.storageOwnedOnly,F.storageLevelOnly=false,false,false
F.ShowStorage("bag"); F.storageFrame.search:SetText("")
local row=F.storageFrame.rows[1]
local other=CreateFrame("Button")
row.scripts.OnEnter(row)
assert(F.storageHover==row and GameTooltip:GetOwner()==row)
GameTooltip:SetOwner(other); GameTooltip:Show()
row.scripts.OnLeave(row)
assert(GameTooltip:IsShown() and GameTooltip:GetOwner()==other and F.storageHover==nil,
    "Leaving a storage row must preserve another control's tooltip")
row.scripts.OnEnter(row)
GameTooltip:SetOwner(other); GameTooltip:Show()
for _,event in ipairs(frames) do
    if event.events.ITEM_DATA_LOAD_RESULT then event.scripts.OnEvent(event,"ITEM_DATA_LOAD_RESULT",row.storageItem.id) end
end
assert(GameTooltip:GetOwner()==other and F.storageHover==nil, "Loaded item data must not reclaim a tooltip")
row.scripts.OnEnter(row)
GameTooltip:SetOwner(other); GameTooltip:Show(); row.UpdateTooltip()
assert(GameTooltip:GetOwner()==other and F.storageHover==nil, "The native updater must respect tooltip ownership")
row.scripts.OnEnter(row); row.scripts.OnLeave(row)
assert(not GameTooltip:IsShown() and F.storageHover==nil, "Owned storage tooltips still close on mouse-leave")
F.storageFrame:Hide()
print("PASS: carried-material shortfalls, combined reagents, unknown counts, inventory refresh and storage tooltip ownership.")
