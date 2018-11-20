
local WDLE = nil

function WD:InitLastEncounterModule(parent)
    WDLE = parent

    local x, y = 1, -30

    WDLE.headers = {}
    local h = createTableHeader(WDLE, WD_BUTTON_TIME, x, y, 70, 20)
    h = createTableHeaderNext(WDLE, h, WD_BUTTON_NAME, 100, 20)
    h = createTableHeaderNext(WDLE, h, WD_BUTTON_ROLE, 50, 20)
    h = createTableHeaderNext(WDLE, h, WD_BUTTON_POINTS_SHORT, 50, 20)
    createTableHeaderNext(WDLE, h, WD_BUTTON_REASON, 300, 20)

    WDLE:SetScript("OnShow", function() WD:RefreshLastEncounterFrame() end)
end

function WD:RefreshLastEncounterFrame()
    local core = WD.mainFrame

    if not core.encounter.fuckers then return end
    if not WDLE.members then WDLE.members = {} end

    local maxWidth = 30
    local maxHeight = 545
    for i=1,#WDLE.headers do
        maxWidth = maxWidth + WDLE.headers[i]:GetWidth() + 1
    end

    local scroller = WDLE.scroller or createScroller(WDLE, maxWidth, maxHeight, #core.encounter.fuckers)
    if not WDLE.scroller then
        WDLE.scroller = scroller
    end

    local x, y = 30, -51
    for k=1,#core.encounter.fuckers do
        local v = core.encounter.fuckers[k]
        if not WDLE.members[k] then
            local member = CreateFrame("Frame", nil, WDLE.scroller.scrollerChild)
            member.info = v
            member:SetSize(maxWidth, 20)
            member:SetPoint("TOPLEFT", WDLE.scroller.scrollerChild, "TOPLEFT", x, y)
            member.column = {}

            local index = 1
            addNextColumn(WDLE, member, index, "LEFT", v.timestamp)
            member.column[index]:SetPoint("TOPLEFT", member, "TOPLEFT", 0, -1)

            index = index + 1
            addNextColumn(WDLE, member, index, "LEFT", getShortCharacterName(v.name))
            index = index + 1
            addNextColumn(WDLE, member, index, "CENTER", v.role)
            index = index + 1
            addNextColumn(WDLE, member, index, "CENTER", v.points)
            index = index + 1
            addNextColumn(WDLE, member, index, "LEFT", v.reason)

            table.insert(WDLE.members, member)
        else
            local member = WDLE.members[k]
            member.column[1].txt:SetText(v.timestamp)
            member.column[2].txt:SetText(getShortCharacterName(v.name))
            member.column[3].txt:SetText(v.role)
            member.column[4].txt:SetText(v.points)
            member.column[5].txt:SetText(v.reason)
            member:Show()
            updateScroller(WDLE.scroller.slider, #core.encounter.fuckers)
        end

        y = y - 21
    end

    if #core.encounter.fuckers < #WDLE.members then
        for i=#core.encounter.fuckers+1, #WDLE.members do
            WDLE.members[i]:Hide()
        end
    end
end
