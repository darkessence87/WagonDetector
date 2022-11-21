
local WDRulesModule = {}
WDRulesModule.__index = WDRulesModule

setmetatable(WDRulesModule, {
    __index = WD.Module,
    __call = function (v, ...)
        local self = setmetatable({}, v)
        self:init(...)
        return self
    end,
})

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
    "RT_CUSTOM",           -- arg0=event_start,     arg1=event_end
}

local statisticTypes = {
    "ST_TARGET_DAMAGE",        -- arg1=range_rule_type,    arg3=unit   collects damage done to specified unit in events range related to that unit
    "ST_TARGET_HEALING",       -- arg1=range_rule_type                 collects healing done to units in events range related to those units
    "ST_TARGET_INTERRUPTS",    -- arg1=range_rule_type                 collects interrupts done to units in events range related to those units
    "ST_SOURCE_DAMAGE",        -- arg1=range_rule_type                 collects damage done by units in events range related to those units
    "ST_SOURCE_HEALING",       -- arg1=range_rule_type                 collects healing done by units in events range related to those units
    "ST_SOURCE_INTERRUPTS",    -- arg1=range_rule_type                 collects interrupts done by units in event range related to those units
}

local function findDuplicate(rule)
    local found = nil
    local function compareArgs(arg1, arg2)
        if not arg1 and not arg2 then
            return true
        end
        if (arg1 and not arg2) or (not arg1 and arg2) then
            return false
        end
        if type(arg1) ~= type(arg2) then
            return false
        end
        if type(arg1) == "table" then
            for k in pairs(arg1) do
                if not arg2[k] then
                    return false
                elseif compareArgs(arg1[k], arg2[k]) == false then
                    return false
                end
            end
            return true
        end
        if arg1 ~= arg2 then
            return false
        end
        return true
    end
    for k,v in pairs(WD.db.profile.statRules) do
        if v.journalId == rule.journalId and v.ruleType == rule.ruleType then
            if compareArgs(v.arg0, rule.arg0) == true and
               compareArgs(v.arg1, rule.arg1) == true
            then
                found = v
                break
            end
        end
    end
    return found
end

local function getRuleDescription(rule)
    local function getRangeRuleDescription(rangeRule, data)
        if rangeRule == "RT_AURA_EXISTS" then
            return string.format(WD_TRACKER_RT_AURA_EXISTS_DESC, WdLib.gui:getSpellLinkByIdWithTexture(data))
        elseif rangeRule == "RT_AURA_NOT_EXISTS" then
            return string.format(WD_TRACKER_RT_AURA_NOT_EXISTS_DESC, WdLib.gui:getSpellLinkByIdWithTexture(data))
        elseif rangeRule == "RT_UNIT_CASTING" then
            return string.format(WD_TRACKER_RT_UNIT_CASTING_DESC, WdLib.gui:getSpellLinkByIdWithTexture(data))
        elseif rangeRule == "RT_CUSTOM" then
            local startEventMsg = WD.GetEventDescription(data.startEvent[1], data.startEvent[2][1], data.startEvent[2][2])
            local endEventMsg = WD.GetEventDescription(data.endEvent[1], data.endEvent[2][1], data.endEvent[2][2])
            return string.format(WD_TRACKER_RT_CUSTOM_DESC, startEventMsg, endEventMsg)
        end
    end

    if rule.ruleType == "RL_QUALITY" then
        if rule.arg0 == "QT_INTERRUPTS" then
            return string.format(WD_TRACKER_QT_INTERRUPTS_DESC, rule.qualityPercent, WdLib.gui:getSpellLinkByIdWithTexture(rule.arg1))
        elseif rule.arg0 == "QT_DISPELS" then
            if rule.earlyDispel > 0 and rule.lateDispel > 0 then
                return string.format(WD_TRACKER_QT_DISPELS_FULL_RANGE, rule.earlyDispel, rule.lateDispel, WdLib.gui:getSpellLinkByIdWithTexture(rule.arg1))
            elseif rule.earlyDispel > 0 and rule.lateDispel == 0 then
                return string.format(WD_TRACKER_QT_DISPELS_LEFT_RANGE, rule.earlyDispel, WdLib.gui:getSpellLinkByIdWithTexture(rule.arg1))
            elseif rule.earlyDispel == 0 and rule.lateDispel > 0 then
                return string.format(WD_TRACKER_QT_DISPELS_RIGHT_RANGE, rule.lateDispel, WdLib.gui:getSpellLinkByIdWithTexture(rule.arg1))
            end
        end
    elseif rule.ruleType == "RL_RANGE_RULE" then
        local eventName, eventArg0, eventArg1 = rule.arg1[1], rule.arg1[2][1], rule.arg1[2][2]
        local eventMsg = WD.GetEventDescription(eventName, eventArg0, eventArg1)
        local rangeMsg = getRangeRuleDescription(rule.arg0[1], rule.arg0[2])
        return eventMsg.." "..rangeMsg
    elseif rule.ruleType == "RL_DEPENDENCY" then
        local reasonName, reasonArg0, reasonArg1 = rule.arg0[1], rule.arg0[2][1], rule.arg0[2][2]
        local reasonMsg = WD.GetEventDescription(reasonName, reasonArg0, reasonArg1)
        local resultName, resultArg0, resultArg1 = rule.arg1[1], rule.arg1[2][1], rule.arg1[2][2]
        local resultMsg = WD.GetEventDescription(resultName, resultArg0, resultArg1)
        return string.format(WD_TRACKER_RT_DEPENDENCY_DESC, resultMsg, rule.timeout, reasonMsg)
    elseif rule.ruleType == "RL_STATISTICS" then
        if rule.arg0 == "ST_TARGET_DAMAGE" then
            local msg = string.format(WD_TRACKER_ST_TARGET_DAMAGE, rule.targetUnit)
            return msg.." "..getRangeRuleDescription(rule.arg1[1], rule.arg1[2])
        elseif rule.arg0 == "ST_TARGET_HEALING" then
            return WD_TRACKER_ST_TARGET_HEALING.." "..getRangeRuleDescription(rule.arg1[1], rule.arg1[2])
        elseif rule.arg0 == "ST_TARGET_INTERRUPTS" then
            return WD_TRACKER_ST_TARGET_INTERRUPTS.." "..getRangeRuleDescription(rule.arg1[1], rule.arg1[2])
        elseif rule.arg0 == "ST_SOURCE_DAMAGE" then
            return WD_TRACKER_ST_SOURCE_DAMAGE.." "..getRangeRuleDescription(rule.arg1[1], rule.arg1[2])
        elseif rule.arg0 == "ST_SOURCE_HEALING" then
            return WD_TRACKER_ST_SOURCE_HEALING.." "..getRangeRuleDescription(rule.arg1[1], rule.arg1[2])
        elseif rule.arg0 == "ST_SOURCE_INTERRUPTS" then
            return WD_TRACKER_ST_SOURCE_INTERRUPTS.." "..getRangeRuleDescription(rule.arg1[1], rule.arg1[2])
        end
    end
    return "Not yet implemented"
end

local function editEventConfig(eventFrame, eventName, args)
    for _,v in pairs(eventFrame.hiddenMenus) do v:Hide() end

    eventFrame.label:SetText(eventName)

    local arg0_edit = eventFrame.hiddenMenus["arg0_edit"]
    local arg1_edit = eventFrame.hiddenMenus["arg1_edit"]
    local arg1_drop = eventFrame.hiddenMenus["arg1_drop"]

    if eventName == "EV_AURA" then
        WdLib.gui:showHiddenEditBox(eventFrame, "arg0_edit", args[1])
        WdLib.gui:updateDropDownMenu(arg1_drop, "Select action:", {{name = "apply"},{name = "remove"}})
        local arg1_frame = WdLib.gui:findDropDownFrameByName(arg1_drop, args[2])
        if arg1_frame then
            arg1_drop.selected = arg1_frame
            arg1_drop:SetText(args[2])
        end
        arg1_drop:Show()
    elseif eventName == "EV_AURA_STACKS" then
        WdLib.gui:showHiddenEditBox(eventFrame, "arg0_edit", args[1])
        WdLib.gui:showHiddenEditBox(eventFrame, "arg1_edit", args[2])
    elseif eventName == "EV_DISPEL" then
        WdLib.gui:showHiddenEditBox(eventFrame, "arg0_edit", args[1])
    elseif eventName == "EV_CAST_START" then
        WdLib.gui:showHiddenEditBox(eventFrame, "arg0_edit", args[1])
        WdLib.gui:showHiddenEditBox(eventFrame, "arg1_edit", args[2])
    elseif eventName == "EV_CAST_INTERRUPTED" then
        WdLib.gui:showHiddenEditBox(eventFrame, "arg0_edit", args[1])
        WdLib.gui:showHiddenEditBox(eventFrame, "arg1_edit", args[2])
    elseif eventName == "EV_CAST_END" then
        WdLib.gui:showHiddenEditBox(eventFrame, "arg0_edit", args[1])
        WdLib.gui:showHiddenEditBox(eventFrame, "arg1_edit", args[2])
    elseif eventName == "EV_DAMAGETAKEN" then
        WdLib.gui:showHiddenEditBox(eventFrame, "arg0_edit", args[1])
        WdLib.gui:showHiddenEditBox(eventFrame, "arg1_edit", args[2])
    elseif eventName == "EV_DEATH" then
        WdLib.gui:showHiddenEditBox(eventFrame, "arg0_edit", args[1])
    elseif eventName == "EV_DEATH_UNIT" then
        WdLib.gui:showHiddenEditBox(eventFrame, "arg0_edit", args[1])
    end
end

local function editEventConfigMenu(frame, ...)
    local parent = WDRS.menus["new_rule"]

    local i = 1
    local menu = parent.hiddenMenus["selected_rule_"..i]
    while menu do
        if not menu.origin or menu.origin == frame then
            menu.origin = frame
            if frame and frame.t then
                frame.t:SetColorTexture(unpack(menu.bg.color))
            end
            editEventConfig(menu, ...)
            menu:Show()
            return
        end
        i = i + 1
        menu = parent.hiddenMenus["selected_rule_"..i]
    end

    if selected then
        print("There are no free frames for config event:"..selected.name)
    end
end

local function showEventConfig(origin, menuId, rule)
--[[
    "EV_AURA"               arg0=aura_id            arg1=apply or remove
    "EV_AURA_STACKS"        arg0=aura_id            arg1=stacks or 0
    "EV_DISPEL"             arg0=aura_id
    "EV_CAST_START"         arg0=spell_id           arg1=unit_name
    "EV_CAST_INTERRUPTED"   arg0=target_spell_id    arg1=target_unit_name
    "EV_CAST_END"           arg0=spell_id           arg1=unit_name
    "EV_DAMAGETAKEN"        arg0=spell_id           arg1=amount or 0
    "EV_DEATH"              arg0=spell_id
    "EV_DEATH_UNIT"         arg0=unit_name
]]
    local parent = WDRS.menus["new_rule"]
    local r = parent.hiddenMenus[menuId]
    for _,v in pairs(r.hiddenMenus) do v:Hide() end
    local arg0_edit = r.hiddenMenus["arg0_edit"]
    local arg1_drop = r.hiddenMenus["arg1_drop"]
    local arg1_edit = r.hiddenMenus["arg1_edit"]

    r.label:SetText(rule)
    r.origin = origin
    if origin and origin.t then
        origin.t:SetColorTexture(unpack(r.bg.color))
    end

    if rule == "EV_AURA" then
        WdLib.gui:showHiddenEditBox(r, "arg0_edit", "aura id")
        WdLib.gui:updateDropDownMenu(arg1_drop, "Select action:", {{name = "apply"},{name = "remove"}})
        arg1_drop:Show()
    elseif rule == "EV_AURA_STACKS" then
        WdLib.gui:showHiddenEditBox(r, "arg0_edit", "aura id")
        WdLib.gui:showHiddenEditBox(r, "arg1_edit", "stacks or 0 (if any)")
    elseif rule == "EV_DISPEL" then
        WdLib.gui:showHiddenEditBox(r, "arg0_edit", "aura id")
    elseif rule == "EV_CAST_START" then
        WdLib.gui:showHiddenEditBox(r, "arg0_edit", "spell id")
        WdLib.gui:showHiddenEditBox(r, "arg1_edit", "caster name")
    elseif rule == "EV_CAST_INTERRUPTED" then
        WdLib.gui:showHiddenEditBox(r, "arg0_edit", "target spell id")
        WdLib.gui:showHiddenEditBox(r, "arg1_edit", "target name")
    elseif rule == "EV_CAST_END" then
        WdLib.gui:showHiddenEditBox(r, "arg0_edit", "spell id")
        WdLib.gui:showHiddenEditBox(r, "arg1_edit", "caster name")
    elseif rule == "EV_DAMAGETAKEN" then
        WdLib.gui:showHiddenEditBox(r, "arg0_edit", "spell id")
        WdLib.gui:showHiddenEditBox(r, "arg1_edit", "amount or 0")
    elseif rule == "EV_DEATH" then
        WdLib.gui:showHiddenEditBox(r, "arg0_edit", "spell id")
    elseif rule == "EV_DEATH_UNIT" then
        WdLib.gui:showHiddenEditBox(r, "arg0_edit", "unit name")
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
            return
        end
        i = i + 1
        menu = parent.hiddenMenus["selected_rule_"..i]
    end

    if selected then
        print("There are no free frames for config event:"..selected.name)
    end
end

local function editRangeRuleMenu(origin, ruleType, arg0)
    local r = WDRS.menus["new_rule"].hiddenMenus["range_menu"]
    for _,v in pairs(r.hiddenMenus) do v:Hide(); updateEventConfigMenu(v); end
    local arg0_edit = r.hiddenMenus["arg0_edit"]
    local arg0_drop = r.hiddenMenus["arg0_drop"]
    local arg1_drop = r.hiddenMenus["arg1_drop"]

    r.origin = origin
    r.origin.t:SetColorTexture(unpack(r.bg.color))
    r.label:SetText(ruleType)

    if ruleType == "RT_UNIT_CASTING" then
        WdLib.gui:showHiddenEditBox(r, "arg0_edit", arg0)
    elseif ruleType == "RT_AURA_EXISTS" then
        WdLib.gui:showHiddenEditBox(r, "arg0_edit", arg0)
    elseif ruleType == "RT_AURA_NOT_EXISTS" then
        WdLib.gui:showHiddenEditBox(r, "arg0_edit", arg0)
    elseif ruleType == "RT_CUSTOM" then
        -- arg0
        WdLib.gui:updateDropDownMenu(arg0_drop, "Select start event:", WdLib.gui:updateItemsByHoverInfo(true, WD.EventTypes, WD.Help.eventsInfo, updateEventConfigMenu))
        local arg0_frame = WdLib.gui:findDropDownFrameByName(arg0_drop, arg0.startEvent[1])
        if arg0_frame then
            arg0_drop.selected = arg0_frame
            arg0_drop:SetText(arg0.startEvent[1])
        end
        arg0_drop:Show()
        editEventConfigMenu(arg0_drop, arg0.startEvent[1], arg0.startEvent[2])
        -- arg1
        WdLib.gui:updateDropDownMenu(arg1_drop, "Select end event:", WdLib.gui:updateItemsByHoverInfo(true, WD.EventTypes, WD.Help.eventsInfo, updateEventConfigMenu))
        local arg1_frame = WdLib.gui:findDropDownFrameByName(arg1_drop, arg0.endEvent[1])
        if arg1_frame then
            arg1_drop.selected = arg1_frame
            arg1_drop:SetText(arg0.endEvent[1])
        end
        arg1_drop:Show()
        editEventConfigMenu(arg1_drop, arg0.endEvent[1], arg0.endEvent[2])
    end

    r:Show()
end

local function updateRangeRuleMenu(frame, selected)
    local r = WDRS.menus["new_rule"].hiddenMenus["range_menu"]
    for _,v in pairs(r.hiddenMenus) do v:Hide(); updateEventConfigMenu(v); end
    local arg0_edit = r.hiddenMenus["arg0_edit"]
    local arg0_drop = r.hiddenMenus["arg0_drop"]
    local arg1_drop = r.hiddenMenus["arg1_drop"]

    if not frame then r:Hide() return end

    r.origin = frame
    r.origin.t:SetColorTexture(unpack(r.bg.color))

    local rule = selected.name
    r.label:SetText(rule)

    if rule == "RT_AURA_EXISTS" then
        WdLib.gui:showHiddenEditBox(r, "arg0_edit", "aura id")
    elseif rule == "RT_AURA_NOT_EXISTS" then
        WdLib.gui:showHiddenEditBox(r, "arg0_edit", "aura id")
    elseif rule == "RT_UNIT_CASTING" then
        WdLib.gui:showHiddenEditBox(r, "arg0_edit", "target spell id")
    elseif rule == "RT_CUSTOM" then
        WdLib.gui:updateDropDownMenu(arg0_drop, "Select start event:", WdLib.gui:updateItemsByHoverInfo(true, WD.EventTypes, WD.Help.eventsInfo, updateEventConfigMenu))
        arg0_drop:Show()
        WdLib.gui:updateDropDownMenu(arg1_drop, "Select end event:", WdLib.gui:updateItemsByHoverInfo(true, WD.EventTypes, WD.Help.eventsInfo, updateEventConfigMenu))
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
        end
    end

    local name = selected.name
    if name == "QT_INTERRUPTS" then
        -- arg1
        WdLib.gui:showHiddenEditBox(parent, "arg1_edit", "RT_UNIT_CASTING")
        updateRangeRuleMenu(arg1_edit, {name = "RT_UNIT_CASTING"})
        arg1_edit.label:SetText("Range rule type:")
        arg1_edit:EnableMouse(false)
        -- arg2
        WdLib.gui:showHiddenEditBox(parent, "arg2_edit", 50)
        arg2_edit.label:SetText("Quality percent:")
        -- arg3
        arg3_edit:Hide()
    elseif name == "QT_DISPELS" then
        -- arg1
        WdLib.gui:showHiddenEditBox(parent, "arg1_edit", "RT_AURA_EXISTS")
        updateRangeRuleMenu(arg1_edit, {name = "RT_AURA_EXISTS"})
        arg1_edit.label:SetText("Range rule type:")
        arg1_edit:EnableMouse(false)
        -- arg2
        WdLib.gui:showHiddenEditBox(parent, "arg2_edit", 2000)
        arg2_edit.label:SetText("Early dispel before (msec):")
        -- arg3
        WdLib.gui:showHiddenEditBox(parent, "arg3_edit", 5000)
        arg3_edit.label:SetText("Late dispel after (msec):")
    elseif name == "ST_TARGET_DAMAGE"
        or name == "ST_TARGET_HEALING"
        or name == "ST_TARGET_INTERRUPTS"
        or name == "ST_SOURCE_DAMAGE"
        or name == "ST_SOURCE_HEALING"
        or name == "ST_SOURCE_INTERRUPTS"
    then
        -- arg1
        WdLib.gui:updateDropDownMenu(arg1_drop, "Select range:", WdLib.gui:updateItemsByHoverInfo(true, rangeRuleTypes, WD.Help.rangesInfo, updateRangeRuleMenu))
        updateRangeRuleMenu()
        arg1_drop.label:SetText("Range rule type:")
        arg1_drop:Show()

        -- arg2
        if name == "ST_TARGET_DAMAGE" then
            WdLib.gui:showHiddenEditBox(parent, "arg2_edit", "unit name")
            arg2_edit.label:SetText("Target unit name:")
        else
            arg2_edit:Hide()
        end
    end
end

local function editRule(rule)
    if not rule then return end
    local parent = WDRS.menus["new_rule"]
    if parent:IsVisible() and parent.selected and parent.selected == rule then parent:Hide() parent.selected = nil return end
    parent.selected = rule

    WDRS.menus["new_rule"].menus["preview"]:SetText(getRuleDescription(rule))

    for _,v in pairs(parent.hiddenMenus) do v:Hide() end
    local arg0_edit = parent.hiddenMenus["arg0_edit"]
    local arg0_drop = parent.hiddenMenus["arg0_drop"]
    local arg1_drop = parent.hiddenMenus["arg1_drop"]
    local arg1_edit = parent.hiddenMenus["arg1_edit"]
    local arg2_edit = parent.hiddenMenus["arg2_edit"]
    local arg3_edit = parent.hiddenMenus["arg3_edit"]

    -- encounter
    local encounterName = WD.EncounterNames[rule.journalId]
    local frame = WdLib.gui:findDropDownFrameByName(parent.menus["encounters"], encounterName)
    if frame then
        parent.menus["encounters"].selected = frame
        parent.menus["encounters"]:SetText(encounterName)
    end

    -- rule
    local ruleFrame = WdLib.gui:findDropDownFrameByName(parent.menus["rule_types"], rule.ruleType)
    if ruleFrame then
        parent.menus["rule_types"].selected = ruleFrame
        parent.menus["rule_types"]:SetText(rule.ruleType)
    end

    if rule.ruleType == "RL_QUALITY" then
        -- quality type
        WdLib.gui:updateDropDownMenu(arg0_drop, "Select quality:", WdLib.gui:convertTypesToItems(qualityTypes, updateNewRuleHiddenMenu))
        local frame = WdLib.gui:findDropDownFrameByName(arg0_drop, rule.arg0)
        if frame then
            arg0_drop.selected = frame
            arg0_drop:SetText(rule.arg0)
        end
        arg0_drop.label:SetText("Quality type:")
        arg0_drop:Show()

        if rule.arg0 == "QT_INTERRUPTS" then
            -- arg1
            WdLib.gui:showHiddenEditBox(parent, "arg1_edit", "RT_UNIT_CASTING")
            arg1_edit.label:SetText("Range rule type:")
            arg1_edit:EnableMouse(false)
            editRangeRuleMenu(arg1_edit, "RT_UNIT_CASTING", rule.arg1)
            -- arg2
            WdLib.gui:showHiddenEditBox(parent, "arg2_edit", rule.qualityPercent)
            arg2_edit.label:SetText("Quality percent:")
            -- arg3
            arg3_edit:Hide()
        elseif rule.arg0 == "QT_DISPELS" then
            -- arg1
            WdLib.gui:showHiddenEditBox(parent, "arg1_edit", "RT_AURA_EXISTS")
            arg1_edit.label:SetText("Range rule type:")
            arg1_edit:EnableMouse(false)
            editRangeRuleMenu(arg1_edit, "RT_AURA_EXISTS", rule.arg1)
            -- arg2
            WdLib.gui:showHiddenEditBox(parent, "arg2_edit", rule.earlyDispel)
            arg2_edit.label:SetText("Early dispel before (msec):")
            -- arg3
            WdLib.gui:showHiddenEditBox(parent, "arg3_edit", rule.lateDispel)
            arg3_edit.label:SetText("Late dispel after (msec):")
       end
    elseif rule.ruleType == "RL_RANGE_RULE" then
        -- range rule type
        WdLib.gui:updateDropDownMenu(arg0_drop, "Select range:", WdLib.gui:updateItemsByHoverInfo(true, rangeRuleTypes, WD.Help.rangesInfo, updateRangeRuleMenu))
        local arg0_frame = WdLib.gui:findDropDownFrameByName(arg0_drop, rule.arg0[1])
        if arg0_frame then
            arg0_drop.selected = arg0_frame
            arg0_drop:SetText(rule.arg0[1])
        end
        arg0_drop.label:SetText("Range rule type:")
        arg0_drop:Show()
        editRangeRuleMenu(arg0_drop, rule.arg0[1], rule.arg0[2])

        -- arg1
        WdLib.gui:updateDropDownMenu(arg1_drop, "Select result event:", WdLib.gui:updateItemsByHoverInfo(true, WD.EventTypes, WD.Help.eventsInfo, updateEventConfigMenu))
        local arg1_frame = WdLib.gui:findDropDownFrameByName(arg1_drop, rule.arg1[1])
        if arg1_frame then
            arg1_drop.selected = arg1_frame
            arg1_drop:SetText(rule.arg1[1])
        end
        arg1_drop.label:SetText("Result event:")
        arg1_drop:Show()
        editEventConfigMenu(arg1_drop, rule.arg1[1], rule.arg1[2])
    elseif rule.ruleType == "RL_DEPENDENCY" then
        -- arg0
        WdLib.gui:updateDropDownMenu(arg0_drop, "Select reason event:", WdLib.gui:updateItemsByHoverInfo(true, WD.EventTypes, WD.Help.eventsInfo, updateEventConfigMenu))
        local arg0_frame = WdLib.gui:findDropDownFrameByName(arg0_drop, rule.arg0[1])
        if arg0_frame then
            arg0_drop.selected = arg0_frame
            arg0_drop:SetText(rule.arg0[1])
        end
        arg0_drop.label:SetText("Reason event:")
        arg0_drop:Show()
        editEventConfigMenu(arg0_drop, rule.arg0[1], rule.arg0[2])
        -- arg1
        WdLib.gui:updateDropDownMenu(arg1_drop, "Select result event:", WdLib.gui:updateItemsByHoverInfo(true, WD.EventTypes, WD.Help.eventsInfo, updateEventConfigMenu))
        local arg1_frame = WdLib.gui:findDropDownFrameByName(arg1_drop, rule.arg1[1])
        if arg1_frame then
            arg1_drop.selected = arg1_frame
            arg1_drop:SetText(rule.arg1[1])
        end
        arg1_drop.label:SetText("Result event:")
        arg1_drop:Show()
        editEventConfigMenu(arg1_drop, rule.arg1[1], rule.arg1[2])
        -- arg2
        WdLib.gui:showHiddenEditBox(parent, "arg2_edit", rule.timeout)
        arg2_edit.label:SetText("Timeout (in msec):")
    elseif rule.ruleType == "RL_STATISTICS" then
        -- statistic type
        WdLib.gui:updateDropDownMenu(arg0_drop, "Select statistics:", WdLib.gui:updateItemsByHoverInfo(true, statisticTypes, WD.Help.statisticInfo, updateNewRuleHiddenMenu))
        local frame = WdLib.gui:findDropDownFrameByName(arg0_drop, rule.arg0)
        if frame then
            arg0_drop.selected = frame
            arg0_drop:SetText(rule.arg0)
        end
        arg0_drop.label:SetText("Statistics type:")
        arg0_drop:Show()

        -- range rule type
        WdLib.gui:updateDropDownMenu(arg1_drop, "Select range:", WdLib.gui:updateItemsByHoverInfo(true, rangeRuleTypes, WD.Help.rangesInfo, updateRangeRuleMenu))
        local arg1_frame = WdLib.gui:findDropDownFrameByName(arg1_drop, rule.arg1[1])
        if arg1_frame then
            arg1_drop.selected = arg1_frame
            arg1_drop:SetText(rule.arg1[1])
        end
        arg1_drop.label:SetText("Range rule type:")
        arg1_drop:Show()
        editRangeRuleMenu(arg1_drop, rule.arg1[1], rule.arg1[2])

        -- arg2
        if rule.arg0 == "ST_TARGET_DAMAGE" then
            WdLib.gui:showHiddenEditBox(parent, "arg2_edit", rule.targetUnit)
            arg2_edit.label:SetText("Target unit name:")
        end
    end

    parent:Show()
end

local function updateRulesListFrame()
    if not WDRS or not WDRS.members then return end

    local maxHeight = 545
    local topLeftPosition = { x = 30, y = -51 }
    local rowsN = #WD.db.profile.statRules
    local columnsN = 5

    -- sort by journalId > points > reason
    local func = function(a, b)
        if a.journalId and b.journalId and a.journalId < b.journalId then return true
        elseif a.journalId and b.journalId and a.journalId > b.journalId then return false
        else
            return getRuleDescription(a) < getRuleDescription(b)
        end
    end
    table.sort(WD.db.profile.statRules, func)

    local function createFn(parent, row, index)
        local v = WD.db.profile.statRules[row]
        if index == 1 then
            local f = WdLib.gui:createCheckButton(parent)
            f:SetSize(parent:GetHeight() - 2, parent:GetHeight() - 2)
            f:SetPoint("TOPLEFT", parent, "TOPLEFT", 1, -1)
            f:SetChecked(v.isActive)
            f:SetScript("OnClick", function() v.isActive = not v.isActive end)
            return f
        elseif index == 2 then
            local f = WdLib.gui:addNextColumn(WDRS, parent, index, "LEFT", WD.EncounterNames[v.journalId])
            f:SetPoint("TOPLEFT", parent.column[1], "TOPRIGHT", 2, 1)
            local instanceName = WD.FindInstanceByJournalId(v.journalId)
            WdLib.gui:generateHover(f, instanceName)
            return f
        elseif index == 3 then
            local f = WdLib.gui:addNextColumn(WDRS, parent, index, "LEFT", getRuleDescription(v))
            WdLib.gui:generateSpellHover(f, getRuleDescription(v))
            return f
        elseif index == 4 then
            local f = WdLib.gui:addNextColumn(WDRS, parent, index, "CENTER", WD_BUTTON_EDIT)
            f:EnableMouse(true)
            f:SetScript("OnClick", function() editRule(v); end)
            f.t:SetColorTexture(.2, 1, .2, .5)
            return f
        elseif index == 5 then
            local f = WdLib.gui:addNextColumn(WDRS, parent, index, "CENTER", WD_BUTTON_DELETE)
            f:EnableMouse(true)
            f:SetScript("OnClick", function() table.remove(WD.db.profile.statRules, row); updateRulesListFrame(); end)
            f.t:SetColorTexture(1, .2, .2, .5)
            return f
        end
    end

    local function updateFn(frame, row, index)
        local v = WD.db.profile.statRules[row]
        if index == 1 then
            frame:SetChecked(v.isActive)
            frame:SetScript("OnClick", function() v.isActive = not v.isActive end)
        elseif index == 2 then
            frame.txt:SetText(WD.EncounterNames[v.journalId])
            local instanceName = WD.FindInstanceByJournalId(v.journalId)
            WdLib.gui:generateHover(frame, instanceName)
        elseif index == 3 then
            frame.txt:SetText(getRuleDescription(v))
            WdLib.gui:generateSpellHover(frame, getRuleDescription(v))
        elseif index == 4 then
            frame:SetScript("OnClick", function(self) editRule(v); end)
        elseif index == 5 then
        end
    end

    WdLib.gui:updateScrollableTable(WDRS, maxHeight, topLeftPosition, rowsN, columnsN, createFn, updateFn)
end

local function findEventConfigByOrigin(origin)
    local parent = WDRS.menus["new_rule"]

    local i = 1
    local menu = parent.hiddenMenus["selected_rule_"..i]
    while menu do
        if menu.origin and menu.origin == origin then
            return menu
        end
        i = i + 1
        menu = parent.hiddenMenus["selected_rule_"..i]
    end
    return nil
end

local function getEventConfigDataForSave(eventName, eventFrame)
    local args = nil
    if eventName == "EV_AURA" then
        local auraId = eventFrame.hiddenMenus["arg0_edit"]:GetText()
        if not GetSpellInfo(auraId) then
            return false, "Please set correct aura id in event config"
        end

        if not eventFrame.hiddenMenus["arg1_drop"].selected then
            return false, "Please select aura action in event config"
        end
        local auraAction = eventFrame.hiddenMenus["arg1_drop"].selected:GetText()
        args = {tonumber(auraId), auraAction}
    elseif eventName == "EV_AURA_STACKS" then
        local auraId = eventFrame.hiddenMenus["arg0_edit"]:GetText()
        if not GetSpellInfo(auraId) then
            return false, "Please set correct aura id in event config"
        end

        local stacks = eventFrame.hiddenMenus["arg1_edit"]:GetText()
        if not tonumber(stacks) or tonumber(stacks) < 0 then
            return false, "Please select correct number of stacks"
        end
        args = {tonumber(auraId), tonumber(stacks)}
    elseif eventName == "EV_DISPEL" then
        local auraId = eventFrame.hiddenMenus["arg0_edit"]:GetText()
        if not GetSpellInfo(auraId) then
            return false, "Please set correct aura id in event config"
        end
        args = {tonumber(auraId)}
    elseif eventName == "EV_CAST_START" then
        local spellId = eventFrame.hiddenMenus["arg0_edit"]:GetText()
        if not GetSpellInfo(spellId) then
            return false, "Please set correct spell id in event config"
        end
        local casterName = eventFrame.hiddenMenus["arg1_edit"]:GetText()
        if casterName:len() == 0 then
            return false, "Please specify caster name"
        end
        args = {tonumber(spellId), casterName}
    elseif eventName == "EV_CAST_INTERRUPTED" then
        local targetSpellId = eventFrame.hiddenMenus["arg0_edit"]:GetText()
        if not GetSpellInfo(targetSpellId) then
            return false, "Please set correct target spell id in event config"
        end
        local targetName = eventFrame.hiddenMenus["arg1_edit"]:GetText()
        if targetName:len() == 0 then
            return false, "Please specify target name"
        end
        args = {tonumber(targetSpellId), targetName}
    elseif eventName == "EV_CAST_END" then
        local spellId = eventFrame.hiddenMenus["arg0_edit"]:GetText()
        if not GetSpellInfo(spellId) then
            return false, "Please set correct spell id in event config"
        end
        local casterName = eventFrame.hiddenMenus["arg1_edit"]:GetText()
        if casterName:len() == 0 then
            return false, "Please specify caster name"
        end
        args = {tonumber(spellId), casterName}
    elseif eventName == "EV_DAMAGETAKEN" then
        local spellId = eventFrame.hiddenMenus["arg0_edit"]:GetText()
        if not GetSpellInfo(spellId) then
            return false, "Please set correct spell id in event config"
        end

        local amount = eventFrame.hiddenMenus["arg1_edit"]:GetText()
        if not tonumber(amount) or tonumber(amount) < 0 then
            return false, "Please select correct amount number"
        end
        args = {tonumber(spellId), tonumber(amount)}
    elseif eventName == "EV_DEATH" then
        local spellId = eventFrame.hiddenMenus["arg0_edit"]:GetText()
        if not GetSpellInfo(spellId) then
            return false, "Please set correct spell id in event config"
        end
        args = {tonumber(spellId)}
    elseif eventName == "EV_DEATH_UNIT" then
        local unitName = eventFrame.hiddenMenus["arg0_edit"]:GetText()
        if unitName:len() == 0 then
            return false, "Please specify unit name"
        end
        args = {unitName}
    else
        return false, "Unknown event: "..eventName
    end

    return args, ""
end

local function getRangeRuleData(parent, frameName)
    local args = nil
    if not parent.hiddenMenus[frameName].selected then
        return false, "Please select range rule type"
    end

    local rangeRule = parent.hiddenMenus[frameName].selected:GetText()
    if rangeRule == "RT_AURA_EXISTS" then           -- arg0=aura_id
        local auraId = tonumber(parent.hiddenMenus["range_menu"].hiddenMenus["arg0_edit"]:GetText())
        if not GetSpellInfo(auraId) then
            return false, "Please set correct aura id in range rule type"
        end

        args = {rangeRule, tonumber(auraId)}
    elseif rangeRule == "RT_AURA_NOT_EXISTS" then   -- arg0=aura_id
        local auraId = tonumber(parent.hiddenMenus["range_menu"].hiddenMenus["arg0_edit"]:GetText())
        if not GetSpellInfo(auraId) then
            return false, "Please set correct aura id in range rule type"
        end

        args = {rangeRule, tonumber(auraId)}
    elseif rangeRule == "RT_UNIT_CASTING" then      -- arg0=target_spell_id
        local spellId = tonumber(parent.hiddenMenus["range_menu"].hiddenMenus["arg0_edit"]:GetText())
        if not GetSpellInfo(spellId) then
            return false, "Please set correct target spell id in range rule type"
        end

        args = {rangeRule, tonumber(spellId)}
    elseif rangeRule == "RT_CUSTOM" then            -- arg0=event_start,     arg1=event_end
        local function getEventData(frameName)
            local frame = parent.hiddenMenus["range_menu"].hiddenMenus[frameName]
            if not frame.selected then
                return nil
            end
            local eventName = frame.selected:GetText()
            local eventFrame = findEventConfigByOrigin(frame)
            local data, errorMsg = getEventConfigDataForSave(eventName, eventFrame)
            return {eventName, data, errorMsg}
        end
        local startData = getEventData("arg0_drop")
        if not startData then
            return false, "Please select start event"
        elseif startData[2] == false then return false, startData[3]
        end
        local endData = getEventData("arg1_drop")
        if not endData then
            return false, "Please select end event"
        elseif endData[2] == false then return false, endData[3]
        end
        args = { rangeRule, { startEvent = startData, endEvent = endData } }
    else
        return false, "Unsupported range rule type selected: "..rangeRule
    end

    return args, ""
end

local function previewRule()
    local parent = WDRS.menus["new_rule"]
    if not parent.menus["encounters"].selected then
        return false, "Please select encounter"
    end
    if not parent.menus["rule_types"].selected then
        return false, "Please select rule type"
    end

    local rule = {}
    rule.journalId = parent.menus["encounters"].selected.data.journalId
    rule.ruleType = parent.menus["rule_types"].selected:GetText()

    if rule.ruleType == "RL_QUALITY" then
        if not parent.hiddenMenus["arg0_drop"].selected then
            return false, "Please select quality type"
        end
        local qualityType = parent.hiddenMenus["arg0_drop"].selected:GetText()
        if qualityType == "QT_INTERRUPTS" then
            local targetSpellId = tonumber(parent.hiddenMenus["range_menu"].hiddenMenus["arg0_edit"]:GetText())
            if not GetSpellInfo(targetSpellId) then
                return false, "Please set correct target spell id"
            end
            local qualityPercent = tonumber(parent.hiddenMenus["arg2_edit"]:GetText())
            if not qualityPercent then
                return false, "Please specify quality percent"
            end

            rule.arg0 = qualityType
            rule.arg1 = tonumber(targetSpellId)
            rule.qualityPercent = qualityPercent
        elseif qualityType == "QT_DISPELS" then
            local auraId = tonumber(parent.hiddenMenus["range_menu"].hiddenMenus["arg0_edit"]:GetText())
            if not GetSpellInfo(auraId) then
                return false, "Please set correct aura id"
            end
            local time1 = tonumber(parent.hiddenMenus["arg2_edit"]:GetText())
            if not time1 or time1 < 0 then
                return false, "Please specify correct early dispel time"
            end
            local time2 = tonumber(parent.hiddenMenus["arg3_edit"]:GetText())
            if not time2 or time2 < 0 then
                return false, "Please specify correct late dispel time"
            end
            if time2 > 0 and time1 > time2 then
                return false, "Early dispel time cannot be greater than late dispel time"
            elseif time1 == 0 and time2 == 0 then
                return false, "Incorrect time range. Must be at least one value > 0"
            end

            rule.arg0 = qualityType
            rule.arg1 = tonumber(auraId)
            rule.earlyDispel = time1
            rule.lateDispel = time2
        else
            return false, "Unsupported quality type selected: "..qualityType
        end
    elseif rule.ruleType == "RL_RANGE_RULE" then        -- arg0=range_rule_type, arg1=event_result                  checks if event_result applied to unit during specified events range
        -- arg0
        local args, errorMsg = getRangeRuleData(parent, "arg0_drop")
        if args == false then
            return false, errorMsg
        else
            rule.arg0 = args
        end

        -- arg1
        if not parent.hiddenMenus["arg1_drop"].selected then
            return false, "Please select result event"
        end
        local eventName = parent.hiddenMenus["arg1_drop"].selected:GetText()
        local eventFrame = findEventConfigByOrigin(parent.hiddenMenus["arg1_drop"])
        local data, errorMsg = getEventConfigDataForSave(eventName, eventFrame)
        if data == false then
            return false, errorMsg
        else
            rule.arg1 = {eventName, data}
        end
    elseif rule.ruleType == "RL_DEPENDENCY" then        -- arg0=event_reason,    arg1=event_result,   arg2=timeout  checks if event_result occured (or not) after event_reason during specified time
        local function getEventData(frameName)
            local frame = parent.hiddenMenus[frameName]
            if not frame.selected then
                return nil
            end
            local eventName = frame.selected:GetText()
            local eventFrame = findEventConfigByOrigin(frame)
            local data, errorMsg = getEventConfigDataForSave(eventName, eventFrame)
            return {eventName, data, errorMsg}
        end

        -- arg0
        local reasonData = getEventData("arg0_drop")
        if not reasonData then
            return false, "Please select reason event"
        elseif reasonData[2] == false then return false
        end
        rule.arg0 = reasonData

        -- arg1
        local resultData = getEventData("arg1_drop")
        if not resultData then
            return false, "Please select result event"
        elseif resultData[2] == false then return false, resultData[3]
        end
        rule.arg1 = resultData

        --arg2
        local timeout = tonumber(parent.hiddenMenus["arg2_edit"]:GetText())
        if not timeout or timeout == 0 then
            return false, "Please specify correct timeout"
        end
        rule.timeout = tonumber(timeout)
    elseif rule.ruleType == "RL_STATISTICS" then
        if not parent.hiddenMenus["arg0_drop"].selected then
            return false, "Please select statistic type"
        end

        -- arg0
        local statisticType = parent.hiddenMenus["arg0_drop"].selected:GetText()
        -- arg1
        local args, errorMsg = getRangeRuleData(parent, "arg1_drop")
        if args == false then
            return false, errorMsg
        end
        -- arg2
        if statisticType == "ST_TARGET_DAMAGE" then
            local targetUnit = parent.hiddenMenus["arg2_edit"]:GetText()
            if targetUnit:len() == 0 then
                return false, "Please specify correct target name"
            end
            rule.targetUnit = targetUnit
        elseif statisticType == "ST_TARGET_INTERRUPTS" or statisticType == "ST_SOURCE_INTERRUPTS" then
            return false, "Not implemented yet:"..statisticType
        end

        rule.arg0 = statisticType
        rule.arg1 = args
    else
        return false, "Not implemented yet:"..rule.ruleType
    end

    WDRS.menus["new_rule"].menus["preview"]:SetText(getRuleDescription(rule))

    return rule, ""
end

local function saveRule()
    local rule, errorMsg = previewRule()
    if rule == false then
        WDRS.menus["new_rule"].menus["preview"]:SetText("|cffff0000"..errorMsg.."|r")
        return false
    else
        WDRS.menus["new_rule"].menus["preview"]:SetText("")
    end

    local duplicate = findDuplicate(rule)
    if not duplicate then
        WD.db.profile.statRules[#WD.db.profile.statRules+1] = rule
    else
        print('Rule has been updated')
        if rule.qualityPercent then duplicate.qualityPercent = rule.qualityPercent end
        if rule.earlyDispel then duplicate.earlyDispel = rule.earlyDispel end
        if rule.lateDispel then duplicate.lateDispel = rule.lateDispel end
        if rule.timeout then duplicate.timeout = rule.timeout end
        if rule.targetUnit then duplicate.targetUnit = rule.targetUnit end
    end

    updateRulesListFrame()
    return true
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
        WdLib.gui:updateDropDownMenu(arg0_drop, "Select range:", WdLib.gui:updateItemsByHoverInfo(true, rangeRuleTypes, WD.Help.rangesInfo, updateRangeRuleMenu))
        arg0_drop.label:SetText("Range rule type:")
        arg0_drop:Show()
        -- arg1
        WdLib.gui:updateDropDownMenu(arg1_drop, "Select result event:", WdLib.gui:updateItemsByHoverInfo(true, WD.EventTypes, WD.Help.eventsInfo, updateEventConfigMenu))
        arg1_drop.label:SetText("Result event:")
        arg1_drop:Show()
    elseif rule == "RL_DEPENDENCY" then
        -- arg0
        WdLib.gui:updateDropDownMenu(arg0_drop, "Select reason event:", WdLib.gui:updateItemsByHoverInfo(true, WD.EventTypes, WD.Help.eventsInfo, updateEventConfigMenu))
        arg0_drop.label:SetText("Reason event:")
        arg0_drop:Show()
        -- arg1
        WdLib.gui:updateDropDownMenu(arg1_drop, "Select result event:", WdLib.gui:updateItemsByHoverInfo(true, WD.EventTypes, WD.Help.eventsInfo, updateEventConfigMenu))
        arg1_drop.label:SetText("Result event:")
        arg1_drop:Show()
        -- arg2
        arg2_edit.label:SetText("Timeout (in msec):")
        WdLib.gui:showHiddenEditBox(parent, "arg2_edit", "1000")
    elseif rule == "RL_STATISTICS" then
        -- arg0
        WdLib.gui:updateDropDownMenu(arg0_drop, "Select statistics:", WdLib.gui:updateItemsByHoverInfo(true, statisticTypes, WD.Help.statisticInfo, updateNewRuleHiddenMenu))
        arg0_drop.label:SetText("Statistics mode:")
        arg0_drop:Show()
    elseif rule == "RL_QUALITY" then
        -- arg0
        WdLib.gui:updateDropDownMenu(arg0_drop, "Select quality:", WdLib.gui:convertTypesToItems(qualityTypes, updateNewRuleHiddenMenu))
        arg0_drop.label:SetText("Quality type:")
        arg0_drop:Show()
    end

    for k,v in pairs(parent.hiddenMenus) do
        if string.match(k, "selected_rule_") then
            v:Hide()
        end
    end
end

local function initSelectedRuleMenu()
    local function updateColorByIndex(frame, index)
        if index == 1 then
            frame.color = {.15, 0, 0, 1}
            frame:SetColorTexture(unpack(frame.color))
        elseif index == 2 then
            frame.color = {0, .15, 0, 1}
            frame:SetColorTexture(unpack(frame.color))
        elseif index == 3 then
            frame.color = {.15, .15, 0, 1}
            frame:SetColorTexture(unpack(frame.color))
        elseif index == 4 then
            frame.color = {.15, .15, .15, 1}
            frame:SetColorTexture(unpack(frame.color))
        else
            frame.color = {0, 0, 0, 1}
            frame:SetColorTexture(unpack(frame.color))
        end
    end

    local parent = WDRS.menus["new_rule"]
    local maxV = 3
    --local m = math.floor(maxV / 2) + 1
    for i=1,maxV do
        local r = WdLib.gui:createRuleWindow(parent)
        r:SetFrameStrata("FULLSCREEN")
        updateColorByIndex(r.bg, i)

        if i == 1 then
            r:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -1, -1)
        --[[elseif i == m then
            r:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 1, 0)]]
        else
            r:SetPoint("TOPRIGHT", parent.hiddenMenus["selected_rule_"..(i-1)], "BOTTOMRIGHT", 0, -1)
        end

        r:SetScript("OnHide", function(self)
            if self.origin and self.origin.t then
                self.origin.t:SetColorTexture(.2,.2,.2,1)
            end
            self.origin = nil
        end)

        parent.hiddenMenus["selected_rule_"..i] = r
    end
end

local function initRangeRuleMenu()
    local parent = WDRS.menus["new_rule"]
    local r = CreateFrame("Frame", nil, parent)
    r.hiddenMenus = {}

    local xSize = 150

    -- label
    r.label = WdLib.gui:createFontDefault(r, "CENTER", "")
    r.label:SetSize(xSize, 20)
    r.label:SetPoint("TOPRIGHT", r, "TOPRIGHT", -1, -1)

    -- arg0: dropdown or editbox
    r.hiddenMenus["arg0_drop"] = WdLib.gui:createDropDownMenu(r)
    r.hiddenMenus["arg0_drop"].txt:SetJustifyH("CENTER")
    r.hiddenMenus["arg0_drop"]:SetSize(xSize, 20)
    r.hiddenMenus["arg0_drop"]:SetPoint("TOPRIGHT", r.label, "BOTTOMRIGHT", 0, -1)
    r.hiddenMenus["arg0_drop"]:Hide()

    r.hiddenMenus["arg0_edit"] = WdLib.gui:createEditBox(r)
    r.hiddenMenus["arg0_edit"]:SetSize(xSize, 20)
    r.hiddenMenus["arg0_edit"]:SetPoint("TOPRIGHT", r.label, "BOTTOMRIGHT", 0, -1)
    r.hiddenMenus["arg0_edit"]:Hide()

    -- arg1: dropdown
    r.hiddenMenus["arg1_drop"] = WdLib.gui:createDropDownMenu(r)
    r.hiddenMenus["arg1_drop"].txt:SetJustifyH("CENTER")
    r.hiddenMenus["arg1_drop"]:SetSize(xSize, 20)
    r.hiddenMenus["arg1_drop"]:SetPoint("TOPRIGHT", r.hiddenMenus["arg0_drop"], "BOTTOMRIGHT", 0, -1)
    r.hiddenMenus["arg1_drop"]:Hide()

    r:SetScript("OnHide", function(self)
        if self.origin and self.origin.t then
            self.origin.t:SetColorTexture(.2,.2,.2,1)
        end
        self.origin = nil

        for _,v in pairs(r.hiddenMenus)
            do v:Hide()
        end
    end)

    r:EnableMouse(true)
    r:SetPoint("TOPLEFT", parent, "TOPLEFT", 1, -1)
    r:SetSize(xSize + 2, 3 * 21 + 1)
    r.bg = WdLib.gui:createColorTexture(r, "ARTWORK", 0, 0, .15, 1)
    r.bg.color = {0, 0, .15, 1}
    r.bg:SetAllPoints()

    r:Hide()

    parent.hiddenMenus["range_menu"] = r
end

local function initNewRuleWindow()
    WDRS.menus["new_rule"] = CreateFrame("Frame", nil, WDRS)
    local r = WDRS.menus["new_rule"]
    r:SetFrameStrata("DIALOG")
    r.menus = {}
    r.hiddenMenus = {}
    r.buttons = {}

    local xSize = 200
    local x = 275
    local totalWidth = xSize + x

    -- preview
    r.menus["preview"] = WdLib.gui:createFontDefault(r, "LEFT", "")
    r.menus["preview"]:SetSize(700, 20)
    r.menus["preview"]:SetPoint("BOTTOMLEFT", r, "BOTTOMLEFT", 5, -2)
    -- encounters menu
    r.menus["encounters"] = WdLib.gui:createDropDownMenu(r, "Select encounter", WD:CreateTierList())
    r.menus["encounters"]:SetSize(xSize, 20)
    r.menus["encounters"]:SetPoint("TOPLEFT", r, "TOPLEFT", x, -1)
    r.menus["encounters"].label = WdLib.gui:createFontDefault(r.menus["encounters"], "RIGHT", "Encounter:")
    r.menus["encounters"].label:SetSize(x - 5, 20)
    r.menus["encounters"].label:SetPoint("TOPLEFT", r, "TOPLEFT", 1, -1)
    -- tracking rules menu
    r.menus["rule_types"] = WdLib.gui:createDropDownMenu(r, "Select rule type", WdLib.gui:updateItemsByHoverInfo(true, trackingRuleTypes, WD.Help.rulesInfo, updateNewRuleMenuByTrackingRules))
    r.menus["rule_types"]:SetSize(xSize, 20)
    r.menus["rule_types"]:SetPoint("TOPLEFT", r.menus["encounters"], "BOTTOMLEFT", 0, -1)
    r.menus["rule_types"].label = WdLib.gui:createFontDefault(r.menus["rule_types"], "RIGHT", "Rule:")
    r.menus["rule_types"].label:SetSize(x - 5, 20)
    r.menus["rule_types"].label:SetPoint("TOPLEFT", r.menus["encounters"].label, "BOTTOMLEFT", 0, -1)

    -- arg0: dropdown or editbox
    r.hiddenMenus["arg0_drop"] = WdLib.gui:createDropDownMenu(r)
    r.hiddenMenus["arg0_drop"].txt:SetJustifyH("CENTER")
    r.hiddenMenus["arg0_drop"]:SetSize(xSize, 20)
    r.hiddenMenus["arg0_drop"]:SetPoint("TOPLEFT", r.menus["rule_types"], "BOTTOMLEFT", 0, -1)
    r.hiddenMenus["arg0_drop"].label = WdLib.gui:createFontDefault(r.hiddenMenus["arg0_drop"], "RIGHT", "Statistics type:")
    r.hiddenMenus["arg0_drop"].label:SetSize(x - 5, 20)
    r.hiddenMenus["arg0_drop"].label:SetPoint("TOPLEFT", r.menus["rule_types"].label, "BOTTOMLEFT", 0, -1)
    r.hiddenMenus["arg0_drop"]:Hide()

    r.hiddenMenus["arg0_edit"] = WdLib.gui:createEditBox(r)
    r.hiddenMenus["arg0_edit"]:SetSize(xSize, 20)
    r.hiddenMenus["arg0_edit"]:SetPoint("TOPLEFT", r.menus["rule_types"], "BOTTOMLEFT", 0, -1)
    r.hiddenMenus["arg0_edit"].label = WdLib.gui:createFontDefault(r.hiddenMenus["arg0_edit"], "RIGHT", "target spell id:")
    r.hiddenMenus["arg0_edit"].label:SetSize(x - 5, 20)
    r.hiddenMenus["arg0_edit"].label:SetPoint("TOPLEFT", r.menus["rule_types"].label, "BOTTOMLEFT", 0, -1)
    r.hiddenMenus["arg0_edit"]:Hide()

    -- arg1: dropdown or editbox
    r.hiddenMenus["arg1_drop"] = WdLib.gui:createDropDownMenu(r)
    r.hiddenMenus["arg1_drop"].txt:SetJustifyH("CENTER")
    r.hiddenMenus["arg1_drop"]:SetSize(xSize, 20)
    r.hiddenMenus["arg1_drop"]:SetPoint("TOPLEFT", r.hiddenMenus["arg0_drop"], "BOTTOMLEFT", 0, -1)
    r.hiddenMenus["arg1_drop"].label = WdLib.gui:createFontDefault(r.hiddenMenus["arg1_drop"], "RIGHT", "")
    r.hiddenMenus["arg1_drop"].label:SetSize(x - 5, 20)
    r.hiddenMenus["arg1_drop"].label:SetPoint("TOPLEFT", r.hiddenMenus["arg0_drop"].label, "BOTTOMLEFT", 0, -1)
    r.hiddenMenus["arg1_drop"]:Hide()

    r.hiddenMenus["arg1_edit"] = WdLib.gui:createEditBox(r)
    r.hiddenMenus["arg1_edit"]:SetSize(xSize, 20)
    r.hiddenMenus["arg1_edit"]:SetPoint("TOPLEFT", r.hiddenMenus["arg0_drop"], "BOTTOMLEFT", 0, -1)
    r.hiddenMenus["arg1_edit"].label = WdLib.gui:createFontDefault(r.hiddenMenus["arg1_edit"], "RIGHT", "quality percent:")
    r.hiddenMenus["arg1_edit"].label:SetSize(x - 5, 20)
    r.hiddenMenus["arg1_edit"].label:SetPoint("TOPLEFT", r.hiddenMenus["arg0_drop"].label, "BOTTOMLEFT", 0, -1)
    r.hiddenMenus["arg1_edit"]:Hide()

    -- arg2: dropdown or editbox
    r.hiddenMenus["arg2_drop"] = WdLib.gui:createDropDownMenu(r)
    r.hiddenMenus["arg2_drop"].txt:SetJustifyH("CENTER")
    r.hiddenMenus["arg2_drop"]:SetSize(xSize, 20)
    r.hiddenMenus["arg2_drop"]:SetPoint("TOPLEFT", r.hiddenMenus["arg1_drop"], "BOTTOMLEFT", 0, -1)
    r.hiddenMenus["arg2_drop"].label = WdLib.gui:createFontDefault(r.hiddenMenus["arg2_drop"], "RIGHT", "Stop event:")
    r.hiddenMenus["arg2_drop"].label:SetSize(x - 5, 20)
    r.hiddenMenus["arg2_drop"].label:SetPoint("TOPLEFT", r.hiddenMenus["arg1_drop"].label, "BOTTOMLEFT", 0, -1)
    r.hiddenMenus["arg2_drop"]:Hide()

    r.hiddenMenus["arg2_edit"] = WdLib.gui:createEditBox(r)
    r.hiddenMenus["arg2_edit"]:SetSize(xSize, 20)
    r.hiddenMenus["arg2_edit"]:SetPoint("TOPLEFT", r.hiddenMenus["arg1_drop"], "BOTTOMLEFT", 0, -1)
    r.hiddenMenus["arg2_edit"].label = WdLib.gui:createFontDefault(r.hiddenMenus["arg2_edit"], "RIGHT", "time to reset (in msec):")
    r.hiddenMenus["arg2_edit"].label:SetSize(x - 5, 20)
    r.hiddenMenus["arg2_edit"].label:SetPoint("TOPLEFT", r.hiddenMenus["arg1_drop"].label, "BOTTOMLEFT", 0, -1)
    r.hiddenMenus["arg2_edit"]:Hide()

    -- arg3: editbox
    r.hiddenMenus["arg3_edit"] = WdLib.gui:createEditBox(r)
    r.hiddenMenus["arg3_edit"]:SetSize(xSize, 20)
    r.hiddenMenus["arg3_edit"]:SetPoint("TOPLEFT", r.hiddenMenus["arg2_drop"], "BOTTOMLEFT", 0, -1)
    r.hiddenMenus["arg3_edit"].label = WdLib.gui:createFontDefault(r.hiddenMenus["arg3_edit"], "RIGHT", "")
    r.hiddenMenus["arg3_edit"].label:SetSize(x - 5, 20)
    r.hiddenMenus["arg3_edit"].label:SetPoint("TOPLEFT", r.hiddenMenus["arg2_drop"].label, "BOTTOMLEFT", 0, -1)
    r.hiddenMenus["arg3_edit"]:Hide()

    r.buttons["save"] = WdLib.gui:createButton(r)
    r.buttons["save"]:SetPoint("TOPLEFT", r.hiddenMenus["arg3_edit"], "BOTTOMLEFT", 1, -2)
    r.buttons["save"]:SetSize(xSize / 2 - 1, 20)
    r.buttons["save"]:SetScript("OnClick", function() local result = saveRule() if result == true then r:Hide() end end)
    r.buttons["save"].t:SetColorTexture(.2, .4, .2, 1)
    r.buttons["save"].txt = WdLib.gui:createFont(r.buttons["save"], "CENTER", "Save")
    r.buttons["save"].txt:SetAllPoints()

    r.buttons["cancel"] = WdLib.gui:createButton(r)
    r.buttons["cancel"]:SetPoint("TOPLEFT", r.buttons["save"], "TOPRIGHT", 1, 0)
    r.buttons["cancel"]:SetSize(xSize / 2 - 2, 20)
    r.buttons["cancel"]:SetScript("OnClick", function() r:Hide() end)
    r.buttons["cancel"].t:SetColorTexture(.4, .2, .2, 1)
    r.buttons["cancel"].txt = WdLib.gui:createFont(r.buttons["cancel"], "CENTER", "Cancel")
    r.buttons["cancel"].txt:SetAllPoints()

    r.buttons["preview"] = WdLib.gui:createButton(r)
    r.buttons["preview"]:SetPoint("TOPRIGHT", r.buttons["save"], "TOPLEFT", -1, 0)
    r.buttons["preview"]:SetSize(xSize / 2 - 2, 20)
    r.buttons["preview"]:SetScript("OnClick", function() local result, errorMsg = previewRule() if result == false then r.menus["preview"]:SetText("|cffff0000"..errorMsg.."|r") end end)
    r.buttons["preview"].txt = WdLib.gui:createFont(r.buttons["preview"], "CENTER", "Preview")
    r.buttons["preview"].txt:SetAllPoints()

    r:EnableMouse(true)
    r:SetPoint("BOTTOMLEFT", WDRS, 2, 2)
    r:SetSize(700, 230)
    r:SetScript("OnHide", function() for _,v in pairs(r.hiddenMenus) do v:Hide() end r.menus["preview"]:SetText("") end)

    r.bg = WdLib.gui:createColorTexture(r, "ARTWORK", 0, 0, 0, .9)
    r.bg:SetAllPoints()

    initSelectedRuleMenu()
    initRangeRuleMenu()

    r:Hide()
end

local function onMenuClick(menu)
    if not WDRS.menus[menu] then return end
    local m = WDRS.menus[menu]
    if m:IsVisible() then
        if m.selected then
            m.selected = nil
            m:Hide()
            m:Show()
        else
            m:Hide()
        end
    else
        m:Show()
    end

    for k,v in pairs(WDRS.menus) do
        if k ~= menu then v:Hide() end
    end
end

function WDRulesModule:init(parent, yOffset)
    WD.Module.init(self, WD_BUTTON_TRACKING_RULES_MODULE, parent, yOffset)

    WDRS = self.frame

    WDRS.menus = {}
    WDRS.buttons = {}
    WDRS.members = {}

    -- new rule button
    WDRS.buttons["add_rule"] = WdLib.gui:createButton(WDRS)
    WDRS.buttons["add_rule"]:SetPoint("TOPLEFT", WDRS, "TOPLEFT", 1, -5)
    WDRS.buttons["add_rule"]:SetSize(125, 20)
    WDRS.buttons["add_rule"]:SetScript("OnClick", function() onMenuClick("new_rule") end)
    WDRS.buttons["add_rule"].txt = WdLib.gui:createFont(WDRS.buttons["add_rule"], "CENTER", WD_BUTTON_NEW_RULE)
    WDRS.buttons["add_rule"].txt:SetAllPoints()

    -- headers
    local x, y = 1, -30
    local height = 20
    WDRS.headers = {}
    local h = WdLib.gui:createTableHeader(WDRS, "", x, y, height, height)
    table.insert(WDRS.headers, h)
    h = WdLib.gui:createTableHeader(WDRS, WD_BUTTON_ENCOUNTER, x + height + 1, y, 150, height)
    table.insert(WDRS.headers, h)
    h = WdLib.gui:createTableHeaderNext(WDRS, h, WD_BUTTON_REASON, 750, height)
    table.insert(WDRS.headers, h)
    h = WdLib.gui:createTableHeaderNext(WDRS, h, "", 50, height)
    table.insert(WDRS.headers, h)
    h = WdLib.gui:createTableHeaderNext(WDRS, h, "", 50, height)
    table.insert(WDRS.headers, h)
    --[[h = WdLib.gui:createTableHeaderNext(WDRS, h, "", 50, 20)
    table.insert(WDRS.headers, h)
    h = WdLib.gui:createTableHeaderNext(WDRS, h, "", 70, 20)
    table.insert(WDRS.headers, h)]]

    initNewRuleWindow()
    updateRulesListFrame()

    function WDRS:OnUpdate()
        updateRulesListFrame()
    end
end

function WD.GetRangeRuleDescription(ruleName, ...)
    local args = {...}
    if ruleName == "RT_AURA_EXISTS" then
        return string.format(WD_TRACKER_RT_AURA_EXISTS_DESC, WdLib.gui:getSpellLinkByIdWithTexture(args[1]))
    elseif ruleName == "RT_AURA_NOT_EXISTS" then
        return string.format(WD_TRACKER_RT_AURA_NOT_EXISTS_DESC, WdLib.gui:getSpellLinkByIdWithTexture(args[1]))
    elseif ruleName == "RT_UNIT_CASTING" then
        return string.format(WD_TRACKER_RT_UNIT_CASTING_DESC, WdLib.gui:getSpellLinkByIdWithTexture(args[1]))
    elseif ruleName == "RT_CUSTOM" then
        local startEvent, endEvent = args[1][1], args[1][2]
        local startEventMsg = WD.GetEventDescription(startEvent[1], startEvent[2], startEvent[3])
        local endEventMsg = WD.GetEventDescription(endEvent[1], endEvent[2], endEvent[3])
        return string.format(WD_TRACKER_RT_CUSTOM_DESC, startEventMsg, endEventMsg)
    end
    return ruleName..": not yet implemented"
end

WD.RulesModule = WDRulesModule