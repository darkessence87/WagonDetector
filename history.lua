
local WDHM = nil

if not WD.cache then WD.cache = {} end
WD.cache.history = {}

local function deleteHistory(v)
    table.remove(WD.db.profile.history, v.index)
    for i=v.index, #WD.db.profile.history do
        WD.db.profile.history[i].index = i
    end

    table.remove(WD.cache.history, v.cacheIndex)
    for i=v.cacheIndex, #WD.cache.history do
        WD.cache.history[i].cacheIndex = i
    end
end

local function revertHistory(v)
    function doRevert(v)
        if v.isReverted and v.isReverted == true then
            v.reason = string.match(v.reason, "%["..WD_REVERT_STR.."%]%s(.*)")
            v.isReverted = false
        else
            v.reason = "["..WD_REVERT_STR.."] "..v.reason
            v.isReverted = true
        end
        v.points = -v.points
    end

    doRevert(v)
    doRevert(WD.db.profile.history[v.index])

    WD:SavePenaltyPointsToGuildRoster(v, "do not add history")
end

local function exportHistory()
    local r = WDHM.exportWindow
    local history = WdLib:table_deepcopy(WD.cache.history)
    for k,v in pairs(history) do
        if not v.isReverted or v.isReverted == false then
            local _, _, spellString = string.find(v.reason, "|Hspell(.+)|h ")
            if spellString then
                v.reason = string.gsub(v.reason, "|", "||")
            end
            if v.role == "Unknown" then
                v.role = nil
            end

            v.cacheIndex = nil

            v.t = v.timestamp
            v.timestamp = nil

            v.n = WdLib:getShortName(v.name)
            v.name = nil

            v.rs = v.reason
            v.reason = nil

            v.e = v.encounter
            v.encounter = nil

            v.p = v.points
            v.points = nil

            v.rl = v.role
            v.role = nil

            v.isReverted = nil
        else
            history[k] = nil
        end
    end
    --local txt = WdLib:encode64(WdLib:table_tostring(history))
    local txt = WdLib:table_tostring(history)

    WdLib:table_wipe(history)

    r.editBox:SetText(txt)
    r.editBox:SetScript("OnChar", function() r.editBox:SetText(txt); r.editBox:HighlightText(); end)
    r.editBox:HighlightText()
    r.editBox:SetCursorPosition(0)
    r.editBox:SetFocus()

    r:Show()
end

local function refreshHistoryFrame()
    if not WDHM then return end
    if not WDHM.members then WDHM.members = {} end

    local maxHeight = 545
    local topLeftPosition = { x = 30, y = -51 }
    local rowsN = #WD.cache.history
    local columnsN = 8

    local function createFn(parent, row, index)
        local v = WD.cache.history[#WD.cache.history+1-row]
        if index == 1 then
            local f = WdLib:addNextColumn(WDHM, parent, index, "LEFT", v.timestamp)
            f:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -1)
            return f
        elseif index == 2 then
            return WdLib:addNextColumn(WDHM, parent, index, "LEFT", v.encounter)
        elseif index == 3 then
            local fuckerName = WdLib:getShortName(v.name)
            if v.mark > 0 then fuckerName = WdLib:getRaidTargetTextureLink(v.mark).." "..fuckerName end
            return WdLib:addNextColumn(WDHM, parent, index, "LEFT", fuckerName)
        elseif index == 4 then
            return WdLib:addNextColumn(WDHM, parent, index, "CENTER", v.role)
        elseif index == 5 then
            return WdLib:addNextColumn(WDHM, parent, index, "CENTER", v.points)
        elseif index == 6 then
            local f = WdLib:addNextColumn(WDHM, parent, index, "LEFT", v.reason)
            WdLib:generateSpellHover(f, v.reason)
            return f
        elseif index == 7 then
            local f = WdLib:addNextColumn(WDHM, parent, index, "CENTER", WD_BUTTON_REVERT)
            f:EnableMouse(true)
            f.t:SetColorTexture(.2, .6, .2, .7)
            f:SetScript("OnClick", function() revertHistory(v); refreshHistoryFrame() end)
            return f
        elseif index == 8 then
            local f = WdLib:addNextColumn(WDHM, parent, index, "CENTER", WD_BUTTON_DELETE)
            f:EnableMouse(true)
            f.t:SetColorTexture(.6, .2, .2, .7)
            f:SetScript("OnClick", function() deleteHistory(v); refreshHistoryFrame() end)
            return f
        end
    end

    local function updateFn(frame, row, index)
        local v = WD.cache.history[#WD.cache.history+1-row]
        if index == 1 then
            frame.txt:SetText(v.timestamp)
        elseif index == 2 then
            frame.txt:SetText(v.encounter)
        elseif index == 3 then
            local fuckerName = WdLib:getShortName(v.name)
            if v.mark > 0 then fuckerName = WdLib:getRaidTargetTextureLink(v.mark).." "..fuckerName end
            frame.txt:SetText(fuckerName)
        elseif index == 4 then
            frame.txt:SetText(v.role)
        elseif index == 5 then
            frame.txt:SetText(v.points)
        elseif index == 6 then
            frame.txt:SetText(v.reason)
            WdLib:generateSpellHover(frame, v.reason)
        elseif index == 7 then
            frame:SetScript("OnClick", function() revertHistory(v); refreshHistoryFrame() end)
        elseif index == 8 then
            frame:SetScript("OnClick", function() deleteHistory(v); refreshHistoryFrame() end)
        end
    end

    WdLib:updateScrollableTable(WDHM, maxHeight, topLeftPosition, rowsN, columnsN, createFn, updateFn)
end

local function matchFilter(str, filter)
    return str:match(filter)
end

local function applyFilters()
    if WDHM.filters[0] == "" then
        WDHM.filters[0] = date("%d/%m")
    end

    WdLib:table_wipe(WD.cache.history)
    for k,v in pairs(WD.db.profile.history) do
        if matchFilter(v.encounter, WDHM.filters[0]) and
           matchFilter(v.name, WDHM.filters[1]) and
           matchFilter(v.role, WDHM.filters[2]) and
           matchFilter(v.reason, WDHM.filters[3])
        then
            local entry = WdLib:table_deepcopy(v)
            entry.cacheIndex = #WD.cache.history+1
            WD.cache.history[entry.cacheIndex] = entry
        end
    end

    refreshHistoryFrame()
end

local function initFiltersTab()
    WDHM.filters = { [0] = "", [1] = "", [2] = "", [3] = "", }

    WDHM.filtersTxt = WdLib:createFontDefault(WDHM, "RIGHT", WD_BUTTON_HISTORY_FILTER)
    WDHM.filtersTxt:SetSize(WDHM.headers[1]:GetSize())
    WDHM.filtersTxt:SetPoint("BOTTOMLEFT", WDHM.headers[1], "TOPLEFT", 0, 5)

    --[[WDHM.clearButton = WdLib:createButton(WDHM)
    WDHM.clearButton:SetSize(WDHM.headers[1]:GetSize())
    WDHM.clearButton:SetPoint("TOPLEFT", WDHM.filtersTxt, "TOPRIGHT", 1, 0)
    WDHM.clearButton:SetScript("OnClick", function() WD:ClearHistory() end)
    WDHM.clearButton.txt = WdLib:createFont(WDHM.clearButton, "CENTER", WD_BUTTON_CLEAR)
    WDHM.clearButton.txt:SetAllPoints()
    WDHM.clearButton.t:SetColorTexture(.6, .2, .2, .7)]]

    WDHM.encounterFilter = WdLib:createEditBox(WDHM)
    WDHM.encounterFilter:SetSize(WDHM.headers[2]:GetSize())
    WDHM.encounterFilter:EnableMouse(true)
    WDHM.encounterFilter:SetPoint("TOPLEFT", WDHM.filtersTxt, "TOPRIGHT", 1, 0)
    WDHM.encounterFilter:SetJustifyH("CENTER")
    WDHM.encounterFilter:SetMaxLetters(15)
    WDHM.encounterFilter:SetText(date("%d/%m"))
    WDHM.encounterFilter:SetScript("OnChar", function() WDHM.filters[0] = WDHM.encounterFilter:GetText() end)
    WDHM.encounterFilter:SetScript("OnEnterPressed", function() WDHM.filters[0] = WDHM.encounterFilter:GetText(); applyFilters() end)
    WDHM.encounterFilter:SetScript("OnEscapePressed", function() WDHM.encounterFilter:ClearFocus() end)

    WDHM.nameFilter = WdLib:createEditBox(WDHM)
    WDHM.nameFilter:SetSize(WDHM.headers[3]:GetSize())
    WDHM.nameFilter:EnableMouse(true)
    WDHM.nameFilter:SetPoint("TOPLEFT", WDHM.encounterFilter, "TOPRIGHT", 1, 0)
    WDHM.nameFilter:SetJustifyH("CENTER")
    WDHM.nameFilter:SetMaxLetters(15)
    WDHM.nameFilter:SetScript("OnChar", function() WDHM.filters[1] = WDHM.nameFilter:GetText() end)
    WDHM.nameFilter:SetScript("OnEnterPressed", function() WDHM.filters[1] = WDHM.nameFilter:GetText(); applyFilters() end)
    WDHM.nameFilter:SetScript("OnEscapePressed", function() WDHM.nameFilter:ClearFocus() end)

    WDHM.roleFilter = WdLib:createEditBox(WDHM)
    WDHM.roleFilter:SetSize(WDHM.headers[4]:GetSize())
    WDHM.roleFilter:EnableMouse(true)
    WDHM.roleFilter:SetPoint("TOPLEFT", WDHM.nameFilter, "TOPRIGHT", 1, 0)
    WDHM.roleFilter:SetJustifyH("CENTER")
    WDHM.roleFilter:SetMaxLetters(6)
    WDHM.roleFilter:SetScript("OnChar", function() WDHM.filters[2] = WDHM.roleFilter:GetText() end)
    WDHM.roleFilter:SetScript("OnEnterPressed", function() WDHM.filters[2] = WDHM.roleFilter:GetText(); applyFilters() end)
    WDHM.roleFilter:SetScript("OnEscapePressed", function() WDHM.roleFilter:ClearFocus() end)

    WDHM.pointsFilter = WdLib:createEditBox(WDHM)
    WDHM.pointsFilter:SetSize(WDHM.headers[5]:GetSize())
    WDHM.pointsFilter:EnableMouse(false)
    WDHM.pointsFilter:SetPoint("TOPLEFT", WDHM.roleFilter, "TOPRIGHT", 1, 0)

    WDHM.reasonFilter = WdLib:createEditBox(WDHM)
    WDHM.reasonFilter:SetSize(WDHM.headers[6]:GetSize())
    WDHM.reasonFilter:EnableMouse(true)
    WDHM.reasonFilter:SetPoint("TOPLEFT", WDHM.pointsFilter, "TOPRIGHT", 1, 0)
    WDHM.reasonFilter:SetJustifyH("CENTER")
    WDHM.reasonFilter:SetMaxLetters(15)
    WDHM.reasonFilter:SetScript("OnChar", function() WDHM.filters[3] = WDHM.reasonFilter:GetText() end)
    WDHM.reasonFilter:SetScript("OnEnterPressed", function() WDHM.filters[3] = WDHM.reasonFilter:GetText(); applyFilters() end)
    WDHM.reasonFilter:SetScript("OnEscapePressed", function() WDHM.reasonFilter:ClearFocus() end)

    WDHM.export = WdLib:createButton(WDHM)
    WDHM.export:SetPoint("TOPLEFT", WDHM.reasonFilter, "TOPRIGHT", 1, 0)
    WDHM.export:SetSize(91, 20)
    WDHM.export:SetScript("OnClick", function() exportHistory() end)
    WDHM.export.txt = WdLib:createFont(WDHM.export, "CENTER", WD_BUTTON_EXPORT)
    WDHM.export.txt:SetAllPoints()

    applyFilters()
end

local function initExportWindow()
    WDHM.exportWindow = CreateFrame("Frame", nil, WDHM)
    local r = WDHM.exportWindow
    r:SetFrameStrata("FULLSCREEN")
    r:EnableMouse(true)
    r:SetPoint("CENTER", UIParent, "CENTER")
    r:SetSize(800, 600)
    r.bg = WdLib:createColorTexture(r, "TEXTURE", 0, 0, 0, 1)
    r.bg:SetAllPoints()

    WdLib:createXButton(r, -1)

    r.editBox = WdLib:createEditBox(r)
    r.editBox:SetFrameStrata("FULLSCREEN")
    r.editBox:SetSize(800, 600)
    r.editBox:SetPoint("TOPLEFT", r, "TOPLEFT", 0, 0)
    r.editBox:SetMultiLine(true)
    r.editBox:SetJustifyH("LEFT")
    r.editBox:SetMaxBytes(nil)
    r.editBox:SetMaxLetters(65536)
    r.editBox:SetScript("OnEscapePressed", function() r:Hide(); end)
    r.editBox:SetScript("OnMouseUp", function() r.editBox:HighlightText(); end)
    r.editBox:SetScript("OnHide", function() r.editBox:SetText(""); end)
    r.editBox:SetAutoFocus(true)
    r.editBox:Show()

    r:Hide()
end

function WD:InitHistoryModule(parent)
    WDHM = parent

    local x, y = 1, -30

    WDHM.headers = {}
    local h = WdLib:createTableHeader(WDHM, WD_BUTTON_TIME, x, y, 70, 20)
    table.insert(WDHM.headers, h)
    h = WdLib:createTableHeaderNext(WDHM, h, WD_BUTTON_ENCOUNTER, 200, 20)
    table.insert(WDHM.headers, h)
    h = WdLib:createTableHeaderNext(WDHM, h, WD_BUTTON_NAME, 100, 20)
    table.insert(WDHM.headers, h)
    h = WdLib:createTableHeaderNext(WDHM, h, WD_BUTTON_ROLE, 55, 20)
    table.insert(WDHM.headers, h)
    h = WdLib:createTableHeaderNext(WDHM, h, WD_BUTTON_POINTS_SHORT, 40, 20)
    table.insert(WDHM.headers, h)
    h = WdLib:createTableHeaderNext(WDHM, h, WD_BUTTON_REASON, 470, 20)
    table.insert(WDHM.headers, h)
    h = WdLib:createTableHeaderNext(WDHM, h, "", 45, 20)
    table.insert(WDHM.headers, h)
    h = WdLib:createTableHeaderNext(WDHM, h, "", 45, 20)
    table.insert(WDHM.headers, h)

    initFiltersTab()
    initExportWindow()

    WDHM:SetScript("OnShow", function() applyFilters(); refreshHistoryFrame() end)

    function WDHM:OnUpdate()
        refreshHistoryFrame()
    end
end

function WD:AddHistory(v)
    WD.db.profile.history[#WD.db.profile.history+1] = v
    v.index = #WD.db.profile.history

    refreshHistoryFrame()
end

function WD:AddPullHistory(encounter)
    if WD.db.profile.encounters[encounter] then
        WD.db.profile.encounters[encounter] = WD.db.profile.encounters[encounter] + 1
    else
        WD.db.profile.encounters[encounter] = 1
    end
end

function WD:ClearHistory()
    WdLib:table_wipe(WD.db.profile.history)
    WdLib:table_wipe(WD.cache.history)

    refreshHistoryFrame()

    print("History cleared")
end
