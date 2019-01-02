
local WDLastEncounterModule = {}
WDLastEncounterModule.__index = WDLastEncounterModule

setmetatable(WDLastEncounterModule, {
    __index = WD.Module,
    __call = function (v, ...)
        local self = setmetatable({}, v)
        self:init(...)
        return self
    end,
})

local WDLE = nil

function WDLastEncounterModule:init(parent, yOffset)
    WD.Module.init(self, WD_BUTTON_LAST_ENCOUNTER_MODULE, parent, yOffset)

    WDLE = self.frame

    local x, y = 1, -30

    WDLE.headers = {}
    local h = WdLib.gui:createTableHeader(WDLE, WD_BUTTON_TIME, x, y, 70, 20)
    table.insert(WDLE.headers, h)
    h = WdLib.gui:createTableHeaderNext(WDLE, h, WD_BUTTON_NAME, 200, 20)
    table.insert(WDLE.headers, h)
    h = WdLib.gui:createTableHeaderNext(WDLE, h, WD_BUTTON_ROLE, 55, 20)
    table.insert(WDLE.headers, h)
    h = WdLib.gui:createTableHeaderNext(WDLE, h, WD_BUTTON_POINTS_SHORT, 60, 20)
    table.insert(WDLE.headers, h)
    h = WdLib.gui:createTableHeaderNext(WDLE, h, WD_BUTTON_REASON, 645, 20)
    table.insert(WDLE.headers, h)

    WDLE:SetScript("OnShow", function() WD:RefreshLastEncounterFrame() end)

    function WDLE:OnUpdate()
        WD:RefreshLastEncounterFrame()
    end
end

function WD:RefreshLastEncounterFrame()
    if not WDLE then return end
    local core = WD.mainFrame

    if not core.encounter.fuckers then return end
    if not WDLE.members then WDLE.members = {} end

    local maxHeight = 545
    local topLeftPosition = { x = 30, y = -51 }
    local rowsN = #core.encounter.fuckers
    local columnsN = 5

    local function createFn(parent, row, index)
        local v = core.encounter.fuckers[row]
        if index == 1 then
            local f = WdLib.gui:addNextColumn(WDLE, parent, index, "LEFT", v.timestamp)
            f:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -1)
            return f
        elseif index == 2 then
            local fuckerName = WdLib.gen:getShortName(v.name)
            if v.mark > 0 then fuckerName = WdLib.gui:getRaidTargetTextureLink(v.mark).." "..fuckerName end
            return WdLib.gui:addNextColumn(WDLE, parent, index, "LEFT", fuckerName)
        elseif index == 3 then
            return WdLib.gui:addNextColumn(WDLE, parent, index, "CENTER", v.role)
        elseif index == 4 then
            return WdLib.gui:addNextColumn(WDLE, parent, index, "CENTER", v.points)
        elseif index == 5 then
            local f = WdLib.gui:addNextColumn(WDLE, parent, index, "LEFT", v.reason)
            WdLib.gui:generateSpellHover(f, v.reason)
            return f
        end
    end

    local function updateFn(frame, row, index)
        local v = core.encounter.fuckers[row]
        if index == 1 then
            frame.txt:SetText(v.timestamp)
        elseif index == 2 then
            local fuckerName = WdLib.gen:getShortName(v.name)
            if v.mark > 0 then fuckerName = WdLib.gui:getRaidTargetTextureLink(v.mark).." "..fuckerName end
            frame.txt:SetText(fuckerName)
        elseif index == 3 then
            frame.txt:SetText(v.role)
        elseif index == 4 then
            frame.txt:SetText(v.points)
        elseif index == 5 then
            frame.txt:SetText(v.reason)
            WdLib.gui:generateSpellHover(frame, v.reason)
        end
    end

    WdLib.gui:updateScrollableTable(WDLE, maxHeight, topLeftPosition, rowsN, columnsN, createFn, updateFn)
end

WD.LastEncounterModule = WDLastEncounterModule