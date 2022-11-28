
local WDSpellDatabaseModule = {}
WDSpellDatabaseModule.__index = WDSpellDatabaseModule

setmetatable(WDSpellDatabaseModule, {
    __index = WD.Module,
    __call = function (v, ...)
        local self = setmetatable({}, v)
        self:init(...)
        return self
    end,
})

local WDSDM = nil

if not WD.cache then WD.cache = {} end
WD.cache.spell_db = {}

if not WD.Spells then WD.Spells = {} end
WD.Spells.flasks = {}
WD.Spells.food = {}
WD.Spells.runes = {}
WD.Spells.potions = {}
WD.Spells.rootEffects = {}
WD.Spells.controlEffects = {}
WD.Spells.knockbackEffects = {}
WD.Spells.silenceEffects = {}

local SPELL_GROUPS = {
    "FLASK",
    "FOOD",
    "RUNE",
    "POTION",
    "ROOT",
    "CONTROL",
    "KNOCKBACK",
    "SILENCE",
}

local CATEGORIES_LIST = {
    "General",
    "DEATHKNIGHT",
    "DEMONHUNTER",
    "DRUID",
    "HUNTER",
    "MAGE",
    "MONK",
    "PALADIN",
    "PRIEST",
    "ROGUE",
    "SHAMAN",
    "WARLOCK",
    "WARRIOR",
    "EVOKER",
}

local function deleteSpellDBEntry(entry)
    for k,v in pairs(WD.db.profile.spell_db) do
        if k == entry.id then
            WD.db.profile.spell_db[k] = nil
            table.remove(WD.db.profile.spell_db, k)
            break
        end
    end

    WD.SpellDBModule:applyFilters()
end

local function refreshFrame()
    if not WDSDM then return end
    if not WDSDM.members then WDSDM.members = {} end

    local maxHeight = 520
    local topLeftPosition = { x = 30, y = -49 }
    local rowsN = #WD.cache.spell_db
    local columnsN = 11

    -- sort by category > group > id
    local func = function(a, b)
        if a.category < b.category then return true
        elseif a.category > b.category then return false
        elseif a.group > b.group then return true
        elseif a.group < b.group then return false
        else
            return a.id < b.id
        end
    end
    table.sort(WD.cache.spell_db, func)
    
    local function setSpellGroup(parent, index, spell, group)
        for i=1, #SPELL_GROUPS do
            i = i + 2
            if i == index then
                local v = parent.column[i].check:GetChecked()
                if v == true then
                    spell.group = group
                else
                    spell.group = ""
                end
            else
                parent.column[i].check:SetChecked(false)
            end
        end
        WD.SpellDBModule:applyFilters()
    end
    
    local function createCheckCell(parent, index)
        local b = CreateFrame("Frame", nil, parent)
        b:SetSize(WDSDM.headers[index]:GetSize())
        b:SetPoint("TOPLEFT", parent.column[index-1], "TOPRIGHT", 1, 0)
        local f = WdLib.gui:createCheckButton(b)
        f:SetSize(18, 18)
        f:SetPoint("CENTER", b, "CENTER")
        b.check = f
        return b
    end

    local function createFn(parent, row, index)
        local v = WD.cache.spell_db[row]
        local vProfile = WD.db.profile.spell_db[v.id]
        if index == 1 then
            local f = WdLib.gui:addNextColumn(WDSDM, parent, index, "CENTER", v.category)
            f:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -1)
            return f
        elseif index == 2 then
            local f = WdLib.gui:addNextColumn(WDSDM, parent, index, "LEFT", WdLib.gui:getSpellLinkByIdWithTexture(v.id))
            WdLib.gui:generateSpellHover(f, f.txt:GetText())
            return f
        elseif index == 3 then
            local f = createCheckCell(parent, index)
            f.check:SetChecked(v.group == "FLASK")
            f.check:SetScript("OnClick", function() setSpellGroup(parent, index, vProfile, "FLASK") end)
            return f
        elseif index == 4 then
            local f = createCheckCell(parent, index)
            f.check:SetChecked(v.group == "FOOD")
            f.check:SetScript("OnClick", function() setSpellGroup(parent, index, vProfile, "FOOD") end)
            return f
        elseif index == 5 then
            local f = createCheckCell(parent, index)
            f.check:SetChecked(v.group == "RUNE")
            f.check:SetScript("OnClick", function() setSpellGroup(parent, index, vProfile, "RUNE") end)
            return f
        elseif index == 6 then
            local f = createCheckCell(parent, index)
            f.check:SetChecked(v.group == "POTION")
            f.check:SetScript("OnClick", function() setSpellGroup(parent, index, vProfile, "POTION") end)
            return f
        elseif index == 7 then
            local f = createCheckCell(parent, index)
            f.check:SetChecked(v.group == "ROOT")
            f.check:SetScript("OnClick", function() setSpellGroup(parent, index, vProfile, "ROOT") end)
            return f
        elseif index == 8 then
            local f = createCheckCell(parent, index)
            f.check:SetChecked(v.group == "CONTROL")
            f.check:SetScript("OnClick", function() setSpellGroup(parent, index, vProfile, "CONTROL") end)
            return f
        elseif index == 9 then
            local f = createCheckCell(parent, index)
            f.check:SetChecked(v.group == "KNOCKBACK")
            f.check:SetScript("OnClick", function() setSpellGroup(parent, index, vProfile, "KNOCKBACK") end)
            return f
        elseif index == 10 then
            local f = createCheckCell(parent, index)
            f.check:SetChecked(v.group == "SILENCE")
            f.check:SetScript("OnClick", function() setSpellGroup(parent, index, vProfile, "SILENCE") end)
            return f
        elseif index == 11 then
            local f = WdLib.gui:addNextColumn(WDSDM, parent, index, "CENTER", WD_BUTTON_DELETE)
            f:EnableMouse(true)
            f.t:SetColorTexture(.6, .2, .2, .7)
            f:SetScript("OnClick", function() deleteSpellDBEntry(v) end)
            return f
        end
    end

    local function updateFn(frame, row, index)
        local v = WD.cache.spell_db[row]
        local vProfile = WD.db.profile.spell_db[v.id]
        if index == 1 then
            frame.txt:SetText(v.category)
        elseif index == 2 then
            frame.txt:SetText(WdLib.gui:getSpellLinkByIdWithTexture(v.id))
            WdLib.gui:generateSpellHover(frame, frame.txt:GetText())
        elseif index == 3 then
            frame.check:SetChecked(v.group == "FLASK")
            frame.check:SetScript("OnClick", function() setSpellGroup(frame.grandParent, index, vProfile, "FLASK") end)
        elseif index == 4 then
            frame.check:SetChecked(v.group == "FOOD")
            frame.check:SetScript("OnClick", function() setSpellGroup(frame.grandParent, index, vProfile, "FOOD") end)
        elseif index == 5 then
            frame.check:SetChecked(v.group == "RUNE")
            frame.check:SetScript("OnClick", function() setSpellGroup(frame.grandParent, index, vProfile, "RUNE") end)
        elseif index == 6 then
            frame.check:SetChecked(v.group == "POTION")
            frame.check:SetScript("OnClick", function() setSpellGroup(frame.grandParent, index, vProfile, "POTION") end)
        elseif index == 7 then
            frame.check:SetChecked(v.group == "ROOT")
            frame.check:SetScript("OnClick", function() setSpellGroup(frame.grandParent, index, vProfile, "ROOT") end)
        elseif index == 8 then
            frame.check:SetChecked(v.group == "CONTROL")
            frame.check:SetScript("OnClick", function() setSpellGroup(frame.grandParent, index, vProfile, "CONTROL") end)
        elseif index == 9 then
            frame.check:SetChecked(v.group == "KNOCKBACK")
            frame.check:SetScript("OnClick", function() setSpellGroup(frame.grandParent, index, vProfile, "KNOCKBACK") end)
        elseif index == 10 then
            frame.check:SetChecked(v.group == "SILENCE")
            frame.check:SetScript("OnClick", function() setSpellGroup(frame.grandParent, index, vProfile, "SILENCE") end)
        elseif index == 11 then
            frame:SetScript("OnClick", function() deleteSpellDBEntry(v) end)
        end
    end

    WdLib.gui:updateScrollableTable(WDSDM, maxHeight, topLeftPosition, rowsN, columnsN, createFn, updateFn)
end

local function matchGroupFilter(isChecked, filter)
    if not filter or filter == false then
        return true
    end
    if filter == true and isChecked == false then
        return false
    end
    return true
end

local function matchSpellFilter(spell, filter)
    if not spell or not spell.id or not filter then
        return true
    end
    if tonumber(filter) ~= nil and spell.id == filter then
        return true
    end
    local name = GetSpellInfo(spell.id)
    if not name then return true end
    return name:match(filter)
end

local function matchCategoryFilter(category, filter)
    if not filter then
        return true
    end
    if filter.txt:GetText() ~= category then
        return false
    end
    return true
end

function WDSpellDatabaseModule:applyFilters()
    WdLib.table:wipe(WD.cache.spell_db)
    WdLib.table:wipe(WD.Spells.flasks)
    WdLib.table:wipe(WD.Spells.food)
    WdLib.table:wipe(WD.Spells.runes)
    WdLib.table:wipe(WD.Spells.potions)
    WdLib.table:wipe(WD.Spells.rootEffects)
    WdLib.table:wipe(WD.Spells.controlEffects)
    WdLib.table:wipe(WD.Spells.knockbackEffects)
    WdLib.table:wipe(WD.Spells.silenceEffects)
    for k,v in pairs(WD.db.profile.spell_db) do
        if type(v.id) == string then
            v.id = tonumber(v.id)
            k = v.id
        end
        if matchCategoryFilter(v.category, WDSDM.filters[0]) and
           matchSpellFilter(v, WDSDM.filters[1]) and
           matchGroupFilter(v.group == "FLASK", WDSDM.filters[2]) and
           matchGroupFilter(v.group == "FOOD", WDSDM.filters[3]) and
           matchGroupFilter(v.group == "RUNE", WDSDM.filters[4]) and
           matchGroupFilter(v.group == "POTION", WDSDM.filters[5]) and
           matchGroupFilter(v.group == "ROOT", WDSDM.filters[6]) and
           matchGroupFilter(v.group == "CONTROL", WDSDM.filters[7]) and
           matchGroupFilter(v.group == "KNOCKBACK", WDSDM.filters[8]) and
           matchGroupFilter(v.group == "SILENCE", WDSDM.filters[9])
        then
            WD.cache.spell_db[#WD.cache.spell_db+1] = WdLib.table:deepcopy(v)
        end
        -- synch db cache
        if v.group == "FLASK" then
            WD.Spells.flasks[v.id] = ""
        end
        if v.group == "FOOD" then
            WD.Spells.food[v.id] = ""
        end
        if v.group == "RUNE" then
            WD.Spells.runes[v.id] = ""
        end
        if v.group == "POTION" then
            WD.Spells.potions[v.id] = ""
        end
        if v.group == "ROOT" then
            WD.Spells.rootEffects[v.id] = ""
        end
        if v.group == "CONTROL" then
            WD.Spells.controlEffects[v.id] = ""
        end
        if v.group == "KNOCKBACK" then
            WD.Spells.knockbackEffects[v.id] = ""
        end
        if v.group == "SILENCE" then
            WD.Spells.silenceEffects[v.id] = ""
        end
    end

    refreshFrame()
end

local function initFiltersTab()
    WDSDM.filters = { [0] = nil, [1] = "", [2] = "", [3] = "", }
    
    WDSDM.categoryFilter = WdLib.gui:createDropDownMenu(WDSDM, "Select category", WdLib.gui:convertTypesToItems(CATEGORIES_LIST), nil, function()
        WDSDM.filters[0] = WDSDM.categoryFilter.selected
        WD.SpellDBModule:applyFilters()
    end)
    WDSDM.categoryFilter:SetSize(WDSDM.headers[1]:GetSize())
    WDSDM.categoryFilter:SetPoint("BOTTOMLEFT", WDSDM.headers[1], "TOPLEFT", 0, 5)

    WDSDM.spellFilter = WdLib.gui:createEditBox(WDSDM)
    WDSDM.spellFilter:SetSize(WDSDM.headers[2]:GetSize())
    WDSDM.spellFilter:EnableMouse(true)
    WDSDM.spellFilter:SetPoint("TOPLEFT", WDSDM.categoryFilter, "TOPRIGHT", 1, 0)
    WDSDM.spellFilter:SetJustifyH("CENTER")
    WDSDM.spellFilter:SetMaxLetters(15)
    WDSDM.spellFilter:SetScript("OnChar", function() WDSDM.filters[1] = WDSDM.spellFilter:GetText() end)
    WDSDM.spellFilter:SetScript("OnEnterPressed", function() WDSDM.filters[1] = WDSDM.spellFilter:GetText(); WD.SpellDBModule:applyFilters() end)
    WDSDM.spellFilter:SetScript("OnEscapePressed", function() WDSDM.spellFilter:ClearFocus() end)
    
    WDSDM.groupFilters = {}
    for i=1, #SPELL_GROUPS do
        WDSDM.groupFilters[i] = CreateFrame("Frame", nil, WDSDM)
        WDSDM.groupFilters[i]:SetSize(WDSDM.headers[3]:GetSize())
        if i > 1 then
            WDSDM.groupFilters[i]:SetPoint("TOPLEFT", WDSDM.groupFilters[i-1], "TOPRIGHT", 1, 0)
        else
            WDSDM.groupFilters[i]:SetPoint("TOPLEFT", WDSDM.spellFilter, "TOPRIGHT", 1, 0)
        end
        local f = WdLib.gui:createCheckButton(WDSDM.groupFilters[i])
        f:SetSize(18, 18)
        f:SetPoint("CENTER", WDSDM.groupFilters[i], "CENTER")
        f:SetChecked(false)
        f:SetScript("OnClick", function() WDSDM.filters[i+1] = WDSDM.groupFilters[i].check:GetChecked(); WD.SpellDBModule:applyFilters() end)
        WDSDM.groupFilters[i].check = f
    end
end

local function initAddSpellTab()
    WDSDM.add_spell = {}
    WDSDM.add_spell.entries = { ["id"] = 0, ["category"] = "", ["group"] = "" }

    local add_button = WdLib.gui:createButton(WDSDM)
    add_button:SetPoint("TOPLEFT", WDSDM.headers[11], "TOPRIGHT", 1, 0)
    add_button:SetSize(150, 20)
    add_button:SetScript("OnClick", function()
        if not WDSDM.category_entry.selected then
            print("Could not save spell without category")
            return
        end
        local spell = {
            category = WDSDM.category_entry.selected.txt:GetText(),
            id = WDSDM.add_spell.entries["id"],
            group = WDSDM.add_spell.entries["group"],
        }
        WD.SpellDBModule:AddSpellDBEntry(spell)
    end)
    add_button.t:SetColorTexture(.2, .4, .2, 1)
    add_button.txt = WdLib.gui:createFont(add_button, "CENTER", "Add spell")
    add_button.txt:SetAllPoints()
    WDSDM.add_spell.button = add_button

    WDSDM.spell_entry = WdLib.gui:createEditBox(WDSDM)
    WDSDM.spell_entry:SetSize(150, 20)
    WDSDM.spell_entry:EnableMouse(true)
    WDSDM.spell_entry:SetPoint("TOPLEFT", WDSDM.add_spell.button, "BOTTOMLEFT", 0, -1)
    WDSDM.spell_entry:SetJustifyH("CENTER")
    WDSDM.spell_entry:SetMaxLetters(15)
    WDSDM.spell_entry:SetScript("OnChar", function() WDSDM.add_spell.entries["id"] = WDSDM.spell_entry:GetNumber() end)
    WDSDM.spell_entry:SetScript("OnEnterPressed", function() WDSDM.add_spell.entries["id"] = WDSDM.spell_entry:GetNumber() end)
    WDSDM.spell_entry:SetScript("OnEscapePressed", function() WDSDM.spell_entry:ClearFocus() end)
    
    WDSDM.category_entry = WdLib.gui:createDropDownMenu(WDSDM, "Select category", WdLib.gui:convertTypesToItems(CATEGORIES_LIST))
    WDSDM.category_entry:SetSize(150, 20)
    WDSDM.category_entry:SetPoint("TOPLEFT", WDSDM.spell_entry, "BOTTOMLEFT", 0, -1)
end

local function initResetSpellsButton()
    WDSDM.reset_spells = {}
    WDSDM.reset_spells.entries = { ["id"] = 0, ["category"] = "", ["group"] = "" }

    local button = WdLib.gui:createButton(WDSDM)
    button:SetPoint("TOPLEFT", WDSDM.category_entry, "BOTTOMLEFT", 0, -21)
    button:SetSize(150, 20)
    button:SetScript("OnClick", function()
        WD:LoadDefaultSpells("reload")
        WD.SpellDBModule:applyFilters()
    end)
    button.t:SetColorTexture(.2, .2, .4, 1)
    button.txt = WdLib.gui:createFont(button, "CENTER", "Reset Spell DB")
    button.txt:SetAllPoints()
    WDSDM.reset_spells.button = button
end

function WDSpellDatabaseModule:init(parent, yOffset)
    WD.Module.init(self, WD_BUTTON_SPELL_DB_MODULE, parent, yOffset)

    WDSDM = self.frame

    local x, y = 0, -35

    WDSDM.headers = {}
    local h = WdLib.gui:createTableHeader(WDSDM, "Category", x, y, 120, 20)
    table.insert(WDSDM.headers, h)
    h = WdLib.gui:createTableHeaderNext(WDSDM, h, "Spell", 350, 20)
    table.insert(WDSDM.headers, h)
    -- groups: flask,food,rune,potion,root,control,knockback,silence
    local groupWidth = 40
    h = WdLib.gui:createTableHeaderNext(WDSDM, h, "Flask", groupWidth, 20)
    table.insert(WDSDM.headers, h)
    h = WdLib.gui:createTableHeaderNext(WDSDM, h, "Food", groupWidth, 20)
    table.insert(WDSDM.headers, h)
    h = WdLib.gui:createTableHeaderNext(WDSDM, h, "Rune", groupWidth, 20)
    table.insert(WDSDM.headers, h)
    h = WdLib.gui:createTableHeaderNext(WDSDM, h, "Potion", groupWidth, 20)
    table.insert(WDSDM.headers, h)
    h = WdLib.gui:createTableHeaderNext(WDSDM, h, "Root", groupWidth, 20)
    table.insert(WDSDM.headers, h)
    h = WdLib.gui:createTableHeaderNext(WDSDM, h, "CC", groupWidth, 20)
    table.insert(WDSDM.headers, h)
    h = WdLib.gui:createTableHeaderNext(WDSDM, h, "Knock", groupWidth, 20)
    table.insert(WDSDM.headers, h)
    h = WdLib.gui:createTableHeaderNext(WDSDM, h, "Silence", groupWidth, 20)
    table.insert(WDSDM.headers, h)
    h = WdLib.gui:createTableHeaderNext(WDSDM, h, "", 45, 20)
    table.insert(WDSDM.headers, h)

    initFiltersTab()
    initAddSpellTab()
    initResetSpellsButton()

    WD.SpellDBModule:applyFilters()

    WDSDM:SetScript("OnShow", function()
        WDSDM.categoryFilter.selected = WDSDM.filters[0]
        if WDSDM.categoryFilter.selected then
            WDSDM.categoryFilter:SetText(WDSDM.categoryFilter.selected.txt:GetText())
        end
        WD.SpellDBModule:applyFilters()
    end)

    function WDSDM:OnUpdate()
        refreshFrame()
    end
end

function WDSpellDatabaseModule:AddSpellDBEntry(entry)
    if not GetSpellInfo(entry.id) then
        print("Could not save spell with id: ".. entry.id ..". Not found")
        return
    end
    
    if WD.db.profile.spell_db[entry.id] then
        print("Could not save spell with id: ".. entry.id ..". Already exists")
        return
    end    

    WD.db.profile.spell_db[entry.id] = entry

    WD.SpellDBModule:applyFilters()
end

WD.SpellDBModule = WDSpellDatabaseModule
