
local WDTS = nil

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

local function generateSpellChart(data)
    local chart = {}
    if not data then return chart end
    for spellId,amount in pairs(data) do
        if tonumber(spellId) and amount > 0 then
            chart[#chart+1] = { id = spellId, value = amount, percent = amount * 100 / data.total }
        end
    end

    local func = function(a, b)
        if a.value > b.value then
            return true
        elseif a.value < b.value then
            return false
        end
        return a.id < b.id
    end
    table.sort(chart, func)

    return chart
end

local function showPopup(parent, data)
    local chart = generateSpellChart(data)
    if #chart == 0 then return end
    WDTS.popup:SetPoint("TOP", parent, "TOP", 0, 0)
    WDTS.popup:SetHeight(#chart * 21 + 1)

    for _,v in pairs(WDTS.popup.members) do
        v:Hide()
    end

    local delta = 100 - chart[1].percent
    for i=1,#chart do
        WDTS.popup.members[i]:SetValue(chart[i].percent + delta)
        WDTS.popup.members[i].leftTxt:SetText(i..WdLib:getSpellLinkByIdWithTexture(chart[i].id))
        WDTS.popup.members[i].rightTxt:SetText(WdLib:shortNumber(chart[i].value).." ("..WdLib:float_round_to(chart[i].percent, 1).."%)")
        WDTS.popup.members[i]:Show()
    end

    WDTS.popup:Show()
end

local function hidePopup()
    WDTS.popup:Hide()
end

local function initSpellChartPopup()
    WDTS.popup = CreateFrame("Frame", nil, WDTS)
    WDTS.popup:SetFrameStrata("TOOLTIP")
    WDTS.popup:SetWidth(302)
    WDTS.popup.bg = WdLib:createColorTexture(WDTS.popup, "BACKGROUND", 0, 0, 0, .9)
    WDTS.popup.bg:SetAllPoints()

    WDTS.popup.members = {}
    for i=1,25 do
        local r = CreateFrame("StatusBar", nil, WDTS.popup)
        r:SetStatusBarTexture([[Interface\AddOns\WagonDetector\media\statusbars\otravi]])
        r:GetStatusBarTexture():SetHorizTile(false)
        r:GetStatusBarTexture():SetVertTile(false)
        r:SetMinMaxValues(0, 100)
        r:SetStatusBarColor(.1,.2,.1,1)
        r:SetSize(300, 20)
        r.leftTxt = WdLib:createFontDefault(r, "LEFT", "")
        r.leftTxt:SetSize(200, 20)
        r.leftTxt:SetPoint("LEFT", r, "LEFT", 2, 0)
        r.rightTxt = WdLib:createFontDefault(r, "RIGHT", "")
        r.rightTxt:SetSize(100, 20)
        r.rightTxt:SetPoint("RIGHT", r, "RIGHT", -2, 0)
        if i == 1 then
            r:SetPoint("TOPLEFT", WDTS.popup, "TOPLEFT", 1, -1)
        else
            r:SetPoint("TOPLEFT", WDTS.popup.members[i-1], "BOTTOMLEFT", 0, -1)
        end
        WDTS.popup.members[#WDTS.popup.members+1] = r
    end

    WDTS.popup:Hide()
end

local function updateInfo()
    local core = WD.mainFrame

    for _,v in pairs(WDTS.data["info_1"].members) do
        v:Hide()
    end

    local chart = {}
    if WDTS.lastSelectedUnit then
        local v = WDTS.lastSelectedUnit:GetParent().info
        for guid,info in pairs(v.stats) do
            local target = findEntityByGUID(guid)
            chart[#chart+1] = { id = WdLib:getColoredName(target.name, target.class), data = info }
        end
    end

    local func = function(a, b)
        if a.data.healDone and b.data.healDone and a.data.healDone.total > b.data.healDone.total then
            return true
        elseif a.data.healDone and b.data.healDone and a.data.healDone.total < b.data.healDone.total then
            return false
        elseif a.data.overhealDone and b.data.overhealDone and a.data.overhealDone.total > b.data.overhealDone.total then
            return true
        elseif a.data.overhealDone and b.data.overhealDone and a.data.overhealDone.total < b.data.overhealDone.total then
            return false
        elseif a.data.healTaken and b.data.healTaken and a.data.healTaken.total > b.data.healTaken.total then
            return true
        elseif a.data.healTaken and b.data.healTaken and a.data.healTaken.total < b.data.healTaken.total then
            return false
        elseif a.data.overhealTaken and b.data.overhealTaken and a.data.overhealTaken.total > b.data.overhealTaken.total then
            return true
        elseif a.data.overhealTaken and b.data.overhealTaken and a.data.overhealTaken.total < b.data.overhealTaken.total then
            return false
        end
        return a.id < b.id
    end
    table.sort(chart, func)

    local maxHeight = 210
    local topLeftPosition = { x = 30, y = -51 }
    local rowsN = #chart
    local columnsN = 5

    local function createFn(parent, row, index)
        local target = chart[row].id
        local v = chart[row].data
        if index == 1 then
            local value = 0
            if v.healDone then value = v.healDone.total end
            local f = WdLib:addNextColumn(WDTS.data["info_1"], parent, index, "CENTER", WdLib:shortNumber(value))
            f:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
            f:SetScript("OnEnter", function() showPopup(f, v.healDone) end)
            f:SetScript("OnLeave", hidePopup)
            return f
        elseif index == 2 then
            local value = 0
            if v.overhealDone then value = v.overhealDone.total end
            local f = WdLib:addNextColumn(WDTS.data["info_1"], parent, index, "CENTER", WdLib:shortNumber(value))
            f:SetScript("OnEnter", function() showPopup(f, v.overhealDone) end)
            f:SetScript("OnLeave", hidePopup)
            return f
        elseif index == 3 then
            local value = 0
            if v.healTaken then value = v.healTaken.total end
            local f = WdLib:addNextColumn(WDTS.data["info_1"], parent, index, "CENTER", WdLib:shortNumber(value))
            f:SetScript("OnEnter", function() showPopup(f, v.healTaken) end)
            f:SetScript("OnLeave", hidePopup)
            return f
        elseif index == 4 then
            local value = 0
            if v.overhealTaken then value = v.overhealTaken.total end
            local f = WdLib:addNextColumn(WDTS.data["info_1"], parent, index, "CENTER", WdLib:shortNumber(value))
            f:SetScript("OnEnter", function() showPopup(f, v.overhealTaken) end)
            f:SetScript("OnLeave", hidePopup)
            return f
        elseif index == 5 then
            return WdLib:addNextColumn(WDTS.data["info_1"], parent, index, "LEFT", target)
        end
    end

    local function updateFn(f, row, index)
        local target = chart[row].id
        local v = chart[row].data
        if index == 1 then
            local value = 0
            if v.healDone then value = v.healDone.total end
            f.txt:SetText(WdLib:shortNumber(value))
            f:SetScript("OnEnter", function() showPopup(f, v.healDone) end)
        elseif index == 2 then
            local value = 0
            if v.overhealDone then value = v.overhealDone.total end
            f.txt:SetText(WdLib:shortNumber(value))
            f:SetScript("OnEnter", function() showPopup(f, v.overhealDone) end)
        elseif index == 3 then
            local value = 0
            if v.healTaken then value = v.healTaken.total end
            f.txt:SetText(WdLib:shortNumber(value))
            f:SetScript("OnEnter", function() showPopup(f, v.healTaken) end)
        elseif index == 4 then
            local value = 0
            if v.overhealTaken then value = v.overhealTaken.total end
            f.txt:SetText(WdLib:shortNumber(value))
            f:SetScript("OnEnter", function() showPopup(f, v.overhealTaken) end)
        elseif index == 5 then
            f.txt:SetText(target)
        end
    end

    WdLib:updateScrollableTable(WDTS.data["info_1"], maxHeight, topLeftPosition, rowsN, columnsN, createFn, updateFn)

    WDTS.data["info_1"]:Show()
end

local function updateUnitButtons()
    for _,v in pairs(WDTS.units.members) do
        v.column[1].t:SetColorTexture(.2, .2, .2, 1)
    end

    if WDTS.lastSelectedUnit then
        WDTS.lastSelectedUnit.t:SetColorTexture(.2, .6, .2, 1)
    end
    updateInfo()
end

local function initInfoTable()
    WDTS.data["info_1"] = CreateFrame("Frame", nil, WDTS)
    local r = WDTS.data["info_1"]
    r:SetPoint("TOPLEFT", WDTS.units.headers[1], "TOPRIGHT", 1, 0)
    r:SetSize(550, 300)

    r.headers = {}
    r.members = {}

    -- headers
    local h = WdLib:createTableHeader(r, "Heal done", 0, 0, 120, 20)
    table.insert(r.headers, h)
    h = WdLib:createTableHeaderNext(r, h, "Overheal done", 120, 20)
    table.insert(r.headers, h)
    h = WdLib:createTableHeaderNext(r, h, "Heal taken", 120, 20)
    table.insert(r.headers, h)
    h = WdLib:createTableHeaderNext(r, h, "Overheal taken", 120, 20)
    table.insert(r.headers, h)
    h = WdLib:createTableHeaderNext(r, h, "Target unit", 250, 20)
    table.insert(r.headers, h)

    r:Hide()
end

local function initUnitButtons()
    WDTS.units = CreateFrame("Frame", nil, WDTS)
    WDTS.units.headers = {}
    WDTS.units.members = {}
    table.insert(WDTS.units.headers, WdLib:createTableHeader(WDTS, "Source units", 1, -30, 300, 20))
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
            WDTS.lastSelectedUnit = nil
            WD:RefreshUnitStatistics()
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
    WDTS.buttons["select_pull"] = WdLib:createDropDownMenu(WDTS, getPullName(), getPulls())
    WDTS.buttons["select_pull"]:SetSize(200, 20)
    WDTS.buttons["select_pull"]:SetPoint("TOPLEFT", WDTS, "TOPLEFT", 1, -5)
    WDTS.buttons["select_pull"]:SetScript("OnShow", function(self) self.txt:SetText(getPullName()) end)
    local frame = WDTS.buttons["select_pull"]
    function frame:Refresh()
        WdLib:updateDropDownMenu(self, getPullName(), getPulls())
    end
end

local function filterBySelectedRule(v)
    if not v.stats then return nil end
    for guid,info in pairs(v.stats) do
        return true
    end
    return nil
end

local function getUnitStatistics()
    local units = {}
    if not WD.db.profile.tracker or not WD.db.profile.tracker.selected or WD.db.profile.tracker.selected > #WD.db.profile.tracker or #WD.db.profile.tracker == 0 then
        return units
    end

    for k,v in pairs(WD.db.profile.tracker[WD.db.profile.tracker.selected]) do
        if k == "npc" then
            for npcId,data in pairs(v) do
                for _,npc in pairs(data) do
                    if type(npc) == "table" then
                        if filterBySelectedRule(npc) then
                            local npcCopy = WdLib:table_deepcopy(npc)
                            npcCopy.npc_id = npcId
                            units[#units+1] = npcCopy
                        end
                    end
                end
            end
        elseif k == "pets" then
            for parentGuid,info in pairs(v) do
                if parentGuid:match("Creature") then
                    for npcId,data in pairs(info) do
                        for _,pet in pairs(data) do
                            if filterBySelectedRule(pet) then
                                local petCopy = WdLib:table_deepcopy(pet)
                                petCopy.npc_id = npcId
                                petCopy.name = "[pet] "..petCopy.name
                                units[#units+1] = petCopy
                            end
                        end
                    end
                end
            end
        elseif k == "players" then
            for guid,pl in pairs(v) do
                if type(pl) == "table" then
                    if filterBySelectedRule(pl) then
                        local plCopy = WdLib:table_deepcopy(pl)
                        plCopy.npc_id = "player"
                        units[#units+1] = plCopy
                    end
                end
            end
        end
    end
    return units
end

function WD:RefreshUnitStatistics()
    if not WDTS then return end

    local units = getUnitStatistics()

    if WDTS.lastSelectedUnit and #units == 0 then
        WDTS.lastSelectedUnit = nil
        updateInfo()
    end

    local maxHeight = 210
    local topLeftPosition = { x = 30, y = -51 }
    local rowsN = #units
    local columnsN = 1

    local func = function(a, b)
        return a.name < b.name
    end
    table.sort(units, func)

    local function createFn(parent, row, index)
        local v = units[row]
        parent.info = v
        if index == 1 then
            local unitName = WdLib:getColoredName(v.name, v.class)
            if v.rt > 0 then unitName = WdLib:getRaidTargetTextureLink(v.rt).." "..unitName end
            local f = WdLib:addNextColumn(WDTS.units, parent, index, "LEFT", unitName)
            f:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
            f:EnableMouse(true)
            f:SetScript("OnClick", function(self) WDTS.lastSelectedUnit = self; updateUnitButtons() end)
            if v.parentName then
                WdLib:generateHover(f, {"id: "..v.npc_id, "Summoned by: |cffffff00"..v.parentName.."|r"})
            else
                WdLib:generateHover(f, "id: "..v.npc_id)
            end
            return f
        end
    end

    local function updateFn(f, row, index)
        local v = units[row]
        f:GetParent().info = v
        if index == 1 then
            local unitName = WdLib:getColoredName(v.name, v.class)
            if v.rt > 0 then unitName = WdLib:getRaidTargetTextureLink(v.rt).." "..unitName end
            f.txt:SetText(unitName)
            f:SetScript("OnClick", function(self) WDTS.lastSelectedUnit = self; updateUnitButtons() end)
            if v.parentName then
                WdLib:generateHover(f, {"id: "..v.npc_id, "Summoned by: |cffffff00"..v.parentName.."|r"})
            else
                WdLib:generateHover(f, "id: "..v.npc_id)
            end
        end
    end

    WdLib:updateScrollableTable(WDTS.units, maxHeight, topLeftPosition, rowsN, columnsN, createFn, updateFn)

    if not WDTS.lastSelectedUnit and #units > 0 then
        WDTS.lastSelectedUnit = WDTS.units.members[1].column[1]
    end
    updateUnitButtons()
end

function WD:InitTrackerStatisticsModule(parent)
    WDTS = parent

    WDTS.buttons = {}
    WDTS.data = {}

    initPullsMenu()
    initUnitButtons()
    initInfoTable()
    initSpellChartPopup()

    WDTS:SetScript("OnShow", function(self) self:OnUpdate() end)

    function WDTS:OnUpdate()
        WD:RefreshUnitStatistics()
    end
end
