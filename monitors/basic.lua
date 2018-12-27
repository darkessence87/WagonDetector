
local WDMonitor = {}
WDMonitor.__index = WDMonitor
setmetatable(WDMonitor, {
    __call = function(v, ...)
        local self = setmetatable({}, v)
        self:init(...)
        return self
    end,
})

function WDMonitor:init(parent, name)
    self.name = name
    self.frame = CreateFrame("Frame", nil, parent)
    self.frame.buttons = {}
    self.frame.data = {}
end

function WDMonitor:initButtons()
    print('WDMonitor : initButtons is not overriden')
end

function WDMonitor:initInfoTable()
    print('WDMonitor : initInfoTable is not overriden')
end

function WDMonitor:refreshInfo()
    print('WDMonitor : refreshInfo is not overriden')
end

function WDMonitor:findNpc(guid)
    if not WD.db.profile.tracker or not WD.db.profile.tracker.selected then return nil end
    local t = WD.db.profile.tracker[WD.db.profile.tracker.selected]
    if not guid then return nil end
    local npcId = WdLib:getNpcId(guid)
    local holder = t.npc[npcId]
    local index = WdLib:findEntityIndex(holder, guid)
    if index then return holder[index] end
    return nil
end

function WDMonitor:findPet(guid)
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

function WDMonitor:findPlayer(guid)
    if not WD.db.profile.tracker or not WD.db.profile.tracker.selected then return nil end
    local t = WD.db.profile.tracker[WD.db.profile.tracker.selected]
    return t.players[guid]
end

function WDMonitor:findEntityByGUID(guid)
    local result = self:findPlayer(guid)
    if result then return result end
    result = self:findPet(guid)
    if result then return result end
    result = self:findNpc(guid)
    if result then return result end
    return nil
end

local WDMB = {}
WDMB.monitors = {}

local function refreshMonitors(needResetButton)
    for k,v in pairs(WDMB.monitors) do
        if needResetButton then
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
            refreshMonitors(true)
            if parent.buttons["select_rule"] then
                parent.buttons["select_rule"]:Refresh()
            end
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

local function createMonitor(parent, name)
    local monitor = nil
    if name == "dispel" then
        monitor = WD.DispelMonitor(parent, "dispel")
    elseif name == "interrupt" then
        monitor = WD.InterruptMonitor(parent, "interrupt")
    elseif name == "buffs" then
        monitor = WD.BuffMonitor(parent, "buffs")
    elseif name == "debuffs" then
        monitor = WD.DebuffMonitor(parent, "debuffs")
    end

    if monitor then
        monitor:initButtons()
        monitor:initInfoTable()
        WDMB.monitors[name] = monitor
    end
end

function WD:RefreshTrackerPulls()
    if WD.guiFrame.module["tracker_auras"] then
        WD.guiFrame.module["tracker_auras"].buttons["select_pull"]:Refresh()
    end
    if WD.guiFrame.module["tracker_overview"] then
        WD.guiFrame.module["tracker_overview"].buttons["select_pull"]:Refresh()
    end
    if WD.guiFrame.module["tracker_statistics"] then
        WD.guiFrame.module["tracker_statistics"].buttons["select_pull"]:Refresh()
        WD.guiFrame.module["tracker_statistics"].buttons["select_rule"]:Refresh()
    end
end

function WD:RefreshBasicMonitors()
    refreshMonitors(true)
end

function WD:InitBasicMonitorModule(parent, module1, module2)
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
    createMonitor(parent, module1)
    createMonitor(parent, module2)

    parent:SetScript("OnShow", function(self) self:OnUpdate() end)
end

WD.Monitor = WDMonitor
