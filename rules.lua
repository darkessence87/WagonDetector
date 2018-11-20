
local WDRM = nil

encounterTypes = {
    "Test",
    "ALL",
    "UD_TALOC",
    "UD_MOTHER",
    "UD_ZEKVOZ",
    "UD_VECTIS",
    "UD_FETID",
    "UD_ZUL",
    "UD_MYTRAX",
    "UD_GHUUN",
}

ruleTypes = {
    "EV_DAMAGETAKEN",
    "EV_DEATH",
    "EV_AURA",
    "EV_AURA_STACKS",
    "EV_START_CAST",
    "EV_CAST",
    "EV_INTERRUPTED_CAST",
    "EV_DEATH_UNIT",
    "EV_POTIONS",
    "EV_FLASKS",
    "EV_FOOD",
    "EV_RUNES"
}

local function editRuleLine(ruleLine)
    local newRuleFrame = WDRM.newRule
    if not ruleLine then return end

    if newRuleFrame:IsVisible() then newRuleFrame:Hide() return end
    newRuleFrame:Show()

    -- encounter
    for i=1,#newRuleFrame.dropFrame0.items do
        if newRuleFrame.dropFrame0.items[i].txt:GetText() == ruleLine.rule.encounter then
            newRuleFrame.dropFrame0.selected = newRuleFrame.dropFrame0.items[i]
            newRuleFrame.dropFrame0:SetText(ruleLine.rule.encounter)
            break
        end
    end

    -- rule
    for i=1,#newRuleFrame.dropFrame1.items do
        if newRuleFrame.dropFrame1.items[i].txt:GetText() == ruleLine.rule.type then
            newRuleFrame.dropFrame1.selected = newRuleFrame.dropFrame1.items[i]
            newRuleFrame.dropFrame1:SetText(ruleLine.rule.type)
            break
        end
    end

    -- arg0
    if rule ~= "EV_POTIONS" and rule ~= "EV_FLASKS" and rule ~= "EV_FOOD" and rule ~= "EV_RUNES" then
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
        for i=1,#newRuleFrame.dropMenu1.items do
            if newRuleFrame.dropMenu1.items[i].txt:GetText() == ruleLine.rule.arg1 then
                newRuleFrame.dropMenu1.selected = newRuleFrame.dropMenu1.items[i]
                newRuleFrame.dropMenu1:SetText(ruleLine.rule.arg1)
                break
            end
        end
        newRuleFrame.dropMenu1:Show()
        newRuleFrame.editBox1:Hide()
    elseif ruleLine.rule.type == "EV_DEATH"
        or ruleLine.rule.type == "EV_DEATH_UNIT"
        or ruleLine.rule.type == "EV_POTIONS"
        or ruleLine.rule.type == "EV_FLASKS"
        or ruleLine.rule.type == "EV_FOOD"
        or ruleLine.rule.type == "EV_RUNES"
    then
        newRuleFrame.editBox1:Hide()
        newRuleFrame.dropMenu1:Hide()
    else
        local ruleTxt = ruleLine.rule.arg1
        newRuleFrame.editBox1:SetText(ruleTxt)
        newRuleFrame.editBox1:SetScript("OnEscapePressed", function() newRuleFrame.editBox1:SetText(ruleTxt); newRuleFrame.editBox1:ClearFocus() end)
        newRuleFrame.editBox1:SetScript("OnEditFocusGained", function() newRuleFrame.editBox1:SetText(""); end)
        newRuleFrame.editBox1:Show()
        newRuleFrame.editBox1:ClearFocus()
        newRuleFrame.dropMenu1:Hide()
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
            return string.format(WD_RULE_DAMAGE_TAKEN, rule.arg1, getSpellLinkById(rule.arg0))
        else
            return string.format(WD_RULE_DAMAGE_TAKEN_AMOUNT, getSpellLinkById(rule.arg0))
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
        return string.format(WD_RULE_AURA_STACKS, rule.arg1, getSpellLinkById(rule.arg0))
    elseif rule.type == "EV_START_CAST" then
        return string.format(WD_RULE_CAST_START, rule.arg1, getSpellLinkById(rule.arg0))
    elseif rule.type == "EV_CAST" then
        return string.format(WD_RULE_CAST, rule.arg1, getSpellLinkById(rule.arg0))
    elseif rule.type == "EV_INTERRUPTED_CAST" then
        return string.format(WD_RULE_CAST_INTERRUPT, getSpellLinkById(rule.arg0), rule.arg1)
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
    for i in string.gmatch(str, "[%w]+=[%w|\"|_|%-]+") do
        local dashIndex = string.find(i, "%=")
        if dashIndex then
            local k = string.sub(i, 1, dashIndex - 1)
            local v = parseValue(string.sub(i, dashIndex + 1))
            if k == "type" then
                rule.type = v
            elseif k == "encounter" then
                rule.encounter = v
            elseif k == "arg0" then
                rule.arg0 = v
            elseif k == "arg1" then
                rule.arg1 = v
            elseif k == "points" then
                rule.points = tonumber(v)
            elseif k == "isActive" then
                rule.isActive = v
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
    local txt = encode64(table.tostring(rule))
    WD:SendAddonMessage("share_rule", txt)
end

local function shareEncounter(encounterName, rules)
    if not rules or #rules == 0 then return end
    local txt = encode64(table.tostring(rules))
    WD:SendAddonMessage("share_encounter", encounterName.."$"..txt)
end

local function updateRuleLines()
    if not WDRM.rules then return end

    local maxWidth = 30
    local maxHeight = 545
    for i=1,#WDRM.headers do
        maxWidth = maxWidth + WDRM.headers[i]:GetWidth() + 1
    end

    local scroller = WDRM.scroller or createScroller(WDRM, maxWidth, maxHeight, #WD.db.profile.rules)
    if not WDRM.scroller then
        WDRM.scroller = scroller
    end

    -- sort by encounter > points
    local func = function(a, b)
        if a.encounter < b.encounter then return true
        elseif a.encounter > b.encounter then return false
        else
            return a.points > b.points
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
            addNextColumn(WDRM, ruleLine, index, "CENTER", v.encounter)
            ruleLine.column[index]:SetPoint("TOPLEFT", ruleLine.column[index-1], "TOPRIGHT", 2, 1)
            index = index + 1
            addNextColumn(WDRM, ruleLine, index, "LEFT", getRuleDescription(v))
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
            ruleLine.column[2].txt:SetText(v.encounter)
            ruleLine.column[3].txt:SetText(getRuleDescription(v))
            ruleLine.column[4].txt:SetText(v.points)
            ruleLine.column[5]:SetScript("OnClick", function() editRuleLine(ruleLine); end)
            ruleLine.column[7]:SetScript("OnClick", function() exportRule(ruleLine.rule); end)
            ruleLine.column[8]:SetScript("OnClick", function() shareRule(ruleLine.rule); end)
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
    local found = false
    for k,v in pairs(WD.db.profile.rules) do
        if v.encounter == rule.encounter and v.type == rule.type and v.arg0 == rule.arg0 and v.arg1 == rule.arg1 then
            found = true
            v.points = rule.points
            break
        end
    end
    return found
end

local function insertRule(rule)
    if rule.points ~= "" and rule.points ~= 0 then
        if isDuplicate(rule) == false then
            rule.isActive = true
            WD.db.profile.rules[#WD.db.profile.rules+1] = rule
            updateRuleLines()
        else
            print("This rule already exists")
        end
    else
        print("Could not add rule with empty points")
    end
end

local function insertEncounter(rules)
    if not rules or #rules == 0 then return end
    local encounter = rules[1].encounter
    local newRules = {}
    for k,v in pairs(WD.db.profile.rules) do
        if v.encounter ~= encounter then
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
    local f = WDRM.newRule
    if not f.dropFrame0.selected or not f.dropFrame1.selected then return end
    local encounterType = f.dropFrame0.selected.txt:GetText()
    local ruleType = f.dropFrame1.selected.txt:GetText()

    local rule = {}
    rule.encounter = encounterType
    rule.type = ruleType
    rule.arg0 = ""
    rule.arg1 = ""
    rule.points = f.editBox2:GetNumber()

    if ruleType == "EV_DAMAGETAKEN" then
        rule.arg0 = tonumber(f.editBox0:GetText()) or 0
        rule.arg1 = tonumber(f.editBox1:GetText()) or 0
    elseif ruleType == "EV_DEATH" then
        rule.arg0 = tonumber(f.editBox0:GetText()) or 0
    elseif ruleType == "EV_AURA" then
        rule.arg0 = tonumber(f.editBox0:GetText()) or 0
        rule.arg1 = f.dropMenu1:GetText()
        if rule.arg1 ~= "apply" and rule.arg1 ~= "remove" then return end
    elseif ruleType == "EV_AURA_STACKS" then
        rule.arg0 = tonumber(f.editBox0:GetText()) or 0
        rule.arg1 = tonumber(f.editBox1:GetText()) or 1
    elseif ruleType == "EV_START_CAST" then
        rule.arg0 = tonumber(f.editBox0:GetText()) or 0
        rule.arg1 = f.editBox1:GetText()
    elseif ruleType == "EV_CAST" then
        rule.arg0 = tonumber(f.editBox0:GetText()) or 0
        rule.arg1 = f.editBox1:GetText()
    elseif ruleType == "EV_INTERRUPTED_CAST" then
        rule.arg0 = tonumber(f.editBox0:GetText()) or 0
        rule.arg1 = f.editBox1:GetText()
    elseif ruleType == "EV_DEATH_UNIT" then
        rule.arg0 = f.editBox0:GetText()
    elseif ruleType == "EV_POTIONS" or ruleType == "EV_FLASKS" or ruleType == "EV_FOOD" or ruleType == "EV_RUNES" then
        -- nothing to do here
    else
        print("Unsupported rule type:"..rule.type)
        return
    end

    insertRule(rule)
end

local function updateNewRuleMenu()
    local newRuleFrame = WDRM.newRule
    if not newRuleFrame.dropFrame1.selected then return end

    local rule = newRuleFrame.dropFrame1.selected.txt:GetText()

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
        newRuleFrame.dropMenu1:Show()
    elseif rule == "EV_DEATH"
        or rule == "EV_DEATH_UNIT"
        or rule == "EV_POTIONS"
        or rule == "EV_FLASKS"
        or rule == "EV_FOOD"
        or rule == "EV_RUNES"
    then
        newRuleFrame.editBox1:Hide()
        newRuleFrame.dropMenu1:Hide()
    else
        local ruleTxt = ""
        if rule == "EV_DAMAGETAKEN" then
            ruleTxt = "amount or any"
        elseif rule == "EV_AURA_STACKS" then
            ruleTxt = "stacks or 1"
        elseif rule == "EV_START_CAST" or rule == "EV_CAST" or rule == "EV_INTERRUPTED_CAST" then
            ruleTxt = "unit name"
        end
        newRuleFrame.editBox1:SetText(ruleTxt)
        newRuleFrame.editBox1:SetScript("OnEscapePressed", function() newRuleFrame.editBox1:SetText(ruleTxt); newRuleFrame.editBox1:ClearFocus() end)
        newRuleFrame.editBox1:SetScript("OnEditFocusGained", function() newRuleFrame.editBox1:SetText(""); end)
        newRuleFrame.editBox1:Show()
        newRuleFrame.editBox1:ClearFocus()
        newRuleFrame.dropMenu1:Hide()
    end

    -- arg2 points
    newRuleFrame.editBox2:SetText("points")
    newRuleFrame.editBox2:SetScript("OnEscapePressed", function() newRuleFrame.editBox2:SetText("points"); newRuleFrame.editBox2:ClearFocus() end)
    newRuleFrame.editBox2:SetScript("OnEditFocusGained", function() newRuleFrame.editBox2:SetText(""); end)
    newRuleFrame.editBox2:Show()
end

local function initNewRuleWindow()
    WDRM.newRule = CreateFrame("Frame", nil, WDRM)
    local r = WDRM.newRule
    r:EnableMouse(true)
    r:SetPoint("BOTTOMLEFT", WDRM.addRule, "TOPLEFT", -1, 1)
    r:SetSize(152, 122)
    r.bg = createColorTexture(r, "TEXTURE", 0, 0, 0, 1)
    r.bg:SetAllPoints()

    local xSize = 150

    local items0 = {}
    for i=1,#encounterTypes do
        local item = { name = encounterTypes[i] }
        table.insert(items0, item)
    end

    r.dropFrame0 = createDropDownMenu(r, "Select encounter", items0)
    r.dropFrame0:SetSize(xSize, 20)
    r.dropFrame0:SetPoint("TOPLEFT", r, "TOPLEFT", 1, -1)

    local items1 = {}
    for i=1,#ruleTypes do
        local item = { name = ruleTypes[i], func = updateNewRuleMenu }
        table.insert(items1, item)
    end

    r.dropFrame1 = createDropDownMenu(r, "Select rule type", items1)
    r.dropFrame1:SetSize(xSize, 20)
    r.dropFrame1:SetPoint("TOPLEFT", r, "TOPLEFT", 1, -22)

    -- editbox arg0
    r.editBox0 = createEditBox(r)
    r.editBox0:SetSize(xSize, 20)
    r.editBox0:SetPoint("TOPLEFT", r.dropFrame1, "BOTTOMLEFT", 0, -1)
    r.editBox0:Hide()

    -- editbox or dropdownmenu arg1
    r.editBox1 = createEditBox(r)
    r.editBox1:SetSize(xSize, 20)
    r.editBox1:SetPoint("TOPLEFT", r.dropFrame1, "BOTTOMLEFT", 0, -22)
    r.editBox1:Hide()

    local items2 = { {name = "apply"},{name = "remove"} }
    r.dropMenu1 = createDropDownMenu(r, "Select aura action", items2)
    r.dropMenu1.txt:SetJustifyH("CENTER")
    r.dropMenu1:SetSize(xSize, 20)
    r.dropMenu1:SetPoint("TOPLEFT", r.dropFrame1, "BOTTOMLEFT", 0, -22)
    r.dropMenu1:Hide()

    -- editbox arg2
    r.editBox2 = createEditBox(r)
    r.editBox2:SetNumeric()
    r.editBox2:SetSize(xSize, 20)
    r.editBox2:SetPoint("TOPLEFT", r.dropFrame1, "BOTTOMLEFT", 0, -43)
    r.editBox2:Hide()

    r:SetScript("OnHide", function()
        r.editBox0:Hide()
        r.editBox1:Hide()
        r.editBox2:Hide()
        r.dropMenu1:Hide()
    end)

    r.saveButton = createButton(r)
    r.saveButton:SetPoint("TOPLEFT", r.dropFrame0, "BOTTOMLEFT", 0, -85)
    r.saveButton:SetSize(74, 15)
    r.saveButton:SetScript("OnClick", function() saveRule(); r:Hide() end)
    r.saveButton.t:SetColorTexture(.2, .4, .2, 1)
    r.saveButton.txt = createFont(r.saveButton, "CENTER", "Save")
    r.saveButton.txt:SetSize(74, 15)
    r.saveButton.txt:SetPoint("LEFT", r.saveButton, "LEFT", 0, 0)

    r.cancelButton = createButton(r)
    r.cancelButton:SetPoint("TOPLEFT", r.saveButton, "TOPRIGHT", 2, 0)
    r.cancelButton:SetSize(74, 15)
    r.cancelButton:SetScript("OnClick", function() r:Hide() end)
    r.cancelButton.t:SetColorTexture(.4, .2, .2, 1)
    r.cancelButton.txt = createFont(r.cancelButton, "CENTER", "Cancel")
    r.cancelButton.txt:SetSize(74, 15)
    r.cancelButton.txt:SetPoint("LEFT", r.cancelButton, "LEFT", 1, 0)

    r:Hide()
end

local function notifyEncounterRules(encounter)
    sendMessage(string.format(WD_NOTIFY_HEADER_RULE, encounter))
    for _,v in pairs(WD.db.profile.rules) do
        if v.encounter == encounter and v.isActive == true then
            local msg = string.format(WD_NOTIFY_RULE, v.points, getRuleDescription(v))
            sendMessage(msg)
        end
    end
end

local function initNotifyRuleWindow()
    WDRM.notifyRule = CreateFrame("Frame", nil, WDRM)
    local r = WDRM.notifyRule
    r:EnableMouse(true)
    r:SetPoint("BOTTOMLEFT", WDRM.notify, "TOPLEFT", 0, 1)
    r:SetSize(152, 22)
    r.bg = createColorTexture(r, "TEXTURE", 0, 0, 0, 1)
    r.bg:SetAllPoints()

    function notifyRule(encounter)
        WDRM.notifyRule:Hide()
        notifyEncounterRules(encounter)
    end

    local items0 = {}
    for i=1,#encounterTypes do
        local item = { name = encounterTypes[i], func = function() notifyRule(encounterTypes[i]) end }
        table.insert(items0, item)
    end

    r.dropFrame0 = createDropDownMenu(r, "Select encounter", items0)
    r.dropFrame0:SetSize(150, 20)
    r.dropFrame0:SetPoint("TOPLEFT", r, "TOPLEFT", 0, -1)

    r:Hide()
end

local function initExportEncounterWindow()
    WDRM.exportEncounter = CreateFrame("Frame", nil, WDRM)
    local r = WDRM.exportEncounter
    r:EnableMouse(true)
    r:SetPoint("BOTTOMLEFT", WDRM.export, "TOPLEFT", 0, 1)
    r:SetSize(152, 22)
    r.bg = createColorTexture(r, "TEXTURE", 0, 0, 0, 1)
    r.bg:SetAllPoints()

    function exportEncounter(encounterName)
        WDRM.exportEncounter:Hide()
        local rules = {}
        for _,v in pairs(WD.db.profile.rules) do
            if v.encounter == encounterName then
                rules[#rules+1] = v
            end
        end
        exportEncounter(rules)
    end

    local items0 = {}
    for i=1,#encounterTypes do
        local item = { name = encounterTypes[i], func = function() exportEncounter(encounterTypes[i]) end }
        table.insert(items0, item)
    end

    r.dropFrame0 = createDropDownMenu(r, "Select encounter", items0)
    r.dropFrame0:SetSize(150, 20)
    r.dropFrame0:SetPoint("TOPLEFT", r, "TOPLEFT", 0, -1)

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

local function initImportEncounterWindow()
    WDRM.importEncounter = CreateFrame("Frame", nil, WDRM)
    local r = WDRM.importEncounter
    r:EnableMouse(true)
    r:SetPoint("CENTER", 0, 0)
    r:SetSize(400, 400)
    r.bg = createColorTexture(r, "TEXTURE", 0, 0, 0, 1)
    r.bg:SetAllPoints()

    function tryImportEncounter(str)
        local rules = importEncounter(str)
        if rules and #rules > 0 then
            StaticPopup_Show("WD_ACCEPT_IMPORT", rules[1].encounter)
        else
            -- try import as single rule
            local rule = importRule(str)
            if rule.type then
                insertRule(rule)
            else
                print("Could not parse rule")
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

    StaticPopupDialogs["WD_ACCEPT_IMPORT"] = {
        text = WD_IMPORT_QUESTION,
        button1 = WD_BUTTON_IMPORT,
        button2 = WD_BUTTON_CANCEL,
        OnAccept = function()
            insertEncounter(importEncounter(r.editBox:GetText()))
            r:Hide()
        end,
        OnCancel = function()
            r:Hide()
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
                if rule.type then
                    insertRule(rule)
                else
                    print("Could not parse rule")
                end
                WDRM.sharedRule = ""
            end
        end,
        OnCancel = function()
            if WDRM.sharedRule then WDRM.sharedRule = "" end
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = false,
        preferredIndex = 3,
    }
end

local function initShareEncounterWindow()
    WDRM.shareEncounter = CreateFrame("Frame", nil, WDRM)
    local r = WDRM.shareEncounter
    r:EnableMouse(true)
    r:SetPoint("BOTTOMLEFT", WDRM.share, "TOPLEFT", 0, 1)
    r:SetSize(152, 22)
    r.bg = createColorTexture(r, "TEXTURE", 0, 0, 0, 1)
    r.bg:SetAllPoints()

    function share(encounterName)
        WDRM.shareEncounter:Hide()
        local rules = {}
        for _,v in pairs(WD.db.profile.rules) do
            if v.encounter == encounterName then
                rules[#rules+1] = v
            end
        end
        shareEncounter(encounterName, rules)
    end

    local items0 = {}
    for i=1,#encounterTypes do
        local item = { name = encounterTypes[i], func = function() share(encounterTypes[i]) end }
        table.insert(items0, item)
    end

    r.dropFrame0 = createDropDownMenu(r, "Select encounter", items0)
    r.dropFrame0:SetSize(150, 20)
    r.dropFrame0:SetPoint("TOPLEFT", r, "TOPLEFT", 0, -1)

    StaticPopupDialogs["WD_ACCEPT_SHARED_ENCOUNTER"] = {
        text = WD_IMPORT_SHARED_ENCOUNTER_QUESTION,
        button1 = WD_BUTTON_ACCEPT,
        button2 = WD_BUTTON_CANCEL,
        OnAccept = function()
            if WDRM.sharedRule then
                local rules = WD:ImportEncounter(WDRM.sharedRule)
                if rules and #rules > 0 then
                    insertEncounter(rules)
                else
                    print("Could not parse rule")
                end

                WDRM.sharedRule = ""
            end
        end,
        OnCancel = function()
            if WDRM.sharedRule then WDRM.sharedRule = "" end
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = false,
        preferredIndex = 3,
    }

    r:Hide()
end

function WD:InitEncountersModule(parent)
    WDRM = parent

    WDRM.rules = {}

    -- new rule button
    WDRM.addRule = createButton(WDRM)
    WDRM.addRule:SetPoint("TOPLEFT", WDRM, "TOPLEFT", 1, -5)
    WDRM.addRule:SetSize(125, 20)
    WDRM.addRule:SetScript("OnClick", function() if WDRM.newRule:IsVisible() then WDRM.newRule:Hide() else WDRM.newRule:Show() end end)
    WDRM.addRule.txt = createFont(WDRM.addRule, "CENTER", WD_BUTTON_NEW_RULE)
    WDRM.addRule.txt:SetAllPoints()

    -- notify rules button
    WDRM.notify = createButton(WDRM)
    WDRM.notify:SetPoint("TOPLEFT", WDRM.addRule, "TOPRIGHT", 1, 0)
    WDRM.notify:SetSize(125, 20)
    WDRM.notify:SetScript("OnClick", function() if WDRM.notifyRule:IsVisible() then WDRM.notifyRule:Hide() else WDRM.notifyRule:Show() end end)
    WDRM.notify.txt = createFont(WDRM.notify, "CENTER", WD_BUTTON_NOTIFY_RULES)
    WDRM.notify.txt:SetAllPoints()

    -- export encounter button
    WDRM.export = createButton(WDRM)
    WDRM.export:SetPoint("TOPLEFT", WDRM.notify, "TOPRIGHT", 1, 0)
    WDRM.export:SetSize(125, 20)
    WDRM.export:SetScript("OnClick", function() if WDRM.exportEncounter:IsVisible() then WDRM.exportEncounter:Hide() else WDRM.exportEncounter:Show() end end)
    WDRM.export.txt = createFont(WDRM.export, "CENTER", WD_BUTTON_EXPORT_ENCOUNTERS)
    WDRM.export.txt:SetAllPoints()

    -- import encounter button
    WDRM.import = createButton(WDRM)
    WDRM.import:SetPoint("TOPLEFT", WDRM.export, "TOPRIGHT", 1, 0)
    WDRM.import:SetSize(125, 20)
    WDRM.import:SetScript("OnClick", function() if WDRM.importEncounter:IsVisible() then WDRM.importEncounter:Hide() else WDRM.importEncounter:Show() end end)
    WDRM.import.txt = createFont(WDRM.import, "CENTER", WD_BUTTON_IMPORT_ENCOUNTERS)
    WDRM.import.txt:SetAllPoints()

    -- share encounter button
    WDRM.share = createButton(WDRM)
    WDRM.share:SetPoint("TOPLEFT", WDRM.import, "TOPRIGHT", 1, 0)
    WDRM.share:SetSize(125, 20)
    WDRM.share:SetScript("OnClick", function() if WDRM.shareEncounter:IsVisible() then WDRM.shareEncounter:Hide() else WDRM.shareEncounter:Show() end end)
    WDRM.share.txt = createFont(WDRM.share, "CENTER", WD_BUTTON_SHARE_ENCOUNTERS)
    WDRM.share.txt:SetAllPoints()

    -- headers
    local x, y = 1, -30
    WDRM.headers = {}
    local h = createTableHeader(WDRM, "", x, y, 20, 20)
    h = createTableHeader(WDRM, WD_BUTTON_ENCOUNTER, x + 21, y, 75, 20)
    h = createTableHeaderNext(WDRM, h, WD_BUTTON_REASON, 395, 20)
    h = createTableHeaderNext(WDRM, h, WD_BUTTON_POINTS_SHORT, 50, 20)
    h = createTableHeaderNext(WDRM, h, "", 50, 20)
    h = createTableHeaderNext(WDRM, h, "", 50, 20)
    h = createTableHeaderNext(WDRM, h, "", 50, 20)
    createTableHeaderNext(WDRM, h, "", 70, 20)

    initNewRuleWindow()
    initNotifyRuleWindow()
    initExportEncounterWindow()
    initExportWindow()
    initImportEncounterWindow()
    initShareEncounterWindow()

    updateRuleLines()
end

function WD:ReceiveSharedRule(sender, str)
    WDRM.sharedRule = str
    StaticPopup_Show("WD_ACCEPT_SHARED_RULE", sender)
end

function WD:ReceiveSharedEncounter(sender, encounter, str)
    WDRM.sharedRule = str
    StaticPopup_Show("WD_ACCEPT_SHARED_ENCOUNTER", sender, encounter)
end
