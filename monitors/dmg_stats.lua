
local WDDSM = nil

local WDDmgStatsMonitor = {}
WDDmgStatsMonitor.__index = WDDmgStatsMonitor

setmetatable(WDDmgStatsMonitor, {
    __index = WD.StatsMonitor,
    __call = function (v, ...)
        local self = setmetatable({}, v)
        self:init(...)
        return self
    end,
})

local function dmgDoneSortFunction(a, b)
    local result = 0
    if not a then
        result = -1
    elseif not b then
        result = 1
    end

    if result == 0 then
        result = WDDSM.parent:compareData(a.data.dmgDone, b.data.dmgDone)
        if result == 0 then
            result = WDDSM.parent:compareData(a.data.overdmgDone, b.data.overdmgDone)
            if result == 0 then
                result = WDDSM.parent:compareData(a.data.dmgTaken, b.data.dmgTaken)
                if result == 0 then
                    result = WDDSM.parent:compareData(a.data.overdmgTaken, b.data.overdmgTaken)
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
    local result = 0
    if not a then
        result = -1
    elseif not b then
        result = 1
    end

    if result == 0 then
        result = WDDSM.parent:compareData(a.data.dmgTaken, b.data.dmgTaken)
        if result == 0 then
            result = WDDSM.parent:compareData(a.data.overdmgTaken, b.data.overdmgTaken)
            if result == 0 then
                result = WDDSM.parent:compareData(a.data.dmgDone, b.data.dmgDone)
                if result == 0 then
                    result = WDDSM.parent:compareData(a.data.overdmgDone, b.data.overdmgDone)
                    if result == 0 then
                        return a.id < b.id
                    end
                end
            end
        end
    end
    return result == 1
end

function WDDmgStatsMonitor:init(parent, name)
    WD.StatsMonitor.init(self, parent, name)
    WDDSM = self.frame
    WDDSM.parent = self
end

function WDDmgStatsMonitor:initMainTable()
    WD.Monitor.initMainTable(self, "dmg_info", "Source units", 1, -310, 380, 20)
end

function WDDmgStatsMonitor:initDataTable()
    local columns = {
        [1] = {"Damage done",      100},
        [2] = {"Overkill done",    100},
        [3] = {"Damage taken",     100},
        [4] = {"Overkill taken",   100},
        [5] = {"Target unit",       250},
    }
    WD.Monitor.initDataTable(self, "dmg_info", columns)

    self.nameFilter = WdLib.gui:createEditBox(self.frame:GetParent())
    self.nameFilter:SetSize(self.frame.dataTable.headers[5]:GetSize())
    self.nameFilter:SetPoint("BOTTOMLEFT", self.frame.dataTable.headers[5], "TOPLEFT", 0, 1)
    self.nameFilter:SetMaxLetters(15)
    self.nameFilter:SetScript("OnChar", function(f) self:updateDataTable() end)
    self.nameFilter:SetScript("OnEnterPressed", function(f) f:ClearFocus() self:updateDataTable() end)
    self.nameFilter:SetScript("OnEscapePressed", function(f) f:ClearFocus() end)
end

function WDDmgStatsMonitor:mergeSpells(parent, pet, ruleId)
    local function mergeDoneData(parentUnit, targetGuid, petData)
        if not parentUnit.stats[targetGuid] then parentUnit.stats[targetGuid] = {} end
        local t = parentUnit.stats[targetGuid]
        if petData.dmgDone then
            if not t.dmgDone then t.dmgDone = {total=0} end
            if not t.dmgDone.pet then t.dmgDone.pet = {total=0} end
            t.dmgDone.total = t.dmgDone.total - t.dmgDone.pet.total
            self:merge(t.dmgDone.pet, petData.dmgDone, pet.name)
            t.dmgDone.total = t.dmgDone.total + t.dmgDone.pet.total
        end
        if petData.overdmgDone then
            if not t.overdmgDone then t.overdmgDone = {total=0} end
            if not t.overdmgDone.pet then t.overdmgDone.pet = {total=0} end
            t.overdmgDone.total = t.overdmgDone.total - t.overdmgDone.pet.total
            self:merge(t.overdmgDone.pet, petData.overdmgDone, pet.name)
            t.overdmgDone.total = t.overdmgDone.total + t.overdmgDone.pet.total
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

function WDDmgStatsMonitor:updateTakenInfo(mode, srcUnit)
    for dstGuid,src in pairs(srcUnit.stats) do
        local dstUnit = self:findUnitByGuid(mode, dstGuid)
        if dstUnit then
            if not dstUnit.stats[srcUnit.guid] then dstUnit.stats[srcUnit.guid] = {} end
            local dst = dstUnit.stats[srcUnit.guid]

            dst.dmgTaken = {total=0}
            dst.overdmgTaken = {total=0}

            self:copyTableTo(src.dmgDone, dst.dmgTaken)
            self:copyTableTo(src.overdmgDone, dst.overdmgTaken)
        end
    end
end

function WDDmgStatsMonitor:updateDataTable()
    local core = WD.mainFrame

    for _,v in pairs(WDDSM.dataTable.members) do
        v:Hide()
    end

    local rule = WDDSM.parent:getCurrentFilter()
    local chart = {}
    if WDDSM.lastSelectedButton then
        local v = WDDSM.lastSelectedButton:GetParent().info
        for guid,info in pairs(v.stats) do
            if (info.dmgDone and info.dmgDone.total > 0) or
               (info.dmgTaken and info.dmgTaken.total > 0) or
               (info.overdmgDone and info.overdmgDone.total > 0) or
               (info.overdmgTaken and info.overdmgTaken.total > 0)
            then
                local target = WDDSM.parent:findEntityByGUID(guid)
                local targetName, classId = guid, 0
                if target then
                    targetName, classId = WdLib.gen:getShortName(target.name), target.class
                    if target.type == "pet" then
                        targetName = WDDSM.parent:updatePetName(target)
                    end
                    targetName = WdLib.gen:getColoredName(targetName, classId)
                end
                local sourceName = WdLib.gen:getColoredName(WdLib.gen:getShortName(v.name), v.class)
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
            local f = WdLib.gui:addNextColumn(WDDSM.dataTable, parent, index, "CENTER", WdLib.gen:shortNumber(value))
            f:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
            WDDSM.parent:initStatusBar(f)
            if v.dmgDone and rule == "done" then
                WDDSM.parent:updateStatusBar(f.bar, chart[row].class, v.dmgDone, chart[1].data.dmgDone)
            else
                WDDSM.parent:updateStatusBar(f.bar)
            end

            local popupLabel = string.format(WD_TRACKER_DONE_POPUP_LABEL, "Damage", target, source)
            f:SetScript("OnEnter", function() WDDSM.parent:showPopup(f, popupLabel, WDDSM.parent:prepareDataForSpellChart(v.dmgDone)) end)
            f:SetScript("OnLeave", function() WDDSM.parent:hidePopup() end)
            return f
        elseif index == 2 then
            local value = ""
            if v.overdmgDone and v.overdmgDone.total > 0 then value = "|cffff0000KILLING BLOW!|r" end
            local f = WdLib.gui:addNextColumn(WDDSM.dataTable, parent, index, "CENTER", value)

            local popupLabel = string.format(WD_TRACKER_DONE_POPUP_LABEL, "Overkill", target, source)
            f:SetScript("OnEnter", function() WDDSM.parent:showPopup(f, popupLabel, WDDSM.parent:prepareDataForSpellChart(v.overdmgDone)) end)
            f:SetScript("OnLeave", function() WDDSM.parent:hidePopup() end)
            return f
        elseif index == 3 then
            local value = 0
            if v.dmgTaken then value = v.dmgTaken.total end
            local f = WdLib.gui:addNextColumn(WDDSM.dataTable, parent, index, "CENTER", WdLib.gen:shortNumber(value))
            WDDSM.parent:initStatusBar(f)
            if v.dmgTaken and rule == "taken" then
                WDDSM.parent:updateStatusBar(f.bar, chart[row].class, v.dmgTaken, chart[1].data.dmgTaken)
            else
                WDDSM.parent:updateStatusBar(f.bar)
            end

            local popupLabel = string.format(WD_TRACKER_TAKEN_POPUP_LABEL, "Damage", source, target)
            f:SetScript("OnEnter", function() WDDSM.parent:showPopup(f, popupLabel, WDDSM.parent:prepareDataForSpellChart(v.dmgTaken)) end)
            f:SetScript("OnLeave", function() WDDSM.parent:hidePopup() end)
            return f
        elseif index == 4 then
            local value = ""
            if v.overdmgTaken and v.overdmgTaken.total > 0 then value = "|cffff0000KILLING BLOW!|r" end
            local f = WdLib.gui:addNextColumn(WDDSM.dataTable, parent, index, "CENTER", value)

            local popupLabel = string.format(WD_TRACKER_TAKEN_POPUP_LABEL, "Overkill", source, target)
            f:SetScript("OnEnter", function() WDDSM.parent:showPopup(f, popupLabel, WDDSM.parent:prepareDataForSpellChart(v.overdmgTaken)) end)
            f:SetScript("OnLeave", function() WDDSM.parent:hidePopup() end)
            return f
        elseif index == 5 then
            return WdLib.gui:addNextColumn(WDDSM.dataTable, parent, index, "LEFT", target)
        end
    end

    local function updateFn(f, row, index)
        local source = chart[row].source
        local target = chart[row].id
        local v = chart[row].data
        if index == 1 then
            local value = 0
            if v.dmgDone then value = v.dmgDone.total end
            f.txt:SetText(WdLib.gen:shortNumber(value))
            if v.dmgDone and rule == "done" then
                WDDSM.parent:updateStatusBar(f.bar, chart[row].class, v.dmgDone, chart[1].data.dmgDone)
            else
                WDDSM.parent:updateStatusBar(f.bar)
            end
            local popupLabel = string.format(WD_TRACKER_DONE_POPUP_LABEL, "Damage", target, source)
            f:SetScript("OnEnter", function() WDDSM.parent:showPopup(f, popupLabel, WDDSM.parent:prepareDataForSpellChart(v.dmgDone)) end)
        elseif index == 2 then
            local value = ""
            if v.overdmgDone and v.overdmgDone.total > 0 then value = "|cffff0000KILLING BLOW!|r" end
            f.txt:SetText(value)
            local popupLabel = string.format(WD_TRACKER_DONE_POPUP_LABEL, "Overkill", target, source)
            f:SetScript("OnEnter", function() WDDSM.parent:showPopup(f, popupLabel, WDDSM.parent:prepareDataForSpellChart(v.overdmgDone)) end)
        elseif index == 3 then
            local value = 0
            if v.dmgTaken then value = v.dmgTaken.total end
            f.txt:SetText(WdLib.gen:shortNumber(value))
            if v.dmgTaken and rule == "taken" then
                WDDSM.parent:updateStatusBar(f.bar, chart[row].class, v.dmgTaken, chart[1].data.dmgTaken)
            else
                WDDSM.parent:updateStatusBar(f.bar)
            end
            local popupLabel = string.format(WD_TRACKER_TAKEN_POPUP_LABEL, "Damage", source, target)
            f:SetScript("OnEnter", function() WDDSM.parent:showPopup(f, popupLabel, WDDSM.parent:prepareDataForSpellChart(v.dmgTaken)) end)
        elseif index == 4 then
            local value = ""
            if v.overdmgTaken and v.overdmgTaken.total > 0 then value = "|cffff0000KILLING BLOW!|r" end
            f.txt:SetText(value)
            local popupLabel = string.format(WD_TRACKER_TAKEN_POPUP_LABEL, "Overkill", source, target)
            f:SetScript("OnEnter", function() WDDSM.parent:showPopup(f, popupLabel, WDDSM.parent:prepareDataForSpellChart(v.overdmgTaken)) end)
        elseif index == 5 then
            f.txt:SetText(target)
        end
    end

    WdLib.gui:updateScrollableTable(WDDSM.dataTable, maxHeight, topLeftPosition, rowsN, columnsN, createFn, updateFn)

    WDDSM.dataTable:Show()
end

function WDDmgStatsMonitor:refreshInfo()
    local mode = "dmg"
    local units, total = self:getUnitStatistics(mode)

    if WDDSM.lastSelectedButton and #units == 0 then
        WDDSM.lastSelectedButton = nil
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
            local unitName = WdLib.gen:getColoredName(v.name, v.class)
            if v.rt and v.rt > 0 then unitName = WdLib.gui:getRaidTargetTextureLink(v.rt).." "..unitName end
            local percent = 0
            if total > 0 then percent = v.total * 100 / total end
            local amount = WdLib.gen:shortNumber(v.total).." ("..WdLib.gen:float_round_to(percent, 1).."%)"

            local pull = WDDSM:GetParent().GetSelectedPull()
            if v.spawnedAt < pull.startTime then
                v.spawnedAt = pull.startTime
            end
            if pull.endTime and v.spawnedAt > pull.endTime then
                v.spawnedAt = pull.endTime
            end
            local lifeTime = WdLib.gen:getTimedDiffShort(v.spawnedAt or 0, v.diedAt or pull.endTime or 0)
            local rowText = row..". "..unitName.." ("..lifeTime..")"
            local f = WdLib.gui:addNextColumn(WDDSM.mainTable, parent, index, "LEFT", rowText)
            f:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)

            f.txt:SetSize(300, 20)
            f.txt:SetPoint("LEFT", 2, 0)
            f.txt2 = WdLib.gui:createFontDefault(f, "RIGHT", amount)
            f.txt2:SetSize(100, 20)
            f.txt2:SetPoint("RIGHT", -2, 0)

            f:SetScript("OnClick", function(rowFrame) WDDSM.lastSelectedButton = rowFrame; self:updateMainTableData() end)
            local popupLabel = string.format(self:getPopupLabelByMode(mode), WdLib.gen:getColoredName(WdLib.gen:getShortName(v.name), v.class))
            f:SetScript("OnEnter", function() self:showPopup(f, popupLabel, WDDSM.parent:prepareTotalDataForSpellChart(v, mode)) end)
            f:SetScript("OnLeave", function() self:hidePopup() end)
            return f
        end
    end

    local function updateFn(f, row, index)
        local v = units[row]
        f:GetParent().info = v
        if index == 1 then
            local unitName = WdLib.gen:getColoredName(v.name, v.class)
            if v.rt and v.rt > 0 then unitName = WdLib.gui:getRaidTargetTextureLink(v.rt).." "..unitName end
            local percent = 0
            if total > 0 then percent = v.total * 100 / total end
            local amount = WdLib.gen:shortNumber(v.total).." ("..WdLib.gen:float_round_to(percent, 1).."%)"

            local pull = WDDSM:GetParent().GetSelectedPull()
            if v.spawnedAt < pull.startTime then
                v.spawnedAt = pull.startTime
            end
            if pull.endTime and v.spawnedAt > pull.endTime then
                v.spawnedAt = pull.endTime
            end
            local lifeTime = WdLib.gen:getTimedDiffShort(v.spawnedAt or 0, v.diedAt or pull.endTime or 0)
            local rowText = row..". "..unitName.." ("..lifeTime..")"
            f.txt:SetText(rowText)
            f.txt2:SetText(amount)

            f:SetScript("OnClick", function(rowFrame) WDDSM.lastSelectedButton = rowFrame; self:updateMainTableData() end)
            local popupLabel = string.format(self:getPopupLabelByMode(mode), WdLib.gen:getColoredName(WdLib.gen:getShortName(v.name), v.class))
            f:SetScript("OnEnter", function() self:showPopup(f, popupLabel, WDDSM.parent:prepareTotalDataForSpellChart(v, mode)) end)
        end
    end

    WdLib.gui:updateScrollableTable(WDDSM.mainTable, maxHeight, topLeftPosition, rowsN, columnsN, createFn, updateFn)

    if not WDDSM.lastSelectedButton and #units > 0 then
        WDDSM.lastSelectedButton = WDDSM.mainTable.members[1].column[1]
    end
    self:updateMainTableData()
end

WD.DmgStatsMonitor = WDDmgStatsMonitor