
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

function WDDispelMonitor:init(parent, name)
    WD.Monitor.init(self, parent, name)
    WDDM = self.frame
    WDDM.parent = self
end

function WDDispelMonitor:initButtons()
    WD.Monitor.initButtons(self, "dispel", "Dispel info", 1, -300, 300, 20)
    WDDM.dispels = WDDM.tables["dispel"]
end

function WDDispelMonitor:initInfoTable()
    local columns = {
        [1] = {"Aura",          170},
        [2] = {WD_BUTTON_TIME,  70},
        [3] = {"N",             25},
        [4] = {"Status",        450},
    }
    WD.Monitor.initInfoTable(self, "dispel", columns)
end

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

local function updateDispelInfo()
    for _,v in pairs(WDDM.data["dispel"].members) do
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
            local f = WdLib:addNextColumn(WDDM.data["dispel"], parent, index, "LEFT", WdLib:getSpellLinkByIdWithTexture(auraId))
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
            return WdLib:addNextColumn(WDDM.data["dispel"], parent, index, "CENTER", v.dispelledAt)
        elseif index == 3 then
            return WdLib:addNextColumn(WDDM.data["dispel"], parent, index, "CENTER", N)
        elseif index == 4 then
            local f = WdLib:addNextColumn(WDDM.data["dispel"], parent, index, "LEFT", getDispelStatusText(v))
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

    WdLib:updateScrollableTable(WDDM.data["dispel"], maxHeight, topLeftPosition, rowsN, columnsN, createFn, updateFn)

    WDDM.data["dispel"]:Show()
end

local function updateDispelButtons()
    for _,v in pairs(WDDM.dispels.members) do
        v.column[1].t:SetColorTexture(.2, .2, .2, 1)
    end

    if WDDM.lastSelectedButton then
        WDDM.lastSelectedButton.t:SetColorTexture(.2, .6, .2, 1)
    end
    updateDispelInfo()
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

local function getDispelledUnits()
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

function WDDispelMonitor:refreshInfo()
    if not WDDM then return end

    local dispels = getDispelledUnits()

    if WDDM.lastSelectedButton and #dispels == 0 then
        WDDM.lastSelectedButton = nil
        updateDispelInfo()
    end

    local maxHeight = 210
    local topLeftPosition = { x = 30, y = -51 }
    local rowsN = #dispels
    local columnsN = 1

    local func = function(a, b)
        return a.name < b.name
    end
    table.sort(dispels, func)

    local function createFn(parent, row, index)
        local v = dispels[row]
        parent.info = v
        if index == 1 then
            local unitName = WdLib:getColoredName(v.name, v.class)
            if v.rt > 0 then unitName = WdLib:getRaidTargetTextureLink(v.rt).." "..unitName end
            local f = WdLib:addNextColumn(WDDM.dispels, parent, index, "LEFT", unitName)
            f:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
            f:EnableMouse(true)
            f:SetScript("OnClick", function(self) WDDM.lastSelectedButton = self; updateDispelButtons() end)
            if v.type == "creature" then
                WdLib:generateHover(f, "id: "..v.npc_id)
            end
            return f
        end
    end

    local function updateFn(f, row, index)
        local v = dispels[row]
        f:GetParent().info = v
        if index == 1 then
            local unitName = WdLib:getColoredName(v.name, v.class)
            if v.rt > 0 then unitName = WdLib:getRaidTargetTextureLink(v.rt).." "..unitName end
            f.txt:SetText(unitName)
            f:SetScript("OnClick", function(self) WDDM.lastSelectedButton = self; updateDispelButtons() end)
            if v.type == "creature" then
                WdLib:generateHover(f, "id: "..v.npc_id)
            end
        end
    end

    WdLib:updateScrollableTable(WDDM.dispels, maxHeight, topLeftPosition, rowsN, columnsN, createFn, updateFn)

    if not WDDM.lastSelectedButton and #dispels > 0 then
        WDDM.lastSelectedButton = WDDM.dispels.members[1].column[1]
    end
    updateDispelButtons()
end

WD.DispelMonitor = WDDispelMonitor