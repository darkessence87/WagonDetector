
local POPUP_MAX_SPELLS = 25

local WDStatsMonitor = {}
WDStatsMonitor.__index = WDStatsMonitor

setmetatable(WDStatsMonitor, {
    __index = WD.Monitor,
    __call = function (v, ...)
        local self = setmetatable({}, v)
        self:init(...)
        return self
    end,
})

function WDStatsMonitor:init(parent, name)
    WD.Monitor.init(self, parent, name)
    self.frame.cache = {}
    self.frame.cache.units = {}
end

function WDStatsMonitor:findParentPet(parentGuid, pet)
    local parent = self:findEntityByGUID(parentGuid)
    if not parent then return pet end
    if parent.type == "pet" then
        return self:findParentPet(parent.parentGuid, parent)
    end
    return pet
end

function WDStatsMonitor:getSelectedRuleType()
    local pull = self.frame:GetParent():GetSelectedPull()
    if not pull then return nil end
    if pull.statRules and pull.selectedRule and pull.statRules[pull.selectedRule] then
        return pull.statRules[pull.selectedRule].data.arg0
    else
        return pull.selectedRule
    end
    return nil
end

function WDStatsMonitor:getSelectedRule()
    local pull = self.frame:GetParent():GetSelectedPull()
    if not pull then return nil end
    if pull.statRules and pull.selectedRule and pull.statRules[pull.selectedRule] then
        return pull.statRules[pull.selectedRule]
    else
        return pull.selectedRule
    end
    return nil
end

function WDStatsMonitor:getCurrentFilter()
    local ruleType = self:getSelectedRuleType()
    if not ruleType then return nil end
    if ruleType == "TOTAL_DONE" or
       ruleType == "ST_SOURCE_DAMAGE" or
       ruleType == "ST_SOURCE_HEALING" or
       ruleType == "ST_SOURCE_INTERRUPTS"
    then
        return "done"
    elseif ruleType == "TOTAL_TAKEN" or
       ruleType == "ST_TARGET_DAMAGE" or
       ruleType == "ST_TARGET_HEALING" or
       ruleType == "ST_TARGET_INTERRUPTS"
    then
        return "taken"
    end
    print("Unknown rule type:"..ruleType)
    return nil
end

function WDStatsMonitor:getPopupLabelByMode(mode)
    local ruleType = self:getSelectedRuleType()
    if not ruleType then return nil end
    if ruleType == "TOTAL_DONE" or
       ruleType == "ST_SOURCE_DAMAGE" or
       ruleType == "ST_SOURCE_HEALING" or
       ruleType == "ST_SOURCE_INTERRUPTS"
    then
        if mode == "heal" then return "Total healing done by %s" end
        if mode == "dmg" then return "Total damage done by %s" end
    elseif ruleType == "TOTAL_TAKEN" or
       ruleType == "ST_TARGET_DAMAGE" or
       ruleType == "ST_TARGET_HEALING" or
       ruleType == "ST_TARGET_INTERRUPTS"
    then
        if mode == "heal" then return "Total healing taken by %s" end
        if mode == "dmg" then return "Total damage taken by %s" end
    end
    print("Unknown rule type:"..ruleType)
    return nil
end

local function generateSpellChart(data)
    local function getSpellTypeByEvent(event)
        if event:match("PERIODIC") then
            if event:match("HEAL") then return "(HOT)" end
            if event:match("DAMAGE") then return "(DOT)" end
        end
        if event:match("ABSORB") then
            return "(ABSORB)"
        end
        if event:match("SHIELD") then
            return "(REFLECT)"
        end
        return nil
    end

    local function createSpellRow(chart, event, spellId, amount, petName)
        if amount > 0 then
            if spellId == ACTION_SWING then
                spellId = 260421
            end
            local t = {}
            t.index = #chart+1
            t.id = spellId
            local spellType = getSpellTypeByEvent(event)
            if spellType and tonumber(spellId) then
                t.spellName = GetSpellInfo(spellId).." "..spellType
            elseif spellType then
                t.spellName = " |cffffffff"..spellId.." "..spellType.."|r"
            end

            if petName then
                if t.spellName then
                    t.spellName = t.spellName.." |cffffffff("..petName..")|r"
                elseif tonumber(spellId) then
                    t.spellName = GetSpellInfo(spellId).." |cffffffff("..petName..")|r"
                else
                    t.spellName = " |cffffffff"..spellId.." ".." ("..petName..")|r"
                end
            end

            t.value = amount
            if data.total > 0 then
                t.percent = amount * 100 / data.total
            else
                t.percent = 0
            end
            chart[#chart+1] = t
        end
    end

    local chart = {}
    if not data then return chart end
    for spellId,spellData in pairs(data.spells) do
        if type(spellData) == "table" then
            for event,amount in pairs(spellData) do
                createSpellRow(chart, event, spellId, amount)
            end
        end
    end
    if data.pet then
        for spellId,spellData in pairs(data.pet.spells) do
            for petName,dataByName in pairs(spellData) do
                if type(dataByName) == "table" then
                    for event,amount in pairs(dataByName) do
                        createSpellRow(chart, event, spellId, amount, petName)
                    end
                end
            end
        end
    end

    local func = function(a, b)
        if a.value > b.value then
            return true
        elseif a.value < b.value then
            return false
        end
        return a.index > b.index
    end
    table.sort(chart, func)

    return chart
end

function WDStatsMonitor:showPopup(parent, label, data)
    local popup = self.frame:GetParent().popup
    local chart = generateSpellChart(data)
    if #chart == 0 then return end
    popup:SetPoint("TOPLEFT", parent, "TOPRIGHT", 0, 0)
    popup:SetHeight((math.min(#chart, POPUP_MAX_SPELLS) + 1) * 21 + 1)

    for _,v in pairs(popup.members) do
        v:Hide()
    end

    if label then
        popup.label:SetText(label)
    end

    local total = chart[1].percent
    for i=1,math.min(#chart, POPUP_MAX_SPELLS) do
        popup.members[i]:SetValue(chart[i].percent * 100 / total)
        local spellId = chart[i].id
        if chart[i].spellName and tonumber(spellId) then
            spellId = WdLib:makeSpellLinkWithTexture(spellId, chart[i].spellName)
        elseif chart[i].spellName then
            spellId = chart[i].spellName
        elseif tonumber(spellId) then
            spellId = WdLib:getSpellLinkByIdWithTexture(spellId)
        else
            spellId = " |cffffffff"..spellId.."|r"
        end
        popup.members[i].leftTxt:SetText(i..spellId)
        popup.members[i].rightTxt:SetText(WdLib:shortNumber(chart[i].value).." ("..WdLib:float_round_to(chart[i].percent, 1).."%)")
        popup.members[i]:Show()
    end

    popup:Show()
end

function WDStatsMonitor:hidePopup()
    self.frame:GetParent().popup:Hide()
end

function WDStatsMonitor:updateStatusBar(bar, class, vCurrent, vTotal)
    if not vCurrent or not vTotal or (vCurrent.total == 0 and vTotal.total == 0) then
        bar:SetValue(0)
        bar:SetStatusBarColor(0,0,0,0)
        return
    end
    local total = vTotal.total
    local curr = vCurrent.total
    local percent = vCurrent.total / vTotal.total
    bar:SetValue(percent * 100)
    local r,g,b = GetClassColor(class)
    if class == 0 then
        local rule = self:getCurrentFilter()
        if rule == "done" then
            r,g,b = 1-percent, percent, 0
        elseif rule == "taken" then
            r,g,b = percent, 1-percent, 0
        end
    end
    bar:SetStatusBarColor(r,g,b,.75)
end

function WDStatsMonitor:initStatusBar(parent)
    local sb = CreateFrame("StatusBar", nil, parent)
    sb:SetStatusBarTexture([[Interface\AddOns\WagonDetector\media\statusbars\otravi]])
    sb:GetStatusBarTexture():SetHorizTile(false)
    sb:GetStatusBarTexture():SetVertTile(false)
    sb:SetMinMaxValues(0, 100)
    sb:SetStatusBarColor(0,0,0,0)
    sb:SetAllPoints()
    parent.txt:SetParent(sb)
    parent.bar = sb
end

function WDStatsMonitor:findUnitByGuid(mode, guid)
    local t = self.frame.cache.units[mode]
    if not t then return nil end
    for i=1,#t do
        if t[i].guid == guid then
            return t[i]
        end
    end
    return nil
end

function WDStatsMonitor:updatePetName(pet)
    local petAsParent = self:findParentPet(pet.parentGuid, pet)
    local newName = pet.name
    if petAsParent.guid ~= pet.guid then
        if petAsParent.type == "pet" then
            local currId = WdLib:getUnitNumber(petAsParent.name)
            if currId then
                newName = newName.."-"..currId
            end
        end
    end
    local parent = self:findEntityByGUID(pet.parentGuid)
    if parent then
        local parentName = WdLib:getColoredName("("..WdLib:getShortName(parent.name, "norealm")..")", parent.class)
        newName = newName.." "..parentName
    end
    return newName
end

function WDStatsMonitor:getTablesNameByRule(mode, rule)
    if mode == "heal" then
        if rule == "done" then
            return {"healDone", "overhealDone"}
        elseif rule == "taken" then
            return {"healTaken", "overhealTaken"}
        elseif rule == "range" then
            print("Not implemented yet")
        end
    elseif mode == "dmg" then
        if rule == "done" then
            return {"dmgDone", "overdmgDone"}
        elseif rule == "taken" then
            return {"dmgTaken", "overdmgTaken"}
        elseif rule == "range" then
            print("Not implemented yet")
        end
    end
    return nil
end

function WDStatsMonitor:preparePetSpells(spellInfo, data)
    for petSpellId,petSpellData in pairs(data) do
        if type(petSpellData) == "table" then
            for petName,dataByName in pairs(petSpellData) do
                for event,eventData in pairs(dataByName) do
                    if type(eventData) == "table" then
                        if not spellInfo.pet then spellInfo.pet = {spells={},total=0} end
                        local t = spellInfo.pet.spells
                        if not t[petSpellId] then t[petSpellId] = {} end
                        if not t[petSpellId][petName] then t[petSpellId][petName] = {} end
                        if not t[petSpellId][petName][event] then t[petSpellId][petName][event] = 0 end
                        t[petSpellId][petName][event] = t[petSpellId][petName][event] + eventData.amount
                    end
                end
            end
        end
    end
end

function WDStatsMonitor:prepareDataForSpellChart(tableData)
    local spellInfo = {spells={},total=0}
    if not tableData then return spellInfo end
    for spellId,spellData in pairs(tableData) do
        if type(spellData) == "table" then
            if spellId == "pet" then
                self:preparePetSpells(spellInfo, spellData)
            else
                for event,eventData in pairs(spellData) do
                    if type(eventData) == "table" then
                        if not spellInfo.spells[spellId] then spellInfo.spells[spellId] = {} end
                        if not spellInfo.spells[spellId][event] then spellInfo.spells[spellId][event] = 0 end
                        spellInfo.spells[spellId][event] = spellInfo.spells[spellId][event] + eventData.amount
                    end
                end
            end
        end
    end
    spellInfo.total = spellInfo.total + tableData.total
    --log(spellInfo)
    return spellInfo
end

function WDStatsMonitor:prepareTotalDataForSpellChart(unit, mode)
    local rule = self:getCurrentFilter()
    local tNames = self:getTablesNameByRule(mode, rule)
    local spellInfo = {spells={},total=0}
    for _,guidData in pairs(unit.stats) do
        if type(guidData) == "table" then
            for tableName,tableData in pairs(guidData) do
                if tableName == tNames[1] then
                    for spellId,spellData in pairs(tableData) do
                        if type(spellData) == "table" then
                            if spellId == "pet" then
                                self:preparePetSpells(spellInfo, spellData)
                            else
                                for event,eventData in pairs(spellData) do
                                    if type(eventData) == "table" then
                                        if not spellInfo.spells[spellId] then spellInfo.spells[spellId] = {} end
                                        if not spellInfo.spells[spellId][event] then spellInfo.spells[spellId][event] = 0 end
                                        spellInfo.spells[spellId][event] = spellInfo.spells[spellId][event] + eventData.amount
                                    end
                                end
                            end
                        end
                    end
                    spellInfo.total = spellInfo.total + tableData.total
                end
            end
        end
    end
    --log(spellInfo)
    return spellInfo
end

function WDStatsMonitor:calculateTotalStatsByRule(unit, mode)
    local rule = self:getCurrentFilter()
    local tNames = self:getTablesNameByRule(mode, rule)
    unit.total = 0
    for k,v in pairs(unit.stats) do
        if type(v) == "table" then
            for tableName,tableData in pairs(v) do
                if tableName == tNames[1] then
                    unit.total = unit.total + tableData.total
                end
            end
        end
    end
end

function WDStatsMonitor:copyTableTo(src, dst)
    if not src or not dst then return end
    for spellId,spellData in pairs(src) do
        if type(spellData) == "table" then
            if spellId == "pet" then
                for petSpellId,petSpellData in pairs(spellData) do
                    if type(petSpellData) == "table" then
                        for petName,dataByName in pairs(petSpellData) do
                            for event,eventData in pairs(dataByName) do
                                if type(eventData) == "table" then
                                    if not dst.pet then dst.pet = {} end
                                    if not dst.pet[petSpellId] then dst.pet[petSpellId] = {} end
                                    if not dst.pet[petSpellId][petName] then dst.pet[petSpellId][petName] = {} end
                                    if not dst.pet[petSpellId][petName][event] then dst.pet[petSpellId][petName][event] = {amount=0} end
                                    dst.pet[petSpellId][petName][event].amount = dst.pet[petSpellId][petName][event].amount + eventData.amount
                                end
                            end
                        end
                    end
                end
            else
                for event,eventData in pairs(spellData) do
                    if type(eventData) == "table" then
                        if not dst[spellId] then dst[spellId] = {} end
                        if not dst[spellId][event] then dst[spellId][event] = {amount=0} end
                        dst[spellId][event].amount = dst[spellId][event].amount + eventData.amount
                    end
                end
            end
        end
    end
    dst.total = dst.total + src.total
end

function WDStatsMonitor:merge(parentTable, petTable, petName)
    if not petTable or not parentTable then return 0 end
    petName = WdLib:getShortName(petName, "norealm")
    for spellId,spellData in pairs(petTable) do
        if type(spellData) == "table" then
            if spellId == "pet" then
                for petSpellId,petSpellData in pairs(spellData) do
                    if type(petSpellData) == "table" then
                        for petName,dataByName in pairs(petSpellData) do
                            for event,eventData in pairs(dataByName) do
                                if type(eventData) == "table" then
                                    if not parentTable[petSpellId] then parentTable[petSpellId] = {} end
                                    if not parentTable[petSpellId][petName] then parentTable[petSpellId][petName] = {} end
                                    if not parentTable[petSpellId][petName][event] then parentTable[petSpellId][petName][event] = {amount=0} end
                                    parentTable[petSpellId][petName][event].amount = parentTable[petSpellId][petName][event].amount + eventData.amount
                                end
                            end
                        end
                    end
                end
            else
                for event,eventData in pairs(spellData) do
                    if type(eventData) == "table" then
                        if petName then
                            if not parentTable[spellId] then parentTable[spellId] = {} end
                            if not parentTable[spellId][petName] then parentTable[spellId][petName] = {} end
                            if not parentTable[spellId][petName][event] then parentTable[spellId][petName][event] = {amount=0} end
                            parentTable[spellId][petName][event].amount = parentTable[spellId][petName][event].amount + eventData.amount
                        else
                            if not parentTable[spellId] then parentTable[spellId] = {} end
                            if not parentTable[spellId][event] then parentTable[spellId][event] = {amount=0} end
                            parentTable[spellId][event].amount = parentTable[spellId][event].amount + eventData.amount
                        end
                    end
                end
            end
        end
    end
    parentTable.total = parentTable.total + petTable.total
end

function WDStatsMonitor:getUnitStatistics(mode)
    if not self.frame.cache.units[mode] then
        self.frame.cache.units[mode] = {}
    else
        WdLib:table_wipe(self.frame.cache.units[mode])
    end

    local ruleType = self:getSelectedRuleType()
    if not ruleType then
        return self.frame.cache.units[mode], 0
    end

    local units = self.frame.cache.units[mode]
    local total = 0

    local function loadUnit(unit, ruleId)
        unit = WdLib:table_deepcopy(unit)
        if ruleId then
            unit.stats = {}
            if unit.ruleStats and unit.ruleStats[ruleId] then
                for k,v in pairs(unit.ruleStats[ruleId].stats) do
                    unit.stats[k] = v
                end
            end
        end
        for guid in pairs(unit.stats) do
            unit.stats[guid].dmgTaken = nil
            unit.stats[guid].overdmgTaken = nil
        end
        return unit
    end

    local pull = self.frame:GetParent():GetSelectedPull()
    if ruleType == "TOTAL_DONE" or ruleType == "TOTAL_TAKEN" then
        -- load npc
        for npcId,data in pairs(pull.npc) do
            for _,npc in pairs(data) do
                if type(npc) == "table" then
                    local unit = loadUnit(npc)
                    if unit then
                        units[#units+1] = unit
                    end
                end
            end
        end
        -- load players
        for guid,pl in pairs(pull.players) do
            if type(pl) == "table" then
                local unit = loadUnit(pl)
                if unit then
                    units[#units+1] = unit
                end
            end
        end
        -- load pets
        for parentGuid,info in pairs(pull.pets) do
            for npcId,data in pairs(info) do
                for k,pet in pairs(data) do
                    local parent = self:findUnitByGuid(mode, parentGuid)
                    if parent then
                        self:mergeSpells(parent, pet)
                    else
                        local petAsParent = self:findParentPet(parentGuid, pet)
                        if petAsParent.guid ~= pet.guid then
                            if petAsParent.type == "pet" then
                                local petUnit = loadUnit(pet)
                                if petUnit then
                                    local currId = WdLib:getUnitNumber(petAsParent.name)
                                    if currId then
                                        petUnit.name = petUnit.name.."-"..currId
                                    end
                                    units[#units+1] = petUnit
                                end
                            end
                        end
                    end
                end
            end
        end
    elseif ruleType then
        local rule = self:getSelectedRule()
        local ruleId = rule.id
        -- load npc
        for npcId,data in pairs(pull.npc) do
            for _,npc in pairs(data) do
                if type(npc) == "table" then
                    local unit = loadUnit(npc, ruleId)
                    if unit then
                        units[#units+1] = unit
                    end
                end
            end
        end
        -- load players
        for guid,pl in pairs(pull.players) do
            if type(pl) == "table" then
                local unit = loadUnit(pl, ruleId)
                if unit then
                    units[#units+1] = unit
                end
            end
        end
        -- load pets
        for parentGuid,info in pairs(pull.pets) do
            for npcId,data in pairs(info) do
                for k,pet in pairs(data) do
                    local parent = self:findUnitByGuid(mode, parentGuid)
                    if parent then
                        self:mergeSpells(parent, pet, ruleId)
                    else
                        local petAsParent = self:findParentPet(parentGuid, pet)
                        if petAsParent.guid ~= pet.guid then
                            if petAsParent.type == "pet" then
                                local petUnit = loadUnit(pet, ruleId)
                                if petUnit then
                                    local currId = WdLib:getUnitNumber(petAsParent.name)
                                    if currId then
                                        petUnit.name = petUnit.name.."-"..currId
                                    end
                                    units[#units+1] = petUnit
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    for i=1,#units do
        self:updateTakenInfo(mode, units[i])
    end
    for i=1,#units do
        self:calculateTotalStatsByRule(units[i], mode)
        total = total + units[i].total
    end

    return units, total
end

function WDStatsMonitor:compareData(v, w)
    if v and w then
        if v.total == w.total then return 0 end
        if v.total > w.total then return 1 end
        if v.total < w.total then return -1 end
    elseif not v and not w then
        return 0
    elseif v then
        return 1
    end
    return -1
end

local WDMB = {}
WDMB.monitors = {}

local ruleTypes = {
    "TOTAL_DONE",
    "TOTAL_TAKEN",
}

local function refreshMonitors(needResetButton)
    for k,v in pairs(WDMB.monitors) do
        if needResetButton == true then
            v.frame.lastSelectedButton = nil
        end
        v:refreshInfo()
    end
end

local function initPullsMenu(parent)
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
            if parent.buttons["select_rule"] then
                parent.buttons["select_rule"]:Refresh()
            end
            refreshMonitors(true)
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
    parent.buttons["select_pull"] = WdLib:createDropDownMenu(parent, getPullName(), getPulls())
    parent.buttons["select_pull"]:SetSize(200, 20)
    parent.buttons["select_pull"]:SetPoint("TOPLEFT", parent, "TOPLEFT", 1, -5)
    parent.buttons["select_pull"]:SetScript("OnShow", function(self) self.txt:SetText(getPullName()) end)
    local frame = parent.buttons["select_pull"]
    function frame:Refresh()
        WdLib:updateDropDownMenu(self, getPullName(), getPulls())
    end

    -- clear current pull history button
    parent.buttons["clear_current_pull"] = WdLib:createButton(parent)
    parent.buttons["clear_current_pull"]:SetSize(90, 20)
    parent.buttons["clear_current_pull"]:SetScript("OnClick", function()
        if WD.db.profile.tracker and WD.db.profile.tracker.selected and WD.db.profile.tracker.selected > 0 then
            table.remove(WD.db.profile.tracker, WD.db.profile.tracker.selected)
            if #WD.db.profile.tracker == 0 then
                WD.db.profile.tracker.selected = 0
            elseif WD.db.profile.tracker.selected > #WD.db.profile.tracker then
                WD.db.profile.tracker.selected = #WD.db.profile.tracker
            end
        end
        WD:RefreshTrackerPulls()
        refreshMonitors(true)
    end)
    parent.buttons["clear_current_pull"].txt = WdLib:createFont(parent.buttons["clear_current_pull"], "CENTER", WD_TRACKER_BUTTON_CLEAR_SELECTED)
    parent.buttons["clear_current_pull"].txt:SetAllPoints()

    -- clear pulls history button
    parent.buttons["clear_pulls"] = WdLib:createButton(parent)
    parent.buttons["clear_pulls"]:SetSize(90, 20)
    parent.buttons["clear_pulls"]:SetScript("OnClick", function()
        WdLib:table_wipe(WD.db.profile.tracker)
        WD:RefreshTrackerPulls()
        refreshMonitors(true)
    end)
    parent.buttons["clear_pulls"].txt = WdLib:createFont(parent.buttons["clear_pulls"], "CENTER", WD_TRACKER_BUTTON_CLEAR)
    parent.buttons["clear_pulls"].txt:SetAllPoints()

    parent.buttons["clear_pulls"]:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -5, -5)
    parent.buttons["clear_current_pull"]:SetPoint("TOPRIGHT", parent.buttons["clear_pulls"], "TOPLEFT", -1, 0)
end

local function initSpellChartPopup(parent)
    local xSize = 350
    parent.popup = CreateFrame("Frame", nil, parent)
    parent.popup:SetFrameStrata("TOOLTIP")
    parent.popup:SetWidth(xSize + 2)
    parent.popup.bg = WdLib:createColorTexture(parent.popup, "BACKGROUND", 0, 0, 0, .9)
    parent.popup.bg:SetAllPoints()

    parent.popup.members = {}
    parent.popup.label = WdLib:createFontDefault(parent.popup, "LEFT", "")
    parent.popup.label:SetPoint("TOPLEFT", 5, -1)
    parent.popup.label:SetSize(xSize, 20)

    for i=1,POPUP_MAX_SPELLS do
        local r = CreateFrame("StatusBar", nil, parent.popup)
        r:SetStatusBarTexture([[Interface\AddOns\WagonDetector\media\statusbars\otravi]])
        r:GetStatusBarTexture():SetHorizTile(false)
        r:GetStatusBarTexture():SetVertTile(false)
        r:SetMinMaxValues(0, 100)
        r:SetStatusBarColor(.15,.25,.15,1)
        r:SetSize(xSize, 20)
        r.leftTxt = WdLib:createFontDefault(r, "LEFT", "")
        r.leftTxt:SetSize(xSize-50, 20)
        r.leftTxt:SetPoint("LEFT", r, "LEFT", 2, 0)
        r.rightTxt = WdLib:createFontDefault(r, "RIGHT", "")
        r.rightTxt:SetSize(100, 20)
        r.rightTxt:SetPoint("RIGHT", r, "RIGHT", -2, 0)
        if i == 1 then
            r:SetPoint("TOPLEFT", parent.popup, "TOPLEFT", 1, -22)
        else
            r:SetPoint("TOPLEFT", parent.popup.members[i-1], "BOTTOMLEFT", 0, -1)
        end
        parent.popup.members[#parent.popup.members+1] = r
    end

    parent.popup:Hide()
end

local function initRulesMenu(parent)
    local function getRuleName(selectedPull)
        if not selectedPull then
            selectedPull = parent:GetSelectedPull()
        end
        if selectedPull then
            if selectedPull.statRules and selectedPull.statRules[selectedPull.selectedRule] then
                return selectedPull.statRules[selectedPull.selectedRule].description
            elseif selectedPull.selectedRule then
                return selectedPull.selectedRule
            else
                selectedPull.selectedRule = "TOTAL_DONE"
                return selectedPull.selectedRule
            end
        end
        return "No pull selected"
    end

    local function getRules()
        local pull = parent:GetSelectedPull()
        if not pull then return {} end

        local items = {}
        local function onSelect(frame, selected)
            local pull = parent:GetSelectedPull()
            pull.selectedRule = selected.id
            parent.buttons["select_rule"]:SetText(getRuleName(pull))
            refreshMonitors(true)
        end
        for i=1,#ruleTypes do
            table.insert(items, {name = ruleTypes[i], index = i, id = ruleTypes[i], func = onSelect})
        end

        if WD.db.profile.tracker.selected and
           WD.db.profile.tracker.selected > 0 and #WD.db.profile.tracker > 0 and
           WD.db.profile.tracker.selected <= #WD.db.profile.tracker and
           WD.db.profile.tracker[WD.db.profile.tracker.selected].statRules
        then
            local t = WD.db.profile.tracker[WD.db.profile.tracker.selected].statRules
            local i = #items + 1
            for k,v in pairs(t) do
                table.insert(items, {name = "Rule ID: "..k, index = i, func = onSelect, id = k, hover = v.description})
                i = i + 1
            end
        end
        return items
    end

    -- select rule button
    parent.buttons["select_rule"] = WdLib:createDropDownMenu(parent, getRuleName(), getRules())
    parent.buttons["select_rule"]:SetSize(400, 20)
    parent.buttons["select_rule"]:SetPoint("TOPLEFT", parent, "TOPLEFT", 386, -5)
    parent.buttons["select_rule"]:SetScript("OnShow", function(self) self.txt:SetText(getRuleName()) end)
    local frame = parent.buttons["select_rule"]
    function frame:Refresh()
        WdLib:updateDropDownMenu(self, getRuleName(), getRules())
    end

    parent.buttons["select_rule"].label = WdLib:createFontDefault(parent, "RIGHT", "Applied rule:")
    parent.buttons["select_rule"].label:SetSize(150, 20)
    parent.buttons["select_rule"].label:SetPoint("RIGHT", parent.buttons["select_rule"], "LEFT", -2, 0)
end

local function createMonitor(parent, name)
    local monitor = nil
    if name == "dmg_stat" then
        monitor = WD.DmgStatsMonitor(parent, name)
    elseif name == "heal_stat" then
        monitor = WD.HealStatsMonitor(parent, name)
    end

    if monitor then
        monitor:initMainTable()
        monitor:initDataTable()
        WDMB.monitors[name] = monitor
    end
end

function WD:RefreshBasicStatsMonitors()
    refreshMonitors(true)
end

function WD:InitBasicStatsMonitorModule(parent)
    parent.buttons = {}
    function parent:GetSelectedPull()
        if WD.db.profile.tracker.selected and
           WD.db.profile.tracker.selected > 0 and #WD.db.profile.tracker > 0 and
           WD.db.profile.tracker.selected <= #WD.db.profile.tracker
        then
            return WD.db.profile.tracker[WD.db.profile.tracker.selected]
        end
        return nil
    end
    function parent:OnUpdate()
        refreshMonitors()
    end

    initPullsMenu(parent)
    initRulesMenu(parent)
    initSpellChartPopup(parent)
    createMonitor(parent, "dmg_stat")
    createMonitor(parent, "heal_stat")

    parent:SetScript("OnShow", function(self) self:OnUpdate() end)
end

WD.StatsMonitor = WDStatsMonitor
