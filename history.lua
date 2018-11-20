
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
    local history = table.deepcopy(WD.cache.history)
    for k,v in pairs(history) do
        if not v.isReverted or v.isReverted == false then
            local _, _, spellString = string.find(v.reason, "|Hspell(.+)|h%[.*%]")
            if spellString then
                v.reason = string.gsub(v.reason, "|", "||")
            end
            if v.role == "Unknown" then
                v.role = nil
            end

            v.cacheIndex = nil

            v.t = v.timestamp
            v.timestamp = nil

            v.n = getShortCharacterName(v.name)
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
    --local txt = encode64(table.tostring(history))
    local txt = table.tostring(history)

    table.wipe(history)

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

    local maxWidth = 30
    local maxHeight = 545
    for i=1,#WDHM.headers do
        maxWidth = maxWidth + WDHM.headers[i]:GetWidth() + 1
    end

    local scroller = WDHM.scroller or createScroller(WDHM, maxWidth, maxHeight, #WD.cache.history)
    if not WDHM.scroller then
        WDHM.scroller = scroller
    end

    local x, y = 30, -51
    for k=#WD.cache.history,1,-1 do
        local v = WD.cache.history[k]
        k=#WD.cache.history-k+1
        if not WDHM.members[k] then
            local member = CreateFrame("Frame", nil, WDHM.scroller.scrollerChild)
            member.info = v
            member:SetSize(maxWidth, 20)
            member:SetPoint("TOPLEFT", WDHM.scroller.scrollerChild, "TOPLEFT", x, y)
            member.column = {}

            local index = 1
            addNextColumn(WDHM, member, index, "LEFT", v.timestamp)
            member.column[index]:SetPoint("TOPLEFT", member, "TOPLEFT", 0, -1)

            index = index + 1
            addNextColumn(WDHM, member, index, "LEFT", v.encounter)

            index = index + 1
            addNextColumn(WDHM, member, index, "LEFT", getShortCharacterName(v.name))

            index = index + 1
            addNextColumn(WDHM, member, index, "CENTER", v.role)

            index = index + 1
            addNextColumn(WDHM, member, index, "CENTER", v.points)

            index = index + 1
            addNextColumn(WDHM, member, index, "LEFT", v.reason)

            index = index + 1
            addNextColumn(WDHM, member, index, "CENTER", WD_BUTTON_REVERT)
            member.column[index]:EnableMouse(true)
            member.column[index].t:SetColorTexture(.2, .6, .2, .7)
            member.column[index]:SetScript("OnClick", function() revertHistory(v); refreshHistoryFrame() end)

            index = index + 1
            addNextColumn(WDHM, member, index, "CENTER", WD_BUTTON_DELETE)
            member.column[index]:EnableMouse(true)
            member.column[index].t:SetColorTexture(.6, .2, .2, .7)
            member.column[index]:SetScript("OnClick", function() deleteHistory(v); refreshHistoryFrame() end)

            table.insert(WDHM.members, member)
        else
            local member = WDHM.members[k]
            member.column[1].txt:SetText(v.timestamp)
            member.column[2].txt:SetText(v.encounter)
            member.column[3].txt:SetText(getShortCharacterName(v.name))
            member.column[4].txt:SetText(v.role)
            member.column[5].txt:SetText(v.points)
            member.column[6].txt:SetText(v.reason)
            member.column[7]:SetScript("OnClick", function() revertHistory(v); refreshHistoryFrame() end)
            member.column[8]:SetScript("OnClick", function() deleteHistory(v); refreshHistoryFrame() end)
            member:Show()
            updateScroller(WDHM.scroller.slider, #WD.cache.history)
        end

        y = y - 21
    end

    if #WD.cache.history < #WDHM.members then
        for i=#WD.cache.history+1, #WDHM.members do
            WDHM.members[i]:Hide()
        end
    end
end

local function matchFilter(str, filter)
    return str:match(filter)
end

local function applyFilters()
    if WDHM.filters[0] == "" then
        WDHM.filters[0] = date("%d/%m")
    end

    table.wipe(WD.cache.history)
    for k,v in pairs(WD.db.profile.history) do
        if matchFilter(v.encounter, WDHM.filters[0]) and
           matchFilter(v.name, WDHM.filters[1]) and
           matchFilter(v.role, WDHM.filters[2]) and
           matchFilter(v.reason, WDHM.filters[3])
        then
            local entry = table.deepcopy(v)
            entry.cacheIndex = #WD.cache.history+1
            WD.cache.history[entry.cacheIndex] = entry
        end
    end

    refreshHistoryFrame()
end

local function initFiltersTab()
    WDHM.filters = { [0] = "", [1] = "", [2] = "", [3] = "", }

    WDHM.filtersTxt = createFontDefault(WDHM, "RIGHT", WD_BUTTON_HISTORY_FILTER)
    WDHM.filtersTxt:SetSize(WDHM.headers[1]:GetSize())
    WDHM.filtersTxt:SetPoint("BOTTOMLEFT", WDHM.headers[1], "TOPLEFT", 0, 5)

    --[[WDHM.clearButton = createButton(WDHM)
    WDHM.clearButton:SetSize(WDHM.headers[1]:GetSize())
    WDHM.clearButton:SetPoint("TOPLEFT", WDHM.filtersTxt, "TOPRIGHT", 1, 0)
    WDHM.clearButton:SetScript("OnClick", function() WD:ClearHistory() end)
    WDHM.clearButton.txt = createFont(WDHM.clearButton, "CENTER", WD_BUTTON_CLEAR)
    WDHM.clearButton.txt:SetAllPoints()
    WDHM.clearButton.t:SetColorTexture(.6, .2, .2, .7)]]

    WDHM.encounterFilter = createEditBox(WDHM)
    WDHM.encounterFilter:SetSize(WDHM.headers[2]:GetSize())
    WDHM.encounterFilter:EnableMouse(true)
    WDHM.encounterFilter:SetPoint("TOPLEFT", WDHM.filtersTxt, "TOPRIGHT", 1, 0)
    WDHM.encounterFilter:SetJustifyH("CENTER")
    WDHM.encounterFilter:SetMaxLetters(15)
    WDHM.encounterFilter:SetText(date("%d/%m"))
    WDHM.encounterFilter:SetScript("OnChar", function() WDHM.filters[0] = WDHM.encounterFilter:GetText() end)
    WDHM.encounterFilter:SetScript("OnEnterPressed", function() WDHM.filters[0] = WDHM.encounterFilter:GetText(); applyFilters() end)
    WDHM.encounterFilter:SetScript("OnEscapePressed", function() WDHM.encounterFilter:ClearFocus() end)

    WDHM.nameFilter = createEditBox(WDHM)
    WDHM.nameFilter:SetSize(WDHM.headers[3]:GetSize())
    WDHM.nameFilter:EnableMouse(true)
    WDHM.nameFilter:SetPoint("TOPLEFT", WDHM.encounterFilter, "TOPRIGHT", 1, 0)
    WDHM.nameFilter:SetJustifyH("CENTER")
    WDHM.nameFilter:SetMaxLetters(15)
    WDHM.nameFilter:SetScript("OnChar", function() WDHM.filters[1] = WDHM.nameFilter:GetText() end)
    WDHM.nameFilter:SetScript("OnEnterPressed", function() WDHM.filters[1] = WDHM.nameFilter:GetText(); applyFilters() end)
    WDHM.nameFilter:SetScript("OnEscapePressed", function() WDHM.nameFilter:ClearFocus() end)

    WDHM.roleFilter = createEditBox(WDHM)
    WDHM.roleFilter:SetSize(WDHM.headers[4]:GetSize())
    WDHM.roleFilter:EnableMouse(true)
    WDHM.roleFilter:SetPoint("TOPLEFT", WDHM.nameFilter, "TOPRIGHT", 1, 0)
    WDHM.roleFilter:SetJustifyH("CENTER")
    WDHM.roleFilter:SetMaxLetters(6)
    WDHM.roleFilter:SetScript("OnChar", function() WDHM.filters[2] = WDHM.roleFilter:GetText() end)
    WDHM.roleFilter:SetScript("OnEnterPressed", function() WDHM.filters[2] = WDHM.roleFilter:GetText(); applyFilters() end)
    WDHM.roleFilter:SetScript("OnEscapePressed", function() WDHM.roleFilter:ClearFocus() end)

    WDHM.pointsFilter = createEditBox(WDHM)
    WDHM.pointsFilter:SetSize(WDHM.headers[5]:GetSize())
    WDHM.pointsFilter:EnableMouse(false)
    WDHM.pointsFilter:SetPoint("TOPLEFT", WDHM.roleFilter, "TOPRIGHT", 1, 0)

    WDHM.reasonFilter = createEditBox(WDHM)
    WDHM.reasonFilter:SetSize(WDHM.headers[6]:GetSize())
    WDHM.reasonFilter:EnableMouse(true)
    WDHM.reasonFilter:SetPoint("TOPLEFT", WDHM.pointsFilter, "TOPRIGHT", 1, 0)
    WDHM.reasonFilter:SetJustifyH("CENTER")
    WDHM.reasonFilter:SetMaxLetters(15)
    WDHM.reasonFilter:SetScript("OnChar", function() WDHM.filters[3] = WDHM.reasonFilter:GetText() end)
    WDHM.reasonFilter:SetScript("OnEnterPressed", function() WDHM.filters[3] = WDHM.reasonFilter:GetText(); applyFilters() end)
    WDHM.reasonFilter:SetScript("OnEscapePressed", function() WDHM.reasonFilter:ClearFocus() end)

    WDHM.export = createButton(WDHM)
    WDHM.export:SetPoint("TOPLEFT", WDHM.reasonFilter, "TOPRIGHT", 1, 0)
    WDHM.export:SetSize(91, 20)
    WDHM.export:SetScript("OnClick", function() exportHistory() end)
    WDHM.export.txt = createFont(WDHM.export, "CENTER", WD_BUTTON_EXPORT)
    WDHM.export.txt:SetAllPoints()

    applyFilters()
end

local function initExportWindow()
    WDHM.exportWindow = CreateFrame("Frame", nil, WDHM)
    local r = WDHM.exportWindow
    r:EnableMouse(true)
    r:SetPoint("CENTER", UIParent, "CENTER")
    r:SetSize(800, 600)
    r.bg = createColorTexture(r, "TEXTURE", 0, 0, 0, 1)
    r.bg:SetAllPoints()

    createXButton(r, -1)

    r.editBox = createEditBox(r)
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
    local h = createTableHeader(WDHM, WD_BUTTON_TIME, x, y, 70, 20)
    h = createTableHeaderNext(WDHM, h, WD_BUTTON_ENCOUNTER, 150, 20)
    h = createTableHeaderNext(WDHM, h, WD_BUTTON_NAME, 100, 20)
    h = createTableHeaderNext(WDHM, h, WD_BUTTON_ROLE, 50, 20)
    h = createTableHeaderNext(WDHM, h, WD_BUTTON_POINTS_SHORT, 40, 20)
    h = createTableHeaderNext(WDHM, h, WD_BUTTON_REASON, 300, 20)
    h = createTableHeaderNext(WDHM, h, "", 45, 20)
    createTableHeaderNext(WDHM, h, "", 45, 20)

    initFiltersTab()
    initExportWindow()

    WDHM:SetScript("OnShow", function() applyFilters(); refreshHistoryFrame() end)
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
    table.wipe(WD.db.profile.history)
    table.wipe(WD.cache.history)
    
    refreshHistoryFrame()
    
    print("History cleared")
end
