local _, F = ...
local PAGE_SIZE = 13
local statuses = {"All records", "Not seen", "Learned", "Previously seen"}
local eligibility = {"Any requirements", "Fits level / skill", "At my skill", "Can learn now", "Unknown requirements"}
local sources = {"All sources", "Vendors", "Trainers", "Quests", "Drops", "Unknown sources"}
local colors = {Learned="|cff83d69a", ["Previously seen"]="|cff9eb7d5", ["Not seen"]="|cffe3cfaa"}
local icons = {
    Alchemy="Trade_Alchemy", Blacksmithing="Trade_BlackSmithing", Cooking="INV_Misc_Food_15",
    Enchanting="Trade_Engraving", Engineering="Trade_Engineering", ["First Aid"]="Spell_Holy_SealOfSacrifice",
    Fishing="Trade_Fishing", Herbalism="Trade_Herbalism", Leatherworking="Trade_LeatherWorking",
    Mining="Trade_Mining", Poisons="Trade_BrewPoison", Skinning="INV_Misc_Pelt_Wolf_01",
    Tailoring="Trade_Tailoring",
}
local sourceIcons = {"INV_Misc_Book_09", "INV_Misc_Coin_01", "INV_Scroll_03", "INV_Misc_Note_01", "INV_Misc_Bag_10", "INV_Misc_QuestionMark"}
F.page, F.sortMode, F.detailTab = 1, "Name", "Learn"

local function label(parent, font, x, y, width, value)
    local t = parent:CreateFontString(nil, "OVERLAY", font or "GameFontNormal")
    t:SetPoint("TOPLEFT", x, y); t:SetWidth(width)
    t:SetJustifyH("LEFT"); t:SetJustifyV("TOP"); t:SetText(value or "")
    return t
end
local function texture(parent, path, x, y, width, height, layer)
    local t = parent:CreateTexture(nil, layer or "ARTWORK")
    t:SetPoint("TOPLEFT", x, y); t:SetSize(width, height); t:SetTexture(path)
    return t
end
local function fill(parent, r, g, b, a, layer)
    local t = parent:CreateTexture(nil, layer or "BACKGROUND")
    t:SetAllPoints(); t:SetColorTexture(r,g,b,a or 1)
    return t
end
local function rule(parent, x, y, width)
    local t = parent:CreateTexture(nil, "BORDER")
    t:SetPoint("TOPLEFT", x, y); t:SetSize(width,1); t:SetColorTexture(0.65,0.49,0.24,0.45)
end
local function panel(parent, x, y, width, height)
    local p = CreateFrame("Frame", nil, parent, BackdropTemplateMixin and "BackdropTemplate")
    p:SetPoint("TOPLEFT", x, y); p:SetSize(width,height)
    fill(p,0.045,0.038,0.027,0.97)
    if p.SetBackdrop then
        p:SetBackdrop({edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=12})
        p:SetBackdropBorderColor(0.52,0.43,0.29,1)
    end
    return p
end
local function tooltip(frame, title, body)
    frame:SetScript("OnEnter",function(self)
        GameTooltip:SetOwner(self,"ANCHOR_RIGHT"); GameTooltip:SetText(title)
        if body then GameTooltip:AddLine(body,0.88,0.83,0.72,true) end
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave",function() GameTooltip:Hide() end)
end
local function button(parent, caption, x, y, width, action)
    local b=CreateFrame("Button",nil,parent,"UIPanelButtonTemplate")
    b:SetPoint("TOPLEFT",x,y); b:SetSize(width,25); b:SetText(caption); b:SetScript("OnClick",action)
    return b
end
local function professionIcon(name) return "Interface\\Icons\\" .. (icons[name] or "INV_Misc_Book_09") end
local function recipeIcon(recipe)
    local item=recipe.items and recipe.items[1]
    if item then
        local icon=F.Safe(C_Item and C_Item.GetItemIconByID or GetItemIcon,item.id)
        if icon then return icon end
    end
    return F.Safe(C_Spell and C_Spell.GetSpellTexture or GetSpellTexture, recipe.id) or professionIcon(recipe.profession)
end
local function stateColor(recipe)
    local state=F.Eligibility(recipe)
    if state=="Learned" or state=="Can learn now" then return "|cff83d69a" end
    if state:find("^Needs ") or state=="Reported unavailable" then return "|cffe28c78" end
    return colors[F.Status(recipe)]
end
local function section(lines,title,text)
    lines[#lines+1]="|cffffcc66"..title.."|r"; lines[#lines+1]=text; lines[#lines+1]=""
end

function F.CloseMenu()
    if F.menuShield then F.menuShield:Hide() end
end
local function dropdown(parent, x, y, width, values, field, after)
    local b=button(parent,"",x,y,width,function(self)
        F.HideRecipeTooltip()
        if F.menuShield and F.menuShield:IsShown() and F.menuOwner==self then F.CloseMenu(); return end
        if not F.menuShield then
            F.menuShield=CreateFrame("Button","ForeverRecipeFinderMenuShield",F.frame)
            F.menuShield:SetAllPoints(UIParent); F.menuShield:SetFrameStrata("FULLSCREEN_DIALOG")
            F.menuShield:SetScript("OnClick",F.CloseMenu)
            F.menu=panel(F.menuShield,0,0,200,40)
            F.menu:EnableMouse(true); F.menu:SetFrameLevel(F.menuShield:GetFrameLevel()+2)
            F.menuRows={}
            tinsert(UISpecialFrames,"ForeverRecipeFinderMenuShield")
        end
        F.menuOwner=self
        F.menu:ClearAllPoints(); F.menu:SetPoint("TOPLEFT",self,"BOTTOMLEFT",0,-2)
        F.menu:SetSize(math.max(width,210),#values*25+12)
        for i,value in ipairs(values) do
            local item=F.menuRows[i]
            if not item then
                item=CreateFrame("Button",nil,F.menu); F.menuRows[i]=item
                item:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
                item.caption=label(item,"GameFontHighlight",24,-5,175)
                item.mark=label(item,"GameFontNormal",5,-5,18)
            end
            item:SetPoint("TOPLEFT",5,-6-(i-1)*25); item:SetSize(math.max(width,210)-10,25)
            item.caption:SetText(value); item.mark:SetText(F[field]==value and "*" or "")
            item:SetScript("OnClick",function()
                F[field]=value; F.page=1; F.CloseMenu()
                if after then after() end
                F.Refresh()
            end)
            item:Show()
        end
        for i=#values+1,#F.menuRows do F.menuRows[i]:Hide() end
        F.menuShield:Show()
    end)
    -- The native arrow makes these controls distinguishable from action buttons.
    texture(b,"Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up",width-24,-3,18,18)
    b.valueText=label(b,"GameFontHighlightSmall",10,-7,width-38)
    b.SetText=function(self,text) self.valueText:SetText(text) end
    b:SetText(F[field])
    return b
end

function F.MaterialDetails(recipe)
    local lines,items,reagents={},{},{}
    for _,item in ipairs(recipe.items) do items[#items+1]=item.name.." ["..item.id.."]" end
    section(lines,"Creates",#items>0 and table.concat(items,"\n").."\nOutput quantity is unverified." or recipe.craftType..". No output item is recorded.")
    for _,r in ipairs(recipe.reagents) do reagents[#reagents+1]=(r.quantity and r.quantity.." x " or "Quantity unknown: ")..r.name end
    section(lines,"Materials",#reagents>0 and table.concat(reagents,"\n") or "No materials recorded.")
    if recipe.tools~="" then section(lines,"Tools",recipe.tools) end
    if recipe.fields["Enchantment ID"] then section(lines,"Enchantment ID",recipe.fields["Enchantment ID"]) end
    return table.concat(lines,"\n")
end
function F.NoteDetails(recipe)
    local lines={}
    local data=F.learning[recipe.id] or {}
    section(lines,"Learning status",F.Status(recipe))
    if F.Status(recipe)=="Not seen" then
        lines[#lines+1]="No learned-recipe observation for this character. Scan your profession before treating this as a missing recipe.\n"
    elseif F.Status(recipe)=="Previously seen" then
        lines[#lines+1]="Observed in an earlier session. Scan this profession to check again.\n"
    end
    section(lines,"Learning requirements",data.evidence or "Learning requirements and acquisition sources are not recorded.")
    if data.skillEvidence then section(lines,"Skill requirement source",data.skillEvidence) end
    lines[#lines+1]="Level and skill checks do not confirm stock, currency, reputation, specialization or quest prerequisites.\n"
    if data.recipeItemID then section(lines,"Teaching item","Recipe item ID "..data.recipeItemID) end
    if recipe.thresholds~="" then section(lines,"Skill-up thresholds",recipe.thresholds.."\nThese are not minimum learning requirements.") end
    section(lines,"Wiki evidence",recipe.evidence.." from build "..recipe.build..". Current beta availability and successful crafting are unverified.")
    section(lines,"Wiki revision",tostring(recipe.revision)..". Imported "..F.source.imported:sub(1,10)..".")
    if recipe.correctionEvidence then
        section(lines,"Verified correction",recipe.correctionEvidence.."\n"..recipe.correctionURL)
    end
    section(lines,"Recipe record",recipe.profession.." / "..recipe.category.."\nSpell ID "..recipe.id)
    return table.concat(lines,"\n")
end
function F.Details(recipe)
    if not recipe then return "Select a recipe from the list." end
    return recipe.name.."\n\n"..F.LearningDetails(recipe).."\n\n"..F.MaterialDetails(recipe).."\n"..F.NoteDetails(recipe)
end
function F.RenderDetails()
    local recipe=F.selected
    F.detailName:SetText(recipe and recipe.name or "Choose a recipe")
    F.detailProfession:SetText(recipe and recipe.profession or "Browse your profession")
    F.detailIcon:SetTexture(recipe and recipeIcon(recipe) or professionIcon(F.profession))
    F.detailState:SetText(recipe and stateColor(recipe)..F.Eligibility(recipe).."|r" or "Requirements, sources and materials")
    local body="Select a recipe to see where to learn it.\n\nUse the filters on the left to narrow the list by skill, learning status and source."
    if recipe then
        if F.detailTab=="Materials" then body=F.MaterialDetails(recipe)
        elseif F.detailTab=="Notes" then body=F.NoteDetails(recipe)
        else body=F.LearningDetails(recipe,true) end
    end
    F.detailText:SetText(body)
    F.detailChild:SetHeight(math.max(342,F.detailText:GetStringHeight()+16))
    for _,tab in ipairs(F.detailTabs) do tab:SetActive(tab.value==F.detailTab) end
end
function F.Select(recipe)
    F.selected=recipe; F.urlMode="wiki"
    F.detailScroll:SetVerticalScroll(0); F.SetSourceLink(); F.Refresh()
end
function F.SetSourceLink()
    if not F.url then return end
    local recipe=F.selected
    local data=recipe and F.learning[recipe.id] or {}
    local observed=recipe and F.db.observedSources[recipe.id]
    local quests=data.quests or (observed and observed.quests)
    local url=recipe and recipe.url or F.source.source
    if F.urlMode=="source" then url=data.skillURL or data.url or url end
    if F.urlMode=="quest" then
        for _,quest in ipairs(quests or {}) do
            url=quest.url or ("https://www.wowhead.com/forever/quest="..quest.id)
            if F.QuestStatus(quest.id)~="Completed" then break end
        end
    end
    F.url:SetText(url)
end
function F.ResetFilters()
    F.filter,F.eligibilityFilter,F.sourceFilter,F.factionFilter="All records","Any requirements","All sources","My faction"
    F.query,F.page="",1; F.search:SetText(""); F.CloseMenu(); F.Refresh()
end
function F.Refresh()
    if not F.frame or not F.uiReady then return end
    local results,learned,previous=F.Results()
    if F.sortMode~="Name" then
        table.sort(results,function(a,b)
            local av,bv
            if F.sortMode=="Skill" then av,bv=F.SkillRequirement(a) or 9999,F.SkillRequirement(b) or 9999
            else av,bv=(F.learning[a.id] or {}).kind or "unknown",(F.learning[b.id] or {}).kind or "unknown" end
            if av~=bv then return av<bv end
            if a.name~=b.name then return a.name<b.name end
            return a.id<b.id
        end)
    end
    F.results=results; F.pages=math.max(1,math.ceil(#results/PAGE_SIZE))
    F.page=math.max(1,math.min(F.page,F.pages))
    F.professionButton:SetText(F.profession); F.statusButton:SetText(F.filter)
    F.eligibilityButton:SetText(F.eligibilityFilter); F.sortButton:SetText("Sort: "..F.sortMode)
    F.factionButton:SetChecked(F.factionFilter=="My faction")
    F.compareButton:SetChecked(F.db.compareGear~=false)
    for _,b in ipairs(F.sourceButtons) do
        b.chosen:SetShown(F.sourceFilter==b.value)
        b.caption:SetText((F.sourceFilter==b.value and "|cffffd579" or "|cffbdb29c")..b.value.."|r")
    end
    F.character:SetText(F.PlayerSummary())
    local portrait=professionIcon(F.profession)
    if SetPortraitToTexture then F.Safe(SetPortraitToTexture,F.portrait,portrait) else F.portrait:SetTexture(portrait) end
    F.count:SetText(#results.." recipes  |  "..learned.." learned  |  "..previous.." previously seen")
    F.pager:SetText(F.page.." / "..F.pages)
    F.footer:SetText(F.lastScan or "Open a profession and click Scan. Mouse wheel turns recipe pages.")
    local selectedVisible=false
    for _,recipe in ipairs(results) do if recipe==F.selected then selectedVisible=true; break end end
    if not selectedVisible then
        F.selected=results[(F.page-1)*PAGE_SIZE+1]
        F.detailScroll:SetVerticalScroll(0); F.urlMode="wiki"; F.SetSourceLink()
    end
    for index,row in ipairs(F.rows) do
        local recipe=results[(F.page-1)*PAGE_SIZE+index]; row.recipe=recipe
        if recipe then
            row.icon:SetTexture(recipeIcon(recipe)); row.name:SetText(recipe.name)
            row.meta:SetText(stateColor(recipe)..F.Eligibility(recipe).."|r")
            row.skill:SetText(tostring(F.SkillRequirement(recipe) or "?"))
            row.selected:SetShown(F.selected==recipe); row.marker:SetShown(F.selected==recipe); row:Show()
        else row:Hide() end
    end
    F.empty:SetText(F.eligibilityFilter=="Can learn now" and "Visit a trainer to check what you can learn now."
        or F.eligibilityFilter=="Fits level / skill" and "No matching recipes.\n\nSome requirements may be unknown. Try At my skill."
        or "No matching recipes.\n\nChange the filters or clear your search.")
    F.empty:SetShown(#results==0)
    F.previous:SetEnabled(F.page>1); F.next:SetEnabled(F.page<F.pages)
    local total,known=0,0
    for _,recipe in ipairs(F.recipes) do
        if F.profession=="All professions" or F.profession==recipe.profession then
            total=total+1; if F.Status(recipe)=="Learned" then known=known+1 end
        end
    end
    F.progress:SetMinMaxValues(0,math.max(total,1)); F.progress:SetValue(known)
    F.progressText:SetText(known.." / "..total.." records observed as learned this session")
    F.RenderDetails(); F.PrimeLevels(); F.UpdateRecipeTooltip()
end

local function detailTab(parent,value,x)
    local b=CreateFrame("Button",nil,parent)
    b.value=value; b:SetPoint("TOPLEFT",x,-104); b:SetSize(98,27)
    b.left=texture(b,nil,0,0,15,27,"BORDER")
    b.middle=texture(b,nil,15,0,68,27,"BORDER")
    b.right=texture(b,nil,83,0,15,27,"BORDER")
    b.caption=label(b,"GameFontNormalSmall",6,-8,86,value); b.caption:SetJustifyH("CENTER")
    b:SetHighlightTexture("Interface\\PaperDollInfoFrame\\UI-Character-Tab-Highlight")
    function b:SetActive(active)
        local path="Interface\\PaperDollInfoFrame\\UI-Character-"..(active and "ActiveTab" or "InactiveTab")
        local bottom=active and 0.546875 or 1
        self.left:SetTexture(path); self.middle:SetTexture(path); self.right:SetTexture(path)
        self.left:SetTexCoord(0,0.15625,0,bottom); self.middle:SetTexCoord(0.15625,0.84375,0,bottom)
        self.right:SetTexCoord(0.84375,1,0,bottom)
        self.caption:SetText((active and "|cffffe0a1" or "|cffb9aa8e")..value.."|r")
    end
    b:SetScript("OnClick",function() F.detailTab=value; F.detailScroll:SetVerticalScroll(0); F.RenderDetails() end)
    return b
end
local function create()
    local frame=CreateFrame("Frame","ForeverRecipeFinderFrame",UIParent,BackdropTemplateMixin and "BackdropTemplate")
    F.frame=frame; frame:SetSize(1000,720)
    frame:SetScale(math.min(1,UIParent:GetWidth()/1040,UIParent:GetHeight()/760))
    frame:SetPoint("CENTER"); frame:SetClampedToScreen(true); frame:SetMovable(true)
    frame:EnableMouse(true); frame:SetFrameStrata("DIALOG")
    fill(frame,0.065,0.051,0.034,0.99)
    if frame.SetBackdrop then
        frame:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",
            edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=16,
            insets={left=4,right=4,top=4,bottom=4}})
        frame:SetBackdropColor(0.065,0.051,0.034,0.99)
        frame:SetBackdropBorderColor(0.9,0.8,0.61,1)
    end
    if type(F.db.position)=="table" and type(F.db.position.x)=="number" and type(F.db.position.y)=="number" then
        frame:ClearAllPoints(); frame:SetPoint("CENTER",UIParent,"CENTER",F.db.position.x,F.db.position.y)
    end
    local drag=CreateFrame("Frame",nil,frame)
    -- Keep the drag region clear of the header buttons so it cannot absorb their clicks.
    drag:SetPoint("TOPLEFT",0,0); drag:SetSize(645,77)
    drag:EnableMouse(true); drag:RegisterForDrag("LeftButton")
    drag:SetScript("OnDragStart",function() F.CloseMenu(); frame:StartMoving() end)
    drag:SetScript("OnDragStop",function()
        frame:StopMovingOrSizing()
        local x,y=frame:GetCenter(); local ux,uy=UIParent:GetCenter()
        local ratio=UIParent:GetEffectiveScale()/frame:GetEffectiveScale()
        F.db.position={x=x-ux*ratio,y=y-uy*ratio}
    end)
    F.portrait=texture(frame,professionIcon(F.profession),23,-17,54,54)
    texture(frame,"Interface\\Buttons\\UI-Quickslot2",14,-8,72,72,"OVERLAY")
    label(frame,"GameFontNormalLarge",91,-23,720,"Forever Recipe Finder")
    F.character=label(frame,"GameFontHighlightSmall",92,-49,545,F.PlayerSummary())
    F.character:SetWordWrap(false)
    local scan=button(frame,"Scan profession",825,-38,145,function() F.CloseMenu(); F.RequestScan(nil,true) end)
    F.scanButton=scan
    F.storageButton=button(frame,"Boxes and bags",658,-38,155,function() F.CloseMenu(); F.ShowStorage() end)
    tooltip(scan,"Scan your profession","Open your character's profession window, then click here. The result appears below and in chat. A successful scan clears filters that would hide learned recipes.")
    local close=CreateFrame("Button",nil,frame,"UIPanelCloseButton")
    close:SetPoint("TOPRIGHT",-4,-4); close:SetScript("OnClick",function() frame:Hide() end)
    frame:SetScript("OnHide",function() F.CloseMenu(); F.HideRecipeTooltip(); GameTooltip:Hide() end)
    tinsert(UISpecialFrames,"ForeverRecipeFinderFrame")
    rule(frame,22,-79,956)

    local filters=panel(frame,18,-91,182,574)
    label(filters,"GameFontNormal",12,-14,158,"Filter recipes")
    rule(filters,12,-36,158)
    label(filters,"GameFontNormalSmall",12,-49,158,"Learning requirements")
    F.eligibilityButton=dropdown(filters,10,-68,162,eligibility,"eligibilityFilter",function() F.filter="All records" end)
    tooltip(F.eligibilityButton,"Learning requirements","Fits level / skill checks recorded requirements. At my skill also includes unknown character levels. Can learn now requires an affordable offer at your open trainer.")
    label(filters,"GameFontNormalSmall",12,-108,158,"Recipe status")
    F.statusButton=dropdown(filters,10,-127,162,statuses,"filter")
    F.factionButton=CreateFrame("CheckButton",nil,filters,"UICheckButtonTemplate")
    F.factionButton:SetPoint("TOPLEFT",9,-172); F.factionButton:SetSize(25,25)
    label(F.factionButton,"GameFontHighlightSmall",27,-7,126,"My faction only")
    F.factionButton:SetScript("OnClick",function(self)
        F.factionFilter=self:GetChecked() and "My faction" or "All factions"; F.page=1; F.Refresh()
    end)
    tooltip(F.factionButton,"Faction sources","Hide recorded NPC locations restricted to the other faction.")
    rule(filters,12,-210,158)
    label(filters,"GameFontNormalSmall",12,-222,158,"Where to learn")
    F.sourceButtons={}
    for i,value in ipairs(sources) do
        local b=CreateFrame("Button",nil,filters)
        b.value=value; b:SetSize(160,28); b:SetPoint("TOPLEFT",11,-245-(i-1)*29)
        b.chosen=fill(b,0.44,0.30,0.09,0.42)
        b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        texture(b,"Interface\\Icons\\"..sourceIcons[i],6,-5,18,18)
        b.caption=label(b,"GameFontHighlight",32,-7,122,value)
        b:SetScript("OnClick",function() F.sourceFilter=value; F.page=1; F.CloseMenu(); F.Refresh() end)
        F.sourceButtons[i]=b
    end
    rule(filters,12,-438,158)
    F.resetButton=button(filters,"Reset filters",12,-458,158,F.ResetFilters)
    F.compareButton=CreateFrame("CheckButton",nil,filters,"UICheckButtonTemplate")
    F.compareButton:SetPoint("TOPLEFT",9,-494); F.compareButton:SetSize(25,25)
    label(F.compareButton,"GameFontHighlightSmall",27,-7,126,"Compare gear")
    F.compareButton:SetScript("OnClick",function(self)
        F.db.compareGear=self:GetChecked() and true or false; F.UpdateRecipeTooltip()
    end)
    tooltip(F.compareButton,"Compare crafted gear","Hover a recipe or its detail icon to compare the crafted item with your equipment, even if you have not learned it. When unchecked, hold Shift or use WoW's comparison setting.")
    label(filters,"GameFontHighlightSmall",13,-536,156,"Hover a recipe to preview its crafted item.")

    F.professionButton=dropdown(frame,214,-94,224,F.professions,"profession")
    F.sortButton=dropdown(frame,449,-94,185,{"Name","Skill","Source"},"sortMode")
    label(frame,"GameFontNormalSmall",216,-126,180,"Search recipes")
    F.search=CreateFrame("EditBox",nil,frame,"InputBoxTemplate")
    F.search:SetPoint("TOPLEFT",221,-143); F.search:SetSize(380,23)
    F.search:SetAutoFocus(false); F.search:SetMaxLetters(160)
    F.search:SetScript("OnTextChanged",function(self) F.query=self:GetText(); F.page=1; F.Refresh() end)
    F.search:SetScript("OnEscapePressed",function(self) self:ClearFocus(); F.CloseMenu() end)
    F.search:SetScript("OnEnterPressed",function(self) self:ClearFocus() end)
    local clear=button(frame,"x",609,-143,25,function() F.search:SetText(""); F.search:ClearFocus() end)
    tooltip(clear,"Clear search")
    F.count=label(frame,"GameFontHighlightSmall",216,-174,420)
    label(frame,"GameFontNormalSmall",224,-190,290,"Recipe")
    local skillLabel=label(frame,"GameFontNormalSmall",590,-190,38,"Skill"); skillLabel:SetJustifyH("RIGHT")
    local list=panel(frame,214,-207,420,416)
    list:EnableMouseWheel(true)
    list:SetScript("OnMouseWheel",function(_,delta)
        F.page=math.max(1,math.min(F.pages,F.page-delta)); F.CloseMenu(); F.Refresh()
    end)
    F.rows={}
    for index=1,PAGE_SIZE do
        local row=CreateFrame("Button",nil,list)
        row:SetPoint("TOPLEFT",2,-(index-1)*32-1); row:SetSize(416,32)
        if index%2==0 then fill(row,0.22,0.18,0.12,0.22) end
        row.selected=fill(row,0.50,0.34,0.10,0.38,"ARTWORK")
        row.marker=row:CreateTexture(nil,"OVERLAY")
        row.marker:SetPoint("TOPLEFT",0,0); row.marker:SetSize(2,32); row.marker:SetColorTexture(0.95,0.72,0.29,1)
        row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        row.icon=texture(row,nil,7,-3,26,26)
        row.icon:SetTexCoord(0.07,0.93,0.07,0.93)
        row.name=label(row,"GameFontHighlight",41,-3,324); row.name:SetWordWrap(false)
        row.meta=label(row,"GameFontHighlightSmall",41,-18,324); row.meta:SetWordWrap(false)
        row.skill=label(row,"GameFontNormal",370,-10,38); row.skill:SetJustifyH("RIGHT")
        row:SetScript("OnClick",function(self)
            if F.RecipeChatClick(self.recipe) then return end
            F.CloseMenu(); F.Select(self.recipe)
        end)
        F.BindRecipeTooltip(row,function() return row.recipe end)
        F.rows[index]=row
    end
    F.empty=label(list,"GameFontHighlight",22,-46,370)
    F.previous=button(frame,"Previous",214,-631,90,function() F.page=F.page-1; F.Refresh() end)
    F.next=button(frame,"Next",544,-631,90,function() F.page=F.page+1; F.Refresh() end)
    F.pager=label(frame,"GameFontHighlightSmall",350,-638,148); F.pager:SetJustifyH("CENTER")
    F.progress=CreateFrame("StatusBar",nil,frame)
    F.progress:SetPoint("TOPLEFT",214,-665); F.progress:SetSize(420,15)
    fill(F.progress,0.08,0.08,0.065,1)
    F.progress:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    F.progress:SetStatusBarColor(0.27,0.40,0.18,1)
    F.progressText=label(F.progress,"GameFontHighlightSmall",3,-2,414); F.progressText:SetJustifyH("CENTER")

    local detail=panel(frame,652,-91,330,574)
    F.detailIcon=texture(detail,professionIcon(F.profession),13,-15,44,44)
    texture(detail,"Interface\\Buttons\\UI-Quickslot2",5,-7,60,60,"OVERLAY")
    F.detailItemButton=CreateFrame("Button",nil,detail)
    F.detailItemButton:SetPoint("TOPLEFT",13,-15); F.detailItemButton:SetSize(44,44)
    F.detailItemButton:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
    F.BindRecipeTooltip(F.detailItemButton,function() return F.selected end)
    F.detailItemButton:SetScript("OnClick",function() F.RecipeChatClick(F.selected) end)
    F.detailName=label(detail,"GameFontNormal",66,-16,250)
    F.detailName:SetHeight(31)
    F.detailProfession=label(detail,"GameFontHighlightSmall",66,-51,247)
    F.detailState=label(detail,"GameFontHighlightSmall",14,-78,302); F.detailState:SetWordWrap(false)
    F.detailTabs={}
    for i,value in ipairs({"Learn","Materials","Notes"}) do F.detailTabs[i]=detailTab(detail,value,10+(i-1)*102) end
    F.detailScroll=CreateFrame("ScrollFrame","ForeverRecipeFinderDetailScroll",detail,"UIPanelScrollFrameTemplate")
    F.detailScroll:SetPoint("TOPLEFT",15,-142); F.detailScroll:SetSize(283,337)
    F.detailChild=CreateFrame("Frame",nil,F.detailScroll); F.detailChild:SetSize(283,342)
    F.detailScroll:SetScrollChild(F.detailChild)
    F.detailText=label(F.detailChild,"GameFontHighlight",0,0,280)
    F.detailText:SetSpacing(4)
    rule(detail,14,-490,302)
    for i,entry in ipairs({{"Wiki","wiki"},{"Source","source"},{"Quest","quest"}}) do
        button(detail,entry[1],13+(i-1)*103,-502,98,function() F.urlMode=entry[2]; F.SetSourceLink() end)
    end
    label(detail,"GameFontHighlightSmall",15,-533,299,"Copy link with Ctrl+C")
    F.url=CreateFrame("EditBox",nil,detail,"InputBoxTemplate")
    F.url:SetPoint("TOPLEFT",19,-550); F.url:SetSize(296,19); F.url:SetAutoFocus(false)
    F.url:SetScript("OnEditFocusGained",function(self) self:HighlightText() end)
    F.url:SetScript("OnEscapePressed",function(self) self:ClearFocus() end)
    F.url:SetScript("OnEnterPressed",function(self) self:ClearFocus() end)
    F.url:SetText(F.source.source)
    rule(frame,22,-688,956)
    F.footer=label(frame,"GameFontHighlightSmall",24,-697,950); F.footer:SetWordWrap(false)
    F.uiReady=true
    frame:Hide()
end
function F.Show()
    if F.storageFrame then F.storageFrame:Hide() end
    if not F.db then F.Initialize() end
    if not F.frame then create() end
    F.search:SetText(F.query); F.frame:Show(); F.Refresh()
end
function F.AttachButton(kind)
    local parent=kind=="craft" and CraftFrame or ProfessionsFrame or TradeSkillFrame
    if not parent then return end
    F.scanButtons=F.scanButtons or {}
    if F.scanButtons[parent] then return end
    local b=CreateFrame("Button",nil,parent,"UIPanelButtonTemplate")
    b:SetSize(100,24); b:SetPoint("TOPLEFT",parent,"BOTTOMLEFT",20,2); b:SetText("Find recipes")
    b:SetScript("OnClick",function() F.RequestScan(kind,true); F.Show() end)
    F.scanButtons[parent]=b
end

