local _, F = ...
local safe = F.Safe
F.eligibilityFilter, F.sourceFilter, F.factionFilter = "Any requirements", "All sources", "My faction"
F.player, F.itemLevels, F.itemRequested, F.liveTrainer = {skills={}}, {}, {}, {}
F.recipeItems = {}
F.sourceLabels = {
    vendor="Vendor", trainer="Trainer", quest="Quest", drop="Drop", worldDrop="World drop",
    blueprint="Blueprint", container="Container", worldEvent="World event", unknown="Unknown",
    profession="With the profession",
}
for id, entry in pairs(F.learning) do
    if entry.recipeItemID then
        F.recipeItems[entry.recipeItemID] = F.recipeItems[entry.recipeItemID] or {}
        table.insert(F.recipeItems[entry.recipeItemID], id)
    end
end

function F.ReadPlayer()
    local skills, detected = {}, false
    local function add(name, rank, maximum)
        local profession = F.ProfessionName(name)
        if profession and type(rank) == "number" then
            skills[profession] = {rank=rank, maximum=maximum}
            detected = true
        end
    end
    if GetProfessions and GetProfessionInfo then
        for _, index in pairs({safe(GetProfessions)}) do
            local name, _, rank, maximum = safe(GetProfessionInfo, index)
            add(name, rank, maximum)
        end
    end
    if GetNumSkillLines and GetSkillLineInfo then
        for index = 1, safe(GetNumSkillLines) or 0 do
            local name, header, _, rank, _, _, maximum = safe(GetSkillLineInfo, index)
            if not header then add(name, rank, maximum) end
        end
    end
    local modernCurrent = false
    if C_TradeSkillUI and not F.ForeignProfession() and safe(C_TradeSkillUI.IsTradeSkillReady) ~= false then
        local name, info = F.CurrentProfessionInfo(F.lastModernIDs)
        if name and info and type(info.skillLevel) == "number" then
            add(name, info.skillLevel, info.maxSkillLevel)
            modernCurrent = true
        end
    end
    if not modernCurrent and TradeSkillFrame and TradeSkillFrame:IsShown() and not F.ForeignProfession() then
        add(safe(GetTradeSkillLine))
    end
    if not modernCurrent and CraftFrame and CraftFrame:IsShown() and not F.ForeignProfession() then
        add(safe(GetCraftDisplaySkillLine))
    end
    F.player = {level=safe(UnitLevel, "player"), faction=string.lower(safe(UnitFactionGroup, "player") or ""),
                skills=skills, detected=detected}
end

function F.PlayerSummary()
    local words = {"Character level " .. tostring(F.player.level or "?")}
    if F.profession ~= "All professions" then
        local skill = F.player.skills[F.profession]
        words[#words+1] = F.profession .. " " .. (skill and tostring(skill.rank) .. "/" .. tostring(skill.maximum or "?") or "not detected")
    else
        for _, name in ipairs(F.professions) do
            local skill = F.player.skills[name]
            if skill then words[#words+1] = name .. " " .. skill.rank end
        end
    end
    if not F.player.detected then words[#words+1] = "Open your professions to read their skill levels." end
    return table.concat(words, "  |  ")
end

function F.LevelRequirement(recipe)
    local observed = F.db and F.db.observedSources[recipe.id]
    if observed and observed.requiredLevel ~= nil then return observed.requiredLevel end
    local data = F.learning[recipe.id] or {}
    if data.requiredLevel ~= nil then return data.requiredLevel end
    if data.recipeItemID then return F.itemLevels[data.recipeItemID] end
end

function F.SkillRequirement(recipe)
    local observed = F.db and F.db.observedSources[recipe.id]
    if observed and observed.requiredSkill then return observed.requiredSkill end
    return F.learning[recipe.id] and F.learning[recipe.id].requiredSkill
end

function F.Eligibility(recipe)
    local status = F.Status(recipe)
    if status ~= "Not seen" then return status end
    local data = F.learning[recipe.id] or {}
    local skill = F.player.skills[recipe.profession]
    if not skill then return "Profession not detected" end
    local needed = F.SkillRequirement(recipe)
    if needed and skill.rank < needed then return "Needs skill " .. needed end
    local level = F.LevelRequirement(recipe)
    if level and F.player.level and F.player.level < level then return "Needs level " .. level end
    if F.liveTrainer[recipe.id] == "available" then return "Can learn now" end
    if data.removed then return "Reported unavailable" end
    if not needed then return "Unknown requirements" end
    if level == nil or not F.player.level then return "Skill fits; level unknown" end
    return "Fits level / skill"
end

local function factionMatches(place)
    return F.factionFilter == "All factions" or not place.faction or place.faction == "neutral"
        or place.faction == F.player.faction
end

function F.Places(recipe)
    local data = F.learning[recipe.id] or {}
    local places = {}
    for _, place in ipairs(data.places or {}) do
        if factionMatches(place) then places[#places+1] = place end
    end
    local observed = F.db and F.db.observedSources[recipe.id]
    for _, place in pairs(observed and observed.places or {}) do
        if factionMatches(place) then
            places[#places+1] = place
        end
    end
    return places
end

function F.HasSource(recipe, kind)
    local data = F.learning[recipe.id] or {}
    local observed = F.db and F.db.observedSources[recipe.id]
    if data.kind == kind then
        local places = data.places or {}
        if #places == 0 then return true end
        for _, place in ipairs(places) do if factionMatches(place) then return true end end
    end
    for _, place in pairs(observed and observed.places or {}) do
        if place.kind == kind and factionMatches(place) then return true end
    end
    return false
end

function F.MatchesLearning(recipe)
    local state = F.Eligibility(recipe)
    if F.eligibilityFilter == "Fits level / skill" and state ~= "Fits level / skill" and state ~= "Can learn now" then return false end
    if F.eligibilityFilter == "At my skill" and state ~= "Fits level / skill" and state ~= "Can learn now" and state ~= "Skill fits; level unknown" then return false end
    if F.eligibilityFilter == "Can learn now" and state ~= "Can learn now" then return false end
    if F.eligibilityFilter == "Unknown requirements" and state ~= "Unknown requirements" and state ~= "Skill fits; level unknown" then return false end
    local kind = ({Vendors="vendor", Trainers="trainer", Quests="quest", Drops="drop", ["Unknown sources"]="unknown"})[F.sourceFilter]
    if kind then
        local matches = F.HasSource(recipe, kind)
        if kind == "drop" then matches = matches or F.HasSource(recipe, "worldDrop") or F.HasSource(recipe, "blueprint") or F.HasSource(recipe, "container") end
        if kind == "unknown" then
            local data = F.learning[recipe.id]
            local observed = F.db and F.db.observedSources[recipe.id]
            matches = (not data or data.kind == "unknown") and not (observed and next(observed.places or {}))
        end
        if not matches then return false end
    end
    return true
end

function F.QuestStatus(id)
    if C_QuestLog then
        if safe(C_QuestLog.IsQuestFlaggedCompleted, id) then return "Completed" end
        if safe(C_QuestLog.IsOnQuest, id) then return "In your quest log" end
    end
    return "Not completed or status unavailable"
end

function F.LearningDetails(recipe, compact)
    local data = F.learning[recipe.id] or {}
    local lines = compact and {} or {F.Eligibility(recipe)}
    local skill = F.player.skills[recipe.profession]
    lines[#lines+1] = "Character level: " .. tostring(F.player.level or "?")
        .. (compact and " / required " .. tostring(F.LevelRequirement(recipe) or "unknown") or "")
    lines[#lines+1] = recipe.profession .. ": " .. (skill and tostring(skill.rank) or "not detected")
        .. " / required " .. tostring(F.SkillRequirement(recipe) or "unknown")
    if not compact then
        lines[#lines+1] = "Level required to learn: " .. tostring(F.LevelRequirement(recipe) or "unknown")
        lines[#lines+1] = "Level and skill checks do not confirm stock, currency, reputation, specialization or quest prerequisites."
        if data.recipeItemID then lines[#lines+1] = "Recipe item ID: " .. data.recipeItemID end
    end
    lines[#lines+1] = "\n|cffffcc66Where to learn|r"
    lines[#lines+1] = "Reported source: " .. (F.sourceLabels[data.kind or "unknown"] or data.kind)
    local places = F.Places(recipe)
    for _, place in ipairs(places) do
        local description = (place.name or "NPC not recorded") .. " / " .. (place.zone or "Location unknown")
        if place.x and place.y then description = description .. string.format(" / %.1f, %.1f", place.x, place.y) end
        if place.faction then description = description .. " / " .. place.faction end
        if place.price then description = description .. " / " .. place.price .. " " .. (place.currency or "copper") end
        if place.kind then description = description .. " / " .. (F.sourceLabels[place.kind] or place.kind) end
        lines[#lines+1] = description
        if place.evidence then lines[#lines+1] = place.evidence end
    end
    if #places == 0 then lines[#lines+1] = "No matching NPC location recorded. Try All factions to view other faction sources." end
    local quests = data.quests
    local observed = F.db and F.db.observedSources[recipe.id]
    if not quests and observed then quests = observed.quests end
    if quests then
        lines[#lines+1] = "\n|cffffcc66Quest route|r"
        for index, quest in ipairs(quests) do
            lines[#lines+1] = index .. ". " .. quest.name .. " [" .. quest.id .. "] / " .. F.QuestStatus(quest.id)
            if quest.minLevel then lines[#lines+1] = "Minimum quest level: " .. quest.minLevel end
            if quest.faction then lines[#lines+1] = "Quest faction: " .. quest.faction end
            if quest.giver then lines[#lines+1] = "Start with " .. quest.giver .. " in " .. (quest.zone or "an unrecorded zone") .. "." end
            if quest.objective then lines[#lines+1] = quest.objective end
        end
        lines[#lines+1] = data.questNote or "Earlier prerequisite quests are not recorded."
    elseif data.kind == "quest" then
        lines[#lines+1] = "The quest name and prerequisite chain are not recorded. Use the source link to investigate this recipe."
    end
    if compact then
        lines[#lines+1] = "\nOther restrictions may apply. See Notes for data sources and limits."
    else
        lines[#lines+1] = "\n" .. (data.evidence or "Learning requirements and acquisition sources are not recorded.")
        if data.skillEvidence then lines[#lines+1] = "Skill requirement: " .. data.skillEvidence end
    end
    return table.concat(lines, "\n")
end

-- Request only a small batch of recipe items whose profession skill is met.
-- Level comes from the teaching item, never the finished gear's equip level.
function F.PrimeLevels()
    if F.levelBatchPending then return end
    local wanted = {}
    for _, recipe in ipairs(F.recipes) do
        local data = F.learning[recipe.id]
        local skill = F.player.skills[recipe.profession]
        if data and data.recipeItemID and skill and data.requiredSkill and skill.rank >= data.requiredSkill
            and not F.itemRequested[data.recipeItemID] and not data.removed then
            wanted[#wanted+1] = data.recipeItemID
            if #wanted == 8 then break end
        end
    end
    if #wanted == 0 then return end
    for _, id in ipairs(wanted) do
        F.itemRequested[id] = true
        local name, _, _, _, level = safe(C_Item and C_Item.GetItemInfo or GetItemInfo, id)
        if name and type(level) == "number" then F.itemLevels[id] = level
        elseif C_Item and C_Item.RequestLoadItemDataByID then safe(C_Item.RequestLoadItemDataByID, id) end
    end
    if C_Timer and C_Timer.After then
        F.levelBatchPending = true
        C_Timer.After(0.5, function()
            F.levelBatchPending = nil
            if F.frame and F.frame:IsShown() then F.Refresh() end
        end)
    end
end

local function location(kind)
    local place = {name=safe(UnitName, "npc") or "Unknown NPC", zone=safe(GetZoneText),
                   kind=kind, faction=F.player.faction, evidence="Observed on this character"}
    local map = C_Map and safe(C_Map.GetBestMapForUnit, "player")
    local point = map and safe(C_Map.GetPlayerMapPosition, map, "player")
    if point and point.GetXY then
        local x,y = safe(point.GetXY, point)
        if x and y then place.x, place.y = x*100, y*100 end
    end
    return place
end
local function record(id, place)
    if not F.db then F.Initialize() end
    local entry = F.db.observedSources[id] or {places={}}
    entry.places = entry.places or {}
    entry.places[place.kind .. ":" .. place.name .. ":" .. (place.zone or "")] = place
    F.db.observedSources[id] = entry
    return entry
end
local function findRecipe(name, profession)
    local found
    for _, recipe in ipairs(F.recipes) do
        if (not profession or recipe.profession == profession) and (F.SpellName(recipe.id) or recipe.name) == name then
            if found then return nil end
            found = recipe.id
        end
    end
    return found
end
function F.ScanTrainer()
    F.ReadPlayer()
    F.liveTrainer = {}
    for index=1, safe(GetNumTrainerServices) or 0 do
        local name, _, state = safe(GetTrainerServiceInfo, index)
        if name and state ~= "header" then
            local skillName, rank = safe(GetTrainerServiceSkillReq, index)
            local profession = F.ProfessionName(skillName or safe(GetTrainerServiceSkillLine,index))
            local id = findRecipe(name, profession)
            if id then
                local observed = record(id, location("trainer"))
                observed.requiredLevel = safe(GetTrainerServiceLevelReq, index)
                if profession == F.byID[id].profession and type(rank) == "number" then observed.requiredSkill = rank end
                local cost = safe(GetTrainerServiceCost,index)
                local money = safe(GetMoney)
                F.liveTrainer[id] = state == "available" and cost and money and money >= cost and "available" or state == "used" and "used" or "unavailable"
                if state == "used" then F.Observe(id, "Trainer shows learned") end
            end
        end
    end
    if F.Refresh then F.Refresh() end
end
function F.ScanMerchant()
    F.ReadPlayer()
    for index=1, safe(GetMerchantNumItems) or 0 do
        local link = safe(GetMerchantItemLink,index)
        local itemID = link and tonumber(link:match("item:(%d+)"))
        for _, id in ipairs(F.recipeItems[itemID] or {}) do record(id, location("vendor")) end
    end
    if F.Refresh then F.Refresh() end
end
function F.ScanQuest()
    F.ReadPlayer()
    local questID, name = safe(GetQuestID), safe(GetTitleText)
    if not questID or questID <= 0 or not name then return end
    for _, kind in ipairs({"reward","choice"}) do
        local count = safe(kind == "reward" and GetNumQuestRewards or GetNumQuestChoices) or 0
        for index=1,count do
            local link = safe(GetQuestItemLink,kind,index)
            local itemID = link and tonumber(link:match("item:(%d+)"))
            for _, id in ipairs(F.recipeItems[itemID] or {}) do
                local place = location("quest")
                local observed = record(id, place)
                observed.quests = {{id=questID, name=name, giver=place.name, zone=place.zone,
                    url="https://www.wowhead.com/forever/quest=" .. questID}}
            end
        end
    end
end

local events = CreateFrame("Frame")
for _, event in ipairs({"PLAYER_LOGIN","PLAYER_LEVEL_UP","SKILL_LINES_CHANGED","TRAINER_SHOW","TRAINER_UPDATE",
    "TRAINER_CLOSED","MERCHANT_SHOW","MERCHANT_UPDATE","QUEST_DETAIL","QUEST_COMPLETE","QUEST_LOG_UPDATE",
    "GET_ITEM_INFO_RECEIVED","ITEM_DATA_LOAD_RESULT","PLAYER_MONEY"}) do pcall(events.RegisterEvent,events,event) end
events:SetScript("OnEvent",function(_,event,id)
    if event == "TRAINER_SHOW" then F.trainerOpen = true; F.ScanTrainer(); return end
    if F.trainerOpen and (event == "TRAINER_UPDATE" or event == "PLAYER_MONEY" or event == "SKILL_LINES_CHANGED") then
        F.ScanTrainer(); return
    end
    if event == "TRAINER_CLOSED" then F.trainerOpen = nil; F.liveTrainer = {} end
    if event == "MERCHANT_SHOW" or event == "MERCHANT_UPDATE" then F.ScanMerchant(); return end
    if event == "QUEST_DETAIL" or event == "QUEST_COMPLETE" then F.ScanQuest() end
    if event == "GET_ITEM_INFO_RECEIVED" or event == "ITEM_DATA_LOAD_RESULT" then
        if not F.recipeItems[id] or not F.itemRequested[id] then return end
        local name, _, _, _, level = safe(C_Item and C_Item.GetItemInfo or GetItemInfo,id)
        if name and type(level) == "number" then F.itemLevels[id] = level end
    end
    F.ReadPlayer()
    if F.frame and F.frame:IsShown() then F.Refresh() end
end)
