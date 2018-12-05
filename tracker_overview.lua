
local WDTO = nil

local function getInterruptStatusText(v)
    if v.status == "INTERRUPTED" then
        local str = "Interrupted by %s's %s in %s sec"
        return string.format(str, getShortCharacterName(v.interrupter), getSpellLinkByIdWithTexture(v.spell_id), v.timediff)
    elseif v.status == "SUCCESS" then
        return "|cffff0000Casted!|r"
    end

    return v.status
end

local function updateInterruptsInfo(v)
    local core = WD.mainFrame
    local parent = WDTO.data["interrupts"]

    for _,v in pairs(parent.members) do
        v:Hide()
    end

    if not v then return end

    local n = 0
    for spell_id,castInfo in pairs(v.casts) do
        if type(castInfo) == "table" then
            for k=1,#castInfo do
                n = n + 1
                local v = castInfo[k]
                if not parent.members[n] then
                    local member = CreateFrame("Frame", nil, parent.headers[1])
                    member:SetSize(parent.headers[1]:GetSize())
                    member:SetPoint("TOPLEFT", parent.headers[1], "BOTTOMLEFT", 0, -1)
                    member.column = {}

                    local index = 1
                    addNextColumn(parent, member, index, "LEFT", getSpellLinkByIdWithTexture(spell_id))
                    if n > 1 then
                        member.column[index]:SetPoint("TOPLEFT", parent.members[n - 1], "BOTTOMLEFT", 0, -1)
                        member:SetPoint("TOPLEFT", parent.members[n - 1], "BOTTOMLEFT", 0, -1)
                    else
                        member.column[index]:SetPoint("TOPLEFT", member, "TOPLEFT", 0, 0)
                    end

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
                    member.column[2].txt:SetText(getTimedDiff(core.encounter.startTime, v.timestamp))
                    member.column[3].txt:SetText(k)
                    member.column[4].txt:SetText(getInterruptStatusText(v))
                    local percent = v.percent or 0
                    member.column[5].txt:SetText(percent)

                    member:Show()
                end
            end
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
    local h = createTableHeader(r, "Spell", 0, 0, 150, 20)
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

local function resetColor()
    for _,v in pairs(WDTO.creatures.members) do
        v.column[1].t:SetColorTexture(.2, .2, .2, 1)
    end
end

local function isValidNpc(v)
    if v.type == "player" then return nil end
    for spell_id,castInfo in pairs(v.casts) do
        if type(castInfo) == "table" and #castInfo > 0 then
            return true
        end
    end
    return nil
end

function WD:RefereshTrackedCreatures()
    if not WDTO then return end

    local creatures = {}
    for name,info in pairs(WD.cache.tracker) do
        for guid,npc in pairs(info) do
            if type(npc) == "table" then
                if isValidNpc(npc) then
                    creatures[#creatures+1] = npc
                end
            end
        end
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
            member:SetPoint("TOPLEFT", WDTO.creatures.headers[1], "BOTTOMLEFT", 0, -1)
            member.column = {}

            local index = 1
            local creatureName = v.name
            if v.rt > 0 then creatureName = getRaidTargetTextureLink(v.rt).." "..creatureName end
            addNextColumn(WDTO.creatures, member, index, "LEFT", creatureName)
            if k > 1 then
                member.column[index]:SetPoint("TOPLEFT", WDTO.creatures.members[k - 1], "BOTTOMLEFT", 0, -1)
                member:SetPoint("TOPLEFT", WDTO.creatures.members[k - 1], "BOTTOMLEFT", 0, -1)
            else
                member.column[index]:SetPoint("TOPLEFT", member, "TOPLEFT", 0, 0)
            end

            member.column[index]:EnableMouse(true)
            member.column[index]:SetScript("OnClick", function(self) resetColor(); updateInterruptsInfo(v); self.t:SetColorTexture(.2, .6, .2, 1) end)

            table.insert(WDTO.creatures.members, member)
        else
            local member = WDTO.creatures.members[k]
            local creatureName = v.name
            if v.rt > 0 then creatureName = getRaidTargetTextureLink(v.rt).." "..creatureName end
            member.column[1].txt:SetText(creatureName)
            member.column[1]:SetScript("OnClick", function(self) resetColor(); updateInterruptsInfo(v); self.t:SetColorTexture(.2, .6, .2, 1) end)

            member:Show()
        end
    end

    if #creatures < #WDTO.creatures.members then
        for i=#creatures+1, #WDTO.creatures.members do
            WDTO.creatures.members[i]:Hide()
        end
    end

    resetColor()
end

function WD:InitTrackerOverviewModule(parent)
    WDTO = parent

    WDTO.data = {}
    WDTO.creatures = {}
    WDTO.creatures.headers = {}
    WDTO.creatures.members = {}

    table.insert(WDTO.creatures.headers, createTableHeader(WDTO, "Creatures", 1, -30, 300, 20))

    WDTO:SetScript("OnShow", function(self) updateInterruptsInfo(); WD:RefereshTrackedCreatures() end)

    initInterruptsInfoTable()

    function WDTO:OnUpdate()
        WD:RefereshTrackedCreatures()
    end
end
