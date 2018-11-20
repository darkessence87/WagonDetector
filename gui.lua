
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

local function initMainModule(mainF)
    -- check lock button
    mainF.lockButton = createCheckButton(mainF)
    mainF.lockButton:SetPoint("TOPLEFT", mainF, "TOPLEFT", 5, -5)
    mainF.lockButton:SetChecked(WD.db.profile.isLocked)
    mainF.lockButton:SetScript("OnClick", function() lockConfig() end)
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
    mainF.dropFrame0:SetScript("OnShow", function() mainF.dropFrame0.txt:SetText(WD.db.profile.chat) end)

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
    mainF.maxDeaths:SetScript("OnShow", function() mainF.maxDeaths.txt:SetText(WD.db.profile.maxDeaths) end)

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
        end }
        table.insert(items3, item)
    end
    updateDropDownMenu(mainF.dropFrame1, "GuildRanks", items3)
    mainF.dropFrame1:SetSize(150, 20)
    mainF.dropFrame1:SetPoint("TOPLEFT", mainF.maxDeathsTxt, "BOTTOMLEFT", 100, -5)
    mainF.dropFrame1:SetScript("OnShow", function() mainF.dropFrame1.txt:SetText(WD.db.profile.minGuildRank.name) end)
end

local function createModuleButton(module, name, ySize, yOffset)
    local parent = module:GetParent()
    module.button = createButton(parent)
    module.button:SetPoint("TOPLEFT", parent, "TOPLEFT", 1, yOffset)
    module.button:SetSize(158, ySize)
    module.button:SetScript("OnClick", function() if not module:IsVisible() then hideModules(); module:Show(); module.button.t:SetColorTexture(.2, .6, .2, 1); end end)
    module.button.txt = createFont(module.button, "LEFT", name)
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
    m:SetFrameStrata("DIALOG")

    if name == "main" then
        initMainModule(m)
    elseif name == "encounters" then
        WD:InitEncountersModule(m)
    elseif name == "guild_roster" then
        WD:InitGuildRosterModule(m)
    elseif name == "last_encounter" then
        WD:InitLastEncounterModule(m)
    elseif name == "history" then
        WD:InitHistoryModule(m)
    end

    return m
end

function WD:CreateGuiFrame()
    -- gui frame
    self.guiFrame = CreateFrame("Frame", "WD.guiFrame", UIParent)
    WDGF = self.guiFrame
    WDGF.module = {}
    WDGF:SetSize(1000, 600)
    WDGF:SetPoint("CENTER", 0, 0)
    WDGF:SetFrameStrata("DIALOG")
    -- default drag mode
    WDGF:EnableMouse(true)
    WDGF:SetScript("OnDragStart", WDGF.StartMoving)
    WDGF:SetScript("OnDragStop", WDGF.StopMovingOrSizing)
    -- WDGF background
    WDGF.bg = createColorTexture(WDGF, "TEXTURE", 0, 0, 0, .99)
    WDGF.bg:ClearAllPoints()
    WDGF.bg:SetPoint("TOPLEFT", WDGF, "TOPLEFT", 0, 0)
    WDGF.bg:SetAllPoints()
    -- x button
    WDGF.xButton = createXButton(WDGF, 0)

    WDGF:RegisterEvent("GUILD_ROSTER_UPDATE")
    WDGF:SetScript("OnEvent", function(self, event)
        local gRanks = WD:GetGuildRanks()
        if #gRanks == 0 then return end

        -- modules frames
        local mainF = createModuleFrame("main")
        createModuleButton(mainF, WD_BUTTON_MAIN_MODULE, 20, -30)
        local encF = createModuleFrame("encounters")
        createModuleButton(encF, WD_BUTTON_ENCOUNTERS_MODULE, 20, -51)
        local pointsF = createModuleFrame("guild_roster")
        createModuleButton(pointsF, WD_BUTTON_GUILD_ROSTER_MODULE, 20, -72)
        local lastEncF = createModuleFrame("last_encounter")
        createModuleButton(lastEncF, WD_BUTTON_LAST_ENCOUNTER_MODULE, 20, -93)
        local historyF = createModuleFrame("history")
        createModuleButton(historyF, WD_BUTTON_HISTORY_MODULE, 20, -114)
        hideModules()

        WDGF:UnregisterEvent("GUILD_ROSTER_UPDATE")
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
end

function WD:OpenConfig()
    WDGF:Show()
end
