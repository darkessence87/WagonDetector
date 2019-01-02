
local WDMainModule = {}
WDMainModule.__index = WDMainModule

setmetatable(WDMainModule, {
    __index = WD.Module,
    __call = function (v, ...)
        local self = setmetatable({}, v)
        self:init(...)
        return self
    end,
})

local function lockConfig(parent)
    if WD.db.profile.isLocked == true then
        parent:RegisterForDrag("LeftButton")
        parent:SetMovable(true)
        WD.db.profile.isLocked = false
    else
        parent:RegisterForDrag()
        parent:SetMovable(false)
        WD.db.profile.isLocked = true
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
    WdLib.gui:updateDropDownMenu(parent, "GuildRanks", items3)
end

function WDMainModule:init(parent, yOffset)
    WD.Module.init(self, WD_BUTTON_MAIN_MODULE, parent, yOffset)
    local mainF = self.frame

    -- check lock button
    mainF.lockButton = WdLib.gui:createCheckButton(mainF)
    mainF.lockButton:SetPoint("TOPLEFT", mainF, "TOPLEFT", 5, -5)
    mainF.lockButton:SetChecked(WD.db.profile.isLocked)
    mainF.lockButton:SetScript("OnClick", function() lockConfig(parent) end)
    mainF.lockButton.txt = WdLib.gui:createFont(mainF.lockButton, "LEFT", WD_BUTTON_LOCK_GUI)
    mainF.lockButton.txt:SetSize(300, 20)
    mainF.lockButton.txt:SetPoint("LEFT", mainF.lockButton, "RIGHT", 5, 0)

    -- default chat selector
    mainF.dropFrame0 = WdLib.gui:createDropDownMenu(mainF)
    WdLib.gui:updateDropDownMenu(mainF.dropFrame0, WD_BUTTON_DEFAULT_CHAT, WdLib.gui:convertTypesToItems(chatTypes, function() WD.db.profile.chat = mainF.dropFrame0.txt:GetText() end))
    mainF.dropFrame0:SetSize(350, 20)
    mainF.dropFrame0:SetPoint("TOPLEFT", mainF.lockButton, "BOTTOMLEFT", 0, -5)
    mainF.dropFrame0:SetScript("OnShow", function() mainF.dropFrame0.txt:SetText(WD.db.profile.chat) end)

    -- check enable button
    mainF.enableButton = WdLib.gui:createCheckButton(mainF)
    mainF.enableButton:SetPoint("TOPLEFT", mainF.dropFrame0, "BOTTOMLEFT", 0, -5)
    mainF.enableButton:SetChecked(WD.db.profile.isEnabled)
    mainF.enableButton:SetScript("OnClick", function() WD:EnableConfig() end)
    mainF.enableButton.txt = WdLib.gui:createFont(mainF.enableButton, "LEFT", WD_BUTTON_ENABLE_CONFIG)
    mainF.enableButton.txt:SetSize(300, 20)
    mainF.enableButton.txt:SetPoint("LEFT", mainF.enableButton, "RIGHT", 5, 0)

    -- check start tracking only by macro
    mainF.autotrackButton = WdLib.gui:createCheckButton(mainF)
    mainF.autotrackButton:SetPoint("TOPLEFT", mainF.enableButton, "BOTTOMLEFT", 0, -5)
    mainF.autotrackButton:SetChecked(WD.db.profile.autoTrack)
    mainF.autotrackButton:SetScript("OnClick", function() WD.db.profile.autoTrack = not WD.db.profile.autoTrack; if WD.db.profile.autoTrack then WD.mainFrame:StartPull() else WD.mainFrame:StopPull() end end)
    mainF.autotrackButton.txt = WdLib.gui:createFont(mainF.autotrackButton, "LEFT", WD_BUTTON_AUTOTRACK)
    mainF.autotrackButton.txt:SetSize(300, 20)
    mainF.autotrackButton.txt:SetPoint("LEFT", mainF.autotrackButton, "RIGHT", 5, 0)

    -- check immediate fail button
    mainF.immediateButton = WdLib.gui:createCheckButton(mainF)
    mainF.immediateButton:SetPoint("TOPLEFT", mainF.autotrackButton, "BOTTOMLEFT", 0, -5)
    mainF.immediateButton:SetChecked(WD.db.profile.sendFailImmediately)
    mainF.immediateButton:SetScript("OnClick", function() WD.db.profile.sendFailImmediately = not WD.db.profile.sendFailImmediately end)
    mainF.immediateButton.txt = WdLib.gui:createFont(mainF.immediateButton, "LEFT", WD_BUTTON_IMMEDIATE_NOTIFY)
    mainF.immediateButton.txt:SetSize(300, 20)
    mainF.immediateButton.txt:SetPoint("LEFT", mainF.immediateButton, "RIGHT", 5, 0)

    -- check penalties button
    mainF.penaltyButton = WdLib.gui:createCheckButton(mainF)
    mainF.penaltyButton:SetPoint("TOPLEFT", mainF.immediateButton, "BOTTOMLEFT", 0, -5)
    mainF.penaltyButton:SetChecked(WD.db.profile.enablePenalties)
    mainF.penaltyButton:SetScript("OnClick", function() WD.db.profile.enablePenalties = not WD.db.profile.enablePenalties end)
    mainF.penaltyButton.txt = WdLib.gui:createFont(mainF.penaltyButton, "LEFT", WD_BUTTON_ENABLE_PENALTIES)
    mainF.penaltyButton.txt:SetSize(300, 20)
    mainF.penaltyButton.txt:SetPoint("LEFT", mainF.penaltyButton, "RIGHT", 5, 0)

    -- max deaths button
    mainF.maxDeathsTxt = WdLib.gui:createFontDefault(mainF, "LEFT", WD_BUTTON_MAX_DEATHS)
    mainF.maxDeathsTxt:SetSize(300, 20)
    mainF.maxDeathsTxt:SetPoint("TOPLEFT", mainF.penaltyButton, "BOTTOMLEFT", 0, -5)
    mainF.maxDeaths = WdLib.gui:createDropDownMenu(mainF)
    local items2 = {}
    for i=1,9 do
        local item = { name = i+1, func = function() WD.db.profile.maxDeaths = tonumber(mainF.maxDeaths.txt:GetText()) end }
        table.insert(items2, item)
    end
    WdLib.gui:updateDropDownMenu(mainF.maxDeaths, WD.db.profile.maxDeaths, items2)
    mainF.maxDeaths:SetSize(150, 20)
    mainF.maxDeaths:SetPoint("TOPLEFT", mainF.penaltyButton, "BOTTOMLEFT", 200, -5)
    mainF.maxDeaths:SetScript("OnShow", function() mainF.maxDeaths.txt:SetText(WD.db.profile.maxDeaths) end)

    -- default guild rank selector
    mainF.rankSelectorTxt = WdLib.gui:createFontDefault(mainF, "LEFT", WD_BUTTON_SELECT_RANK)
    mainF.rankSelectorTxt:SetSize(200, 20)
    mainF.rankSelectorTxt:SetPoint("TOPLEFT", mainF.maxDeathsTxt, "BOTTOMLEFT", 0, -5)
    mainF.dropFrame1 = WdLib.gui:createDropDownMenu(mainF)
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

WD.MainModule = WDMainModule