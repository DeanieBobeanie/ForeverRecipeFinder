-- Check the checked-in catalog before tests replace runtime state with fixtures.
local function integer(value, minimum)
    return type(value) == "number" and value >= minimum and value == math.floor(value)
end
local function text(value)
    return type(value) == "string" and value:find("%S") ~= nil
end
local function url(value)
    return text(value) and value:match("^https://[^/]+/") ~= nil
end
local function itemList(items, label, quantities)
    local ids = {}
    assert(type(items) == "table", label .. " is missing")
    for _, item in ipairs(items) do
        assert(integer(item.id, 1), label .. " has an invalid item ID")
        assert(not ids[item.id], label .. " repeats item " .. item.id)
        ids[item.id] = true
        assert(text(item.name), label .. " has an unnamed item")
        if quantities then
            assert(integer(item.quantity, 1), label .. " has an invalid quantity")
        end
    end
end

local recipes = {}
assert(#F.recipes == F.source.count, "Recipe metadata count does not match the catalog")
assert(url(F.source.source), "Recipe catalog source is missing")
for _, recipe in ipairs(F.recipes) do
    assert(integer(recipe.id, 1) and not recipes[recipe.id], "Invalid or duplicate recipe ID")
    recipes[recipe.id] = recipe
    assert(text(recipe.name) and text(recipe.profession), "Recipe identity is incomplete")
    assert(url(recipe.url) and integer(recipe.revision, 1), "Recipe source revision is missing")
    assert(text(recipe.build) and text(recipe.evidence), "Recipe evidence is missing")
    assert(tonumber(recipe.fields["Spell ID"]) == recipe.id, "Recipe source spell ID disagrees")
    assert(recipe.fields.Profession == recipe.profession, "Recipe source profession disagrees")
    itemList(recipe.items, "Recipe " .. recipe.id .. " outputs", false)
    itemList(recipe.reagents, "Recipe " .. recipe.id .. " ingredients", true)
    if recipe.correctionURL or recipe.correctionEvidence then
        assert(url(recipe.correctionURL) and text(recipe.correctionEvidence), "Recipe correction needs evidence")
    end
end

local kinds = {vendor=true, trainer=true, quest=true, drop=true, worldDrop=true,
    blueprint=true, container=true, worldEvent=true, unknown=true, profession=true}
local factions = {alliance=true, horde=true, neutral=true}
local learningCount = 0
for id, entry in pairs(F.learning) do
    learningCount = learningCount + 1
    assert(recipes[id], "Learning entry points to a missing recipe: " .. tostring(id))
    assert(kinds[entry.kind], "Learning entry has an unsupported source kind")
    assert(url(entry.url) and text(entry.evidence), "Learning entry needs source evidence")
    if entry.requiredSkill ~= nil then
        assert(integer(entry.requiredSkill, 0), "Invalid learning skill requirement")
        assert(url(entry.skillURL) and text(entry.skillEvidence),
            "Recipe " .. id .. " has a skill requirement without specific evidence")
    end
    if entry.requiredLevel ~= nil then assert(integer(entry.requiredLevel, 0), "Invalid learning level") end
    if entry.recipeItemID ~= nil then assert(integer(entry.recipeItemID, 1), "Invalid teaching item ID") end
    for _, place in ipairs(entry.places or {}) do
        if place.faction then assert(factions[place.faction], "Unknown source faction") end
        if place.x ~= nil or place.y ~= nil then
            assert(type(place.x) == "number" and place.x >= 0 and place.x <= 100
                and type(place.y) == "number" and place.y >= 0 and place.y <= 100,
                "Source coordinates must include valid x and y percentages")
        end
    end
    for _, quest in ipairs(entry.quests or {}) do
        assert(integer(quest.id, 1) and text(quest.name) and url(quest.url), "Quest reference is incomplete")
    end
end
assert(F.learning[24801].requiredSkill == nil,
    "Smoked Desert Dumplings must not use an unverified Classic skill requirement")

local storageIDs, crates, bags, bundles, unresolved = {}, 0, 0, 0, 0
for _, entry in ipairs(F.storage) do
    assert(integer(entry.id, 1) and not storageIDs[entry.id], "Invalid or duplicate storage item ID")
    storageIDs[entry.id] = true
    assert(text(entry.name) and text(entry.category) and url(entry.url), "Storage identity or source is missing")
    assert(integer(entry.minLevel, 0), "Invalid storage level requirement")
    if entry.type == "crate" then
        crates = crates + 1
        assert(type(entry.bundles) == "table" and #entry.bundles > 0, "Crate has no material alternatives")
        local seen = {}
        for _, bundle in ipairs(entry.bundles) do
            bundles = bundles + 1
            assert(text(bundle.name) and integer(bundle.quantity, 1), "Invalid crate material requirement")
            if bundle.id then
                assert(integer(bundle.id, 1) and not seen[bundle.id], "Invalid or duplicate crate material ID")
                seen[bundle.id] = true
            else
                unresolved = unresolved + 1
                assert(text(bundle.note), "Unresolved crate materials need an explanation")
            end
        end
    else
        assert(entry.type == "bag", "Unknown storage entry type")
        bags = bags + 1
        assert(integer(entry.classMask, 0), "Invalid bag class mask")
    end
end
assert(crates == F.storageSource.crateCount and bags == F.storageSource.bagCount
    and bundles == F.storageSource.bundleCount, "Storage source counts disagree")
assert(unresolved == F.storageSource.unresolvedBundleIDs, "Unresolved material count disagrees")
for _, id in ipairs(F.storageSource.excludedInternalItems) do
    assert(not storageIDs[id], "Internal storage placeholder is present in the player catalog")
end
print("PASS: catalog IDs, ingredient quantities, learning references and evidence, coordinates, quest links, and storage metadata for "
    .. #F.recipes .. " recipes and " .. learningCount .. " learning records.")
