
local WDTS = nil

local POPUP_MAX_SPELLS = 25

local function log(data)
    --if WD.DebugEnabled ~= true then return end
    if type(data) == "table" then
        print(WdLib:table_tostring(data))
    else
        print(data or "nil")
    end
end

local ruleTypes = {
    "TOTAL_DONE",
    "TOTAL_TAKEN",
}

local function getCurrentFilter()
    local ruleType = WD.db.profile.tracker.selectedRule
    if ruleType == "TOTAL_DONE" then
        return "done"
    elseif ruleType == "TOTAL_TAKEN" then
        return "taken"
    end
    print("Unknown rule type:"..ruleType)
    return nil
end

local function getPopupLabelByMode(mode)
    local ruleType = WD.db.profile.tracker.selectedRule
    if ruleType == "TOTAL_DONE" then
        if mode == "heal" then return "Total healing done by %s" end
        if mode == "dmg" then return "Total damage done by %s" end
    elseif ruleType == "TOTAL_TAKEN" then
        if mode == "heal" then return "Total healing taken by %s" end
        if mode == "dmg" then return "Total damage taken by %s" end
    end
    print("Unknown rule type:"..ruleType)
    return nil
end

local function getTablesNameByRule(mode, rule)
    if mode == "heal" then
        if rule == "done" then
            return {"healDone", "overhealDone"}
        elseif rule == "taken" then
            return {"healTaken", "overhealTaken"}
        elseif rule == "range" then
            print("Not implemented yet")
        end
    elseif mode == "dmg" then
        if rule == "done" then
            return {"dmgDone", "overdmgDone"}
        elseif rule == "taken" then
            return {"dmgTaken", "overdmgTaken"}
        elseif rule == "range" then
            print("Not implemented yet")
        end
    end
    return nil
end

local function findNpc(guid)
    if not WD.db.profile.tracker or not WD.db.profile.tracker.selected then return nil end
    local t = WD.db.profile.tracker[WD.db.profile.tracker.selected]
    if not guid then return nil end
    local npcId = WdLib:getNpcId(guid)
    local holder = t.npc[npcId]
    local index = WdLib:findEntityIndex(holder, guid)
    if index then return holder[index] end
    return nil
end

local function findPet(guid)
    if not WD.db.profile.tracker or not WD.db.profile.tracker.selected then return nil end
    local t = WD.db.profile.tracker[WD.db.profile.tracker.selected]
    if not guid then return nil end
    for parentGuid,infoByNpcId in pairs(t.pets) do
        for npcId,infoByGuid in pairs(infoByNpcId) do
            local index = WdLib:findEntityIndex(infoByGuid, guid)
            if index then return infoByGuid[index] end
        end
    end
    return nil
end

local function findPlayer(guid)
    if not WD.db.profile.tracker or not WD.db.profile.tracker.selected then return nil end
    local t = WD.db.profile.tracker[WD.db.profile.tracker.selected]
    return t.players[guid]
end

local function findEntityByGUID(guid)
    local result = findPlayer(guid)
    if result then return result end
    result = findPet(guid)
    if result then return result end
    result = findNpc(guid)
    if result then return result end
    return nil
end

local function generateSpellChart(data)
    local function getSpellTypeByEvent(event)
        if event:match("PERIODIC") then
            if event:match("HEAL") then return "(HOT)" end
            if event:match("DAMAGE") then return "(DOT)" end
        end
        if event:match("ABSORB") then
            return "(ABSORB)"
        end
        if event:match("SHIELD") then
            return "(REFLECT)"
        end
        return nil
    end

    local function createSpellRow(chart, event, spellId, amount, petName)
        if amount > 0 then
            if spellId == ACTION_SWING then
                spellId = 260421
            end
            local t = {}
            t.index = #chart+1
            t.id = spellId
            local spellType = getSpellTypeByEvent(event)
            if spellType and tonumber(spellId) then
                t.spellName = GetSpellInfo(spellId).." "..spellType
            elseif spellType then
                t.spellName = " |cffffffff"..spellId.." "..spellType.."|r"
            end

            if petName then
                if t.spellName then
                    t.spellName = t.spellName.." |cffffffff("..petName..")|r"
                elseif tonumber(spellId) then
                    t.spellName = GetSpellInfo(spellId).." |cffffffff("..petName..")|r"
                else
                    t.spellName = " |cffffffff"..spellId.." ".." ("..petName..")|r"
                end
            end

            t.value = amount
            if data.total > 0 then
                t.percent = amount * 100 / data.total
            else
                t.percent = 0
            end
            chart[#chart+1] = t
        end
    end

    local chart = {}
    if not data then return chart end
    for spellId,spellData in pairs(data.spells) do
        if type(spellData) == "table" then
            for event,amount in pairs(spellData) do
                createSpellRow(chart, event, spellId, amount)
            end
        end
    end
    if data.pet then
        for spellId,spellData in pairs(data.pet.spells) do
            for petName,dataByName in pairs(spellData) do
                if type(dataByName) == "table" then
                    for event,amount in pairs(dataByName) do
                        createSpellRow(chart, event, spellId, amount, petName)
                    end
                end
            end
        end
    end

    local func = function(a, b)
        if a.value > b.value then
            return true
        elseif a.value < b.value then
            return false
        end
        return a.index > b.index
    end
    table.sort(chart, func)

    return chart
end

local function preparePetSpells(spellInfo, data)
    for petSpellId,petSpellData in pairs(data) do
        if type(petSpellData) == "table" then
            for petName,dataByName in pairs(petSpellData) do
                for event,eventData in pairs(dataByName) do
                    if type(eventData) == "table" then
                        if not spellInfo.pet then spellInfo.pet = {spells={},total=0} end
                        local t = spellInfo.pet.spells
                        if not t[petSpellId] then t[petSpellId] = {} end
                        if not t[petSpellId][petName] then t[petSpellId][petName] = {} end
                        if not t[petSpellId][petName][event] then t[petSpellId][petName][event] = 0 end
                        t[petSpellId][petName][event] = t[petSpellId][petName][event] + eventData.amount
                    end
                end
            end
        end
    end
end

local function prepareDataForSpellChart(tableData)
    local spellInfo = {spells={},total=0}
    if not tableData then return spellInfo end
    for spellId,spellData in pairs(tableData) do
        if type(spellData) == "table" then
            if spellId == "pet" then
                preparePetSpells(spellInfo, spellData)
            else
                for event,eventData in pairs(spellData) do
                    if type(eventData) == "table" then
                        if not spellInfo.spells[spellId] then spellInfo.spells[spellId] = {} end
                        if not spellInfo.spells[spellId][event] then spellInfo.spells[spellId][event] = 0 end
                        spellInfo.spells[spellId][event] = spellInfo.spells[spellId][event] + eventData.amount
                    end
                end
            end
        end
    end
    spellInfo.total = spellInfo.total + tableData.total
    --log(spellInfo)
    return spellInfo
end

local function prepareTotalDataForSpellChart(unit, mode)
    local rule = getCurrentFilter()
    local tNames = getTablesNameByRule(mode, rule)
    local spellInfo = {spells={},total=0}
    for _,guidData in pairs(unit.stats) do
        if type(guidData) == "table" then
            for tableName,tableData in pairs(guidData) do
                if tableName == tNames[1] then
                    for spellId,spellData in pairs(tableData) do
                        if type(spellData) == "table" then
                            if spellId == "pet" then
                                preparePetSpells(spellInfo, spellData)
                            else
                                for event,eventData in pairs(spellData) do
                                    if type(eventData) == "table" then
                                        if not spellInfo.spells[spellId] then spellInfo.spells[spellId] = {} end
                                        if not spellInfo.spells[spellId][event] then spellInfo.spells[spellId][event] = 0 end
                                        spellInfo.spells[spellId][event] = spellInfo.spells[spellId][event] + eventData.amount
                                    end
                                end
                            end
                        end
                    end
                    spellInfo.total = spellInfo.total + tableData.total
                end
            end
        end
    end
    --log(spellInfo)
    return spellInfo
end

local function showPopup(parent, label, data)
    local chart = generateSpellChart(data)
    if #chart == 0 then return end
    WDTS.popup:SetPoint("TOPLEFT", parent, "TOPRIGHT", 0, 0)
    WDTS.popup:SetHeight((math.min(#chart, POPUP_MAX_SPELLS) + 1) * 21 + 1)

    for _,v in pairs(WDTS.popup.members) do
        v:Hide()
    end

    if label then
        WDTS.popup.label:SetText(label)
    end

    local total = chart[1].percent
    for i=1,math.min(#chart, POPUP_MAX_SPELLS) do
        WDTS.popup.members[i]:SetValue(chart[i].percent * 100 / total)
        local spellId = chart[i].id
        if chart[i].spellName and tonumber(spellId) then
            spellId = WdLib:makeSpellLinkWithTexture(spellId, chart[i].spellName)
        elseif chart[i].spellName then
            spellId = chart[i].spellName
        elseif tonumber(spellId) then
            spellId = WdLib:getSpellLinkByIdWithTexture(spellId)
        else
            spellId = " |cffffffff"..spellId.."|r"
        end
        WDTS.popup.members[i].leftTxt:SetText(i..spellId)
        WDTS.popup.members[i].rightTxt:SetText(WdLib:shortNumber(chart[i].value).." ("..WdLib:float_round_to(chart[i].percent, 1).."%)")
        WDTS.popup.members[i]:Show()
    end

    WDTS.popup:Show()
end

local function hidePopup()
    WDTS.popup:Hide()
end

local function initSpellChartPopup()
    local xSize = 350
    WDTS.popup = CreateFrame("Frame", nil, WDTS)
    WDTS.popup:SetFrameStrata("TOOLTIP")
    WDTS.popup:SetWidth(xSize + 2)
    WDTS.popup.bg = WdLib:createColorTexture(WDTS.popup, "BACKGROUND", 0, 0, 0, .9)
    WDTS.popup.bg:SetAllPoints()

    WDTS.popup.members = {}
    WDTS.popup.label = WdLib:createFontDefault(WDTS.popup, "LEFT", "")
    WDTS.popup.label:SetPoint("TOPLEFT", 5, -1)
    WDTS.popup.label:SetSize(xSize, 20)

    for i=1,POPUP_MAX_SPELLS do
        local r = CreateFrame("StatusBar", nil, WDTS.popup)
        r:SetStatusBarTexture([[Interface\AddOns\WagonDetector\media\statusbars\otravi]])
        r:GetStatusBarTexture():SetHorizTile(false)
        r:GetStatusBarTexture():SetVertTile(false)
        r:SetMinMaxValues(0, 100)
        r:SetStatusBarColor(.15,.25,.15,1)
        r:SetSize(xSize, 20)
        r.leftTxt = WdLib:createFontDefault(r, "LEFT", "")
        r.leftTxt:SetSize(xSize-50, 20)
        r.leftTxt:SetPoint("LEFT", r, "LEFT", 2, 0)
        r.rightTxt = WdLib:createFontDefault(r, "RIGHT", "")
        r.rightTxt:SetSize(100, 20)
        r.rightTxt:SetPoint("RIGHT", r, "RIGHT", -2, 0)
        if i == 1 then
            r:SetPoint("TOPLEFT", WDTS.popup, "TOPLEFT", 1, -22)
        else
            r:SetPoint("TOPLEFT", WDTS.popup.members[i-1], "BOTTOMLEFT", 0, -1)
        end
        WDTS.popup.members[#WDTS.popup.members+1] = r
    end

    WDTS.popup:Hide()
end

local function healDoneSortFunction(a, b)
    local function compareData(v, w)
        if v and w then
            if v.total == w.total then return 0 end
            if v.total > w.total then return 1 end
            if v.total < w.total then return -1 end
        elseif not v and not w then
            return 0
        elseif v then
            return 1
        end
        return -1
    end

    local result = 0
    if not a then
        result = -1
    elseif not b then
        result = 1
    end

    if result == 0 then
        result = compareData(a.data.healDone, b.data.healDone)
        if result == 0 then
            result = compareData(a.data.overhealDone, b.data.overhealDone)
            if result == 0 then
                result = compareData(a.data.healTaken, b.data.healTaken)
                if result == 0 then
                    result = compareData(a.data.overhealTaken, b.data.overhealTaken)
                    if result == 0 then
                        return a.id < b.id
                    end
                end
            end
        end
    end
    return result == 1
end

local function healTakenSortFunction(a, b)
    local function compareData(v, w)
        if v and w then
            if v.total == w.total then return 0 end
            if v.total > w.total then return 1 end
            if v.total < w.total then return -1 end
        elseif not v and not w then
            return 0
        elseif v then
            return 1
        end
        return -1
    end

    local result = 0
    if not a then
        result = -1
    elseif not b then
        result = 1
    end

    if result == 0 then
        result = compareData(a.data.healTaken, b.data.healTaken)
        if result == 0 then
            result = compareData(a.data.overhealTaken, b.data.overhealTaken)
            if result == 0 then
                result = compareData(a.data.healDone, b.data.healDone)
                if result == 0 then
                    result = compareData(a.data.overhealDone, b.data.overhealDone)
                    if result == 0 then
                        return a.id < b.id
                    end
                end
            end
        end
    end
    return result == 1
end

local function dmgDoneSortFunction(a, b)
    local function compareData(v, w)
        if v and w then
            if v.total == w.total then return 0 end
            if v.total > w.total then return 1 end
            if v.total < w.total then return -1 end
        elseif not v and not w then
            return 0
        elseif v then
            return 1
        end
        return -1
    end

    local result = 0
    if not a then
        result = -1
    elseif not b then
        result = 1
    end

    if result == 0 then
        result = compareData(a.data.dmgDone, b.data.dmgDone)
        if result == 0 then
            result = compareData(a.data.overdmgDone, b.data.overdmgDone)
            if result == 0 then
                result = compareData(a.data.dmgTaken, b.data.dmgTaken)
                if result == 0 then
                    result = compareData(a.data.overdmgTaken, b.data.overdmgTaken)
                    if result == 0 then
                        return a.id < b.id
                    end
                end
            end
        end
    end
    return result == 1
end

local function dmgTakenSortFunction(a, b)
    local function compareData(v, w)
        if v and w then
            if v.total == w.total then return 0 end
            if v.total > w.total then return 1 end
            if v.total < w.total then return -1 end
        elseif not v and not w then
            return 0
        elseif v then
            return 1
        end
        return -1
    end

    local result = 0
    if not a then
        result = -1
    elseif not b then
        result = 1
    end

    if result == 0 then
        result = compareData(a.data.dmgTaken, b.data.dmgTaken)
        if result == 0 then
            result = compareData(a.data.overdmgTaken, b.data.overdmgTaken)
            if result == 0 then
                result = compareData(a.data.dmgDone, b.data.dmgDone)
                if result == 0 then
                    result = compareData(a.data.overdmgDone, b.data.overdmgDone)
                    if result == 0 then
                        return a.id < b.id
                    end
                end
            end
        end
    end
    return result == 1
end

local function updateHealInfo()
    local core = WD.mainFrame

    for _,v in pairs(WDTS.data["heal_info"].members) do
        v:Hide()
    end

    local chart = {}
    if WDTS.lastSelectedUnitHeal then
        local v = WDTS.lastSelectedUnitHeal:GetParent().info
        for guid,info in pairs(v.stats) do
            if (info.healDone and info.healDone.total > 0) or
               (info.healTaken and info.healTaken.total > 0) or
               (info.overhealDone and info.overhealDone.total > 0) or
               (info.overhealTaken and info.overhealTaken.total > 0)
            then
                local target = findEntityByGUID(guid)
                if not target then target = { name = guid, class = 0 } end
                chart[#chart+1] = {
                    id = WdLib:getColoredName(WdLib:getShortName(target.name), target.class),
                    data = info,
                    source = WdLib:getColoredName(WdLib:getShortName(v.name), v.class)
                }
            end
        end
        local rule = getCurrentFilter()
        if rule == "done" then
            table.sort(chart, healDoneSortFunction)
        elseif rule == "taken" then
            table.sort(chart, healTakenSortFunction)
        end
    end

    local maxHeight = 210
    local topLeftPosition = { x = 30, y = -51 }
    local rowsN = #chart
    local columnsN = 5

    local function createFn(parent, row, index)
        local source = chart[row].source
        local target = chart[row].id
        local v = chart[row].data
        if index == 1 then
            local value = 0
            if v.healDone then value = v.healDone.total end
            local f = WdLib:addNextColumn(WDTS.data["heal_info"], parent, index, "CENTER", WdLib:shortNumber(value))
            f:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)

            local popupLabel = string.format(WD_TRACKER_DONE_POPUP_LABEL, "Healing", target, source)
            f:SetScript("OnEnter", function() showPopup(f, popupLabel, prepareDataForSpellChart(v.healDone)) end)
            f:SetScript("OnLeave", hidePopup)
            return f
        elseif index == 2 then
            local value = 0
            if v.overhealDone then value = v.overhealDone.total end
            local f = WdLib:addNextColumn(WDTS.data["heal_info"], parent, index, "CENTER", WdLib:shortNumber(value))

            local popupLabel = string.format(WD_TRACKER_DONE_POPUP_LABEL, "Overhealing", target, source)
            f:SetScript("OnEnter", function() showPopup(f, popupLabel, prepareDataForSpellChart(v.overhealDone)) end)
            f:SetScript("OnLeave", hidePopup)
            return f
        elseif index == 3 then
            local value = 0
            if v.healTaken then value = v.healTaken.total end
            local f = WdLib:addNextColumn(WDTS.data["heal_info"], parent, index, "CENTER", WdLib:shortNumber(value))

            local popupLabel = string.format(WD_TRACKER_TAKEN_POPUP_LABEL, "Healing", source, target)
            f:SetScript("OnEnter", function() showPopup(f, popupLabel, prepareDataForSpellChart(v.healTaken)) end)
            f:SetScript("OnLeave", hidePopup)
            return f
        elseif index == 4 then
            local value = 0
            if v.overhealTaken then value = v.overhealTaken.total end
            local f = WdLib:addNextColumn(WDTS.data["heal_info"], parent, index, "CENTER", WdLib:shortNumber(value))

            local popupLabel = string.format(WD_TRACKER_TAKEN_POPUP_LABEL, "Overhealing", source, target)
            f:SetScript("OnEnter", function() showPopup(f, popupLabel, prepareDataForSpellChart(v.overhealTaken)) end)
            f:SetScript("OnLeave", hidePopup)
            return f
        elseif index == 5 then
            return WdLib:addNextColumn(WDTS.data["heal_info"], parent, index, "LEFT", target)
        end
    end

    local function updateFn(f, row, index)
        local source = chart[row].source
        local target = chart[row].id
        local v = chart[row].data
        if index == 1 then
            local value = 0
            if v.healDone then value = v.healDone.total end
            f.txt:SetText(WdLib:shortNumber(value))
            local popupLabel = string.format(WD_TRACKER_DONE_POPUP_LABEL, "Healing", target, source)
            f:SetScript("OnEnter", function() showPopup(f, popupLabel, prepareDataForSpellChart(v.healDone)) end)
        elseif index == 2 then
            local value = 0
            if v.overhealDone then value = v.overhealDone.total end
            f.txt:SetText(WdLib:shortNumber(value))
            local popupLabel = string.format(WD_TRACKER_DONE_POPUP_LABEL, "Overhealing", target, source)
            f:SetScript("OnEnter", function() showPopup(f, popupLabel, prepareDataForSpellChart(v.overhealDone)) end)
        elseif index == 3 then
            local value = 0
            if v.healTaken then value = v.healTaken.total end
            f.txt:SetText(WdLib:shortNumber(value))
            local popupLabel = string.format(WD_TRACKER_TAKEN_POPUP_LABEL, "Healing", source, target)
            f:SetScript("OnEnter", function() showPopup(f, popupLabel, prepareDataForSpellChart(v.healTaken)) end)
        elseif index == 4 then
            local value = 0
            if v.overhealTaken then value = v.overhealTaken.total end
            f.txt:SetText(WdLib:shortNumber(value))
            local popupLabel = string.format(WD_TRACKER_TAKEN_POPUP_LABEL, "Overhealing", source, target)
            f:SetScript("OnEnter", function() showPopup(f, popupLabel, prepareDataForSpellChart(v.overhealTaken)) end)
        elseif index == 5 then
            f.txt:SetText(target)
        end
    end

    WdLib:updateScrollableTable(WDTS.data["heal_info"], maxHeight, topLeftPosition, rowsN, columnsN, createFn, updateFn)

    WDTS.data["heal_info"]:Show()
end

local function updateDmgInfo()
    local core = WD.mainFrame

    for _,v in pairs(WDTS.data["dmg_info"].members) do
        v:Hide()
    end

    local chart = {}
    if WDTS.lastSelectedUnitDmg then
        local v = WDTS.lastSelectedUnitDmg:GetParent().info
        for guid,info in pairs(v.stats) do
            if (info.dmgDone and info.dmgDone.total > 0) or
               (info.dmgTaken and info.dmgTaken.total > 0) or
               (info.overdmgDone and info.overdmgDone.total > 0) or
               (info.overdmgTaken and info.overdmgTaken.total > 0)
            then
                local target = findEntityByGUID(guid)
                if not target then target = { name = guid, class = 0 } end
                chart[#chart+1] = {
                    id = WdLib:getColoredName(WdLib:getShortName(target.name), target.class),
                    data = info,
                    source = WdLib:getColoredName(WdLib:getShortName(v.name), v.class)
                }
            end
        end
        if #chart > 0 then
            local rule = getCurrentFilter()
            if rule == "done" then
                table.sort(chart, dmgDoneSortFunction)
            elseif rule == "taken" then
                table.sort(chart, dmgTakenSortFunction)
            end
        end
    end

    local maxHeight = 210
    local topLeftPosition = { x = 30, y = -51 }
    local rowsN = #chart
    local columnsN = 5

    local function createFn(parent, row, index)
        local source = chart[row].source
        local target = chart[row].id
        local v = chart[row].data
        if index == 1 then
            local value = 0
            if v.dmgDone then value = v.dmgDone.total end
            local f = WdLib:addNextColumn(WDTS.data["dmg_info"], parent, index, "CENTER", WdLib:shortNumber(value))
            f:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)

            local popupLabel = string.format(WD_TRACKER_DONE_POPUP_LABEL, "Damage", target, source)
            f:SetScript("OnEnter", function() showPopup(f, popupLabel, prepareDataForSpellChart(v.dmgDone)) end)
            f:SetScript("OnLeave", hidePopup)
            return f
        elseif index == 2 then
            local value = 0
            if v.overdmgDone then value = v.overdmgDone.total end
            local f = WdLib:addNextColumn(WDTS.data["dmg_info"], parent, index, "CENTER", WdLib:shortNumber(value))

            local popupLabel = string.format(WD_TRACKER_DONE_POPUP_LABEL, "Overkill", target, source)
            f:SetScript("OnEnter", function() showPopup(f, popupLabel, prepareDataForSpellChart(v.overdmgDone)) end)
            f:SetScript("OnLeave", hidePopup)
            return f
        elseif index == 3 then
            local value = 0
            if v.dmgTaken then value = v.dmgTaken.total end
            local f = WdLib:addNextColumn(WDTS.data["dmg_info"], parent, index, "CENTER", WdLib:shortNumber(value))

            local popupLabel = string.format(WD_TRACKER_TAKEN_POPUP_LABEL, "Damage", source, target)
            f:SetScript("OnEnter", function() showPopup(f, popupLabel, prepareDataForSpellChart(v.dmgTaken)) end)
            f:SetScript("OnLeave", hidePopup)
            return f
        elseif index == 4 then
            local value = 0
            if v.overdmgTaken then value = v.overdmgTaken.total end
            local f = WdLib:addNextColumn(WDTS.data["dmg_info"], parent, index, "CENTER", WdLib:shortNumber(value))

            local popupLabel = string.format(WD_TRACKER_TAKEN_POPUP_LABEL, "Overkill", source, target)
            f:SetScript("OnEnter", function() showPopup(f, popupLabel, prepareDataForSpellChart(v.overdmgTaken)) end)
            f:SetScript("OnLeave", hidePopup)
            return f
        elseif index == 5 then
            return WdLib:addNextColumn(WDTS.data["dmg_info"], parent, index, "LEFT", target)
        end
    end

    local function updateFn(f, row, index)
        local source = chart[row].source
        local target = chart[row].id
        local v = chart[row].data
        if index == 1 then
            local value = 0
            if v.dmgDone then value = v.dmgDone.total end
            f.txt:SetText(WdLib:shortNumber(value))
            local popupLabel = string.format(WD_TRACKER_DONE_POPUP_LABEL, "Damage", target, source)
            f:SetScript("OnEnter", function() showPopup(f, popupLabel, prepareDataForSpellChart(v.dmgDone)) end)
        elseif index == 2 then
            local value = 0
            if v.overdmgDone then value = v.overdmgDone.total end
            f.txt:SetText(WdLib:shortNumber(value))
            local popupLabel = string.format(WD_TRACKER_DONE_POPUP_LABEL, "Overkill", target, source)
            f:SetScript("OnEnter", function() showPopup(f, popupLabel, prepareDataForSpellChart(v.overdmgDone)) end)
        elseif index == 3 then
            local value = 0
            if v.dmgTaken then value = v.dmgTaken.total end
            f.txt:SetText(WdLib:shortNumber(value))
            local popupLabel = string.format(WD_TRACKER_TAKEN_POPUP_LABEL, "Damage", source, target)
            f:SetScript("OnEnter", function() showPopup(f, popupLabel, prepareDataForSpellChart(v.dmgTaken)) end)
        elseif index == 4 then
            local value = 0
            if v.overdmgTaken then value = v.overdmgTaken.total end
            f.txt:SetText(WdLib:shortNumber(value))
            local popupLabel = string.format(WD_TRACKER_TAKEN_POPUP_LABEL, "Overkill", source, target)
            f:SetScript("OnEnter", function() showPopup(f, popupLabel, prepareDataForSpellChart(v.overdmgTaken)) end)
        elseif index == 5 then
            f.txt:SetText(target)
        end
    end

    WdLib:updateScrollableTable(WDTS.data["dmg_info"], maxHeight, topLeftPosition, rowsN, columnsN, createFn, updateFn)

    WDTS.data["dmg_info"]:Show()
end

local function updateUnitHealButtons()
    for _,v in pairs(WDTS.unitsHeal.members) do
        v.column[1].t:SetColorTexture(.2, .2, .2, 1)
    end

    if WDTS.lastSelectedUnitHeal then
        WDTS.lastSelectedUnitHeal.t:SetColorTexture(.2, .6, .2, 1)
    end
    updateHealInfo()
end

local function updateUnitDmgButtons()
    for _,v in pairs(WDTS.unitsDmg.members) do
        v.column[1].t:SetColorTexture(.2, .2, .2, 1)
    end

    if WDTS.lastSelectedUnitDmg then
        WDTS.lastSelectedUnitDmg.t:SetColorTexture(.2, .6, .2, 1)
    end
    updateDmgInfo()
end

local function initHealInfoTable()
    WDTS.data["heal_info"] = CreateFrame("Frame", nil, WDTS)
    local r = WDTS.data["heal_info"]
    r:SetPoint("TOPLEFT", WDTS.unitsHeal.headers[1], "TOPRIGHT", 1, 0)
    r:SetSize(550, 300)

    r.headers = {}
    r.members = {}

    -- headers
    local h = WdLib:createTableHeader(r, "Heal done", 0, 0, 120, 20)
    table.insert(r.headers, h)
    h = WdLib:createTableHeaderNext(r, h, "Overheal done", 120, 20)
    table.insert(r.headers, h)
    h = WdLib:createTableHeaderNext(r, h, "Heal taken", 120, 20)
    table.insert(r.headers, h)
    h = WdLib:createTableHeaderNext(r, h, "Overheal taken", 120, 20)
    table.insert(r.headers, h)
    h = WdLib:createTableHeaderNext(r, h, "Target unit", 250, 20)
    table.insert(r.headers, h)

    r:Hide()
end

local function initDmgInfoTable()
    WDTS.data["dmg_info"] = CreateFrame("Frame", nil, WDTS)
    local r = WDTS.data["dmg_info"]
    r:SetPoint("TOPLEFT", WDTS.unitsDmg.headers[1], "TOPRIGHT", 1, 0)
    r:SetSize(550, 300)

    r.headers = {}
    r.members = {}

    -- headers
    local h = WdLib:createTableHeader(r, "Damage done", 0, 0, 120, 20)
    table.insert(r.headers, h)
    h = WdLib:createTableHeaderNext(r, h, "Overkill done", 120, 20)
    table.insert(r.headers, h)
    h = WdLib:createTableHeaderNext(r, h, "Damage taken", 120, 20)
    table.insert(r.headers, h)
    h = WdLib:createTableHeaderNext(r, h, "Overkill taken", 120, 20)
    table.insert(r.headers, h)
    h = WdLib:createTableHeaderNext(r, h, "Target unit", 250, 20)
    table.insert(r.headers, h)

    r:Hide()
end

local function initUnitHealButtons()
    WDTS.unitsHeal = CreateFrame("Frame", nil, WDTS)
    WDTS.unitsHeal.headers = {}
    WDTS.unitsHeal.members = {}
    table.insert(WDTS.unitsHeal.headers, WdLib:createTableHeader(WDTS, "Source units", 1, -30, 300, 20))
end

local function initUnitDmgButtons()
    WDTS.unitsDmg = CreateFrame("Frame", nil, WDTS)
    WDTS.unitsDmg.headers = {}
    WDTS.unitsDmg.members = {}
    table.insert(WDTS.unitsDmg.headers, WdLib:createTableHeader(WDTS, "Source units", 1, -300, 300, 20))
end

local function initPullsMenu()
    local function getPullName()
        if WD.db.profile.tracker.selected and
           WD.db.profile.tracker.selected > 0 and #WD.db.profile.tracker > 0 and
           WD.db.profile.tracker.selected <= #WD.db.profile.tracker
        then
            return WD.db.profile.tracker[WD.db.profile.tracker.selected].pullName
        elseif #WD.db.profile.tracker > 0 then
            WD.db.profile.tracker.selected = #WD.db.profile.tracker
            return WD.db.profile.tracker[#WD.db.profile.tracker].pullName
        end
        return "No pulls"
    end

    local function getPulls()
        local items = {}
        local function onSelect(frame, selected)
            WD.db.profile.tracker.selected = selected.index
            WDTS.lastSelectedUnitHeal = nil
            WDTS.lastSelectedUnitDmg = nil
            WD:RefreshUnitStatistics()
        end
        local i = 1
        for k,v in pairs(WD.db.profile.tracker) do
            if type(v) == "table" then
                table.insert(items, {name = v.pullName, index = i, func = onSelect})
                i = i + 1
            end
        end
        return items
    end

    -- select pull button
    WDTS.buttons["select_pull"] = WdLib:createDropDownMenu(WDTS, getPullName(), getPulls())
    WDTS.buttons["select_pull"]:SetSize(200, 20)
    WDTS.buttons["select_pull"]:SetPoint("TOPLEFT", WDTS, "TOPLEFT", 1, -5)
    WDTS.buttons["select_pull"]:SetScript("OnShow", function(self) self.txt:SetText(getPullName()) end)
    local frame = WDTS.buttons["select_pull"]
    function frame:Refresh()
        WdLib:updateDropDownMenu(self, getPullName(), getPulls())
    end

    -- clear current pull history button
    WDTS.buttons["clear_current_pull"] = WdLib:createButton(WDTS)
    WDTS.buttons["clear_current_pull"]:SetSize(90, 20)
    WDTS.buttons["clear_current_pull"]:SetScript("OnClick", function()
        if WD.db.profile.tracker and WD.db.profile.tracker.selected and WD.db.profile.tracker.selected > 0 then
            table.remove(WD.db.profile.tracker, WD.db.profile.tracker.selected)
            if #WD.db.profile.tracker == 0 then
                WD.db.profile.tracker.selected = 0
            elseif WD.db.profile.tracker.selected > #WD.db.profile.tracker then
                WD.db.profile.tracker.selected = #WD.db.profile.tracker
            end
        end
        WD:RefreshTrackerPulls()
        WD:RefreshUnitStatistics()
    end)
    WDTS.buttons["clear_current_pull"].txt = WdLib:createFont(WDTS.buttons["clear_current_pull"], "CENTER", WD_TRACKER_BUTTON_CLEAR_SELECTED)
    WDTS.buttons["clear_current_pull"].txt:SetAllPoints()

    -- clear pulls history button
    WDTS.buttons["clear_pulls"] = WdLib:createButton(WDTS)
    WDTS.buttons["clear_pulls"]:SetSize(90, 20)
    WDTS.buttons["clear_pulls"]:SetScript("OnClick", function()
        WdLib:table_wipe(WD.db.profile.tracker)
        WD:RefreshTrackerPulls()
        WD:RefreshUnitStatistics()
    end)
    WDTS.buttons["clear_pulls"].txt = WdLib:createFont(WDTS.buttons["clear_pulls"], "CENTER", WD_TRACKER_BUTTON_CLEAR)
    WDTS.buttons["clear_pulls"].txt:SetAllPoints()

    WDTS.buttons["clear_pulls"]:SetPoint("TOPRIGHT", WDTS, "TOPRIGHT", -5, -5)
    WDTS.buttons["clear_current_pull"]:SetPoint("TOPRIGHT", WDTS.buttons["clear_pulls"], "TOPLEFT", -1, 0)
end

local function initRulesMenu()
    local function getRuleName()
        if WD.db.profile.tracker and not WD.db.profile.tracker.selectedRule then
            WD.db.profile.tracker.selectedRule = "TOTAL_DONE"
        end
        return WD.db.profile.tracker.selectedRule or "TOTAL_DONE"
    end

    local function getRules()
        local items = {}
        local function onSelect(frame, selected)
            WD.db.profile.tracker.selectedRule = selected.name
            WDTS.lastSelectedUnitHeal = nil
            WDTS.lastSelectedUnitDmg = nil
            WD:RefreshUnitStatistics()
        end
        for i=1,#ruleTypes do
            table.insert(items, {name = ruleTypes[i], index = i, func = onSelect})
        end
        if WD.db.profile.tracker.statRules then
            local i = #items + 1
            for k,v in pairs(WD.db.profile.tracker.statRules) do
                if type(v) == "table" then
                    table.insert(items, {name = v.pullName, index = i, func = onSelect})
                    i = i + 1
                end
            end
        end
        return items
    end

    -- select rule button
    WDTS.buttons["select_rule"] = WdLib:createDropDownMenu(WDTS, getRuleName(), getRules())
    WDTS.buttons["select_rule"]:SetSize(200, 20)
    WDTS.buttons["select_rule"]:SetPoint("TOPLEFT", WDTS, "TOPLEFT", 401, -5)
    WDTS.buttons["select_rule"]:SetScript("OnShow", function(self) self.txt:SetText(getRuleName()) end)
    local frame = WDTS.buttons["select_rule"]
    function frame:Refresh()
        WdLib:updateDropDownMenu(self, getRuleName(), getRules())
    end

    WDTS.buttons["select_rule"].label = WdLib:createFontDefault(WDTS, "RIGHT", "Applied rule:")
    WDTS.buttons["select_rule"].label:SetSize(150, 20)
    WDTS.buttons["select_rule"].label:SetPoint("RIGHT", WDTS.buttons["select_rule"], "LEFT", -2, 0)
end

local function filterBySelectedRule(v, mode, rule)
    if not v or not v.stats or not rule or not mode then return nil end
    local function validate(unit)
        for guid,info in pairs(unit.stats) do
            if mode == "heal" and rule == "done" and ((info.healDone and info.healDone.total > 0) or (info.overhealDone and info.overhealDone.total > 0)) then
                return true
            end
            if mode == "heal" and rule == "taken" and ((info.healTaken and info.healTaken.total > 0) or (info.overhealTaken and info.overhealTaken.total > 0)) then
                return true
            end
            if mode == "dmg" and rule == "done" and ((info.dmgDone and info.dmgDone.total > 0) or (info.overdmgDone and info.overdmgDone.total > 0)) then
                return true
            end
            if mode == "dmg" and rule == "taken" and ((info.dmgTaken and info.dmgTaken.total > 0) or (info.overdmgTaken and info.overdmgTaken.total > 0)) then
                return true
            end
        end
        return nil
    end
    if validate(v) then return true end
    if v.pets then
        for _,guid in pairs(v.pets) do
            local pet = findEntityByGUID(guid)
            if validate(pet) then return true end
        end
    end
    return nil
end

local function calculateTotalStatsByRule(unit, mode, rule)
    local tNames = getTablesNameByRule(mode, rule)
    unit.total = 0
    for k,v in pairs(unit.stats) do
        if type(v) == "table" then
            for tableName,tableData in pairs(v) do
                if tableName == tNames[1] then
                    unit.total = unit.total + tableData.total
                end
            end
        end
    end
end

local function mergeSpells(units, parent, pet)
    local function findUnit(guid)
        for i=1,#units do
            if units[i].guid == guid then
                return units[i]
            end
        end
        return nil
    end

    local function merge(parentTable, petTable, petName)
        if not petTable or not parentTable then return 0 end
        petName = WdLib:getShortName(petName, "norealm")
        for spellId,spellData in pairs(petTable) do
            if type(spellData) == "table" then
                for event,eventData in pairs(spellData) do
                    if type(eventData) == "table" then
                        if not parentTable[spellId] then parentTable[spellId] = {} end
                        if not parentTable[spellId][petName] then parentTable[spellId][petName] = {} end
                        if not parentTable[spellId][petName][event] then parentTable[spellId][petName][event] = {amount=0} end
                        parentTable[spellId][petName][event].amount = parentTable[spellId][petName][event].amount + eventData.amount
                    end
                end
            end
        end
        parentTable.total = parentTable.total + petTable.total
    end

    local function mergeDoneData(parentUnit, targetGuid, petData)
        if not parentUnit.stats[targetGuid] then parentUnit.stats[targetGuid] = {} end
        local t = parentUnit.stats[targetGuid]
        if petData.healDone then
            if not t.healDone then t.healDone = {total=0} end
            if not t.healDone.pet then t.healDone.pet = {total=0} end
            t.healDone.total = t.healDone.total - t.healDone.pet.total
            merge(t.healDone.pet, petData.healDone, pet.name)
            t.healDone.total = t.healDone.total + t.healDone.pet.total
        end
        if petData.overhealDone then
            if not t.overhealDone then t.overhealDone = {total=0} end
            if not t.overhealDone.pet then t.overhealDone.pet = {total=0} end
            t.overhealDone.total = t.overhealDone.total - t.overhealDone.pet.total
            merge(t.overhealDone.pet, petData.overhealDone, pet.name)
            t.overhealDone.total = t.overhealDone.total + t.overhealDone.pet.total
        end
        if petData.dmgDone then
            if not t.dmgDone then t.dmgDone = {total=0} end
            if not t.dmgDone.pet then t.dmgDone.pet = {total=0} end
            t.dmgDone.total = t.dmgDone.total - t.dmgDone.pet.total
            merge(t.dmgDone.pet, petData.dmgDone, pet.name)
            t.dmgDone.total = t.dmgDone.total + t.dmgDone.pet.total
        end
        if petData.overdmgDone then
            if not t.overdmgDone then t.overdmgDone = {total=0} end
            if not t.overdmgDone.pet then t.overdmgDone.pet = {total=0} end
            t.overdmgDone.total = t.overdmgDone.total - t.overdmgDone.pet.total
            merge(t.overdmgDone.pet, petData.overdmgDone, pet.name)
            t.overdmgDone.total = t.overdmgDone.total + t.overdmgDone.pet.total
        end
    end

    local function mergeTakenData(parentUnit, targetGuid, petData)
        if not parentUnit.stats[targetGuid] then parentUnit.stats[targetGuid] = {} end
        local t = parentUnit.stats[targetGuid]
        if petData.healDone then
            if not t.healTaken then t.healTaken = {total=0} end
            if not t.healTaken.pet then t.healTaken.pet = {total=0} end
            t.healTaken.total = t.healTaken.total - t.healTaken.pet.total
            merge(t.healTaken.pet, petData.healDone, pet.name)
            t.healTaken.total = t.healTaken.total + t.healTaken.pet.total
            parentUnit.stats[pet.guid].healTaken = nil
        end
        if petData.overhealDone then
            if not t.overhealTaken then t.overhealTaken = {total=0} end
            if not t.overhealTaken.pet then t.overhealTaken.pet = {total=0} end
            t.overhealTaken.total = t.overhealTaken.total - t.overhealTaken.pet.total
            merge(t.overhealTaken.pet, petData.overhealDone, pet.name)
            t.overhealTaken.total = t.overhealTaken.total + t.overhealTaken.pet.total
            parentUnit.stats[pet.guid].overhealTaken = nil
        end
        if petData.dmgDone then
            if not t.dmgTaken then t.dmgTaken = {total=0} end
            if not t.dmgTaken.pet then t.dmgTaken.pet = {total=0} end
            t.dmgTaken.total = t.dmgTaken.total - t.dmgTaken.pet.total
            merge(t.dmgTaken.pet, petData.dmgDone, pet.name)
            t.dmgTaken.total = t.dmgTaken.total + t.dmgTaken.pet.total
            parentUnit.stats[pet.guid].dmgTaken = nil
        end
        if petData.overdmgDone then
            if not t.overdmgTaken then t.overdmgTaken = {total=0} end
            if not t.overdmgTaken.pet then t.overdmgTaken.pet = {total=0} end
            t.overdmgTaken.total = t.overdmgTaken.total - t.overdmgTaken.pet.total
            merge(t.overdmgTaken.pet, petData.overdmgDone, pet.name)
            t.overdmgTaken.total = t.overdmgTaken.total + t.overdmgTaken.pet.total
            parentUnit.stats[pet.guid].overdmgTaken = nil
        end
    end

    local function updateTakenData(targetGuid, petData)
        local target = findUnit(targetGuid)
        if not target then return end
        mergeTakenData(target, parent.guid, petData)
    end

    for targetGuid,petData in pairs(pet.stats) do
        -- add pet's data to parent's
        mergeDoneData(parent, targetGuid, petData)
        -- re-arrange taken data from pet source to parent source
        updateTakenData(targetGuid, petData)
    end
end

local function getUnitStatistics(mode)
    local units = {}
    local total = 0
    if not WD.db.profile.tracker or not WD.db.profile.tracker.selected or WD.db.profile.tracker.selected > #WD.db.profile.tracker or #WD.db.profile.tracker == 0 then
        return units, total
    end

    local ruleType = WD.db.profile.tracker.selectedRule
    if ruleType == "TOTAL_DONE" or ruleType == "TOTAL_TAKEN" then

        local function findParent(guid)
            for i=1,#units do
                if units[i].guid == guid then
                    return units[i]
                end
            end
            return nil
        end

        local function filterUnit(unit)
            unit = WdLib:table_deepcopy(unit)
            local rule = getCurrentFilter()
            if filterBySelectedRule(unit, mode, rule) then
                calculateTotalStatsByRule(unit, mode, rule)
                total = total + unit.total
                units[#units+1] = unit
            end
        end

        -- load npc
        for npcId,data in pairs(WD.db.profile.tracker[WD.db.profile.tracker.selected].npc) do
            for _,npc in pairs(data) do
                if type(npc) == "table" then
                    filterUnit(npc)
                end
            end
        end
        -- load players
        for guid,pl in pairs(WD.db.profile.tracker[WD.db.profile.tracker.selected].players) do
            if type(pl) == "table" then
                filterUnit(pl)
            end
        end
        -- load pets
        for parentGuid,info in pairs(WD.db.profile.tracker[WD.db.profile.tracker.selected].pets) do
            for npcId,data in pairs(info) do
                for k,pet in pairs(data) do
                    local parent = findParent(parentGuid)
                    if parent then
                        total = total - parent.total
                        mergeSpells(units, parent, pet)
                        calculateTotalStatsByRule(parent, mode, getCurrentFilter())
                        total = total + parent.total
                    end
                end
            end
        end
    end

    return units, total
end

function refreshUnitHealStatistics()
    if not WDTS then return end

    local mode = "heal"
    local units, total = getUnitStatistics(mode)

    if WDTS.lastSelectedUnitHeal and #units == 0 then
        WDTS.lastSelectedUnitHeal = nil
        updateHealInfo()
    end

    local maxHeight = 210
    local topLeftPosition = { x = 30, y = -51 }
    local rowsN = #units
    local columnsN = 1

    local func = function(a, b)
        if a.total > b.total then return true
        elseif a.total < b.total then return false
        end
        return a.name < b.name
    end
    table.sort(units, func)

    local function createFn(parent, row, index)
        local v = units[row]
        parent.info = v
        if index == 1 then
            local unitName = WdLib:getColoredName(v.name, v.class)
            if v.rt > 0 then unitName = WdLib:getRaidTargetTextureLink(v.rt).." "..unitName end
            local percent = 0
            if total > 0 then percent = v.total * 100 / total end
            local amount = WdLib:shortNumber(v.total).." ("..WdLib:float_round_to(percent, 1).."%)"

            local f = WdLib:addNextColumn(WDTS.unitsHeal, parent, index, "LEFT", row..". "..unitName)
            f:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)

            f.txt:SetSize(200, 20)
            f.txt:SetPoint("LEFT", 2, 0)
            f.txt2 = WdLib:createFontDefault(f, "RIGHT", amount)
            f.txt2:SetSize(100, 20)
            f.txt2:SetPoint("RIGHT", -2, 0)

            f:SetScript("OnClick", function(self) WDTS.lastSelectedUnitHeal = self; updateUnitHealButtons() end)
            local popupLabel = string.format(getPopupLabelByMode(mode), WdLib:getColoredName(WdLib:getShortName(v.name), v.class))
            f:SetScript("OnEnter", function() showPopup(f, popupLabel, prepareTotalDataForSpellChart(v, mode)) end)
            f:SetScript("OnLeave", hidePopup)
            return f
        end
    end

    local function updateFn(f, row, index)
        local v = units[row]
        f:GetParent().info = v
        if index == 1 then
            local unitName = WdLib:getColoredName(v.name, v.class)
            if v.rt > 0 then unitName = WdLib:getRaidTargetTextureLink(v.rt).." "..unitName end
            local percent = 0
            if total > 0 then percent = v.total * 100 / total end
            local amount = WdLib:shortNumber(v.total).." ("..WdLib:float_round_to(percent, 1).."%)"

            f.txt:SetText(row..". "..unitName)
            f.txt2:SetText(amount)

            f:SetScript("OnClick", function(self) WDTS.lastSelectedUnitHeal = self; updateUnitHealButtons() end)
            local popupLabel = string.format(getPopupLabelByMode(mode), WdLib:getColoredName(WdLib:getShortName(v.name), v.class))
            f:SetScript("OnEnter", function() showPopup(f, popupLabel, prepareTotalDataForSpellChart(v, mode)) end)
        end
    end

    WdLib:updateScrollableTable(WDTS.unitsHeal, maxHeight, topLeftPosition, rowsN, columnsN, createFn, updateFn)

    if not WDTS.lastSelectedUnitHeal and #units > 0 then
        WDTS.lastSelectedUnitHeal = WDTS.unitsHeal.members[1].column[1]
    end
    updateUnitHealButtons()
end

function refreshUnitDmgStatistics()
    if not WDTS then return end

    local mode = "dmg"
    local units, total = getUnitStatistics(mode)

    if WDTS.lastSelectedUnitDmg and #units == 0 then
        WDTS.lastSelectedUnitDmg = nil
        updateDmgInfo()
    end

    local maxHeight = 210
    local topLeftPosition = { x = 30, y = -51 }
    local rowsN = #units
    local columnsN = 1

    local func = function(a, b)
        if a.total > b.total then return true
        elseif a.total < b.total then return false
        end
        return a.name < b.name
    end
    table.sort(units, func)

    local function createFn(parent, row, index)
        local v = units[row]
        parent.info = v
        if index == 1 then
            local unitName = WdLib:getColoredName(v.name, v.class)
            if v.rt > 0 then unitName = WdLib:getRaidTargetTextureLink(v.rt).." "..unitName end
            local percent = 0
            if total > 0 then percent = v.total * 100 / total end
            local amount = WdLib:shortNumber(v.total).." ("..WdLib:float_round_to(percent, 1).."%)"

            local f = WdLib:addNextColumn(WDTS.unitsDmg, parent, index, "LEFT", row..". "..unitName)
            f:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)

            f.txt:SetSize(200, 20)
            f.txt:SetPoint("LEFT", 2, 0)
            f.txt2 = WdLib:createFontDefault(f, "RIGHT", amount)
            f.txt2:SetSize(100, 20)
            f.txt2:SetPoint("RIGHT", -2, 0)

            f:SetScript("OnClick", function(self) WDTS.lastSelectedUnitDmg = self; updateUnitDmgButtons() end)
            local popupLabel = string.format(getPopupLabelByMode(mode), WdLib:getColoredName(WdLib:getShortName(v.name), v.class))
            f:SetScript("OnEnter", function() showPopup(f, popupLabel, prepareTotalDataForSpellChart(v, mode)) end)
            f:SetScript("OnLeave", hidePopup)
            return f
        end
    end

    local function updateFn(f, row, index)
        local v = units[row]
        f:GetParent().info = v
        if index == 1 then
            local unitName = WdLib:getColoredName(v.name, v.class)
            if v.rt > 0 then unitName = WdLib:getRaidTargetTextureLink(v.rt).." "..unitName end
            local percent = 0
            if total > 0 then percent = v.total * 100 / total end
            local amount = WdLib:shortNumber(v.total).." ("..WdLib:float_round_to(percent, 1).."%)"

            f.txt:SetText(row..". "..unitName)
            f.txt2:SetText(amount)

            f:SetScript("OnClick", function(self) WDTS.lastSelectedUnitDmg = self; updateUnitDmgButtons() end)
            local popupLabel = string.format(getPopupLabelByMode(mode), WdLib:getColoredName(WdLib:getShortName(v.name), v.class))
            f:SetScript("OnEnter", function() showPopup(f, popupLabel, prepareTotalDataForSpellChart(v, mode)) end)
        end
    end

    WdLib:updateScrollableTable(WDTS.unitsDmg, maxHeight, topLeftPosition, rowsN, columnsN, createFn, updateFn)

    if not WDTS.lastSelectedUnitDmg and #units > 0 then
        WDTS.lastSelectedUnitDmg = WDTS.unitsDmg.members[1].column[1]
    end
    updateUnitDmgButtons()
end

function WD:RefreshUnitStatistics()
    refreshUnitHealStatistics()
    refreshUnitDmgStatistics()
end

function WD:InitTrackerStatisticsModule(parent)
    WDTS = parent

    WDTS.buttons = {}
    WDTS.data = {}

    initPullsMenu()
    initRulesMenu()
    initUnitHealButtons()
    initUnitDmgButtons()
    initHealInfoTable()
    initDmgInfoTable()
    initSpellChartPopup()

    WDTS:SetScript("OnShow", function(self) self:OnUpdate() end)

    function WDTS:OnUpdate()
        WD:RefreshUnitStatistics()
    end
end
