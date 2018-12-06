
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

    local maxWidth = 30
    local maxHeight = 545
    for i=1,#WDLE.headers do
        maxWidth = maxWidth + WDLE.headers[i]:GetWidth() + 1
    end

    local scroller = WDLE.scroller or WdLib:createScroller(WDLE, maxWidth, maxHeight, #core.encounter.fuckers)
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
            WdLib:addNextColumn(WDLE, member, index, "LEFT", v.timestamp)
            member.column[index]:SetPoint("TOPLEFT", member, "TOPLEFT", 0, -1)

            index = index + 1
            local fuckerName = WdLib:getShortCharacterName(v.name)
            if v.mark > 0 then fuckerName = WdLib:getRaidTargetTextureLink(v.mark).." "..fuckerName end
            WdLib:addNextColumn(WDLE, member, index, "LEFT", fuckerName)
            index = index + 1
            WdLib:addNextColumn(WDLE, member, index, "CENTER", v.role)
            index = index + 1
            WdLib:addNextColumn(WDLE, member, index, "CENTER", v.points)
            index = index + 1
            WdLib:addNextColumn(WDLE, member, index, "LEFT", v.reason)
            WdLib:generateSpellHover(member.column[index], v.reason)

            table.insert(WDLE.members, member)
        else
            local member = WDLE.members[k]
            member.column[1].txt:SetText(v.timestamp)
            local fuckerName = WdLib:getShortCharacterName(v.name)
            if v.mark > 0 then fuckerName = WdLib:getRaidTargetTextureLink(v.mark).." "..fuckerName end
            member.column[2].txt:SetText(fuckerName)
            member.column[3].txt:SetText(v.role)
            member.column[4].txt:SetText(v.points)
            member.column[5].txt:SetText(v.reason)
            WdLib:generateSpellHover(member.column[5], v.reason)
            member:Show()
            WdLib:updateScroller(WDLE.scroller.slider, #core.encounter.fuckers)
        end

        y = y - 21
    end

    if #core.encounter.fuckers < #WDLE.members then
        for i=#core.encounter.fuckers+1, #WDLE.members do
            WDLE.members[i]:Hide()
        end
    end
end
