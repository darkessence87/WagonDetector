
encounterTypes = {
    'Test',
    'UD_TALOC',
    'UD_MOTHER',
    'UD_ZEKVOZ',
    'UD_VECTIS',
    'UD_FETID',
    'UD_ZUL',
    'UD_MYTRAX',
    'UD_GHUUN',
}

ruleTypes = {
    'EV_DAMAGETAKEN',
    'EV_DEATH',
    'EV_AURA',
    'EV_AURA_STACKS',
    'EV_START_CAST',
    'EV_CAST',
    'EV_INTERRUPTED_CAST',
    'EV_DEATH_UNIT',
    'EV_POTIONS',
    'EV_FLASKS',
    'EV_FOOD',
    'EV_RUNES'
}

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

local function editRuleLine(ruleLine)
    local newRuleFrame = WD.guiFrame.module['encounters'].newRule
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
    if rule ~= 'EV_POTIONS' and rule ~= 'EV_FLASKS' and rule ~= 'EV_FOOD' and rule ~= 'EV_RUNES' then
        local txt = ruleLine.rule.arg0
        newRuleFrame.editBox0:SetText(txt)
        newRuleFrame.editBox0:SetScript('OnEscapePressed', function() newRuleFrame.editBox0:SetText(txt); newRuleFrame.editBox0:ClearFocus() end)
        newRuleFrame.editBox0:SetScript('OnEditFocusGained', function() newRuleFrame.editBox0:SetText(""); end)
        newRuleFrame.editBox0:Show()
    else
        newRuleFrame.editBox0:Hide()
    end

    -- arg1
    if ruleLine.rule.type == 'EV_AURA' then
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
        newRuleFrame.editBox1:SetScript('OnEscapePressed', function() newRuleFrame.editBox1:SetText(ruleTxt); newRuleFrame.editBox1:ClearFocus() end)
        newRuleFrame.editBox1:SetScript('OnEditFocusGained', function() newRuleFrame.editBox1:SetText(""); end)
        newRuleFrame.editBox1:Show()
        newRuleFrame.editBox1:ClearFocus()
        newRuleFrame.dropMenu1:Hide()
    end

    -- points
    local points = ruleLine.rule.points
    newRuleFrame.editBox2:SetText(points)
    newRuleFrame.editBox2:SetScript('OnEscapePressed', function() newRuleFrame.editBox2:SetText(points); newRuleFrame.editBox2:ClearFocus() end)
    newRuleFrame.editBox2:SetScript('OnEditFocusGained', function() newRuleFrame.editBox2:SetText(""); end)
    newRuleFrame.editBox2:Show()
end

local function updateRuleLines(self)
    if not self.rules then return end

    local maxWidth = 30
    local maxHeight = 545
    for i=1,#self.headers do
        maxWidth = maxWidth + self.headers[i]:GetWidth() + 1
    end

    local scroller = self.scroller or createScroller(self, maxWidth, maxHeight, #WD.db.profile.rules)
    if not self.scroller then
        self.scroller = scroller
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
        if not self.rules[k] then
            local ruleLine = CreateFrame("Frame", nil, self.scroller.scrollerChild)
            ruleLine.rule = v
            ruleLine:SetSize(maxWidth, 20)
            ruleLine:SetPoint("TOPLEFT", self.scroller.scrollerChild, "TOPLEFT", x, y)
            ruleLine.column = {}

            local index = 1
            ruleLine.column[index] = createCheckButton(ruleLine)
            ruleLine.column[index]:SetSize(18, 18)
            ruleLine.column[index]:SetPoint("TOPLEFT", ruleLine, "TOPLEFT", 1, -1)
            ruleLine.column[index]:SetChecked(v.isActive)
            ruleLine.column[index]:SetScript("OnClick", function() v.isActive = not v.isActive end)

            index = index + 1
            addNextColumn(self, ruleLine, index, "CENTER", v.encounter)
            ruleLine.column[index]:SetPoint("TOPLEFT", ruleLine.column[index-1], "TOPRIGHT", 2, 1)
            index = index + 1
            addNextColumn(self, ruleLine, index, "LEFT", getRuleDescription(v))
            index = index + 1
            addNextColumn(self, ruleLine, index, "CENTER", v.points)
            index = index + 1
            addNextColumn(self, ruleLine, index, "CENTER", WD_BUTTON_EDIT)
            ruleLine.column[index]:EnableMouse(true)
            ruleLine.column[index]:SetScript('OnClick', function() editRuleLine(ruleLine); end)
            ruleLine.column[index].t:SetColorTexture(.2, 1, .2, .5)
            index = index + 1
            addNextColumn(self, ruleLine, index, "CENTER", WD_BUTTON_DELETE)
            ruleLine.column[index]:EnableMouse(true)
            ruleLine.column[index]:SetScript('OnClick', function() table.remove(WD.db.profile.rules, k); updateRuleLines(self); end)
            ruleLine.column[index].t:SetColorTexture(1, .2, .2, .5)
            index = index + 1
            addNextColumn(self, ruleLine, index, "CENTER", WD_BUTTON_EXPORT)
            ruleLine.column[index]:EnableMouse(true)
            ruleLine.column[index]:SetScript('OnClick', function() WD:ExportRule(self, ruleLine.rule); end)
            ruleLine.column[index].t:SetColorTexture(1, .2, .2, .5)

            table.insert(self.rules, ruleLine)
        else
            local ruleLine = self.rules[k]
            ruleLine.column[1]:SetChecked(v.isActive)
            ruleLine.column[1]:SetScript("OnClick", function() v.isActive = not v.isActive end)
            ruleLine.column[2].txt:SetText(v.encounter)
            ruleLine.column[3].txt:SetText(getRuleDescription(v))
            ruleLine.column[4].txt:SetText(v.points)
            ruleLine.column[5]:SetScript('OnClick', function() editRuleLine(ruleLine); end)
            ruleLine.column[7]:SetScript('OnClick', function() WD:ExportRule(self, ruleLine.rule); end)
            ruleLine:Show()
            updateScroller(self.scroller.slider, #WD.db.profile.rules)
        end

        y = y - 21
    end

    if #WD.db.profile.rules < #self.rules then
        for i=#WD.db.profile.rules+1, #self.rules do
            self.rules[i]:Hide()
        end
    end
end

local function saveRule(self)
    local f = self.newRule
    if not f.dropFrame0.selected or not f.dropFrame1.selected then return end
    local encounterType = f.dropFrame0.selected.txt:GetText()
    local ruleType = f.dropFrame1.selected.txt:GetText()

    local rule = {}
    rule.encounter = encounterType
    rule.type = ruleType
    rule.arg0 = ""
    rule.arg1 = ""
    rule.points = f.editBox2:GetNumber()

    if ruleType == 'EV_DAMAGETAKEN' then
        rule.arg0 = tonumber(f.editBox0:GetText()) or 0
        rule.arg1 = tonumber(f.editBox1:GetText()) or 0
    elseif ruleType == 'EV_DEATH' then
        rule.arg0 = tonumber(f.editBox0:GetText()) or 0
    elseif ruleType == 'EV_AURA' then
        rule.arg0 = tonumber(f.editBox0:GetText()) or 0
        rule.arg1 = f.dropMenu1:GetText()
        if rule.arg1 ~= "apply" and rule.arg1 ~= "remove" then return end
    elseif ruleType == 'EV_AURA_STACKS' then
        rule.arg0 = tonumber(f.editBox0:GetText()) or 0
        rule.arg1 = tonumber(f.editBox1:GetText()) or 1
    elseif ruleType == 'EV_START_CAST' then
        rule.arg0 = tonumber(f.editBox0:GetText()) or 0
        rule.arg1 = f.editBox1:GetText()
    elseif ruleType == 'EV_CAST' then
        rule.arg0 = tonumber(f.editBox0:GetText()) or 0
        rule.arg1 = f.editBox1:GetText()
    elseif ruleType == 'EV_INTERRUPTED_CAST' then
        rule.arg0 = tonumber(f.editBox0:GetText()) or 0
        rule.arg1 = f.editBox1:GetText()
    elseif ruleType == 'EV_DEATH_UNIT' then
        rule.arg0 = f.editBox0:GetText()
    elseif ruleType == 'EV_POTIONS' or ruleType == 'EV_FLASKS' or ruleType == 'EV_FOOD' or ruleType == 'EV_RUNES' then
        -- nothing to do here
    else
        print("Unsupported rule type:"..rule.type)
        return
    end

    if rule.points == "" or rule.points == 0 then return end

    -- find duplicate
    local found = false
    for k,v in pairs(WD.db.profile.rules) do
        if v.encounter == rule.encounter and v.type == rule.type and v.arg0 == rule.arg0 and v.arg1 == rule.arg1 then
            found = true
            v.points = rule.points
            break
        end
    end

    if found == false then
        rule.isActive = true
        WD.db.profile.rules[#WD.db.profile.rules+1] = rule
    end

    updateRuleLines(self)
end

local function initNewRuleWindow(self)
    self.newRule = CreateFrame("Frame", nil, self)
    local r = self.newRule
    r:EnableMouse(true)
    r:SetPoint("TOPLEFT", self.headers[#self.headers], "TOPRIGHT", 1, 1)
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
        local item = { name = ruleTypes[i], func = WD.UpdateNewRuleMenu }
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
    r.dropMenu1 = createDropDownMenu(r, 'Select aura action', items2)
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

    r:SetScript('OnHide', function()
        r.editBox0:Hide()
        r.editBox1:Hide()
        r.editBox2:Hide()
        r.dropMenu1:Hide()
    end)

    r.saveButton = createButton(r)
    r.saveButton:SetPoint("TOPLEFT", r.dropFrame0, "BOTTOMLEFT", 0, -85)
    r.saveButton:SetSize(74, 15)
    r.saveButton:SetScript('OnClick', function() saveRule(self); r:Hide() end)
    r.saveButton.t:SetColorTexture(.2, .4, .2, 1)
    r.saveButton.txt = createFont(r.saveButton, "CENTER", "Save")
    r.saveButton.txt:SetSize(74, 15)
    r.saveButton.txt:SetPoint("LEFT", r.saveButton, "LEFT", 0, 0)

    r.cancelButton = createButton(r)
    r.cancelButton:SetPoint("TOPLEFT", r.saveButton, "TOPRIGHT", 2, 0)
    r.cancelButton:SetSize(74, 15)
    r.cancelButton:SetScript('OnClick', function() r:Hide() end)
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

local function initNotifyRuleWindow(self)
    self.notifyRule = CreateFrame("Frame", nil, self)
    local r = self.notifyRule
    r:EnableMouse(true)
    r:SetPoint("BOTTOMLEFT", self.notify, "TOPLEFT", 0, 1)
    r:SetSize(152, 22)
    r.bg = createColorTexture(r, "TEXTURE", 0, 0, 0, 1)
    r.bg:SetAllPoints()

    function notifyRule(encounter)
        self.notifyRule:Hide()
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

local function initExportRuleWindow(self)
    self.exportRule = CreateFrame("Frame", nil, self)
    local r = self.exportRule
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
    r.editBox:SetScript("OnEscapePressed", function() r:Hide(); end);
    r.editBox:SetScript("OnMouseUp", function() r.editBox:HighlightText(); end);
    r.editBox.t = createColorTexture(r.editBox, "BACKGROUND", .2, .2, .2, 1)
    r.editBox.t:SetAllPoints()
    r.editBox:Show()

    r:Hide()
end

function WD:InitEncountersModule(parent)
    parent.rules = {}

    -- new rule button
    parent.addRule = createButton(parent)
    parent.addRule:SetPoint("TOPLEFT", parent, "TOPLEFT", 1, -5)
    parent.addRule:SetSize(125, 20)
    parent.addRule:SetScript("OnClick", function() WD:OpenNewRuleMenu() end)
    parent.addRule.txt = createFont(parent.addRule, "CENTER", WD_BUTTON_NEW_RULE)
    parent.addRule.txt:SetAllPoints()

    -- notify rules button
    parent.notify = createButton(parent)
    parent.notify:SetPoint("TOPLEFT", parent.addRule, "TOPRIGHT", 1, 0)
    parent.notify:SetSize(125, 20)
    parent.notify:SetScript("OnClick", function() WD:OpenNotifyRuleMenu() end)
    parent.notify.txt = createFont(parent.notify, "CENTER", WD_BUTTON_NOTIFY_RULES)
    parent.notify.txt:SetAllPoints()

    -- headers
    local x, y = 1, -30
    parent.headers = {}
    local h = createTableHeader(parent, '', x, y, 20, 20)
    h = createTableHeader(parent, WD_BUTTON_ENCOUNTER, x + 21, y, 75, 20)
    h = createTableHeaderNext(parent, h, WD_BUTTON_REASON, 395, 20)
    h = createTableHeaderNext(parent, h, WD_BUTTON_POINTS_SHORT, 50, 20)
    h = createTableHeaderNext(parent, h, '', 50, 20)
    h = createTableHeaderNext(parent, h, '', 50, 20)
    createTableHeaderNext(parent, h, '', 50, 20)

    initNewRuleWindow(parent)
    initNotifyRuleWindow(parent)
    initExportRuleWindow(parent)

    updateRuleLines(parent)
end

function WD:UpdateNewRuleMenu()
    local newRuleFrame = WD.guiFrame.module['encounters'].newRule
    if not newRuleFrame.dropFrame1.selected then return end

    local rule = newRuleFrame.dropFrame1.selected.txt:GetText()

    -- arg0 name (based on rule type)
    if rule ~= 'EV_POTIONS' and rule ~= 'EV_FLASKS' and rule ~= 'EV_FOOD' and rule ~= 'EV_RUNES' then
        local txt = ""
        if rule == "EV_DEATH_UNIT" then
            txt = "unit name"
        else
            txt = "spellid"
        end

        newRuleFrame.editBox0:SetText(txt)
        newRuleFrame.editBox0:SetScript('OnEscapePressed', function() newRuleFrame.editBox0:SetText(txt); newRuleFrame.editBox0:ClearFocus() end)
        newRuleFrame.editBox0:SetScript('OnEditFocusGained', function() newRuleFrame.editBox0:SetText(""); end)
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
        newRuleFrame.editBox1:SetScript('OnEscapePressed', function() newRuleFrame.editBox1:SetText(ruleTxt); newRuleFrame.editBox1:ClearFocus() end)
        newRuleFrame.editBox1:SetScript('OnEditFocusGained', function() newRuleFrame.editBox1:SetText(""); end)
        newRuleFrame.editBox1:Show()
        newRuleFrame.editBox1:ClearFocus()
        newRuleFrame.dropMenu1:Hide()
    end

    -- arg2 points
    newRuleFrame.editBox2:SetText("points")
    newRuleFrame.editBox2:SetScript('OnEscapePressed', function() newRuleFrame.editBox2:SetText("points"); newRuleFrame.editBox2:ClearFocus() end)
    newRuleFrame.editBox2:SetScript('OnEditFocusGained', function() newRuleFrame.editBox2:SetText(""); end)
    newRuleFrame.editBox2:Show()
end

function WD:ExportRule(self, rule)
    local txt = encode64(table.tostring(rule))
    --txt = decode64(txt)
    --print(txt)
    local r = self.exportRule
    r.editBox:SetText(txt)
    r.editBox:SetScript("OnChar", function() r.editBox:SetText(txt); r.editBox:HighlightText(); end)
    r.editBox:HighlightText()
    r.editBox:SetAutoFocus(true)
    r.editBox:SetCursorPosition(0)

    r:Show()
end

function WD:ImportRule(str)
    local d = decode64(str)
    -- parse rule
    -- /script WD:ImportRule('e3R5cGU9IkVWX0RFQVRIIixhcmcxPSIiLGVuY291bnRlcj0iVURfTU9USEVSIixwb2ludHM9MjUsYXJnMD0yNjgyNzcsaXNBY3RpdmU9dHJ1ZX0=')
    -- {type="EV_DEATH",arg1="",encounter="UD_MOTHER",points=25,arg0=267803,isActive=true}

    function parseValue(s)
        if string.find(s, "\"") then
            return s:sub(2,-2)
        elseif s == "true" then
            return true
        elseif s == "false" then
            return false
        else
            return s
        end
    end

    local rule = {}
    for i in string.gmatch(d, "[%w]+=[\"|_|%w]+") do
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
                rule.points = v
            elseif k == "isActive" then
                rule.isActive = v
            end
        end
    end

    print(getRuleDescription(rule))
end
