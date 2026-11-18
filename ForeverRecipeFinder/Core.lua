local addonName, F = ...
_G.ForeverRecipeFinder = F
F.byID, F.professions, F.professionSet = {}, {"All professions"}, {}
F.query, F.profession, F.filter = "", "All professions", "All records"
F.sessionKnown = {}

local function safe(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d, e, f, g, h, i, j, k, l = pcall(fn, ...)
    if ok then return a, b, c, d, e, f, g, h, i, j, k, l end
end
F.Safe = safe

function F.SpellName(id)
    if C_Spell and C_Spell.GetSpellName then return safe(C_Spell.GetSpellName, id) end
    return safe(GetSpellInfo, id)
end

for _, recipe in ipairs(F.recipes) do
    F.byID[recipe.id] = recipe
    if not F.professionSet[recipe.profession] then
        F.professionSet[recipe.profession] = true
        F.professions[#F.professions + 1] = recipe.profession
    end
    recipe.search = string.lower(recipe.name .. " " .. recipe.id .. " " .. recipe.profession .. " " .. recipe.category)
end
table.sort(F.professions, function(a, b)
    if a == b then return false end
    if a == "All professions" then return true end
    if b == "All professions" then return false end
    return a < b
end)
table.sort(F.recipes, function(a, b)
    if a.name == b.name then return a.id < b.id end
    return a.name < b.name
end)

local professionSpells = {
    Alchemy = 2259, Blacksmithing = 2018, Cooking = 2550, Enchanting = 7411,
    Engineering = 4036, ["First Aid"] = 3273, Fishing = 7620, Herbalism = 2366,
    Leatherworking = 2108, Mining = 2575, Poisons = 2842, Skinning = 8613, Tailoring = 3908,
}
function F.ProfessionName(name)
    if F.professionSet[name] then return name end
    for english, id in pairs(professionSpells) do
        if F.SpellName(id) == name and name then return english end
    end
end

function F.Initialize()
    if type(ForeverRecipeFinderDB) ~= "table" then ForeverRecipeFinderDB = {} end
    if type(ForeverRecipeFinderDB.known) ~= "table" then ForeverRecipeFinderDB.known = {} end
    ForeverRecipeFinderDB.version = 2
    if type(ForeverRecipeFinderDB.observedSources) ~= "table" then ForeverRecipeFinderDB.observedSources = {} end
    F.db = ForeverRecipeFinderDB
end
function F.Observe(id, how)
    id = tonumber(id)
    if not id or id <= 0 then return end
    F.sessionKnown[id] = true
    if F.db then F.db.known[id] = { method = how, at = time and time() or 0 } end
end
function F.Status(recipe)
    if F.sessionKnown[recipe.id] then return "Learned" end
    if F.db and F.db.known[recipe.id] then return "Previously seen" end
    return "Not seen"
end
function F.LinkID(link)
    if type(link) ~= "string" then return nil end
    -- Output item IDs must never be interpreted as crafting spell IDs.
    return tonumber(link:match("|Henchant:(%d+)")) or tonumber(link:match("|Hspell:(%d+)"))
end
local nameIndexes = {}
local function identify(name, link, profession)
    local id = F.LinkID(link)
    if id then return id end
    if not name or not profession then return nil end
    if not nameIndexes[profession] then
        local index = {}
        local function add(key, id)
            if key then index[key] = index[key] == nil and id or index[key] == id and id or false end
        end
        for _, r in ipairs(F.recipes) do
            if r.profession == profession then
                add(r.name, r.id); add(F.SpellName(r.id), r.id)
            end
        end
        nameIndexes[profession] = index
    end
    return nameIndexes[profession][name] or nil
end
F.IdentifyRecipe = identify

function F.ForeignProfession()
    local api = C_TradeSkillUI or {}
    return safe(IsTradeSkillLinked) or safe(api.IsTradeSkillLinked)
        or safe(api.IsTradeSkillGuild) or safe(api.IsNPCCrafting)
end

function F.ProfessionDataClosed()
    -- Clients can retain ready recipe data after their profession window closes.
    return F.professionClosed and not F.tradeOpen
        and not (TradeSkillFrame and TradeSkillFrame:IsShown())
        and not (CraftFrame and CraftFrame:IsShown())
        and not (ProfessionsFrame and ProfessionsFrame:IsShown())
end

function F.CurrentProfessionInfo(ids)
    local api = C_TradeSkillUI or {}
    local info = safe(api.GetBaseProfessionInfo)
    if type(info) == "table" and F.ProfessionName(info.professionName) then
        return F.ProfessionName(info.professionName), info
    end
    local first = ids and ids[1]
    if first then
        info = safe(api.GetProfessionInfoByRecipeID, first)
        if type(info) == "table" then
            local name = F.ProfessionName(info.parentProfessionName) or F.ProfessionName(info.professionName)
            if name then return name, info end
        end
        if F.byID[first] then return F.byID[first].profession end
    end
end

function F.Scan(kind)
    if not F.db then F.Initialize() end
    local observed, profession, seen, reason = 0, nil, {}, "closed"
    local inspected, missing, unknown = 0, 0, 0
    local function observe(id, method)
        if id and not seen[id] then
            seen[id] = true
            F.Observe(id, method)
            if F.byID[id] then observed = observed + 1 else unknown = unknown + 1 end
        end
    end
    local api = C_TradeSkillUI
    local modern = api and api.GetAllRecipeIDs and api.GetRecipeInfo
    local craftOpen = kind == "craft" or (not modern and kind ~= "trade" and CraftFrame and CraftFrame:IsShown())
    local tradeOpen = kind == "trade" or (TradeSkillFrame and TradeSkillFrame:IsShown())
    if F.ForeignProfession() then
        reason = "foreign"
    elseif F.ProfessionDataClosed() then
        reason = "closed"
    elseif craftOpen and GetNumCrafts and GetCraftInfo then
        profession = F.ProfessionName(safe(GetCraftDisplaySkillLine) or safe(GetCraftName))
        if profession then nameIndexes[profession] = nil end
        local count = safe(GetNumCrafts) or 0
        reason = "waiting"
        for index = 1, count do
            local name, _, craftType = safe(GetCraftInfo, index)
            if not name then
                missing = missing + 1
            elseif craftType ~= "header" and craftType ~= "subheader" then
                inspected = inspected + 1
                local id = identify(name, safe(GetCraftRecipeLink, index), profession)
                if id then observe(id, "Craft window") else missing = missing + 1 end
            end
        end
        if inspected > 0 and missing == 0 then reason = "ok" end
    elseif api and api.GetAllRecipeIDs and api.GetRecipeInfo then
        -- The current API takes precedence over compatibility globals and frames.
        local ready = safe(api.IsTradeSkillReady)
        local ids = safe(api.GetAllRecipeIDs)
        local open = tradeOpen or (ProfessionsFrame and ProfessionsFrame:IsShown()) or F.tradeOpen
        if ready == false then
            reason = open and "waiting" or "closed"
        elseif type(ids) == "table" and #ids > 0 then
            profession = F.CurrentProfessionInfo(ids)
            F.lastModernIDs = ids
            for _, id in ipairs(ids) do
                local info = safe(api.GetRecipeInfo, id)
                if type(info) ~= "table" or type(info.learned) ~= "boolean" then
                    missing = missing + 1
                else
                    inspected = inspected + 1
                    if info.learned then
                        local spellID = F.LinkID(safe(api.GetRecipeLink, id)) or id
                        observe(spellID, "Profession API")
                    end
                end
            end
            reason = missing > 0 and "waiting" or "ok"
        else
            reason = (open or ready == true) and "waiting" or "closed"
        end
    elseif tradeOpen and GetNumTradeSkills and GetTradeSkillInfo then
        profession = F.ProfessionName(safe(GetTradeSkillLine))
        if profession then nameIndexes[profession] = nil end
        reason = "waiting"
        for index = 1, safe(GetNumTradeSkills) or 0 do
            local name, skillType = safe(GetTradeSkillInfo, index)
            if not name then
                missing = missing + 1
            elseif skillType ~= "header" and skillType ~= "subheader" then
                inspected = inspected + 1
                local id = identify(name, safe(GetTradeSkillRecipeLink, index), profession)
                if id then observe(id, "Profession window") else missing = missing + 1 end
            end
        end
        if inspected > 0 and missing == 0 then reason = "ok" end
    end
    if profession and inspected > 0 then F.profession = profession end
    F.scanReason, F.scanProfession = reason, profession
    if reason == "ok" then
        F.lastScan = "Scanned " .. (profession or "profession") .. ": " .. observed .. " learned recipes matched."
        if unknown > 0 then F.lastScan = F.lastScan .. " " .. unknown .. " outside the wiki catalog." end
    elseif reason == "waiting" then
        F.lastScan = "Waiting for profession data. " .. observed .. " learned recipes matched so far."
    elseif reason == "foreign" then
        F.lastScan = "Open your own profession. Linked, guild and NPC recipe lists are not scanned."
    else
        F.lastScan = "Open your character's profession window, then click Scan profession."
    end
    if F.Refresh then F.Refresh() end
    return observed, reason
end

function F.RequestScan(kind, manual)
    kind = kind or F.activeScanKind
    F.scanToken = (F.scanToken or 0) + 1
    local token, delays = F.scanToken, {0.2, 0.5, 1, 2}
    if manual then F.scanManualPending = true end
    local function attempt(index)
        if token ~= F.scanToken then return end
        local _, reason = F.Scan(kind)
        if reason == "waiting" and delays[index] and C_Timer and C_Timer.After then
            C_Timer.After(delays[index], function() attempt(index + 1) end)
            return
        end
        if reason == "waiting" then
            F.lastScan = "Profession data is still loading. Reopen your profession and click Scan again."
        end
        if F.scanManualPending then
            F.scanManualPending = nil
            if reason == "ok" then
                -- A learning-only filter would otherwise hide the newly learned rows.
                F.filter, F.eligibilityFilter, F.sourceFilter = "All records", "Any requirements", "All sources"
                F.query, F.page = "", 1
                if F.search then F.search:SetText("") end
            end
            F.Print(F.lastScan)
        end
        if F.Refresh then F.Refresh() end
    end
    attempt(1)
end

function F.Results()
    if F.ReadPlayer then F.ReadPlayer() end
    local results, learned, previous = {}, 0, 0
    local query = string.lower(F.query or "")
    for _, recipe in ipairs(F.recipes) do
        local status = F.Status(recipe)
        local match = F.profession == "All professions" or recipe.profession == F.profession
        if match and F.filter ~= "All records" and F.filter ~= status then match = false end
        if match and F.MatchesLearning and not F.MatchesLearning(recipe) then match = false end
        if match then
            for word in query:gmatch("%S+") do
                if not recipe.search:find(word, 1, true) then match = false; break end
            end
        end
        if match then
            results[#results + 1] = recipe
            if status == "Learned" then learned = learned + 1 end
            if status == "Previously seen" then previous = previous + 1 end
        end
    end
    return results, learned, previous
end
function F.Print(text)
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cffffcc66Forever Recipe Finder:|r " .. text) end
end
function F.Command(text)
    if not F.db then F.Initialize() end
    text = (text or ""):match("^%s*(.-)%s*$")
    if text == "help" then
        F.Print("/frf opens recipes. /frf boxes opens crates. /frf bags opens new bags. /frf scan scans an open profession. /frf resetpos centers the window. /frf forget clears observations. /frf <words> searches.")
        return
    elseif text == "boxes" or text == "crates" or text == "bags" then
        F.ShowStorage(text == "bags" and "bag" or "crate")
        return
    elseif text == "forget" then
        F.db.known, F.sessionKnown = {}, {}
        F.Print("Cleared this character's learned-recipe observations.")
    elseif text == "resetpos" then
        F.db.position = nil
        if F.frame then F.frame:ClearAllPoints(); F.frame:SetPoint("CENTER") end
        if F.storageFrame then F.storageFrame:ClearAllPoints(); F.storageFrame:SetPoint("CENTER") end
    elseif text == "scan" then
        F.RequestScan(nil, true)
    elseif text ~= "" then
        F.query = text
        F.profession, F.filter = "All professions", "All records"
        F.eligibilityFilter, F.sourceFilter = "Any requirements", "All sources"
    end
    F.Show()
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
for _, event in ipairs({"TRADE_SKILL_SHOW", "TRADE_SKILL_CLOSE", "TRADE_SKILL_DATA_SOURCE_CHANGED",
    "TRADE_SKILL_LIST_UPDATE", "TRADE_SKILL_DETAILS_UPDATE", "TRADE_SKILL_UPDATE", "CRAFT_SHOW", "CRAFT_CLOSE",
    "CRAFT_UPDATE", "NEW_RECIPE_LEARNED", "SKILL_LINES_CHANGED"}) do
    pcall(events.RegisterEvent, events, event)
end
local pending
events:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" then
        if name == addonName then F.Initialize() end
        return
    end
    if event == "PLAYER_LOGIN" then
        F.Print(F.source.count .. " wiki recipe records loaded. Type /frf to browse.")
        return
    end
    if event == "NEW_RECIPE_LEARNED" then
        F.Observe(name, "Recipe learned event")
        if F.Refresh then F.Refresh() end
    end
    if event == "TRADE_SKILL_CLOSE" or event == "CRAFT_CLOSE" then
        pending = nil
        F.tradeOpen, F.activeScanKind = nil, nil
        F.professionClosed, F.lastModernIDs = true, nil
        F.scanToken = (F.scanToken or 0) + 1
        if F.scanManualPending then
            F.scanManualPending = nil
            F.lastScan = "Profession closed. Open it again to finish scanning."
            F.Print(F.lastScan)
        end
        return
    end
    local kind = event:match("^CRAFT") and "craft" or "trade"
    if event == "CRAFT_SHOW" or event == "TRADE_SKILL_SHOW" or event == "TRADE_SKILL_DATA_SOURCE_CHANGED" then
        if event == "TRADE_SKILL_DATA_SOURCE_CHANGED" and F.ProfessionDataClosed() then return end
        pending = nil
        F.lastModernIDs = nil
        F.professionClosed = nil
        F.tradeOpen, F.activeScanKind = true, kind
        F.AttachButton(kind)
        F.RequestScan(kind)
        return
    end
    if pending then return end
    local request = {}
    pending = request
    local function update()
        if pending ~= request then return end
        pending = nil
        F.RequestScan(F.activeScanKind)
    end
    if C_Timer and C_Timer.After then C_Timer.After(0.1, update) else update() end
end)
SLASH_FOREVERRECIPEFINDER1, SLASH_FOREVERRECIPEFINDER2 = "/frf", "/recipefinder"
SlashCmdList.FOREVERRECIPEFINDER = F.Command
