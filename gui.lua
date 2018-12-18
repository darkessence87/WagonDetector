
local WDGF = nil

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

local function lockConfig()
    if WD.db.profile.isLocked == true then
        WDGF:RegisterForDrag("LeftButton")
        WDGF:SetMovable(true)
        WD.db.profile.isLocked = false
    else
        WDGF:RegisterForDrag()
        WDGF:SetMovable(false)
        WD.db.profile.isLocked = true
    end
end

local function hideModules()
    for _,v in pairs(WDGF.module) do
        v.button.t:SetColorTexture(.2, .2, .2, 1)
        v:Hide()
    end
end

local function reloadGuildRanksMenu(parent)
    local items3 = {}
    local gRanks = WD:GetGuildRanks()
    for k,v in pairs(gRanks) do
        local item = { name = v.name, func = function()
            WD.db.profile.minGuildRank = v
            parent.txt:SetText(WD.db.profile.minGuildRank.name)
            WD:OnGuildRosterUpdate()
        end }
        table.insert(items3, item)
    end
    WdLib:updateDropDownMenu(parent, "GuildRanks", items3)
end

local function initMainModule(mainF)
    -- check lock button
    mainF.lockButton = WdLib:createCheckButton(mainF)
    mainF.lockButton:SetPoint("TOPLEFT", mainF, "TOPLEFT", 5, -5)
    mainF.lockButton:SetChecked(WD.db.profile.isLocked)
    mainF.lockButton:SetScript("OnClick", function() lockConfig() end)
    mainF.lockButton.txt = WdLib:createFont(mainF.lockButton, "LEFT", WD_BUTTON_LOCK_GUI)
    mainF.lockButton.txt:SetSize(300, 20)
    mainF.lockButton.txt:SetPoint("LEFT", mainF.lockButton, "RIGHT", 5, 0)

    -- default chat selector
    mainF.dropFrame0 = WdLib:createDropDownMenu(mainF)
    WdLib:updateDropDownMenu(mainF.dropFrame0, WD_BUTTON_DEFAULT_CHAT, WdLib:convertTypesToItems(chatTypes, function() WD.db.profile.chat = mainF.dropFrame0.txt:GetText() end))
    mainF.dropFrame0:SetSize(350, 20)
    mainF.dropFrame0:SetPoint("TOPLEFT", mainF.lockButton, "BOTTOMLEFT", 0, -5)
    mainF.dropFrame0:SetScript("OnShow", function() mainF.dropFrame0.txt:SetText(WD.db.profile.chat) end)

    -- check enable button
    mainF.enableButton = WdLib:createCheckButton(mainF)
    mainF.enableButton:SetPoint("TOPLEFT", mainF.dropFrame0, "BOTTOMLEFT", 0, -5)
    mainF.enableButton:SetChecked(WD.db.profile.isEnabled)
    mainF.enableButton:SetScript("OnClick", function() WD:EnableConfig() end)
    mainF.enableButton.txt = WdLib:createFont(mainF.enableButton, "LEFT", WD_BUTTON_ENABLE_CONFIG)
    mainF.enableButton.txt:SetSize(300, 20)
    mainF.enableButton.txt:SetPoint("LEFT", mainF.enableButton, "RIGHT", 5, 0)

    -- check start tracking only by macro
    mainF.autotrackButton = WdLib:createCheckButton(mainF)
    mainF.autotrackButton:SetPoint("TOPLEFT", mainF.enableButton, "BOTTOMLEFT", 0, -5)
    mainF.autotrackButton:SetChecked(WD.db.profile.autoTrack)
    mainF.autotrackButton:SetScript("OnClick", function() WD.db.profile.autoTrack = not WD.db.profile.autoTrack; if WD.db.profile.autoTrack then WD.mainFrame:StartPull() else WD.mainFrame:StopPull() end end)
    mainF.autotrackButton.txt = WdLib:createFont(mainF.autotrackButton, "LEFT", WD_BUTTON_AUTOTRACK)
    mainF.autotrackButton.txt:SetSize(300, 20)
    mainF.autotrackButton.txt:SetPoint("LEFT", mainF.autotrackButton, "RIGHT", 5, 0)

    -- check immediate fail button
    mainF.immediateButton = WdLib:createCheckButton(mainF)
    mainF.immediateButton:SetPoint("TOPLEFT", mainF.autotrackButton, "BOTTOMLEFT", 0, -5)
    mainF.immediateButton:SetChecked(WD.db.profile.sendFailImmediately)
    mainF.immediateButton:SetScript("OnClick", function() WD.db.profile.sendFailImmediately = not WD.db.profile.sendFailImmediately end)
    mainF.immediateButton.txt = WdLib:createFont(mainF.immediateButton, "LEFT", WD_BUTTON_IMMEDIATE_NOTIFY)
    mainF.immediateButton.txt:SetSize(300, 20)
    mainF.immediateButton.txt:SetPoint("LEFT", mainF.immediateButton, "RIGHT", 5, 0)

    -- check penalties button
    mainF.penaltyButton = WdLib:createCheckButton(mainF)
    mainF.penaltyButton:SetPoint("TOPLEFT", mainF.immediateButton, "BOTTOMLEFT", 0, -5)
    mainF.penaltyButton:SetChecked(WD.db.profile.enablePenalties)
    mainF.penaltyButton:SetScript("OnClick", function() WD.db.profile.enablePenalties = not WD.db.profile.enablePenalties end)
    mainF.penaltyButton.txt = WdLib:createFont(mainF.penaltyButton, "LEFT", WD_BUTTON_ENABLE_PENALTIES)
    mainF.penaltyButton.txt:SetSize(300, 20)
    mainF.penaltyButton.txt:SetPoint("LEFT", mainF.penaltyButton, "RIGHT", 5, 0)

    -- max deaths button
    mainF.maxDeathsTxt = WdLib:createFontDefault(mainF, "LEFT", WD_BUTTON_MAX_DEATHS)
    mainF.maxDeathsTxt:SetSize(300, 20)
    mainF.maxDeathsTxt:SetPoint("TOPLEFT", mainF.penaltyButton, "BOTTOMLEFT", 0, -5)
    mainF.maxDeaths = WdLib:createDropDownMenu(mainF)
    local items2 = {}
    for i=1,9 do
        local item = { name = i+1, func = function() WD.db.profile.maxDeaths = tonumber(mainF.maxDeaths.txt:GetText()) end }
        table.insert(items2, item)
    end
    WdLib:updateDropDownMenu(mainF.maxDeaths, WD.db.profile.maxDeaths, items2)
    mainF.maxDeaths:SetSize(150, 20)
    mainF.maxDeaths:SetPoint("TOPLEFT", mainF.penaltyButton, "BOTTOMLEFT", 200, -5)
    mainF.maxDeaths:SetScript("OnShow", function() mainF.maxDeaths.txt:SetText(WD.db.profile.maxDeaths) end)

    -- default guild rank selector
    mainF.rankSelectorTxt = WdLib:createFontDefault(mainF, "LEFT", WD_BUTTON_SELECT_RANK)
    mainF.rankSelectorTxt:SetSize(200, 20)
    mainF.rankSelectorTxt:SetPoint("TOPLEFT", mainF.maxDeathsTxt, "BOTTOMLEFT", 0, -5)
    mainF.dropFrame1 = WdLib:createDropDownMenu(mainF)
    reloadGuildRanksMenu(mainF.dropFrame1)
    mainF.dropFrame1:SetSize(250, 20)
    mainF.dropFrame1:SetPoint("TOPLEFT", mainF.maxDeathsTxt, "BOTTOMLEFT", 100, -5)
    mainF.dropFrame1:SetScript("OnShow", function()
        if WD.db.profile.minGuildRank then
            mainF.dropFrame1.txt:SetText(WD.db.profile.minGuildRank.name)
        else
            mainF.dropFrame1.txt:SetText("GuildRanks")
        end
    end)

    function mainF:OnUpdate()
        WD:OnGuildRosterUpdate()
        mainF.autotrackButton:SetChecked(WD.db.profile.autoTrack)
        mainF.enableButton:SetChecked(WD.db.profile.isEnabled)
        mainF.dropFrame0.txt:SetText(WD.db.profile.chat)
        reloadGuildRanksMenu(mainF.dropFrame1)
        mainF.immediateButton:SetChecked(WD.db.profile.sendFailImmediately)
        mainF.lockButton:SetChecked(WD.db.profile.isLocked)
        mainF.maxDeaths.txt:SetText(WD.db.profile.maxDeaths)
        mainF.penaltyButton:SetChecked(WD.db.profile.enablePenalties)
    end
end

local function createModuleButton(module, name, ySize, yOffset)
    local parent = module:GetParent()
    module.button = WdLib:createButton(parent)
    module.button:SetPoint("TOPLEFT", parent, "TOPLEFT", 1, yOffset)
    module.button:SetSize(158, ySize)
    module.button:SetScript("OnClick", function() if not module:IsVisible() then hideModules(); module:Show(); module.button.t:SetColorTexture(.2, .6, .2, 1); end end)
    module.button.txt = WdLib:createFont(module.button, "LEFT", name)
    module.button.txt:SetSize(150, ySize)
    module.button.txt:SetPoint("LEFT", module.button, "LEFT", 5, 0)
    module.button.t:SetColorTexture(.2, .2, .2, 1)
end

local function createModuleFrame(name)
    WDGF.module[name] = CreateFrame("Frame", nil, WDGF)
    local m = WDGF.module[name]
    m:SetSize(800, 600)
    m:ClearAllPoints()
    m:SetPoint("TOPLEFT", WDGF, "TOPLEFT", 161, 0)
    m:SetFrameStrata("HIGH")

    if name == "main" then
        initMainModule(m)
    elseif name == "encounters" then
        WD:InitEncountersModule(m)
    elseif name == "encounters_statistics" then
        WD:InitRulesStatisticsModule(m)
    elseif name == "guild_roster" then
        WD:InitGuildRosterModule(m)
    elseif name == "last_encounter" then
        WD:InitLastEncounterModule(m)
    elseif name == "history" then
        WD:InitHistoryModule(m)
    elseif name == "raid_overview" then
        WD:InitRaidOverviewModule(m)
    elseif name == "tracker_overview" then
        WD:InitTrackerOverviewModule(m)
    elseif name == "tracker_statistics" then
        WD:InitTrackerStatisticsModule(m)
    elseif name == "help" then
        WD:InitHelpModule(m)
    end

    return m
end

function WD:CreateGuiFrame()
    -- gui frame
    self.guiFrame = CreateFrame("Frame", "WD.guiFrame", UIParent)
    WDGF = self.guiFrame
    WDGF.module = {}
    WDGF:SetSize(1200, 600)
    WDGF:SetPoint("CENTER", 0, 0)
    WDGF:SetFrameStrata("HIGH")
    -- default drag mode
    WDGF:EnableMouse(true)
    WDGF:SetScript("OnDragStart", WDGF.StartMoving)
    WDGF:SetScript("OnDragStop", WDGF.StopMovingOrSizing)
    -- WDGF background
    WDGF.bg = WdLib:createColorTexture(WDGF, "TEXTURE", .1, .1, .1, .99)
    WDGF.bg:ClearAllPoints()
    WDGF.bg:SetPoint("TOPLEFT", WDGF, "TOPLEFT", 0, 0)
    WDGF.bg:SetAllPoints()
    -- x button
    WDGF.xButton = WdLib:createXButton(WDGF, 0)

    WDGF:RegisterEvent("PLAYER_ENTERING_WORLD")
    WDGF:RegisterEvent("GUILD_ROSTER_UPDATE")
    WDGF:SetScript("OnEvent", function(self, event)
        if event == "PLAYER_ENTERING_WORLD" then
            WD:OnUpdate()

            -- modules frames
            local x, y = 20, -30
            local dy = -21

            local mainF = createModuleFrame("main")
            local i = 0
            createModuleButton(mainF, WD_BUTTON_MAIN_MODULE, x, y + i * dy)

            local pointsF = createModuleFrame("guild_roster")
            i = i + 1
            createModuleButton(pointsF, WD_BUTTON_GUILD_ROSTER_MODULE, x, y + i * dy)

            local raidF = createModuleFrame("raid_overview")
            i = i + 1
            createModuleButton(raidF, WD_BUTTON_RAID_OVERVIEW_MODULE, x, y + i * dy)

            local encF = createModuleFrame("encounters")
            i = i + 1
            createModuleButton(encF, WD_BUTTON_ENCOUNTERS_MODULE, x, y + i * dy)

            local statRulesF = createModuleFrame("encounters_statistics")
            i = i + 1
            createModuleButton(statRulesF, WD_BUTTON_TRACKING_RULES_MODULE, x, y + i * dy)

            local trackerF = createModuleFrame("tracker_overview")
            i = i + 1
            createModuleButton(trackerF, WD_BUTTON_TRACKING_OVERVIEW_MODULE, x, y + i * dy)

            local statsF = createModuleFrame("tracker_statistics")
            i = i + 1
            createModuleButton(statsF, WD_BUTTON_TRACKING_STATS_MODULE, x, y + i * dy)

            local lastEncF = createModuleFrame("last_encounter")
            i = i + 1
            createModuleButton(lastEncF, WD_BUTTON_LAST_ENCOUNTER_MODULE, x, y + i * dy)

            local historyF = createModuleFrame("history")
            i = i + 1
            createModuleButton(historyF, WD_BUTTON_HISTORY_MODULE, x, y + i * dy)

            local helpF = createModuleFrame("help")
            i = i + 1
            createModuleButton(helpF, WD_BUTTON_HELP_MODULE, x, y + i * dy)

            hideModules()
            WDGF:UnregisterEvent("PLAYER_ENTERING_WORLD")
        elseif event == "GUILD_ROSTER_UPDATE" then
            local gRanks = WD:GetGuildRanks()
            if #gRanks ~= 0 then
                WDGF:UnregisterEvent("GUILD_ROSTER_UPDATE")
            end
            WDGF:OnUpdate()
        end
    end)
    WDGF:SetScript("OnShow", function(self)
        if self:IsEventRegistered("GUILD_ROSTER_UPDATE") then
            GuildRoster()
        end
    end)

    GuildRoster()
    WDGF:Hide()

    if WD.db.profile.isLocked == false then
        WDGF:RegisterForDrag("LeftButton")
        WDGF:SetMovable(true)
    else
        WDGF:RegisterForDrag()
        WDGF:SetMovable(false)
    end

    function WDGF:OnUpdate()
        for _,v in pairs(WDGF.module) do
            v:OnUpdate()
        end
    end
end

function WD:OpenConfig()
    WDGF:Show()
end
