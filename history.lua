
local WDHM = nil

function WD:InitHistoryModule(parent)
    WDHM = parent

    local x, y = 1, -30

    WDHM.headers = {}
    local h = createTableHeader(WDHM, WD_BUTTON_TIME, x, y, 70, 20)
    h = createTableHeaderNext(WDHM, h, WD_BUTTON_ENCOUNTER, 150, 20)
    h = createTableHeaderNext(WDHM, h, WD_BUTTON_NAME, 100, 20)
    h = createTableHeaderNext(WDHM, h, WD_BUTTON_POINTS_SHORT, 50, 20)
    h = createTableHeaderNext(WDHM, h, WD_BUTTON_REASON, 300, 20)
    h = createTableHeaderNext(WDHM, h, "", 40, 20)
    createTableHeaderNext(WDHM, h, "", 40, 20)

    WDHM:SetScript("OnShow", WD.RefreshHistoryFrame)

    WDHM.exportWindow = CreateFrame("Frame", nil, WDHM)
    local r = WDHM.exportWindow
    r:EnableMouse(true)
    r:SetPoint("CENTER", 0, 0)
    r:SetSize(400, 400)
    r.bg = createColorTexture(r, "TEXTURE", 0, 0, 0, 1)
    r.bg:SetAllPoints()

    createXButton(r, -1)

    r.editBox = createEditBox(r)
    r.editBox:SetSize(398, 378)
    r.editBox:SetPoint("TOPLEFT", r, "TOPLEFT", 1, -21)
    r.editBox:SetMultiLine(true)
    r.editBox:SetJustifyH("LEFT")
    r.editBox:SetMaxBytes(nil)
    r.editBox:SetMaxLetters(4096)
    r.editBox:SetScript("OnEscapePressed", function() r:Hide(); end)
    r.editBox:SetScript("OnMouseUp", function() r.editBox:HighlightText(); end)
    r.editBox:SetScript("OnHide", function() r.editBox:SetText(""); end)
    r.editBox:Show()

    r:Hide()

    WDHM.export = createButton(WDHM)
    WDHM.export:SetPoint("TOPLEFT", WDHM, "TOPLEFT", 1, -5)
    WDHM.export:SetSize(125, 20)
    WDHM.export:SetScript("OnClick", function() WD:ExportHistory() end)
    WDHM.export.txt = createFont(WDHM.export, "CENTER", WD_BUTTON_EXPORT)
    WDHM.export.txt:SetAllPoints()
end

function WD:RefreshHistoryFrame()
    if not WDHM then return end
    if not WDHM.members then WDHM.members = {} end

    local maxWidth = 30
    local maxHeight = 545
    for i=1,#WDHM.headers do
        maxWidth = maxWidth + WDHM.headers[i]:GetWidth() + 1
    end

    local scroller = WDHM.scroller or createScroller(WDHM, maxWidth, maxHeight, #WD.db.profile.history)
    if not WDHM.scroller then
        WDHM.scroller = scroller
    end

    local x, y = 30, -51
    for k=#WD.db.profile.history,1,-1 do
        local v = WD.db.profile.history[k]
        k=#WD.db.profile.history-k+1
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
            addNextColumn(WDHM, member, index, "CENTER", v.points)

            index = index + 1
            addNextColumn(WDHM, member, index, "LEFT", v.reason)

            index = index + 1
            addNextColumn(WDHM, member, index, "CENTER", WD_BUTTON_REVERT)
            member.column[index]:EnableMouse(true)
            member.column[index].t:SetColorTexture(.2, .6, .2, .7)
            member.column[index]:SetScript("OnClick", function() WD:RevertHistory(v) end)

            index = index + 1
            addNextColumn(WDHM, member, index, "CENTER", WD_BUTTON_DELETE)
            member.column[index]:EnableMouse(true)
            member.column[index].t:SetColorTexture(.6, .2, .2, .7)
            member.column[index]:SetScript("OnClick", function() WD:DeleteHistory(v) end)

            table.insert(WDHM.members, member)
        else
            local member = WDHM.members[k]
            member.column[1].txt:SetText(v.timestamp)
            member.column[2].txt:SetText(v.encounter)
            member.column[3].txt:SetText(getShortCharacterName(v.name))
            member.column[4].txt:SetText(v.points)
            member.column[5].txt:SetText(v.reason)
            member.column[6]:SetScript("OnClick", function() WD:RevertHistory(v) end)
            member.column[7]:SetScript("OnClick", function() WD:DeleteHistory(v) end)
            member:Show()
            updateScroller(WDHM.scroller.slider, #WD.db.profile.history)
        end

        y = y - 21
    end

    if #WD.db.profile.history < #WDHM.members then
        for i=#WD.db.profile.history+1, #WDHM.members do
            WDHM.members[i]:Hide()
        end
    end
end

function WD:AddHistory(v)
    WD.db.profile.history[#WD.db.profile.history+1] = v
    v.index = #WD.db.profile.history

    WD:RefreshHistoryFrame()
end

function WD:RevertHistory(v)
    WD:DeleteHistory(v)

    if v.isReverted == true then
        v.reason = string.match(v.reason, "%["..WD_REVERT_STR.."%]%s(.*)")
        v.isReverted = false
    else
        v.reason = "["..WD_REVERT_STR.."] "..v.reason
        v.isReverted = true
    end

    v.points = -v.points
    WD:SavePenaltyPointsToGuildRoster(v)
end

function WD:DeleteHistory(v)
    local index = v.index
    table.remove(WD.db.profile.history, v.index)
    for i=index, #WD.db.profile.history do
        WD.db.profile.history[i].index = i
    end

    WD:RefreshHistoryFrame()
end

function WD:AddPullHistory(encounter)
    if WD.db.profile.encounters[encounter] then
        WD.db.profile.encounters[encounter] = WD.db.profile.encounters[encounter] + 1
    else
        WD.db.profile.encounters[encounter] = 1
    end
end

function WD:ExportHistory()
    local r = WDHM.exportWindow
    local history = deepcopy(WD.db.profile.history)
    for k,v in pairs(history) do
        local _, _, spellString = string.find(v.reason, "|c%x+|H(.+)|h%[.*%]")
        if spellString then
            v.reason = string.gsub(v.reason, "|", "||")
        end
    end
    local txt = encode64(table.tostring(history))

    r.editBox:SetText(txt)
    r.editBox:SetScript("OnChar", function() r.editBox:SetText(txt); r.editBox:HighlightText(); end)
    r.editBox:HighlightText()
    r.editBox:SetAutoFocus(true)
    r.editBox:SetCursorPosition(0)

    r:Show()
end
