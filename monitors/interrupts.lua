
local WDIM = nil

local WDInterruptMonitor = {}
WDInterruptMonitor.__index = WDInterruptMonitor

setmetatable(WDInterruptMonitor, {
    __index = WD.Monitor,
    __call = function (v, ...)
        local self = setmetatable({}, v)
        self:init(...)
        return self
    end,
})

local function getInterruptStatusText(v)
    if v.status == "INTERRUPTED" then
        local interrupterName = UNKNOWNOBJECT
        if type(v.interrupter) == "table" then
            interrupterName = WdLib.gen:getColoredName(WdLib.gen:getShortName(v.interrupter.name, "noRealm"), v.interrupter.class)
        else
            local interrupter = WDIM.parent:findEntityByGUID(v.interrupter)
            if interrupter then
                interrupterName = WdLib.gen:getColoredName(WdLib.gen:getShortName(interrupter.name, "noRealm"), interrupter.class)
            end
        end
        return string.format(WD_TRACKER_INTERRUPTED_BY, interrupterName, WdLib.gui:getSpellLinkByIdWithTexture(v.spell_id), v.timediff)
    elseif v.status == "SUCCESS" then
        return string.format(WD_TRACKER_CASTED_IN, v.timediff)
    end

    return v.status
end

local function isCastedNpc(v)
    for spell_id,castInfo in pairs(v.casts) do
        if type(castInfo) == "table" and #castInfo > 0 then
            return true
        end
    end
    return nil
end

function WDInterruptMonitor:init(parent, name)
    WD.Monitor.init(self, parent, name)
    WDIM = self.frame
    WDIM.parent = self
end

function WDInterruptMonitor:initMainTable()
    WD.Monitor.initMainTable(self, "interrupts", "Casts info", 1, -50, 300, 20)
    WDIM.creatures = WDIM.tables["interrupts"]
end

function WDInterruptMonitor:initDataTable()
    local columns = {
        [1] = {"Spell",         170},
        [2] = {WD_BUTTON_TIME,  70},
        [3] = {"N",             25},
        [4] = {"Status",        400},
        [5] = {"Quality",       50},
    }
    WD.Monitor.initDataTable(self, "interrupts", columns)
    WdLib.gui:generateHover(WDIM.dataTable.headers[5], WD_TRACKER_QUALITY_DESC)
end

function WDInterruptMonitor:getMainTableData()
    local creatures = {}
    if not WD.db.profile.tracker or not WD.db.profile.tracker.selected or WD.db.profile.tracker.selected > #WD.db.profile.tracker or #WD.db.profile.tracker == 0 then
        return creatures
    end

    for k,v in pairs(WD.db.profile.tracker[WD.db.profile.tracker.selected]) do
        if k == "npc" and self.npcFilter:GetChecked() then
            for npcId,data in pairs(v) do
                for _,npc in pairs(data) do
                    if type(npc) == "table" then
                        if isCastedNpc(npc) then
                            local npcCopy = WdLib.table:deepcopy(npc)
                            npcCopy.npc_id = npcId
                            creatures[#creatures+1] = npcCopy
                        end
                    end
                end
            end
        elseif k == "pets" then
            for parentGuid,info in pairs(v) do
                if parentGuid:match("Creature") then
                    for npcId,data in pairs(info) do
                        for _,pet in pairs(data) do
                            --print(WdLib.table:tostring(pet))
                            if isCastedNpc(pet) then
                                local petCopy = WdLib.table:deepcopy(pet)
                                petCopy.npc_id = npcId
                                petCopy.name = "[pet] "..petCopy.name
                                creatures[#creatures+1] = petCopy
                            end
                        end
                    end
                end
            end
        --[[elseif k == "players" then
            for guid,pl in pairs(v) do
                if type(pl) == "table" then
                    if isCastedNpc(pl) then
                        local plCopy = WdLib.table:deepcopy(pl)
                        plCopy.npc_id = "player"
                        creatures[#creatures+1] = plCopy
                    end
                end
            end]]
        end
    end
    return creatures
end

function WDInterruptMonitor:getMainTableSortFunction()
    return function(a, b)
        return a.name < b.name
    end
end

function WDInterruptMonitor:getMainTableRowText(v)
    local unitName = WdLib.gen:getColoredName(v.name, v.class)
    if v.rt > 0 then unitName = WdLib.gui:getRaidTargetTextureLink(v.rt).." "..unitName end
    return unitName
end

function WDInterruptMonitor:getMainTableRowHover(v)
    if v.parentName then
        return {"id: "..v.npc_id, "Summoned by: |cffffff00"..v.parentName.."|r"}
    else
        return "id: "..v.npc_id
    end
    return nil
end

function WDInterruptMonitor:updateDataTable()
    for _,v in pairs(WDIM.dataTable.members) do
        v:Hide()
    end

    local casts = {}
    if WDIM.lastSelectedButton then
        local v = WDIM.lastSelectedButton:GetParent().info
        for spellId,castInfo in pairs(v.casts) do
            if type(castInfo) == "table" then
                for i=1,#castInfo do
                    casts[#casts+1] = { N = i, id = spellId, data = castInfo[i] }
                end
            end
        end
    end

    local maxHeight = 210
    local topLeftPosition = { x = 30, y = -51 }
    local rowsN = #casts
    local columnsN = 5

    local function createFn(parent, row, index)
        local spellId = casts[row].id
        local N = casts[row].N
        local v = casts[row].data
        if index == 1 then
            local f = WdLib.gui:addNextColumn(WDIM.dataTable, parent, index, "LEFT", WdLib.gui:getSpellLinkByIdWithTexture(spellId))
            f:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
            WdLib.gui:generateSpellHover(f, WdLib.gui:getSpellLinkByIdWithTexture(spellId))
            return f
        elseif index == 2 then
            return WdLib.gui:addNextColumn(WDIM.dataTable, parent, index, "CENTER", v.timestamp)
        elseif index == 3 then
            return WdLib.gui:addNextColumn(WDIM.dataTable, parent, index, "CENTER", N)
        elseif index == 4 then
            local f = WdLib.gui:addNextColumn(WDIM.dataTable, parent, index, "LEFT", getInterruptStatusText(v))
            WdLib.gui:generateSpellHover(f, getInterruptStatusText(v))
            return f
        elseif index == 5 then
            return WdLib.gui:addNextColumn(WDIM.dataTable, parent, index, "CENTER", v.percent or 0)
        end
    end

    local function updateFn(f, row, index)
        local spellId = casts[row].id
        local N = casts[row].N
        local v = casts[row].data
        if index == 1 then
            f.txt:SetText(WdLib.gui:getSpellLinkByIdWithTexture(spellId))
            WdLib.gui:generateSpellHover(f, WdLib.gui:getSpellLinkByIdWithTexture(spellId))
        elseif index == 2 then
            f.txt:SetText(v.timestamp)
        elseif index == 3 then
            f.txt:SetText(N)
        elseif index == 4 then
            f.txt:SetText(getInterruptStatusText(v))
            WdLib.gui:generateSpellHover(f, getInterruptStatusText(v))
        elseif index == 5 then
            f.txt:SetText(v.percent or 0)
        end
    end

    WdLib.gui:updateScrollableTable(WDIM.dataTable, maxHeight, topLeftPosition, rowsN, columnsN, createFn, updateFn)

    WDIM.dataTable:Show()
end

WD.InterruptMonitor = WDInterruptMonitor