
local WDRS = nil

local statisticRuleTypes = {
    "RULE_DEPENDENCY",          -- arg0=event_reason, arg1=event_result, arg2=time_before_reset, arg3=is_inverted   checks if event_result occured (or not) after event_reason during specified time
    "RULE_INTERRUPTS_QUALITY",  -- arg0=target_spell_id, arg1=quality_value                                         checks if spell was interrupted too early based on quality_value (in percents of cast duration)
    "RULE_RANGE_STATS",         -- arg0=statistic_type
}

local statisticTypes = {
    "TARGET_DAMAGE",            -- arg1=event_start, arg2=event_stop, arg3=unit collects damage done to specified unit in events range related to that unit
    "TARGET_HEALING",           -- arg1=event_start, arg2=event_stop            collects healing done to units in events range related to those units
    "TARGET_INTERRUPTS",        -- arg1=event_start, arg2=event_stop            collects interrupts done to units in events range related to those units
    "SOURCE_DAMAGE",            -- arg1=event_start, arg2=event_stop            collects damage done by units in events range related to those units
    "SOURCE_HEALING",           -- arg1=event_start, arg2=event_stop            collects healing done by units in events range related to those units
    "SOURCE_INTERRUPTS",        -- arg1=event_start, arg2=event_stop            collects interrupts done by units in event range related to those units
}

local function getStatisticRuleTypesItems(fn)
    local items = {}
    for i=1,#statisticRuleTypes do
        local item = { name = statisticRuleTypes[i], func = fn }
        table.insert(items, item)
    end
    return items
end

local function getStatisticTypesItems(fn)
    local items = {}
    for i=1,#statisticTypes do
        local item = { name = statisticTypes[i], func = fn }
        table.insert(items, item)
    end
    return items
end

local function showHiddenRule(name, selected)
    local parent = WDRS.menus["new_rule"]
    local r = parent.hiddenMenus[name]

    local rule = selected.data.name
    r.label:SetText(rule)

    -- arg0
    if rule ~= "EV_POTIONS" and rule ~= "EV_FLASKS" and rule ~= "EV_FOOD" and rule ~= "EV_RUNES" then
        local txt = ""
        if rule == "EV_DEATH_UNIT" then
            txt = "unit name"
        else
            txt = "spellid"
        end

        r.hiddenMenus["arg0_edit"]:SetText(txt)
        r.hiddenMenus["arg0_edit"]:SetScript("OnEscapePressed", function() r.hiddenMenus["arg0_edit"]:SetText(txt); r.hiddenMenus["arg0_edit"]:ClearFocus() end)
        r.hiddenMenus["arg0_edit"]:SetScript("OnEditFocusGained", function() r.hiddenMenus["arg0_edit"]:SetText(""); end)
        r.hiddenMenus["arg0_edit"]:Show()
    else
        r.hiddenMenus["arg0_edit"]:Hide()
    end

    -- arg1
    if rule == "EV_AURA" then
        r.hiddenMenus["arg1_edit"]:Hide()
        r.hiddenMenus["arg1_drop1"]:Show()
    elseif rule == "EV_DEATH"
        or rule == "EV_DEATH_UNIT"
        or rule == "EV_DISPEL"
        or rule == "EV_POTIONS"
        or rule == "EV_FLASKS"
        or rule == "EV_FOOD"
        or rule == "EV_RUNES"
    then
        r.hiddenMenus["arg1_edit"]:Hide()
        r.hiddenMenus["arg1_drop1"]:Hide()
    else
        local ruleTxt = ""
        if rule == "EV_DAMAGETAKEN" then
            ruleTxt = "amount or any"
        elseif rule == "EV_AURA_STACKS" then
            ruleTxt = "stacks (0 if any)"
        elseif rule == "EV_CAST_START" or rule == "EV_CAST_END" or rule == "EV_CAST_INTERRUPTED" then
            ruleTxt = "unit name"
        end
        r.hiddenMenus["arg1_edit"]:SetText(ruleTxt)
        r.hiddenMenus["arg1_edit"]:SetScript("OnEscapePressed", function() r.hiddenMenus["arg1_edit"]:SetText(ruleTxt); r.hiddenMenus["arg1_edit"]:ClearFocus() end)
        r.hiddenMenus["arg1_edit"]:SetScript("OnEditFocusGained", function() r.hiddenMenus["arg1_edit"]:SetText(""); end)
        r.hiddenMenus["arg1_edit"]:Show()
        r.hiddenMenus["arg1_edit"]:ClearFocus()
        r.hiddenMenus["arg1_drop1"]:Hide()
    end

    r:Show()
end

local function updateNewRuleHiddenMenu()
    local parent = WDRS.menus["new_rule"]
    local arg0 = parent.hiddenMenus["arg0_drop1"]
    local arg1 = parent.hiddenMenus["arg1_drop1"]
    local arg2 = parent.hiddenMenus["arg2_drop1"]

    parent.hiddenMenus["selected_rule_1"]:Hide()
    parent.hiddenMenus["selected_rule_2"]:Hide()

    if arg0:IsVisible() and arg0.selected then
        showHiddenRule("selected_rule_1", arg0.selected)
        if arg1:IsVisible() and arg1.selected then
            showHiddenRule("selected_rule_2", arg1.selected)
        end
    else
        if arg1:IsVisible() and arg1.selected then
            showHiddenRule("selected_rule_1", arg1.selected)
            if arg2:IsVisible() and arg2.selected then
                showHiddenRule("selected_rule_2", arg2.selected)
            end
        end
    end
end

local function updateNewRuleMenu()
    local parent = WDRS.menus["new_rule"]
    if not parent.menus["rule_types"].selected then return end

    local rule = parent.menus["rule_types"].selected.txt:GetText()

    -- arg0
    if rule == "RULE_DEPENDENCY" then
        parent.hiddenMenus["arg0_drop1"]:Show()
        parent.hiddenMenus["arg0_drop2"]:Hide()
        parent.hiddenMenus["arg0_edit"]:Hide()
    elseif rule == "RULE_INTERRUPTS_QUALITY" then
        parent.hiddenMenus["arg0_drop1"]:Hide()
        parent.hiddenMenus["arg0_drop2"]:Hide()
        local txt = "target spell id"
        parent.hiddenMenus["arg0_edit"]:SetText(txt)
        parent.hiddenMenus["arg0_edit"]:SetScript("OnEscapePressed", function() parent.hiddenMenus["arg0_edit"]:SetText(txt); parent.hiddenMenus["arg0_edit"]:ClearFocus() end)
        parent.hiddenMenus["arg0_edit"]:SetScript("OnEditFocusGained", function() parent.hiddenMenus["arg0_edit"]:SetText(""); end)
        parent.hiddenMenus["arg0_edit"]:Show()
    elseif rule == "RULE_RANGE_STATS" then
        parent.hiddenMenus["arg0_drop1"]:Hide()
        parent.hiddenMenus["arg0_drop2"]:Show()
        parent.hiddenMenus["arg0_edit"]:Hide()
    end

    -- arg1
    if rule == "RULE_DEPENDENCY" then
        parent.hiddenMenus["arg1_drop1"].label:SetText("Result event:")
        parent.hiddenMenus["arg1_drop1"]:Show()
        parent.hiddenMenus["arg1_edit"]:Hide()
    elseif rule == "RULE_INTERRUPTS_QUALITY" then
        parent.hiddenMenus["arg1_drop1"]:Hide()
        local txt = "quality percent"
        parent.hiddenMenus["arg1_edit"]:SetText(txt)
        parent.hiddenMenus["arg1_edit"]:SetScript("OnEscapePressed", function() parent.hiddenMenus["arg1_edit"]:SetText(txt); parent.hiddenMenus["arg1_edit"]:ClearFocus() end)
        parent.hiddenMenus["arg1_edit"]:SetScript("OnEditFocusGained", function() parent.hiddenMenus["arg1_edit"]:SetText(""); end)
        parent.hiddenMenus["arg1_edit"]:Show()
    elseif rule == "RULE_RANGE_STATS" then
        local statType = parent.hiddenMenus["arg0_drop2"].selected
        if statType then
            parent.hiddenMenus["arg1_drop1"].label:SetText("Start event:")
            parent.hiddenMenus["arg1_drop1"]:Show()
        else
            parent.hiddenMenus["arg1_drop1"]:Hide()
        end
        parent.hiddenMenus["arg1_edit"]:Hide()
    end

    -- arg2
    if rule == "RULE_DEPENDENCY" then
        parent.hiddenMenus["arg2_drop1"]:Hide()
        local txt = "timeout (msec)"
        parent.hiddenMenus["arg2_edit"]:SetText(txt)
        parent.hiddenMenus["arg2_edit"]:SetScript("OnEscapePressed", function() parent.hiddenMenus["arg2_edit"]:SetText(txt); parent.hiddenMenus["arg2_edit"]:ClearFocus() end)
        parent.hiddenMenus["arg2_edit"]:SetScript("OnEditFocusGained", function() parent.hiddenMenus["arg2_edit"]:SetText(""); end)
        parent.hiddenMenus["arg2_edit"]:Show()
    elseif rule == "RULE_INTERRUPTS_QUALITY" then
        parent.hiddenMenus["arg2_drop1"]:Hide()
        parent.hiddenMenus["arg2_edit"]:Hide()
    elseif rule == "RULE_RANGE_STATS" then
        local statType = parent.hiddenMenus["arg0_drop2"].selected
        if statType then
            parent.hiddenMenus["arg2_drop1"]:Show()
        else
            parent.hiddenMenus["arg2_drop1"]:Hide()
        end
        parent.hiddenMenus["arg2_edit"]:Hide()
    end

    -- arg3
    if rule == "RULE_DEPENDENCY" then
        local txt = "inverted (0 or 1)"
        parent.hiddenMenus["arg3_edit"].label:SetText("invert logic?")
        parent.hiddenMenus["arg3_edit"]:SetText(txt)
        parent.hiddenMenus["arg3_edit"]:SetScript("OnEscapePressed", function() parent.hiddenMenus["arg3_edit"]:SetText(txt); parent.hiddenMenus["arg3_edit"]:ClearFocus() end)
        parent.hiddenMenus["arg3_edit"]:SetScript("OnEditFocusGained", function() parent.hiddenMenus["arg3_edit"]:SetText(""); end)
        parent.hiddenMenus["arg3_edit"]:Show()
    elseif rule == "RULE_INTERRUPTS_QUALITY" then
        parent.hiddenMenus["arg3_edit"]:Hide()
    elseif rule == "RULE_RANGE_STATS" then
        local statType = parent.hiddenMenus["arg0_drop2"].selected
        if statType and statType.txt:GetText() == "TARGET_DAMAGE" then
            local txt = "unit name"
            parent.hiddenMenus["arg3_edit"].label:SetText("unit name")
            parent.hiddenMenus["arg3_edit"]:SetText(txt)
            parent.hiddenMenus["arg3_edit"]:SetScript("OnEscapePressed", function() parent.hiddenMenus["arg3_edit"]:SetText(txt); parent.hiddenMenus["arg3_edit"]:ClearFocus() end)
            parent.hiddenMenus["arg3_edit"]:SetScript("OnEditFocusGained", function() parent.hiddenMenus["arg3_edit"]:SetText(""); end)
            parent.hiddenMenus["arg3_edit"]:Show()
        else
            parent.hiddenMenus["arg3_edit"]:Hide()
        end
    end

    parent.hiddenMenus["selected_rule_1"]:Hide()
    parent.hiddenMenus["selected_rule_2"]:Hide()
end

local function initSelectedRuleMenu()
    WDRS.menus["new_rule"].hiddenMenus["selected_rule_1"] = createRuleWindow(WDRS.menus["new_rule"])
    WDRS.menus["new_rule"].hiddenMenus["selected_rule_2"] = createRuleWindow(WDRS.menus["new_rule"])

    local l = WDRS.menus["new_rule"].hiddenMenus["selected_rule_1"]
    local r = WDRS.menus["new_rule"].hiddenMenus["selected_rule_2"]

    l:SetFrameStrata("HIGH")
    r:SetFrameStrata("HIGH")

    l:SetPoint("TOPLEFT", WDRS.menus["new_rule"], "TOPRIGHT", 1, 0)
    r:SetPoint("BOTTOMLEFT", WDRS.menus["new_rule"], "BOTTOMRIGHT", 1, 0)
end

local function initNewRuleWindow()
    WDRS.menus["new_rule"] = CreateFrame("Frame", nil, WDRS)
    local r = WDRS.menus["new_rule"]
    r.menus = {}
    r.hiddenMenus = {}
    r.buttons = {}

    local totalWidth = 325
    local xSize = 200
    local x = totalWidth - xSize

    -- encounters menu
    r.menus["encounters"] = createDropDownMenu(r, "Select encounter", WD:CreateTierList())
    r.menus["encounters"]:SetSize(xSize, 20)
    r.menus["encounters"]:SetPoint("TOPLEFT", r, "TOPLEFT", x, -1)
    r.menus["encounters"].label = createFontDefault(r.menus["encounters"], "RIGHT", "Encounter:")
    r.menus["encounters"].label:SetSize(x - 5, 20)
    r.menus["encounters"].label:SetPoint("TOPLEFT", r, "TOPLEFT", 1, -1)
    -- statistic rules menu
    r.menus["rule_types"] = createDropDownMenu(r, "Select rule type", getStatisticRuleTypesItems(updateNewRuleMenu))
    r.menus["rule_types"]:SetSize(xSize, 20)
    r.menus["rule_types"]:SetPoint("TOPLEFT", r.menus["encounters"], "BOTTOMLEFT", 0, -1)
    r.menus["rule_types"].label = createFontDefault(r.menus["rule_types"], "RIGHT", "Rule:")
    r.menus["rule_types"].label:SetSize(x - 5, 20)
    r.menus["rule_types"].label:SetPoint("TOPLEFT", r.menus["encounters"].label, "BOTTOMLEFT", 0, -1)
    -- role filter
    r.menus["roles"] = createDropDownMenu(r, "ANY", getRoleTypesItems())
    r.menus["roles"].txt:SetJustifyH("CENTER")
    r.menus["roles"]:SetSize(xSize, 20)
    r.menus["roles"]:SetPoint("TOPLEFT", r.menus["rule_types"], "BOTTOMLEFT", 0, -1)
    r.menus["roles"].label = createFontDefault(r.menus["roles"], "RIGHT", "Role:")
    r.menus["roles"].label:SetSize(x - 5, 20)
    r.menus["roles"].label:SetPoint("TOPLEFT", r.menus["rule_types"].label, "BOTTOMLEFT", 0, -1)

    -- arg0: dropdown or editbox
    r.hiddenMenus["arg0_drop1"] = createDropDownMenu(r, "Select event", getRuleTypesItems(updateNewRuleHiddenMenu))
    r.hiddenMenus["arg0_drop1"].txt:SetJustifyH("CENTER")
    r.hiddenMenus["arg0_drop1"]:SetSize(xSize, 20)
    r.hiddenMenus["arg0_drop1"]:SetPoint("TOPLEFT", r.menus["roles"], "BOTTOMLEFT", 0, -1)
    r.hiddenMenus["arg0_drop1"].label = createFontDefault(r.hiddenMenus["arg0_drop1"], "RIGHT", "Reason event:")
    r.hiddenMenus["arg0_drop1"].label:SetSize(x - 5, 20)
    r.hiddenMenus["arg0_drop1"].label:SetPoint("TOPLEFT", r.menus["roles"].label, "BOTTOMLEFT", 0, -1)
    r.hiddenMenus["arg0_drop1"]:Hide()

    r.hiddenMenus["arg0_drop2"] = createDropDownMenu(r, "Select statistics type", getStatisticTypesItems(updateNewRuleMenu))
    r.hiddenMenus["arg0_drop2"].txt:SetJustifyH("CENTER")
    r.hiddenMenus["arg0_drop2"]:SetSize(xSize, 20)
    r.hiddenMenus["arg0_drop2"]:SetPoint("TOPLEFT", r.menus["roles"], "BOTTOMLEFT", 0, -1)
    r.hiddenMenus["arg0_drop2"].label = createFontDefault(r.hiddenMenus["arg0_drop2"], "RIGHT", "Statistics type:")
    r.hiddenMenus["arg0_drop2"].label:SetSize(x - 5, 20)
    r.hiddenMenus["arg0_drop2"].label:SetPoint("TOPLEFT", r.menus["roles"].label, "BOTTOMLEFT", 0, -1)
    r.hiddenMenus["arg0_drop2"]:Hide()

    r.hiddenMenus["arg0_edit"] = createEditBox(r)
    r.hiddenMenus["arg0_edit"]:SetSize(xSize, 20)
    r.hiddenMenus["arg0_edit"]:SetPoint("TOPLEFT", r.menus["roles"], "BOTTOMLEFT", 0, -1)
    r.hiddenMenus["arg0_edit"].label = createFontDefault(r.hiddenMenus["arg0_edit"], "RIGHT", "target spell id:")
    r.hiddenMenus["arg0_edit"].label:SetSize(x - 5, 20)
    r.hiddenMenus["arg0_edit"].label:SetPoint("TOPLEFT", r.menus["roles"].label, "BOTTOMLEFT", 0, -1)
    r.hiddenMenus["arg0_edit"]:Hide()

    -- arg1: dropdown or editbox
    r.hiddenMenus["arg1_drop1"] = createDropDownMenu(r, "Select event", getRuleTypesItems(updateNewRuleHiddenMenu))
    r.hiddenMenus["arg1_drop1"].txt:SetJustifyH("CENTER")
    r.hiddenMenus["arg1_drop1"]:SetSize(xSize, 20)
    r.hiddenMenus["arg1_drop1"]:SetPoint("TOPLEFT", r.hiddenMenus["arg0_drop1"], "BOTTOMLEFT", 0, -1)
    r.hiddenMenus["arg1_drop1"].label = createFontDefault(r.hiddenMenus["arg1_drop1"], "RIGHT", "")
    r.hiddenMenus["arg1_drop1"].label:SetSize(x - 5, 20)
    r.hiddenMenus["arg1_drop1"].label:SetPoint("TOPLEFT", r.hiddenMenus["arg0_drop1"].label, "BOTTOMLEFT", 0, -1)
    r.hiddenMenus["arg1_drop1"]:Hide()

    r.hiddenMenus["arg1_edit"] = createEditBox(r)
    r.hiddenMenus["arg1_edit"]:SetSize(xSize, 20)
    r.hiddenMenus["arg1_edit"]:SetPoint("TOPLEFT", r.hiddenMenus["arg0_drop1"], "BOTTOMLEFT", 0, -1)
    r.hiddenMenus["arg1_edit"].label = createFontDefault(r.hiddenMenus["arg1_edit"], "RIGHT", "quality percent:")
    r.hiddenMenus["arg1_edit"].label:SetSize(x - 5, 20)
    r.hiddenMenus["arg1_edit"].label:SetPoint("TOPLEFT", r.hiddenMenus["arg0_drop1"].label, "BOTTOMLEFT", 0, -1)
    r.hiddenMenus["arg1_edit"]:Hide()

    -- arg2: dropdown or editbox
    r.hiddenMenus["arg2_drop1"] = createDropDownMenu(r, "Select event", getRuleTypesItems(updateNewRuleHiddenMenu))
    r.hiddenMenus["arg2_drop1"].txt:SetJustifyH("CENTER")
    r.hiddenMenus["arg2_drop1"]:SetSize(xSize, 20)
    r.hiddenMenus["arg2_drop1"]:SetPoint("TOPLEFT", r.hiddenMenus["arg1_drop1"], "BOTTOMLEFT", 0, -1)
    r.hiddenMenus["arg2_drop1"].label = createFontDefault(r.hiddenMenus["arg2_drop1"], "RIGHT", "Stop event:")
    r.hiddenMenus["arg2_drop1"].label:SetSize(x - 5, 20)
    r.hiddenMenus["arg2_drop1"].label:SetPoint("TOPLEFT", r.hiddenMenus["arg1_drop1"].label, "BOTTOMLEFT", 0, -1)
    r.hiddenMenus["arg2_drop1"]:Hide()

    r.hiddenMenus["arg2_edit"] = createEditBox(r)
    r.hiddenMenus["arg2_edit"]:SetSize(xSize, 20)
    r.hiddenMenus["arg2_edit"]:SetPoint("TOPLEFT", r.hiddenMenus["arg1_drop1"], "BOTTOMLEFT", 0, -1)
    r.hiddenMenus["arg2_edit"].label = createFontDefault(r.hiddenMenus["arg2_edit"], "RIGHT", "time to reset (in msec):")
    r.hiddenMenus["arg2_edit"].label:SetSize(x - 5, 20)
    r.hiddenMenus["arg2_edit"].label:SetPoint("TOPLEFT", r.hiddenMenus["arg1_drop1"].label, "BOTTOMLEFT", 0, -1)
    r.hiddenMenus["arg2_edit"]:Hide()

    -- arg3: editbox
    r.hiddenMenus["arg3_edit"] = createEditBox(r)
    r.hiddenMenus["arg3_edit"]:SetSize(xSize, 20)
    r.hiddenMenus["arg3_edit"]:SetPoint("TOPLEFT", r.hiddenMenus["arg2_drop1"], "BOTTOMLEFT", 0, -1)
    r.hiddenMenus["arg3_edit"].label = createFontDefault(r.hiddenMenus["arg3_edit"], "RIGHT", "")
    r.hiddenMenus["arg3_edit"].label:SetSize(x - 5, 20)
    r.hiddenMenus["arg3_edit"].label:SetPoint("TOPLEFT", r.hiddenMenus["arg2_drop1"].label, "BOTTOMLEFT", 0, -1)
    r.hiddenMenus["arg3_edit"]:Hide()

    r:SetScript("OnHide", function() for _,v in pairs(r.hiddenMenus) do v:Hide() end end)

    r.buttons["save"] = createButton(r)
    r.buttons["save"]:SetPoint("TOPLEFT", r.hiddenMenus["arg3_edit"], "BOTTOMLEFT", 1, -2)
    r.buttons["save"]:SetSize(xSize / 2 - 1, 20)
    r.buttons["save"]:SetScript("OnClick", function() print('Not yet implemented'); r:Hide() end)
    r.buttons["save"].t:SetColorTexture(.2, .4, .2, 1)
    r.buttons["save"].txt = createFont(r.buttons["save"], "CENTER", "Save")
    r.buttons["save"].txt:SetAllPoints()

    r.buttons["cancel"] = createButton(r)
    r.buttons["cancel"]:SetPoint("TOPLEFT", r.buttons["save"], "TOPRIGHT", 1, 0)
    r.buttons["cancel"]:SetSize(xSize / 2 - 2, 20)
    r.buttons["cancel"]:SetScript("OnClick", function() r:Hide() end)
    r.buttons["cancel"].t:SetColorTexture(.4, .2, .2, 1)
    r.buttons["cancel"].txt = createFont(r.buttons["cancel"], "CENTER", "Cancel")
    r.buttons["cancel"].txt:SetAllPoints()

    r:EnableMouse(true)
    r:SetPoint("CENTER", WDRS, -150, 150)
    r:SetSize(totalWidth, 8 * 21 + 3)
    r.bg = createColorTexture(r, "TEXTURE", 0, 0, 0, 1)
    r.bg:SetAllPoints()

    initSelectedRuleMenu()

    r:Hide()
end

local function onMenuClick(menu)
    if not WDRS.menus[menu] then return end
    if WDRS.menus[menu]:IsVisible() then
        WDRS.menus[menu]:Hide()
    else
        WDRS.menus[menu]:Show()
    end

    for k,v in pairs(WDRS.menus) do
        if k ~= menu then v:Hide() end
    end
end

function WD:InitRulesStatisticsModule(parent)
    WDRS = parent

    WDRS.menus = {}
    WDRS.buttons = {}
    WDRS.rules = {}

    -- new rule button
    WDRS.buttons["add_rule"] = createButton(WDRS)
    WDRS.buttons["add_rule"]:SetPoint("TOPLEFT", WDRS, "TOPLEFT", 1, -5)
    WDRS.buttons["add_rule"]:SetSize(125, 20)
    WDRS.buttons["add_rule"]:SetScript("OnClick", function() onMenuClick("new_rule") end)
    WDRS.buttons["add_rule"].txt = createFont(WDRS.buttons["add_rule"], "CENTER", WD_BUTTON_NEW_RULE)
    WDRS.buttons["add_rule"].txt:SetAllPoints()

    -- headers
    local x, y = 1, -30
    WDRS.headers = {}
    local h = createTableHeader(WDRS, "", x, y, 20, 20)
    table.insert(WDRS.headers, h)
    h = createTableHeader(WDRS, WD_BUTTON_ENCOUNTER, x + 21, y, 150, 20)
    table.insert(WDRS.headers, h)
    h = createTableHeaderNext(WDRS, h, WD_BUTTON_ROLE, 75, 20)
    table.insert(WDRS.headers, h)
    h = createTableHeaderNext(WDRS, h, WD_BUTTON_REASON, 300, 20)
    table.insert(WDRS.headers, h)
    h = createTableHeaderNext(WDRS, h, WD_BUTTON_POINTS_SHORT, 50, 20)
    table.insert(WDRS.headers, h)
    h = createTableHeaderNext(WDRS, h, "", 50, 20)
    table.insert(WDRS.headers, h)
    h = createTableHeaderNext(WDRS, h, "", 50, 20)
    table.insert(WDRS.headers, h)
    h = createTableHeaderNext(WDRS, h, "", 50, 20)
    table.insert(WDRS.headers, h)
    h = createTableHeaderNext(WDRS, h, "", 70, 20)
    table.insert(WDRS.headers, h)

    initNewRuleWindow()

    function WDRS:OnUpdate()
    end
end
