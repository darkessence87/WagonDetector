
local WDRM = nil

local insertQueue = {}

local function findDropDownFrameByName(parent, name)
    for i=1,#parent.items do
        if parent.items[i].txt:GetText() == name then
            return parent.items[i]
        end

        if parent.items[i].items then
            local frame = findDropDownFrameByName(parent.items[i], name)
            if frame then return frame end
        end
    end
    return nil
end

local function editRuleLine(ruleLine)
    local newRuleFrame = WDRM.menus["new_rule"]
    if not ruleLine then return end

    if newRuleFrame:IsVisible() then newRuleFrame:Hide() return end
    newRuleFrame:Show()

    -- encounter
    local encounterName = WD.EncounterNames[ruleLine.rule.journalId]
    local frame = findDropDownFrameByName(newRuleFrame.menus["encounters"], encounterName)
    if frame then
        newRuleFrame.menus["encounters"].selected = frame
        newRuleFrame.menus["encounters"]:SetText(encounterName)
    end

    -- rule
    for i=1,#newRuleFrame.menus["rule_types"].items do
        if newRuleFrame.menus["rule_types"].items[i].txt:GetText() == ruleLine.rule.type then
            newRuleFrame.menus["rule_types"].selected = newRuleFrame.menus["rule_types"].items[i]
            newRuleFrame.menus["rule_types"]:SetText(ruleLine.rule.type)
            break
        end
    end

    -- role
    for i=1,#newRuleFrame.menus["roles"].items do
        if newRuleFrame.menus["roles"].items[i].txt:GetText() == ruleLine.rule.role then
            newRuleFrame.menus["roles"].selected = newRuleFrame.menus["roles"].items[i]
            newRuleFrame.menus["roles"]:SetText(ruleLine.rule.role)
            break
        end
    end
    newRuleFrame.menus["roles"]:Show()

    -- arg0
    if ruleLine.rule.type ~= "EV_POTIONS" and ruleLine.rule.type ~= "EV_FLASKS" and ruleLine.rule.type ~= "EV_FOOD" and ruleLine.rule.type ~= "EV_RUNES" then
        local txt = ruleLine.rule.arg0
        newRuleFrame.editBox0:SetText(txt)
        newRuleFrame.editBox0:SetScript("OnEscapePressed", function() newRuleFrame.editBox0:SetText(txt); newRuleFrame.editBox0:ClearFocus() end)
        newRuleFrame.editBox0:SetScript("OnEditFocusGained", function() newRuleFrame.editBox0:SetText(""); end)
        newRuleFrame.editBox0:Show()
    else
        newRuleFrame.editBox0:Hide()
    end

    -- arg1
    if ruleLine.rule.type == "EV_AURA" then
        for i=1,#newRuleFrame.menus["aura_actions"].items do
            if newRuleFrame.menus["aura_actions"].items[i].txt:GetText() == ruleLine.rule.arg1 then
                newRuleFrame.menus["aura_actions"].selected = newRuleFrame.menus["aura_actions"].items[i]
                newRuleFrame.menus["aura_actions"]:SetText(ruleLine.rule.arg1)
                break
            end
        end
        newRuleFrame.menus["aura_actions"]:Show()
        newRuleFrame.editBox1:Hide()
    elseif ruleLine.rule.type == "EV_DEATH"
        or ruleLine.rule.type == "EV_DEATH_UNIT"
        or ruleLine.rule.type == "EV_DISPEL"
        or ruleLine.rule.type == "EV_POTIONS"
        or ruleLine.rule.type == "EV_FLASKS"
        or ruleLine.rule.type == "EV_FOOD"
        or ruleLine.rule.type == "EV_RUNES"
    then
        newRuleFrame.editBox1:Hide()
        newRuleFrame.menus["aura_actions"]:Hide()
    else
        local ruleTxt = ruleLine.rule.arg1
        newRuleFrame.editBox1:SetText(ruleTxt)
        newRuleFrame.editBox1:SetScript("OnEscapePressed", function() newRuleFrame.editBox1:SetText(ruleTxt); newRuleFrame.editBox1:ClearFocus() end)
        newRuleFrame.editBox1:SetScript("OnEditFocusGained", function() newRuleFrame.editBox1:SetText(""); end)
        newRuleFrame.editBox1:Show()
        newRuleFrame.editBox1:ClearFocus()
        newRuleFrame.menus["aura_actions"]:Hide()
    end

    -- points
    local points = ruleLine.rule.points
    newRuleFrame.editBox2:SetText(points)
    newRuleFrame.editBox2:SetScript("OnEscapePressed", function() newRuleFrame.editBox2:SetText(points); newRuleFrame.editBox2:ClearFocus() end)
    newRuleFrame.editBox2:SetScript("OnEditFocusGained", function() newRuleFrame.editBox2:SetText(""); end)
    newRuleFrame.editBox2:Show()
end

local function getRuleDescription(rule)
    if rule.type == "EV_DAMAGETAKEN" then
        if rule.arg1 > 0 then
            return string.format(WD_RULE_DAMAGE_TAKEN_AMOUNT, rule.arg1, getSpellLinkById(rule.arg0))
        else
            return string.format(WD_RULE_DAMAGE_TAKEN, getSpellLinkById(rule.arg0))
        end
    elseif rule.type == "EV_DEATH" then
        return string.format(WD_RULE_DEATH, getSpellLinkById(rule.arg0))
    elseif rule.type == "EV_AURA" then
        if rule.arg1 == "apply" then
            return string.format(WD_RULE_APPLY_AURA, getSpellLinkById(rule.arg0))
        else
            return string.format(WD_RULE_REMOVE_AURA, getSpellLinkById(rule.arg0))
        end
    elseif rule.type == "EV_AURA_STACKS" then
        if rule.arg1 > 0 then
            return string.format(WD_RULE_AURA_STACKS, rule.arg1, getSpellLinkById(rule.arg0))
        else
            return string.format(WD_RULE_AURA_STACKS_ANY, "", getSpellLinkById(rule.arg0))
        end
    elseif rule.type == "EV_CAST_START" then
        return string.format(WD_RULE_CAST_START, rule.arg1, getSpellLinkById(rule.arg0))
    elseif rule.type == "EV_CAST_END" then
        return string.format(WD_RULE_CAST, rule.arg1, getSpellLinkById(rule.arg0))
    elseif rule.type == "EV_CAST_INTERRUPTED" then
        return string.format(WD_RULE_CAST_INTERRUPT, rule.arg1, getSpellLinkById(rule.arg0))
    elseif rule.type == "EV_DISPEL" then
        return string.format(WD_RULE_DISPEL, getSpellLinkById(rule.arg0))
    elseif rule.type == "EV_DEATH_UNIT" then
        return string.format(WD_RULE_DEATH_UNIT, rule.arg0)
    elseif rule.type == "EV_POTIONS" then
        return string.format(WD_RULE_POTIONS)
    elseif rule.type == "EV_FLASKS" then
        return string.format(WD_RULE_FLASKS)
    elseif rule.type == "EV_FOOD" then
        return string.format(WD_RULE_FOOD)
    elseif rule.type == "EV_RUNES" then
        return string.format(WD_RULE_RUNES)
    end

    return "Unsupported rule"
end

local function isValidRule(rule)
    if rule and rule.type then
        if not rule.version or rule.version < WD.minRulesVersion then
            print(string.format(WD_RULE_ERROR_OLD_VERSION, rule.version or "none", WD.minRulesVersion))
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
    rule.version = WD.version
    local txt = encode64(table.tostring(rule))
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
    for _,v in pairs(rules) do v.version = WD.version end
    local txt = encode64(table.tostring(rules))
    local r = WDRM.exportWindow
    r.editBox:SetText(txt)
    r.editBox:SetScript("OnChar", function() r.editBox:SetText(txt); r.editBox:HighlightText(); end)
    r.editBox:HighlightText()
    r.editBox:SetAutoFocus(true)
    r.editBox:SetCursorPosition(0)

    r:Show()
end

local function importRule(str)
    local d = decode64(str)
    local rule = parseRule(d)
    return rule
end

local function importEncounter(str)
    local d = decode64(str)
    local rules = parseEncounter(d)
    return rules
end

local function shareRule(rule)
    if not rule then return end
    rule.version = WD.version
    local txt = encode64(table.tostring(rule))
    WD:SendAddonMessage("share_rule", txt)
end

local function shareEncounter(encounterName, rules)
    if not rules or #rules == 0 then return end
    WD:SendAddonMessage("request_share_encounter", encounterName)
end

local function updateRuleLines()
    if not WDRM or not WDRM.rules then return end

    local maxWidth = 30
    local maxHeight = 545
    for i=1,#WDRM.headers do
        maxWidth = maxWidth + WDRM.headers[i]:GetWidth() + 1
    end

    local scroller = WDRM.scroller or createScroller(WDRM, maxWidth, maxHeight, #WD.db.profile.rules)
    if not WDRM.scroller then
        WDRM.scroller = scroller
    end

    -- sort by journalId > points > reason
    local func = function(a, b)
        if a.journalId < b.journalId then return true
        elseif a.journalId > b.journalId then return false
        elseif a.points > b.points then return true
        elseif a.points < b.points then return false
        elseif a.arg0 and b.arg0 then
            if tonumber(a.arg0) and tonumber(b.arg0) then return tonumber(a.arg0) < tonumber(b.arg0)
            else return tostring(a.arg0) < tostring(b.arg0)
            end
        else
            return true
        end
    end
    table.sort(WD.db.profile.rules, func)

    local x, y = 30, -51
    for k,v in pairs(WD.db.profile.rules) do
        if not WDRM.rules[k] then
            local ruleLine = CreateFrame("Frame", nil, WDRM.scroller.scrollerChild)
            ruleLine.rule = v
            ruleLine:SetSize(maxWidth, 20)
            ruleLine:SetPoint("TOPLEFT", WDRM.scroller.scrollerChild, "TOPLEFT", x, y)
            ruleLine.column = {}

            local index = 1
            ruleLine.column[index] = createCheckButton(ruleLine)
            ruleLine.column[index]:SetSize(18, 18)
            ruleLine.column[index]:SetPoint("TOPLEFT", ruleLine, "TOPLEFT", 1, -1)
            ruleLine.column[index]:SetChecked(v.isActive)
            ruleLine.column[index]:SetScript("OnClick", function() v.isActive = not v.isActive end)

            index = index + 1
            addNextColumn(WDRM, ruleLine, index, "LEFT", WD.EncounterNames[v.journalId])
            ruleLine.column[index]:SetPoint("TOPLEFT", ruleLine.column[index-1], "TOPRIGHT", 2, 1)
            local instanceName = WD.FindInstanceByJournalId(v.journalId)
            ruleLine.column[index]:SetScript("OnEnter", function(self)
                if instanceName then
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetText(instanceName, nil, nil, nil, nil, true)
                    GameTooltip:Show()
                end
            end)
            ruleLine.column[index]:SetScript("OnLeave", function() GameTooltip_Hide() end)

            index = index + 1
            addNextColumn(WDRM, ruleLine, index, "LEFT", v.role)
            index = index + 1
            addNextColumn(WDRM, ruleLine, index, "LEFT", getRuleDescription(v))
            ruleLine.column[index]:SetScript("OnEnter", function(self)
                local reason = getRuleDescription(v)
                local _, _, spellId = string.find(reason, "|Hspell:(.+)|h%[.*%]|h")
                if spellId then
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetHyperlink(getSpellLinkById(spellId))
                    GameTooltip:AddLine('id: '..spellId, 1, 1, 1)
                    GameTooltip:Show()
                end
            end)
            ruleLine.column[index]:SetScript("OnLeave", function() GameTooltip_Hide() end)

            index = index + 1
            addNextColumn(WDRM, ruleLine, index, "CENTER", v.points)
            index = index + 1
            addNextColumn(WDRM, ruleLine, index, "CENTER", WD_BUTTON_EDIT)
            ruleLine.column[index]:EnableMouse(true)
            ruleLine.column[index]:SetScript("OnClick", function() editRuleLine(ruleLine); end)
            ruleLine.column[index].t:SetColorTexture(.2, 1, .2, .5)
            index = index + 1
            addNextColumn(WDRM, ruleLine, index, "CENTER", WD_BUTTON_DELETE)
            ruleLine.column[index]:EnableMouse(true)
            ruleLine.column[index]:SetScript("OnClick", function() table.remove(WD.db.profile.rules, k); updateRuleLines(); end)
            ruleLine.column[index].t:SetColorTexture(1, .2, .2, .5)
            index = index + 1
            addNextColumn(WDRM, ruleLine, index, "CENTER", WD_BUTTON_EXPORT)
            ruleLine.column[index]:EnableMouse(true)
            ruleLine.column[index]:SetScript("OnClick", function() exportRule(ruleLine.rule); end)
            ruleLine.column[index].t:SetColorTexture(1, .2, .2, .5)
            index = index + 1
            addNextColumn(WDRM, ruleLine, index, "CENTER", WD_BUTTON_SHARE)
            ruleLine.column[index]:EnableMouse(true)
            ruleLine.column[index]:SetScript("OnClick", function() shareRule(ruleLine.rule); end)
            ruleLine.column[index].t:SetColorTexture(1, .2, .2, .5)

            table.insert(WDRM.rules, ruleLine)
        else
            local ruleLine = WDRM.rules[k]
            ruleLine.rule = v
            ruleLine.column[1]:SetChecked(v.isActive)
            ruleLine.column[1]:SetScript("OnClick", function() v.isActive = not v.isActive end)
            ruleLine.column[2].txt:SetText(WD.EncounterNames[v.journalId])
            local instanceName = WD.FindInstanceByJournalId(v.journalId)
            ruleLine.column[2]:SetScript("OnEnter", function(self)
                if instanceName then
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetText(instanceName, nil, nil, nil, nil, true)
                    GameTooltip:Show()
                end
            end)
            ruleLine.column[3].txt:SetText(v.role)
            ruleLine.column[4].txt:SetText(getRuleDescription(v))
            ruleLine.column[4]:SetScript("OnEnter", function(self)
                local reason = getRuleDescription(v)
                local _, _, spellId = string.find(reason, "|Hspell:(.+)|h%[.*%]|h")
                if spellId then
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetHyperlink(getSpellLinkById(spellId))
                    GameTooltip:AddLine('id: '..spellId, 1, 1, 1)
                    GameTooltip:Show()
                end
            end)

            ruleLine.column[5].txt:SetText(v.points)
            ruleLine.column[6]:SetScript("OnClick", function() editRuleLine(ruleLine); end)

            ruleLine.column[8]:SetScript("OnClick", function() exportRule(ruleLine.rule); end)
            ruleLine.column[9]:SetScript("OnClick", function() shareRule(ruleLine.rule); end)
            ruleLine:Show()
            updateScroller(WDRM.scroller.slider, #WD.db.profile.rules)
        end

        y = y - 21
    end

    if #WD.db.profile.rules < #WDRM.rules then
        for i=#WD.db.profile.rules+1, #WDRM.rules do
            WDRM.rules[i]:Hide()
        end
    end
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

local function saveRule()
    local f = WDRM.menus["new_rule"]
    if not f.menus["encounters"].selected or not f.menus["rule_types"].selected then return end
    local journalId = f.menus["encounters"].selected.data.journalId
    local ruleType = f.menus["rule_types"].selected.txt:GetText()

    local rule = {}
    rule.journalId = journalId
    rule.type = ruleType
    rule.arg0 = ""
    rule.arg1 = ""
    rule.points = f.editBox2:GetNumber()
    rule.role = f.menus["roles"]:GetText()
    rule.version = WD.version

    if ruleType == "EV_DAMAGETAKEN" then
        rule.arg0 = tonumber(f.editBox0:GetText()) or 0
        rule.arg1 = tonumber(f.editBox1:GetText()) or 0
    elseif ruleType == "EV_DEATH" then
        rule.arg0 = tonumber(f.editBox0:GetText()) or 0
    elseif ruleType == "EV_AURA" then
        rule.arg0 = tonumber(f.editBox0:GetText()) or 0
        rule.arg1 = f.menus["aura_actions"]:GetText()
        if rule.arg1 ~= "apply" and rule.arg1 ~= "remove" then return end
    elseif ruleType == "EV_AURA_STACKS" then
        rule.arg0 = tonumber(f.editBox0:GetText()) or 0
        rule.arg1 = tonumber(f.editBox1:GetText()) or 0
    elseif ruleType == "EV_CAST_START" then
        rule.arg0 = tonumber(f.editBox0:GetText()) or 0
        rule.arg1 = f.editBox1:GetText()
    elseif ruleType == "EV_CAST_END" then
        rule.arg0 = tonumber(f.editBox0:GetText()) or 0
        rule.arg1 = f.editBox1:GetText()
    elseif ruleType == "EV_CAST_INTERRUPTED" then
        rule.arg0 = tonumber(f.editBox0:GetText()) or 0
        rule.arg1 = f.editBox1:GetText()
    elseif ruleType == "EV_DEATH_UNIT" then
        rule.arg0 = f.editBox0:GetText()
    elseif ruleType == "EV_DISPEL" then
        rule.arg0 = tonumber(f.editBox0:GetText()) or 0
    elseif ruleType == "EV_POTIONS" or ruleType == "EV_FLASKS" or ruleType == "EV_FOOD" or ruleType == "EV_RUNES" then
        -- nothing to do here
    else
        print("Unsupported rule type:"..rule.type)
        return
    end

    insertRule(rule)
end

local function updateNewRuleMenu()
    local newRuleFrame = WDRM.menus["new_rule"]
    if not newRuleFrame.menus["rule_types"].selected then return end

    local rule = newRuleFrame.menus["rule_types"].selected.txt:GetText()

    -- arg0 name (based on rule type)
    if rule ~= "EV_POTIONS" and rule ~= "EV_FLASKS" and rule ~= "EV_FOOD" and rule ~= "EV_RUNES" then
        local txt = ""
        if rule == "EV_DEATH_UNIT" then
            txt = "unit name"
        else
            txt = "spellid"
        end

        newRuleFrame.editBox0:SetText(txt)
        newRuleFrame.editBox0:SetScript("OnEscapePressed", function() newRuleFrame.editBox0:SetText(txt); newRuleFrame.editBox0:ClearFocus() end)
        newRuleFrame.editBox0:SetScript("OnEditFocusGained", function() newRuleFrame.editBox0:SetText(""); end)
        newRuleFrame.editBox0:Show()
    else
        newRuleFrame.editBox0:Hide()
    end

    -- arg1 name (based on rule type)
    if rule == "EV_AURA" then
        newRuleFrame.editBox1:Hide()
        newRuleFrame.menus["aura_actions"]:Show()
    elseif rule == "EV_DEATH"
        or rule == "EV_DEATH_UNIT"
        or rule == "EV_DISPEL"
        or rule == "EV_POTIONS"
        or rule == "EV_FLASKS"
        or rule == "EV_FOOD"
        or rule == "EV_RUNES"
    then
        newRuleFrame.editBox1:Hide()
        newRuleFrame.menus["aura_actions"]:Hide()
    else
        local ruleTxt = ""
        if rule == "EV_DAMAGETAKEN" then
            ruleTxt = "amount or any"
        elseif rule == "EV_AURA_STACKS" then
            ruleTxt = "stacks (0 if any)"
        elseif rule == "EV_CAST_START" or rule == "EV_CAST_END" or rule == "EV_CAST_INTERRUPTED" then
            ruleTxt = "unit name"
        end
        newRuleFrame.editBox1:SetText(ruleTxt)
        newRuleFrame.editBox1:SetScript("OnEscapePressed", function() newRuleFrame.editBox1:SetText(ruleTxt); newRuleFrame.editBox1:ClearFocus() end)
        newRuleFrame.editBox1:SetScript("OnEditFocusGained", function() newRuleFrame.editBox1:SetText(""); end)
        newRuleFrame.editBox1:Show()
        newRuleFrame.editBox1:ClearFocus()
        newRuleFrame.menus["aura_actions"]:Hide()
    end

    -- arg2 points
    newRuleFrame.editBox2:SetText("points")
    newRuleFrame.editBox2:SetScript("OnEscapePressed", function() newRuleFrame.editBox2:SetText("points"); newRuleFrame.editBox2:ClearFocus() end)
    newRuleFrame.editBox2:SetScript("OnEditFocusGained", function() newRuleFrame.editBox2:SetText(""); end)
    newRuleFrame.editBox2:Show()

    -- role
    newRuleFrame.menus["roles"]:Show()
end

local function initNewRuleWindow()
    WDRM.menus["new_rule"] = CreateFrame("Frame", nil, WDRM)
    local r = WDRM.menus["new_rule"]
    r.menus = {}
    r:EnableMouse(true)
    r:SetPoint("BOTTOMLEFT", WDRM.buttons["add_rule"], "TOPLEFT", -1, 6)
    r:SetSize(300, 151)
    r.bg = createColorTexture(r, "TEXTURE", 0, 0, 0, 1)
    r.bg:SetAllPoints()

    local xSize = 298

    r.menus["encounters"] = createDropDownMenu(r, "Select encounter", WD:CreateTierList())
    r.menus["encounters"]:SetSize(xSize, 20)
    r.menus["encounters"]:SetPoint("TOPLEFT", r, "TOPLEFT", 1, -1)

    local items1 = {}
    for i=1,#WD.RuleTypes do
        local item = { name = WD.RuleTypes[i], func = updateNewRuleMenu }
        table.insert(items1, item)
    end

    r.menus["rule_types"] = createDropDownMenu(r, "Select rule type", items1)
    r.menus["rule_types"]:SetSize(xSize, 20)
    r.menus["rule_types"]:SetPoint("TOPLEFT", r.menus["encounters"], "BOTTOMLEFT", 0, -1)

    -- editbox arg0
    r.editBox0 = createEditBox(r)
    r.editBox0:SetSize(xSize, 20)
    r.editBox0:SetPoint("TOPLEFT", r.menus["rule_types"], "BOTTOMLEFT", 0, -1)
    r.editBox0:Hide()

    -- editbox or dropdownmenu arg1
    r.editBox1 = createEditBox(r)
    r.editBox1:SetSize(xSize, 20)
    r.editBox1:SetPoint("TOPLEFT", r.editBox0, "BOTTOMLEFT", 0, -1)
    r.editBox1:Hide()

    local items2 = { {name = "apply"},{name = "remove"} }
    r.menus["aura_actions"] = createDropDownMenu(r, "Select aura action", items2)
    r.menus["aura_actions"].txt:SetJustifyH("CENTER")
    r.menus["aura_actions"]:SetSize(xSize, 20)
    r.menus["aura_actions"]:SetPoint("TOPLEFT", r.editBox0, "BOTTOMLEFT", 0, -1)
    r.menus["aura_actions"]:Hide()

    -- editbox arg2
    r.editBox2 = createEditBox(r)
    r.editBox2:SetNumeric()
    r.editBox2:SetSize(xSize, 20)
    r.editBox2:SetPoint("TOPLEFT", r.editBox0, "BOTTOMLEFT", 0, -22)
    r.editBox2:Hide()

    -- role filter
    local items3 = {}
    for i=1,#WD.RoleTypes do
        local item = { name = WD.RoleTypes[i] }
        table.insert(items3, item)
    end
    r.menus["roles"] = createDropDownMenu(r, "ANY", items3)
    r.menus["roles"].txt:SetJustifyH("CENTER")
    r.menus["roles"]:SetSize(xSize, 20)
    r.menus["roles"]:SetPoint("TOPLEFT", r.editBox2, "BOTTOMLEFT", 0, -1)
    r.menus["roles"]:Hide()

    r:SetScript("OnHide", function()
        r.editBox0:Hide()
        r.editBox1:Hide()
        r.editBox2:Hide()
        r.menus["aura_actions"]:Hide()
        r.menus["roles"]:Hide()
    end)

    r.saveButton = createButton(r)
    r.saveButton:SetPoint("TOPLEFT", r.menus["roles"], "BOTTOMLEFT", 1, -2)
    r.saveButton:SetSize(xSize / 2 - 1, 20)
    r.saveButton:SetScript("OnClick", function() saveRule(); r:Hide() end)
    r.saveButton.t:SetColorTexture(.2, .4, .2, 1)
    r.saveButton.txt = createFont(r.saveButton, "CENTER", "Save")
    r.saveButton.txt:SetAllPoints()

    r.cancelButton = createButton(r)
    r.cancelButton:SetPoint("TOPLEFT", r.saveButton, "TOPRIGHT", 1, 0)
    r.cancelButton:SetSize(xSize / 2 - 2, 20)
    r.cancelButton:SetScript("OnClick", function() r:Hide() end)
    r.cancelButton.t:SetColorTexture(.4, .2, .2, 1)
    r.cancelButton.txt = createFont(r.cancelButton, "CENTER", "Cancel")
    r.cancelButton.txt:SetAllPoints()

    r:Hide()
end

local function notifyEncounterRules(encounter)
    print("encounter instance id: " .. encounter.id)
    sendMessage(string.format(WD_NOTIFY_HEADER_RULE, encounter.name))
    for _,v in pairs(WD.db.profile.rules) do
        if WD.EncounterNames[v.journalId] == encounter.name and v.isActive == true then
            local msg = string.format(WD_NOTIFY_RULE, v.role, v.points, getRuleDescription(v))
            sendMessage(msg)
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
    r.bg = createColorTexture(r, "TEXTURE", 0, 0, 0, 1)
    r.bg:SetAllPoints()

    function notifyRule(encounter)
        WDRM.menus["notify_rule"]:Hide()
        notifyEncounterRules(encounter)
    end

    r.menus["encounters"] = createDropDownMenu(r, "Select encounter", WD:CreateTierList(notifyRule))
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
    r.bg = createColorTexture(r, "TEXTURE", 0, 0, 0, 1)
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

    r.menus["encounters"] = createDropDownMenu(r, "Select encounter", WD:CreateTierList(tryExportEncounter))
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
    r.bg = createColorTexture(r, "TEXTURE", 0, 0, 0, 1)
    r.bg:SetAllPoints()

    createXButton(r, -1)

    r.editBox = createEditBox(r)
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
    r.bg = createColorTexture(r, "TEXTURE", 0, 0, 0, 1)
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

    createXButton(r, -1)

    r.editBox = createEditBox(r)
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

    r.button = createButton(r)
    r.button:SetPoint("TOPLEFT", r, "TOPLEFT", 1, -1)
    r.button:SetSize(125, 20)
    r.button:SetScript("OnClick", function() tryImportEncounter(r.editBox:GetText()) end)
    r.button.txt = createFont(r.button, "CENTER", WD_BUTTON_IMPORT)
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
    r.bg = createColorTexture(r, "TEXTURE", 0, 0, 0, 1)
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

    r.menus["encounters"] = createDropDownMenu(r, "Select encounter", WD:CreateTierList(share))
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
    WDRM.rules = {}

    -- new rule button
    WDRM.buttons["add_rule"] = createButton(WDRM)
    WDRM.buttons["add_rule"]:SetPoint("TOPLEFT", WDRM, "TOPLEFT", 1, -5)
    WDRM.buttons["add_rule"]:SetSize(125, 20)
    WDRM.buttons["add_rule"]:SetScript("OnClick", function() onMenuClick("new_rule") end)
    WDRM.buttons["add_rule"].txt = createFont(WDRM.buttons["add_rule"], "CENTER", WD_BUTTON_NEW_RULE)
    WDRM.buttons["add_rule"].txt:SetAllPoints()

    -- notify rules button
    WDRM.buttons["notify"] = createButton(WDRM)
    WDRM.buttons["notify"]:SetPoint("TOPLEFT", WDRM.buttons["add_rule"], "TOPRIGHT", 1, 0)
    WDRM.buttons["notify"]:SetSize(125, 20)
    WDRM.buttons["notify"]:SetScript("OnClick", function() onMenuClick("notify_rule") end)
    WDRM.buttons["notify"].txt = createFont(WDRM.buttons["notify"], "CENTER", WD_BUTTON_NOTIFY_RULES)
    WDRM.buttons["notify"].txt:SetAllPoints()

    -- export encounter button
    WDRM.buttons["export"] = createButton(WDRM)
    WDRM.buttons["export"]:SetPoint("TOPLEFT", WDRM.buttons["notify"], "TOPRIGHT", 1, 0)
    WDRM.buttons["export"]:SetSize(125, 20)
    WDRM.buttons["export"]:SetScript("OnClick", function() onMenuClick("export_encounter") end)
    WDRM.buttons["export"].txt = createFont(WDRM.buttons["export"], "CENTER", WD_BUTTON_EXPORT_ENCOUNTERS)
    WDRM.buttons["export"].txt:SetAllPoints()

    -- import encounter button
    WDRM.buttons["import"] = createButton(WDRM)
    WDRM.buttons["import"]:SetPoint("TOPLEFT", WDRM.buttons["export"], "TOPRIGHT", 1, 0)
    WDRM.buttons["import"]:SetSize(125, 20)
    WDRM.buttons["import"]:SetScript("OnClick", function() onMenuClick("import_encounter") end)
    WDRM.buttons["import"].txt = createFont(WDRM.buttons["import"], "CENTER", WD_BUTTON_IMPORT_ENCOUNTERS)
    WDRM.buttons["import"].txt:SetAllPoints()

    -- share encounter button
    WDRM.buttons["share"] = createButton(WDRM)
    WDRM.buttons["share"]:SetPoint("TOPLEFT", WDRM.buttons["import"], "TOPRIGHT", 1, 0)
    WDRM.buttons["share"]:SetSize(125, 20)
    WDRM.buttons["share"]:SetScript("OnClick", function() onMenuClick("share_encounter") end)
    WDRM.buttons["share"].txt = createFont(WDRM.buttons["share"], "CENTER", WD_BUTTON_SHARE_ENCOUNTERS)
    WDRM.buttons["share"].txt:SetAllPoints()

    -- headers
    local x, y = 1, -30
    WDRM.headers = {}
    local h = createTableHeader(WDRM, "", x, y, 20, 20)
    table.insert(WDRM.headers, h)
    h = createTableHeader(WDRM, WD_BUTTON_ENCOUNTER, x + 21, y, 150, 20)
    table.insert(WDRM.headers, h)
    h = createTableHeaderNext(WDRM, h, WD_BUTTON_ROLE, 75, 20)
    table.insert(WDRM.headers, h)
    h = createTableHeaderNext(WDRM, h, WD_BUTTON_REASON, 300, 20)
    table.insert(WDRM.headers, h)
    h = createTableHeaderNext(WDRM, h, WD_BUTTON_POINTS_SHORT, 50, 20)
    table.insert(WDRM.headers, h)
    h = createTableHeaderNext(WDRM, h, "", 50, 20)
    table.insert(WDRM.headers, h)
    h = createTableHeaderNext(WDRM, h, "", 50, 20)
    table.insert(WDRM.headers, h)
    h = createTableHeaderNext(WDRM, h, "", 50, 20)
    table.insert(WDRM.headers, h)
    h = createTableHeaderNext(WDRM, h, "", 70, 20)
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
            v.version = WD.version
            local txt = encode64(table.tostring(v))
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
