
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

function WDInterruptMonitor:init(parent, name)
    WD.Monitor.init(self, parent, name)
    WDIM = self.frame
    WDIM.parent = self
end

function WDInterruptMonitor:initButtons()
    WD.Monitor.initButtons(self, "interrupts", "Casts info", 1, -30, 300, 20)
    WDIM.creatures = WDIM.tables["interrupts"]
end

function WDInterruptMonitor:initInfoTable()
    local columns = {
        [1] = {"Spell",         170},
        [2] = {WD_BUTTON_TIME,  70},
        [3] = {"N",             25},
        [4] = {"Status",        400},
        [5] = {"Quality",       50},
    }
    WD.Monitor.initInfoTable(self, "interrupts", columns)
    WdLib:generateHover(WDIM.data["interrupts"].headers[5], WD_TRACKER_QUALITY_DESC)
end

local function getInterruptStatusText(v)
    if v.status == "INTERRUPTED" then
        local interrupterName = UNKNOWNOBJECT
        if type(v.interrupter) == "table" then
            interrupterName = WdLib:getColoredName(WdLib:getShortName(v.interrupter.name, "noRealm"), v.interrupter.class)
        else
            local interrupter = WDIM.parent:findEntityByGUID(v.interrupter)
            if interrupter then
                interrupterName = WdLib:getColoredName(WdLib:getShortName(interrupter.name, "noRealm"), interrupter.class)
            end
        end
        return string.format(WD_TRACKER_INTERRUPTED_BY, interrupterName, WdLib:getSpellLinkByIdWithTexture(v.spell_id), v.timediff)
    elseif v.status == "SUCCESS" then
        return string.format(WD_TRACKER_CASTED_IN, v.timediff)
    end

    return v.status
end

local function updateInterruptsInfo()
    for _,v in pairs(WDIM.data["interrupts"].members) do
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
            local f = WdLib:addNextColumn(WDIM.data["interrupts"], parent, index, "LEFT", WdLib:getSpellLinkByIdWithTexture(spellId))
            f:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
            WdLib:generateSpellHover(f, WdLib:getSpellLinkByIdWithTexture(spellId))
            return f
        elseif index == 2 then
            return WdLib:addNextColumn(WDIM.data["interrupts"], parent, index, "CENTER", v.timestamp)
        elseif index == 3 then
            return WdLib:addNextColumn(WDIM.data["interrupts"], parent, index, "CENTER", N)
        elseif index == 4 then
            local f = WdLib:addNextColumn(WDIM.data["interrupts"], parent, index, "LEFT", getInterruptStatusText(v))
            WdLib:generateSpellHover(f, getInterruptStatusText(v))
            return f
        elseif index == 5 then
            return WdLib:addNextColumn(WDIM.data["interrupts"], parent, index, "CENTER", v.percent or 0)
        end
    end

    local function updateFn(f, row, index)
        local spellId = casts[row].id
        local N = casts[row].N
        local v = casts[row].data
        if index == 1 then
            f.txt:SetText(WdLib:getSpellLinkByIdWithTexture(spellId))
            WdLib:generateSpellHover(f, WdLib:getSpellLinkByIdWithTexture(spellId))
        elseif index == 2 then
            f.txt:SetText(v.timestamp)
        elseif index == 3 then
            f.txt:SetText(N)
        elseif index == 4 then
            f.txt:SetText(getInterruptStatusText(v))
            WdLib:generateSpellHover(f, getInterruptStatusText(v))
        elseif index == 5 then
            f.txt:SetText(v.percent or 0)
        end
    end

    WdLib:updateScrollableTable(WDIM.data["interrupts"], maxHeight, topLeftPosition, rowsN, columnsN, createFn, updateFn)

    WDIM.data["interrupts"]:Show()
end

local function updateCreatureButtons()
    for _,v in pairs(WDIM.creatures.members) do
        v.column[1].t:SetColorTexture(.2, .2, .2, 1)
    end

    if WDIM.lastSelectedButton then
        WDIM.lastSelectedButton.t:SetColorTexture(.2, .6, .2, 1)
    end
    updateInterruptsInfo()
end

local function isCastedNpc(v)
    for spell_id,castInfo in pairs(v.casts) do
        if type(castInfo) == "table" and #castInfo > 0 then
            return true
        end
    end
    return nil
end

local function getCastedCreatures()
    local creatures = {}
    if not WD.db.profile.tracker or not WD.db.profile.tracker.selected or WD.db.profile.tracker.selected > #WD.db.profile.tracker or #WD.db.profile.tracker == 0 then
        return creatures
    end

    for k,v in pairs(WD.db.profile.tracker[WD.db.profile.tracker.selected]) do
        if k == "npc" then
            for npcId,data in pairs(v) do
                for _,npc in pairs(data) do
                    if type(npc) == "table" then
                        if isCastedNpc(npc) then
                            local npcCopy = WdLib:table_deepcopy(npc)
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
                            --print(WdLib:table_tostring(pet))
                            if isCastedNpc(pet) then
                                local petCopy = WdLib:table_deepcopy(pet)
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
                        local plCopy = WdLib:table_deepcopy(pl)
                        plCopy.npc_id = "player"
                        creatures[#creatures+1] = plCopy
                    end
                end
            end]]
        end
    end
    return creatures
end

function WDInterruptMonitor:refreshInfo()
    if not WDIM then return end

    local creatures = getCastedCreatures()

    if WDIM.lastSelectedButton and #creatures == 0 then
        WDIM.lastSelectedButton = nil
        updateInterruptsInfo()
    end

    local maxHeight = 210
    local topLeftPosition = { x = 30, y = -51 }
    local rowsN = #creatures
    local columnsN = 1

    local func = function(a, b)
        return a.name < b.name
    end
    table.sort(creatures, func)

    local function createFn(parent, row, index)
        local v = creatures[row]
        parent.info = v
        if index == 1 then
            local unitName = WdLib:getColoredName(v.name, v.class)
            if v.rt > 0 then unitName = WdLib:getRaidTargetTextureLink(v.rt).." "..unitName end
            local f = WdLib:addNextColumn(WDIM.creatures, parent, index, "LEFT", unitName)
            f:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
            f:EnableMouse(true)
            f:SetScript("OnClick", function(self) WDIM.lastSelectedButton = self; updateCreatureButtons() end)
            if v.parentName then
                WdLib:generateHover(f, {"id: "..v.npc_id, "Summoned by: |cffffff00"..v.parentName.."|r"})
            else
                WdLib:generateHover(f, "id: "..v.npc_id)
            end
            return f
        end
    end

    local function updateFn(f, row, index)
        local v = creatures[row]
        f:GetParent().info = v
        if index == 1 then
            local unitName = WdLib:getColoredName(v.name, v.class)
            if v.rt > 0 then unitName = WdLib:getRaidTargetTextureLink(v.rt).." "..unitName end
            f.txt:SetText(unitName)
            f:SetScript("OnClick", function(self) WDIM.lastSelectedButton = self; updateCreatureButtons() end)
            if v.parentName then
                WdLib:generateHover(f, {"id: "..v.npc_id, "Summoned by: |cffffff00"..v.parentName.."|r"})
            else
                WdLib:generateHover(f, "id: "..v.npc_id)
            end
        end
    end

    WdLib:updateScrollableTable(WDIM.creatures, maxHeight, topLeftPosition, rowsN, columnsN, createFn, updateFn)

    if not WDIM.lastSelectedButton and #creatures > 0 then
        WDIM.lastSelectedButton = WDIM.creatures.members[1].column[1]
    end
    updateCreatureButtons()
end

WD.InterruptMonitor = WDInterruptMonitor