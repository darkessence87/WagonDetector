
local WDRS = nil

local trackingRuleTypes = {
    "RL_RANGE_RULE",    -- arg0=range_rule_type, arg1=event_result                  checks if event_result applied to unit during specified events range
    "RL_DEPENDENCY",    -- arg0=event_reason,    arg1=event_result,   arg2=timeout  checks if event_result occured (or not) after event_reason during specified time
    "RL_STATISTICS",    -- arg0=statistic_type
    "RL_QUALITY",       -- arg0=quality_type                                        checks if spell was dispelled/interrupted too early or too late based on quality_value
}

local qualityTypes = {
    "QT_INTERRUPTS",       -- arg1=range_rule(RT_UNIT_CASTING),   arg2=quality_percent                        (in percents of total cast duration)
    "QT_DISPELS",          -- arg1=range_rule(RT_AURA_EXISTS),    arg2=time_from_value,   arg3=time_to_value  (in msec after aura applied)
}

local rangeRuleTypes = {
    "RT_AURA_EXISTS",      -- arg0=aura_id
    "RT_AURA_NOT_EXISTS",  -- arg0=aura_id
    "RT_UNIT_CASTING",     -- arg0=target_spell_id
    "RT_CUSTOM",           -- arg0=event_start,     arg1=event_result
}

local statisticTypes = {
    "ST_TARGET_DAMAGE",        -- arg1=range_rule_type,    arg3=unit   collects damage done to specified unit in events range related to that unit
    "ST_TARGET_HEALING",       -- arg1=range_rule_type                 collects healing done to units in events range related to those units
    "ST_TARGET_INTERRUPTS",    -- arg1=range_rule_type                 collects interrupts done to units in events range related to those units
    "ST_SOURCE_DAMAGE",        -- arg1=range_rule_type                 collects damage done by units in events range related to those units
    "ST_SOURCE_HEALING",       -- arg1=range_rule_type                 collects healing done by units in events range related to those units
    "ST_SOURCE_INTERRUPTS",    -- arg1=range_rule_type                 collects interrupts done by units in event range related to those units
}

local function showEventConfig(origin, name, rule)
--[[
    "EV_AURA"               arg0=aura_id      arg1=apply or remove
    "EV_AURA_STACKS"        arg0=aura_id      arg1=stacks or 0
    "EV_DISPEL"             arg0=aura_id
    "EV_CAST_START"         arg0=spell_id           arg1=unit_name
    "EV_CAST_INTERRUPTED"   arg0=target_spell_id    arg1=target_unit_name
    "EV_CAST_END"           arg0=spell_id           arg1=unit_name
    "EV_DAMAGETAKEN"        arg0=spell_id           arg1=amount or 0
    "EV_DEATH"              arg0=spell_id
    "EV_DEATH_UNIT"         arg0=unit_name
]]
    local parent = WDRS.menus["new_rule"]
    local r = parent.hiddenMenus[name]
    for _,v in pairs(r.hiddenMenus) do v:Hide() end
    local arg0_edit = r.hiddenMenus["arg0_edit"]
    local arg1_drop = r.hiddenMenus["arg1_drop"]
    local arg1_edit = r.hiddenMenus["arg1_edit"]

    r.label:SetText(rule)
    r.origin = origin

    if rule == "EV_AURA" then
        showHiddenEditBox(r, "arg0_edit", "aura id")
        updateDropDownMenu(arg1_drop, "Select action:", {{name = "apply"},{name = "remove"}})
        arg1_drop:Show()
    elseif rule == "EV_AURA_STACKS" then
        showHiddenEditBox(r, "arg0_edit", "aura id")
        showHiddenEditBox(r, "arg1_edit", "stacks or 0 (if any)")
    elseif rule == "EV_DISPEL" then
        showHiddenEditBox(r, "arg0_edit", "aura id")
    elseif rule == "EV_CAST_START" then
        showHiddenEditBox(r, "arg0_edit", "spell id")
        showHiddenEditBox(r, "arg1_edit", "caster name")
    elseif rule == "EV_CAST_INTERRUPTED" then
        showHiddenEditBox(r, "arg0_edit", "target spell id")
        showHiddenEditBox(r, "arg1_edit", "target name")
    elseif rule == "EV_CAST_END" then
        showHiddenEditBox(r, "arg0_edit", "spell id")
        showHiddenEditBox(r, "arg1_edit", "caster name")
    elseif rule == "EV_DAMAGETAKEN" then
        showHiddenEditBox(r, "arg0_edit", "spell id")
        showHiddenEditBox(r, "arg1_edit", "amount or 0")
    elseif rule == "EV_DEATH" then
        showHiddenEditBox(r, "arg0_edit", "spell id")
    elseif rule == "EV_DEATH_UNIT" then
        showHiddenEditBox(r, "arg0_edit", "unit name")
    end

    r:Show()
end

local function updateEventConfigMenu(frame, selected)
    local parent = WDRS.menus["new_rule"]

    local i = 1
    local menu = parent.hiddenMenus["selected_rule_"..i]
    while menu do
        if selected and (not menu.origin or menu.origin == frame) then
            showEventConfig(frame, "selected_rule_"..i, selected.name)
            return
        elseif not selected and menu.origin and menu.origin == frame then
            menu:Hide()
            menu.origin = nil
            return
        end
        i = i + 1
        menu = parent.hiddenMenus["selected_rule_"..i]
    end

    if selected then
        print("There are no free frames for config event:"..selected.name)
    end
end

local function updateRangeRuleMenu(frame, selected)
    local r = WDRS.menus["new_rule"].hiddenMenus["range_menu"]
    for _,v in pairs(r.hiddenMenus) do v:Hide(); updateEventConfigMenu(v); end
    local arg0_edit = r.hiddenMenus["arg0_edit"]
    local arg0_drop = r.hiddenMenus["arg0_drop"]
    local arg1_drop = r.hiddenMenus["arg1_drop"]

    local rule = selected.name
    r.label:SetText(rule)

    if rule == "RT_AURA_EXISTS" then
        showHiddenEditBox(r, "arg0_edit", "aura id")
    elseif rule == "RT_AURA_NOT_EXISTS" then
        showHiddenEditBox(r, "arg0_edit", "aura id")
    elseif rule == "RT_UNIT_CASTING" then
        showHiddenEditBox(r, "arg0_edit", "target spell id")
    elseif rule == "RT_CUSTOM" then
        updateDropDownMenu(arg0_drop, "Select start event:", updateItemsByHoverInfo(convertTypesToItems(WD.RuleTypes, updateEventConfigMenu), WD.Help.eventsInfo))
        arg0_drop:Show()
        updateDropDownMenu(arg1_drop, "Select end event:", updateItemsByHoverInfo(convertTypesToItems(WD.RuleTypes, updateEventConfigMenu), WD.Help.eventsInfo))
        arg1_drop:Show()
    end

    r:Show()
end

local function updateNewRuleHiddenMenu(frame, selected)
    local parent = WDRS.menus["new_rule"]
    local arg1_drop = parent.hiddenMenus["arg1_drop"]
    local arg2_drop = parent.hiddenMenus["arg2_drop"]
    local arg1_edit = parent.hiddenMenus["arg1_edit"]
    local arg2_edit = parent.hiddenMenus["arg2_edit"]
    local arg3_edit = parent.hiddenMenus["arg3_edit"]

    for k,v in pairs(parent.hiddenMenus) do
        if string.match(k, "selected_rule_") then
            v:Hide()
            v.origin = nil
        end
    end

    local name = selected.name
    if name == "QT_INTERRUPTS" then
        -- arg1
        showHiddenEditBox(parent, "arg1_edit", "RT_UNIT_CASTING")
        updateRangeRuleMenu(arg1_edit, {name = "RT_UNIT_CASTING"})
        arg1_edit.label:SetText("Range rule type:")
        arg1_edit:EnableMouse(false)
        -- arg2
        showHiddenEditBox(parent, "arg2_edit", 50)
        arg2_edit.label:SetText("Quality percent:")
        -- arg3
        arg3_edit:Hide()
    elseif name == "QT_DISPELS" then
        -- arg1
        showHiddenEditBox(parent, "arg1_edit", "RT_AURA_EXISTS")
        updateRangeRuleMenu(arg1_edit, {name = "RT_AURA_EXISTS"})
        arg1_edit.label:SetText("Range rule type:")
        arg1_edit:EnableMouse(false)
        -- arg2
        showHiddenEditBox(parent, "arg2_edit", 2000)
        arg2_edit.label:SetText("Early dispel before (msec):")
        -- arg3
        showHiddenEditBox(parent, "arg3_edit", 5000)
        arg3_edit.label:SetText("Late dispel after (msec):")
    elseif name == "ST_TARGET_DAMAGE"
        or name == "ST_TARGET_HEALING"
        or name == "ST_TARGET_INTERRUPTS"
        or name == "ST_SOURCE_DAMAGE"
        or name == "ST_SOURCE_HEALING"
        or name == "ST_SOURCE_INTERRUPTS"
    then
        -- arg1
        updateDropDownMenu(arg1_drop, "Select range:", updateItemsByHoverInfo(convertTypesToItems(rangeRuleTypes, updateRangeRuleMenu), WD.Help.rangesInfo))
        arg1_drop.label:SetText("Range rule type:")
        arg1_drop:Show()

        -- arg2
        if name == "ST_TARGET_DAMAGE" then
            showHiddenEditBox(parent, "arg2_edit", "unit name")
            arg2_edit.label:SetText("Target unit name:")
        else
            arg2_edit:Hide()
        end
    end
end

local function updateNewRuleMenuByTrackingRules(frame, selected)
    local parent = WDRS.menus["new_rule"]
    local rule = selected.name
    for _,v in pairs(parent.hiddenMenus) do v:Hide() end
    local arg0_drop = parent.hiddenMenus["arg0_drop"]
    local arg1_drop = parent.hiddenMenus["arg1_drop"]
    local arg2_drop = parent.hiddenMenus["arg2_drop"]
    local arg0_edit = parent.hiddenMenus["arg0_edit"]
    local arg1_edit = parent.hiddenMenus["arg1_edit"]
    local arg2_edit = parent.hiddenMenus["arg2_edit"]
    local arg3_edit = parent.hiddenMenus["arg3_edit"]

    if rule == "RL_RANGE_RULE" then
        -- arg0
        updateDropDownMenu(arg0_drop, "Select range:", updateItemsByHoverInfo(convertTypesToItems(rangeRuleTypes, updateRangeRuleMenu), WD.Help.rangesInfo))
        arg0_drop.label:SetText("Range rule type:")
        arg0_drop:Show()
        -- arg1
        updateDropDownMenu(arg1_drop, "Select result event:", updateItemsByHoverInfo(convertTypesToItems(WD.RuleTypes, updateEventConfigMenu), WD.Help.eventsInfo))
        arg1_drop.label:SetText("Result event:")
        arg1_drop:Show()
    elseif rule == "RL_DEPENDENCY" then
        -- arg0
        updateDropDownMenu(arg0_drop, "Select reason event:", updateItemsByHoverInfo(convertTypesToItems(WD.RuleTypes, updateEventConfigMenu), WD.Help.eventsInfo))
        arg0_drop.label:SetText("Reason event:")
        arg0_drop:Show()
        -- arg1
        updateDropDownMenu(arg1_drop, "Select result event:", updateItemsByHoverInfo(convertTypesToItems(WD.RuleTypes, updateEventConfigMenu), WD.Help.eventsInfo))
        arg1_drop.label:SetText("Result event:")
        arg1_drop:Show()
        -- arg2
        arg2_edit.label:SetText("Timeout (in msec):")
        showHiddenEditBox(parent, "arg2_edit", "1000")
    elseif rule == "RL_STATISTICS" then
        -- arg0
        updateDropDownMenu(arg0_drop, "Select statistics:", updateItemsByHoverInfo(convertTypesToItems(statisticTypes, updateNewRuleHiddenMenu), WD.Help.statisticInfo))
        arg0_drop.label:SetText("Statistics mode:")
        arg0_drop:Show()
    elseif rule == "RL_QUALITY" then
        -- arg0
        updateDropDownMenu(arg0_drop, "Select quality:", convertTypesToItems(qualityTypes, updateNewRuleHiddenMenu))
        arg0_drop.label:SetText("Quality type:")
        arg0_drop:Show()
    end

    for k,v in pairs(parent.hiddenMenus) do
        if string.match(k, "selected_rule_") then
            v:Hide()
            v.origin = nil
        end
    end
end

local function initSelectedRuleMenu()
    local parent = WDRS.menus["new_rule"]
    local maxV = 4
    local m = math.floor(maxV / 2) + 1
    for i=1,maxV do
        local r = createRuleWindow(parent)
        r:SetFrameStrata("HIGH")

        if i == 1 then
            r:SetPoint("TOPLEFT", parent, "TOPRIGHT", 1, 0)
        elseif i == m then
            r:SetPoint("BOTTOMLEFT", parent, "BOTTOMRIGHT", 1, 0)
        else
            r:SetPoint("TOPLEFT", parent.hiddenMenus["selected_rule_"..(i-1)], "TOPRIGHT", 1, 0)
        end

        parent.hiddenMenus["selected_rule_"..i] = r
    end
end

local function initRangeRuleMenu()
    local parent = WDRS.menus["new_rule"]
    local r = CreateFrame("Frame", nil, parent)
    r.hiddenMenus = {}

    local xSize = 150

    -- label
    r.label = createFontDefault(r, "CENTER", "")
    r.label:SetSize(xSize, 20)
    r.label:SetPoint("TOPRIGHT", r, "TOPRIGHT", 1, -1)

    -- arg0: dropdown or editbox
    r.hiddenMenus["arg0_drop"] = createDropDownMenu(r)
    r.hiddenMenus["arg0_drop"].txt:SetJustifyH("CENTER")
    r.hiddenMenus["arg0_drop"]:SetSize(xSize, 20)
    r.hiddenMenus["arg0_drop"]:SetPoint("TOPRIGHT", r.label, "BOTTOMRIGHT", 0, -1)
    r.hiddenMenus["arg0_drop"]:Hide()

    r.hiddenMenus["arg0_edit"] = createEditBox(r)
    r.hiddenMenus["arg0_edit"]:SetSize(xSize, 20)
    r.hiddenMenus["arg0_edit"]:SetPoint("TOPRIGHT", r.label, "BOTTOMRIGHT", 0, -1)
    r.hiddenMenus["arg0_edit"]:Hide()

    -- arg1: dropdown
    r.hiddenMenus["arg1_drop"] = createDropDownMenu(r)
    r.hiddenMenus["arg1_drop"].txt:SetJustifyH("CENTER")
    r.hiddenMenus["arg1_drop"]:SetSize(xSize, 20)
    r.hiddenMenus["arg1_drop"]:SetPoint("TOPRIGHT", r.hiddenMenus["arg0_drop"], "BOTTOMRIGHT", 0, -1)
    r.hiddenMenus["arg1_drop"]:Hide()

    r:SetScript("OnHide", function() for _,v in pairs(r.hiddenMenus) do v:Hide() end end)

    r:EnableMouse(true)
    r:SetPoint("TOPRIGHT", parent, "TOPLEFT", -1, 0)
    r:SetSize(xSize, 2 * 21 + 1)
    r.bg = createColorTexture(r, "TEXTURE", 0, 0, 0, 1)
    r.bg:SetAllPoints()

    r:Hide()

    parent.hiddenMenus["range_menu"] = r
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
    -- tracking rules menu
    r.menus["rule_types"] = createDropDownMenu(r, "Select rule type", updateItemsByHoverInfo(convertTypesToItems(trackingRuleTypes, updateNewRuleMenuByTrackingRules), WD.Help.rulesInfo))
    r.menus["rule_types"]:SetSize(xSize, 20)
    r.menus["rule_types"]:SetPoint("TOPLEFT", r.menus["encounters"], "BOTTOMLEFT", 0, -1)
    r.menus["rule_types"].label = createFontDefault(r.menus["rule_types"], "RIGHT", "Rule:")
    r.menus["rule_types"].label:SetSize(x - 5, 20)
    r.menus["rule_types"].label:SetPoint("TOPLEFT", r.menus["encounters"].label, "BOTTOMLEFT", 0, -1)

    -- arg0: dropdown or editbox
    r.hiddenMenus["arg0_drop"] = createDropDownMenu(r)
    r.hiddenMenus["arg0_drop"].txt:SetJustifyH("CENTER")
    r.hiddenMenus["arg0_drop"]:SetSize(xSize, 20)
    r.hiddenMenus["arg0_drop"]:SetPoint("TOPLEFT", r.menus["rule_types"], "BOTTOMLEFT", 0, -1)
    r.hiddenMenus["arg0_drop"].label = createFontDefault(r.hiddenMenus["arg0_drop"], "RIGHT", "Statistics type:")
    r.hiddenMenus["arg0_drop"].label:SetSize(x - 5, 20)
    r.hiddenMenus["arg0_drop"].label:SetPoint("TOPLEFT", r.menus["rule_types"].label, "BOTTOMLEFT", 0, -1)
    r.hiddenMenus["arg0_drop"]:Hide()

    r.hiddenMenus["arg0_edit"] = createEditBox(r)
    r.hiddenMenus["arg0_edit"]:SetSize(xSize, 20)
    r.hiddenMenus["arg0_edit"]:SetPoint("TOPLEFT", r.menus["rule_types"], "BOTTOMLEFT", 0, -1)
    r.hiddenMenus["arg0_edit"].label = createFontDefault(r.hiddenMenus["arg0_edit"], "RIGHT", "target spell id:")
    r.hiddenMenus["arg0_edit"].label:SetSize(x - 5, 20)
    r.hiddenMenus["arg0_edit"].label:SetPoint("TOPLEFT", r.menus["rule_types"].label, "BOTTOMLEFT", 0, -1)
    r.hiddenMenus["arg0_edit"]:Hide()

    -- arg1: dropdown or editbox
    r.hiddenMenus["arg1_drop"] = createDropDownMenu(r)
    r.hiddenMenus["arg1_drop"].txt:SetJustifyH("CENTER")
    r.hiddenMenus["arg1_drop"]:SetSize(xSize, 20)
    r.hiddenMenus["arg1_drop"]:SetPoint("TOPLEFT", r.hiddenMenus["arg0_drop"], "BOTTOMLEFT", 0, -1)
    r.hiddenMenus["arg1_drop"].label = createFontDefault(r.hiddenMenus["arg1_drop"], "RIGHT", "")
    r.hiddenMenus["arg1_drop"].label:SetSize(x - 5, 20)
    r.hiddenMenus["arg1_drop"].label:SetPoint("TOPLEFT", r.hiddenMenus["arg0_drop"].label, "BOTTOMLEFT", 0, -1)
    r.hiddenMenus["arg1_drop"]:Hide()

    r.hiddenMenus["arg1_edit"] = createEditBox(r)
    r.hiddenMenus["arg1_edit"]:SetSize(xSize, 20)
    r.hiddenMenus["arg1_edit"]:SetPoint("TOPLEFT", r.hiddenMenus["arg0_drop"], "BOTTOMLEFT", 0, -1)
    r.hiddenMenus["arg1_edit"].label = createFontDefault(r.hiddenMenus["arg1_edit"], "RIGHT", "quality percent:")
    r.hiddenMenus["arg1_edit"].label:SetSize(x - 5, 20)
    r.hiddenMenus["arg1_edit"].label:SetPoint("TOPLEFT", r.hiddenMenus["arg0_drop"].label, "BOTTOMLEFT", 0, -1)
    r.hiddenMenus["arg1_edit"]:Hide()

    -- arg2: dropdown or editbox
    r.hiddenMenus["arg2_drop"] = createDropDownMenu(r)
    r.hiddenMenus["arg2_drop"].txt:SetJustifyH("CENTER")
    r.hiddenMenus["arg2_drop"]:SetSize(xSize, 20)
    r.hiddenMenus["arg2_drop"]:SetPoint("TOPLEFT", r.hiddenMenus["arg1_drop"], "BOTTOMLEFT", 0, -1)
    r.hiddenMenus["arg2_drop"].label = createFontDefault(r.hiddenMenus["arg2_drop"], "RIGHT", "Stop event:")
    r.hiddenMenus["arg2_drop"].label:SetSize(x - 5, 20)
    r.hiddenMenus["arg2_drop"].label:SetPoint("TOPLEFT", r.hiddenMenus["arg1_drop"].label, "BOTTOMLEFT", 0, -1)
    r.hiddenMenus["arg2_drop"]:Hide()

    r.hiddenMenus["arg2_edit"] = createEditBox(r)
    r.hiddenMenus["arg2_edit"]:SetSize(xSize, 20)
    r.hiddenMenus["arg2_edit"]:SetPoint("TOPLEFT", r.hiddenMenus["arg1_drop"], "BOTTOMLEFT", 0, -1)
    r.hiddenMenus["arg2_edit"].label = createFontDefault(r.hiddenMenus["arg2_edit"], "RIGHT", "time to reset (in msec):")
    r.hiddenMenus["arg2_edit"].label:SetSize(x - 5, 20)
    r.hiddenMenus["arg2_edit"].label:SetPoint("TOPLEFT", r.hiddenMenus["arg1_drop"].label, "BOTTOMLEFT", 0, -1)
    r.hiddenMenus["arg2_edit"]:Hide()

    -- arg3: editbox
    r.hiddenMenus["arg3_edit"] = createEditBox(r)
    r.hiddenMenus["arg3_edit"]:SetSize(xSize, 20)
    r.hiddenMenus["arg3_edit"]:SetPoint("TOPLEFT", r.hiddenMenus["arg2_drop"], "BOTTOMLEFT", 0, -1)
    r.hiddenMenus["arg3_edit"].label = createFontDefault(r.hiddenMenus["arg3_edit"], "RIGHT", "")
    r.hiddenMenus["arg3_edit"].label:SetSize(x - 5, 20)
    r.hiddenMenus["arg3_edit"].label:SetPoint("TOPLEFT", r.hiddenMenus["arg2_drop"].label, "BOTTOMLEFT", 0, -1)
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
    r:SetPoint("CENTER", WDRS, -80, 150)
    r:SetSize(totalWidth, 7 * 21 + 3)
    r.bg = createColorTexture(r, "TEXTURE", 0, 0, 0, 1)
    r.bg:SetAllPoints()

    initSelectedRuleMenu()
    initRangeRuleMenu()

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
