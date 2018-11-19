
WD.options.args.configButton = {
    name = "/cd config",
    type = "execute",
    func = function() WD:OpenConfig() end,
}

chatTypes = {
    "OFFICER",
    "RAID",
    "PRINT"
}

local function updateGuildRosterFrame(self)
    if #WD.cache.rosterkeys == 0 then
        if #self.members then
            for i=1, #self.members do
                self.members[i]:Hide()
            end
        end
        return
    end

    local maxWidth = 30
    local maxHeight = 545
    for i=1,#self.headers do
        maxWidth = maxWidth + self.headers[i]:GetWidth() + 1
    end

    local scroller = self.scroller or createScroller(self, maxWidth, maxHeight, #WD.cache.rosterkeys)
    if not self.scroller then
        self.scroller = scroller
    end

    local x, y = 30, -51
    for k=1,#WD.cache.rosterkeys do
        local v = WD.cache.roster[WD.cache.rosterkeys[k]]
        if not self.members[k] then
            local member = CreateFrame("Frame", nil, self.scroller.scrollerChild)
            member.info = v
            member:SetSize(maxWidth, 20)
            member:SetPoint("TOPLEFT", self.scroller.scrollerChild, "TOPLEFT", x, y)
            member.column = {}

            local index = 1
            addNextColumn(self, member, index, "LEFT", getShortCharacterName(v.name))
            member.column[index]:SetPoint("TOPLEFT", member, "TOPLEFT", 0, -1)
            member.column[index]:EnableMouse(true)
            local r,g,b = GetClassColor(v.class)
            member.column[index].txt:SetTextColor(r, g, b, 1)
            member.column[index]:SetScript('OnEnter', function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                local tooltip = "Alts:\n"
                for i=1,#v.alts do
                    tooltip = tooltip..getShortCharacterName(v.alts[i]).."\n"
                end
                if #v.alts > 0 then
                    GameTooltip:SetText(tooltip, nil, nil, nil, nil, true)
                    GameTooltip:Show()
                end
            end)
            member.column[index]:SetScript('OnLeave', function(self) GameTooltip_Hide() end)

            index = index + 1
            addNextColumn(self, member, index, "CENTER", v.rank)
            index = index + 1
            addNextColumn(self, member, index, "CENTER", v.points)
            index = index + 1
            addNextColumn(self, member, index, "CENTER", v.pulls)
            index = index + 1
            addNextColumn(self, member, index, "CENTER", v.coef)

            table.insert(self.members, member)
        else
            local member = self.members[k]
            member.column[1].txt:SetText(getShortCharacterName(v.name))
            local r,g,b = GetClassColor(v.class)
            member.column[1].txt:SetTextColor(r, g, b, 1)
            member.column[1]:SetScript('OnEnter', function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                local tooltip = "Alts:\n"
                for i=1,#v.alts do
                    tooltip = tooltip..getShortCharacterName(v.alts[i]).."\n"
                end
                if #v.alts > 0 then
                    GameTooltip:SetText(tooltip, nil, nil, nil, nil, true)
                    GameTooltip:Show()
                end
            end)
            member.column[2].txt:SetText(v.rank)
            member.column[3].txt:SetText(v.points)
            member.column[4].txt:SetText(v.pulls)
            member.column[5].txt:SetText(v.coef)
            member:Show()
            updateScroller(self.scroller.slider, #WD.cache.rosterkeys)
        end

        y = y - 21
    end

    if #WD.cache.rosterkeys < #self.members then
        for i=#WD.cache.rosterkeys+1, #self.members do
            self.members[i]:Hide()
        end
    end
end

local function initMainModule(mainF)
    -- check lock button
    mainF.lockButton = createCheckButton(mainF)
    mainF.lockButton:SetPoint("TOPLEFT", mainF, "TOPLEFT", 5, -5)
    mainF.lockButton:SetChecked(WD.db.profile.isLocked)
    mainF.lockButton:SetScript("OnClick", function() WD:LockConfig() end)
    mainF.lockButton.txt = createFont(mainF.lockButton, "LEFT", WD_BUTTON_LOCK_GUI)
    mainF.lockButton.txt:SetSize(200, 20)
    mainF.lockButton.txt:SetPoint("LEFT", mainF.lockButton, "RIGHT", 5, 0)

    -- default chat selector
    mainF.dropFrame0 = createDropDownMenu(mainF)
    local items = {}
    for i=1,#chatTypes do
        local item = { name = chatTypes[i], func = function() WD.db.profile.chat = mainF.dropFrame0.txt:GetText() end }
        table.insert(items, item)
    end
    updateDropDownMenu(mainF.dropFrame0, WD_BUTTON_DEFAULT_CHAT, items)
    mainF.dropFrame0:SetSize(250, 20)
    mainF.dropFrame0:SetPoint("TOPLEFT", mainF.lockButton, "BOTTOMLEFT", 0, -5)
    mainF.dropFrame0:SetScript('OnShow', function() mainF.dropFrame0.txt:SetText(WD.db.profile.chat) end)

    -- check enable button
    mainF.enableButton = createCheckButton(mainF)
    mainF.enableButton:SetPoint("TOPLEFT", mainF.dropFrame0, "BOTTOMLEFT", 0, -5)
    mainF.enableButton:SetChecked(WD.db.profile.isEnabled)
    mainF.enableButton:SetScript("OnClick", function() WD:EnableConfig() end)
    mainF.enableButton.txt = createFont(mainF.enableButton, "LEFT", WD_BUTTON_ENABLE_CONFIG)
    mainF.enableButton.txt:SetSize(200, 20)
    mainF.enableButton.txt:SetPoint("LEFT", mainF.enableButton, "RIGHT", 5, 0)

    -- check immediate fail button
    mainF.immediateButton = createCheckButton(mainF)
    mainF.immediateButton:SetPoint("TOPLEFT", mainF.enableButton, "BOTTOMLEFT", 0, -5)
    mainF.immediateButton:SetChecked(WD.db.profile.sendFailImmediately)
    mainF.immediateButton:SetScript("OnClick", function() WD.db.profile.sendFailImmediately = not WD.db.profile.sendFailImmediately end)
    mainF.immediateButton.txt = createFont(mainF.immediateButton, "LEFT", WD_BUTTON_IMMEDIATE_NOTIFY)
    mainF.immediateButton.txt:SetSize(200, 20)
    mainF.immediateButton.txt:SetPoint("LEFT", mainF.immediateButton, "RIGHT", 5, 0)

    -- check penalties button
    mainF.penaltyButton = createCheckButton(mainF)
    mainF.penaltyButton:SetPoint("TOPLEFT", mainF.immediateButton, "BOTTOMLEFT", 0, -5)
    mainF.penaltyButton:SetChecked(WD.db.profile.enablePenalties)
    mainF.penaltyButton:SetScript("OnClick", function() WD.db.profile.enablePenalties = not WD.db.profile.enablePenalties end)
    mainF.penaltyButton.txt = createFont(mainF.penaltyButton, "LEFT", WD_BUTTON_ENABLE_PENALTIES)
    mainF.penaltyButton.txt:SetSize(200, 20)
    mainF.penaltyButton.txt:SetPoint("LEFT", mainF.penaltyButton, "RIGHT", 5, 0)

    -- max deaths button
    mainF.maxDeathsTxt = createFontDefault(mainF, "LEFT", WD_BUTTON_MAX_DEATHS)
    mainF.maxDeathsTxt:SetSize(200, 20)
    mainF.maxDeathsTxt:SetPoint("TOPLEFT", mainF.penaltyButton, "BOTTOMLEFT", 0, -5)
    mainF.maxDeaths = createDropDownMenu(mainF)
    local items2 = {}
    for i=1,9 do
        local item = { name = i+1, func = function() WD.db.profile.maxDeaths = tonumber(mainF.maxDeaths.txt:GetText()) end }
        table.insert(items2, item)
    end
    updateDropDownMenu(mainF.maxDeaths, WD.db.profile.maxDeaths, items2)
    mainF.maxDeaths:SetSize(50, 20)
    mainF.maxDeaths:SetPoint("TOPLEFT", mainF.penaltyButton, "BOTTOMLEFT", 200, -5)
    mainF.maxDeaths:SetScript('OnShow', function() mainF.maxDeaths.txt:SetText(WD.db.profile.maxDeaths) end)

    -- default guild rank selector
    mainF.rankSelectorTxt = createFontDefault(mainF, "LEFT", WD_BUTTON_SELECT_RANK)
    mainF.rankSelectorTxt:SetSize(100, 20)
    mainF.rankSelectorTxt:SetPoint("TOPLEFT", mainF.maxDeathsTxt, "BOTTOMLEFT", 0, -5)
    mainF.dropFrame1 = createDropDownMenu(mainF)
    local items3 = {}
    local gRanks = WD:GetGuildRanks()
    for k,v in pairs(gRanks) do
        local item = { name = v.name, func = function()
            WD.db.profile.minGuildRank = v
            mainF.dropFrame1.txt:SetText(WD.db.profile.minGuildRank.name)
            WD:OnGuildRosterUpdate()
            updateGuildRosterFrame(WD.guiFrame.module['guild_roster'])
        end }
        table.insert(items3, item)
    end
    updateDropDownMenu(mainF.dropFrame1, "GuildRanks", items3)
    mainF.dropFrame1:SetSize(150, 20)
    mainF.dropFrame1:SetPoint("TOPLEFT", mainF.maxDeathsTxt, "BOTTOMLEFT", 100, -5)
    mainF.dropFrame1:SetScript('OnShow', function() mainF.dropFrame1.txt:SetText(WD.db.profile.minGuildRank.name) end)
end

local function initGuildRosterModule(self)
    local x, y = 1, -30
    self.headers = {}
    self.members = {}

    function headerButtonFunction(param)
        if self.sorted == param then
            WD:SortGuildRoster(param, not WD.cache.rostersortinverse, function() updateGuildRosterFrame(self) end)
        else
            WD:SortGuildRoster(param, false, function() updateGuildRosterFrame(self) end) 
        end
        self.sorted = param
    end

    local h = createTableHeader(self, WD_BUTTON_NAME, x, y, 150, 20, function() headerButtonFunction("BY_NAME") end)
    h = createTableHeaderNext(self, h, WD_BUTTON_RANK, 75, 20, function() headerButtonFunction("BY_RANK") end)
    h = createTableHeaderNext(self, h, WD_BUTTON_POINTS, 75, 20, function() headerButtonFunction("BY_POINTS") end)
    h = createTableHeaderNext(self, h, WD_BUTTON_PULLS, 75, 20, function() headerButtonFunction("BY_PULLS") end)
    createTableHeaderNext(self, h, WD_BUTTON_COEF, 75, 20, function() headerButtonFunction("BY_RESULT") end)

    WD.cache.roster = {}
    WD.cache.rosterkeys = {}

    WD:OnGuildRosterUpdate()
    WD:SortGuildRoster("BY_NAME", false, function() updateGuildRosterFrame(self) end)

    self:RegisterEvent('GUILD_ROSTER_UPDATE')
    self:SetScript('OnEvent', function(self, event, ...)
        if event == 'GUILD_ROSTER_UPDATE' then
            WD:OnGuildRosterUpdate()
            updateGuildRosterFrame(self)
        end
    end)
end

local function initLastEncounterModule(self)
    local x, y = 1, -30

    self.headers = {}
    local h = createTableHeader(self, WD_BUTTON_TIME, x, y, 70, 20)
    h = createTableHeaderNext(self, h, WD_BUTTON_NAME, 100, 20)
    h = createTableHeaderNext(self, h, WD_BUTTON_ROLE, 100, 20)
    h = createTableHeaderNext(self, h, WD_BUTTON_POINTS_SHORT, 50, 20)
    createTableHeaderNext(self, h, WD_BUTTON_REASON, 300, 20)

    self:SetScript('OnShow', function(self) WD:RefreshLastEncounterFrame() end)
end

local function initHistoryModule(self)
    local x, y = 1, -30

    self.headers = {}
    local h = createTableHeader(self, WD_BUTTON_TIME, x, y, 70, 20)
    h = createTableHeaderNext(self, h, WD_BUTTON_ENCOUNTER, 150, 20)
    h = createTableHeaderNext(self, h, WD_BUTTON_NAME, 100, 20)
    h = createTableHeaderNext(self, h, WD_BUTTON_POINTS_SHORT, 50, 20)
    h = createTableHeaderNext(self, h, WD_BUTTON_REASON, 300, 20)
    h = createTableHeaderNext(self, h, '', 40, 20)
    createTableHeaderNext(self, h, '', 40, 20)

    self:SetScript('OnShow', WD.RefreshHistoryFrame)

    self.exportWindow = CreateFrame("Frame", nil, self)
    local r = self.exportWindow
    r:EnableMouse(true)
    r:SetPoint("CENTER", 0, 0)
    r:SetSize(400, 400)
    r.bg = createColorTexture(r, "TEXTURE", 0, 0, 0, 1)
    r.bg:SetAllPoints()

    createXButton(r, -1)

    r.editBox = createEditBox(r)
    r.editBox:SetSize(398, 378)
    r.editBox:SetPoint("TOPLEFT", r, "TOPLEFT", 1, -21)
    r.editBox:SetMultiLine(true)
    r.editBox:SetJustifyH("LEFT")
    r.editBox:SetMaxBytes(nil)
    r.editBox:SetMaxLetters(4096)
    r.editBox:SetHyperlinksEnabled(true)
    r.editBox:SetScript("OnEscapePressed", function() r:Hide(); end);
    r.editBox:SetScript("OnMouseUp", function() r.editBox:HighlightText(); end);
    r.editBox:Show()

    r:Hide()

    self.export = createButton(self)
    self.export:SetPoint("TOPLEFT", self, "TOPLEFT", 1, -5)
    self.export:SetSize(125, 20)
    self.export:SetScript("OnClick", function() WD:ExportHistory() end)
    self.export.txt = createFont(self.export, "CENTER", WD_BUTTON_EXPORT)
    self.export.txt:SetAllPoints()
end

local function createModuleButton(self, name, ySize, yOffset)
    local parent = self:GetParent()
    self.button = createButton(parent)
    self.button:SetPoint("TOPLEFT", parent, "TOPLEFT", 1, yOffset)
    self.button:SetSize(198, ySize)
    self.button:SetScript('OnClick', function() if not self:IsVisible() then WD:HideModules(); self:Show(); self.button.t:SetColorTexture(.2, .6, .2, 1); end end)
    self.button.txt = createFont(self.button, "LEFT", name)
    self.button.txt:SetSize(190, ySize)
    self.button.txt:SetPoint("LEFT", self.button, "LEFT", 5, 0)
    self.button.t:SetColorTexture(.2, .2, .2, 1)
end

local function createModuleFrame(self, name)
    self.module[name] = CreateFrame("Frame", nil, self)
    local m = self.module[name]
    m:SetSize(800, 600)
    m:ClearAllPoints()
    m:SetPoint("TOPLEFT", self, "TOPLEFT", 201, 0)
    m:SetFrameStrata("DIALOG")

    if name == 'main' then
        initMainModule(m)
    elseif name == 'encounters' then
        WD:InitEncountersModule(m)
    elseif name == 'guild_roster' then
        initGuildRosterModule(m)
    elseif name == 'last_encounter' then
        initLastEncounterModule(m)
    elseif name == 'history' then
        initHistoryModule(m)
    end

    return m
end

function WD:HideModules()
    if self.guiFrame == nil then return end
    for _,v in pairs(self.guiFrame.module) do
        v.button.t:SetColorTexture(.2, .2, .2, 1)
        v:Hide()
    end
end

function WD:CreateGuiFrame()
    -- gui frame
    self.guiFrame = CreateFrame("Frame", "WD.guiFrame", UIParent)
    local gui = WD.guiFrame
    gui.module = {}
    gui:SetSize(1000, 600)
    gui:SetPoint("CENTER", 0, 0)
    gui:SetFrameStrata("DIALOG")
    -- default drag mode
    gui:EnableMouse(true)
    gui:SetScript("OnDragStart", gui.StartMoving)
    gui:SetScript("OnDragStop", gui.StopMovingOrSizing)
    -- gui background
    gui.bg = createColorTexture(gui, "TEXTURE", 0, 0, 0, .99)
    gui.bg:ClearAllPoints()
    gui.bg:SetPoint("TOPLEFT", gui, "TOPLEFT", 0, 0)
    gui.bg:SetAllPoints()
    -- x button
    gui.xButton = createXButton(gui, 0)

    gui:RegisterEvent('GUILD_ROSTER_UPDATE')
    gui:SetScript('OnEvent', function(self, event)
        local gRanks = WD:GetGuildRanks()
        if #gRanks == 0 then return end

        -- modules frames
        local mainF = createModuleFrame(gui, 'main')
        createModuleButton(mainF, WD_BUTTON_MAIN_MODULE, 20, -30)
        local encF = createModuleFrame(gui, 'encounters')
        createModuleButton(encF, WD_BUTTON_ENCOUNTERS_MODULE, 20, -51)
        local pointsF = createModuleFrame(gui, 'guild_roster')
        createModuleButton(pointsF, WD_BUTTON_GUILD_ROSTER_MODULE, 20, -72)
        local lastEncF = createModuleFrame(gui, 'last_encounter')
        createModuleButton(lastEncF, WD_BUTTON_LAST_ENCOUNTER_MODULE, 20, -93)
        local historyF = createModuleFrame(gui, 'history')
        createModuleButton(historyF, WD_BUTTON_HISTORY_MODULE, 20, -114)
        WD:HideModules()

        gui:UnregisterEvent('GUILD_ROSTER_UPDATE')
    end)

    GuildRoster()
    gui:Hide()

    if WD.db.profile.isLocked == false then
        gui:RegisterForDrag("LeftButton")
        gui:SetMovable(true)
    else
        gui:RegisterForDrag()
        gui:SetMovable(false)
    end
end

function WD:LockConfig()
    local gui = self.guiFrame
    if WD.db.profile.isLocked == true then
        gui:RegisterForDrag("LeftButton")
        gui:SetMovable(true)
        WD.db.profile.isLocked = false
    else
        gui:RegisterForDrag()
        gui:SetMovable(false)
        WD.db.profile.isLocked = true
    end
end

function WD:OpenConfig()
    if self.guiFrame == nil or self.mainFrame == nil then return end
    self.guiFrame:Show()
end

function WD:OpenNewRuleMenu()
    local encF = self.guiFrame.module['encounters']
    if encF.newRule:IsVisible() then encF.newRule:Hide() else encF.newRule:Show() end
end

function WD:OpenNotifyRuleMenu()
    local encF = self.guiFrame.module['encounters']
    if encF.notifyRule:IsVisible() then encF.notifyRule:Hide() else encF.notifyRule:Show() end
end

function WD:OpenExportEncounterMenu()
    local encF = self.guiFrame.module['encounters']
    if encF.exportEncounter:IsVisible() then encF.exportEncounter:Hide() else encF.exportEncounter:Show() end
end

function WD:OpenImportEncounterMenu()
    local encF = self.guiFrame.module['encounters']
    if encF.importEncounter:IsVisible() then encF.importEncounter:Hide() else encF.importEncounter:Show() end
end

function WD:OpenShareEncounterMenu()
    local encF = self.guiFrame.module['encounters']
    if encF.shareEncounter:IsVisible() then encF.shareEncounter:Hide() else encF.shareEncounter:Show() end
end

function WD:RefreshGuildRosterFrame()
    local f = WD.guiFrame.module['guild_roster']
    if f then
        GuildRoster()
    end
end

function WD:RefreshLastEncounterFrame()
    local core = WD.mainFrame
    local self = WD.guiFrame.module['last_encounter']

    if not core.encounter.fuckers then return end
    if not self.members then self.members = {} end

    local maxWidth = 30
    local maxHeight = 545
    for i=1,#self.headers do
        maxWidth = maxWidth + self.headers[i]:GetWidth() + 1
    end

    local scroller = self.scroller or createScroller(self, maxWidth, maxHeight, #core.encounter.fuckers)
    if not self.scroller then
        self.scroller = scroller
    end

    local x, y = 30, -51
    for k=1,#core.encounter.fuckers do
        local v = core.encounter.fuckers[k]
        if not self.members[k] then
            local member = CreateFrame("Frame", nil, self.scroller.scrollerChild)
            member.info = v
            member:SetSize(maxWidth, 20)
            member:SetPoint("TOPLEFT", self.scroller.scrollerChild, "TOPLEFT", x, y)
            member.column = {}

            local index = 1
            addNextColumn(self, member, index, "LEFT", v.timestamp)
            member.column[index]:SetPoint("TOPLEFT", member, "TOPLEFT", 0, -1)

            index = index + 1
            addNextColumn(self, member, index, "LEFT", getShortCharacterName(v.name))
            index = index + 1
            addNextColumn(self, member, index, "CENTER", v.role)
            index = index + 1
            addNextColumn(self, member, index, "CENTER", v.points)
            index = index + 1
            addNextColumn(self, member, index, "LEFT", v.reason)

            table.insert(self.members, member)
        else
            local member = self.members[k]
            member.column[1].txt:SetText(v.timestamp)
            member.column[2].txt:SetText(v.name)
            member.column[3].txt:SetText(v.role)
            member.column[4].txt:SetText(v.points)
            member.column[5].txt:SetText(v.reason)
            member:Show()
            updateScroller(self.scroller.slider, #core.encounter.fuckers)
        end

        y = y - 21
    end

    if #core.encounter.fuckers < #self.members then
        for i=#core.encounter.fuckers+1, #self.members do
            self.members[i]:Hide()
        end
    end
end

function WD:RefreshHistoryFrame()
    local self = WD.guiFrame.module['history']
    if not self then return end
    if not self.members then self.members = {} end

    local maxWidth = 30
    local maxHeight = 545
    for i=1,#self.headers do
        maxWidth = maxWidth + self.headers[i]:GetWidth() + 1
    end

    local scroller = self.scroller or createScroller(self, maxWidth, maxHeight, #WD.db.profile.history)
    if not self.scroller then
        self.scroller = scroller
    end

    local x, y = 30, -51
    for k=#WD.db.profile.history,1,-1 do
        local v = WD.db.profile.history[k]
        k=#WD.db.profile.history-k+1
        if not self.members[k] then
            local member = CreateFrame("Frame", nil, self.scroller.scrollerChild)
            member.info = v
            member:SetSize(maxWidth, 20)
            member:SetPoint("TOPLEFT", self.scroller.scrollerChild, "TOPLEFT", x, y)
            member.column = {}

            local index = 1
            addNextColumn(self, member, index, "LEFT", v.timestamp)
            member.column[index]:SetPoint("TOPLEFT", member, "TOPLEFT", 0, -1)

            index = index + 1
            addNextColumn(self, member, index, "LEFT", v.encounter)

            index = index + 1
            addNextColumn(self, member, index, "LEFT", getShortCharacterName(v.name))

            index = index + 1
            addNextColumn(self, member, index, "CENTER", v.points)

            index = index + 1
            addNextColumn(self, member, index, "LEFT", v.reason)

            index = index + 1
            addNextColumn(self, member, index, "CENTER", WD_BUTTON_REVERT)
            member.column[index]:EnableMouse(true)
            member.column[index].t:SetColorTexture(.2, .6, .2, .7)
            member.column[index]:SetScript('OnClick', function() WD:RevertHistory(v) end)

            index = index + 1
            addNextColumn(self, member, index, "CENTER", WD_BUTTON_DELETE)
            member.column[index]:EnableMouse(true)
            member.column[index].t:SetColorTexture(.6, .2, .2, .7)
            member.column[index]:SetScript('OnClick', function() WD:DeleteHistory(v) end)

            table.insert(self.members, member)
        else
            local member = self.members[k]
            member.column[1].txt:SetText(v.timestamp)
            member.column[2].txt:SetText(v.encounter)
            member.column[3].txt:SetText(getShortCharacterName(v.name))
            member.column[4].txt:SetText(v.points)
            member.column[5].txt:SetText(v.reason)
            member.column[6]:SetScript('OnClick', function() WD:RevertHistory(v) end)
            member.column[7]:SetScript('OnClick', function() WD:DeleteHistory(v) end)
            member:Show()
            updateScroller(self.scroller.slider, #WD.db.profile.history)
        end

        y = y - 21
    end

    if #WD.db.profile.history < #self.members then
        for i=#WD.db.profile.history+1, #self.members do
            self.members[i]:Hide()
        end
    end
end
