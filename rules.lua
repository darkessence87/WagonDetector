
local WDRM = nil

local insertQueue = {}

local function editRuleLine(rule)
    if not rule then return end
    local r = WDRM.menus["new_rule"]
    if r:IsVisible() then r:Hide() return end

    for _,v in pairs(r.hiddenMenus) do v:Hide() end
    local arg0_edit = r.hiddenMenus["arg0_edit"]
    local arg1_drop = r.hiddenMenus["arg1_drop"]
    local arg1_edit = r.hiddenMenus["arg1_edit"]
    local arg2_edit = r.hiddenMenus["arg2_edit"]

    -- encounter
    local encounterName = WD.EncounterNames[rule.journalId]
    local frame = WdLib:findDropDownFrameByName(r.menus["encounters"], encounterName)
    if frame then
        r.menus["encounters"].selected = frame
        r.menus["encounters"]:SetText(encounterName)
    end

    -- role
    for i=1,#r.menus["roles"].items do
        if r.menus["roles"].items[i].txt:GetText() == rule.role then
            r.menus["roles"].selected = r.menus["roles"].items[i]
            r.menus["roles"]:SetText(rule.role)
            break
        end
    end

    -- rule
    for i=1,#r.menus["rule_types"].items do
        if r.menus["rule_types"].items[i].txt:GetText() == rule.type then
            r.menus["rule_types"].selected = r.menus["rule_types"].items[i]
            r.menus["rule_types"]:SetText(rule.type)
            break
        end
    end

    if rule.type == "EV_AURA" then
        WdLib:showHiddenEditBox(r, "arg0_edit", rule.arg0)
        arg0_edit.label:SetText("Aura id:")

        WdLib:updateDropDownMenu(arg1_drop, "Select action:", {{name = "apply"},{name = "remove"}})
        local frame = WdLib:findDropDownFrameByName(arg1_drop, rule.arg1)
        if frame then
            arg1_drop.selected = frame
            arg1_drop:SetText(rule.arg1)
        end
        arg1_drop.label:SetText("Action:")
        arg1_drop:Show()
    elseif rule.type == "EV_AURA_STACKS" then
        WdLib:showHiddenEditBox(r, "arg0_edit", rule.arg0)
        arg0_edit.label:SetText("Aura id:")
        WdLib:showHiddenEditBox(r, "arg1_edit", rule.arg1)
        arg1_edit.label:SetText("Stacks:")
    elseif rule.type == "EV_DISPEL" then
        WdLib:showHiddenEditBox(r, "arg0_edit", rule.arg0)
        arg0_edit.label:SetText("Aura id:")
    elseif rule.type == "EV_CAST_START" then
        WdLib:showHiddenEditBox(r, "arg0_edit", rule.arg0)
        arg0_edit.label:SetText("Spell id:")
        WdLib:showHiddenEditBox(r, "arg1_edit", rule.arg1)
        arg1_edit.label:SetText("Caster name:")
    elseif rule.type == "EV_CAST_INTERRUPTED" then
        WdLib:showHiddenEditBox(r, "arg0_edit", rule.arg0)
        arg0_edit.label:SetText("Target spell id:")
        WdLib:showHiddenEditBox(r, "arg1_edit", rule.arg1)
        arg1_edit.label:SetText("Target name:")
    elseif rule.type == "EV_CAST_END" then
        WdLib:showHiddenEditBox(r, "arg0_edit", rule.arg0)
        arg0_edit.label:SetText("Spell id:")
        WdLib:showHiddenEditBox(r, "arg1_edit", rule.arg1)
        arg1_edit.label:SetText("Caster name:")
    elseif rule.type == "EV_DAMAGETAKEN" then
        WdLib:showHiddenEditBox(r, "arg0_edit", rule.arg0)
        arg0_edit.label:SetText("Spell id:")
        WdLib:showHiddenEditBox(r, "arg1_edit", rule.arg1)
        arg1_edit.label:SetText("Amount:")
    elseif rule.type == "EV_DEATH" then
        WdLib:showHiddenEditBox(r, "arg0_edit", rule.arg0)
        arg0_edit.label:SetText("Spell id:")
    elseif rule.type == "EV_DEATH_UNIT" then
        WdLib:showHiddenEditBox(r, "arg0_edit", rule.arg0)
        arg0_edit.label:SetText("Unit name:")
    end

    WdLib:showHiddenEditBox(r, "arg2_edit", rule.points)
    arg2_edit.label:SetText("Points:")

    r:Show()
end

local function getRuleDescription(rule)
    return WD.GetEventDescription(rule.type, rule.arg0, rule.arg1)
end

local function isValidRule(rule)
    if rule and rule.type then
        if not rule.version or rule.version < WD.MinRulesVersion then
            print(string.format(WD_RULE_ERROR_OLD_VERSION, rule.version or "none", WD.MinRulesVersion))
            return false
        end
    else
        print("Could not parse rule")
        return false
    end
    return true
end

local function parseRule(str)
    function parseValue(s)
        if string.find(s, "\"") then
            return s:sub(2,-2)
        elseif s == "true" then
            return true
        elseif s == "false" then
            return false
        elseif tonumber(s) ~= nil then
            return tonumber(s)
        else
            return s
        end
    end

    local rule = {}
    for i in string.gmatch(str, "[%w]+=[%w\"_%-%.]+") do
        local dashIndex = string.find(i, "%=")
        if dashIndex then
            local k = string.sub(i, 1, dashIndex - 1)
            local v = parseValue(string.sub(i, dashIndex + 1))
            --print(k)
            --print(v)
            if k == "type" then
                rule.type = v
            elseif k == "journalId" then
                rule.journalId = tonumber(v)
            elseif k == "arg0" then
                rule.arg0 = v
            elseif k == "arg1" then
                rule.arg1 = v
            elseif k == "points" then
                rule.points = tonumber(v)
            elseif k == "isActive" then
                rule.isActive = v
            elseif k == "version" then
                rule.version = v
            end
        end
    end

    return rule
end

local function parseEncounter(str)
    local rules = {}

    string.gsub(str:sub(2,-2),"{(.-)}", function(a)
        rules[#rules+1] = parseRule(a)
    end)

    return rules
end

local function exportRule(rule)
    if not rule then return end
    rule.version = WD.Version
    local txt = WdLib:encode64(WdLib:table_tostring(rule))
    local r = WDRM.exportWindow
    r.editBox:SetText(txt)
    r.editBox:SetScript("OnChar", function() r.editBox:SetText(txt); r.editBox:HighlightText(); end)
    r.editBox:HighlightText()
    r.editBox:SetAutoFocus(true)
    r.editBox:SetCursorPosition(0)

    r:Show()
end

local function exportEncounter(rules)
    if not rules or #rules == 0 then return end
    for _,v in pairs(rules) do v.version = WD.Version end
    local txt = WdLib:encode64(WdLib:table_tostring(rules))
    local r = WDRM.exportWindow
    r.editBox:SetText(txt)
    r.editBox:SetScript("OnChar", function() r.editBox:SetText(txt); r.editBox:HighlightText(); end)
    r.editBox:HighlightText()
    r.editBox:SetAutoFocus(true)
    r.editBox:SetCursorPosition(0)

    r:Show()
end

local function importRule(str)
    local d = WdLib:decode64(str)
    local rule = parseRule(d)
    return rule
end

local function importEncounter(str)
    local d = WdLib:decode64(str)
    local rules = parseEncounter(d)
    return rules
end

local function shareRule(rule)
    if not rule then return end
    rule.version = WD.Version
    local txt = WdLib:encode64(WdLib:table_tostring(rule))
    WD:SendAddonMessage("share_rule", txt)
end

local function shareEncounter(encounterName, rules)
    if not rules or #rules == 0 then return end
    WD:SendAddonMessage("request_share_encounter", encounterName)
end

local function updateRuleLines()
    if not WDRM or not WDRM.members then return end

    local maxHeight = 545
    local topLeftPosition = { x = 30, y = -51 }
    local rowsN = #WD.db.profile.rules
    local columnsN = 9

    -- sort by journalId > points > reason
    local func = function(a, b)
        if a.journalId < b.journalId then return true
        elseif a.journalId > b.journalId then return false
        elseif a.points > b.points then return true
        elseif a.points < b.points then return false
        else
            return getRuleDescription(a) < getRuleDescription(b)
        end
    end
    table.sort(WD.db.profile.rules, func)

    local function createFn(parent, row, index)
        local v = WD.db.profile.rules[row]
        if index == 1 then
            local f = WdLib:createCheckButton(parent)
            f:SetSize(18, 18)
            f:SetPoint("TOPLEFT", parent, "TOPLEFT", 1, -1)
            f:SetChecked(v.isActive)
            f:SetScript("OnClick", function() v.isActive = not v.isActive end)
            return f
        elseif index == 2 then
            local f = WdLib:addNextColumn(WDRM, parent, index, "LEFT", WD.EncounterNames[v.journalId])
            f:SetPoint("TOPLEFT", parent.column[1], "TOPRIGHT", 2, 1)
            local instanceName = WD.FindInstanceByJournalId(v.journalId)
            WdLib:generateHover(f, instanceName)
            return f
        elseif index == 3 then
            return WdLib:addNextColumn(WDRM, parent, index, "LEFT", v.role)
        elseif index == 4 then
            local f = WdLib:addNextColumn(WDRM, parent, index, "LEFT", getRuleDescription(v))
            WdLib:generateSpellHover(f, getRuleDescription(v))
            return f
        elseif index == 5 then
            return WdLib:addNextColumn(WDRM, parent, index, "CENTER", v.points)
        elseif index == 6 then
            local f = WdLib:addNextColumn(WDRM, parent, index, "CENTER", WD_BUTTON_EDIT)
            f:EnableMouse(true)
            f:SetScript("OnClick", function() editRuleLine(v); end)
            f.t:SetColorTexture(.2, 1, .2, .5)
            return f
        elseif index == 7 then
            local f = WdLib:addNextColumn(WDRM, parent, index, "CENTER", WD_BUTTON_DELETE)
            f:EnableMouse(true)
            f:SetScript("OnClick", function() table.remove(WD.db.profile.rules, row); updateRuleLines(); end)
            f.t:SetColorTexture(1, .2, .2, .5)
            return f
        elseif index == 8 then
            local f = WdLib:addNextColumn(WDRM, parent, index, "CENTER", WD_BUTTON_EXPORT)
            f:EnableMouse(true)
            f:SetScript("OnClick", function() exportRule(v); end)
            f.t:SetColorTexture(1, .2, .2, .5)
            return f
        elseif index == 9 then
            local f = WdLib:addNextColumn(WDRM, parent, index, "CENTER", WD_BUTTON_SHARE)
            f:EnableMouse(true)
            f:SetScript("OnClick", function() shareRule(v); end)
            f.t:SetColorTexture(1, .2, .2, .5)
            return f
        end
    end

    local function updateFn(frame, row, index)
        local v = WD.db.profile.rules[row]
        if index == 1 then
            frame:SetChecked(v.isActive)
            frame:SetScript("OnClick", function() v.isActive = not v.isActive end)
        elseif index == 2 then
            frame.txt:SetText(WD.EncounterNames[v.journalId])
            local instanceName = WD.FindInstanceByJournalId(v.journalId)
            WdLib:generateHover(frame, instanceName)
        elseif index == 3 then
            frame.txt:SetText(v.role)
        elseif index == 4 then
            frame.txt:SetText(getRuleDescription(v))
            WdLib:generateSpellHover(frame, getRuleDescription(v))
        elseif index == 5 then
            frame.txt:SetText(v.points)
        elseif index == 6 then
            frame:SetScript("OnClick", function(self) editRuleLine(v); end)
        elseif index == 7 then
        elseif index == 8 then
            frame:SetScript("OnClick", function() exportRule(v); end)
        elseif index == 9 then
            frame:SetScript("OnClick", function() shareRule(v); end)
        end
    end

    WdLib:updateScrollableTable(WDRM, maxHeight, topLeftPosition, rowsN, columnsN, createFn, updateFn)
end

local function isDuplicate(rule)
    if not rule.role then rule.role = "ANY" end

    local found = false
    for k,v in pairs(WD.db.profile.rules) do
        if not v.role then v.role = "ANY" end
        if v.journalId == rule.journalId and v.type == rule.type and v.arg0 == rule.arg0 and v.arg1 == rule.arg1 then
            found = true
            v.role = rule.role
            v.points = rule.points
            break
        end
    end
    return found
end

local function insertRule(rule)
    if isDuplicate(rule) == false then
        WD.db.profile.rules[#WD.db.profile.rules+1] = rule
    end

    updateRuleLines()
end

local function insertEncounter(rules)
    if not rules or #rules == 0 then return end
    local journalId = rules[1].journalId
    local newRules = {}
    for k,v in pairs(WD.db.profile.rules) do
        if v.journalId ~= journalId then
            newRules[#newRules+1] = v
        end
    end
    for i=1,#rules do
        newRules[#newRules+1] = rules[i]
    end
    WD.db.profile.rules = newRules
    updateRuleLines()
end

local function isRuleSavable()
    local parent = WDRM.menus["new_rule"]
    if not parent.menus["encounters"].selected then
        print("Please select encounter")
        return false
    end
    if not parent.menus["rule_types"].selected then
        print("Please select rule type")
        return false
    end

    local arg0_edit = parent.hiddenMenus["arg0_edit"]
    local arg1_drop = parent.hiddenMenus["arg1_drop"]
    local arg1_edit = parent.hiddenMenus["arg1_edit"]

    local arg0 = arg0_edit:GetText()
    local arg1 = arg1_edit:GetText()

    local ruleType = parent.menus["rule_types"].selected.data.name
    if ruleType == "EV_DAMAGETAKEN" then
        if not GetSpellInfo(arg0) then
            print("Unknown spell id")
            return false
        end
        if tonumber(arg1) < 0 then
            print("Incorrect amount, must be >= 0")
            return false
        end
    elseif ruleType == "EV_DEATH" then
        if not GetSpellInfo(arg0) then
            print("Unknown spell id")
            return false
        end
    elseif ruleType == "EV_AURA" then
        if not GetSpellInfo(arg0) then
            print("Unknown aura id")
            return false
        end
        if not arg1_drop.selected then
            print("Please select action")
            return false
        end
    elseif ruleType == "EV_AURA_STACKS" then
        if not GetSpellInfo(arg0) then
            print("Unknown aura id")
            return false
        end
    elseif ruleType == "EV_CAST_START" then
        if not GetSpellInfo(arg0) then
            print("Unknown spell id")
            return false
        end
        if arg1:len() == 0 then
            print("Incorrect caster name")
            return false
        end
    elseif ruleType == "EV_CAST_END" then
        if not GetSpellInfo(arg0) then
            print("Unknown spell id")
            return false
        end
        if arg1:len() == 0 then
            print("Incorrect caster name")
            return false
        end
    elseif ruleType == "EV_CAST_INTERRUPTED" then
        if not GetSpellInfo(arg0) then
            print("Unknown target spell id")
            return false
        end
        if arg1:len() == 0 then
            print("Incorrect target name")
            return false
        end
    elseif ruleType == "EV_DEATH_UNIT" then
        if arg0:len() == 0 then
            print("Incorrect unit name")
            return false
        end
    elseif ruleType == "EV_DISPEL" then
        if not GetSpellInfo(arg0) then
            print("Unknown aura id")
            return false
        end
    elseif ruleType == "EV_POTIONS" or ruleType == "EV_FLASKS" or ruleType == "EV_FOOD" or ruleType == "EV_RUNES" then
        -- nothing to do here
    else
        print("Unsupported rule type:"..ruleType)
        return false
    end

    return true
end

local function saveRule()
    local parent = WDRM.menus["new_rule"]
    local journalId = parent.menus["encounters"].selected.data.journalId
    local ruleType = parent.menus["rule_types"].selected.txt:GetText()
    local arg0_edit = parent.hiddenMenus["arg0_edit"]
    local arg1_drop = parent.hiddenMenus["arg1_drop"]
    local arg1_edit = parent.hiddenMenus["arg1_edit"]
    local arg0 = arg0_edit:GetText()
    local arg1 = arg1_edit:GetText()

    local rule = {}
    rule.journalId = journalId
    rule.type = ruleType
    rule.arg0 = ""
    rule.arg1 = ""
    rule.points = parent.hiddenMenus["arg2_edit"]:GetNumber()
    rule.role = parent.menus["roles"]:GetText()
    rule.version = WD.Version

    if ruleType == "EV_DAMAGETAKEN" then
        rule.arg0 = tonumber(arg0) or 0
        rule.arg1 = tonumber(arg1) or 0
    elseif ruleType == "EV_DEATH" then
        rule.arg0 = tonumber(arg0) or 0
    elseif ruleType == "EV_AURA" then
        rule.arg0 = tonumber(arg0) or 0
        rule.arg1 = arg1_drop:GetText()
        if rule.arg1 ~= "apply" and rule.arg1 ~= "remove" then return end
    elseif ruleType == "EV_AURA_STACKS" then
        rule.arg0 = tonumber(arg0) or 0
        rule.arg1 = tonumber(arg1) or 0
    elseif ruleType == "EV_CAST_START" then
        rule.arg0 = tonumber(arg0) or 0
        rule.arg1 = arg1
    elseif ruleType == "EV_CAST_END" then
        rule.arg0 = tonumber(arg0) or 0
        rule.arg1 = arg1
    elseif ruleType == "EV_CAST_INTERRUPTED" then
        rule.arg0 = tonumber(arg0) or 0
        rule.arg1 = arg1
    elseif ruleType == "EV_DEATH_UNIT" then
        rule.arg0 = arg0
    elseif ruleType == "EV_DISPEL" then
        rule.arg0 = tonumber(arg0) or 0
    elseif ruleType == "EV_POTIONS" or ruleType == "EV_FLASKS" or ruleType == "EV_FOOD" or ruleType == "EV_RUNES" then
        -- nothing to do here
    else
        print("Unsupported rule type:"..rule.type)
        return
    end

    insertRule(rule)
end

local function updateNewRuleMenu(frame, selected)
--[[
    "EV_AURA"               arg0=aura_spell_id      arg1=apply or remove
    "EV_AURA_STACKS"        arg0=aura_spell_id      arg1=stacks or 0
    "EV_DISPEL"             arg0=aura_spell_id
    "EV_CAST_START"         arg0=spell_id           arg1=unit_name
    "EV_CAST_INTERRUPTED"   arg0=target_spell_id    arg1=target_unit_name
    "EV_CAST_END"           arg0=spell_id           arg1=unit_name
    "EV_DAMAGETAKEN"        arg0=spell_id           arg1=amount or 0
    "EV_DEATH"              arg0=spell_id
    "EV_DEATH_UNIT"         arg0=unit_name
    "EV_POTIONS"
    "EV_FLASKS"
    "EV_FOOD"
    "EV_RUNES"
]]
    local r = WDRM.menus["new_rule"]
    local rule = selected.name
    for _,v in pairs(r.hiddenMenus) do v:Hide() end
    local arg0_edit = r.hiddenMenus["arg0_edit"]
    local arg1_drop = r.hiddenMenus["arg1_drop"]
    local arg1_edit = r.hiddenMenus["arg1_edit"]
    local arg2_edit = r.hiddenMenus["arg2_edit"]

    local rule = selected.name

    if rule == "EV_AURA" then
        WdLib:showHiddenEditBox(r, "arg0_edit", "aura id")
        arg0_edit.label:SetText("Aura id:")
        WdLib:updateDropDownMenu(arg1_drop, "Select action:", {{name = "apply"},{name = "remove"}})
        arg1_drop.label:SetText("Action:")
        arg1_drop:Show()
    elseif rule == "EV_AURA_STACKS" then
        WdLib:showHiddenEditBox(r, "arg0_edit", "aura id")
        arg0_edit.label:SetText("Aura id:")
        WdLib:showHiddenEditBox(r, "arg1_edit", "stacks or 0 (if any)")
        arg1_edit.label:SetText("Stacks:")
    elseif rule == "EV_DISPEL" then
        WdLib:showHiddenEditBox(r, "arg0_edit", "aura id")
        arg0_edit.label:SetText("Aura id:")
    elseif rule == "EV_CAST_START" then
        WdLib:showHiddenEditBox(r, "arg0_edit", "spell id")
        arg0_edit.label:SetText("Spell id:")
        WdLib:showHiddenEditBox(r, "arg1_edit", "caster name")
        arg1_edit.label:SetText("Caster name:")
    elseif rule == "EV_CAST_INTERRUPTED" then
        WdLib:showHiddenEditBox(r, "arg0_edit", "target spell id")
        arg0_edit.label:SetText("Target spell id:")
        WdLib:showHiddenEditBox(r, "arg1_edit", "target name")
        arg1_edit.label:SetText("Target name:")
    elseif rule == "EV_CAST_END" then
        WdLib:showHiddenEditBox(r, "arg0_edit", "spell id")
        arg0_edit.label:SetText("Spell id:")
        WdLib:showHiddenEditBox(r, "arg1_edit", "caster name")
        arg1_edit.label:SetText("Caster name:")
    elseif rule == "EV_DAMAGETAKEN" then
        WdLib:showHiddenEditBox(r, "arg0_edit", "spell id")
        arg0_edit.label:SetText("Spell id:")
        WdLib:showHiddenEditBox(r, "arg1_edit", "amount or 0")
        arg1_edit.label:SetText("Amount:")
    elseif rule == "EV_DEATH" then
        WdLib:showHiddenEditBox(r, "arg0_edit", "spell id")
        arg0_edit.label:SetText("Spell id:")
    elseif rule == "EV_DEATH_UNIT" then
        WdLib:showHiddenEditBox(r, "arg0_edit", "unit name")
        arg0_edit.label:SetText("Unit name:")
    end

    WdLib:showHiddenEditBox(r, "arg2_edit", 0)
    arg2_edit.label:SetText("Points:")
end

local function initNewRuleWindow()
    WDRM.menus["new_rule"] = CreateFrame("Frame", nil, WDRM)
    local r = WDRM.menus["new_rule"]
    r.menus = {}
    r.hiddenMenus = {}
    r.buttons = {}

    local totalWidth = 325
    local xSize = 200
    local x = totalWidth - xSize

    -- encounters menu
    r.menus["encounters"] = WdLib:createDropDownMenu(r, "Select encounter", WD:CreateTierList())
    r.menus["encounters"]:SetSize(xSize, 20)
    r.menus["encounters"]:SetPoint("TOPLEFT", r, "TOPLEFT", x, -1)
    r.menus["encounters"].label = WdLib:createFontDefault(r.menus["encounters"], "RIGHT", "Encounter:")
    r.menus["encounters"].label:SetSize(x - 5, 20)
    r.menus["encounters"].label:SetPoint("TOPLEFT", r, "TOPLEFT", 1, -1)
    -- roles filter
    r.menus["roles"] = WdLib:createDropDownMenu(r, "ANY", WdLib:convertTypesToItems(WD.RoleTypes))
    r.menus["roles"].txt:SetJustifyH("CENTER")
    r.menus["roles"]:SetSize(xSize, 20)
    r.menus["roles"]:SetPoint("TOPLEFT", r.menus["encounters"], "BOTTOMLEFT", 0, -1)
    r.menus["roles"].label = WdLib:createFontDefault(r.menus["roles"], "RIGHT", "Role:")
    r.menus["roles"].label:SetSize(x - 5, 20)
    r.menus["roles"].label:SetPoint("TOPLEFT", r.menus["encounters"].label, "BOTTOMLEFT", 0, -1)
    -- events menu
    local items = WdLib:convertTypesToItems(WD.EventTypes, updateNewRuleMenu)
    table.insert(items, { name = "EV_POTIONS", func = updateNewRuleMenu })
    table.insert(items, { name = "EV_FLASKS", func = updateNewRuleMenu })
    table.insert(items, { name = "EV_FOOD", func = updateNewRuleMenu })
    table.insert(items, { name = "EV_RUNES", func = updateNewRuleMenu })
    r.menus["rule_types"] = WdLib:createDropDownMenu(r, "Select rule type", WdLib:updateItemsByHoverInfo(false, items, WD.Help.eventsInfo))
    r.menus["rule_types"]:SetSize(xSize, 20)
    r.menus["rule_types"]:SetPoint("TOPLEFT", r.menus["roles"], "BOTTOMLEFT", 0, -1)
    r.menus["rule_types"].label = WdLib:createFontDefault(r.menus["rule_types"], "RIGHT", "Rule:")
    r.menus["rule_types"].label:SetSize(x - 5, 20)
    r.menus["rule_types"].label:SetPoint("TOPLEFT", r.menus["roles"].label, "BOTTOMLEFT", 0, -1)

    -- arg0: editbox
    r.hiddenMenus["arg0_edit"] = WdLib:createEditBox(r)
    r.hiddenMenus["arg0_edit"]:SetSize(xSize, 20)
    r.hiddenMenus["arg0_edit"]:SetPoint("TOPLEFT", r.menus["rule_types"], "BOTTOMLEFT", 0, -1)
    r.hiddenMenus["arg0_edit"].label = WdLib:createFontDefault(r.hiddenMenus["arg0_edit"], "RIGHT", "")
    r.hiddenMenus["arg0_edit"].label:SetSize(x - 5, 20)
    r.hiddenMenus["arg0_edit"].label:SetPoint("TOPLEFT", r.menus["rule_types"].label, "BOTTOMLEFT", 0, -1)
    r.hiddenMenus["arg0_edit"]:Hide()

    -- arg1: dropdown or editbox
    r.hiddenMenus["arg1_drop"] = WdLib:createDropDownMenu(r, "Select aura action", {{name = "apply"},{name = "remove"}})
    r.hiddenMenus["arg1_drop"].txt:SetJustifyH("CENTER")
    r.hiddenMenus["arg1_drop"]:SetSize(xSize, 20)
    r.hiddenMenus["arg1_drop"]:SetPoint("TOPLEFT", r.hiddenMenus["arg0_edit"], "BOTTOMLEFT", 0, -1)
    r.hiddenMenus["arg1_drop"].label = WdLib:createFontDefault(r.hiddenMenus["arg1_drop"], "RIGHT", "")
    r.hiddenMenus["arg1_drop"].label:SetSize(x - 5, 20)
    r.hiddenMenus["arg1_drop"].label:SetPoint("TOPLEFT", r.hiddenMenus["arg0_edit"].label, "BOTTOMLEFT", 0, -1)
    r.hiddenMenus["arg1_drop"]:Hide()

    r.hiddenMenus["arg1_edit"] = WdLib:createEditBox(r)
    r.hiddenMenus["arg1_edit"]:SetSize(xSize, 20)
    r.hiddenMenus["arg1_edit"]:SetPoint("TOPLEFT", r.hiddenMenus["arg0_edit"], "BOTTOMLEFT", 0, -1)
    r.hiddenMenus["arg1_edit"].label = WdLib:createFontDefault(r.hiddenMenus["arg1_edit"], "RIGHT", "")
    r.hiddenMenus["arg1_edit"].label:SetSize(x - 5, 20)
    r.hiddenMenus["arg1_edit"].label:SetPoint("TOPLEFT", r.hiddenMenus["arg0_edit"].label, "BOTTOMLEFT", 0, -1)
    r.hiddenMenus["arg1_edit"]:Hide()

    -- arg2: editbox
    r.hiddenMenus["arg2_edit"] = WdLib:createEditBox(r)
    r.hiddenMenus["arg2_edit"]:SetNumeric()
    r.hiddenMenus["arg2_edit"]:SetSize(xSize, 20)
    r.hiddenMenus["arg2_edit"]:SetPoint("TOPLEFT", r.hiddenMenus["arg1_drop"], "BOTTOMLEFT", 0, -1)
    r.hiddenMenus["arg2_edit"].label = WdLib:createFontDefault(r.hiddenMenus["arg2_edit"], "RIGHT", "")
    r.hiddenMenus["arg2_edit"].label:SetSize(x - 5, 20)
    r.hiddenMenus["arg2_edit"].label:SetPoint("TOPLEFT", r.hiddenMenus["arg1_drop"].label, "BOTTOMLEFT", 0, -1)
    r.hiddenMenus["arg2_edit"]:Hide()

    r:SetScript("OnHide", function() for _,v in pairs(r.hiddenMenus) do v:Hide() end end)

    r.buttons["save"] = WdLib:createButton(r)
    r.buttons["save"]:SetPoint("TOPLEFT", r.hiddenMenus["arg2_edit"], "BOTTOMLEFT", 1, -2)
    r.buttons["save"]:SetSize(xSize / 2 - 1, 20)
    r.buttons["save"]:SetScript("OnClick", function() if isRuleSavable() then saveRule(); r:Hide() end end)
    r.buttons["save"].t:SetColorTexture(.2, .4, .2, 1)
    r.buttons["save"].txt = WdLib:createFont(r.buttons["save"], "CENTER", "Save")
    r.buttons["save"].txt:SetAllPoints()

    r.buttons["cancel"] = WdLib:createButton(r)
    r.buttons["cancel"]:SetPoint("TOPLEFT", r.buttons["save"], "TOPRIGHT", 1, 0)
    r.buttons["cancel"]:SetSize(xSize / 2 - 2, 20)
    r.buttons["cancel"]:SetScript("OnClick", function() r:Hide() end)
    r.buttons["cancel"].t:SetColorTexture(.4, .2, .2, 1)
    r.buttons["cancel"].txt = WdLib:createFont(r.buttons["cancel"], "CENTER", "Cancel")
    r.buttons["cancel"].txt:SetAllPoints()

    r:EnableMouse(true)
    r:SetPoint("CENTER", WDRM, -80, 150)
    r:SetSize(totalWidth, 7 * 21 + 3)
    r.bg = WdLib:createColorTexture(r, "TEXTURE", 0, 0, 0, 1)
    r.bg:SetAllPoints()

    r:Hide()
end

local function notifyEncounterRules(encounter)
    print("encounter instance id: " .. encounter.id)
    WdLib:sendMessage(string.format(WD_NOTIFY_HEADER_RULE, encounter.name))
    for _,v in pairs(WD.db.profile.rules) do
        if WD.EncounterNames[v.journalId] == encounter.name and v.isActive == true then
            local msg = string.format(WD_NOTIFY_RULE, v.role, v.points, getRuleDescription(v))
            WdLib:sendMessage(msg)
        end
    end
end

local function initNotifyRuleWindow()
    WDRM.menus["notify_rule"] = CreateFrame("Frame", nil, WDRM)
    local r = WDRM.menus["notify_rule"]
    r.menus = {}
    r:EnableMouse(true)
    r:SetPoint("BOTTOMLEFT", WDRM.buttons["notify"], "TOPLEFT", 0, 1)
    r:SetSize(152, 22)
    r.bg = WdLib:createColorTexture(r, "TEXTURE", 0, 0, 0, 1)
    r.bg:SetAllPoints()

    function notifyRule(encounter)
        WDRM.menus["notify_rule"]:Hide()
        notifyEncounterRules(encounter)
    end

    r.menus["encounters"] = WdLib:createDropDownMenu(r, "Select encounter", WD:CreateTierList(notifyRule))
    r.menus["encounters"]:SetSize(150, 20)
    r.menus["encounters"]:SetPoint("TOPLEFT", r, "TOPLEFT", 0, -1)

    r:Hide()
end

local function initExportEncounterWindow()
    WDRM.menus["export_encounter"] = CreateFrame("Frame", nil, WDRM)
    local r = WDRM.menus["export_encounter"]
    r.menus = {}
    r:EnableMouse(true)
    r:SetPoint("BOTTOMLEFT", WDRM.buttons["export"], "TOPLEFT", 0, 1)
    r:SetSize(152, 22)
    r.bg = WdLib:createColorTexture(r, "TEXTURE", 0, 0, 0, 1)
    r.bg:SetAllPoints()

    function tryExportEncounter(encounter)
        WDRM.menus["export_encounter"]:Hide()
        local rules = {}
        for _,v in pairs(WD.db.profile.rules) do
            if v.journalId == encounter.journalId then
                rules[#rules+1] = v
            end
        end
        exportEncounter(rules)
    end

    r.menus["encounters"] = WdLib:createDropDownMenu(r, "Select encounter", WD:CreateTierList(tryExportEncounter))
    r.menus["encounters"]:SetSize(150, 20)
    r.menus["encounters"]:SetPoint("TOPLEFT", r, "TOPLEFT", 0, -1)

    r:Hide()
end

local function initExportWindow()
    WDRM.exportWindow = CreateFrame("Frame", nil, WDRM)
    local r = WDRM.exportWindow
    r:EnableMouse(true)
    r:SetPoint("CENTER", 0, 0)
    r:SetSize(400, 400)
    r.bg = WdLib:createColorTexture(r, "TEXTURE", 0, 0, 0, 1)
    r.bg:SetAllPoints()

    WdLib:createXButton(r, -1)

    r.editBox = WdLib:createEditBox(r)
    r.editBox:SetSize(398, 378)
    r.editBox:SetPoint("TOPLEFT", r, "TOPLEFT", 1, -21)
    r.editBox:SetMultiLine(true)
    r.editBox:SetJustifyH("LEFT")
    r.editBox:SetMaxBytes(nil)
    r.editBox:SetMaxLetters(2048)
    r.editBox:SetScript("OnEscapePressed", function() r:Hide(); end)
    r.editBox:SetScript("OnMouseUp", function() r.editBox:HighlightText(); end)
    r.editBox:Show()

    r:Hide()
end

local function initPopupLogic()
    StaticPopupDialogs["WD_ACCEPT_IMPORT"] = {
        text = WD_IMPORT_QUESTION,
        button1 = WD_BUTTON_IMPORT,
        button2 = WD_BUTTON_CANCEL,
        OnAccept = function()
            insertEncounter(importEncounter(WDRM.menus["import_encounter"].editBox:GetText()))
            WDRM.menus["import_encounter"]:Hide()
        end,
        OnCancel = function()
            WDRM.menus["import_encounter"]:Hide()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = false,
        preferredIndex = 3,
    }

    StaticPopupDialogs["WD_ACCEPT_SHARED_RULE"] = {
        text = WD_IMPORT_SHARED_QUESTION,
        button1 = WD_BUTTON_ACCEPT,
        button2 = WD_BUTTON_CANCEL,
        OnAccept = function()
            if WDRM.sharedRule then
                local rule = importRule(WDRM.sharedRule)
                if isValidRule(rule) then
                    insertRule(rule)
                end
                WDRM.sharedRule = nil
            end
        end,
        OnHide = function()
            if #insertQueue > 0 then
                local sender = insertQueue[1].sender
                WDRM.sharedRule = insertQueue[1].str
                table.remove(insertQueue, 1)
                StaticPopup_Show("WD_ACCEPT_SHARED_RULE", sender)
            end
        end,
        OnCancel = function()
            if WDRM.sharedRule then WDRM.sharedRule = nil end
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = false,
        preferredIndex = 3,
    }
end

local function initImportEncounterWindow()
    WDRM.menus["import_encounter"] = CreateFrame("Frame", nil, WDRM)
    local r = WDRM.menus["import_encounter"]
    r:EnableMouse(true)
    r:SetPoint("CENTER", 0, 0)
    r:SetSize(400, 400)
    r.bg = WdLib:createColorTexture(r, "TEXTURE", 0, 0, 0, 1)
    r.bg:SetAllPoints()

    function tryImportEncounter(str)
        local rules = importEncounter(str)
        if rules and #rules > 0 then
            StaticPopup_Show("WD_ACCEPT_IMPORT", WD.EncounterNames[rules[1].journalId])
        else
            -- try import as single rule
            local rule = importRule(str)
            if isValidRule(rule) then
                insertRule(rule)
            end
            r:Hide()
        end
    end

    WdLib:createXButton(r, -1)

    r.editBox = WdLib:createEditBox(r)
    r.editBox:SetSize(398, 378)
    r.editBox:SetPoint("TOPLEFT", r, "TOPLEFT", 1, -22)
    r.editBox:SetMultiLine(true)
    r.editBox:SetJustifyH("LEFT")
    r.editBox:SetMaxBytes(nil)
    r.editBox:SetMaxLetters(2048)
    r.editBox:SetScript("OnEnterPressed", function() tryImportEncounter(r.editBox:GetText()) end)
    r.editBox:SetScript("OnEscapePressed", function() r:Hide(); end)
    r.editBox:SetScript("OnMouseUp", function() r.editBox:HighlightText(); end)
    r.editBox:SetScript("OnShow", function() r.editBox:SetText(""); r.editBox:SetFocus() end)
    r.editBox:Show()

    r.button = WdLib:createButton(r)
    r.button:SetPoint("TOPLEFT", r, "TOPLEFT", 1, -1)
    r.button:SetSize(125, 20)
    r.button:SetScript("OnClick", function() tryImportEncounter(r.editBox:GetText()) end)
    r.button.txt = WdLib:createFont(r.button, "CENTER", WD_BUTTON_IMPORT)
    r.button.txt:SetAllPoints()

    r:Hide()

    initPopupLogic()
end

local function initShareEncounterWindow()
    WDRM.menus["share_encounter"] = CreateFrame("Frame", nil, WDRM)
    local r = WDRM.menus["share_encounter"]
    r.menus = {}
    r:EnableMouse(true)
    r:SetPoint("BOTTOMLEFT", WDRM.buttons["share"], "TOPLEFT", 0, 1)
    r:SetSize(152, 22)
    r.bg = WdLib:createColorTexture(r, "TEXTURE", 0, 0, 0, 1)
    r.bg:SetAllPoints()

    function share(encounter)
        WDRM.menus["share_encounter"]:Hide()
        local rules = {}
        for _,v in pairs(WD.db.profile.rules) do
            if v.journalId == encounter.journalId then
                rules[#rules+1] = v
            end
        end
        shareEncounter(WD.EncounterNames[encounter.journalId], rules)
    end

    r.menus["encounters"] = WdLib:createDropDownMenu(r, "Select encounter", WD:CreateTierList(share))
    r.menus["encounters"]:SetSize(150, 20)
    r.menus["encounters"]:SetPoint("TOPLEFT", r, "TOPLEFT", 0, -1)

    StaticPopupDialogs["WD_ACCEPT_SHARED_ENCOUNTER"] = {
        text = WD_IMPORT_SHARED_ENCOUNTER_QUESTION,
        button1 = WD_BUTTON_ACCEPT,
        button2 = WD_BUTTON_CANCEL,
        OnAccept = function()
            if WDRM.sharedEncounter then
                WD:SendAddonMessage("response_share_encounter", WDRM.sharedEncounter)
            end
            WDRM.sharedEncounter = nil
        end,
        OnCancel = function()
            if WDRM.sharedEncounter then WDRM.sharedEncounter = nil end
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = false,
        preferredIndex = 3,
    }

    r:Hide()
end

local function onMenuClick(menu)
    if not WDRM.menus[menu] then return end
    if WDRM.menus[menu]:IsVisible() then
        WDRM.menus[menu]:Hide()
    else
        WDRM.menus[menu]:Show()
    end

    for k,v in pairs(WDRM.menus) do
        if k ~= menu then v:Hide() end
    end
end

function WD:InitEncountersModule(parent)
    WDRM = parent

    WDRM.menus = {}
    WDRM.buttons = {}
    WDRM.members = {}

    -- new rule button
    WDRM.buttons["add_rule"] = WdLib:createButton(WDRM)
    WDRM.buttons["add_rule"]:SetPoint("TOPLEFT", WDRM, "TOPLEFT", 1, -5)
    WDRM.buttons["add_rule"]:SetSize(125, 20)
    WDRM.buttons["add_rule"]:SetScript("OnClick", function() onMenuClick("new_rule") end)
    WDRM.buttons["add_rule"].txt = WdLib:createFont(WDRM.buttons["add_rule"], "CENTER", WD_BUTTON_NEW_RULE)
    WDRM.buttons["add_rule"].txt:SetAllPoints()

    -- notify rules button
    WDRM.buttons["notify"] = WdLib:createButton(WDRM)
    WDRM.buttons["notify"]:SetPoint("TOPLEFT", WDRM.buttons["add_rule"], "TOPRIGHT", 1, 0)
    WDRM.buttons["notify"]:SetSize(125, 20)
    WDRM.buttons["notify"]:SetScript("OnClick", function() onMenuClick("notify_rule") end)
    WDRM.buttons["notify"].txt = WdLib:createFont(WDRM.buttons["notify"], "CENTER", WD_BUTTON_NOTIFY_RULES)
    WDRM.buttons["notify"].txt:SetAllPoints()

    -- export encounter button
    WDRM.buttons["export"] = WdLib:createButton(WDRM)
    WDRM.buttons["export"]:SetPoint("TOPLEFT", WDRM.buttons["notify"], "TOPRIGHT", 1, 0)
    WDRM.buttons["export"]:SetSize(125, 20)
    WDRM.buttons["export"]:SetScript("OnClick", function() onMenuClick("export_encounter") end)
    WDRM.buttons["export"].txt = WdLib:createFont(WDRM.buttons["export"], "CENTER", WD_BUTTON_EXPORT_ENCOUNTERS)
    WDRM.buttons["export"].txt:SetAllPoints()

    -- import encounter button
    WDRM.buttons["import"] = WdLib:createButton(WDRM)
    WDRM.buttons["import"]:SetPoint("TOPLEFT", WDRM.buttons["export"], "TOPRIGHT", 1, 0)
    WDRM.buttons["import"]:SetSize(125, 20)
    WDRM.buttons["import"]:SetScript("OnClick", function() onMenuClick("import_encounter") end)
    WDRM.buttons["import"].txt = WdLib:createFont(WDRM.buttons["import"], "CENTER", WD_BUTTON_IMPORT_ENCOUNTERS)
    WDRM.buttons["import"].txt:SetAllPoints()

    -- share encounter button
    WDRM.buttons["share"] = WdLib:createButton(WDRM)
    WDRM.buttons["share"]:SetPoint("TOPLEFT", WDRM.buttons["import"], "TOPRIGHT", 1, 0)
    WDRM.buttons["share"]:SetSize(125, 20)
    WDRM.buttons["share"]:SetScript("OnClick", function() onMenuClick("share_encounter") end)
    WDRM.buttons["share"].txt = WdLib:createFont(WDRM.buttons["share"], "CENTER", WD_BUTTON_SHARE_ENCOUNTERS)
    WDRM.buttons["share"].txt:SetAllPoints()

    -- headers
    local x, y = 1, -30
    WDRM.headers = {}
    local h = WdLib:createTableHeader(WDRM, "", x, y, 20, 20)
    table.insert(WDRM.headers, h)
    h = WdLib:createTableHeader(WDRM, WD_BUTTON_ENCOUNTER, x + 21, y, 200, 20)
    table.insert(WDRM.headers, h)
    h = WdLib:createTableHeaderNext(WDRM, h, WD_BUTTON_ROLE, 75, 20)
    table.insert(WDRM.headers, h)
    h = WdLib:createTableHeaderNext(WDRM, h, WD_BUTTON_REASON, 450, 20)
    table.insert(WDRM.headers, h)
    h = WdLib:createTableHeaderNext(WDRM, h, WD_BUTTON_POINTS_SHORT, 50, 20)
    table.insert(WDRM.headers, h)
    h = WdLib:createTableHeaderNext(WDRM, h, "", 50, 20)
    table.insert(WDRM.headers, h)
    h = WdLib:createTableHeaderNext(WDRM, h, "", 50, 20)
    table.insert(WDRM.headers, h)
    h = WdLib:createTableHeaderNext(WDRM, h, "", 50, 20)
    table.insert(WDRM.headers, h)
    h = WdLib:createTableHeaderNext(WDRM, h, "", 70, 20)
    table.insert(WDRM.headers, h)

    initNewRuleWindow()
    initNotifyRuleWindow()
    initExportEncounterWindow()
    initExportWindow()
    initImportEncounterWindow()
    initShareEncounterWindow()

    updateRuleLines()

    function WDRM:OnUpdate()
        updateRuleLines()
    end
end

function WD:ReceiveSharedRule(sender, str)
    if WDRM.sharedRule then
        local data = {}
        data.sender = sender
        data.str = str
        insertQueue[#insertQueue+1] = data
        return
    end
    WDRM.sharedRule = str
    StaticPopup_Show("WD_ACCEPT_SHARED_RULE", sender)
end

function WD:ReceiveSharedEncounter(sender, encounter)
    WDRM.sharedEncounter = encounter
    StaticPopup_Show("WD_ACCEPT_SHARED_ENCOUNTER", sender, encounter)
end

function WD:SendSharedEncounter(sender, encounterName)
    for _,v in pairs(WD.db.profile.rules) do
        if v.journalId == encounterName then
            v.version = WD.Version
            local txt = WdLib:encode64(WdLib:table_tostring(v))
            WD:SendAddonMessage("receive_rule", txt, sender)
        end
    end
end

function WD:ReceiveRequestedRule(sender, data)
    local rule = importRule(data)
    if isValidRule(rule) then
        insertRule(rule)
    end
end

function WD:GetAllowedRoles(role)
    if role == "ANY" then return {"Tank", "Healer", "Melee", "Ranged", "Unknown"} end
    if role == "DPS" then return {"Melee", "Ranged"} end
    if role == "NOT_TANK" then return {"Healer", "Melee", "Ranged"} end
    return { role }
end

function WD:CreateTierList(fn)
    local t = {}

    local testItem = { name = "Test", id = 0, journalId = 0 }
    if fn then testItem.func = function() fn(testItem) end end
    table.insert(t, testItem)

    local allItem = { name = "ALL", id = -1, journalId = -1 }
    if fn then allItem.func = function() fn(allItem) end end
    table.insert(t, allItem)

    for _,tier in pairs(WD.TiersInfo) do
        local tierItem = {}
        tierItem.name = tier.name
        for _,inst in pairs(tier.instances) do
            if not tierItem.items then tierItem.items = {} end
            local instItem = {}
            instItem.name = inst.name
            for _,enc in pairs(inst.encounters) do
                if not instItem.items then instItem.items = {} end
                local encItem = {}
                encItem.name = enc.name
                encItem.journalId = enc.journalId
                if fn then encItem.func = function() fn(enc) end end
                table.insert(instItem.items, encItem)
            end
            table.insert(tierItem.items, instItem)
        end
        table.insert(t, tierItem)
    end
    return t
end
