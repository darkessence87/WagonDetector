
local WDDM = nil

local WDDispelMonitor = {}
WDDispelMonitor.__index = WDDispelMonitor

setmetatable(WDDispelMonitor, {
    __index = WD.Monitor,
    __call = function (v, ...)
        local self = setmetatable({}, v)
        self:init(...)
        return self
    end,
})

local function getDispelledAuras(auras)
    local result = {}
    for auraId,auraInfo in pairs(auras) do
        for i=1,#auraInfo do
            if auraInfo[i].dispell_id then
                result[#result+1] = { N = i, id = auraId, data = auraInfo[i] }
            end
        end
    end
    return result
end

local function getDispelStatusText(v)
    local dispellerName = UNKNOWNOBJECT
    if type(v.dispeller) == "table" then
        dispellerName = WdLib:getColoredName(WdLib:getShortName(v.dispeller.name, "noRealm"), v.dispeller.class)
    else
        local dispeller = WDDM.parent:findEntityByGUID(v.dispeller)
        if dispeller then
            dispellerName = WdLib:getColoredName(WdLib:getShortName(dispeller.name, "noRealm"), dispeller.class)
        end
    end
    return string.format(WD_TRACKER_DISPELLED_BY, dispellerName, WdLib:getSpellLinkByIdWithTexture(v.dispell_id), v.dispelledIn)
end

local function isDispelledUnit(v)
    for auraId,auraInfo in pairs(v.auras) do
        for _,aura in pairs(auraInfo) do
            if aura.dispell_id then
                return true
            end
        end
    end
    return nil
end

function WDDispelMonitor:init(parent, name)
    WD.Monitor.init(self, parent, name)
    WDDM = self.frame
    WDDM.parent = self
end

function WDDispelMonitor:initMainTable()
    WD.Monitor.initMainTable(self, "dispel", "Dispel info", 1, -310, 300, 20)
    WDDM.dispels = WDDM.tables["dispel"]
end

function WDDispelMonitor:initDataTable()
    local columns = {
        [1] = {"Aura",          170},
        [2] = {WD_BUTTON_TIME,  70},
        [3] = {"N",             25},
        [4] = {"Status",        450},
    }
    WD.Monitor.initDataTable(self, "dispel", columns)
end

function WDDispelMonitor:getMainTableData()
    local units = {}
    if not WD.db.profile.tracker or not WD.db.profile.tracker.selected or WD.db.profile.tracker.selected > #WD.db.profile.tracker or #WD.db.profile.tracker == 0 then
        return units
    end
    for k,v in pairs(WD.db.profile.tracker[WD.db.profile.tracker.selected]) do
        if k == "npc" then
            for npcId,data in pairs(v) do
                for guid,npc in pairs(data) do
                    if type(npc) == "table" then
                        if isDispelledUnit(npc) then
                            npc.npc_id = npcId
                            units[#units+1] = npc
                        end
                    end
                end
            end
        elseif k == "players" then
            for guid,raider in pairs(v) do
                if isDispelledUnit(raider) then
                    units[#units+1] = raider
                end
            end
        end
    end
    return units
end

function WDDispelMonitor:getMainTableSortFunction()
    return function(a, b)
        return a.name < b.name
    end
end

function WDDispelMonitor:getMainTableRowText(v)
    local unitName = WdLib:getColoredName(v.name, v.class)
    if v.rt > 0 then unitName = WdLib:getRaidTargetTextureLink(v.rt).." "..unitName end
    return unitName
end

function WDDispelMonitor:getMainTableRowHover(v)
    if v.type == "creature" then
        return "id: "..v.npc_id
    end
    return nil
end

function WDDispelMonitor:updateDataTable()
    for _,v in pairs(WDDM.dataTable.members) do
        v:Hide()
    end

    local auras = {}
    if WDDM.lastSelectedButton then
        local v = WDDM.lastSelectedButton:GetParent().info
        auras = getDispelledAuras(v.auras)
    end

    local maxHeight = 210
    local topLeftPosition = { x = 30, y = -51 }
    local rowsN = #auras
    local columnsN = 4

    local function createFn(parent, row, index)
        local auraId = auras[row].id
        local N = auras[row].N
        local v = auras[row].data
        if index == 1 then
            local f = WdLib:addNextColumn(WDDM.dataTable, parent, index, "LEFT", WdLib:getSpellLinkByIdWithTexture(auraId))
            f:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
            local caster = WDDM.parent:findEntityByGUID(v.caster)
            if caster then
                caster = WdLib:getColoredName(WdLib:getShortName(caster.name, "noRealm"), caster.class)
            else
                caster = "|cffffffffEnvironment|r"
            end
            WdLib:generateSpellHover(f, WdLib:getSpellLinkByIdWithTexture(auraId), "|cffffff00Casted by:|r "..caster)
            return f
        elseif index == 2 then
            return WdLib:addNextColumn(WDDM.dataTable, parent, index, "CENTER", v.dispelledAt)
        elseif index == 3 then
            return WdLib:addNextColumn(WDDM.dataTable, parent, index, "CENTER", N)
        elseif index == 4 then
            local f = WdLib:addNextColumn(WDDM.dataTable, parent, index, "LEFT", getDispelStatusText(v))
            WdLib:generateSpellHover(f, getDispelStatusText(v))
            return f
        end
    end

    local function updateFn(f, row, index)
        local auraId = auras[row].id
        local N = auras[row].N
        local v = auras[row].data
        if index == 1 then
            f.txt:SetText(WdLib:getSpellLinkByIdWithTexture(auraId))
            local caster = WDDM.parent:findEntityByGUID(v.caster)
            if caster then
                caster = WdLib:getColoredName(WdLib:getShortName(caster.name, "noRealm"), caster.class)
            else
                caster = "|cffffffffEnvironment|r"
            end
            WdLib:generateSpellHover(f, WdLib:getSpellLinkByIdWithTexture(auraId), "|cffffff00Casted by:|r "..caster)
        elseif index == 2 then
            f.txt:SetText(v.dispelledAt)
        elseif index == 3 then
            f.txt:SetText(N)
        elseif index == 4 then
            f.txt:SetText(getDispelStatusText(v))
            WdLib:generateSpellHover(f, getDispelStatusText(v))
        end
    end

    WdLib:updateScrollableTable(WDDM.dataTable, maxHeight, topLeftPosition, rowsN, columnsN, createFn, updateFn)

    WDDM.dataTable:Show()
end

WD.DispelMonitor = WDDispelMonitor