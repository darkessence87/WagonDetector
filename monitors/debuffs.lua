
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

function WDDebuffMonitor:init(parent, name)
    WD.Monitor.init(self, parent, name)
    WDDAM = self.frame
    WDDAM.parent = self
end

function WDDebuffMonitor:initButtons()
    WDDAM.debuffs = CreateFrame("Frame", nil, WDDAM)
    WDDAM.debuffs.headers = {}
    WDDAM.debuffs.members = {}
    table.insert(WDDAM.debuffs.headers, WdLib:createTableHeader(WDDAM:GetParent(), "Debuffs info", 1, -300, 300, 20))
end

function WDDebuffMonitor:initInfoTable()
    WDDAM.data["debuffs"] = CreateFrame("Frame", nil, WDDAM)
    local r = WDDAM.data["debuffs"]
    r:SetPoint("TOPLEFT", WDDAM.debuffs.headers[1], "TOPRIGHT", 1, 0)
    r:SetSize(550, 300)

    r.headers = {}
    r.members = {}

    -- headers
    local h = WdLib:createTableHeader(r, "Debuff", 0, 0, 250, 20)
    table.insert(r.headers, h)
    h = WdLib:createTableHeaderNext(r, h, "Uptime", 70, 20)
    table.insert(r.headers, h)
    h = WdLib:createTableHeaderNext(r, h, "Count", 40, 20)
    table.insert(r.headers, h)
    h = WdLib:createTableHeaderNext(r, h, "Casted by", 250, 20)
    table.insert(r.headers, h)

    r:Hide()
end

local function getFilteredDebuffs(auras)
    local result = {}
    local pull = WDDAM:GetParent().GetSelectedPull()
    if not pull then return result end
    local pullDuration = 0
    if pull.endTime and pull.startTime then
        pullDuration = pull.endTime - pull.startTime
    end

    local function calculateUptime(v, totalV)
        if not v or not totalV or totalV == 0 then return nil end
        return WdLib:float_round_to(v * 100 / totalV, 1)
    end

    for auraId,auraInfo in pairs(auras) do
        local byCaster = {}
        for i=1,#auraInfo do
            if auraInfo[i].isBuff == false then
                local caster = auraInfo[i].caster
                local duration = auraInfo[i].duration
                if not duration then
                    if pull.endTime then
                        local t = (pull.endTime - auraInfo[i].applied) / 1000
                        duration = WdLib:float_round_to(t * 1000, 2)
                    elseif i > 1 then
                        duration = 0
                    else
                        duration = pullDuration
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
            if info.duration > pullDuration then
                info.duration = pullDuration
            end
            result[#result+1] = { N = info.count, id = auraId, data = { uptime = calculateUptime(info.duration, pullDuration) or 0, caster = casterGuid } }
        end
    end
    return result
end

local function getDebuffStatusText(v)
    local casterName = UNKNOWNOBJECT
    local caster = WDDAM.parent:findEntityByGUID(v.caster)
    if caster then
        casterName = WdLib:getColoredName(WdLib:getShortName(caster.name, "noRealm"), caster.class)
    else
        casterName = "|cffffffffEnvironment|r"
    end
    return string.format(WD_TRACKER_AURA_CASTED_BY, casterName)
end

local function updateDebuffInfo()
    for _,v in pairs(WDDAM.data["debuffs"].members) do
        v:Hide()
    end

    local auras = {}
    if WDDAM.lastSelectedButton then
        local v = WDDAM.lastSelectedButton:GetParent().info
        auras = getFilteredDebuffs(v.auras)
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
            local f = WdLib:addNextColumn(WDDAM.data["debuffs"], parent, index, "LEFT", WdLib:getSpellLinkByIdWithTexture(auraId))
            f:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
            WdLib:generateSpellHover(f, WdLib:getSpellLinkByIdWithTexture(auraId))
            return f
        elseif index == 2 then
            return WdLib:addNextColumn(WDDAM.data["debuffs"], parent, index, "RIGHT", v.uptime.." %")
        elseif index == 3 then
            return WdLib:addNextColumn(WDDAM.data["debuffs"], parent, index, "CENTER", N)
        elseif index == 4 then
            local f = WdLib:addNextColumn(WDDAM.data["debuffs"], parent, index, "LEFT", getDebuffStatusText(v))
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

    WdLib:updateScrollableTable(WDDAM.data["debuffs"], maxHeight, topLeftPosition, rowsN, columnsN, createFn, updateFn)

    WDDAM.data["debuffs"]:Show()
end

local function updateUnitButtons()
    for _,v in pairs(WDDAM.debuffs.members) do
        v.column[1].t:SetColorTexture(.2, .2, .2, 1)
    end

    if WDDAM.lastSelectedButton then
        WDDAM.lastSelectedButton.t:SetColorTexture(.2, .6, .2, 1)
    end
    updateDebuffInfo()
end

local function hasDebuff(unit)
    for _,auraInfo in pairs(unit.auras) do
        for i=1,#auraInfo do
            if auraInfo[i].isBuff == false then return true end
        end
    end
    return nil
end

local function getUnitsWithDebuffs()
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

function WDDebuffMonitor:refreshInfo()
    if not WDDAM then return end

    local units = getUnitsWithDebuffs()

    if WDDAM.lastSelectedButton and #units == 0 then
        WDDAM.lastSelectedButton = nil
        updateDebuffInfo()
    end

    local maxHeight = 210
    local topLeftPosition = { x = 30, y = -51 }
    local rowsN = #units
    local columnsN = 1

    local func = function(a, b)
        return a.name < b.name
    end
    table.sort(units, func)

    local function createFn(parent, row, index)
        local v = units[row]
        parent.info = v
        if index == 1 then
            local unitName = WdLib:getColoredName(v.name, v.class)
            if v.rt > 0 then unitName = WdLib:getRaidTargetTextureLink(v.rt).." "..unitName end
            local f = WdLib:addNextColumn(WDDAM.debuffs, parent, index, "LEFT", unitName)
            f:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
            f:EnableMouse(true)
            f:SetScript("OnClick", function(self) WDDAM.lastSelectedButton = self; updateUnitButtons() end)
            if v.type == "creature" then
                WdLib:generateHover(f, "id: "..v.npc_id)
            end
            return f
        end
    end

    local function updateFn(f, row, index)
        local v = units[row]
        f:GetParent().info = v
        if index == 1 then
            local unitName = WdLib:getColoredName(v.name, v.class)
            if v.rt > 0 then unitName = WdLib:getRaidTargetTextureLink(v.rt).." "..unitName end
            f.txt:SetText(unitName)
            f:SetScript("OnClick", function(self) WDDAM.lastSelectedButton = self; updateUnitButtons() end)
            if v.type == "creature" then
                WdLib:generateHover(f, "id: "..v.npc_id)
            end
        end
    end

    WdLib:updateScrollableTable(WDDAM.debuffs, maxHeight, topLeftPosition, rowsN, columnsN, createFn, updateFn)

    if not WDDAM.lastSelectedButton and #units > 0 then
        WDDAM.lastSelectedButton = WDDAM.debuffs.members[1].column[1]
    end
    updateUnitButtons()
end

WD.DebuffMonitor = WDDebuffMonitor