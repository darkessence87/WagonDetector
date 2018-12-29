
local WDHSM = nil

local WDHealStatsMonitor = {}
WDHealStatsMonitor.__index = WDHealStatsMonitor

setmetatable(WDHealStatsMonitor, {
    __index = WD.StatsMonitor,
    __call = function (cls, ...)
        local self = setmetatable({}, cls)
        self:init(...)
        return self
    end,
})

local function healDoneSortFunction(a, b)
    local result = 0
    if not a then
        result = -1
    elseif not b then
        result = 1
    end

    if result == 0 then
        result = WDHSM.parent:compareData(a.data.healDone, b.data.healDone)
        if result == 0 then
            result = WDHSM.parent:compareData(a.data.overhealDone, b.data.overhealDone)
            if result == 0 then
                result = WDHSM.parent:compareData(a.data.healTaken, b.data.healTaken)
                if result == 0 then
                    result = WDHSM.parent:compareData(a.data.overhealTaken, b.data.overhealTaken)
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
    local result = 0
    if not a then
        result = -1
    elseif not b then
        result = 1
    end

    if result == 0 then
        result = WDHSM.parent:compareData(a.data.healTaken, b.data.healTaken)
        if result == 0 then
            result = WDHSM.parent:compareData(a.data.overhealTaken, b.data.overhealTaken)
            if result == 0 then
                result = WDHSM.parent:compareData(a.data.healDone, b.data.healDone)
                if result == 0 then
                    result = WDHSM.parent:compareData(a.data.overhealDone, b.data.overhealDone)
                    if result == 0 then
                        return a.id < b.id
                    end
                end
            end
        end
    end
    return result == 1
end

function WDHealStatsMonitor:init(parent, name)
    WD.StatsMonitor.init(self, parent, name)
    WDHSM = self.frame
    WDHSM.parent = self
end

function WDHealStatsMonitor:initMainTable()
    WD.Monitor.initMainTable(self, "heal_info", "Source units", 1, -50, 380, 20)
end

function WDHealStatsMonitor:initDataTable()
    local columns = {
        [1] = {"Heal done",      100},
        [2] = {"Overheal done",  100},
        [3] = {"Heal taken",     100},
        [4] = {"Overheal taken", 100},
        [5] = {"Target unit",    250},
    }
    WD.Monitor.initDataTable(self, "heal_info", columns)

    self.nameFilter = WdLib:createEditBox(self.frame:GetParent())
    self.nameFilter:SetSize(self.frame.dataTable.headers[5]:GetSize())
    self.nameFilter:SetPoint("BOTTOMLEFT", self.frame.dataTable.headers[5], "TOPLEFT", 0, 1)
    self.nameFilter:SetMaxLetters(15)
    self.nameFilter:SetScript("OnChar", function(f) self:updateDataTable() end)
    self.nameFilter:SetScript("OnEnterPressed", function(f) f:ClearFocus() self:updateDataTable() end)
    self.nameFilter:SetScript("OnEscapePressed", function(f) f:ClearFocus() end)
end

function WDHealStatsMonitor:mergeSpells(parent, pet, ruleId)
    local function mergeDoneData(parentUnit, targetGuid, petData)
        if not parentUnit.stats[targetGuid] then parentUnit.stats[targetGuid] = {} end
        local t = parentUnit.stats[targetGuid]
        if petData.healDone then
            if not t.healDone then t.healDone = {total=0} end
            if not t.healDone.pet then t.healDone.pet = {total=0} end
            t.healDone.total = t.healDone.total - t.healDone.pet.total
            self:merge(t.healDone.pet, petData.healDone, pet.name)
            t.healDone.total = t.healDone.total + t.healDone.pet.total
        end
        if petData.overhealDone then
            if not t.overhealDone then t.overhealDone = {total=0} end
            if not t.overhealDone.pet then t.overhealDone.pet = {total=0} end
            t.overhealDone.total = t.overhealDone.total - t.overhealDone.pet.total
            self:merge(t.overhealDone.pet, petData.overhealDone, pet.name)
            t.overhealDone.total = t.overhealDone.total + t.overhealDone.pet.total
        end
    end

    if ruleId then
        if pet.ruleStats and pet.ruleStats[ruleId] then
            for targetGuid,petData in pairs(pet.ruleStats[ruleId].stats) do
                mergeDoneData(parent, targetGuid, petData)
            end
        end
    else
        for targetGuid,petData in pairs(pet.stats) do
            mergeDoneData(parent, targetGuid, petData)
        end
    end
end

function WDHealStatsMonitor:updateTakenInfo(mode, srcUnit)
    for dstGuid,src in pairs(srcUnit.stats) do
        local dstUnit = self:findUnitByGuid(mode, dstGuid)
        if dstUnit then
            if not dstUnit.stats[srcUnit.guid] then dstUnit.stats[srcUnit.guid] = {} end
            local dst = dstUnit.stats[srcUnit.guid]

            dst.healTaken = {total=0}
            dst.overhealTaken = {total=0}

            self:copyTableTo(src.healDone, dst.healTaken)
            self:copyTableTo(src.overhealDone, dst.overhealTaken)
        end
    end
end

function WDHealStatsMonitor:updateDataTable()
    local core = WD.mainFrame

    for _,v in pairs(WDHSM.dataTable.members) do
        v:Hide()
    end

    local rule = WDHSM.parent:getCurrentFilter()
    local chart = {}
    if WDHSM.lastSelectedButton then
        local v = WDHSM.lastSelectedButton:GetParent().info
        for guid,info in pairs(v.stats) do
            if (info.healDone and info.healDone.total > 0) or
               (info.healTaken and info.healTaken.total > 0) or
               (info.overhealDone and info.overhealDone.total > 0) or
               (info.overhealTaken and info.overhealTaken.total > 0)
            then
                local target = WDHSM.parent:findEntityByGUID(guid)
                local targetName, classId = guid, 0
                if target then
                    targetName, classId = WdLib:getShortName(target.name), target.class
                    if target.type == "pet" then
                        targetName = WDHSM.parent:updatePetName(target)
                    end
                    targetName = WdLib:getColoredName(targetName, classId)
                end
                local sourceName = WdLib:getColoredName(WdLib:getShortName(v.name), v.class)
                local filter = self.nameFilter:GetText()
                if not filter or (filter and targetName:match(filter)) then
                    chart[#chart+1] = {
                        id = targetName,
                        data = info,
                        source = sourceName,
                        class = classId,
                    }
                end
            end
        end
        if #chart > 0 then
            if rule == "done" then
                table.sort(chart, healDoneSortFunction)
            elseif rule == "taken" then
                table.sort(chart, healTakenSortFunction)
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
            if v.healDone then value = v.healDone.total end
            local f = WdLib:addNextColumn(WDHSM.dataTable, parent, index, "CENTER", WdLib:shortNumber(value))
            f:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
            WDHSM.parent:initStatusBar(f)
            if v.healDone and rule == "done" then
                WDHSM.parent:updateStatusBar(f.bar, chart[row].class, v.healDone, chart[1].data.healDone)
            else
                WDHSM.parent:updateStatusBar(f.bar)
            end

            local popupLabel = string.format(WD_TRACKER_DONE_POPUP_LABEL, "Healing", target, source)
            f:SetScript("OnEnter", function() WDHSM.parent:showPopup(f, popupLabel, WDHSM.parent:prepareDataForSpellChart(v.healDone)) end)
            f:SetScript("OnLeave", function() WDHSM.parent:hidePopup() end)
            return f
        elseif index == 2 then
            local value = 0
            if v.overhealDone then value = v.overhealDone.total end
            local f = WdLib:addNextColumn(WDHSM.dataTable, parent, index, "CENTER", WdLib:shortNumber(value))

            local popupLabel = string.format(WD_TRACKER_DONE_POPUP_LABEL, "Overhealing", target, source)
            f:SetScript("OnEnter", function() WDHSM.parent:showPopup(f, popupLabel, WDHSM.parent:prepareDataForSpellChart(v.overhealDone)) end)
            f:SetScript("OnLeave", function() WDHSM.parent:hidePopup() end)
            return f
        elseif index == 3 then
            local value = 0
            if v.healTaken then value = v.healTaken.total end
            local f = WdLib:addNextColumn(WDHSM.dataTable, parent, index, "CENTER", WdLib:shortNumber(value))
            WDHSM.parent:initStatusBar(f)
            if v.healTaken and rule == "taken" then
                WDHSM.parent:updateStatusBar(f.bar, chart[row].class, v.healTaken, chart[1].data.healTaken)
            else
                WDHSM.parent:updateStatusBar(f.bar)
            end

            local popupLabel = string.format(WD_TRACKER_TAKEN_POPUP_LABEL, "Healing", source, target)
            f:SetScript("OnEnter", function() WDHSM.parent:showPopup(f, popupLabel, WDHSM.parent:prepareDataForSpellChart(v.healTaken)) end)
            f:SetScript("OnLeave", function() WDHSM.parent:hidePopup() end)
            return f
        elseif index == 4 then
            local value = 0
            if v.overhealTaken then value = v.overhealTaken.total end
            local f = WdLib:addNextColumn(WDHSM.dataTable, parent, index, "CENTER", WdLib:shortNumber(value))

            local popupLabel = string.format(WD_TRACKER_TAKEN_POPUP_LABEL, "Overhealing", source, target)
            f:SetScript("OnEnter", function() WDHSM.parent:showPopup(f, popupLabel, WDHSM.parent:prepareDataForSpellChart(v.overhealTaken)) end)
            f:SetScript("OnLeave", function() WDHSM.parent:hidePopup() end)
            return f
        elseif index == 5 then
            return WdLib:addNextColumn(WDHSM.dataTable, parent, index, "LEFT", target)
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
            if v.healDone and rule == "done" then
                WDHSM.parent:updateStatusBar(f.bar, chart[row].class, v.healDone, chart[1].data.healDone)
            else
                WDHSM.parent:updateStatusBar(f.bar)
            end
            local popupLabel = string.format(WD_TRACKER_DONE_POPUP_LABEL, "Healing", target, source)
            f:SetScript("OnEnter", function() WDHSM.parent:showPopup(f, popupLabel, WDHSM.parent:prepareDataForSpellChart(v.healDone)) end)
        elseif index == 2 then
            local value = 0
            if v.overhealDone then value = v.overhealDone.total end
            f.txt:SetText(WdLib:shortNumber(value))
            local popupLabel = string.format(WD_TRACKER_DONE_POPUP_LABEL, "Overhealing", target, source)
            f:SetScript("OnEnter", function() WDHSM.parent:showPopup(f, popupLabel, WDHSM.parent:prepareDataForSpellChart(v.overhealDone)) end)
        elseif index == 3 then
            local value = 0
            if v.healTaken then value = v.healTaken.total end
            f.txt:SetText(WdLib:shortNumber(value))
            if v.healTaken and rule == "taken" then
                WDHSM.parent:updateStatusBar(f.bar, chart[row].class, v.healTaken, chart[1].data.healTaken)
            else
                WDHSM.parent:updateStatusBar(f.bar)
            end
            local popupLabel = string.format(WD_TRACKER_TAKEN_POPUP_LABEL, "Healing", source, target)
            f:SetScript("OnEnter", function() WDHSM.parent:showPopup(f, popupLabel, WDHSM.parent:prepareDataForSpellChart(v.healTaken)) end)
        elseif index == 4 then
            local value = 0
            if v.overhealTaken then value = v.overhealTaken.total end
            f.txt:SetText(WdLib:shortNumber(value))
            local popupLabel = string.format(WD_TRACKER_TAKEN_POPUP_LABEL, "Overhealing", source, target)
            f:SetScript("OnEnter", function() WDHSM.parent:showPopup(f, popupLabel, WDHSM.parent:prepareDataForSpellChart(v.overhealTaken)) end)
        elseif index == 5 then
            f.txt:SetText(target)
        end
    end

    WdLib:updateScrollableTable(WDHSM.dataTable, maxHeight, topLeftPosition, rowsN, columnsN, createFn, updateFn)

    WDHSM.dataTable:Show()
end

function WDHealStatsMonitor:refreshInfo()
    local mode = "heal"
    local units, total = self:getUnitStatistics(mode)

    if WDHSM.lastSelectedButton and #units == 0 then
        WDHSM.lastSelectedButton = nil
        self:updateDataTable()
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

            local f = WdLib:addNextColumn(WDHSM.mainTable, parent, index, "LEFT", row..". "..unitName)
            f:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)

            f.txt:SetSize(300, 20)
            f.txt:SetPoint("LEFT", 2, 0)
            f.txt2 = WdLib:createFontDefault(f, "RIGHT", amount)
            f.txt2:SetSize(100, 20)
            f.txt2:SetPoint("RIGHT", -2, 0)

            f:SetScript("OnClick", function(rowFrame) WDHSM.lastSelectedButton = rowFrame; self:updateMainTableData() end)
            local popupLabel = string.format(self:getPopupLabelByMode(mode), WdLib:getColoredName(WdLib:getShortName(v.name), v.class))
            f:SetScript("OnEnter", function() self:showPopup(f, popupLabel, WDHSM.parent:prepareTotalDataForSpellChart(v, mode)) end)
            f:SetScript("OnLeave", function() self:hidePopup() end)
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

            f:SetScript("OnClick", function(rowFrame) WDHSM.lastSelectedButton = rowFrame; self:updateMainTableData() end)
            local popupLabel = string.format(self:getPopupLabelByMode(mode), WdLib:getColoredName(WdLib:getShortName(v.name), v.class))
            f:SetScript("OnEnter", function() self:showPopup(f, popupLabel, WDHSM.parent:prepareTotalDataForSpellChart(v, mode)) end)
        end
    end

    WdLib:updateScrollableTable(WDHSM.mainTable, maxHeight, topLeftPosition, rowsN, columnsN, createFn, updateFn)

    if not WDHSM.lastSelectedButton and #units > 0 then
        WDHSM.lastSelectedButton = WDHSM.mainTable.members[1].column[1]
    end
    self:updateMainTableData()
end

WD.HealStatsMonitor = WDHealStatsMonitor