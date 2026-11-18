-- Runtime regressions use the same mock client as the existing tests.
local globalNames = {"C_TradeSkillUI", "GetProfessions", "GetProfessionInfo", "GetNumSkillLines",
    "GetTradeSkillLine", "GetNumTradeSkills", "GetTradeSkillInfo", "GetTradeSkillRecipeLink",
    "GetCraftDisplaySkillLine", "GetNumCrafts", "GetCraftInfo", "GetCraftRecipeLink",
    "GetSpellInfo", "C_Spell", "C_Timer", "ProfessionsFrame", "IsTradeSkillLinked",
    "GetMerchantNumItems", "GetMerchantItemLink", "UnitName"}
local fieldNames = {"Refresh", "AttachButton", "db", "sessionKnown", "player", "liveTrainer",
    "tradeOpen", "activeScanKind", "professionClosed", "lastModernIDs", "profession",
    "scanToken", "scanManualPending", "scanReason", "scanProfession", "lastScan", "merchantOpen"}
local globals, fields = {}, {}
for _, name in ipairs(globalNames) do globals[name] = _G[name] end
for _, name in ipairs(fieldNames) do fields[name] = F[name] end
local tradeShown, craftShown = TradeSkillFrame:IsShown(), CraftFrame:IsShown()
local coreEvents, learningEvents
for _, frame in ipairs(frames) do
    if frame.events.ADDON_LOADED then coreEvents = frame end
    if frame.events.TRAINER_SHOW then learningEvents = frame end
end
local function coreEvent(name) coreEvents.scripts.OnEvent(coreEvents, name) end
local function learningEvent(name) learningEvents.scripts.OnEvent(learningEvents, name) end
local callbacks = {}
C_Timer = {After=function(_, callback) callbacks[#callbacks+1] = callback end}
local function drain()
    local count = 0
    while #callbacks > 0 do
        count = count + 1
        assert(count <= 10, "Runtime retries must remain bounded")
        table.remove(callbacks, 1)()
    end
end
F.Refresh, F.AttachButton = nil, function() end
F.db, F.sessionKnown = {known={}, observedSources={}}, {}
coreEvent("TRADE_SKILL_CLOSE")
F.tradeOpen, F.activeScanKind, F.professionClosed = nil, nil, nil
F.scanManualPending = nil
GetProfessions, GetNumSkillLines, IsTradeSkillLinked, C_Spell = nil, nil, nil, nil
ProfessionsFrame = nil
TradeSkillFrame:Hide(); CraftFrame:Hide()
C_TradeSkillUI = {
    IsTradeSkillReady=function() return true end,
    GetAllRecipeIDs=function() return {3979} end,
    GetRecipeInfo=function() return {learned=true} end,
    GetBaseProfessionInfo=function()
        return {professionName="Engineering", skillLevel=180, maxSkillLevel=225}
    end,
}

-- Headless API discovery still works before a client has reported closure.
local count, reason = F.Scan()
assert(count == 1 and reason == "ok" and F.sessionKnown[3979])
coreEvent("TRADE_SKILL_DETAILS_UPDATE")
assert(#callbacks == 1)
coreEvent("TRADE_SKILL_CLOSE")
assert(F.lastModernIDs == nil)
F.sessionKnown, F.db.known = {}, {}
drain()
assert(not F.sessionKnown[3979],
    "A delayed update must not promote cached recipes after the close event")
count, reason = F.Scan()
assert(count == 0 and reason == "closed")
F.ReadPlayer()
assert(not F.player.skills.Engineering,
    "A closed profession's cached skill must not become the current skill")
coreEvent("TRADE_SKILL_DATA_SOURCE_CHANGED")
assert(not F.tradeOpen and F.professionClosed,
    "A late data-source event must not reopen the profession")
coreEvent("TRADE_SKILL_SHOW")
assert(F.sessionKnown[3979] and not F.professionClosed,
    "The next show event must allow scanning without requiring a known frame")

-- A partially populated legacy list must retry instead of declaring success.
C_TradeSkillUI = nil
TradeSkillFrame:Show()
F.sessionKnown, F.db.known = {}, {}
local secondReady = false
GetTradeSkillLine=function() return "Engineering", 180, 225 end
GetNumTradeSkills=function() return 2 end
GetTradeSkillInfo=function(index)
    if index == 1 then return "Accurate Scope", "optimal" end
    if secondReady then return "Second recipe", "optimal" end
end
GetTradeSkillRecipeLink=function(index)
    return "|Henchant:" .. (index == 1 and 3979 or 1293088) .. "|h[Recipe]|h"
end
F.RequestScan("trade")
assert(F.scanReason == "waiting" and F.sessionKnown[3979] and not F.sessionKnown[1293088])
secondReady = true
drain()
assert(F.scanReason == "ok" and F.sessionKnown[1293088])

-- Localized spell data can arrive after the first name index was built.
F.sessionKnown, F.db.known = {}, {}
local localizedReady = false
GetNumTradeSkills=function() return 1 end
GetTradeSkillInfo=function() return "Localized Accurate Scope", "optimal" end
GetTradeSkillRecipeLink=function() return nil end
GetSpellInfo=function(id)
    if localizedReady and id == 3979 then return "Localized Accurate Scope" end
end
F.RequestScan("trade")
assert(F.scanReason == "waiting" and not F.sessionKnown[3979])
localizedReady = true
drain()
assert(F.scanReason == "ok" and F.sessionKnown[3979],
    "Retrying must rebuild the profession's localized recipe names")

-- The separate Craft API needs the same partial-list retry behavior.
F.sessionKnown, F.db.known = {}, {}
TradeSkillFrame:Hide(); CraftFrame:Show()
local craftReady = false
GetCraftDisplaySkillLine=function() return "Enchanting" end
GetNumCrafts=function() return 2 end
GetCraftInfo=function(index)
    if index == 1 or craftReady then return "Enchant", "", "optimal" end
end
GetCraftRecipeLink=function(index)
    return "|Henchant:" .. (index == 1 and 27837 or 25124) .. "|h[Enchant]|h"
end
F.RequestScan("craft")
assert(F.scanReason == "waiting" and F.sessionKnown[27837] and not F.sessionKnown[25124])
craftReady = true
drain()
assert(F.scanReason == "ok" and F.sessionKnown[25124])

-- A current affordable trainer offer overrides stale imported requirements.
local recipe = F.byID[3979]
local learning = F.learning[3979]
F.learning[3979] = {requiredSkill=999, requiredLevel=999}
F.sessionKnown, F.db.known, F.db.observedSources = {}, {}, {}
F.player = {level=20, skills={Engineering={rank=180}}}
F.liveTrainer = {[3979]="available"}
assert(F.Eligibility(recipe) == "Can learn now")
F.liveTrainer = {}
assert(F.Eligibility(recipe) == "Needs skill 999",
    "Without a live offer, the recorded requirement still applies")
F.learning[3979] = learning

-- Cached merchant rows must not record a different NPC after merchant close.
CraftFrame:Hide(); F.tradeOpen, F.professionClosed = nil, true
GetMerchantNumItems=function() return 1 end
GetMerchantItemLink=function() return "|Hitem:13310|h[Schematic: Accurate Scope]|h" end
local npcName = "Actual merchant"
UnitName=function() return npcName end
learningEvent("MERCHANT_SHOW")
local places = F.db.observedSources[3979].places
local placeCount = 0
for _ in pairs(places) do placeCount = placeCount + 1 end
assert(placeCount == 1)
learningEvent("MERCHANT_CLOSED")
npcName = "Different target"
learningEvent("MERCHANT_UPDATE")
placeCount = 0
for _, place in pairs(places) do
    placeCount = placeCount + 1
    assert(place.name == "Actual merchant")
end
assert(placeCount == 1)

for _, name in ipairs(globalNames) do _G[name] = globals[name] end
for _, name in ipairs(fieldNames) do F[name] = fields[name] end
TradeSkillFrame:SetShown(tradeShown); CraftFrame:SetShown(craftShown)
print("PASS: closed profession caches, delayed legacy/localized scans, trainer precedence and merchant closure.")
