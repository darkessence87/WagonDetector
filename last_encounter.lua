
local WDLE = nil

function WD:InitLastEncounterModule(parent)
    WDLE = parent

    local x, y = 1, -30

    WDLE.headers = {}
    local h = WdLib:createTableHeader(WDLE, WD_BUTTON_TIME, x, y, 70, 20)
    table.insert(WDLE.headers, h)
    h = WdLib:createTableHeaderNext(WDLE, h, WD_BUTTON_NAME, 200, 20)
    table.insert(WDLE.headers, h)
    h = WdLib:createTableHeaderNext(WDLE, h, WD_BUTTON_ROLE, 75, 20)
    table.insert(WDLE.headers, h)
    h = WdLib:createTableHeaderNext(WDLE, h, WD_BUTTON_POINTS_SHORT, 60, 20)
    table.insert(WDLE.headers, h)
    h = WdLib:createTableHeaderNext(WDLE, h, WD_BUTTON_REASON, 600, 20)
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
            local f = WdLib:addNextColumn(WDLE, parent, index, "LEFT", v.timestamp)
            f:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -1)
            return f
        elseif index == 2 then
            local fuckerName = WdLib:getShortName(v.name)
            if v.mark > 0 then fuckerName = WdLib:getRaidTargetTextureLink(v.mark).." "..fuckerName end
            return WdLib:addNextColumn(WDLE, parent, index, "LEFT", fuckerName)
        elseif index == 3 then
            return WdLib:addNextColumn(WDLE, parent, index, "CENTER", v.role)
        elseif index == 4 then
            return WdLib:addNextColumn(WDLE, parent, index, "CENTER", v.points)
        elseif index == 5 then
            local f = WdLib:addNextColumn(WDLE, parent, index, "LEFT", v.reason)
            WdLib:generateSpellHover(f, v.reason)
            return f
        end
    end

    local function updateFn(frame, row, index)
        local v = core.encounter.fuckers[row]
        if index == 1 then
            frame.txt:SetText(v.timestamp)
        elseif index == 2 then
            local fuckerName = WdLib:getShortName(v.name)
            if v.mark > 0 then fuckerName = WdLib:getRaidTargetTextureLink(v.mark).." "..fuckerName end
            frame.txt:SetText(fuckerName)
        elseif index == 3 then
            frame.txt:SetText(v.role)
        elseif index == 4 then
            frame.txt:SetText(v.points)
        elseif index == 5 then
            frame.txt:SetText(v.reason)
            WdLib:generateSpellHover(frame, v.reason)
        end
    end

    WdLib:updateScrollableTable(WDLE, maxHeight, topLeftPosition, rowsN, columnsN, createFn, updateFn)
end
