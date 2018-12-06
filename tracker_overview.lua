
local WDTO = nil

local function getInterruptStatusText(v)
    if v.status == "INTERRUPTED" then
        return string.format(WD_TRACKER_INTERRUPTED_BY, getColoredName(getShortCharacterName(v.interrupter.name), v.interrupter.class), getSpellLinkByIdWithTexture(v.spell_id), v.timediff)
    elseif v.status == "SUCCESS" then
        return string.format(WD_TRACKER_CASTED_IN, v.timediff)
    end

    return v.status
end

local function updateInterruptsInfo()
    local core = WD.mainFrame
    local parent = WDTO.data["interrupts"]

    for _,v in pairs(parent.members) do
        v:Hide()
    end

    if not WDTO.lastSelectedCreature then return end
    local v = WDTO.lastSelectedCreature:GetParent().info

    local maxWidth = 30
    local maxHeight = 210
    for i=1,#parent.headers do
        maxWidth = maxWidth + parent.headers[i]:GetWidth() + 1
    end

    local totalCasts = 0
    for _,castInfo in pairs(v.casts) do
        if type(castInfo) == "table" then
            totalCasts = totalCasts + #castInfo
        end
    end

    local scroller = parent.scroller or createScroller(parent, maxWidth, maxHeight, totalCasts)
    if not parent.scroller then
        parent.scroller = scroller
    end

    local x, y = 30, -51
    local n = 0
    for spell_id,castInfo in pairs(v.casts) do
        if type(castInfo) == "table" then
            for k=1,#castInfo do
                n = n + 1
                local v = castInfo[k]
                if not parent.members[n] then
                    local member = CreateFrame("Frame", nil, parent.scroller.scrollerChild)
                    member:SetSize(parent.headers[1]:GetSize())
                    member:SetPoint("TOPLEFT", parent.scroller.scrollerChild, "TOPLEFT", x, y)
                    member.column = {}

                    local index = 1
                    addNextColumn(parent, member, index, "LEFT", getSpellLinkByIdWithTexture(spell_id))
                    if n > 1 then
                        member.column[index]:SetPoint("TOPLEFT", parent.members[n - 1], "BOTTOMLEFT", 0, -1)
                        member:SetPoint("TOPLEFT", parent.members[n - 1], "BOTTOMLEFT", 0, -1)
                    else
                        member.column[index]:SetPoint("TOPLEFT", member, "TOPLEFT", 0, 0)
                    end
                    generateSpellHover(member.column[index], getSpellLinkByIdWithTexture(spell_id))


                    index = index + 1
                    addNextColumn(parent, member, index, "CENTER", getTimedDiff(core.encounter.startTime, v.timestamp))
                    index = index + 1
                    addNextColumn(parent, member, index, "CENTER", k)
                    index = index + 1
                    addNextColumn(parent, member, index, "LEFT", getInterruptStatusText(v))
                    index = index + 1
                    local percent = v.percent or 0
                    addNextColumn(parent, member, index, "CENTER", percent)

                    table.insert(parent.members, member)
                else
                    local member = parent.members[n]
                    member.column[1].txt:SetText(getSpellLinkByIdWithTexture(spell_id))
                    generateSpellHover(member.column[1], getSpellLinkByIdWithTexture(spell_id))
                    member.column[2].txt:SetText(getTimedDiff(core.encounter.startTime, v.timestamp))
                    member.column[3].txt:SetText(k)
                    member.column[4].txt:SetText(getInterruptStatusText(v))
                    local percent = v.percent or 0
                    member.column[5].txt:SetText(percent)

                    member:Show()
                    updateScroller(parent.scroller.slider, totalCasts)
                end
            end
        end
    end

    if totalCasts < #parent.members then
        for i=totalCasts+1, #parent.members do
            parent.members[i]:Hide()
        end
    end

    parent:Show()
end

local function initInterruptsInfoTable()
    WDTO.data["interrupts"] = CreateFrame("Frame", nil, WDTO)
    local r = WDTO.data["interrupts"]
    r:SetPoint("TOPLEFT", WDTO.creatures.headers[1], "TOPRIGHT", 1, 0)
    r:SetSize(550, 300)
    --r.bg = createColorTexture(r, "TEXTURE", 0, 0, 0, 1)
    --r.bg:SetAllPoints()

    r.headers = {}
    r.members = {}

    -- headers
    local h = createTableHeader(r, "Spell", 0, 0, 170, 20)
    table.insert(r.headers, h)
    h = createTableHeaderNext(r, h, WD_BUTTON_TIME, 70, 20)
    table.insert(r.headers, h)
    h = createTableHeaderNext(r, h, "N", 25, 20)
    table.insert(r.headers, h)
    h = createTableHeaderNext(r, h, "Status", 400, 20)
    table.insert(r.headers, h)
    h = createTableHeaderNext(r, h, "Quality", 50, 20)
    table.insert(r.headers, h)

    r:Hide()
end

local function updateCreatureButtons()
    for _,v in pairs(WDTO.creatures.members) do
        v.column[1].t:SetColorTexture(.2, .2, .2, 1)
    end

    if WDTO.lastSelectedCreature then
        WDTO.lastSelectedCreature.t:SetColorTexture(.2, .6, .2, 1)
        updateInterruptsInfo()
    end
end

local function isValidNpc(v)
    for spell_id,castInfo in pairs(v.casts) do
        if type(castInfo) == "table" and #castInfo > 0 then
            return true
        end
    end
    return nil
end

function WD:RefreshTrackedCreatures()
    if not WDTO then return end

    local creatures = {}
    for npcId,data in pairs(WD.cache.tracker.npc) do
        for guid,npc in pairs(data) do
            if type(npc) == "table" then
                if isValidNpc(npc) then
                    npc.npc_id = npcId
                    creatures[#creatures+1] = npc
                end
            end
        end
    end

    if WDTO.lastSelectedCreature and #creatures == 0 then
        WDTO.lastSelectedCreature = nil
        updateInterruptsInfo()
    end

    local func = function(a, b)
        return a.name < b.name
    end
    table.sort(creatures, func)

    for k=1,#creatures do
        local v = creatures[k]
        if not WDTO.creatures.members[k] then
            local member = CreateFrame("Frame", nil, WDTO.creatures.headers[1])
            member.info = v
            member:SetSize(WDTO.creatures.headers[1]:GetSize())
            member.column = {}

            local index = 1
            local creatureName = v.name
            if v.rt > 0 then creatureName = getRaidTargetTextureLink(v.rt).." "..creatureName end
            addNextColumn(WDTO.creatures, member, index, "LEFT", creatureName)
            if k > 1 then
                member:SetPoint("TOPLEFT", WDTO.creatures.members[k - 1], "BOTTOMLEFT", 0, -1)
                member.column[index]:SetPoint("TOPLEFT", WDTO.creatures.members[k - 1], "BOTTOMLEFT", 0, -1)
            else
                member:SetPoint("TOPLEFT", WDTO.creatures.headers[1], "BOTTOMLEFT", 0, -2)
                member.column[index]:SetPoint("TOPLEFT", member, "TOPLEFT", 0, 0)
            end

            member.column[index]:EnableMouse(true)
            member.column[index]:SetScript("OnClick", function(self) WDTO.lastSelectedCreature = self; updateCreatureButtons() end)
            generateHover(member.column[index], "id: "..v.npc_id)

            table.insert(WDTO.creatures.members, member)
        else
            local member = WDTO.creatures.members[k]
            if WDTO.lastSelectedCreature and WDTO.lastSelectedCreature:GetParent().info.guid == member.info.guid then
                WDTO.lastSelectedCreature = member.column[1]
            end
            local creatureName = v.name
            if v.rt > 0 then creatureName = getRaidTargetTextureLink(v.rt).." "..creatureName end
            member.column[1].txt:SetText(creatureName)
            member.column[1]:SetScript("OnClick", function(self) WDTO.lastSelectedCreature = self; updateCreatureButtons() end)
            generateHover(member.column[1], "id: "..v.npc_id)
            member.info = v

            member:Show()
        end
    end

    if #creatures < #WDTO.creatures.members then
        for i=#creatures+1, #WDTO.creatures.members do
            WDTO.creatures.members[i]:Hide()
        end
    end

    if not WDTO.lastSelectedCreature and #creatures > 0 then
        WDTO.lastSelectedCreature = WDTO.creatures.members[1].column[1]
    end
    updateCreatureButtons()
end

function WD:InitTrackerOverviewModule(parent)
    WDTO = parent

    WDTO.data = {}
    WDTO.creatures = {}
    WDTO.creatures.headers = {}
    WDTO.creatures.members = {}

    table.insert(WDTO.creatures.headers, createTableHeader(WDTO, "Creatures", 1, -30, 300, 20))

    WDTO:SetScript("OnShow", function(self) WD:RefreshTrackedCreatures() end)

    initInterruptsInfoTable()

    function WDTO:OnUpdate()
        WD:RefreshTrackedCreatures()
    end
end
