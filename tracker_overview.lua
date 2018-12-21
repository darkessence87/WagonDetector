
local WDTO = nil

local function findNpc(guid)
    if not WD.db.profile.tracker or not WD.db.profile.tracker.selected then return nil end
    local t = WD.db.profile.tracker[WD.db.profile.tracker.selected]
    if not guid or not guid:match("Creature") then return nil end
    local npcId = WdLib:getNpcId(guid)
    local holder = t.npc[npcId]
    local index = WdLib:findEntityIndex(holder, guid)
    if index then return holder[index] end
    return nil
end

local function findPet(guid)
    if not WD.db.profile.tracker or not WD.db.profile.tracker.selected then return nil end
    local t = WD.db.profile.tracker[WD.db.profile.tracker.selected]
    if not guid then return nil end
    for parentGuid,infoByNpcId in pairs(t.pets) do
        for name,infoByGuid in pairs(infoByNpcId) do
            local index = WdLib:findEntityIndex(infoByGuid, guid)
            if index then return infoByGuid[index] end
        end
    end
    return nil
end

local function findPlayer(guid)
    if not WD.db.profile.tracker or not WD.db.profile.tracker.selected then return nil end
    local t = WD.db.profile.tracker[WD.db.profile.tracker.selected]
    return t.players[guid]
end

local function findEntityByGUID(guid)
    local result = findPlayer(guid)
    if result then return result end
    result = findPet(guid)
    if result then return result end
    result = findNpc(guid)
    if result then return result end
    return nil
end

local function getDispelledAuras(auras)
    local result = {}
    for auraId,auraInfo in pairs(auras) do
        for i=1,#auraInfo do
            if auraInfo[i].dispell_id then
                result[#result+1] = { N = i, id = auraId, data = auraInfo[i] }
            end
        end
    end
    return result
end

local function getInterruptStatusText(v)
    if v.status == "INTERRUPTED" then
        local interrupterName = UNKNOWNOBJECT
        if type(v.interrupter) == "table" then
            interrupterName = WdLib:getColoredName(WdLib:getShortName(v.interrupter.name, "noRealm"), v.interrupter.class)
        else
            local interrupter = findEntityByGUID(v.interrupter)
            if interrupter then
                interrupterName = WdLib:getColoredName(WdLib:getShortName(interrupter.name, "noRealm"), interrupter.class)
            end
        end
        return string.format(WD_TRACKER_INTERRUPTED_BY, interrupterName, WdLib:getSpellLinkByIdWithTexture(v.spell_id), v.timediff)
    elseif v.status == "SUCCESS" then
        return string.format(WD_TRACKER_CASTED_IN, v.timediff)
    end

    return v.status
end

local function getDispelStatusText(v)
    local dispellerName = UNKNOWNOBJECT
    if type(v.dispeller) == "table" then
        dispellerName = WdLib:getColoredName(WdLib:getShortName(v.dispeller.name, "noRealm"), v.dispeller.class)
    else
        local dispeller = findEntityByGUID(v.dispeller)
        if dispeller then
            dispellerName = WdLib:getColoredName(WdLib:getShortName(dispeller.name, "noRealm"), dispeller.class)
        end
    end
    return string.format(WD_TRACKER_DISPELLED_BY, dispellerName, WdLib:getSpellLinkByIdWithTexture(v.dispell_id), v.dispelledIn)
end

local function updateDispelInfo()
    local core = WD.mainFrame

    for _,v in pairs(WDTO.data["dispel"].members) do
        v:Hide()
    end

    local auras = {}
    if WDTO.lastSelectedDispel then
        local v = WDTO.lastSelectedDispel:GetParent().info
        auras = getDispelledAuras(v.auras)
    end

    local maxHeight = 210
    local topLeftPosition = { x = 30, y = -51 }
    local rowsN = #auras
    local columnsN = 4

    local function createFn(parent, row, index)
        local auraId = auras[row].id
        local N = auras[row].N
        local v = auras[row].data
        if index == 1 then
            local f = WdLib:addNextColumn(WDTO.data["dispel"], parent, index, "LEFT", WdLib:getSpellLinkByIdWithTexture(auraId))
            f:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
            local caster = findEntityByGUID(v.caster)
            if caster then
                caster = WdLib:getColoredName(WdLib:getShortName(caster.name, "noRealm"), caster.class)
            else
                caster = "|cffffffffEnvironment|r"
            end
            WdLib:generateSpellHover(f, WdLib:getSpellLinkByIdWithTexture(auraId), "|cffffff00Casted by:|r "..caster)
            return f
        elseif index == 2 then
            return WdLib:addNextColumn(WDTO.data["dispel"], parent, index, "CENTER", v.dispelledAt)
        elseif index == 3 then
            return WdLib:addNextColumn(WDTO.data["dispel"], parent, index, "CENTER", N)
        elseif index == 4 then
            local f = WdLib:addNextColumn(WDTO.data["dispel"], parent, index, "LEFT", getDispelStatusText(v))
            WdLib:generateSpellHover(f, getDispelStatusText(v))
            return f
        end
    end

    local function updateFn(f, row, index)
        local auraId = auras[row].id
        local N = auras[row].N
        local v = auras[row].data
        if index == 1 then
            f.txt:SetText(WdLib:getSpellLinkByIdWithTexture(auraId))
            local caster = findEntityByGUID(v.caster)
            if caster then
                caster = WdLib:getColoredName(WdLib:getShortName(caster.name, "noRealm"), caster.class)
            else
                caster = "|cffffffffEnvironment|r"
            end
            WdLib:generateSpellHover(f, WdLib:getSpellLinkByIdWithTexture(auraId), "|cffffff00Casted by:|r "..caster)
        elseif index == 2 then
            f.txt:SetText(v.dispelledAt)
        elseif index == 3 then
            f.txt:SetText(N)
        elseif index == 4 then
            f.txt:SetText(getDispelStatusText(v))
            WdLib:generateSpellHover(f, getDispelStatusText(v))
        end
    end

    WdLib:updateScrollableTable(WDTO.data["dispel"], maxHeight, topLeftPosition, rowsN, columnsN, createFn, updateFn)

    WDTO.data["dispel"]:Show()
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

    for _,v in pairs(WDTO.data["interrupts"].members) do
        v:Hide()
    end

    local casts = {}
    if WDTO.lastSelectedCreature then
        local v = WDTO.lastSelectedCreature:GetParent().info
        for spellId,castInfo in pairs(v.casts) do
            if type(castInfo) == "table" then
                for i=1,#castInfo do
                    casts[#casts+1] = { N = i, id = spellId, data = castInfo[i] }
                end
            end
        end
    end

    local maxHeight = 210
    local topLeftPosition = { x = 30, y = -51 }
    local rowsN = #casts
    local columnsN = 5

    local function createFn(parent, row, index)
        local spellId = casts[row].id
        local N = casts[row].N
        local v = casts[row].data
        if index == 1 then
            local f = WdLib:addNextColumn(WDTO.data["interrupts"], parent, index, "LEFT", WdLib:getSpellLinkByIdWithTexture(spellId))
            f:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
            WdLib:generateSpellHover(f, WdLib:getSpellLinkByIdWithTexture(spellId))
            return f
        elseif index == 2 then
            return WdLib:addNextColumn(WDTO.data["interrupts"], parent, index, "CENTER", v.timestamp)
        elseif index == 3 then
            return WdLib:addNextColumn(WDTO.data["interrupts"], parent, index, "CENTER", N)
        elseif index == 4 then
            local f = WdLib:addNextColumn(WDTO.data["interrupts"], parent, index, "LEFT", getInterruptStatusText(v))
            WdLib:generateSpellHover(f, getInterruptStatusText(v))
            return f
        elseif index == 5 then
            return WdLib:addNextColumn(WDTO.data["interrupts"], parent, index, "CENTER", v.percent or 0)
        end
    end

    local function updateFn(f, row, index)
        local spellId = casts[row].id
        local N = casts[row].N
        local v = casts[row].data
        if index == 1 then
            f.txt:SetText(WdLib:getSpellLinkByIdWithTexture(spellId))
            WdLib:generateSpellHover(f, WdLib:getSpellLinkByIdWithTexture(spellId))
        elseif index == 2 then
            f.txt:SetText(v.timestamp)
        elseif index == 3 then
            f.txt:SetText(N)
        elseif index == 4 then
            f.txt:SetText(getInterruptStatusText(v))
            WdLib:generateSpellHover(f, getInterruptStatusText(v))
        elseif index == 5 then
            f.txt:SetText(v.percent or 0)
        end
    end

    WdLib:updateScrollableTable(WDTO.data["interrupts"], maxHeight, topLeftPosition, rowsN, columnsN, createFn, updateFn)

    WDTO.data["interrupts"]:Show()
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
            WDTO.lastSelectedDispel = nil
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
    WDTO.buttons["select_pull"]:SetSize(200, 20)
    WDTO.buttons["select_pull"]:SetPoint("TOPLEFT", WDTO, "TOPLEFT", 1, -5)
    WDTO.buttons["select_pull"]:SetScript("OnShow", function(self) self.txt:SetText(getPullName()) end)
    local frame = WDTO.buttons["select_pull"]
    function frame:Refresh()
        WdLib:updateDropDownMenu(self, getPullName(), getPulls())
    end

    -- clear current pull history button
    WDTO.buttons["clear_current_pull"] = WdLib:createButton(WDTO)
    WDTO.buttons["clear_current_pull"]:SetSize(90, 20)
    WDTO.buttons["clear_current_pull"]:SetScript("OnClick", function()
        if WD.db.profile.tracker and WD.db.profile.tracker.selected and WD.db.profile.tracker.selected > 0 then
            table.remove(WD.db.profile.tracker, WD.db.profile.tracker.selected)
            if #WD.db.profile.tracker == 0 then
                WD.db.profile.tracker.selected = 0
            elseif WD.db.profile.tracker.selected > #WD.db.profile.tracker then
                WD.db.profile.tracker.selected = #WD.db.profile.tracker
            end
        end
        WD:RefreshTrackerPulls()
        WD:RefreshTrackedCreatures()
        WD:RefreshTrackedDispels()
    end)
    WDTO.buttons["clear_current_pull"].txt = WdLib:createFont(WDTO.buttons["clear_current_pull"], "CENTER", WD_TRACKER_BUTTON_CLEAR_SELECTED)
    WDTO.buttons["clear_current_pull"].txt:SetAllPoints()

    -- clear pulls history button
    WDTO.buttons["clear_pulls"] = WdLib:createButton(WDTO)
    WDTO.buttons["clear_pulls"]:SetSize(90, 20)
    WDTO.buttons["clear_pulls"]:SetScript("OnClick", function()
        WdLib:table_wipe(WD.db.profile.tracker)
        WD:RefreshTrackerPulls()
        WD:RefreshTrackedCreatures()
        WD:RefreshTrackedDispels()
    end)
    WDTO.buttons["clear_pulls"].txt = WdLib:createFont(WDTO.buttons["clear_pulls"], "CENTER", WD_TRACKER_BUTTON_CLEAR)
    WDTO.buttons["clear_pulls"].txt:SetAllPoints()

    WDTO.buttons["clear_pulls"]:SetPoint("TOPRIGHT", WDTO, "TOPRIGHT", -5, -5)
    WDTO.buttons["clear_current_pull"]:SetPoint("TOPRIGHT", WDTO.buttons["clear_pulls"], "TOPLEFT", -1, 0)
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

local function getDispelledUnits()
    local units = {}
    if not WD.db.profile.tracker or not WD.db.profile.tracker.selected or WD.db.profile.tracker.selected > #WD.db.profile.tracker or #WD.db.profile.tracker == 0 then
        return units
    end
    for k,v in pairs(WD.db.profile.tracker[WD.db.profile.tracker.selected]) do
        if k == "npc" then
            for npcId,data in pairs(v) do
                for guid,npc in pairs(data) do
                    if type(npc) == "table" then
                        if isDispelledUnit(npc) then
                            npc.npc_id = npcId
                            units[#units+1] = npc
                        end
                    end
                end
            end
        elseif k == "players" then
            for guid,raider in pairs(v) do
                if isDispelledUnit(raider) then
                    units[#units+1] = raider
                end
            end
        end
    end
    return units
end

local function getCastedCreatures()
    local creatures = {}
    if not WD.db.profile.tracker or not WD.db.profile.tracker.selected or WD.db.profile.tracker.selected > #WD.db.profile.tracker or #WD.db.profile.tracker == 0 then
        return creatures
    end

    for k,v in pairs(WD.db.profile.tracker[WD.db.profile.tracker.selected]) do
        if k == "npc" then
            for npcId,data in pairs(v) do
                for _,npc in pairs(data) do
                    if type(npc) == "table" then
                        if isCastedNpc(npc) then
                            local npcCopy = WdLib:table_deepcopy(npc)
                            npcCopy.npc_id = npcId
                            creatures[#creatures+1] = npcCopy
                        end
                    end
                end
            end
        elseif k == "pets" then
            for parentGuid,info in pairs(v) do
                if parentGuid:match("Creature") then
                    for npcId,data in pairs(info) do
                        for _,pet in pairs(data) do
                            --print(WdLib:table_tostring(pet))
                            if isCastedNpc(pet) then
                                local petCopy = WdLib:table_deepcopy(pet)
                                petCopy.npc_id = npcId
                                petCopy.name = "[pet] "..petCopy.name
                                creatures[#creatures+1] = petCopy
                            end
                        end
                    end
                end
            end
        --[[elseif k == "players" then
            for guid,pl in pairs(v) do
                if type(pl) == "table" then
                    if isCastedNpc(pl) then
                        local plCopy = WdLib:table_deepcopy(pl)
                        plCopy.npc_id = "player"
                        creatures[#creatures+1] = plCopy
                    end
                end
            end]]
        end
    end
    return creatures
end

function WD:RefreshTrackedDispels()
    if not WDTO then return end

    local dispels = getDispelledUnits()

    if WDTO.lastSelectedDispel and #dispels == 0 then
        WDTO.lastSelectedDispel = nil
        updateDispelInfo()
    end

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

    local function updateFn(f, row, index)
        local v = dispels[row]
        f:GetParent().info = v
        if index == 1 then
            local unitName = v.name
            if v.rt > 0 then unitName = WdLib:getRaidTargetTextureLink(v.rt).." "..unitName end
            f.txt:SetText(unitName)
            f:SetScript("OnClick", function(self) WDTO.lastSelectedDispel = self; updateDispelButtons() end)
            if v.type == "creature" then
                WdLib:generateHover(f, "id: "..v.npc_id)
            end
        end
    end

    WdLib:updateScrollableTable(WDTO.dispels, maxHeight, topLeftPosition, rowsN, columnsN, createFn, updateFn)

    if not WDTO.lastSelectedDispel and #dispels > 0 then
        WDTO.lastSelectedDispel = WDTO.dispels.members[1].column[1]
    end
    updateDispelButtons()
end

function WD:RefreshTrackedCreatures()
    if not WDTO then return end

    local creatures = getCastedCreatures()

    if WDTO.lastSelectedCreature and #creatures == 0 then
        WDTO.lastSelectedCreature = nil
        updateInterruptsInfo()
    end

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
            if v.parentName then
                WdLib:generateHover(f, {"id: "..v.npc_id, "Summoned by: |cffffff00"..v.parentName.."|r"})
            else
                WdLib:generateHover(f, "id: "..v.npc_id)
            end
            return f
        end
    end

    local function updateFn(f, row, index)
        local v = creatures[row]
        f:GetParent().info = v
        if index == 1 then
            local unitName = v.name
            if v.rt > 0 then unitName = WdLib:getRaidTargetTextureLink(v.rt).." "..unitName end
            f.txt:SetText(unitName)
            f:SetScript("OnClick", function(self) WDTO.lastSelectedCreature = self; updateCreatureButtons() end)
            if v.parentName then
                WdLib:generateHover(f, {"id: "..v.npc_id, "Summoned by: |cffffff00"..v.parentName.."|r"})
            else
                WdLib:generateHover(f, "id: "..v.npc_id)
            end
        end
    end

    WdLib:updateScrollableTable(WDTO.creatures, maxHeight, topLeftPosition, rowsN, columnsN, createFn, updateFn)

    if not WDTO.lastSelectedCreature and #creatures > 0 then
        WDTO.lastSelectedCreature = WDTO.creatures.members[1].column[1]
    end
    updateCreatureButtons()
end

function WD:RefreshTrackerPulls()
    if WD.guiFrame.module["tracker_overview"] then
        WD.guiFrame.module["tracker_overview"].buttons["select_pull"]:Refresh()
    end
    if WD.guiFrame.module["tracker_statistics"] then
        WD.guiFrame.module["tracker_statistics"].buttons["select_pull"]:Refresh()
        WD.guiFrame.module["tracker_statistics"].buttons["select_rule"]:Refresh()
    end
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

    WDTO:SetScript("OnShow", function(self) self:OnUpdate() end)

    function WDTO:OnUpdate()
        WD:RefreshTrackedCreatures()
        WD:RefreshTrackedDispels()
    end
end
