local _, F = ...
local safe = F.Safe
F.storageByID, F.storageRecipes = {}, {}
for _, entry in ipairs(F.storage) do F.storageByID[entry.id] = entry end
for _, recipe in ipairs(F.recipes) do
    for _, item in ipairs(recipe.items) do
        F.storageRecipes[item.id] = F.storageRecipes[item.id] or {}
        table.insert(F.storageRecipes[item.id], recipe)
    end
end
F.storageMode, F.storageQuery, F.storagePage = "crate", "", 1

function F.CarriedCount(id)
    if not id then return nil end
    local count = safe(C_Item and C_Item.GetItemCount, id, false, false, false)
    if type(count) ~= "number" then count = safe(GetItemCount, id, false, false, false) end
    if type(count) == "number" and count >= 0 then return count end
end
function F.StorageReady(entry, counts)
    if entry.type ~= "crate" then return false end
    local owned = counts and counts[entry.id] or F.CarriedCount(entry.id)
    if not owned or owned < 1 or (safe(UnitLevel,"player") or 0) < entry.minLevel then return false end
    for _, bundle in ipairs(entry.bundles) do
        local count = bundle.id and (counts and counts[bundle.id] or F.CarriedCount(bundle.id))
        if count and count >= bundle.quantity then return true end
    end
    return false
end
function F.StorageResults()
    local results, counts = {}, {}
    local level = safe(UnitLevel,"player") or 0
    for _, entry in ipairs(F.storage) do
        if entry.type == F.storageMode then
            counts[entry.id] = F.CarriedCount(entry.id)
            for _, bundle in ipairs(entry.bundles or {}) do
                if bundle.id then counts[bundle.id] = F.CarriedCount(bundle.id) end
            end
            local words = entry.name.." "..entry.id.." "..entry.category.." "..(entry.profession or "")
            for _, bundle in ipairs(entry.bundles or {}) do words = words.." "..bundle.name end
            for _, recipe in ipairs(F.storageRecipes[entry.id] or {}) do words = words.." "..recipe.profession end
            local match = true
            for word in F.storageQuery:lower():gmatch("%S+") do
                if not words:lower():find(word,1,true) then match = false; break end
            end
            if match and (not F.storageLevelOnly or level >= entry.minLevel)
                and (not F.storageOwnedOnly or (counts[entry.id] or 0) > 0)
                and (entry.type ~= "crate" or not F.storageReadyOnly or F.StorageReady(entry,counts)) then
                results[#results+1] = entry
            end
        end
    end
    table.sort(results,function(a,b)
        if a.minLevel ~= b.minLevel then return a.minLevel < b.minLevel end
        if a.name ~= b.name then return a.name < b.name end
        return a.id < b.id
    end)
    return results, counts
end
function F.OpenStorageRecipe(id)
    local recipes = F.storageRecipes[id]
    if not recipes or not recipes[1] then return false end
    local recipe = recipes[1]
    F.profession, F.filter, F.query = recipe.profession, "All records", tostring(recipe.id)
    F.eligibilityFilter, F.sourceFilter = "Any requirements", "All sources"
    F.factionFilter, F.page = "All factions", 1
    F.Show(); F.Select(recipe)
    if F.storageFrame then F.storageFrame:Hide() end
    return true
end
local function label(parent,x,y,w,text,font)
    local t=parent:CreateFontString(nil,"OVERLAY",font or "GameFontHighlight")
    t:SetPoint("TOPLEFT",x,y); t:SetWidth(w); t:SetJustifyH("LEFT"); t:SetJustifyV("TOP")
    t:SetText(text or ""); return t
end
local function button(parent,x,y,w,text,fn)
    local b=CreateFrame("Button",nil,parent,"UIPanelButtonTemplate")
    b:SetPoint("TOPLEFT",x,y); b:SetSize(w,25); b:SetText(text); b:SetScript("OnClick",fn)
    return b
end
local function showItem(owner)
    local item=owner.storageItem
    if not item or not item.id then return end
    F.HideRecipeTooltip()
    F.storageHover=owner
    GameTooltip:SetOwner(owner,"ANCHOR_RIGHT")
    local name=safe(C_Item and C_Item.GetItemInfo or GetItemInfo,item.id)
    local ok=GameTooltip.SetHyperlink and pcall(GameTooltip.SetHyperlink,GameTooltip,"item:"..item.id)
    if not name or not ok then
        GameTooltip:SetText(item.name)
        GameTooltip:AddLine("Loading item details...",1,0.8,0.4)
        if owner.requestedItem~=item.id then
            owner.requestedItem=item.id
            safe(C_Item and C_Item.RequestLoadItemDataByID,item.id)
        end
    end
    GameTooltip:AddLine("Shift-click to put this item in a chat draft.",0.7,0.8,0.9,true)
    GameTooltip:Show()
end
local function hideItem(owner)
    if F.storageHover==owner then GameTooltip:Hide(); F.storageHover=nil end
end
local function bindItem(owner)
    owner:SetScript("OnEnter",showItem)
    owner:SetScript("OnLeave",hideItem)
    owner:SetScript("OnHide",hideItem)
    owner.UpdateTooltip=function() showItem(owner) end
end
local function linkItem(item)
    return item and item.id and F.LinkCraftedItem({items={{id=item.id,name=item.name}}})
end
function F.StorageDescription(entry)
    if not entry then return "No matching entries. Clear the search or untick a filter." end
    local lines={entry.category.."  |  Required level "..entry.minLevel,
        "Carried: "..tostring(F.CarriedCount(entry.id) or "?").."  |  Item ID "..entry.id}
    if entry.type=="crate" then
        lines[#lines+1]="\nFill with ONE of these bundles. Counts use carried items only; bank and alt materials are excluded."
        lines[#lines+1]="Click a material with a recipe to open it. Shift-click links the material."
    else
        lines[#lines+1]="\nHover the item icon for the game's bag capacity and restrictions."
        if entry.classMask~=0 and entry.classMask~=32767 then
            lines[#lines+1]="This item has class restrictions. Check its tooltip."
        end
        local recipe=(F.storageRecipes[entry.id] or {})[1]
        if recipe then
            lines[#lines+1]="\nCrafted with "..recipe.profession.."."
            lines[#lines+1]=F.LearningDetails(recipe,true)
            lines[#lines+1]="\n"..F.MaterialDetails(recipe)
        else
            lines[#lines+1]="\nNo crafting recipe or acquisition source is verified in this catalog. Its presence in client data does not confirm availability."
        end
    end
    return table.concat(lines,"\n")
end
function F.RefreshStorage()
    local frame=F.storageFrame
    if not frame then return end
    if F.storageHover then hideItem(F.storageHover) end
    local results,counts=F.StorageResults()
    local pages=math.max(1,math.ceil(#results/12))
    F.storagePage=math.max(1,math.min(F.storagePage,pages))
    F.storageResults=results
    local selected=false
    for _,entry in ipairs(results) do if entry==F.storageSelected then selected=true end end
    if not selected then F.storageSelected=results[(F.storagePage-1)*12+1] end
    local entry=F.storageSelected
    frame.count:SetText(#results..(F.storageMode=="crate" and " crates" or " new bags and containers"))
    frame.pager:SetText(F.storagePage.." / "..pages)
    frame.previous:SetEnabled(F.storagePage>1); frame.next:SetEnabled(F.storagePage<pages)
    frame.ready:SetEnabled(F.storageMode=="crate")
    frame.crates:SetText(F.storageMode=="crate" and "[ Waylaid Crates ]" or "Waylaid Crates")
    frame.bags:SetText(F.storageMode=="bag" and "[ New bags ]" or "New bags")
    for index,row in ipairs(frame.rows) do
        local item=results[(F.storagePage-1)*12+index]; row.storageItem=item
        if item then
            row.name:SetText((item==entry and "|cffffd579" or "|cffffffff")..item.name:gsub("^Waylaid Crate: ","").."|r")
            row.meta:SetText("Level "..item.minLevel.."  |  Carried "..tostring(counts[item.id] or "?")
                ..(F.StorageReady(item,counts) and "  |  Materials ready" or ""))
            row:Show()
        else row:Hide() end
    end
    frame.name:SetText(entry and entry.name or "Choose a box or bag")
    frame.icon.storageItem=entry
    frame.icon.texture:SetTexture(entry and ("Interface\\Icons\\"..entry.icon) or "Interface\\Icons\\INV_Misc_Bag_10")
    frame.body:SetText(F.StorageDescription(entry))
    local height=frame.body:GetStringHeight()+15
    for index,b in ipairs(frame.bundles) do
        local bundle=entry and entry.bundles and entry.bundles[index]; b.storageItem=bundle
        if bundle then
            local have=bundle.id and counts[bundle.id]
            local ready=have and have>=bundle.quantity
            local suffix=have and ("  |  "..have.." carried, "..math.max(0,bundle.quantity-have).." missing") or "  |  Count unknown"
            b:SetText((ready and "|cff83d69a" or "|cffffffff")..bundle.quantity.." x "..bundle.name.."|r"..suffix
                ..((bundle.id and F.storageRecipes[bundle.id]) and "\nView recipe" or ""))
            b:ClearAllPoints(); b:SetPoint("TOPLEFT",0,-height); height=height+48; b:Show()
        else b:Hide() end
    end
    local tail=""
    if entry and entry.type=="crate" then
        local faction=safe(UnitFactionGroup,"player")
        tail="\nTurn in the sealed crate at your trade camp.\n"
        if faction~="Horde" then tail=tail.."Alliance: Marcy Baker, Three Corners, Redridge Mountains.\n" end
        if faction~="Alliance" then tail=tail.."Horde: Dokimi, outside the Crossroads, The Barrens.\n" end
        tail=tail.."Reward currency: Merchant's Favor. Reward amounts and current stock are not verified here.\n"
        for _,bundle in ipairs(entry.bundles) do if bundle.note then tail=tail.."\n"..bundle.name..": "..bundle.note.."\n" end end
        tail=tail.."\nMaterial counts are a checklist. Fill and turn in crates through the game's own controls."
    end
    frame.tail:SetText(tail); frame.tail:ClearAllPoints(); frame.tail:SetPoint("TOPLEFT",0,-height)
    frame.child:SetHeight(math.max(390,height+frame.tail:GetStringHeight()+20))
    frame.recipe:SetEnabled(entry and F.storageRecipes[entry.id]~=nil or false)
    frame.url:SetText(entry and entry.url or F.storageSource.source)
end
function F.ShowStorage(mode)
    if not F.db then F.Initialize() end
    if mode then
        local changed=mode~=F.storageMode
        F.storageMode=mode; F.storagePage=1; F.storageSelected=nil
        if changed then
            F.storageQuery=""
            if F.storageFrame then F.storageFrame.search:SetText("") end
        end
    end
    if not F.storageFrame then
        local frame=CreateFrame("Frame","ForeverRecipeFinderStorageFrame",UIParent,BackdropTemplateMixin and "BackdropTemplate")
        F.storageFrame=frame; frame:SetSize(980,700); frame:SetPoint("CENTER")
        frame:SetScale(math.min(1,UIParent:GetWidth()/1020,UIParent:GetHeight()/740))
        frame:SetClampedToScreen(true); frame:SetFrameStrata("DIALOG"); frame:EnableMouse(true); frame:SetMovable(true)
        if frame.SetBackdrop then
            frame:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",
            edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=16,
            insets={left=4,right=4,top=4,bottom=4}})
        frame:SetBackdropColor(0.065,0.051,0.034,0.99)
        end
        local drag=CreateFrame("Frame",nil,frame); drag:SetPoint("TOPLEFT",15,-12); drag:SetSize(915,42)
        drag:EnableMouse(true); drag:RegisterForDrag("LeftButton")
        drag:SetScript("OnDragStart",function() frame:StartMoving() end)
        drag:SetScript("OnDragStop",function() frame:StopMovingOrSizing() end)
        label(frame,24,-25,820,"Tradeskill boxes and bags","GameFontNormalLarge")
        local close=CreateFrame("Button",nil,frame,"UIPanelCloseButton"); close:SetPoint("TOPRIGHT",-5,-5)
        close:SetScript("OnClick",function() frame:Hide() end)
        frame:SetScript("OnHide",function() if F.storageHover then hideItem(F.storageHover) end end)
        tinsert(UISpecialFrames,"ForeverRecipeFinderStorageFrame")
        frame.crates=button(frame,24,-65,175,"Waylaid Crates",function() F.ShowStorage("crate") end)
        frame.bags=button(frame,207,-65,175,"New bags",function() F.ShowStorage("bag") end)
        button(frame,774,-65,178,"Back to recipes",function() frame:Hide(); F.Show() end)
        frame.search=CreateFrame("EditBox",nil,frame,"InputBoxTemplate")
        frame.search:SetPoint("TOPLEFT",30,-108); frame.search:SetSize(350,24); frame.search:SetAutoFocus(false)
        label(frame,400,-113,530,"Search by item, material, profession or ID","GameFontHighlightSmall")
        frame.search:SetScript("OnTextChanged",function(self)
            F.storageQuery=self:GetText(); F.storagePage=1; F.storageSelected=nil
            if frame.built then F.RefreshStorage(); frame.scroll:SetVerticalScroll(0) end
        end)
        local function check(x,title,key)
            local c=CreateFrame("CheckButton",nil,frame,"UICheckButtonTemplate")
            c:SetPoint("TOPLEFT",x,-143); c:SetSize(24,24)
            label(c,27,-6,180,title,"GameFontHighlightSmall")
            c:SetScript("OnClick",function(self) F[key]=self:GetChecked() and true or false; F.storagePage=1; F.storageSelected=nil; F.RefreshStorage(); frame.scroll:SetVerticalScroll(0) end)
            return c
        end
        frame.level=check(24,"My level", "storageLevelOnly")
        frame.owned=check(185,"In my bags", "storageOwnedOnly")
        frame.ready=check(355,"Crate and materials ready", "storageReadyOnly")
        frame.count=label(frame,24,-181,355,"","GameFontNormal")
        frame.rows={}
        for index=1,12 do
            local row=CreateFrame("Button",nil,frame); row:SetPoint("TOPLEFT",24,-209-(index-1)*34); row:SetSize(355,33)
            row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
            row.name=label(row,4,-2,347,"","GameFontHighlightSmall"); row.name:SetWordWrap(false)
            row.meta=label(row,4,-17,347,"","GameFontDisableSmall")
            bindItem(row)
            row:SetScript("OnClick",function(self)
                if safe(IsShiftKeyDown) then linkItem(self.storageItem)
                else F.storageSelected=self.storageItem; frame.scroll:SetVerticalScroll(0); F.RefreshStorage() end
            end)
            frame.rows[index]=row
        end
        frame.previous=button(frame,24,-627,90,"Previous",function() F.storagePage=F.storagePage-1; F.storageSelected=nil; F.RefreshStorage(); frame.scroll:SetVerticalScroll(0) end)
        frame.pager=label(frame,174,-633,80,"")
        frame.next=button(frame,289,-627,90,"Next",function() F.storagePage=F.storagePage+1; F.storageSelected=nil; F.RefreshStorage(); frame.scroll:SetVerticalScroll(0) end)
        frame.icon=CreateFrame("Button",nil,frame); frame.icon:SetPoint("TOPLEFT",409,-183); frame.icon:SetSize(42,42)
        frame.icon.texture=frame.icon:CreateTexture(nil,"ARTWORK"); frame.icon.texture:SetAllPoints()
        bindItem(frame.icon); frame.icon:SetScript("OnClick",function(self) if safe(IsShiftKeyDown) then linkItem(self.storageItem) end end)
        frame.name=label(frame,463,-185,478,"","GameFontNormalLarge")
        frame.scroll=CreateFrame("ScrollFrame",nil,frame,"UIPanelScrollFrameTemplate")
        frame.scroll:SetPoint("TOPLEFT",410,-240); frame.scroll:SetSize(518,354)
        frame.child=CreateFrame("Frame",nil,frame.scroll); frame.child:SetSize(518,390); frame.scroll:SetScrollChild(frame.child)
        frame.body=label(frame.child,0,0,508,""); frame.body:SetSpacing(4)
        frame.tail=label(frame.child,0,0,508,""); frame.tail:SetSpacing(4)
        frame.bundles={}
        for index=1,5 do
            local b=button(frame.child,0,0,505,"",function(self)
                local item=self.storageItem
                if safe(IsShiftKeyDown) then linkItem(item)
                elseif item and item.id then F.OpenStorageRecipe(item.id) end
            end)
            b:SetHeight(43); bindItem(b); frame.bundles[index]=b
        end
        frame.recipe=button(frame,410,-608,180,"View crafting recipe",function() if F.storageSelected then F.OpenStorageRecipe(F.storageSelected.id) end end)
        label(frame,410,-642,520,"Source link, Ctrl+C to copy","GameFontHighlightSmall")
        frame.url=CreateFrame("EditBox",nil,frame,"InputBoxTemplate")
        frame.url:SetPoint("TOPLEFT",415,-661); frame.url:SetSize(511,22); frame.url:SetAutoFocus(false)
        frame.url:SetScript("OnEditFocusGained",function(self) self:HighlightText() end)
        label(frame,24,-672,365,"Forever beta data, checked "..F.storageSource.audited,"GameFontDisableSmall")
        frame.built=true
    end
    if F.frame then F.frame:Hide() end
    F.storageFrame:Show(); F.storageFrame.scroll:SetVerticalScroll(0); F.RefreshStorage()
end
local events=CreateFrame("Frame")
for _,event in ipairs({"BAG_UPDATE_DELAYED","PLAYER_LEVEL_UP","PLAYER_ENTERING_WORLD","GET_ITEM_INFO_RECEIVED","ITEM_DATA_LOAD_RESULT"}) do
    pcall(events.RegisterEvent,events,event)
end
events:SetScript("OnEvent",function(_,event,id)
    if not F.storageFrame or not F.storageFrame:IsShown() then return end
    if event=="GET_ITEM_INFO_RECEIVED" or event=="ITEM_DATA_LOAD_RESULT" then
        if F.storageHover and F.storageHover.storageItem.id==id then showItem(F.storageHover) end
    else F.RefreshStorage() end
end)
