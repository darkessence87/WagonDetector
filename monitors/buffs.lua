
local WDBAM = nil

local DEFAULT_ZOOM_VALUE = 0
local MAX_ZOOM_VALUE = 90
local DEFAULT_DELTA_VALUE = 0
local DELTA_UPDATE_RATIO = 0.05
local DELTA_SPEED_RATIO = 0.5
local GRAPHIC_COORDS = { x0=15, y0=15, x=370, y=140 }

local WDBuffMonitor = {}
WDBuffMonitor.__index = WDBuffMonitor

setmetatable(WDBuffMonitor, {
    __index = WD.Monitor,
    __call = function (v, ...)
        local self = setmetatable({}, v)
        self:init(...)
        return self
    end,
})

local function calculateLifetime(pull, unit)
    local fromTime = unit.spawnedAt or pull.startTime or 0
    local toTime = unit.diedAt or pull.endTime or GetTime()
    return toTime - fromTime
end

local function calculateUptime(v, totalV)
    if not v or not totalV or totalV == 0 then return nil end
    return WdLib.gen:float_round_to(v * 100 / totalV, 1)
end

local function calculateAuraDuration(pull, unit, aura, index)
    if unit.diedAt or pull.endTime then
        local toTime = unit.diedAt or pull.endTime or 0
        if toTime > 0 then
            local t = (toTime - aura.applied) / 1000
            return WdLib.gen:float_round_to(t * 1000, 2)
        end
    end
    if index > 1 then
        return 0
    end
    return nil
end

local function getCasterName(v)
    local casterName = UNKNOWNOBJECT
    local caster = WDBAM.parent:findEntityByGUID(v.caster)
    if caster then
        casterName = caster.name
        if caster.type == "pet" then
            casterName = WDBAM.parent:updatePetName(caster)
        end
        casterName = WdLib.gen:getColoredName(WdLib.gen:getShortName(casterName), caster.class)
    else
        casterName = "|cffffffffEnvironment|r"
    end
    return casterName
end

local function getFilteredBuffs(unit, filter)
    local result = {}
    local pull = WDBAM:GetParent().GetSelectedPull()
    if not pull then return result end

    local maxDuration = calculateLifetime(pull, unit)

    for auraId,auraInfo in pairs(unit.auras) do
        local byCaster = {}
        for i=1,#auraInfo do
            if auraInfo[i].isBuff == true then
                local caster = auraInfo[i].caster
                if not filter or (filter and getCasterName(auraInfo[i]):match(filter)) then
                    local duration = auraInfo[i].duration
                    if not duration then
                        duration = calculateAuraDuration(pull, unit, auraInfo[i], i)
                        if not duration then
                            duration = maxDuration
                        end
                    end
                    local stacks = 0
                    if type(auraInfo[i].stacks) == "number" then
                        local n = auraInfo[i].stacks
                        auraInfo[i].stacks = {}
                        auraInfo[i].stacks[#auraInfo[i].stacks+1] = { applied = auraInfo[i].applied, stack = n }
                    end
                    if auraInfo[i].stacks then
                        for k in pairs(auraInfo[i].stacks) do
                            stacks = max(stacks, auraInfo[i].stacks[k].stack)
                        end
                    end

                    if not byCaster[caster] then byCaster[caster] = {duration=0, count=0, maxStacks=0} end
                    if duration > 0 then
                        byCaster[caster].duration = byCaster[caster].duration + duration
                        byCaster[caster].count = byCaster[caster].count + 1
                        byCaster[caster].maxStacks = max(byCaster[caster].maxStacks, stacks)
                    end
                end
            end
        end
        for casterGuid,info in pairs(byCaster) do
            if info.duration > maxDuration then
                info.duration = maxDuration
            end
            result[#result+1] = { N = info.count, M = info.maxStacks, id = auraId, data = { uptime = calculateUptime(info.duration, maxDuration) or 0, caster = casterGuid } }
        end
    end
    return result
end

local function hasBuff(unit)
    for _,auraInfo in pairs(unit.auras) do
        for i=1,#auraInfo do
            if auraInfo[i].isBuff == true then return true end
        end
    end
    return nil
end

local function calculateTimelineCoordinates(l, percentValue, isVertical)
    if not l then return nil end
    local _,_,fx,fy = l:GetStartPoint()
    if isVertical then
        local h = l:GetHeight()
        return fy + (h * percentValue / 100)
    else
        local w = l:GetWidth()
        return fx + (w * percentValue / 100)
    end
end

local function addSteps(l, steps, isVertical)
    if not steps or steps == 0 then
        return
    end

    local _,_,fx,fy = l:GetStartPoint()
    local stepLines = {}
    for i=1,steps do
        if isVertical then
            local step = l:GetHeight() / steps
            stepLines[#stepLines+1] = WD.Graphic:DrawLineXY(fx-2, fy+i*step, fx+2, fy+i*step)
        else
            local step = l:GetWidth() / steps
            stepLines[#stepLines+1] = WD.Graphic:DrawLineXY(fx+i*step, fy-2, fx+i*step, fy+2)
        end
    end
    return stepLines
end

local function drawTimeline(steps)
    local l = WD.Graphic:DrawLineXY(GRAPHIC_COORDS.x0, GRAPHIC_COORDS.y0, GRAPHIC_COORDS.x, GRAPHIC_COORDS.y0)
    l.steps = addSteps(l, steps)

    local pull = WDBAM:GetParent().GetSelectedPull()
    if pull then
        local totalTime = (pull.endTime or GetTime()) - pull.startTime
        if totalTime and steps and steps > 0 then
            local step = 100 / steps
            local zoomedStep = step * (100 - WDBAM.zoomValue) / 100
            for k,v in pairs(l.steps) do
                if not v.txt then
                    v.txt = WdLib.gui:createFontDefault(WD.Graphic, "CENTER", "0")
                end
                v.txt:SetFont([[Interface\AddOns\WagonDetector\media\fonts\Noto.ttf]], 9, "")
                v.txt:SetSize(70, 20)
                v.txt:SetPoint("CENTER", v, "CENTER", 0, -7)
                local perc = k * zoomedStep + WDBAM.deltaValue
                v.txt:SetText(WdLib.gen:getTimeString(perc * totalTime / 100))
                --v.txt:SetText(perc)
            end
        end
    end
    return l
end

local function drawNumberLine(steps)
    local l = WD.Graphic:DrawLineXY(GRAPHIC_COORDS.x0, GRAPHIC_COORDS.y0, GRAPHIC_COORDS.x0, GRAPHIC_COORDS.y)
    l.steps = addSteps(l, steps, true)

    if steps and steps > 0 then
        for k,v in pairs(l.steps) do
            if not v.txt then
                v.txt = WdLib.gui:createFontDefault(WD.Graphic, "CENTER", "0")
            end
            v.txt:SetFont([[Interface\AddOns\WagonDetector\media\fonts\Noto.ttf]], 9, "")
            v.txt:SetSize(70, 20)
            v.txt:SetPoint("CENTER", v, "CENTER", -7, 0)
            v.txt:SetText(k)
        end
    end
    return l
end

function WDBuffMonitor:init(parent, name)
    WD.Monitor.init(self, parent, name)
    WDBAM = self.frame
    WDBAM.parent = self
    WDBAM.zoomValue = DEFAULT_ZOOM_VALUE
    WDBAM.deltaValue = DEFAULT_DELTA_VALUE
    WDBAM.cached_auras = {}
end

function WDBuffMonitor:initMainTable()
    WD.Monitor.initMainTable(self, "buffs", "Gained buffs info", 1, -50, 300, 20)

    self.showGraphicCheck = WdLib.gui:createCheckButton(self.frame:GetParent())
    self.showGraphicCheck:SetPoint("TOPLEFT", self.npcFilter.txt, "TOPRIGHT", 1, 0)
    self.showGraphicCheck:SetChecked(false)
    self.showGraphicCheck:SetScript("OnClick", function(s)
        local isChecked = self.showGraphicCheck:GetChecked()
        if isChecked and WDBAM:GetParent().GetSelectedPull() then
            self.graphicFrame:Show()
        else
            self.graphicFrame:Hide()
        end
    end)
    self.showGraphicCheck.txt = WdLib.gui:createFont(self.showGraphicCheck, "LEFT", "show graphic")
    self.showGraphicCheck.txt:SetSize(70, 20)
    self.showGraphicCheck.txt:SetPoint("LEFT", self.showGraphicCheck, "RIGHT", 5, 0)

    self.graphicFrame = CreateFrame("Frame", nil, self.frame)
    self.graphicFrame:EnableMouse(true)
    self.graphicFrame:RegisterForDrag("LeftButton")
    local buffSelf = self
    local function updateDelta(delta, dontNotify)
        local valueCap = WDBAM.zoomValue
        local value = WDBAM.deltaValue + delta * (DELTA_SPEED_RATIO * (100 - WDBAM.zoomValue) / 100)
        if value > valueCap then
            value = valueCap
        elseif value < 0 then
            value = 0
        end
        if value ~= WDBAM.deltaValue then
            WDBAM.deltaValue = WdLib.gen:float_round_to(value, 2)
            --print(WDBAM.deltaValue)
            if not dontNotify then
                buffSelf:showGraphic()
            end
        end
    end
    local function onDragStart(self)
        local x = GetCursorPosition()
        self.xPos = x
        self.isDragging = true
        local timeElapsed = 0
        self:HookScript("OnUpdate", function(self, elapsed)
            if not self.isDragging then
                return
            end

            timeElapsed = timeElapsed + elapsed
            if timeElapsed > DELTA_UPDATE_RATIO then
                timeElapsed = 0

                local x = GetCursorPosition()
                local delta = self.xPos - x
                updateDelta(delta)
                self.xPos = x
            end
        end)
    end
    local function onDragStop(self)
        local x = GetCursorPosition()
        local delta = self.xPos - x
        updateDelta(delta)
        self.xPos = x
        self.isDragging = false
    end
    local function zoomFn(self, delta)
        local speed = 10 * delta
        if IsControlKeyDown() then
            speed = 5 * delta
        end
        if IsShiftKeyDown() then
            speed = 20 * delta
        end
        local value = WDBAM.zoomValue + speed
        if value < 0 then
            value = 0
        elseif value > MAX_ZOOM_VALUE then
            value = MAX_ZOOM_VALUE
        end
        if value ~= WDBAM.zoomValue then
            WDBAM.zoomValue = value
            updateDelta(0, false)
            buffSelf:showGraphic()
        end
    end
    self.graphicFrame:SetScript("OnMouseWheel", zoomFn)
    self.graphicFrame:SetScript("OnDragStart", onDragStart)
    self.graphicFrame:SetScript("OnDragStop", onDragStop)
    self.graphicFrame:SetPoint("BOTTOMLEFT", WD.Graphic, "BOTTOMLEFT", GRAPHIC_COORDS.x0, GRAPHIC_COORDS.y0)
    self.graphicFrame:SetPoint("TOPRIGHT", WD.Graphic, "BOTTOMLEFT", GRAPHIC_COORDS.x, GRAPHIC_COORDS.y)
    --self.graphicFrame:SetFrameStrata("WORLD")
    self.graphicFrame.bg = WdLib.gui:createColorTexture(self.graphicFrame, "BACKGROUND", .3, .3, .3, .8)
    self.graphicFrame.bg:SetAllPoints()
    self.graphicFrame:Hide()

    self.graphicFrame:HookScript("OnShow", function()
        WD.Graphic:SetParent(self.graphicFrame)
        self:showGraphic()
    end)
    self.graphicFrame:HookScript("OnHide", function()
        WD.Graphic:SetParent(UIParent)
        self:hideGraphic()
    end)
end

function WDBuffMonitor:initDataTable()
    local columns = {
        [1] = {"Buff",      300},
        [2] = {"Uptime",    60},
        [3] = {"Count",     40},
        [4] = {"Max Stacks",40},
        [5] = {"Casted by", 270},
    }
    WD.Monitor.initDataTable(self, "buffs", columns)

    self.nameFilter = WdLib.gui:createEditBox(self.frame:GetParent())
    self.nameFilter:SetSize(self.frame.dataTable.headers[#columns]:GetSize())
    self.nameFilter:SetPoint("BOTTOMLEFT", self.frame.dataTable.headers[#columns], "TOPLEFT", 0, 1)
    self.nameFilter:SetMaxLetters(15)
    self.nameFilter:SetScript("OnChar", function(f) self:updateDataTable() end)
    self.nameFilter:SetScript("OnEnterPressed", function(f) f:ClearFocus() self:updateDataTable() end)
    self.nameFilter:SetScript("OnEscapePressed", function(f) f:ClearFocus() end)
end

function WDBuffMonitor:getMainTableData()
    local units = {}
    if not WD.db.profile.tracker or not WD.db.profile.tracker.selected or WD.db.profile.tracker.selected > #WD.db.profile.tracker or #WD.db.profile.tracker == 0 then
        return units
    end
    for k,v in pairs(WD.db.profile.tracker[WD.db.profile.tracker.selected]) do
        if k == "npc" and self.npcFilter:GetChecked() then
            for npcId,data in pairs(v) do
                for guid,npc in pairs(data) do
                    if type(npc) == "table" then
                        if hasBuff(npc) then
                            npc.npc_id = npcId
                            units[#units+1] = npc
                        end
                    end
                end
            end
        elseif k == "players" and self.playersFilter:GetChecked() then
            for guid,raider in pairs(v) do
                if hasBuff(raider) then
                    units[#units+1] = raider
                end
            end
        end
    end
    return units
end

function WDBuffMonitor:getMainTableSortFunction()
    return function(a, b)
        return a.name < b.name
    end
end

function WDBuffMonitor:getMainTableRowText(v)
    local unitName = WdLib.gen:getColoredName(v.name, v.class)
    if v.rt and v.rt > 0 then unitName = WdLib.gui:getRaidTargetTextureLink(v.rt).." "..unitName end
    return unitName
end

function WDBuffMonitor:getMainTableRowHover(v)
    if v.type == "creature" then
        return "id: "..v.npc_id
    end
    return nil
end

function WDBuffMonitor:updateDataTable(filter)
    for _,v in pairs(WDBAM.dataTable.members) do
        v:Hide()
    end

    WdLib.table:wipe(WDBAM.cached_auras)
    if WDBAM.lastSelectedButton then
        local unit = WDBAM.lastSelectedButton:GetParent().info
        WDBAM.cached_auras = getFilteredBuffs(unit, self.nameFilter:GetText())
    end

    local func = function(a, b)
        if a.data.uptime > b.data.uptime then return true
        elseif a.data.uptime < b.data.uptime then return false
        end
        if a.data.caster > b.data.caster then return true
        elseif a.data.caster < b.data.caster then return false
        end
        return a.id < b.id
    end
    table.sort(WDBAM.cached_auras, func)


    local maxHeight = 210
    local topLeftPosition = { x = 30, y = -51 }
    local rowsN = #WDBAM.cached_auras
    local columnsN = 5

    local function createFn(parent, row, index)
        local auraId = WDBAM.cached_auras[row].id
        local N = WDBAM.cached_auras[row].N
        local M = WDBAM.cached_auras[row].M
        local v = WDBAM.cached_auras[row].data
        parent.info = auraId
        if index == 1 then
            local f = WdLib.gui:addNextColumn(WDBAM.dataTable, parent, index, "LEFT", WdLib.gui:getSpellLinkByIdWithTexture(auraId))
            f:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
            f:SetScript("OnClick", function(rowFrame) WDBAM.lastSelectedAura = rowFrame; self:showGraphic() end)
            WdLib.gui:generateSpellHover(f, WdLib.gui:getSpellLinkByIdWithTexture(auraId))
            return f
        elseif index == 2 then
            return WdLib.gui:addNextColumn(WDBAM.dataTable, parent, index, "RIGHT", v.uptime.." %")
        elseif index == 3 then
            return WdLib.gui:addNextColumn(WDBAM.dataTable, parent, index, "CENTER", N)
        elseif index == 4 then
            return WdLib.gui:addNextColumn(WDBAM.dataTable, parent, index, "CENTER", M)
        elseif index == 5 then
            local f = WdLib.gui:addNextColumn(WDBAM.dataTable, parent, index, "LEFT", getCasterName(v))
            WdLib.gui:generateSpellHover(f, getCasterName(v))
            return f
        end
    end

    local function updateFn(f, row, index)
        local auraId = WDBAM.cached_auras[row].id
        local N = WDBAM.cached_auras[row].N
        local M = WDBAM.cached_auras[row].M
        local v = WDBAM.cached_auras[row].data
        f:GetParent().info = auraId
        if index == 1 then
            f.txt:SetText(WdLib.gui:getSpellLinkByIdWithTexture(auraId))
            f:SetScript("OnClick", function(rowFrame) WDBAM.lastSelectedAura = rowFrame; self:showGraphic() end)
            WdLib.gui:generateSpellHover(f, WdLib.gui:getSpellLinkByIdWithTexture(auraId))
        elseif index == 2 then
            f.txt:SetText(v.uptime.." %")
        elseif index == 3 then
            f.txt:SetText(N)
        elseif index == 4 then
            f.txt:SetText(M)
        elseif index == 5 then
            f.txt:SetText(getCasterName(v))
            WdLib.gui:generateSpellHover(f, getCasterName(v))
        end
    end

    WdLib.gui:updateScrollableTable(WDBAM.dataTable, maxHeight, topLeftPosition, rowsN, columnsN, createFn, updateFn)

    WDBAM.dataTable:Show()

    if not WDBAM:GetParent().GetSelectedPull() then
        self.graphicFrame:Hide()
    elseif self.showGraphicCheck:GetChecked() and not self.graphicFrame:IsVisible() then
        self.graphicFrame:Show()
    else
        self:showGraphic()
    end
end

function WDBuffMonitor:showGraphic()
    if not self.showGraphicCheck:GetChecked() or not self.graphicFrame:IsVisible() then
        return
    end

    local pull = WDBAM:GetParent().GetSelectedPull()
    if not pull then
        return
    end

    WD.Graphic:SetSize(400, 180)
    WD.Graphic:SetPoint("TOPLEFT", self.nameFilter, "TOPRIGHT", 28, -41)

    WD.Graphic:Reset()
    WD.Graphic:ReserveLines(1000)

    -- timeline + zoom processing
    local timeL = drawTimeline(4)

    -- auras processing
    local function applyZoom(perc)
        return (perc - WDBAM.deltaValue) * 100 / (100 - WDBAM.zoomValue)
    end

    local maxStacks = 1
    local data = {}
    if WDBAM.lastSelectedButton and WDBAM.lastSelectedAura then
        local unit = WDBAM.lastSelectedButton:GetParent().info
        local auraId = WDBAM.lastSelectedAura:GetParent().info
        local auraInfo = unit.auras[auraId]
        if auraInfo then
            local maxDuration = calculateLifetime(pull, unit)
            local totalTime = (pull.endTime or GetTime()) - pull.startTime

            for i=1,#auraInfo do
--if i == 1 then
                if auraInfo[i].isBuff == true then
                    WD.Graphic.txt:SetText(self:getMainTableRowText(unit)..'\n'..getCasterName(auraInfo[i])..'\'s '..WdLib.gui:getSpellLinkByIdWithTexture(auraId))

                    local duration = auraInfo[i].duration
                    if not duration then
                        duration = calculateAuraDuration(pull, unit, auraInfo[i], i)
                        if not duration then
                            duration = maxDuration
                        end
                    end
                    if duration > maxDuration then
                        duration = maxDuration
                    end

                    data[i] = {}
                    data[i].applied = auraInfo[i].applied - pull.startTime
                    data[i].removed = data[i].applied + duration
                    data[i].appliedPerc = applyZoom(WdLib.gen:float_round_to(data[i].applied * 100 / totalTime, 1))
                    data[i].removedPerc = applyZoom(WdLib.gen:float_round_to(data[i].removed * 100 / totalTime, 1))

                    local auraStacks = {}
                    local stacks = 1
                    if auraInfo[i].stacks then
                        for k in pairs(auraInfo[i].stacks) do
                            stacks = max(stacks, auraInfo[i].stacks[k].stack)

                            local st = {}
                            st.applied = auraInfo[i].stacks[k].applied - pull.startTime
                            st.appliedPerc = applyZoom(WdLib.gen:float_round_to(st.applied * 100 / totalTime, 1))
                            st.stack = auraInfo[i].stacks[k].stack
                            auraStacks[#auraStacks+1] = st
                        end
                    end
                    maxStacks = max(maxStacks, stacks)
                    data[i].stacks = auraStacks
                    --print('applied', data[i].applied)
                    --print('appliedPerc', WdLib.gen:float_round_to(data[i].applied * 100 / totalTime, 1))
                    --print('appliedPercZoommed', data[i].appliedPerc)
                    --print('removed', data[i].removed)
                    --print('removedPerc', WdLib.gen:float_round_to(data[i].removed * 100 / totalTime, 1))
                    --print('removedPercZoommed', data[i].removedPerc)
                end
--end
            end
        end
    end
    -- draw auras
    local stacksL = drawNumberLine(maxStacks)
    for i=1,#data do
        local function calcStackPerc(stack)
            return WdLib.gen:float_round_to(stack * 100 / maxStacks, 1)
        end

        local function findClosestStacksToZoom(aura)
            local lStack = nil
            local rStack = nil
            for k,v in pairs(aura.stacks) do
                if v.appliedPerc < 0 then
                    lStack = v
                elseif v.appliedPerc > 100 then
                    rStack = v
                    break
                end
            end
            return lStack, rStack
        end

        local function generatePolyline(aura)
            local X0 = calculateTimelineCoordinates(timeL, 0)
            local X100 = calculateTimelineCoordinates(timeL, 100)
            local Y0 = calculateTimelineCoordinates(stacksL, 0, true)

            --print('-aura-')

            local startP = nil
            local midPoints = {}
            local endP = nil
            for k,v in pairs(aura.stacks) do
                if not startP then
                    if v.appliedPerc >= 0 and v.appliedPerc <= 100 then
                        if k > 1 then
                            local prevStack = aura.stacks[k-1]
                            --print('k > 1', 'prevStack', prevStack.appliedPerc, 'v', v.appliedPerc)
                            --print('k > 1', 'prevStack', prevStack.stack, 'v', v.stack)

                            startP = {}
                            startP.x = X0
                            startP.y = calculateTimelineCoordinates(stacksL, calcStackPerc(prevStack.stack), true)
                            --startP.id = 's prev'

                            local midP1 = {}
                            midP1.x = calculateTimelineCoordinates(timeL, v.appliedPerc)
                            midP1.y = calculateTimelineCoordinates(stacksL, calcStackPerc(prevStack.stack), true)
                            --midP1.id = 'midP1 v'..k
                            midPoints[#midPoints+1] = midP1

                            if prevStack.stack ~= v.stack then
                                local midP2 = {}
                                midP2.x = calculateTimelineCoordinates(timeL, v.appliedPerc)
                                midP2.y = calculateTimelineCoordinates(stacksL, calcStackPerc(v.stack), true)
                                --midP2.id = 'midP2 v'..k
                                midPoints[#midPoints+1] = midP2
                            end
                        else
                            --print('k = 1', 'v', v.appliedPerc)
                            --print('k = 1', 'v', v.stack)

                            startP = {}
                            startP.x = calculateTimelineCoordinates(timeL, v.appliedPerc)
                            startP.y = Y0
                            --startP.id = 's v'..k

                            local midP1 = {}
                            midP1.x = calculateTimelineCoordinates(timeL, v.appliedPerc)
                            midP1.y = calculateTimelineCoordinates(stacksL, calcStackPerc(v.stack), true)
                            --midP1.id = 'midP1 v'..k
                            midPoints[#midPoints+1] = midP1
                        end
                    end
                elseif not endP then
                    local prevStack = aura.stacks[k-1]
                    if v.appliedPerc <= 100 then
                        local midP1 = {}
                        midP1.x = calculateTimelineCoordinates(timeL, v.appliedPerc)
                        midP1.y = calculateTimelineCoordinates(stacksL, calcStackPerc(prevStack.stack), true)
                        --midP1.id = 'midP11 v'..k
                        midPoints[#midPoints+1] = midP1

                        if prevStack.stack ~= v.stack then
                            local midP2 = {}
                            midP2.x = calculateTimelineCoordinates(timeL, v.appliedPerc)
                            midP2.y = calculateTimelineCoordinates(stacksL, calcStackPerc(v.stack), true)
                            --midP2.id = 'midP22 v'..k
                            midPoints[#midPoints+1] = midP2
                        end
                    else
                        endP = {}
                        endP.x = X100
                        endP.y = calculateTimelineCoordinates(stacksL, calcStackPerc(prevStack.stack), true)
                        --endP.id = 'e v'..k
                        break
                    end
                end
            end

            if not startP then
                local l,r = findClosestStacksToZoom(aura)
                if l then
                    startP = {}
                    startP.x = X0
                    startP.y = calculateTimelineCoordinates(stacksL, calcStackPerc(l.stack), true)
                    --startP.id = 's closest'
                else
                    --print('startP', 'nil')
                end
            end

            if not endP then
                local _,r = findClosestStacksToZoom(aura)
                local l = midPoints[#midPoints] or startP
                if r and l then
                    endP = {}
                    endP.x = X100
                    endP.y = l.y
                    --endP.id = 'e closest'
                elseif l then
                    if aura.removedPerc >= 0 and aura.removedPerc <= 100 then
                        local midP1 = {}
                        midP1.x = calculateTimelineCoordinates(timeL, aura.removedPerc)
                        midP1.y = l.y
                        --midP1.id = 'midP1 L'
                        midPoints[#midPoints+1] = midP1

                        endP = {}
                        endP.x = calculateTimelineCoordinates(timeL, aura.removedPerc)
                        endP.y = Y0
                        --endP.id = 'e L'
                    elseif aura.removedPerc > 100 then
                        endP = {}
                        endP.x = X100
                        endP.y = l.y
                        --endP.id = 'e L._'
                    end
                else
                    --print('endP', 'nil')
                end
            end

            local points = {}

            if startP then
                --print('startP', startP.id)
                points[#points+1] = startP
                for k,v in pairs(midPoints) do
                    --print(v.id)
                    points[#points+1] = v
                end
                --print('endP', endP and endP.id or 'failed')
                points[#points+1] = endP
            end

            return points
        end

        local resultLines = WD.Graphic:DrawPolyline(generatePolyline(data[i]))
        if resultLines then
            for k,v in pairs(resultLines) do
                v:SetColorTexture(0,1,0,1)
            end
        end
    end
    --print('zoom', WDBAM.zoomValue)

    WD.Graphic:OnUpdate()
    WD.Graphic:Show()
end

function WDBuffMonitor:hideGraphic()
    WD.Graphic:Hide()
end

WD.BuffMonitor = WDBuffMonitor