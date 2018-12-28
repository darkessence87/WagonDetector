
local WDDAM = nil

local WDDebuffMonitor = {}
WDDebuffMonitor.__index = WDDebuffMonitor

setmetatable(WDDebuffMonitor, {
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
    return WdLib:float_round_to(v * 100 / totalV, 1)
end

local function calculateAuraDuration(pull, unit, aura, index)
    if unit.diedAt or pull.endTime then
        local toTime = unit.diedAt or pull.endTime or 0
        if toTime > 0 then
            local t = (toTime - aura.applied) / 1000
            return WdLib:float_round_to(t * 1000, 2)
        end
    end
    if index > 1 then
        return 0
    end
    return nil
end

local function getFilteredDebuffs(unit)
    local result = {}
    local pull = WDDAM:GetParent().GetSelectedPull()
    if not pull then return result end

    local maxDuration = calculateLifetime(pull, unit)

    for auraId,auraInfo in pairs(unit.auras) do
        local byCaster = {}
        for i=1,#auraInfo do
            if auraInfo[i].isBuff == false then
                local caster = auraInfo[i].caster
                local duration = auraInfo[i].duration
                if not duration then
                    duration = calculateAuraDuration(pull, unit, auraInfo[i], i)
                    if not duration then
                        duration = maxDuration
                    end
                end

                if not byCaster[caster] then byCaster[caster] = {duration=0, count=0} end
                if duration > 0 then
                    byCaster[caster].duration = byCaster[caster].duration + duration
                    byCaster[caster].count = byCaster[caster].count + 1
                end
            end
        end
        for casterGuid,info in pairs(byCaster) do
            if info.duration > maxDuration then
                info.duration = maxDuration
            end
            result[#result+1] = { N = info.count, id = auraId, data = { uptime = calculateUptime(info.duration, maxDuration) or 0, caster = casterGuid } }
        end
    end
    return result
end

local function getDebuffStatusText(v)
    local casterName = UNKNOWNOBJECT
    local caster = WDDAM.parent:findEntityByGUID(v.caster)
    if caster then
        casterName = WdLib:getColoredName(WdLib:getShortName(caster.name), caster.class)
    else
        casterName = "|cffffffffEnvironment|r"
    end
    return casterName
end

local function hasDebuff(unit)
    for _,auraInfo in pairs(unit.auras) do
        for i=1,#auraInfo do
            if auraInfo[i].isBuff == false then return true end
        end
    end
    return nil
end

function WDDebuffMonitor:init(parent, name)
    WD.Monitor.init(self, parent, name)
    WDDAM = self.frame
    WDDAM.parent = self
end

function WDDebuffMonitor:initMainTable()
    WD.Monitor.initMainTable(self, "debuffs", "Debuffs info", 1, -300, 300, 20)
end

function WDDebuffMonitor:initDataTable()
    local columns = {
        [1] = {"Debuff",    300},
        [2] = {"Uptime",    70},
        [3] = {"Count",     40},
        [4] = {"Casted by", 300},
    }
    WD.Monitor.initDataTable(self, "debuffs", columns)
end

function WDDebuffMonitor:getMainTableData()
    local units = {}
    if not WD.db.profile.tracker or not WD.db.profile.tracker.selected or WD.db.profile.tracker.selected > #WD.db.profile.tracker or #WD.db.profile.tracker == 0 then
        return units
    end
    for k,v in pairs(WD.db.profile.tracker[WD.db.profile.tracker.selected]) do
        if k == "npc" then
            for npcId,data in pairs(v) do
                for guid,npc in pairs(data) do
                    if type(npc) == "table" then
                        if hasDebuff(npc) then
                            npc.npc_id = npcId
                            units[#units+1] = npc
                        end
                    end
                end
            end
        elseif k == "players" then
            for guid,raider in pairs(v) do
                if hasDebuff(raider) then
                    units[#units+1] = raider
                end
            end
        end
    end
    return units
end

function WDDebuffMonitor:getMainTableSortFunction()
    return function(a, b)
        return a.name < b.name
    end
end

function WDDebuffMonitor:getMainTableRowText(v)
    local unitName = WdLib:getColoredName(v.name, v.class)
    if v.rt > 0 then unitName = WdLib:getRaidTargetTextureLink(v.rt).." "..unitName end
    return unitName
end

function WDDebuffMonitor:getMainTableRowHover(v)
    if v.type == "creature" then
        return "id: "..v.npc_id
    end
    return nil
end

function WDDebuffMonitor:updateDataTable()
    for _,v in pairs(WDDAM.dataTable.members) do
        v:Hide()
    end

    local auras = {}
    if WDDAM.lastSelectedButton then
        local v = WDDAM.lastSelectedButton:GetParent().info
        auras = getFilteredDebuffs(v)
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
    local columnsN = 4

    local function createFn(parent, row, index)
        local auraId = auras[row].id
        local N = auras[row].N
        local v = auras[row].data
        if index == 1 then
            local f = WdLib:addNextColumn(WDDAM.dataTable, parent, index, "LEFT", WdLib:getSpellLinkByIdWithTexture(auraId))
            f:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
            WdLib:generateSpellHover(f, WdLib:getSpellLinkByIdWithTexture(auraId))
            return f
        elseif index == 2 then
            return WdLib:addNextColumn(WDDAM.dataTable, parent, index, "RIGHT", v.uptime.." %")
        elseif index == 3 then
            return WdLib:addNextColumn(WDDAM.dataTable, parent, index, "CENTER", N)
        elseif index == 4 then
            local f = WdLib:addNextColumn(WDDAM.dataTable, parent, index, "LEFT", getDebuffStatusText(v))
            WdLib:generateSpellHover(f, getDebuffStatusText(v))
            return f
        end
    end

    local function updateFn(f, row, index)
        local auraId = auras[row].id
        local N = auras[row].N
        local v = auras[row].data
        if index == 1 then
            f.txt:SetText(WdLib:getSpellLinkByIdWithTexture(auraId))
            WdLib:generateSpellHover(f, WdLib:getSpellLinkByIdWithTexture(auraId))
        elseif index == 2 then
            f.txt:SetText(v.uptime.." %")
        elseif index == 3 then
            f.txt:SetText(N)
        elseif index == 4 then
            f.txt:SetText(getDebuffStatusText(v))
            WdLib:generateSpellHover(f, getDebuffStatusText(v))
        end
    end

    WdLib:updateScrollableTable(WDDAM.dataTable, maxHeight, topLeftPosition, rowsN, columnsN, createFn, updateFn)

    WDDAM.dataTable:Show()
end

WD.DebuffMonitor = WDDebuffMonitor