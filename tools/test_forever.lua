F = {}
frames = {}
messages = {}
local methods = {}
function methods:SetScript(event, fn) self.scripts[event] = fn end
function methods:RegisterEvent(event) self.events[event] = true end
function methods:SetText(text)
 self.text = tostring(text)
 if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self) end
end
function methods:GetText() return self.text or "" end
function methods:SetSize(w,h) self.w,self.h=w,h end
function methods:SetWidth(w) self.w=w end
function methods:SetHeight(h) self.h=h end
function methods:GetWidth() return self.w or 1920 end
function methods:GetHeight() return self.h or 1080 end
function methods:GetStringHeight() return 500 end
function methods:Show() self.shown=true end
function methods:Hide() self.shown=false end
function methods:IsShown() return self.shown end
function methods:SetShown(b) self.shown=b end
function methods:SetEnabled(b) self.enabled=b end
function methods:SetVerticalScroll(n) self.scroll=n end
function methods:SetScale(n) self.scale=n end
function methods:GetEffectiveScale() return self.scale or 1 end
function methods:GetCenter() return 960,540 end
function methods:SetPoint(...) self.point={...} end
function methods:SetScrollChild(child) self.child=child end
function methods:SetTexture(path) self.texture=path end
function methods:SetChecked(value) self.checked=value end
function methods:GetChecked() return self.checked end
function methods:SetFrameLevel(value) self.frameLevel=value end
function methods:GetFrameLevel() return self.frameLevel or 1 end
function methods:SetMinMaxValues(low,high) self.low,self.high=low,high end
function methods:SetValue(value) self.value=value end
for _, name in ipairs({"SetJustifyH","SetJustifyV","SetAllPoints","SetColorTexture","SetBackdrop",
 "SetBackdropBorderColor","SetBackdropColor","ClearAllPoints","SetClampedToScreen","SetMovable","EnableMouse",
 "SetFrameStrata","RegisterForDrag","StartMoving","StopMovingOrSizing","RegisterForClicks",
 "SetAutoFocus","SetMaxLetters","ClearFocus","EnableMouseWheel","SetHighlightTexture",
 "SetWordWrap","SetSpacing","HighlightText","SetOwner","AddLine","SetTexCoord",
 "SetStatusBarTexture","SetStatusBarColor"}) do methods[name]=function() end end
function CreateFrame(kind,name,parent,template)
 local obj=setmetatable({scripts={},events={},shown=true}, {__index=methods})
 frames[#frames+1]=obj
 if name then _G[name]=obj end
 return obj
end
function methods:CreateTexture() return CreateFrame("Texture") end
function methods:CreateFontString() return CreateFrame("FontString") end
UIParent=CreateFrame("Frame")
UIParent:SetSize(1920,1080)
GameTooltip=CreateFrame("Frame")
BackdropTemplateMixin={}
UISpecialFrames={}
SlashCmdList={}
tinsert=table.insert
DEFAULT_CHAT_FRAME={AddMessage=function(_,text) messages[#messages+1]=text end}
time=function() return 123456 end
GetSpellInfo=function() return nil end
IsSpellKnown=function() return false end
IsPlayerSpell=function() return false end
C_Timer={After=function(_,f) f() end}
-- LOAD ADDON HERE
F.Initialize()
assert(#F.recipes == 2258 and #F.professions == 14)
assert(F.byID[1263078].items[1].id == 279990)
assert(F.byID[1263078].reagents[1].quantity == 1)
assert(F.byID[1249957].name == "Peace Tea")
assert(F.byID[1293088].items[1].id == 274048)
assert(F.byID[1293088].items[1].name == "Unnamed item 274048")
local outputs, reagents = 0, 0
for _, r in ipairs(F.recipes) do
 outputs = outputs + #r.items
 reagents = reagents + #r.reagents
 for _, ingredient in ipairs(r.reagents) do assert(ingredient.id > 0 and ingredient.quantity > 0) end
end
assert(outputs == 2091 and reagents == 7481)
assert(F.learning[3755].requiredSkill == 1 and F.learning[3755].kind == "profession")
assert(not F.learning[3755].recipeItemID, "Linen Bag needs no teaching item")
assert(F.learning[3275].requiredSkill == 1, "Linen Bandage is a starting recipe")
assert(F.learning[2667].requiredSkill == 90, "Use Forever's Runed Copper Breastplate requirement")
assert(F.learning[25124].requiredSkill == 5, "Minor Wizard Oil requires skill 5")
assert(F.learning[3757].requiredSkill == nil, "Unknown trainer requirements must not use Classic fallback")
for _, id in ipairs({1301455,1301461,1301431,1301437}) do
 local recipe=F.byID[id]
 assert(#recipe.reagents == 2 and recipe.correctionURL)
 for _, reagent in ipairs(recipe.reagents) do assert(reagent.id ~= 4321) end
end
local savedPlayer=F.player
F.player={level=5,skills={Tailoring={rank=1,max=75}}}
F.eligibilityFilter="At my skill"
assert(F.MatchesLearning(F.byID[3755]), "A beginning tailor must see Linen Bag at skill 1")
F.player.skills.Tailoring.rank=0
assert(not F.MatchesLearning(F.byID[3755]), "The skill filter must enforce the lower boundary")
F.player=savedPlayer; F.eligibilityFilter="Any requirements"
assert(F.LinkID("|cfff|Hitem:3979|h[X]|h") == nil)
assert(F.LinkID("|cfff|Henchant:3979|h[X]|h") == 3979)
assert(F.LinkID("|Hspell:3979|h[X]|h") == 3979)
F.query="peace tea"; assert(#F.Results()==1)
F.query="["; assert(#F.Results()==0)
F.query=""; F.profession="Engineering"; assert(#F.Results()==250)
F.profession="All professions"
F.db.known[3979]={method="Old session"}; assert(F.Status(F.byID[3979])=="Previously seen")

-- A filtered profession window records only visible positives.
TradeSkillFrame=CreateFrame("Frame")
GetTradeSkillLine=function() return "Engineering",100,150 end
GetNumTradeSkills=function() return 2 end
GetTradeSkillInfo=function(i) if i==1 then return "Scopes","header" end return "Accurate Scope","optimal" end
GetTradeSkillRecipeLink=function(i) if i==2 then return "|Henchant:3979|h[Accurate Scope]|h" end end
F.Scan()
assert(F.Status(F.byID[3979])=="Learned")
assert(F.Status(F.byID[1293088])=="Not seen")
assert(F.profession=="Engineering")
F.sessionKnown={}; F.db.known={}
IsTradeSkillLinked=function() return true end
F.Scan(); assert(F.Status(F.byID[3979])=="Not seen")
IsTradeSkillLinked=nil
TradeSkillFrame:Hide()

-- A modern client must not add unlearned or another player's recipes.
C_TradeSkillUI={GetAllRecipeIDs=function() return {3979,1293088} end,
 GetRecipeInfo=function(id) return {learned=id==3979} end}
F.Scan(); assert(F.Status(F.byID[3979])=="Learned" and F.Status(F.byID[1293088])=="Not seen")
F.sessionKnown={}; F.db.known={}
C_TradeSkillUI.IsTradeSkillGuild=function() return true end
F.Scan(); assert(F.Status(F.byID[3979])=="Not seen")
C_TradeSkillUI=nil

-- Enchanting uses the separate Craft API.
CraftFrame=CreateFrame("Frame")
GetCraftDisplaySkillLine=function() return "Enchanting" end
GetNumCrafts=function() return 2 end
GetCraftInfo=function(i) if i==1 then return "Enchanting","","header" end return "Recipe","","optimal" end
local enchanting
for _, r in ipairs(F.recipes) do if r.profession=="Enchanting" then enchanting=r.id; break end end
GetCraftRecipeLink=function(i) if i==2 then return "|Henchant:"..enchanting.."|h[Recipe]|h" end end
F.Scan(); assert(F.sessionKnown[enchanting] and F.profession=="Enchanting")
CraftFrame:Hide()
F.sessionKnown={}; F.db.known={}
IsSpellKnown=function() error("Unsupported") end
F.Scan(); assert(not next(F.sessionKnown))
IsSpellKnown=function(id) return id==1249957 end
F.Scan(); assert(F.Status(F.byID[1249957])=="Not seen", "A closed profession must not trigger a catalog-wide spellbook scan")

-- Construct the actual UI with explicit frame-method stubs.
F.query=""; F.profession="All professions"; F.filter="All records"
F.Show(); assert(F.frame:IsShown() and #F.results==2258 and F.pages==174)
F.Select(F.byID[1263078])
F.detailTab="Materials"; F.RenderDetails()
assert(F.detailText:GetText():find("Lich's Index Finger",1,true))
F.detailTab="Notes"; F.RenderDetails()
assert(F.detailText:GetText():find("not minimum learning requirements",1,true))
F.detailTab="Learn"; F.RenderDetails()
assert(F.url:GetText():find("wowfwiki.com",1,true))
F.next.scripts.OnClick(); assert(F.page==2)
F.page=999; F.Refresh(); assert(F.page==174 and not F.next.enabled)
F.search:SetText("zzzzneverarecipe"); assert(#F.results==0 and F.page==1 and F.empty:IsShown())
F.Command("Peace Tea"); assert(#F.results==1)
F.Command("forget"); assert(not next(F.db.known) and not next(F.sessionKnown))
F.Command("resetpos"); assert(F.db.position==nil)
F.Command("help"); assert(#messages>=2)
F.AttachButton("trade"); F.AttachButton("craft")
assert(F.scanButtons[TradeSkillFrame] and F.scanButtons[CraftFrame])
for _, frame in ipairs(frames) do
 if frame.events.ADDON_LOADED then
  frame.scripts.OnEvent(frame,"ADDON_LOADED","ForeverRecipeFinder")
  frame.scripts.OnEvent(frame,"PLAYER_LOGIN")
  frame.scripts.OnEvent(frame,"NEW_RECIPE_LEARNED",3979)
  assert(F.sessionKnown[3979])
 end
end
print("PASS: data, search, professions, saved status, legacy/modern/craft scans, linked/guild rejection, optional APIs, UI and events.")

-- Learning filters use character and profession requirements independently.
F.frame:Hide()
C_Timer.After=function() end
F.sessionKnown={}; F.db.known={}; F.db.observedSources={}
F.query=""; F.filter="All records"; F.profession="All professions"
local playerLevel, engineeringRank, money = 20, 180, 100
UnitLevel=function() return playerLevel end
UnitFactionGroup=function() return "Alliance" end
GetProfessions=function() return 1,nil,nil,nil,5 end
GetProfessionInfo=function(i)
 if i==1 then return "Engineering",0,engineeringRank,225 end
 if i==5 then return "Cooking",0,35,75 end
end
IsSpellKnown=function() return false end
F.ReadPlayer()
assert(F.player.skills.Engineering.rank==180 and F.player.skills.Cooking.rank==35)
assert(F.player.level==20 and F.player.faction=="alliance")
local scope=F.byID[3979]
local scopeData=F.learning[3979]
F.itemLevels={}
assert(F.Eligibility(scope)=="Skill fits; level unknown")
F.eligibilityFilter="Fits level / skill"; assert(not F.MatchesLearning(scope))
F.eligibilityFilter="At my skill"; assert(F.MatchesLearning(scope))
F.itemLevels[scope.items[1].id]=60
assert(F.LevelRequirement(scope)==nil, "Output equipment level must not become learning level")
F.itemLevels[scopeData.recipeItemID]=20
assert(F.Eligibility(scope)=="Fits level / skill")
playerLevel=19; F.ReadPlayer(); assert(F.Eligibility(scope)=="Needs level 20")
playerLevel=20; engineeringRank=179; F.ReadPlayer(); assert(F.Eligibility(scope)=="Needs skill 180")
engineeringRank=180; F.ReadPlayer(); assert(F.Eligibility(scope)=="Fits level / skill")
F.sessionKnown[3979]=true; assert(not F.MatchesLearning(scope))
F.sessionKnown={}; F.db.known[3979]={}; assert(not F.MatchesLearning(scope))
F.db.known={}
F.learning[3979]={kind="unknown",places={}}
assert(F.Eligibility(scope)=="Unknown requirements" and not F.MatchesLearning(scope))
F.learning[3979]=scopeData

-- Each acquisition type applies the faction restriction to its own locations.
F.eligibilityFilter="Any requirements"; F.sourceFilter="Vendors"; F.factionFilter="My faction"
F.learning[3979]={kind="vendor",requiredSkill=180,places={{name="Horde vendor",faction="horde"}}}
F.db.observedSources[3979]={places={trainer={name="Alliance trainer",kind="trainer",faction="alliance"}}}
assert(not F.MatchesLearning(scope), "An unrelated Alliance source must not admit a Horde vendor")
F.sourceFilter="Trainers"; assert(F.MatchesLearning(scope))
F.sourceFilter="Vendors"; F.factionFilter="All factions"; assert(F.MatchesLearning(scope))
F.factionFilter="My faction"
F.learning[3979]={kind="unknown",places={}}
F.sourceFilter="Unknown sources"; assert(not F.MatchesLearning(scope))
F.db.observedSources={}
assert(F.MatchesLearning(scope))
F.learning[3979]=scopeData

-- Trainer state is authoritative only while the trainer is open and affordable.
F.sourceFilter="All sources"
UnitName=function(unit) if unit=="npc" then return "Test trainer" end end
GetZoneText=function() return "Test zone" end
GetNumTrainerServices=function() return 1 end
GetTrainerServiceInfo=function() return "Accurate Scope","","available" end
GetTrainerServiceSkillReq=function() return "Engineering",180,true end
GetTrainerServiceLevelReq=function() return 20 end
GetTrainerServiceCost=function() return 100 end
GetMoney=function() return money end
local learningEvents
for _,frame in ipairs(frames) do if frame.events.TRAINER_SHOW then learningEvents=frame end end
assert(learningEvents)
local function event(name,id) learningEvents.scripts.OnEvent(learningEvents,name,id) end
event("TRAINER_SHOW")
assert(F.Eligibility(scope)=="Can learn now")
F.eligibilityFilter="Can learn now"; assert(F.MatchesLearning(scope))
money=99; event("PLAYER_MONEY"); assert(not F.MatchesLearning(scope))
money=100; event("PLAYER_MONEY"); assert(F.MatchesLearning(scope))
scopeData.removed=1
assert(F.MatchesLearning(scope), "A current trainer offer overrides a reported removal")
scopeData.removed=nil
event("TRAINER_CLOSED"); assert(not F.MatchesLearning(scope))
event("TRAINER_UPDATE"); assert(not F.MatchesLearning(scope), "Late updates must not reopen a closed trainer")
assert(F.db.observedSources[3979].requiredLevel==20)
F.learning[3979]=nil
assert(F.LevelRequirement(scope)==20, "Observed requirements must work without imported data")
F.learning[3979]=scopeData

-- Merchant visits record a source, without claiming the character can learn it.
F.db.observedSources={}
GetMerchantNumItems=function() return 1 end
GetMerchantItemLink=function() return "|Hitem:13310|h[Schematic: Accurate Scope]|h" end
UnitName=function() return "Observed shopkeeper" end
F.ScanMerchant()
assert(F.HasSource(scope,"vendor") and F.Status(scope)=="Not seen")
assert(F.LearningDetails(scope):find("Observed shopkeeper",1,true))

-- Failed item loads leave unknown requirements. A later response can fill them.
F.db.observedSources={}; F.itemLevels={}; F.itemRequested={[13310]=true}
GetItemInfo=function() return nil end
event("GET_ITEM_INFO_RECEIVED",13310); assert(F.LevelRequirement(scope)==nil)
GetItemInfo=function(id)
 if id==13310 then return "Schematic: Accurate Scope","",1,60,0 end
end
event("GET_ITEM_INFO_RECEIVED",13310); assert(F.LevelRequirement(scope)==0)
assert(F.Eligibility(scope)=="Fits level / skill")

-- Quest state identifies the next known step without inventing prerequisites.
C_QuestLog={
 IsQuestFlaggedCompleted=function(id) return id==8307 end,
 IsOnQuest=function(id) return id==8313 end,
}
assert(F.QuestStatus(8307)=="Completed")
assert(F.QuestStatus(8313)=="In your quest log")
F.eligibilityFilter="Any requirements"
F.Select(F.byID[24801]); F.urlMode="quest"; F.SetSourceLink()
assert(F.url:GetText():find("quest=8313",1,true))
assert(F.LearningDetails(F.byID[1270635]):find("earlier prerequisites are not verified",1,true))
GetQuestID=function() return 12345 end
GetTitleText=function() return "Observed reward quest" end
GetNumQuestRewards=function() return 1 end
GetNumQuestChoices=function() return 0 end
GetQuestItemLink=function() return "|Hitem:13310|h[Schematic: Accurate Scope]|h" end
event("QUEST_DETAIL")
assert(F.db.observedSources[3979].quests[1].id==12345 and F.HasSource(scope,"quest"))
assert(F.Status(scope)=="Not seen")

-- Forgetting a profession must remove it from the current skill shortlist.
GetProfessions=function() return nil end
F.ReadPlayer(); assert(F.Eligibility(scope)=="Profession not detected")
GetNumSkillLines=function() return 2 end
GetSkillLineInfo=function(i)
 if i==1 then return "Professions",true end
 return "Engineering",false,false,180,0,0,225
end
F.ReadPlayer(); assert(F.player.skills.Engineering.rank==180)
assert(F.Eligibility(scope)=="Fits level / skill")
ForeverRecipeFinderDB={known={[3979]={method="Earlier version"}}}
F.Initialize()
assert(F.db.version==2 and F.db.known[3979] and type(F.db.observedSources)=="table")
print("PASS: learning boundaries, unknown data, profession detection, faction/source filters, trainer money/close events, merchant observations, item levels, quest routes and saved-data migration.")

-- Exercise the new controls through their click handlers.
F.ResetFilters()
F.profession="All professions"; F.Refresh()
assert(#F.results==2258 and F.progress.high==2258)
F.professionButton.scripts.OnClick(F.professionButton)
assert(F.menuShield:IsShown() and #F.menuRows>=14)
for _,row in ipairs(F.menuRows) do
 if row.caption:GetText()=="Cooking" then row.scripts.OnClick(); break end
end
assert(F.profession=="Cooking" and not F.menuShield:IsShown())
for _,recipe in ipairs(F.results) do assert(recipe.profession=="Cooking") end
F.eligibilityButton.scripts.OnClick(F.eligibilityButton)
assert(F.menuShield:IsShown())
F.eligibilityButton.scripts.OnClick(F.eligibilityButton)
assert(not F.menuShield:IsShown(), "A second click must close the same menu")
F.sortButton.scripts.OnClick(F.sortButton)
for _,row in ipairs(F.menuRows) do
 if row:IsShown() and row.caption:GetText()=="Skill" then row.scripts.OnClick(); break end
end
assert(F.sortMode=="Skill")
local last=-1
for _,recipe in ipairs(F.results) do
 local needed=F.SkillRequirement(recipe) or 9999
 assert(needed>=last); last=needed
end
F.sourceButtons[2].scripts.OnClick()
assert(F.sourceFilter=="Vendors")
for _,recipe in ipairs(F.results) do assert(F.HasSource(recipe,"vendor")) end
F.factionButton:SetChecked(false); F.factionButton.scripts.OnClick(F.factionButton)
assert(F.factionFilter=="All factions")
F.resetButton.scripts.OnClick()
assert(F.sourceFilter=="All sources" and F.factionFilter=="My faction" and F.profession=="Cooking")
F.Select(F.byID[1270633])
F.detailTabs[2].scripts.OnClick()
assert(F.detailTab=="Materials" and F.detailText:GetText():find("Materials",1,true))
F.detailTabs[3].scripts.OnClick()
assert(F.detailTab=="Notes" and F.detailText:GetText():find("Wiki evidence",1,true))
F.detailTabs[1].scripts.OnClick()
assert(F.detailTab=="Learn" and F.detailText:GetText():find("Restocking the Larders",1,true))
assert(not F.detailText:GetText():find("Classic/TBC fallback",1,true), "Long evidence belongs on Notes")
F.professionButton.scripts.OnClick(F.professionButton)
F.frame.scripts.OnHide()
assert(not F.menuShield:IsShown())
F.search:SetText("zzzzneverarecipe")
assert(F.selected==nil and F.detailName:GetText()=="Choose a recipe" and F.empty:IsShown())
F.search:SetText("")
assert(F.selected and not F.empty:IsShown())
print("PASS: dropdown selection/dismissal, skill sorting, source buttons, faction checkbox, filter reset, detail tabs, progress totals and empty-selection cleanup.")

-- Native item comparison must receive the crafted item, even for unseen recipes.
F.frame:Show(); F.sessionKnown={}; F.db.known={}; F.db.compareGear=nil
local nativeComparisons, requestedItems={},{}
local itemReady, shiftDown=true,false
local chest, food, enchant=F.byID[9813],F.byID[1270633],F.byID[27837]
function GameTooltip:SetOwner(owner) self.owner=owner; self.lines={}; self.hyperlink=nil end
function GameTooltip:GetOwner() return self.owner end
function GameTooltip:SetText(text) self.text=text; self.lines={text}; self.hyperlink=nil end
function GameTooltip:AddLine(text) table.insert(self.lines,text) end
function GameTooltip:SetHyperlink(link) self.hyperlink=link; self.lines={"Native item stats"} end
function GameTooltip:SetSpellByID(id) self.spell=id; self.hyperlink=nil; self.lines={"Native spell effect"} end
GameTooltip.shoppingTooltips={CreateFrame("Frame"),CreateFrame("Frame")}
GameTooltip_HideShoppingTooltips=function(tooltip)
 for _,shopping in ipairs(tooltip.shoppingTooltips) do shopping:Hide() end
end
GameTooltip_ShowCompareItem=function(tooltip)
 assert(tooltip==GameTooltip and tooltip.hyperlink)
 nativeComparisons[#nativeComparisons+1]=tooltip.hyperlink
 tooltip.shoppingTooltips[1]:Show()
end
C_Item={
 GetItemInfo=function(id)
  if not itemReady then return nil end
  if id==7914 then return "Barbaric Iron Breastplate","|Hitem:7914|h[Barbaric Iron Breastplate]|h",2,32,27,"Armor","Mail",1,"INVTYPE_CHEST" end
  if id==263509 then return "Skywall Souffle","|Hitem:263509|h[Skywall Souffle]|h",1,5,0,"Consumable","Food",20,"" end
 end,
 IsEquippableItem=function(id) return id==7914 end,
 RequestLoadItemDataByID=function(id) requestedItems[#requestedItems+1]=id end,
}
IsModifiedClick=function(kind) return kind=="COMPAREITEMS" and shiftDown end
GetCVarBool=function() return false end
local hoverRow=F.rows[1]
hoverRow:Show(); hoverRow.recipe=chest
hoverRow.scripts.OnEnter(hoverRow)
assert(F.Status(chest)=="Not seen" and F.itemHover.itemID==7914)
assert(#nativeComparisons==1 and nativeComparisons[1]:find("item:7914",1,true))
assert(not nativeComparisons[1]:find("item:7979",1,true), "Never compare the teaching recipe item")
assert(GameTooltip.shoppingTooltips[1]:IsShown())
F.compareButton:SetChecked(false); F.compareButton.scripts.OnClick(F.compareButton)
assert(F.db.compareGear==false and not GameTooltip.shoppingTooltips[1]:IsShown())
local tooltipEvents
for _,frame in ipairs(frames) do if frame.events.PLAYER_EQUIPMENT_CHANGED then tooltipEvents=frame end end
assert(tooltipEvents)
local function tooltipEvent(name,id) tooltipEvents.scripts.OnEvent(tooltipEvents,name,id) end
shiftDown=true; tooltipEvent("MODIFIER_STATE_CHANGED")
assert(GameTooltip.shoppingTooltips[1]:IsShown())
local before=#nativeComparisons
tooltipEvent("PLAYER_EQUIPMENT_CHANGED",5)
assert(#nativeComparisons>before, "Equipment changes must refresh the native comparison")
shiftDown=false; tooltipEvent("MODIFIER_STATE_CHANGED")
assert(not GameTooltip.shoppingTooltips[1]:IsShown())
F.db.compareGear=true

-- Recycled rows switch their tooltip to the new item; consumables do not compare.
before=#nativeComparisons
hoverRow.recipe=food; hoverRow:UpdateTooltip()
assert(F.itemHover.itemID==263509 and GameTooltip.hyperlink:find("item:263509",1,true))
assert(#nativeComparisons==before and not GameTooltip.shoppingTooltips[1]:IsShown())
hoverRow.recipe=enchant; hoverRow:UpdateTooltip()
assert(GameTooltip.spell==27837 and GameTooltip.hyperlink==nil and #nativeComparisons==before)
hoverRow.scripts.OnLeave(hoverRow)
assert(F.itemHover==nil and not GameTooltip:IsShown())

-- Item data loading only requests the output item and does not invent stats.
itemReady=false; hoverRow.recipe=chest; hoverRow.scripts.OnEnter(hoverRow)
assert(F.itemHover.loading and requestedItems[#requestedItems]==7914)
assert(#nativeComparisons==before and GameTooltip.hyperlink==nil)
local requests=#requestedItems
tooltipEvent("GET_ITEM_INFO_RECEIVED",7914)
assert(#requestedItems==requests and F.itemHover.loading)
itemReady=true; tooltipEvent("ITEM_DATA_LOAD_RESULT",7914)
assert(not F.itemHover.loading and #nativeComparisons>before)
before=#nativeComparisons
tooltipEvent("ITEM_DATA_LOAD_RESULT",7979)
assert(#nativeComparisons==before, "Unrelated teaching-item responses must not replace the output tooltip")
hoverRow.scripts.OnLeave(hoverRow)

-- Detail-icon hover and ownership cleanup must not hide another addon's tooltip.
F.selected=chest; F.detailItemButton.scripts.OnEnter(F.detailItemButton)
assert(F.itemHover.owner==F.detailItemButton and F.itemHover.itemID==7914)
local otherOwner=CreateFrame("Button")
GameTooltip:SetOwner(otherOwner); GameTooltip:Show()
F.detailItemButton.scripts.OnLeave(F.detailItemButton)
assert(GameTooltip:IsShown() and GameTooltip:GetOwner()==otherOwner and not F.itemHover)
hoverRow.recipe=chest; hoverRow.scripts.OnEnter(hoverRow)
hoverRow.recipe=nil; hoverRow:UpdateTooltip()
assert(F.itemHover==nil and not GameTooltip:IsShown())
hoverRow.recipe=chest; hoverRow.scripts.OnEnter(hoverRow)
F.frame.scripts.OnHide()
assert(F.itemHover==nil and not GameTooltip.shoppingTooltips[1]:IsShown())

-- Missing optional APIs degrade to the ordinary tooltip without errors.
GameTooltip_ShowCompareItem=nil
hoverRow.scripts.OnEnter(hoverRow)
assert(GameTooltip.hyperlink:find("item:7914",1,true))
F.HideRecipeTooltip()
local modernInfo=C_Item.GetItemInfo
C_Item=nil; GetItemInfo=modernInfo; IsEquippableItem=nil
hoverRow.scripts.OnEnter(hoverRow)
assert(F.itemHover.equippable, "The legacy equip-location fallback should still recognize gear")
F.HideRecipeTooltip()
GameTooltip.SetHyperlink=function() error("Item unavailable") end
hoverRow.scripts.OnEnter(hoverRow)
assert(not F.itemHover.equippable and GameTooltip:GetText()=="Barbaric Iron Breastplate")
F.HideRecipeTooltip()
print("PASS: unseen crafted-item previews, native gear comparison, Shift override, equipment refresh, non-gear/spell tooltips, async item data, row recycling, tooltip ownership and optional API failures.")

-- The reported top-right button must prefer current APIs over legacy stubs.
F.sessionKnown={}; F.db.known={}
local scans,spellbookCalls=0,0
local ready,catalogAvailable,recipeReady=true,true,true
C_TradeSkillUI={
 IsTradeSkillReady=function() return ready end,
 GetBaseProfessionInfo=function() return {professionName="Engineering",skillLevel=180,maxSkillLevel=225} end,
 GetAllRecipeIDs=function() scans=scans+1; return catalogAvailable and {3979,1293088} or {} end,
 GetRecipeInfo=function(id) if recipeReady then return {learned=id==3979} end end,
}
TradeSkillFrame:Show(); CraftFrame:Hide()
GetNumTradeSkills=function() error("Modern scan must not call the legacy list") end
IsSpellKnown=function() spellbookCalls=spellbookCalls+1; return false end
F.profession="Cooking"; F.filter="Not seen"; F.eligibilityFilter="At my skill"; F.query="not this recipe"
F.scanButton.scripts.OnClick(F.scanButton)
assert(F.profession=="Engineering" and F.Status(F.byID[3979])=="Learned")
assert(F.scanReason=="ok" and F.lastScan:find("1 learned",1,true))
assert(F.query=="" and F.filter=="All records" and F.eligibilityFilter=="Any requirements")
assert(spellbookCalls==0 and scans==1, "Routine scanning must avoid thousands of spellbook probes")
assert(F.player.skills.Engineering.rank==180)
local coreEvents
for _,frame in ipairs(frames) do if frame.events.ADDON_LOADED then coreEvents=frame end end
local function coreEvent(name,id) coreEvents.scripts.OnEvent(coreEvents,name,id) end
F.Observe(1270633,"Cooking window")
coreEvent("SKILL_LINES_CHANGED")
assert(F.Status(F.byID[3979])=="Learned" and F.Status(F.byID[1270633])=="Learned")
coreEvent("NEW_RECIPE_LEARNED",1293088)
assert(F.Status(F.byID[1293088])=="Learned", "New recipes must show immediately before a delayed rescan")

-- A bounded retry handles late and partially populated profession data.
local callbacks={}
C_Timer.After=function(_,fn) callbacks[#callbacks+1]=fn end
local function nextCallback()
 assert(#callbacks>0,"Expected a scheduled callback")
 local fn=table.remove(callbacks,1); fn()
end
F.sessionKnown={}; F.db.known={}; F.levelBatchPending=true
ready=false; catalogAvailable=false
F.scanButton.scripts.OnClick(F.scanButton)
assert(F.scanReason=="waiting" and not F.sessionKnown[3979] and #callbacks==1)
ready=true; catalogAvailable=true; recipeReady=false
nextCallback()
assert(F.scanReason=="waiting" and not F.sessionKnown[3979] and #callbacks==1)
recipeReady=true; nextCallback()
assert(F.scanReason=="ok" and F.sessionKnown[3979] and #callbacks==0)
assert(not F.scanManualPending)
F.Observe(1270633,"Earlier profession")
catalogAvailable=false; F.RequestScan("trade",true)
local attempts=0
while #callbacks>0 do nextCallback(); attempts=attempts+1; assert(attempts<10) end
assert(F.lastScan:find("still loading",1,true) and F.sessionKnown[1270633])
F.RequestScan("trade",true)
coreEvent("TRADE_SKILL_CLOSE")
catalogAvailable=true
while #callbacks>0 do nextCallback() end
assert(not F.scanManualPending and F.lastScan:find("closed",1,true))

-- Closed cached sources and other players' lists must never become live scans.
TradeSkillFrame:Hide(); ready=false
local n,why=F.Scan()
assert(n==0 and why=="closed")
ready=true
C_TradeSkillUI.IsNPCCrafting=function() return true end
n,why=F.Scan(); assert(n==0 and why=="foreign")
C_TradeSkillUI.IsNPCCrafting=nil
C_TradeSkillUI.IsTradeSkillLinked=function() return true end
n,why=F.Scan(); assert(n==0 and why=="foreign")
C_TradeSkillUI.IsTradeSkillLinked=nil
C_TradeSkillUI.GetAllRecipeIDs=function() return {999999} end
C_TradeSkillUI.GetRecipeInfo=function() return {learned=true} end
C_TradeSkillUI.GetRecipeLink=function() return "|Henchant:3979|h[Accurate Scope]|h" end
F.sessionKnown={}; F.Scan()
assert(F.sessionKnown[3979] and not F.sessionKnown[999999])
print("PASS: top-right scan button, current API precedence, scan feedback, preserved learned status, immediate learn events, bounded retries, cancellation, foreign/closed lists and recipe-link IDs.")

-- Chat linking uses an item hyperlink and never sends the draft.
local drafts,opens={},{}
local chatReady=true
C_Item={GetItemInfo=function(id)
 if chatReady and id==7914 then return "Barbaric Iron Breastplate","|Hitem:7914|h[Barbaric Iron Breastplate]|h" end
end,RequestLoadItemDataByID=function() end}
IsModifiedClick=function(kind) return kind=="CHATLINK" end
IsShiftKeyDown=function() return true end
ChatEdit_LinkItem=function(id,link) drafts[#drafts+1]={id=id,link=link} end
local originalSelection=F.selected
hoverRow.recipe=chest; hoverRow.scripts.OnClick(hoverRow)
assert(#drafts==1 and drafts[1].id==7914 and drafts[1].link:find("item:7914",1,true))
assert(F.selected==originalSelection, "Shift-click should link without changing the selected recipe")
F.selected=chest; F.detailItemButton.scripts.OnClick()
assert(#drafts==2)
chatReady=false; hoverRow.scripts.OnClick(hoverRow)
assert(#drafts==2 and messages[#messages]:find("loading",1,true))
F.LinkCraftedItem(enchant)
assert(#drafts==2 and messages[#messages]:find("no recorded output",1,true))
chatReady=true; ChatEdit_LinkItem=nil
local draft={text="My existing message "}
function draft:Insert(text) self.text=self.text..text end
ChatEdit_GetActiveWindow=function() return draft end
assert(F.LinkCraftedItem(chest) and draft.text:find("My existing message |Hitem:7914",1,true))
ChatEdit_GetActiveWindow=function() return nil end
ChatFrame_OpenChat=function(text) opens[#opens+1]=text end
assert(F.LinkCraftedItem(chest) and #opens==1)
ChatFrame_OpenChat=nil
assert(not F.LinkCraftedItem(chest) and messages[#messages]:find("Press Enter",1,true))
print("PASS: row/icon Shift-click chat links, crafted output IDs, preserved drafts, chat opening, loading feedback and recipes without items.")

assert(_G.ForeverRecipeFinder == F, "Standalone namespace must be registered")
assert(SLASH_FOREVERRECIPEFINDER1 == "/frf" and SLASH_FOREVERRECIPEFINDER2 == "/recipefinder")
assert(SlashCmdList.FOREVERRECIPEFINDER == F.Command)
assert(_G.ARLForever == nil and SlashCmdList.ARLFOREVER == nil, "Do not claim ARL's namespace")
local oldData = {known={sentinel=true}}
_G.ARLForeverDB = oldData
F.Initialize()
assert(F.db == ForeverRecipeFinderDB and F.db ~= oldData)
assert(_G.ARLForeverDB == oldData and oldData.known.sentinel, "Leave prior saved data untouched")
print("PASS: separate identity, slash commands and saved data; no ARL dependency.")
