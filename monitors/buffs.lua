
local WDBAM = nil

local WDBuffMonitor = {}
WDBuffMonitor.__index = WDBuffMonitor

setmetatable(WDBuffMonitor, {
    __index = WD.Monitor,
    __call = function (v, ...)
        local self = setmetatable({}, v)
        self:init(...)
        return self
    end,
})

local function calculateLifetime(pull, unit)
    local fromTime = unit.spawnedAt or pull.startTime or 0
    local toTime = unit.diedAt or pull.endTime or 0
    return toTime - fromTime
end

local function calculateUptime(v, totalV)
    if not v or not totalV or totalV == 0 then return nil end
    return WdLib.gen:float_round_to(v * 100 / totalV, 1)
end

local function calculateAuraDuration(pull, unit, aura, index)
    if unit.diedAt or pull.endTime then
        local toTime = unit.diedAt or pull.endTime or 0
        if toTime > 0 then
            local t = (toTime - aura.applied) / 1000
            return WdLib.gen:float_round_to(t * 1000, 2)
        end
    end
    if index > 1 then
        return 0
    end
    return nil
end

local function getCasterName(v)
    local casterName = UNKNOWNOBJECT
    local caster = WDBAM.parent:findEntityByGUID(v.caster)
    if caster then
        casterName = caster.name
        if caster.type == "pet" then
            casterName = WDBAM.parent:updatePetName(caster)
        end
        casterName = WdLib.gen:getColoredName(WdLib.gen:getShortName(casterName), caster.class)
    else
        casterName = "|cffffffffEnvironment|r"
    end
    return casterName
end

local function getFilteredBuffs(unit, filter)
    local result = {}
    local pull = WDBAM:GetParent().GetSelectedPull()
    if not pull then return result end

    local maxDuration = calculateLifetime(pull, unit)

    for auraId,auraInfo in pairs(unit.auras) do
        local byCaster = {}
        for i=1,#auraInfo do
            if auraInfo[i].isBuff == true then
                local caster = auraInfo[i].caster
                if not filter or (filter and getCasterName(auraInfo[i]):match(filter)) then
                    local duration = auraInfo[i].duration
                    if not duration then
                        duration = calculateAuraDuration(pull, unit, auraInfo[i], i)
                        if not duration then
                            duration = maxDuration
                        end
                    end
                    local stacks = auraInfo[i].stacks or 0

                    if not byCaster[caster] then byCaster[caster] = {duration=0, count=0, maxStacks=0} end
                    if duration > 0 then
                        byCaster[caster].duration = byCaster[caster].duration + duration
                        byCaster[caster].count = byCaster[caster].count + 1
                        byCaster[caster].maxStacks = max(byCaster[caster].maxStacks, stacks)
                    end
                end
            end
        end
        for casterGuid,info in pairs(byCaster) do
            if info.duration > maxDuration then
                info.duration = maxDuration
            end
            result[#result+1] = { N = info.count, M = info.maxStacks, id = auraId, data = { uptime = calculateUptime(info.duration, maxDuration) or 0, caster = casterGuid } }
        end
    end
    return result
end

local function hasBuff(unit)
    for _,auraInfo in pairs(unit.auras) do
        for i=1,#auraInfo do
            if auraInfo[i].isBuff == true then return true end
        end
    end
    return nil
end

function WDBuffMonitor:init(parent, name)
    WD.Monitor.init(self, parent, name)
    WDBAM = self.frame
    WDBAM.parent = self
end

function WDBuffMonitor:initMainTable()
    WD.Monitor.initMainTable(self, "buffs", "Gained buffs info", 1, -50, 300, 20)
end

function WDBuffMonitor:initDataTable()
    local columns = {
        [1] = {"Buff",      300},
        [2] = {"Uptime",    60},
        [3] = {"Count",     40},
        [4] = {"Max Stacks",40},
        [5] = {"Casted by", 270},
    }
    WD.Monitor.initDataTable(self, "buffs", columns)

    self.nameFilter = WdLib.gui:createEditBox(self.frame:GetParent())
    self.nameFilter:SetSize(self.frame.dataTable.headers[#columns]:GetSize())
    self.nameFilter:SetPoint("BOTTOMLEFT", self.frame.dataTable.headers[#columns], "TOPLEFT", 0, 1)
    self.nameFilter:SetMaxLetters(15)
    self.nameFilter:SetScript("OnChar", function(f) self:updateDataTable() end)
    self.nameFilter:SetScript("OnEnterPressed", function(f) f:ClearFocus() self:updateDataTable() end)
    self.nameFilter:SetScript("OnEscapePressed", function(f) f:ClearFocus() end)
end

function WDBuffMonitor:getMainTableData()
    local units = {}
    if not WD.db.profile.tracker or not WD.db.profile.tracker.selected or WD.db.profile.tracker.selected > #WD.db.profile.tracker or #WD.db.profile.tracker == 0 then
        return units
    end
    for k,v in pairs(WD.db.profile.tracker[WD.db.profile.tracker.selected]) do
        if k == "npc" and self.npcFilter:GetChecked() then
            for npcId,data in pairs(v) do
                for guid,npc in pairs(data) do
                    if type(npc) == "table" then
                        if hasBuff(npc) then
                            npc.npc_id = npcId
                            units[#units+1] = npc
                        end
                    end
                end
            end
        elseif k == "players" and self.playersFilter:GetChecked() then
            for guid,raider in pairs(v) do
                if hasBuff(raider) then
                    units[#units+1] = raider
                end
            end
        end
    end
    return units
end

function WDBuffMonitor:getMainTableSortFunction()
    return function(a, b)
        return a.name < b.name
    end
end

function WDBuffMonitor:getMainTableRowText(v)
    local unitName = WdLib.gen:getColoredName(v.name, v.class)
    if v.rt > 0 then unitName = WdLib.gui:getRaidTargetTextureLink(v.rt).." "..unitName end
    return unitName
end

function WDBuffMonitor:getMainTableRowHover(v)
    if v.type == "creature" then
        return "id: "..v.npc_id
    end
    return nil
end

function WDBuffMonitor:updateDataTable(filter)
    for _,v in pairs(WDBAM.dataTable.members) do
        v:Hide()
    end

    local auras = {}
    if WDBAM.lastSelectedButton then
        local v = WDBAM.lastSelectedButton:GetParent().info
        auras = getFilteredBuffs(v, self.nameFilter:GetText())
    end

    local func = function(a, b)
        if a.data.uptime > b.data.uptime then return true
        elseif a.data.uptime < b.data.uptime then return false
        end
        if a.data.caster > b.data.caster then return true
        elseif a.data.caster < b.data.caster then return false
        end
        return a.id < b.id
    end
    table.sort(auras, func)


    local maxHeight = 210
    local topLeftPosition = { x = 30, y = -51 }
    local rowsN = #auras
    local columnsN = 5

    local function createFn(parent, row, index)
        local auraId = auras[row].id
        local N = auras[row].N
        local M = auras[row].M
        local v = auras[row].data
        if index == 1 then
            local f = WdLib.gui:addNextColumn(WDBAM.dataTable, parent, index, "LEFT", WdLib.gui:getSpellLinkByIdWithTexture(auraId))
            f:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
            WdLib.gui:generateSpellHover(f, WdLib.gui:getSpellLinkByIdWithTexture(auraId))
            return f
        elseif index == 2 then
            return WdLib.gui:addNextColumn(WDBAM.dataTable, parent, index, "RIGHT", v.uptime.." %")
        elseif index == 3 then
            return WdLib.gui:addNextColumn(WDBAM.dataTable, parent, index, "CENTER", N)
        elseif index == 4 then
            return WdLib.gui:addNextColumn(WDBAM.dataTable, parent, index, "CENTER", M)
        elseif index == 5 then
            local f = WdLib.gui:addNextColumn(WDBAM.dataTable, parent, index, "LEFT", getCasterName(v))
            WdLib.gui:generateSpellHover(f, getCasterName(v))
            return f
        end
    end

    local function updateFn(f, row, index)
        local auraId = auras[row].id
        local N = auras[row].N
        local M = auras[row].M
        local v = auras[row].data
        if index == 1 then
            f.txt:SetText(WdLib.gui:getSpellLinkByIdWithTexture(auraId))
            WdLib.gui:generateSpellHover(f, WdLib.gui:getSpellLinkByIdWithTexture(auraId))
        elseif index == 2 then
            f.txt:SetText(v.uptime.." %")
        elseif index == 3 then
            f.txt:SetText(N)
        elseif index == 4 then
            f.txt:SetText(M)
        elseif index == 5 then
            f.txt:SetText(getCasterName(v))
            WdLib.gui:generateSpellHover(f, getCasterName(v))
        end
    end

    WdLib.gui:updateScrollableTable(WDBAM.dataTable, maxHeight, topLeftPosition, rowsN, columnsN, createFn, updateFn)

    WDBAM.dataTable:Show()
end

WD.BuffMonitor = WDBuffMonitor