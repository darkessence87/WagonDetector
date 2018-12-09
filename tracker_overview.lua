
local WDTO = nil

local function getDispelledAuras(auras)
    local result = {}
    for auraId,auraInfo in pairs(auras) do
        for i=1,#auraInfo do
            if auraInfo[i].dispell_id then
                if not result[auraId] then result[auraId] = {} end
                result[auraId][#result[auraId]+1] = auraInfo[i]
            end
        end
    end
    return result
end

local function getInterruptStatusText(v)
    if v.status == "INTERRUPTED" then
        local interrupter = nil
        if type(v.interrupter) == "table" then
            interrupter = v.interrupter
        else
            interrupter = WD:FindEntityByGUID(v.interrupter)
        end
        return string.format(WD_TRACKER_INTERRUPTED_BY, WdLib:getColoredName(WdLib:getShortCharacterName(interrupter.name), interrupter.class), WdLib:getSpellLinkByIdWithTexture(v.spell_id), v.timediff)
    elseif v.status == "SUCCESS" then
        return string.format(WD_TRACKER_CASTED_IN, v.timediff)
    end

    return v.status
end

local function getDispelStatusText(v)
    if not v.dispeller then return "Error" end
    local dispeller = nil
    if type(v.dispeller) == "table" then
        dispeller = v.dispeller
    else
        dispeller = WD:FindEntityByGUID(v.dispeller)
    end
    if not dispeller then return "Error" end
    return string.format(WD_TRACKER_DISPELLED_BY, WdLib:getColoredName(WdLib:getShortCharacterName(dispeller.name), dispeller.class), WdLib:getSpellLinkByIdWithTexture(v.dispell_id), v.dispelledIn)
end

local function updateDispelInfo()
    local core = WD.mainFrame
    local parent = WDTO.data["dispel"]

    for _,v in pairs(parent.members) do
        v:Hide()
    end

    if not WDTO.lastSelectedDispel then return end
    local v = WDTO.lastSelectedDispel:GetParent().info

    local maxWidth = 30
    local maxHeight = 210
    for i=1,#parent.headers do
        maxWidth = maxWidth + parent.headers[i]:GetWidth() + 1
    end

    local auras = getDispelledAuras(v.auras)
    local totalAuras = 0
    for _,auraInfo in pairs(auras) do
        if type(auraInfo) == "table" then
            totalAuras = totalAuras + #auraInfo
        end
    end

    local scroller = parent.scroller or WdLib:createScroller(parent, maxWidth, maxHeight, totalAuras)
    if not parent.scroller then
        parent.scroller = scroller
    end

    local x, y = 30, -51
    local n = 0
    for auraId,auraInfo in pairs(auras) do
        if type(auraInfo) == "table" then
            for k=1,#auraInfo do
                n = n + 1
                local v = auraInfo[k]
                if not parent.members[n] then
                    local member = CreateFrame("Frame", nil, parent.scroller.scrollerChild)
                    member:SetSize(parent.headers[1]:GetSize())
                    member:SetPoint("TOPLEFT", parent.scroller.scrollerChild, "TOPLEFT", x, y)
                    member.column = {}

                    local index = 1
                    WdLib:addNextColumn(parent, member, index, "LEFT", WdLib:getSpellLinkByIdWithTexture(auraId))
                    if n > 1 then
                        member.column[index]:SetPoint("TOPLEFT", parent.members[n - 1], "BOTTOMLEFT", 0, -1)
                        member:SetPoint("TOPLEFT", parent.members[n - 1], "BOTTOMLEFT", 0, -1)
                    else
                        member.column[index]:SetPoint("TOPLEFT", member, "TOPLEFT", 0, 0)
                    end
                    WdLib:generateSpellHover(member.column[index], WdLib:getSpellLinkByIdWithTexture(auraId))

                    index = index + 1
                    WdLib:addNextColumn(parent, member, index, "CENTER", v.dispelledAt)
                    index = index + 1
                    WdLib:addNextColumn(parent, member, index, "CENTER", k)
                    index = index + 1
                    WdLib:addNextColumn(parent, member, index, "LEFT", getDispelStatusText(v))
                    WdLib:generateSpellHover(member.column[index], getDispelStatusText(v))
                    index = index + 1

                    table.insert(parent.members, member)
                else
                    local member = parent.members[n]
                    member.column[1].txt:SetText(WdLib:getSpellLinkByIdWithTexture(auraId))
                    WdLib:generateSpellHover(member.column[1], WdLib:getSpellLinkByIdWithTexture(auraId))
                    member.column[2].txt:SetText(v.dispelledAt)
                    member.column[3].txt:SetText(k)
                    member.column[4].txt:SetText(getDispelStatusText(v))
                    WdLib:generateSpellHover(member.column[4], getDispelStatusText(v))

                    member:Show()
                end
            end
        end
    end

    WdLib:updateScroller(parent.scroller.slider, totalAuras)

    if totalAuras < #parent.members then
        for i=totalAuras+1, #parent.members do
            parent.members[i]:Hide()
        end
    end

    parent:Show()
end

local function initDispelInfoTable()
    WDTO.data["dispel"] = CreateFrame("Frame", nil, WDTO)
    local r = WDTO.data["dispel"]
    r:SetPoint("TOPLEFT", WDTO.dispels.headers[1], "TOPRIGHT", 1, 0)
    r:SetSize(550, 300)

    r.headers = {}
    r.members = {}

    -- headers
    local h = WdLib:createTableHeader(r, "Aura", 0, 0, 170, 20)
    table.insert(r.headers, h)
    h = WdLib:createTableHeaderNext(r, h, WD_BUTTON_TIME, 70, 20)
    table.insert(r.headers, h)
    h = WdLib:createTableHeaderNext(r, h, "N", 25, 20)
    table.insert(r.headers, h)
    h = WdLib:createTableHeaderNext(r, h, "Status", 450, 20)
    table.insert(r.headers, h)

    r:Hide()
end

local function updateDispelButtons()
    for _,v in pairs(WDTO.dispels.members) do
        v.column[1].t:SetColorTexture(.2, .2, .2, 1)
    end

    if WDTO.lastSelectedDispel then
        WDTO.lastSelectedDispel.t:SetColorTexture(.2, .6, .2, 1)
    end
    updateDispelInfo()
end

local function initDispelButtons()
    WDTO.dispels = CreateFrame("Frame", nil, WDTO)
    WDTO.dispels.headers = {}
    WDTO.dispels.members = {}
    table.insert(WDTO.dispels.headers, WdLib:createTableHeader(WDTO, "Dispel info", 1, -300, 300, 20))
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

    local scroller = parent.scroller or WdLib:createScroller(parent, maxWidth, maxHeight, totalCasts)
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
                    WdLib:addNextColumn(parent, member, index, "LEFT", WdLib:getSpellLinkByIdWithTexture(spell_id))
                    if n > 1 then
                        member.column[index]:SetPoint("TOPLEFT", parent.members[n - 1], "BOTTOMLEFT", 0, -1)
                        member:SetPoint("TOPLEFT", parent.members[n - 1], "BOTTOMLEFT", 0, -1)
                    else
                        member.column[index]:SetPoint("TOPLEFT", member, "TOPLEFT", 0, 0)
                    end
                    WdLib:generateSpellHover(member.column[index], WdLib:getSpellLinkByIdWithTexture(spell_id))

                    index = index + 1
                    WdLib:addNextColumn(parent, member, index, "CENTER", v.timestamp)
                    index = index + 1
                    WdLib:addNextColumn(parent, member, index, "CENTER", k)
                    index = index + 1
                    WdLib:addNextColumn(parent, member, index, "LEFT", getInterruptStatusText(v))
                    WdLib:generateSpellHover(member.column[index], getInterruptStatusText(v))
                    index = index + 1
                    local percent = v.percent or 0
                    WdLib:addNextColumn(parent, member, index, "CENTER", percent)

                    table.insert(parent.members, member)
                else
                    local member = parent.members[n]
                    member.column[1].txt:SetText(WdLib:getSpellLinkByIdWithTexture(spell_id))
                    WdLib:generateSpellHover(member.column[1], WdLib:getSpellLinkByIdWithTexture(spell_id))
                    member.column[2].txt:SetText(v.timestamp)
                    member.column[3].txt:SetText(k)
                    member.column[4].txt:SetText(getInterruptStatusText(v))
                    WdLib:generateSpellHover(member.column[4], getInterruptStatusText(v))
                    local percent = v.percent or 0
                    member.column[5].txt:SetText(percent)

                    member:Show()
                    WdLib:updateScroller(parent.scroller.slider, totalCasts)
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
    --r.bg = WdLib:createColorTexture(r, "TEXTURE", 0, 0, 0, 1)
    --r.bg:SetAllPoints()

    r.headers = {}
    r.members = {}

    -- headers
    local h = WdLib:createTableHeader(r, "Spell", 0, 0, 170, 20)
    table.insert(r.headers, h)
    h = WdLib:createTableHeaderNext(r, h, WD_BUTTON_TIME, 70, 20)
    table.insert(r.headers, h)
    h = WdLib:createTableHeaderNext(r, h, "N", 25, 20)
    table.insert(r.headers, h)
    h = WdLib:createTableHeaderNext(r, h, "Status", 400, 20)
    table.insert(r.headers, h)
    h = WdLib:createTableHeaderNext(r, h, "Quality", 50, 20)
    WdLib:generateHover(h, WD_TRACKER_QUALITY_DESC)
    table.insert(r.headers, h)

    r:Hide()
end

local function updateCreatureButtons()
    for _,v in pairs(WDTO.creatures.members) do
        v.column[1].t:SetColorTexture(.2, .2, .2, 1)
    end

    if WDTO.lastSelectedCreature then
        WDTO.lastSelectedCreature.t:SetColorTexture(.2, .6, .2, 1)
    end
    updateInterruptsInfo()
end

local function initCreatureButtons()
    WDTO.creatures = CreateFrame("Frame", nil, WDTO)
    WDTO.creatures.headers = {}
    WDTO.creatures.members = {}
    table.insert(WDTO.creatures.headers, WdLib:createTableHeader(WDTO, "Casts info", 1, -30, 300, 20))
end

local function initPullsMenu()
    local function getPullName()
        if WD.db.profile.tracker.selected and
           WD.db.profile.tracker.selected > 0 and #WD.db.profile.tracker > 0 and
           WD.db.profile.tracker.selected <= #WD.db.profile.tracker
        then
            return WD.db.profile.tracker[WD.db.profile.tracker.selected].pullName
        elseif #WD.db.profile.tracker > 0 then
            WD.db.profile.tracker.selected = #WD.db.profile.tracker
            return WD.db.profile.tracker[#WD.db.profile.tracker].pullName
        end
        return "No pulls"
    end

    local function getPulls()
        local items = {}
        local function onSelect(frame, selected)
            WD.db.profile.tracker.selected = selected.index
            WDTO.lastSelectedCreature = nil
            WD:RefreshTrackedCreatures()
            WD:RefreshTrackedDispels()
        end
        local i = 1
        for k,v in pairs(WD.db.profile.tracker) do
            if type(v) == "table" then
                table.insert(items, {name = v.pullName, index = i, func = onSelect})
                i = i + 1
            end
        end
        return items
    end

    -- select pull button
    WDTO.buttons["select_pull"] = WdLib:createDropDownMenu(WDTO, getPullName(), getPulls())
    WDTO.buttons["select_pull"]:SetSize(150, 20)
    WDTO.buttons["select_pull"]:SetPoint("TOPLEFT", WDTO, "TOPLEFT", 1, -5)
    WDTO.buttons["select_pull"]:SetScript("OnShow", function(self) self.txt:SetText(getPullName()) end)
    local frame = WDTO.buttons["select_pull"]
    function frame:Refresh()
        WdLib:updateDropDownMenu(self, getPullName(), getPulls())
    end

    -- clear pulls history button
    WDTO.buttons["clear_pulls"] = WdLib:createButton(WDTO)
    WDTO.buttons["clear_pulls"]:SetPoint("TOPRIGHT", WDTO, "TOPRIGHT", -5, -5)
    WDTO.buttons["clear_pulls"]:SetSize(90, 20)
    WDTO.buttons["clear_pulls"]:SetScript("OnClick", function()
        WdLib:table_wipe(WD.db.profile.tracker)
        WD:RefreshTrackerPulls()
        WD:RefreshTrackedCreatures()
        WD:RefreshTrackedDispels()
    end)
    WDTO.buttons["clear_pulls"].txt = WdLib:createFont(WDTO.buttons["clear_pulls"], "CENTER", WD_TRACKER_BUTTON_CLEAR)
    WDTO.buttons["clear_pulls"].txt:SetAllPoints()
end

local function isCastedNpc(v)
    for spell_id,castInfo in pairs(v.casts) do
        if type(castInfo) == "table" and #castInfo > 0 then
            return true
        end
    end
    return nil
end

local function isDispelledUnit(v)
    for auraId,auraInfo in pairs(v.auras) do
        for _,aura in pairs(auraInfo) do
            if aura.dispell_id then
                return true
            end
        end
    end
    return nil
end

function WD:RefreshTrackedDispels()
    if not WDTO then return end

    if not WD.db.profile.tracker.selected or WD.db.profile.tracker.selected > #WD.db.profile.tracker or #WD.db.profile.tracker == 0 then
        WDTO.lastSelectedDispel = nil
        updateDispelInfo()
        for i=1, #WDTO.dispels.members do
            WDTO.dispels.members[i]:Hide()
        end
        updateDispelButtons()
        return
    end

    local dispels = {}
    for k,v in pairs(WD.db.profile.tracker[WD.db.profile.tracker.selected]) do
        if k == "npc" then
            for npcId,data in pairs(v) do
                for guid,npc in pairs(data) do
                    if type(npc) == "table" then
                        if isDispelledUnit(npc) then
                            npc.npc_id = npcId
                            dispels[#dispels+1] = npc
                        end
                    end
                end
            end
        elseif k == "players" then
            for guid,raider in pairs(v) do
                if isDispelledUnit(raider) then
                    dispels[#dispels+1] = raider
                end
            end
        end
    end

    if WDTO.lastSelectedDispel and #dispels == 0 then
        WDTO.lastSelectedDispel = nil
        updateDispelInfo()
    end

    local maxWidth = 30
    local maxHeight = 210
    local topLeftPosition = { x = 30, y = -51 }
    local rowsN = #dispels
    local columnsN = 1

    local func = function(a, b)
        return a.name < b.name
    end
    table.sort(dispels, func)

    local function createFn(parent, row, index)
        local v = dispels[row]
        parent.info = v
        if index == 1 then
            local unitName = v.name
            if v.rt > 0 then unitName = WdLib:getRaidTargetTextureLink(v.rt).." "..unitName end
            local f = WdLib:addNextColumn(WDTO.dispels, parent, index, "LEFT", unitName)
            f:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
            f:EnableMouse(true)
            f:SetScript("OnClick", function(self) WDTO.lastSelectedDispel = self; updateDispelButtons() end)
            if v.type == "creature" then
                WdLib:generateHover(f, "id: "..v.npc_id)
            end
            return f
        end
    end

    local function updateFn(frame, row, index)
        local v = dispels[row]
        frame:GetParent().info = v
        if index == 1 then
            local unitName = v.name
            if v.rt > 0 then unitName = WdLib:getRaidTargetTextureLink(v.rt).." "..unitName end
            frame.txt:SetText(unitName)
            frame:SetScript("OnClick", function(self) WDTO.lastSelectedDispel = self; updateDispelButtons() end)
            if v.type == "creature" then
                WdLib:generateHover(frame, "id: "..v.npc_id)
            end
        end
    end

    WdLib:updateScrollableTable(WDTO.dispels, maxWidth, maxHeight, topLeftPosition, rowsN, columnsN, createFn, updateFn)    

    if not WDTO.lastSelectedDispel and #dispels > 0 then
        WDTO.lastSelectedDispel = WDTO.dispels.members[1].column[1]
    end
    updateDispelButtons()
end

function WD:RefreshTrackedCreatures()
    if not WDTO then return end

    if not WD.db.profile.tracker.selected or WD.db.profile.tracker.selected > #WD.db.profile.tracker or #WD.db.profile.tracker == 0 then
        WDTO.lastSelectedCreature = nil
        updateInterruptsInfo()
        for i=1, #WDTO.creatures.members do
            WDTO.creatures.members[i]:Hide()
        end
        updateCreatureButtons()
        return
    end

    local creatures = {}
    for k,v in pairs(WD.db.profile.tracker[WD.db.profile.tracker.selected]) do
        if k == "npc" then
            for npcId,data in pairs(v) do
                for guid,npc in pairs(data) do
                    if type(npc) == "table" then
                        if isCastedNpc(npc) then
                            npc.npc_id = npcId
                            creatures[#creatures+1] = npc
                        end
                    end
                end
            end
        end
    end

    if WDTO.lastSelectedCreature and #creatures == 0 then
        WDTO.lastSelectedCreature = nil
        updateInterruptsInfo()
    end
    
    local maxWidth = 30
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
            local unitName = v.name
            if v.rt > 0 then unitName = WdLib:getRaidTargetTextureLink(v.rt).." "..unitName end
            local f = WdLib:addNextColumn(WDTO.creatures, parent, index, "LEFT", unitName)
            f:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
            f:EnableMouse(true)
            f:SetScript("OnClick", function(self) WDTO.lastSelectedCreature = self; updateCreatureButtons() end)
            WdLib:generateHover(f, "id: "..v.npc_id)
            return f
        end
    end

    local function updateFn(frame, row, index)
        local v = creatures[row]
        frame:GetParent().info = v
        if index == 1 then
            local unitName = v.name
            if v.rt > 0 then unitName = WdLib:getRaidTargetTextureLink(v.rt).." "..unitName end
            frame.txt:SetText(unitName)
            frame:SetScript("OnClick", function(self) WDTO.lastSelectedCreature = self; updateCreatureButtons() end)
            WdLib:generateHover(frame, "id: "..v.npc_id)
        end
    end

    WdLib:updateScrollableTable(WDTO.creatures, maxWidth, maxHeight, topLeftPosition, rowsN, columnsN, createFn, updateFn)    

    if not WDTO.lastSelectedCreature and #creatures > 0 then
        WDTO.lastSelectedCreature = WDTO.creatures.members[1].column[1]
    end
    updateCreatureButtons()
end

function WD:RefreshTrackerPulls()
    WDTO.buttons["select_pull"]:Refresh()
end

function WD:InitTrackerOverviewModule(parent)
    WDTO = parent

    WDTO.buttons = {}
    WDTO.data = {}

    initPullsMenu()
    initCreatureButtons()
    initInterruptsInfoTable()
    initDispelButtons()
    initDispelInfoTable()

    function WDTO:OnUpdate()
        WD:RefreshTrackedCreatures()
        WD:RefreshTrackedDispels()
    end
end
