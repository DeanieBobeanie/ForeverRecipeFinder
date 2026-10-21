local _, F = ...
local safe = F.Safe

local function ownsTooltip(owner)
    return GameTooltip and safe(GameTooltip.GetOwner, GameTooltip) == owner
end
local function hideComparisons()
    if GameTooltip_HideShoppingTooltips then safe(GameTooltip_HideShoppingTooltips, GameTooltip) end
    for _, tooltip in pairs(GameTooltip and GameTooltip.shoppingTooltips or {}) do safe(tooltip.Hide, tooltip) end
end
function F.HideRecipeTooltip(owner)
    local hover = F.itemHover
    if not hover or (owner and owner ~= hover.owner) then return end
    if ownsTooltip(hover.owner) then
        hideComparisons()
        GameTooltip:Hide()
    end
    F.itemHover = nil
end

local function itemInfo(id)
    return safe(C_Item and C_Item.GetItemInfo or GetItemInfo, id)
end

function F.LinkCraftedItem(recipe)
    local item = recipe and recipe.items and recipe.items[1]
    if not item then F.Print("This recipe has no recorded output item to link."); return false end
    local _, link = itemInfo(item.id)
    if type(link) ~= "string" or not link:find("|Hitem:" .. item.id .. "[:|]") then
        if C_Item then safe(C_Item.RequestLoadItemDataByID, item.id) end
        F.Print("Item data is loading. Hover the recipe, then Shift-click again to link it.")
        return false
    end
    local linkItem = ChatFrameUtil and ChatFrameUtil.LinkItem or ChatEdit_LinkItem
    if type(linkItem) == "function" then
        local ok = pcall(linkItem, item.id, link)
        if ok then return true end
    end
    local active = safe(ChatFrameUtil and ChatFrameUtil.GetActiveWindow or ChatEdit_GetActiveWindow)
    if active and type(active.Insert) == "function" then
        local ok = pcall(active.Insert, active, link)
        if ok then return true end
    end
    local openChat = ChatFrameUtil and ChatFrameUtil.OpenChat or ChatFrame_OpenChat
    if type(openChat) == "function" then
        local ok = pcall(openChat, link)
        if ok then return true end
    end
    F.Print("Could not open the chat editor. Press Enter, then Shift-click the recipe again.")
    return false
end
function F.RecipeChatClick(recipe)
    if safe(IsModifiedClick, "CHATLINK") or safe(IsShiftKeyDown) then
        F.LinkCraftedItem(recipe)
        return true
    end
    return false
end
local function equippable(id, equipLocation)
    local result = safe(C_Item and C_Item.IsEquippableItem or IsEquippableItem, id)
    if type(result) == "boolean" then return result end
    if type(equipLocation) == "string" then return equipLocation ~= "" and equipLocation ~= "INVTYPE_NON_EQUIP" end
    return false
end
local function compare(hover)
    if not ownsTooltip(hover.owner) then return end
    local automatic = not F.db or F.db.compareGear ~= false
    local wanted = automatic or safe(IsModifiedClick, "COMPAREITEMS")
        or safe(C_CVar and C_CVar.GetCVarBool or GetCVarBool, "alwaysCompareItems")
    if hover.equippable and not hover.loading and wanted then
        -- Blizzard chooses the equipped slots and calculates its stat changes,
        -- including paired slots and two-handed weapons. No guessed stat sums.
        if type(GameTooltip_ShowCompareItem) == "function" then
            local ok = pcall(GameTooltip_ShowCompareItem, GameTooltip)
            if not ok then hideComparisons() end
        end
    else
        hideComparisons()
    end
end
local function addRecipeContext(recipe, gear)
    GameTooltip:AddLine(" ", 1, 1, 1)
    GameTooltip:AddLine("Recipe: " .. recipe.name, 1, 0.8, 0.4, true)
    GameTooltip:AddLine(recipe.profession .. " / " .. F.Eligibility(recipe), 0.85, 0.8, 0.7, true)
    if gear then
        GameTooltip:AddLine("Base item preview; random bonuses and enchants are not included.", 0.65, 0.65, 0.65, true)
    end
end

function F.ShowRecipeTooltip(owner, recipe)
    if not owner or not recipe or not GameTooltip then F.HideRecipeTooltip(owner); return end
    local previous = F.itemHover
    local item = recipe.items and recipe.items[1]
    local hover = {owner=owner, recipe=recipe, itemID=item and item.id}
    if previous and previous.owner == owner and previous.itemID == hover.itemID then
        hover.requested = previous.requested
    end
    F.itemHover = hover
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    hideComparisons()
    if item then
        local name, link, _, _, _, _, _, _, equipLocation = itemInfo(item.id)
        local loaded = type(name) == "string" and name ~= ""
        local valid = false
        if type(GameTooltip.SetHyperlink) == "function" then
            valid = pcall(GameTooltip.SetHyperlink, GameTooltip, link or ("item:" .. item.id))
        end
        hover.loading = not loaded
        hover.equippable = loaded and equippable(item.id, equipLocation)
        if not loaded or not valid then
            GameTooltip:SetText(name or item.name or recipe.name)
            GameTooltip:AddLine(not loaded and "Loading item data. No stats available yet."
                or "This client could not display the item tooltip.", 1, 0.8, 0.4, true)
            GameTooltip:AddLine("Item ID " .. item.id, 0.7, 0.7, 0.7)
            hover.equippable = false
        end
        addRecipeContext(recipe, hover.equippable)
        GameTooltip:AddLine("Shift-click to link the crafted item in chat.", 0.7, 0.8, 0.9, true)
        if hover.equippable then
            GameTooltip:AddLine("Compare with equipped gear. Red requirements on the item still apply.", 0.7, 0.8, 0.9, true)
        end
        if not loaded and not hover.requested then
            hover.requested = true
            if C_Item then safe(C_Item.RequestLoadItemDataByID, item.id) end
        end
    else
        local valid = type(GameTooltip.SetSpellByID) == "function"
            and pcall(GameTooltip.SetSpellByID, GameTooltip, recipe.id)
        if not valid then GameTooltip:SetText(recipe.name) end
        addRecipeContext(recipe, false)
        GameTooltip:AddLine("No crafted item is recorded for this recipe.", 0.7, 0.7, 0.7, true)
    end
    GameTooltip:Show()
    compare(hover)
end

function F.UpdateRecipeTooltip(force)
    local hover = F.itemHover
    if not hover then return end
    if not ownsTooltip(hover.owner) then F.itemHover = nil; return end
    if (F.frame and not F.frame:IsShown()) or not hover.owner:IsShown() then F.HideRecipeTooltip(); return end
    local recipe = hover.recipe
    if hover.owner.frfRecipeGetter then recipe = hover.owner.frfRecipeGetter() end
    -- A recycled list row must never retain the previous recipe's gear tooltip.
    if not recipe then F.HideRecipeTooltip(); return end
    if force or recipe ~= hover.recipe or (hover.loading and itemInfo(hover.itemID)) then
        F.ShowRecipeTooltip(hover.owner, recipe)
    else
        compare(hover)
    end
end
function F.BindRecipeTooltip(owner, getter)
    owner.frfRecipeGetter = getter
    owner:SetScript("OnEnter", function(self) F.ShowRecipeTooltip(self, getter()) end)
    owner:SetScript("OnLeave", function(self) F.HideRecipeTooltip(self) end)
    owner:SetScript("OnHide", function(self) F.HideRecipeTooltip(self) end)
    -- The native tooltip calls its owner's updater; no global tooltip hook.
    owner.UpdateTooltip = function() F.UpdateRecipeTooltip() end
end

local events = CreateFrame("Frame")
for _, event in ipairs({"GET_ITEM_INFO_RECEIVED", "ITEM_DATA_LOAD_RESULT", "PLAYER_EQUIPMENT_CHANGED", "MODIFIER_STATE_CHANGED"}) do
    pcall(events.RegisterEvent, events, event)
end
events:SetScript("OnEvent", function(_, event, id)
    if not F.itemHover then return end
    if event == "GET_ITEM_INFO_RECEIVED" or event == "ITEM_DATA_LOAD_RESULT" then
        if id ~= F.itemHover.itemID then return end
        F.UpdateRecipeTooltip(true)
    else
        F.UpdateRecipeTooltip(event == "PLAYER_EQUIPMENT_CHANGED")
    end
end)
